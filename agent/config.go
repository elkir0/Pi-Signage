package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// ---- Fixed on-disk locations (env-overridable for tests) ----

const (
	defaultConfigDir = "/opt/pisignage/config"
	agentVersion     = "0.1.0"
	agentBinaryName  = "zaforge-agent"
)

// Paths bundles every file the agent reads or writes. Centralised so tests can
// redirect everything under a temp dir via ZF_CONFIG_DIR.
type Paths struct {
	ConfigDir      string // /opt/pisignage/config
	AgentJSON      string // .../agent.json          (read: loopback token)
	RelayJSON      string // .../relay.json          (read: relay endpoint + enroll code)
	FeatureFlags   string // .../feature_flags        (read: ENABLE_RELAY)
	RelayDir       string // .../relay/               (agent-owned state, 0700)
	WGPrivateKey   string // .../relay/wg_private.key (0600, pi:pi)
	EnrollmentJSON string // .../relay/enrollment.json(0600, secrets stripped where re-fetchable)
	WGInterface    string // zf0
	WGDataPath     string // .../relay/wg.json   (0600 pi:pi DATA file the root helper consumes)
}

func resolvePaths() Paths {
	dir := os.Getenv("ZF_CONFIG_DIR")
	if dir == "" {
		dir = defaultConfigDir
	}
	relayDir := filepath.Join(dir, "relay")
	// The agent NEVER writes /etc/wireguard/zf0.conf. It stages a validated DATA
	// file (wg.json) that the root helper zaforge-wg-up.sh consumes. Overridable
	// for tests via ZF_WG_DATA.
	wgData := os.Getenv("ZF_WG_DATA")
	if wgData == "" {
		wgData = filepath.Join(relayDir, "wg.json")
	}
	return Paths{
		ConfigDir:      dir,
		AgentJSON:      filepath.Join(dir, "agent.json"),
		RelayJSON:      filepath.Join(dir, "relay.json"),
		FeatureFlags:   filepath.Join(dir, "feature_flags"),
		RelayDir:       relayDir,
		WGPrivateKey:   filepath.Join(relayDir, "wg_private.key"),
		EnrollmentJSON: filepath.Join(relayDir, "enrollment.json"),
		WGInterface:    "zf0",
		WGDataPath:     wgData,
	}
}

// ---- relay.json : operator-provisioned bootstrap ----
// Shape:
//
//	{
//	  "relay_url": "https://relay.zaforge.com",
//	  "enrollment_code": "ZF-7Q2M-K4XR-9TVB",
//	  "rebind": false
//	}
type RelayConfig struct {
	RelayURL       string `json:"relay_url"`
	EnrollmentCode string `json:"enrollment_code"`
	Rebind         bool   `json:"rebind"`
}

func loadRelayConfig(path string) (*RelayConfig, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read relay.json: %w", err)
	}
	var rc RelayConfig
	if err := json.Unmarshal(b, &rc); err != nil {
		return nil, fmt.Errorf("parse relay.json: %w", err)
	}
	if rc.RelayURL == "" {
		return nil, fmt.Errorf("relay.json: relay_url is empty")
	}
	return &rc, nil
}

// ---- agent.json : loopback bridge token (Phase 0, already deployed) ----
func loadAgentToken(path string) (string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("read agent.json: %w", err)
	}
	var j struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal(b, &j); err != nil {
		return "", fmt.Errorf("parse agent.json: %w", err)
	}
	if len(j.Token) < 32 {
		return "", fmt.Errorf("agent.json token missing or too short")
	}
	return j.Token, nil
}

// enableRelay reports whether the relay feature is on. Default 0 (OFF).
// feature_flags is a simple KEY=VALUE file; we only care about ENABLE_RELAY=1.
func enableRelay(featureFlagsPath string) bool {
	if v := os.Getenv("ENABLE_RELAY"); v != "" {
		return v == "1" || v == "true"
	}
	b, err := os.ReadFile(featureFlagsPath)
	if err != nil {
		return false
	}
	for _, line := range splitLines(string(b)) {
		if line == "ENABLE_RELAY=1" {
			return true
		}
	}
	return false
}

func splitLines(s string) []string {
	var out []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			out = append(out, trimSpace(s[start:i]))
			start = i + 1
		}
	}
	if start < len(s) {
		out = append(out, trimSpace(s[start:]))
	}
	return out
}

func trimSpace(s string) string {
	for len(s) > 0 && (s[0] == ' ' || s[0] == '\t' || s[0] == '\r') {
		s = s[1:]
	}
	for len(s) > 0 {
		c := s[len(s)-1]
		if c == ' ' || c == '\t' || c == '\r' {
			s = s[:len(s)-1]
		} else {
			break
		}
	}
	return s
}
