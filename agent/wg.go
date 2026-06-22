package main

import (
	"crypto/ecdh"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"
)

// SECURITY MODEL (agent side)
//
//   The agent runs as user 'pi' and must NEVER be able to escalate to root by
//   authoring a file that a privileged tool then executes. In particular:
//     - We do NOT write /etc/wireguard/zf0.conf and we do NOT call `wg-quick`.
//       wg-quick executes PostUp/PreUp/PostDown lines as root, so letting an
//       unprivileged process author its conf is a trivial root hole.
//     - Instead the agent writes ONLY two things it owns:
//         * the WG private key (pi:pi 0600) at WGPrivateKey
//         * a strictly-shaped DATA file wg.json (pi:pi 0600) at WGDataPath
//       then invokes the fixed, argument-less root helper:
//         sudo -n /opt/pisignage/scripts/zaforge-wg-up.sh
//       The helper (root) re-validates every field, reads the pi-owned private
//       key, and brings the interface up with ip(8) + `wg setconf` from a
//       root-only file — no hook surface anywhere.
//
//   The agent NEVER runs `wg` / `wg-quick` / `ip` under sudo itself; all status
//   reads below are unprivileged (`wg show` works read-only for the owner of the
//   interface namespace; if denied we degrade gracefully and let the handshake
//   wait time out rather than crashing the player).

// WGKeyPair holds base64 (standard, with padding) Curve25519 keys, the same
// encoding `wg` uses.
type WGKeyPair struct {
	PrivateB64 string
	PublicB64  string
}

// generateWGKeyPair produces a Curve25519 keypair using stdlib crypto/ecdh
// (X25519). No external crypto dependency. The clamping required by WireGuard
// is applied internally by crypto/ecdh, and the resulting public key is
// byte-identical to what `wg pubkey` would derive from the same private scalar.
func generateWGKeyPair() (*WGKeyPair, error) {
	curve := ecdh.X25519()
	priv, err := curve.GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("x25519 keygen: %w", err)
	}
	return &WGKeyPair{
		PrivateB64: base64.StdEncoding.EncodeToString(priv.Bytes()),
		PublicB64:  base64.StdEncoding.EncodeToString(priv.PublicKey().Bytes()),
	}, nil
}

// loadOrCreateWGKeyPair returns a stable keypair: it reuses the private key on
// disk if present (so re-enrollment with rebind keeps the same identity when the
// operator chooses), else generates and persists a new one at 0600 pi:pi.
func loadOrCreateWGKeyPair(privPath string) (*WGKeyPair, error) {
	if b, err := os.ReadFile(privPath); err == nil {
		privB64 := strings.TrimSpace(string(b))
		raw, derr := base64.StdEncoding.DecodeString(privB64)
		if derr == nil && len(raw) == 32 {
			curve := ecdh.X25519()
			priv, kerr := curve.NewPrivateKey(raw)
			if kerr == nil {
				return &WGKeyPair{
					PrivateB64: privB64,
					PublicB64:  base64.StdEncoding.EncodeToString(priv.PublicKey().Bytes()),
				}, nil
			}
		}
	}
	kp, err := generateWGKeyPair()
	if err != nil {
		return nil, err
	}
	if err := writeFile0600(privPath, []byte(kp.PrivateB64+"\n")); err != nil {
		return nil, fmt.Errorf("persist wg private key: %w", err)
	}
	return kp, nil
}

// fingerprint returns SHA256:aa:bb:.. over the base64 public key string, matching
// the relay's enrollment-response fingerprint (admin confirms this visually).
func fingerprint(pubB64 string) string {
	sum := sha256.Sum256([]byte(pubB64))
	parts := make([]string, len(sum))
	for i, b := range sum {
		parts[i] = fmt.Sprintf("%02x", b)
	}
	return "SHA256:" + strings.Join(parts, ":")
}

// ---- validation mirrors (and is a defence-in-depth duplicate of) the helper ----

var (
	reWGKey      = regexp.MustCompile(`^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$`)
	reIPv4CIDR   = regexp.MustCompile(`^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}/(3[0-2]|[12]?[0-9])$`)
	reHostPort   = regexp.MustCompile(`^([A-Za-z0-9.-]{1,253}):([1-9][0-9]{0,4})$`)
	reRelayAllow = regexp.MustCompile(`^10\.70\.0\.1/32$`)
)

// wgData is the strict, flat shape the root helper consumes. We marshal exactly
// these keys (no hooks, no DNS, no extra fields the helper would ignore).
type wgData struct {
	Iface          string `json:"iface"`
	Address        string `json:"address"`
	PrivateKeyPath string `json:"private_key_path"`
	ServerPubkey   string `json:"server_pubkey"`
	Endpoint       string `json:"endpoint"`
	AllowedIPs     string `json:"allowed_ips"`
	Keepalive      int    `json:"keepalive"`
}

// buildWGData validates the enrollment-derived peer into the helper's data
// shape, enforcing the LAN-safety invariant (relay /32 ONLY) BEFORE we ever
// write anything a privileged tool will read. Returns an error (never panics)
// so a malicious/garbled relay response cannot brick the Pi or escalate.
func buildWGData(iface, privKeyPath, address string, peer EnrollWGPeer) (*wgData, error) {
	if iface != "zf0" {
		return nil, fmt.Errorf("wg: unexpected interface name")
	}
	if !reIPv4CIDR.MatchString(address) {
		return nil, fmt.Errorf("wg: address not IPv4/CIDR")
	}
	if !reWGKey.MatchString(peer.PublicKey) {
		return nil, fmt.Errorf("wg: server pubkey invalid")
	}
	if !reHostPort.MatchString(peer.Endpoint) {
		return nil, fmt.Errorf("wg: endpoint not host:port")
	}
	// LAN-SAFETY INVARIANT: relay /32 only. A wider AllowedIPs would steal the
	// Pi's routes and brick the customer's own network — reject hard, never the
	// customer LAN, never 0.0.0.0/0.
	if !reRelayAllow.MatchString(peer.AllowedIPs) {
		return nil, fmt.Errorf("wg: allowed_ips must be exactly 10.70.0.1/32")
	}
	ka := peer.PersistentKeepalive
	if ka < 0 || ka > 65535 {
		ka = 0
	}
	return &wgData{
		Iface:          iface,
		Address:        address,
		PrivateKeyPath: privKeyPath,
		ServerPubkey:   peer.PublicKey,
		Endpoint:       peer.Endpoint,
		AllowedIPs:     peer.AllowedIPs,
		Keepalive:      ka,
	}, nil
}

// writeWGData stages the validated DATA file (pi:pi 0600). This file contains NO
// secret material (the private key stays in its own 0600 file referenced by
// path), so it is safe to persist. It is the ONLY thing the root helper reads
// besides the private-key file.
func writeWGData(path string, d *wgData) error {
	b, err := json.MarshalIndent(d, "", "  ")
	if err != nil {
		return err
	}
	b = append(b, '\n')
	return writeFile0600(path, b)
}

// bringUpTunnel stages wg.json then invokes the fixed root helper. No wg-quick,
// no agent-authored /etc/wireguard conf, no PostUp/PreUp hook surface. The helper
// path and the fact that it takes NO arguments are both pinned in sudoers.
func bringUpTunnel(dataPath string, d *wgData) error {
	if err := writeWGData(dataPath, d); err != nil {
		return fmt.Errorf("stage wg data: %w", err)
	}
	// Fixed, argument-less invocation. sudo -n so we never hang on a prompt.
	if err := run("sudo", "-n", wgUpHelperPath()); err != nil {
		return fmt.Errorf("wg up helper: %w", err)
	}
	return nil
}

// bringDownTunnel tears the tunnel down via the fixed root helper (best effort).
func bringDownTunnel() {
	_ = runQuiet("sudo", "-n", wgDownHelperPath())
}

func wgUpHelperPath() string {
	return getenvDefault("ZF_WG_UP", "/opt/pisignage/scripts/zaforge-wg-up.sh")
}

func wgDownHelperPath() string {
	return getenvDefault("ZF_WG_DOWN", "/opt/pisignage/scripts/zaforge-wg-down.sh")
}

// waitHandshake polls `wg show <iface> latest-handshakes` until a non-zero
// handshake appears or the deadline passes. This is an UNPRIVILEGED read; if it
// is denied we simply keep polling until timeout and let the caller back off —
// we never escalate and never crash.
func waitHandshake(iface string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		out, err := runOut("wg", "show", iface, "latest-handshakes")
		if err == nil {
			for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
				fields := strings.Fields(line)
				if len(fields) == 2 && fields[1] != "0" {
					return nil
				}
			}
		}
		time.Sleep(2 * time.Second)
	}
	return fmt.Errorf("no wireguard handshake on %s within %s", iface, timeout)
}

// ---- small exec helpers ----

func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stderr // surface helper output into the journal
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runQuiet(name string, args ...string) error {
	return exec.Command(name, args...).Run()
}

func runOut(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	return string(out), err
}
