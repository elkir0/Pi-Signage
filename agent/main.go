// Command zaforge-agent is the Pi-side control-plane agent for the Zaforge fleet.
//
// It enrolls to the relay over HTTPS, brings up a persistent WireGuard tunnel,
// then heartbeats + receives commands over MQTT *inside* that tunnel, executing
// each command via the LOCAL PiSignage API on 127.0.0.1 with the X-Agent-Token
// loopback bridge (the four reachable endpoints only) or, for reboot, directly
// as user pi via the pre-existing sudoers grant.
//
// DEPENDENCY JUSTIFICATION (kept deliberately minimal):
//   - github.com/eclipse/paho.mqtt.golang : MQTT 3.1.1 client. Chosen over a
//     hand-rolled stdlib implementation because it gives us, battle-tested:
//     auto-reconnect with backoff, Last-Will-and-Testament, QoS1 delivery,
//     and clean keepalive handling — exactly the robustness this agent needs.
//   - WireGuard: the agent (user pi) NEVER calls wg-quick and NEVER authors
//     /etc/wireguard/zf0.conf (wg-quick runs PostUp/PreUp lines as root, so an
//     unprivileged process authoring its conf would be a trivial root hole).
//     Instead the agent stages a STRICTLY-VALIDATED data file (wg.json, relay
//     /32 only, no DNS, no hooks) plus its own 0600 private key, then calls the
//     fixed root helper `sudo -n /opt/pisignage/scripts/zaforge-wg-up.sh` (no
//     args). That helper re-validates every field and brings the interface up
//     with ip(8) + `wg setconf` from a root-only file — no hook surface.
//   - Curve25519 keygen uses stdlib crypto/ecdh (X25519) — NO extra crypto dep.
//
// Everything else is the Go standard library. The result is a single static
// binary with no runtime deps on the Pi beyond the wireguard-tools package.
//
// SAFETY: the agent must NEVER take down the player. Every failure path logs and
// retries with backoff; the PiSignage web stack and kiosk run untouched.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func nowUnix() int64 { return time.Now().Unix() }

func getenv(k string) string { return os.Getenv(k) }
func getenvDefault(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func main() {
	log.SetFlags(log.LstdFlags | log.LUTC)
	log.SetPrefix("zaforge-agent: ")

	showFP := flag.Bool("show-fingerprint", false, "print the device WG public-key fingerprint and exit")
	version := flag.Bool("version", false, "print version and exit")
	flag.Parse()

	if *version {
		fmt.Println(agentBinaryName, agentVersion)
		return
	}

	paths := resolvePaths()

	// --show-fingerprint must work offline (operator reads it during admin confirm).
	if *showFP {
		kp, err := loadOrCreateWGKeyPair(paths.WGPrivateKey)
		if err != nil {
			log.Fatalf("cannot load/create wg key: %v", err)
		}
		fmt.Println(fingerprint(kp.PublicB64))
		return
	}

	// Feature gate: default OFF. Exit 0 cleanly so systemd does not flap-restart.
	if !enableRelay(paths.FeatureFlags) {
		log.Printf("ENABLE_RELAY not set — relay agent disabled, exiting cleanly")
		return
	}

	if missing := reachableBinaries(); len(missing) > 0 {
		log.Printf("WARNING: missing required tools %v — WireGuard bring-up will fail until installed", missing)
	}

	if err := os.MkdirAll(paths.RelayDir, 0700); err != nil {
		log.Fatalf("cannot create relay state dir: %v", err)
	}

	// Top-level supervision loop: on any fatal error in a session we back off and
	// retry forever (systemd also restarts us, but in-process retry avoids churn).
	backoff := newBackoff(5*time.Second, 5*time.Minute)
	for {
		if err := runSession(paths); err != nil {
			d := backoff.next()
			log.Printf("session ended: %v — retrying in %s", err, d)
			time.Sleep(d)
			continue
		}
		return // clean shutdown (SIGTERM)
	}
}

// runSession performs one full bring-up and runs until shutdown or fatal error.
func runSession(paths Paths) error {
	rc, err := loadRelayConfig(paths.RelayJSON)
	if err != nil {
		return fmt.Errorf("relay config: %w", err)
	}
	token, err := loadAgentToken(paths.AgentJSON)
	if err != nil {
		return fmt.Errorf("agent token: %w", err)
	}
	kp, err := loadOrCreateWGKeyPair(paths.WGPrivateKey)
	if err != nil {
		return fmt.Errorf("wg keypair: %w", err)
	}

	// 1) Enrollment — reuse a persisted enrollment if present (survives reboot);
	//    otherwise enroll fresh (idempotent via a stable nonce so a lost response
	//    on retry does not consume a second code).
	er, savedNonce, err := loadEnrollment(paths.EnrollmentJSON)
	if err != nil {
		log.Printf("could not read persisted enrollment (%v) — will enroll fresh", err)
	}
	if er == nil {
		nonce := savedNonce
		if nonce == "" {
			nonce, err = newNonce()
			if err != nil {
				return fmt.Errorf("nonce: %w", err)
			}
		}
		if rc.EnrollmentCode == "" {
			return fmt.Errorf("no persisted enrollment and relay.json has no enrollment_code")
		}
		facts := gatherFacts()
		er, err = enroll(rc, kp, facts, nonce)
		if err != nil {
			return fmt.Errorf("enroll: %w", err)
		}
		if err := persistEnrollment(paths.EnrollmentJSON, er, nonce); err != nil {
			log.Printf("WARNING: could not persist enrollment: %v", err)
		}
		log.Printf("enrolled: device_id=%s fingerprint=%s", er.DeviceID, er.Fingerprint)
	}

	// 2) WireGuard — stage a STRICTLY-VALIDATED data file (relay /32 only, no DNS,
	//    no hooks) and bring the tunnel up via the fixed root helper. The agent
	//    never authors /etc/wireguard/zf0.conf and never calls wg-quick.
	wd, err := buildWGData(paths.WGInterface, paths.WGPrivateKey, er.WG.Address, er.WG.Peer)
	if err != nil {
		return fmt.Errorf("wg data: %w", err)
	}
	if err := bringUpTunnel(paths.WGDataPath, wd); err != nil {
		return fmt.Errorf("wg up: %w", err)
	}
	if err := waitTunnel(fmt.Sprintf("%s:%d", er.MQTT.Host, er.MQTT.Port), 30*time.Second); err != nil {
		return fmt.Errorf("wg tunnel probe: %w", err)
	}
	log.Printf("wireguard tunnel up (%s -> %s)", er.WG.Address, er.WG.Peer.Endpoint)

	// 3) MQTT inside the tunnel.
	api := newLocalAPI(token)
	dedup := newDedupLRU(256)
	bootTime := time.Now()
	stop := make(chan struct{})

	var mqttAgent *MQTTAgent
	exec := &executor{api: api, dedup: dedup}
	exec.onEvent = func(t string, p any) { mqttAgent.publishEvent(t, p) }

	onCmd := func(env commandEnvelope) {
		res := exec.handle(env)
		mqttAgent.publishResult(res)
	}

	mqttAgent, err = connectMQTT(er.MQTT, onCmd)
	if err != nil {
		return fmt.Errorf("mqtt: %w", err)
	}

	// reboot hook: publish result + retained offline, flush, then reboot as pi.
	exec.onReboot = func() {
		log.Printf("reboot requested — publishing graceful offline then rebooting")
		mqttAgent.publishOfflineRetained()
		time.Sleep(1 * time.Second) // allow QoS1 flush
		if err := doReboot(); err != nil {
			log.Printf("reboot failed: %v", err)
		}
	}

	// 4) Heartbeat loop.
	go runHeartbeatLoop(mqttAgent, api, er.DeviceID, er.HeartbeatInterval, bootTime, stop)
	log.Printf("agent running: heartbeating every %ds on %s", maxInt(er.HeartbeatInterval, 30), er.MQTT.BaseTopic)

	// 5) Wait for SIGTERM/SIGINT -> graceful offline + disconnect.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
	<-sigCh
	log.Printf("shutdown signal received — going offline gracefully")
	close(stop)
	mqttAgent.publishOfflineRetained()
	mqttAgent.disconnect()
	// Tear the tunnel down via the fixed root helper (best effort; never fatal).
	bringDownTunnel()
	return nil
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// ---- exponential backoff with cap ----
type backoff struct {
	cur, min, max time.Duration
}

func newBackoff(min, max time.Duration) *backoff { return &backoff{cur: min, min: min, max: max} }
func (b *backoff) next() time.Duration {
	d := b.cur
	b.cur *= 2
	if b.cur > b.max {
		b.cur = b.max
	}
	return d
}
func (b *backoff) reset() { b.cur = b.min }
