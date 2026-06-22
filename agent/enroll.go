package main

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

// ---- enrollment request/response envelopes (CONTRACT v1) ----

type enrollRequest struct {
	V              int             `json:"v"`
	EnrollmentCode string          `json:"enrollment_code"`
	WGPublicKey    string          `json:"wg_public_key"`
	Rebind         bool            `json:"rebind,omitempty"`
	Agent          enrollAgentInfo `json:"agent"`
	DeviceFacts    DeviceFacts     `json:"device_facts"`
	Nonce          string          `json:"nonce"`
}

type enrollAgentInfo struct {
	Version string `json:"version"`
	Binary  string `json:"binary"`
}

// EnrollResponse mirrors the 200 body. Secrets (mqtt.password) are used in-memory
// to connect, then the persisted copy keeps them so the agent can reconnect after
// a reboot without re-enrolling (file is 0600). We never log the plaintext.
type EnrollResponse struct {
	V                 int            `json:"v"`
	DeviceID          string         `json:"device_id"`
	TenantID          string         `json:"tenant_id"`
	Fingerprint       string         `json:"fingerprint"`
	WG                EnrollWG       `json:"wg"`
	MQTT              EnrollMQTT     `json:"mqtt"`
	HeartbeatInterval int            `json:"heartbeat_interval_s"`
}

type EnrollWG struct {
	Address    string       `json:"address"`
	AllowedIPs string       `json:"allowed_ips"`
	DNS        *string      `json:"dns"`
	Peer       EnrollWGPeer `json:"peer"`
}

type EnrollWGPeer struct {
	PublicKey           string `json:"public_key"`
	Endpoint            string `json:"endpoint"`
	PersistentKeepalive int    `json:"persistent_keepalive"`
	// AllowedIPs is what the agent writes into the [Peer] block: the relay /32.
	// Sourced from EnrollWG.AllowedIPs (the response puts it one level up); the
	// agent copies it down before rendering the conf.
	AllowedIPs string `json:"-"`
}

type EnrollMQTT struct {
	Host      string `json:"host"`
	Port      int    `json:"port"`
	TLS       bool   `json:"tls"`
	Username  string `json:"username"`
	Password  string `json:"password"`
	ClientID  string `json:"client_id"`
	Keepalive int    `json:"keepalive"`
	BaseTopic string `json:"base_topic"`
}

type enrollError struct {
	V     int    `json:"v"`
	Error string `json:"error"`
}

func newNonce() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

// enroll performs POST /enroll. It is idempotent across retries via the nonce,
// which is persisted alongside the (yet-incomplete) enrollment so a lost-response
// retry reuses the same nonce and the relay returns the same device row.
func enroll(rc *RelayConfig, kp *WGKeyPair, facts DeviceFacts, nonce string) (*EnrollResponse, error) {
	req := enrollRequest{
		V:              1,
		EnrollmentCode: rc.EnrollmentCode,
		WGPublicKey:    kp.PublicB64,
		Rebind:         rc.Rebind,
		Agent:          enrollAgentInfo{Version: agentVersion, Binary: agentBinaryName},
		DeviceFacts:    facts,
		Nonce:          nonce,
	}
	body, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	url := rc.RelayURL + "/enroll"
	httpReq, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("User-Agent", agentBinaryName+"/"+agentVersion)

	client := &http.Client{Timeout: 20 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("enroll transport: %w", err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))

	if resp.StatusCode == http.StatusOK {
		var er EnrollResponse
		if err := json.Unmarshal(raw, &er); err != nil {
			return nil, fmt.Errorf("enroll: malformed 200 body: %w", err)
		}
		if er.DeviceID == "" || er.WG.Address == "" || er.MQTT.Username == "" {
			return nil, fmt.Errorf("enroll: incomplete 200 body")
		}
		// Hoist AllowedIPs from wg.allowed_ips into the peer for conf rendering.
		er.WG.Peer.AllowedIPs = er.WG.AllowedIPs
		return &er, nil
	}

	// Non-200: surface the generic error code only (no oracle, no secret leak).
	var ee enrollError
	_ = json.Unmarshal(raw, &ee)
	code := ee.Error
	if code == "" {
		code = fmt.Sprintf("http_%d", resp.StatusCode)
	}
	return nil, fmt.Errorf("enroll rejected: %s", code)
}

// persistEnrollment writes enrollment.json at 0600. We keep the mqtt password so
// reboots reconnect without re-enrolling; the file is owner-only and never logged.
func persistEnrollment(path string, er *EnrollResponse, nonce string) error {
	wrapper := struct {
		Nonce      string          `json:"nonce"`
		EnrolledAt int64           `json:"enrolled_at"`
		Response   *EnrollResponse `json:"response"`
	}{Nonce: nonce, EnrolledAt: time.Now().Unix(), Response: er}
	b, err := json.MarshalIndent(wrapper, "", "  ")
	if err != nil {
		return err
	}
	return writeFile0600(path, b)
}

// loadEnrollment returns a previously persisted enrollment, or (nil,nil) if none.
func loadEnrollment(path string) (*EnrollResponse, string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, "", nil
		}
		return nil, "", err
	}
	var wrapper struct {
		Nonce    string          `json:"nonce"`
		Response *EnrollResponse `json:"response"`
	}
	if err := json.Unmarshal(b, &wrapper); err != nil {
		return nil, "", err
	}
	if wrapper.Response != nil {
		wrapper.Response.WG.Peer.AllowedIPs = wrapper.Response.WG.AllowedIPs
	}
	return wrapper.Response, wrapper.Nonce, nil
}
