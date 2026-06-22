package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

// LocalAPI is the loopback client to the PiSignage PHP API.
type LocalAPI struct {
	base   string // http://127.0.0.1
	token  string // X-Agent-Token
	client *http.Client
}

func newLocalAPI(token string) *LocalAPI {
	base := "http://127.0.0.1"
	if v := getenv("ZF_LOCAL_API_BASE"); v != "" {
		base = v
	}
	return &LocalAPI{
		base:   base,
		token:  token,
		client: &http.Client{Timeout: 8 * time.Second},
	}
}

// piResponse is the standard PiSignage envelope {success,data,message}.
type piResponse struct {
	Success bool            `json:"success"`
	Data    json.RawMessage `json:"data"`
	Message string          `json:"message"`
}

// do performs a loopback call and decodes the standard envelope. The returned
// error is one of the contract error codes (loopback_5xx, timeout, ...) so the
// caller can put it straight into a result payload with no internal leakage.
func (a *LocalAPI) do(method, path string, body any) (*piResponse, error) {
	var rdr io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("bad_request")
		}
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, a.base+path, rdr)
	if err != nil {
		return nil, fmt.Errorf("bad_request")
	}
	req.Header.Set("X-Agent-Token", a.token)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := a.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("timeout")
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))

	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return nil, fmt.Errorf("forbidden_endpoint")
	}
	if resp.StatusCode >= 500 {
		return nil, fmt.Errorf("loopback_5xx")
	}
	var pr piResponse
	if err := json.Unmarshal(raw, &pr); err != nil {
		return nil, fmt.Errorf("loopback_5xx")
	}
	if resp.StatusCode >= 400 || !pr.Success {
		return &pr, fmt.Errorf("rejected")
	}
	return &pr, nil
}

// ---- typed wrappers for the four reachable endpoints ----

// GET /api/stats.php
func (a *LocalAPI) stats() (*statsData, error) {
	pr, err := a.do(http.MethodGet, "/api/stats.php", nil)
	if err != nil {
		return nil, err
	}
	var d statsData
	if err := json.Unmarshal(pr.Data, &d); err != nil {
		return nil, fmt.Errorf("loopback_5xx")
	}
	return &d, nil
}

// GET /api/display.php?action=state
func (a *LocalAPI) displayState() (*displayStateData, error) {
	pr, err := a.do(http.MethodGet, "/api/display.php?action=state", nil)
	if err != nil {
		return nil, err
	}
	var d displayStateData
	if err := json.Unmarshal(pr.Data, &d); err != nil {
		return nil, fmt.Errorf("loopback_5xx")
	}
	return &d, nil
}

// POST /api/display.php?action=command {cmd:...}
func (a *LocalAPI) displayCommand(cmd string) (*piResponse, error) {
	return a.do(http.MethodPost, "/api/display.php?action=command", map[string]string{"cmd": cmd})
}

// POST /api/playlists.php  (create/replace named playlist; body = playlist)
func (a *LocalAPI) savePlaylist(pl map[string]any) (*piResponse, error) {
	return a.do(http.MethodPost, "/api/playlists.php", pl)
}

// POST /api/playlists.php?action=activate&name=<name>
func (a *LocalAPI) activatePlaylist(name string) (*piResponse, error) {
	q := "/api/playlists.php?action=activate&name=" + url.QueryEscape(name)
	return a.do(http.MethodPost, q, nil)
}

// ---- remote-control bridge: data reads + media/playlist management ----

// GET /api/playlists.php  (list all + active slug)
func (a *LocalAPI) listPlaylists() (*piResponse, error) {
	return a.do(http.MethodGet, "/api/playlists.php", nil)
}

// GET /api/playlists.php?name=<name>  (one playlist)
func (a *LocalAPI) getPlaylist(name string) (*piResponse, error) {
	return a.do(http.MethodGet, "/api/playlists.php?name="+url.QueryEscape(name), nil)
}

// DELETE /api/playlists.php?name=<name>
func (a *LocalAPI) deletePlaylist(name string) (*piResponse, error) {
	return a.do(http.MethodDelete, "/api/playlists.php?name="+url.QueryEscape(name), nil)
}

// GET /api/media.php?action=list
func (a *LocalAPI) listMedia() (*piResponse, error) {
	return a.do(http.MethodGet, "/api/media.php?action=list", nil)
}

// DELETE /api/media.php  {filename}  (PHP basename()s server-side)
func (a *LocalAPI) deleteMedia(filename string) (*piResponse, error) {
	return a.do(http.MethodDelete, "/api/media.php", map[string]any{"filename": filename})
}

// POST /api/youtube.php  {url,quality,format,audio_only}  (yt-dlp -> /media/)
func (a *LocalAPI) downloadYouTube(body map[string]any) (*piResponse, error) {
	return a.do(http.MethodPost, "/api/youtube.php", body)
}

// GET /api/youtube.php?action=queue  (download jobs)
func (a *LocalAPI) listDownloads() (*piResponse, error) {
	return a.do(http.MethodGet, "/api/youtube.php?action=queue", nil)
}

// POST /api/display.php?action=playmedia  {file}  (play one file as a live 1-item playlist)
func (a *LocalAPI) playMedia(file string) (*piResponse, error) {
	return a.do(http.MethodPost, "/api/display.php?action=playmedia", map[string]any{"file": file})
}

// NOTE: volume is NOT bridged through PHP. system.php is deny-all'd at nginx (it
// carries reboot/shutdown), and HDMI cards expose no mixer. The agent talks to
// ALSA directly (amixer, user pi) — see commands.go get/set/toggle-mute handlers.

// ---- response shapes (only the fields the heartbeat/command need) ----

type statsData struct {
	CPU struct {
		Usage   float64 `json:"usage"`
		Load1   float64 `json:"load_1min"`
	} `json:"cpu"`
	Memory struct {
		Percent float64 `json:"percent"`
	} `json:"memory"`
	Disk struct {
		Percent int `json:"percent"`
	} `json:"disk"`
	Temperature *float64 `json:"temperature"`
	Uptime      string   `json:"uptime"`
	Throttled   *struct {
		UnderVoltageNow      bool `json:"under_voltage_now"`
		UnderVoltageOccurred bool `json:"under_voltage_occurred"`
	} `json:"throttled"`
}

type displayStateData struct {
	State *struct {
		Status  string `json:"status"`
		Name    string `json:"name"`
		Version int    `json:"version"`
		Index   int    `json:"index"`
		Count   int    `json:"count"`
		Current struct {
			Name string `json:"name"`
		} `json:"current"`
	} `json:"state"`
	Online bool `json:"online"`
	Active *struct {
		Slug string `json:"slug"`
		Name string `json:"name"`
	} `json:"active"`
}
