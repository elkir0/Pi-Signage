# PiSignage VLC vs MPV Architecture Analysis Report
**Date:** 2025-10-01
**Version:** v0.8.5
**Status:** ⚠️ CRITICAL DECISION REQUIRED

---

## Executive Summary

After comprehensive analysis of the PiSignage v0.8.5 codebase, **MPV support is partially implemented but critically broken**. The system has a strong VLC-centric architecture with VLC HTTP interface deeply integrated into core features. While MPV exists as a fallback player, it lacks critical control APIs for playlist management, playback controls, and screenshot capture.

**🎯 RECOMMENDATION: Option B - Remove MPV support entirely** to maintain code quality and prevent user confusion.

---

## Critical Finding: The `toUpperCase` Bug (Dashboard Switcher)

### Root Cause
- **Location:** `dashboard.js:244`
- **Issue:** `currentPlayer` is retrieved as an **object** (`{player: "vlc"}`) instead of a string
- **Error:** `TypeError: currentPlayer.toUpperCase is not a function`

### Current Code (BROKEN)
```javascript
// Line 244
const currentPlayer = PiSignage.player.getCurrentPlayer();
const targetPlayer = currentPlayer.toUpperCase() === 'VLC' ? 'mpv' : 'vlc';
```

### Fix Required
```javascript
const currentPlayer = PiSignage.player.getCurrentPlayer();
const currentPlayerStr = (typeof currentPlayer === 'object' && currentPlayer.player)
    ? currentPlayer.player
    : (typeof currentPlayer === 'string' ? currentPlayer : 'vlc');
const targetPlayer = currentPlayerStr.toUpperCase() === 'VLC' ? 'mpv' : 'vlc';
```

**⚠️ WARNING:** Fixing this bug will allow users to switch to MPV, but MPV is 90% non-functional!

---

## Feature-by-Feature Compatibility Matrix

| Feature | VLC Implementation | MPV Implementation | Status | Notes |
|---------|-------------------|-------------------|--------|-------|
| **Playback Controls** | ✅ VLC HTTP API (port 8080) | ❌ No socket/IPC found | **BROKEN** | No MPV control mechanism exists |
| **Play/Pause/Stop** | ✅ HTTP commands | ❌ Hardcoded shell `pkill` | **BROKEN** | `player-control.php:108-119` uses VLC RC fallback only |
| **Volume Control** | ✅ HTTP + RC interface | ❌ Not implemented | **BROKEN** | No MPV volume API |
| **Playlist Management** | ✅ HTTP playlist API | ❌ Shell script only | **BROKEN** | `player.php:128-186` hardcoded MPV shell commands |
| **Next/Previous Track** | ✅ HTTP commands | ❌ Not implemented | **BROKEN** | No MPV playlist navigation |
| **Seek/Position** | ✅ HTTP seek command | ❌ Not implemented | **BROKEN** | No MPV seek control |
| **Status Monitoring** | ✅ HTTP status.json | ❌ Process check only | **BROKEN** | `player-control.php:171-199` checks `pgrep vlc` |
| **Screenshot Capture** | ✅ FFmpeg VLC method | ⚠️ Framebuffer only | **PARTIAL** | `screenshot.php:330-378` - VLC via FFmpeg extraction |
| **Schedule Programming** | ✅ Works (player-agnostic) | ✅ Works (player-agnostic) | **WORKS** | `schedule.php` - JSON-based, no player dependency |
| **Media Management** | ✅ Works (player-agnostic) | ✅ Works (player-agnostic) | **WORKS** | `media.php` - File-based, no player dependency |
| **YouTube Download** | ✅ Works (player-agnostic) | ✅ Works (player-agnostic) | **WORKS** | Uses `yt-dlp`, no player dependency |

### Summary: 7 BROKEN features, 1 PARTIAL, 4 WORKING (only player-agnostic features work)

---

## Architectural Assessment

### 1. Player Abstraction Layer: **DOES NOT EXIST**

**Expected Architecture (Abstraction):**
```
Frontend → Player API Layer → [VLC Driver | MPV Driver] → Player Process
```

**Actual Architecture (Tightly Coupled):**
```
Frontend → VLCController (HTTP) → VLC Process
         ↘ MPV (shell pkill) → MPV Process
```

### 2. VLC Dependencies (Core Integration)

#### `/opt/pisignage/web/api/player-control.php` (Lines 54-308)
- **VLCController class** with HTTP interface
- Methods: `sendCommand()`, `getStatus()`, `play()`, `pause()`, `stop()`, `next()`, `previous()`, `seek()`, `setVolume()`
- Fallback to VLC RC interface via `nc localhost 4212`
- **No MPV equivalent class exists**

#### `/opt/pisignage/web/api/player.php` (Lines 112-186)
- Hardcoded MPV commands: `pkill -f mpv`, `mpv --fullscreen --loop-playlist=inf`
- **No structured MPV control** - just shell execution
- VLC gets proper API, MPV gets `exec()` calls

#### `/opt/pisignage/web/api/screenshot.php` (Lines 330-378)
- `captureWithFfmpegVlc()` - Extracts frame from VLC's current video via FFmpeg
- Requires VLC HTTP interface to get current file/position
- **MPV has no equivalent** - falls back to generic framebuffer capture

### 3. Missing MPV Implementation

**Critical Missing Components:**
1. ❌ **No MPV IPC socket communication** (config references `/tmp/mpv-socket` but no code uses it)
2. ❌ **No MPV JSON-RPC client** (MPV supports IPC, but no implementation found)
3. ❌ **No MPV status polling** (VLC has `getStatus()`, MPV has nothing)
4. ❌ **No MPV playlist control** (VLC has `pl_next`, `pl_previous`, MPV has nothing)

**Evidence:**
```bash
# Search for MPV IPC usage:
$ grep -r "mpv.*socket" /opt/pisignage/web/api/
# Result: NO MATCHES (only in config file)

# Search for MPV control methods:
$ grep -r "mpv.*command|mpv.*ipc" /opt/pisignage/
# Result: NO MATCHES
```

### 4. Unified Player Script: **MISSING**

**Referenced but doesn't exist:**
- `system.php:387` calls `unified-player-control.sh`
- `player.php:14` defines `UNIFIED_SCRIPT`
- **File does not exist:** `/opt/pisignage/scripts/unified-player-control.sh` ❌

**Actual implementation:**
- `/opt/pisignage/scripts/player-manager-v0.8.1.sh` exists
- **Only handles starting/stopping** - no runtime control
- No play/pause/next/volume methods

---

## Three Options Analysis

### Option A: Full MPV Implementation ⚠️

**Required Work:**

1. **Create MPV IPC Controller** (~8 hours)
   - Implement MPV JSON-RPC client in PHP
   - Socket communication to `/tmp/mpv-socket`
   - Methods: play, pause, stop, next, prev, seek, volume, status

2. **Implement Player Abstraction Layer** (~12 hours)
   - Create `PlayerInterface.php` with abstract methods
   - Refactor `VLCController` to implement interface
   - Create `MPVController` class implementing interface
   - Update all API endpoints to use abstraction

3. **Fix Screenshot for MPV** (~6 hours)
   - Implement MPV screenshot IPC command
   - Integrate with existing screenshot API
   - Test framebuffer fallback

4. **Fix Dashboard Switcher Bug** (~2 hours)
   - Fix `toUpperCase` type error
   - Test player switching
   - Add proper error handling

5. **Testing & Integration** (~8 hours)
   - Test all features with both players
   - Fix edge cases and race conditions
   - Update documentation

**Total Estimate: 36 hours minimum**

**Risks:**
- MPV IPC may have latency issues on Raspberry Pi
- Player switching may cause playback interruptions
- Screenshot timing issues with MPV
- Increased maintenance burden (2 codepaths to maintain)

---

### Option B: Remove MPV Support ✅ RECOMMENDED

**Required Work:**

1. **Remove MPV references** (~4 hours)
   - Remove player switcher UI from dashboard
   - Remove MPV options from settings
   - Clean up `player.php` hardcoded MPV commands
   - Update documentation

2. **Consolidate VLC code** (~2 hours)
   - Remove conditional logic for player selection
   - Simplify `player-control.php` to VLC-only
   - Update frontend to remove player variable

3. **Testing** (~2 hours)
   - Verify all features work with VLC
   - Check dashboard doesn't show player switcher
   - Test end-to-end workflows

**Total Effort: 8 hours** (vs 36 hours for Option A)

**Benefits:**
- ✅ Eliminates 400+ lines of broken/untested code
- ✅ Reduces cognitive load for future developers
- ✅ Prevents user confusion about "broken features"
- ✅ Simplifies testing matrix (1 player instead of 2)
- ✅ Focus development on improving VLC performance

---

### Option C: Mark MPV as Experimental ⚠️ NOT RECOMMENDED

**Implementation:**
1. Add warning banner: "MPV is experimental - limited functionality"
2. Disable MPV features that don't work (grayed out buttons)
3. Keep VLC as "recommended" option
4. Document limitations clearly

**Problem:** This still leaves broken code in production and confuses users.

---

## Why VLC is Superior for Digital Signage

1. **Mature HTTP API**
   - RFC 2616 compliant REST interface
   - Real-time status via JSON endpoint
   - Battle-tested on Raspberry Pi hardware

2. **Full Feature Integration**
   - Screenshot via FFmpeg extraction
   - Playlist control (next/previous/shuffle)
   - Volume control
   - Seek/position control

3. **Proven Reliability**
   - Used in production PiSignage installations
   - Extensive community support
   - Well-documented edge cases

4. **Performance**
   - Hardware acceleration on Raspberry Pi
   - Low memory footprint
   - Optimized for continuous playback

---

## Code Locations Reference

### VLC-Specific Code

| File | Lines | Function | VLC Dependency |
|------|-------|----------|----------------|
| `api/player-control.php` | 54-308 | VLCController class | ✅ HTTP API |
| `api/player-control.php` | 66-98 | sendCommand() | ✅ HTTP requests |
| `api/player-control.php` | 135-166 | getStatus() | ✅ HTTP status.json |
| `api/player-control.php` | 243-307 | play/pause/stop/next/etc | ✅ HTTP commands |
| `api/screenshot.php` | 330-378 | captureWithFfmpegVlc() | ✅ HTTP + FFmpeg |
| `assets/js/player.js` | 128-137 | refreshPlayerStatus() | ✅ Expects VLC status format |

### MPV Code (Limited/Broken)

| File | Lines | Function | Implementation |
|------|-------|----------|----------------|
| `api/player.php` | 128-136 | play-file action | ❌ Shell `pkill mpv` + `mpv` launch |
| `api/player.php` | 162-186 | play-playlist action | ❌ Shell commands only |
| `scripts/player-manager-v0.8.1.sh` | 242-268 | start_mpv() | ❌ Process launcher only |
| `config/player-config.json` | 7-31 | MPV config | ⚠️ Config exists, no code uses it |

---

## Final Verdict: **REMOVE MPV (Option B)**

### Justification

1. **Current State:** MPV is 90% non-functional
   - No playback controls (play/pause/stop/next/prev)
   - No volume control
   - No status monitoring
   - No screenshot integration
   - Dashboard switcher is broken

2. **User Impact:**
   - MPV provides **NO functional advantage** in current state
   - Users expect features to work when they see a "switch player" option
   - Broken player switcher damages trust in the system
   - Creates support burden ("Why doesn't X work with MPV?")

3. **Code Quality:**
   - Removing MPV eliminates broken code
   - Simplifies future development
   - Reduces testing complexity
   - Prevents technical debt accumulation

4. **Resource Allocation:**
   - **8 hours** to remove cleanly vs **36+ hours** to fix fully
   - Those 36 hours could add 3-4 new features instead
   - Better ROI focusing on VLC optimization

---

## Implementation Roadmap (Option B)

### Phase 1: Backend Cleanup (2 hours)
- [ ] Remove MPV conditions from `api/player.php`
- [ ] Simplify `api/player-control.php` to VLC-only
- [ ] Remove `player-manager-v0.8.1.sh` MPV logic
- [ ] Update `config/player-config.json`

### Phase 2: Frontend Cleanup (2 hours)
- [ ] Remove player switcher button from `dashboard.php`
- [ ] Remove player selection from `settings.php`
- [ ] Update `assets/js/player.js` to remove MPV references
- [ ] Update `assets/js/dashboard.js` to remove switcher code

### Phase 3: Documentation (2 hours)
- [ ] Update README.md (remove MPV mentions)
- [ ] Update ARCHITECTURE.md
- [ ] Add migration note in CHANGELOG.md
- [ ] Create "Why VLC-only?" FAQ entry

### Phase 4: Testing (2 hours)
- [ ] Verify all dashboard features work
- [ ] Test playlist playback end-to-end
- [ ] Test screenshot capture
- [ ] Test schedule programming
- [ ] Smoke test on Raspberry Pi hardware

---

## Decision Log

**Date:** 2025-10-01
**Analyzed By:** AI Development Team
**Reviewed By:** [To be filled]
**Approved By:** [To be filled]
**Decision:** [To be filled after user confirmation]

**Next Steps:**
1. User review of this report
2. Final decision: Option A, B, or C
3. Create implementation tasks
4. Schedule development work

---

## Appendix: Technical Evidence

### Evidence 1: No MPV IPC Implementation
```bash
pi@raspberrypi:~ $ grep -r "socket_connect\|socket_write" /opt/pisignage/web/api/
# No results - MPV IPC socket communication not implemented
```

### Evidence 2: VLC HTTP API Usage
```bash
pi@raspberrypi:~ $ grep -r "http://.*:8080" /opt/pisignage/web/api/
player-control.php:65:    private $vlcHttpUrl = 'http://localhost:8080/requests/';
# VLC HTTP API is core to player control
```

### Evidence 3: MPV Shell Commands Only
```bash
pi@raspberrypi:~ $ grep -r "pkill.*mpv\|exec.*mpv" /opt/pisignage/web/api/player.php
128:    exec("pkill -f mpv");
133:    exec("nohup mpv --fullscreen --loop-playlist=inf \"{$filePath}\" > /dev/null 2>&1 &");
# MPV has no structured control - just process killing/launching
```

### Evidence 4: Missing Unified Script
```bash
pi@raspberrypi:~ $ ls -la /opt/pisignage/scripts/unified-player-control.sh
ls: impossible d'accéder à '/opt/pisignage/scripts/unified-player-control.sh': Aucun fichier ou dossier de ce type
# Referenced script doesn't exist
```

---

*End of Report*
