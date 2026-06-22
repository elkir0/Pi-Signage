package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"sync"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
)

// Topics derived from the enrollment base_topic zf/<t>/<d>.
type topics struct {
	hb     string
	status string
	cmd    string
	result string
	event  string
}

func topicsFor(base string) topics {
	return topics{
		hb:     base + "/hb",
		status: base + "/status",
		cmd:    base + "/cmd",
		result: base + "/result",
		event:  base + "/event",
	}
}

// MQTTAgent wraps the paho client + the agent's publishing helpers.
type MQTTAgent struct {
	client   mqtt.Client
	topics   topics
	deviceID string
	mu       sync.Mutex
}

func statusPayload(online bool, reason string) []byte {
	m := map[string]any{"v": 1, "online": online, "ts": nowUnix()}
	if reason != "" {
		m["reason"] = reason
	}
	b, _ := json.Marshal(m)
	return b
}

// connectMQTT builds and connects the client. onCmd is invoked for each command
// message; the caller wires it to executor.handle + publishResult.
func connectMQTT(cfg EnrollMQTT, onCmd func(commandEnvelope)) (*MQTTAgent, error) {
	tp := topicsFor(cfg.BaseTopic)

	opts := mqtt.NewClientOptions()
	scheme := "tcp"
	opts.AddBroker(fmt.Sprintf("%s://%s:%d", scheme, cfg.Host, cfg.Port))
	opts.SetClientID(cfg.ClientID)
	opts.SetUsername(cfg.Username)
	opts.SetPassword(cfg.Password)
	if cfg.Keepalive > 0 {
		opts.SetKeepAlive(time.Duration(cfg.Keepalive) * time.Second)
	}
	// Robust reconnect: paho handles backoff internally.
	opts.SetAutoReconnect(true)
	opts.SetConnectRetry(true)
	opts.SetConnectRetryInterval(5 * time.Second)
	opts.SetMaxReconnectInterval(2 * time.Minute)
	opts.SetCleanSession(true)
	opts.SetConnectTimeout(20 * time.Second)
	opts.SetWriteTimeout(10 * time.Second)

	// LWT: retained offline on .../status, fired by broker after keepalive*1.5.
	opts.SetBinaryWill(tp.status, statusPayload(false, "lwt"), 1, true)

	agent := &MQTTAgent{topics: tp, deviceID: cfg.Username}

	// On every (re)connect: re-subscribe to cmd and re-assert retained online:true.
	opts.SetOnConnectHandler(func(c mqtt.Client) {
		log.Printf("mqtt connected (%s)", cfg.Host)
		tok := c.Subscribe(tp.cmd, 1, func(_ mqtt.Client, m mqtt.Message) {
			var env commandEnvelope
			if err := json.Unmarshal(m.Payload(), &env); err != nil {
				log.Printf("cmd: bad payload: %v", err)
				return
			}
			onCmd(env)
		})
		tok.Wait()
		if tok.Error() != nil {
			log.Printf("mqtt subscribe error: %v", tok.Error())
		}
		c.Publish(tp.status, 1, true, statusPayload(true, ""))
	})
	opts.SetConnectionLostHandler(func(_ mqtt.Client, err error) {
		log.Printf("mqtt connection lost: %v (auto-reconnecting)", err)
	})

	client := mqtt.NewClient(opts)
	if tok := client.Connect(); tok.Wait() && tok.Error() != nil {
		return nil, fmt.Errorf("mqtt connect: %w", tok.Error())
	}
	agent.client = client
	return agent, nil
}

func (a *MQTTAgent) publishHeartbeat(hb heartbeat) {
	b, _ := json.Marshal(hb)
	a.client.Publish(a.topics.hb, 1, false, b)
}

func (a *MQTTAgent) publishResult(r resultEnvelope) {
	b, _ := json.Marshal(r)
	tok := a.client.Publish(a.topics.result, 1, false, b)
	tok.WaitTimeout(5 * time.Second)
}

func (a *MQTTAgent) publishEvent(eventType string, payload any) {
	envelope := map[string]any{"v": 1, "ts": nowUnix(), "type": eventType, "payload": payload}
	b, _ := json.Marshal(envelope)
	a.client.Publish(a.topics.event, 1, false, b)
}

// publishOfflineRetained is used on graceful shutdown and just before reboot.
func (a *MQTTAgent) publishOfflineRetained() {
	tok := a.client.Publish(a.topics.status, 1, true, statusPayload(false, "shutdown"))
	tok.WaitTimeout(5 * time.Second)
}

func (a *MQTTAgent) disconnect() {
	a.client.Disconnect(500)
}

// runHeartbeatLoop publishes a heartbeat every interval with +-3s jitter until
// stop is closed. seq increments per boot so the relay can detect restarts/gaps.
func runHeartbeatLoop(a *MQTTAgent, api *LocalAPI, deviceID string, intervalS int, bootTime time.Time, stop <-chan struct{}) {
	if intervalS <= 0 {
		intervalS = 30
	}
	var seq uint64
	for {
		seq++
		hb := buildHeartbeat(api, deviceID, seq, bootTime)
		a.publishHeartbeat(hb)

		jitter := time.Duration(rand.Intn(6001)-3000) * time.Millisecond // +-3s
		wait := time.Duration(intervalS)*time.Second + jitter
		select {
		case <-stop:
			return
		case <-time.After(wait):
		}
	}
}
