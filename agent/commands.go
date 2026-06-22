package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path"
	"regexp"
	"strings"
	"sync"
)

// commandEnvelope is what the relay publishes on .../cmd.
type commandEnvelope struct {
	V     int             `json:"v"`
	TS    int64           `json:"ts"`
	CmdID string          `json:"cmd_id"`
	Type  string          `json:"type"`
	Args  json.RawMessage `json:"args"`
}

// resultEnvelope is what the agent publishes on .../result.
type resultEnvelope struct {
	V      int     `json:"v"`
	TS     int64   `json:"ts"`
	CmdID  string  `json:"cmd_id"`
	Type   string  `json:"type"`
	OK     bool    `json:"ok"`
	Code   string  `json:"code"` // applied|rejected|error|not_implemented
	Detail any     `json:"detail,omitempty"`
	Error  *string `json:"error"`
}

// dedupLRU is a tiny fixed-size set of seen cmd_ids.
type dedupLRU struct {
	mu    sync.Mutex
	order []string
	seen  map[string]struct{}
	cap   int
}

func newDedupLRU(capacity int) *dedupLRU {
	return &dedupLRU{seen: make(map[string]struct{}, capacity), cap: capacity}
}

// add returns true if id was already present (a redelivery).
func (d *dedupLRU) add(id string) bool {
	d.mu.Lock()
	defer d.mu.Unlock()
	if _, ok := d.seen[id]; ok {
		return true
	}
	d.seen[id] = struct{}{}
	d.order = append(d.order, id)
	if len(d.order) > d.cap {
		evict := d.order[0]
		d.order = d.order[1:]
		delete(d.seen, evict)
	}
	return false
}

// executor carries everything a command handler needs.
type executor struct {
	api      *LocalAPI
	dedup    *dedupLRU
	onEvent  func(eventType string, payload any) // publishes to .../event
	onReboot func()                              // graceful shutdown hook (publish status, then reboot)
}

func okResult(cmdID, typ, code string, detail any) resultEnvelope {
	return resultEnvelope{V: 1, TS: nowUnix(), CmdID: cmdID, Type: typ, OK: true, Code: code, Detail: detail}
}

func errResult(cmdID, typ, code, errStr string) resultEnvelope {
	e := errStr
	return resultEnvelope{V: 1, TS: nowUnix(), CmdID: cmdID, Type: typ, OK: false, Code: code, Error: &e}
}

// handle executes one command and returns the result to publish. Redelivered
// cmd_ids are re-ACKed (same shape) but NOT re-executed.
func (e *executor) handle(env commandEnvelope) resultEnvelope {
	if env.V > 1 {
		// Forward-compat: unknown higher version -> ignore (still ACK rejected).
		return errResult(env.CmdID, env.Type, "rejected", "unsupported_version")
	}
	if e.dedup.add(env.CmdID) {
		return okResult(env.CmdID, env.Type, "applied", map[string]any{"dedup": true})
	}

	switch env.Type {
	case "push-playlist":
		return e.pushPlaylist(env)
	case "switch":
		return e.switchPlaylist(env)
	case "reload", "play", "pause", "next", "prev":
		return e.transport(env)
	case "screenshot":
		return e.screenshot(env)
	case "get-stats":
		return e.getStats(env)
	// ---- remote-control: read state ----
	case "list-playlists":
		return e.simpleRead(env, func() (*piResponse, error) { return e.api.listPlaylists() })
	case "get-playlist":
		return e.getPlaylistCmd(env)
	case "list-media":
		return e.simpleRead(env, func() (*piResponse, error) { return e.api.listMedia() })
	case "list-downloads":
		return e.simpleRead(env, func() (*piResponse, error) { return e.api.listDownloads() })
	case "get-volume":
		return e.getVolumeCmd(env)
	// ---- remote-control: act on the player ----
	case "delete-playlist":
		return e.deletePlaylistCmd(env)
	case "delete-media":
		return e.deleteMediaCmd(env)
	case "download-media":
		return e.downloadMediaCmd(env)
	case "playmedia":
		return e.playMediaCmd(env)
	case "set-volume":
		return e.setVolumeCmd(env)
	case "toggle-mute":
		return e.toggleMuteCmd(env)
	case "reboot":
		return e.reboot(env)
	case "ota":
		// SECURITY: OTA is deliberately STUBBED. We must NEVER download+swap the
		// agent binary from a relay-supplied URL+sha256 — a compromised/malicious
		// relay would then root the entire fleet (sha256 only proves integrity of
		// whatever the relay told us to fetch, NOT its authenticity).
		// TODO(ota): implement only with an OFFLINE minisign/Ed25519 signature
		// over the artifact, verified with a public key COMPILED INTO this agent
		// (never relay-supplied). Reject unsigned/relay-keyed updates.
		return errResult(env.CmdID, env.Type, "not_implemented", "not_implemented")
	default:
		return errResult(env.CmdID, env.Type, "rejected", "unknown_type")
	}
}

// safePlaylistName constrains a relay-supplied playlist name/slug to a charset
// that cannot escape the playlists directory or overwrite an arbitrary file.
// The PHP side slugifies server-side, but we MUST NOT trust the relay to send a
// benign value: a "../../config/x" name could clobber files. Allow only
// [A-Za-z0-9 _-], 1..64 chars, no leading/trailing space.
var rePlaylistName = regexp.MustCompile(`^[A-Za-z0-9](?:[A-Za-z0-9 _-]{0,62}[A-Za-z0-9])?$`)

// mediaRoot is the canonical URL prefix every playlist item must live under.
// Items are served as /media/<file>; <file> is a single path component (no
// subdirectories on the Pi). We canonicalise and confirm the resolved path
// stays strictly under this root.
const mediaRoot = "/media/"

// validateMediaURL URL-decodes, cleans/canonicalises, and confirms a relay-
// supplied item url resolves to a real file UNDER /media/ with no traversal.
// Returns the cleaned, safe url or ("", false).
func validateMediaURL(raw string) (string, bool) {
	if raw == "" {
		return "", false
	}
	// Reject absolute/scheme URLs and protocol-relative ("//host/..").
	if u, err := url.Parse(raw); err != nil || u.Scheme != "" || u.Host != "" || u.Opaque != "" {
		return "", false
	}
	if strings.HasPrefix(raw, "//") {
		return "", false
	}
	// URL-decode (defeats %2e%2e / %2f encoded traversal) then re-check for any
	// residual encoded byte — after one decode there must be no '%' left that
	// could hide a second-order traversal.
	dec, err := url.PathUnescape(raw)
	if err != nil || strings.Contains(dec, "%") {
		return "", false
	}
	// Reject NUL and backslash tricks outright.
	if strings.ContainsAny(dec, "\x00\\") {
		return "", false
	}
	if !strings.HasPrefix(dec, mediaRoot) {
		return "", false
	}
	// On the Pi, media lives directly under /media/ as a SINGLE path component
	// (no subdirectories). Require exactly that BEFORE any cleaning so we never
	// silently accept syntax that traversed through subdirectories (e.g.
	// "/media/a/../b"): the relative portion must contain no '/' at all.
	rel := strings.TrimPrefix(dec, mediaRoot)
	if rel == "" || strings.Contains(rel, "/") {
		return "", false
	}
	// Canonicalise and confirm the result is still exactly /media/<rel> with no
	// dot-only names slipping through.
	clean := path.Clean(dec)
	if clean != mediaRoot+rel {
		return "", false
	}
	if rel == "." || rel == ".." {
		return "", false
	}
	return clean, true
}

// 1) push-playlist -> POST /api/playlists.php (metadata only; media must already exist under /media/).
func (e *executor) pushPlaylist(env commandEnvelope) resultEnvelope {
	var args struct {
		Name     string           `json:"name"`
		Autoplay *bool            `json:"autoplay"`
		AutoLoop *bool            `json:"autoLoop"`
		Items    []map[string]any `json:"items"`
	}
	if err := json.Unmarshal(env.Args, &args); err != nil || args.Name == "" {
		return errResult(env.CmdID, env.Type, "rejected", "bad_request")
	}
	// Constrain the playlist name so the relay cannot overwrite arbitrary files.
	if !rePlaylistName.MatchString(args.Name) {
		return errResult(env.CmdID, env.Type, "rejected", "invalid_name")
	}
	// Guard: every item url must canonicalise to a real file under /media/ with
	// no traversal (encoded or otherwise), no scheme, no absolute escape.
	for i, it := range args.Items {
		urlv, _ := it["url"].(string)
		safe, ok := validateMediaURL(urlv)
		if !ok {
			return errResult(env.CmdID, env.Type, "rejected", "invalid_media_url")
		}
		// Replace with the canonicalised value so the PHP side stores the clean path.
		args.Items[i]["url"] = safe
	}
	body := map[string]any{"name": args.Name, "items": args.Items}
	if args.Autoplay != nil {
		body["autoplay"] = *args.Autoplay
	}
	if args.AutoLoop != nil {
		body["autoLoop"] = *args.AutoLoop
	}
	pr, err := e.api.savePlaylist(body)
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", mapLoopErr(err))
	}
	return okResult(env.CmdID, env.Type, "applied", json.RawMessage(pr.Data))
}

// 2) switch -> POST /api/playlists.php?action=activate&name=...
func (e *executor) switchPlaylist(env commandEnvelope) resultEnvelope {
	var args struct {
		Name string `json:"name"`
		Slug string `json:"slug"`
	}
	_ = json.Unmarshal(env.Args, &args)
	name := args.Name
	if name == "" {
		name = args.Slug // activate accepts a name; slug round-trips through slugify server-side.
	}
	if name == "" {
		return errResult(env.CmdID, env.Type, "rejected", "bad_request")
	}
	// Constrain the relay-supplied name/slug to a safe charset (no traversal).
	if !rePlaylistName.MatchString(name) {
		return errResult(env.CmdID, env.Type, "rejected", "invalid_name")
	}
	pr, err := e.api.activatePlaylist(name)
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", mapLoopErr(err))
	}
	return okResult(env.CmdID, env.Type, "applied", json.RawMessage(pr.Data))
}

// 3) reload/play/pause/next/prev -> POST /api/display.php?action=command
func (e *executor) transport(env commandEnvelope) resultEnvelope {
	pr, err := e.api.displayCommand(env.Type)
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", mapLoopErr(err))
	}
	return okResult(env.CmdID, env.Type, "applied", json.RawMessage(pr.Data))
}

// 4) screenshot -> run grim-capture.sh directly (agent is pi; no sudo/HTTP).
func (e *executor) screenshot(env commandEnvelope) resultEnvelope {
	script := getenvDefault("ZF_GRIM_CAPTURE", "/opt/pisignage/scripts/grim-capture.sh")
	out, err := exec.Command("/bin/sh", script).Output()
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", "capture_failed")
	}
	path := strings.TrimSpace(string(out))
	fi, statErr := os.Stat(path)
	if statErr != nil {
		return errResult(env.CmdID, env.Type, "error", "capture_failed")
	}
	sum, _ := sha256File(path)
	detail := map[string]any{"path": path, "bytes": fi.Size(), "sha256": sum}
	if e.onEvent != nil {
		ev := map[string]any{"type": "screenshot-ready", "path": path, "bytes": fi.Size(), "sha256": sum}
		e.onEvent("screenshot-ready", ev)
	}
	return okResult(env.CmdID, env.Type, "applied", detail)
}

// 5) get-stats -> GET /api/stats.php ; mirror the heartbeat 'system' object.
func (e *executor) getStats(env commandEnvelope) resultEnvelope {
	st, err := e.api.stats()
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", mapLoopErr(err))
	}
	return okResult(env.CmdID, env.Type, "applied", map[string]any{"system": mapSystem(st)})
}

// ---- remote-control handlers --------------------------------------------------

// simpleRead calls a no-arg bridge endpoint and returns its data verbatim as the
// result detail (used for the read/list and the idempotent toggle commands).
func (e *executor) simpleRead(env commandEnvelope, fn func() (*piResponse, error)) resultEnvelope {
	pr, err := fn()
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", mapLoopErr(err))
	}
	return okResult(env.CmdID, env.Type, "applied", json.RawMessage(pr.Data))
}

// safeMediaFilename: a SINGLE path component, no traversal/NUL/separators, not a
// dot-name. Defence-in-depth (PHP also basename()s + confirms under /media/).
var reUnsafeFilename = regexp.MustCompile(`[/\\\x00]`)

func safeMediaFilename(name string) bool {
	if name == "" || len(name) > 255 {
		return false
	}
	if name == "." || name == ".." || strings.HasPrefix(name, ".") || strings.Contains(name, "..") {
		return false
	}
	return !reUnsafeFilename.MatchString(name)
}

// isYouTubeHost: the parsed URL host must be a real YouTube domain (exact match or
// a subdomain of youtube.com / youtube-nocookie.com). Anti-SSRF for download-media.
var ytHosts = map[string]struct{}{
	"youtube.com": {}, "www.youtube.com": {}, "m.youtube.com": {}, "music.youtube.com": {},
	"youtu.be": {}, "youtube-nocookie.com": {}, "www.youtube-nocookie.com": {},
}

func isYouTubeHost(host string) bool {
	h := strings.ToLower(host)
	if _, ok := ytHosts[h]; ok {
		return true
	}
	return strings.HasSuffix(h, ".youtube.com") || strings.HasSuffix(h, ".youtube-nocookie.com")
}

func (e *executor) getPlaylistCmd(env commandEnvelope) resultEnvelope {
	var args struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(env.Args, &args); err != nil || !rePlaylistName.MatchString(args.Name) {
		return errResult(env.CmdID, env.Type, "rejected", "invalid_name")
	}
	pr, err := e.api.getPlaylist(args.Name)
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", mapLoopErr(err))
	}
	return okResult(env.CmdID, env.Type, "applied", json.RawMessage(pr.Data))
}

func (e *executor) deletePlaylistCmd(env commandEnvelope) resultEnvelope {
	var args struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(env.Args, &args); err != nil || !rePlaylistName.MatchString(args.Name) {
		return errResult(env.CmdID, env.Type, "rejected", "invalid_name")
	}
	pr, err := e.api.deletePlaylist(args.Name)
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", mapLoopErr(err))
	}
	return okResult(env.CmdID, env.Type, "applied", json.RawMessage(pr.Data))
}

func (e *executor) deleteMediaCmd(env commandEnvelope) resultEnvelope {
	var args struct {
		Filename string `json:"filename"`
	}
	if err := json.Unmarshal(env.Args, &args); err != nil || !safeMediaFilename(args.Filename) {
		return errResult(env.CmdID, env.Type, "rejected", "invalid_filename")
	}
	pr, err := e.api.deleteMedia(args.Filename)
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", mapLoopErr(err))
	}
	return okResult(env.CmdID, env.Type, "applied", json.RawMessage(pr.Data))
}

func (e *executor) playMediaCmd(env commandEnvelope) resultEnvelope {
	var args struct {
		File string `json:"file"`
	}
	if err := json.Unmarshal(env.Args, &args); err != nil || !safeMediaFilename(args.File) {
		return errResult(env.CmdID, env.Type, "rejected", "invalid_filename")
	}
	pr, err := e.api.playMedia(args.File)
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", mapLoopErr(err))
	}
	return okResult(env.CmdID, env.Type, "applied", json.RawMessage(pr.Data))
}

func (e *executor) downloadMediaCmd(env commandEnvelope) resultEnvelope {
	var args struct {
		URL       string `json:"url"`
		Quality   string `json:"quality"`
		Format    string `json:"format"`
		AudioOnly bool   `json:"audio_only"`
	}
	if err := json.Unmarshal(env.Args, &args); err != nil || args.URL == "" {
		return errResult(env.CmdID, env.Type, "rejected", "bad_request")
	}
	// SECURITY (anti-SSRF): the agent does NOT delegate URL trust to the PHP layer.
	// The Pi sits on the WireGuard tunnel, so an open fetch would reach the relay,
	// other peers, LAN admin panels and cloud-metadata (169.254.169.254). Require
	// http(s), reject userinfo (the youtube.com@evil-host trick), and require the
	// REAL parsed host to be a YouTube domain (defeats the subdomain trick too).
	u, perr := url.Parse(args.URL)
	if perr != nil || (u.Scheme != "http" && u.Scheme != "https") || u.User != nil {
		return errResult(env.CmdID, env.Type, "rejected", "invalid_url")
	}
	if !isYouTubeHost(u.Hostname()) {
		return errResult(env.CmdID, env.Type, "rejected", "not_youtube")
	}
	body := map[string]any{"url": args.URL}
	if args.Quality != "" {
		body["quality"] = args.Quality
	}
	if args.Format != "" {
		body["format"] = args.Format
	}
	if args.AudioOnly {
		body["audio_only"] = true
	}
	pr, err := e.api.downloadYouTube(body)
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", mapLoopErr(err))
	}
	return okResult(env.CmdID, env.Type, "applied", json.RawMessage(pr.Data))
}

// ---- volume via DIRECT amixer (agent runs as pi, in the audio group) ----
// system.php is deny-all'd at nginx (it carries reboot/shutdown), and HDMI cards
// expose no mixer. We talk to ALSA directly: auto-detect the first card with a
// usable simple control (preferring PCM/Master/Headphone), then sget/sset it.

var (
	reAmixerPct  = regexp.MustCompile(`\[(\d+)%\]`)
	reAmixerOn   = regexp.MustCompile(`\[(on|off)\]`)
	reAmixerCtrl = regexp.MustCompile(`Simple mixer control '([^']+)'`)
)

func amixerBin() string { return getenvDefault("ZF_AMIXER", "/usr/bin/amixer") }

// alsaMixer returns (card, control) for the first ALSA card exposing a usable
// simple mixer control. HDMI cards have none, so this naturally lands on the
// analog/headphone card.
func alsaMixer() (string, string, bool) {
	prefer := []string{"PCM", "Master", "Headphone", "Speaker", "Digital", "Analogue", "Playback"}
	for c := 0; c <= 4; c++ {
		card := fmt.Sprintf("%d", c)
		out, err := exec.Command(amixerBin(), "-c", card, "scontrols").Output()
		if err != nil || len(out) == 0 {
			continue
		}
		s := string(out)
		for _, name := range prefer {
			if strings.Contains(s, "'"+name+"'") {
				return card, name, true
			}
		}
		if m := reAmixerCtrl.FindStringSubmatch(s); m != nil {
			return card, m[1], true
		}
	}
	return "", "", false
}

func parseAmixer(out string) (int, bool) {
	vol := -1
	if m := reAmixerPct.FindStringSubmatch(out); m != nil {
		fmt.Sscanf(m[1], "%d", &vol)
	}
	muted := false
	if m := reAmixerOn.FindStringSubmatch(out); m != nil {
		muted = m[1] == "off"
	}
	return vol, muted
}

func (e *executor) getVolumeCmd(env commandEnvelope) resultEnvelope {
	card, ctrl, ok := alsaMixer()
	if !ok {
		return errResult(env.CmdID, env.Type, "error", "no_mixer")
	}
	out, err := exec.Command(amixerBin(), "-c", card, "sget", ctrl).Output()
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", "amixer_failed")
	}
	vol, muted := parseAmixer(string(out))
	return okResult(env.CmdID, env.Type, "applied", map[string]any{"volume": vol, "muted": muted, "card": card, "control": ctrl})
}

func (e *executor) setVolumeCmd(env commandEnvelope) resultEnvelope {
	var args struct {
		Level *int `json:"level"`
	}
	if err := json.Unmarshal(env.Args, &args); err != nil || args.Level == nil {
		return errResult(env.CmdID, env.Type, "rejected", "bad_request")
	}
	lvl := *args.Level
	if lvl < 0 {
		lvl = 0
	}
	if lvl > 100 {
		lvl = 100
	}
	card, ctrl, ok := alsaMixer()
	if !ok {
		return errResult(env.CmdID, env.Type, "error", "no_mixer")
	}
	out, err := exec.Command(amixerBin(), "-c", card, "sset", ctrl, fmt.Sprintf("%d%%", lvl), "unmute").Output()
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", "amixer_failed")
	}
	vol, muted := parseAmixer(string(out))
	if vol < 0 {
		vol = lvl
	}
	return okResult(env.CmdID, env.Type, "applied", map[string]any{"volume": vol, "muted": muted, "card": card, "control": ctrl})
}

func (e *executor) toggleMuteCmd(env commandEnvelope) resultEnvelope {
	card, ctrl, ok := alsaMixer()
	if !ok {
		return errResult(env.CmdID, env.Type, "error", "no_mixer")
	}
	out, err := exec.Command(amixerBin(), "-c", card, "sset", ctrl, "toggle").Output()
	if err != nil {
		return errResult(env.CmdID, env.Type, "error", "amixer_failed")
	}
	vol, muted := parseAmixer(string(out))
	return okResult(env.CmdID, env.Type, "applied", map[string]any{"volume": vol, "muted": muted, "card": card, "control": ctrl})
}

//  6. reboot -> agent itself runs `sudo /sbin/reboot` (grant pre-exists in sudoers).
//     Publish success + graceful offline FIRST (via onReboot), then exec reboot.
func (e *executor) reboot(env commandEnvelope) resultEnvelope {
	var args struct {
		Confirm bool `json:"confirm"`
	}
	_ = json.Unmarshal(env.Args, &args)
	if !args.Confirm {
		return errResult(env.CmdID, env.Type, "rejected", "confirm_required")
	}
	res := okResult(env.CmdID, env.Type, "applied", map[string]any{"rebooting": true})
	if e.onReboot != nil {
		// onReboot publishes this result + retained status online:false, flushes, then triggers reboot.
		go e.onReboot()
	}
	return res
}

func mapLoopErr(err error) string {
	switch err.Error() {
	case "timeout", "loopback_5xx", "forbidden_endpoint", "bad_request":
		return err.Error()
	case "rejected":
		return "loopback_rejected"
	default:
		return "error"
	}
}

func sha256File(path string) (string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:]), nil
}

// doReboot performs the privileged reboot via the NARROW, fixed sudoers grant
// in install.sh (post-hardening):
//
//	pi ALL=(root) NOPASSWD: /sbin/shutdown, /sbin/reboot,
//	                        /bin/systemctl reboot, /bin/systemctl poweroff
//
// We use /sbin/reboot (a fixed path). There is NO bare /bin/systemctl grant, so
// nothing here may shell out to an arbitrary systemctl subcommand. A player
// restart is NOT done here: it routes through the local display API.
func doReboot() error {
	if err := exec.Command("sudo", "-n", "/sbin/reboot").Run(); err != nil {
		return fmt.Errorf("reboot: %w", err)
	}
	return nil
}
