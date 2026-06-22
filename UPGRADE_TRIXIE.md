# Pi-Signage Upgrade to Trixie (Debian 13) - Wayland Kiosk Mode

**Version:** 1.1 (aligned with PiSignage v0.12)
**Target OS:** Raspberry Pi OS Trixie (Debian 13)
**Target Hardware:** Raspberry Pi 4 / Pi 5
**Display Stack:** Wayland + labwc + Chromium kiosk (lightdm autologin)

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture](#architecture)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [API Usage](#api-usage)
7. [Testing & Validation](#testing--validation)
8. [Rollback](#rollback)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Configuration](#advanced-configuration)

---

## Overview

This guide covers **Chromium kiosk mode on Wayland** for Pi-Signage running on Raspberry Pi OS **Trixie (Debian 13)**. Since **v0.12 the only playback engine is the Chromium HTML5 player** (VLC removed). The stack provides:

- ✅ **Modern display server:** Wayland via `labwc` compositor
- ✅ **Single engine:** Chromium browser in full-screen kiosk mode serving `http://127.0.0.1/player`
- ✅ **Clean boot:** `lightdm` (autologin `pi`) + `plymouth` for seamless startup
- ✅ **Scriptable:** All configuration via files in `/opt/pisignage/config`
- ✅ **API-driven:** Remote control of kiosk URL, flags, and display restart

---

## Prerequisites

### Hardware
- **Raspberry Pi 4** (2GB+ RAM recommended) or **Raspberry Pi 5**
- HDMI display (1080p or 4K)
- Network connectivity (Ethernet or WiFi)
- MicroSD card (16GB+ recommended)

### Software
- **Raspberry Pi OS Trixie (Debian 13) - DESKTOP EDITION**
  - ⚠️ **IMPORTANT:** Desktop edition is REQUIRED (not Lite)
  - Lite edition lacks critical Wayland/graphics infrastructure
  - Download: https://www.raspberrypi.com/software/operating-systems/
  - Look for "Raspberry Pi OS with desktop" (64-bit recommended)
- Fresh installation or existing Pi-Signage v0.8.9+

### Verification

Check your OS version:
```bash
cat /etc/os-release
```

Expected output should include:
```
VERSION_CODENAME=trixie
VERSION_ID="13"
```

---

## Architecture

### Legacy Stack (Pre-Trixie, removed in v0.12)
```
┌────────────────────────────────────┐
│  X11 + VLC fullscreen              │
│  (xinit, xserver-xorg)             │
└────────────────────────────────────┘
```

### Trixie Stack (current)
```
┌──────────────────────────────────────────────────────────────┐
│  lightdm (autologin pi) → labwc (Wayland) → Chromium kiosk   │
│                                                               │
│  • lightdm: Auto-login & session manager                     │
│  • labwc: Lightweight Wayland compositor                     │
│  • Chromium: Kiosk browser (--kiosk http://127.0.0.1/player) │
│  • Player: HTML5 engine (web/player.php) — sole media player │
└──────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Role | Config File |
|-----------|------|-------------|
| **lightdm** | Auto-login (`pi`) & session init | `/etc/lightdm/lightdm.conf` |
| **labwc** | Wayland compositor | `~/.config/labwc/rc.xml` |
| **Chromium** | Kiosk browser | `/opt/pisignage/config/kiosk_url`<br>`/opt/pisignage/config/kiosk_flags` |
| **kiosk-apply** | Config generator | `/opt/pisignage/scripts/kiosk-apply` |
| **API** | Remote control | `/opt/pisignage/web/api/kiosk.php` |

---

## Installation

### Option 1: Fresh Installation (Recommended)

1. **Clone Pi-Signage** (feature branch):
```bash
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage
git checkout feature/trixie-kiosk-chromium
```

2. **Run installer**:
```bash
bash install.sh
```

The installer will:
- ✅ Detect Trixie (Debian 13)
- ✅ Install: `chromium-browser`, `labwc`, `lightdm`, `plymouth`
- ✅ Create kiosk configs in `/opt/pisignage/config/`
- ✅ Deploy labwc template to `~/.config/labwc/rc.xml`
- ✅ Generate initial `~/.config/labwc/autostart`

### Option 2: Upgrade Existing Installation

If you already have Pi-Signage v0.8.9:

```bash
cd /opt/pisignage
git fetch origin
git checkout feature/trixie-kiosk-chromium
git pull

# Re-run installer to add Trixie components
bash /path/to/Pi-Signage/install.sh
```

### Post-Installation

**Verify installation:**
```bash
dpkg -l | grep -E 'chromium-browser|labwc|lightdm'
ls -la /opt/pisignage/config/kiosk_*
cat ~/.config/labwc/autostart
```

---

## Configuration

### Default Files

After installation, these files are created:

| File | Purpose | Default Value |
|------|---------|---------------|
| `/opt/pisignage/config/kiosk_url` | Target URL | `http://127.0.0.1/player` |
| `/opt/pisignage/config/kiosk_flags` | Chromium flags | `--incognito --noerrdialogs --disable-translate --no-first-run` |
| `/opt/pisignage/config/feature_flags` | Enable/disable kiosk | `ENABLE_KIOSK=1` |

### Changing the Kiosk URL

**Method 1: Direct file edit**
```bash
echo "http://your-dashboard.local" | sudo tee /opt/pisignage/config/kiosk_url
bash /opt/pisignage/scripts/kiosk-apply
```

**Method 2: Via API** (see [API Usage](#api-usage))

### Customizing Chromium Flags

Edit flags file:
```bash
sudo nano /opt/pisignage/config/kiosk_flags
```

Recommended flags:
```
--incognito --noerrdialogs --disable-translate --no-first-run --disable-infobars --disable-session-crashed-bubble
```

Apply changes:
```bash
bash /opt/pisignage/scripts/kiosk-apply
```

### Disabling Kiosk Mode

Set feature flag to `0`:
```bash
echo "ENABLE_KIOSK=0" | sudo tee /opt/pisignage/config/feature_flags
```

Kiosk Chromium will not start on next boot (the system boots to a console / blank session). Re-enable with `ENABLE_KIOSK=1` and reboot.

---

## API Usage

The kiosk mode exposes REST endpoints for remote control.

### Base URL
```
http://<pi-ip>/api/kiosk.php
```

### Endpoints

#### 1. Get Kiosk Status
```bash
curl http://<pi-ip>/api/kiosk.php
```

**Response:**
```json
{
  "success": true,
  "data": {
    "enabled": true,
    "url": "http://127.0.0.1/player",
    "flags": "--incognito --noerrdialogs",
    "chromium_running": true,
    "autostart_exists": true
  }
}
```

#### 2. Get Current URL
```bash
curl http://<pi-ip>/api/kiosk.php/url
```

#### 3. Update URL
```bash
curl -X PUT http://<pi-ip>/api/kiosk.php/url \
  -H "Content-Type: application/json" \
  -d '{"url":"https://grafana.local/dashboard"}'
```

#### 4. Get Chromium Flags
```bash
curl http://<pi-ip>/api/kiosk.php/flags
```

#### 5. Update Flags
```bash
curl -X PUT http://<pi-ip>/api/kiosk.php/flags \
  -H "Content-Type: application/json" \
  -d '{"flags":"--incognito --disable-infobars"}'
```

#### 6. Restart Chromium
```bash
curl -X POST http://<pi-ip>/api/kiosk.php/restart
```

**Note:** Chromium restart requires a session restart for immediate effect — restart the display manager: `sudo systemctl restart display-manager` (alias for `lightdm`).

#### 7. Reload the playlist live (no restart)

To reload the on-screen content without restarting the browser, signal the player engine via the display control API:
```bash
curl -X POST "http://<pi-ip>/api/display.php?action=command" \
  -H "Content-Type: application/json" \
  -d '{"cmd":"reload"}'
```
The player polls `GET /api/display.php?action=command` every 2s and the active-playlist version every 10s, so changes propagate on their own.

---

## Testing & Validation

### Run Automated Tests

**Smoke tests** (local, no RPi required):
```bash
cd /path/to/Pi-Signage
bash scripts/tests/smoke.sh
```

**API tests** (requires running server):
```bash
# On RPi or with nginx running:
bash scripts/tests/api.sh
```

### Validation Matrix

| Test | Command | Expected Result |
|------|---------|----------------|
| **1. Boot to lightdm** | `systemctl status lightdm` | Active (running) |
| **2. labwc running** | `pgrep -a labwc` | Process found |
| **3. Chromium kiosk** | `pgrep -fa chromium.*kiosk` | Process found |
| **4. Network ready** | `ping -c1 8.8.8.8` | 0% packet loss |
| **5. Rotation (if needed)** | `wlr-randr` | Shows correct orientation |
| **6. 4K display** | `wlr-randr \| grep current` | Shows native resolution |
| **7. Idle disabled** | Check `~/.config/labwc/rc.xml` | Contains `<disable/>` |
| **8. Cursor hidden** | Visual check | Cursor not visible in kiosk |
| **9. CEC (optional)** | `echo 'on 0' \| cec-client -s` | TV powers on |
| **10. API reachable** | `curl http://localhost/api/kiosk.php` | JSON response |

### Manual Validation

1. **Reboot and observe:**
   ```bash
   sudo reboot
   ```

2. **Expected behavior:**
   - Plymouth splash screen (optional)
   - Auto-login (`pi`) via lightdm
   - labwc starts
   - Chromium opens fullscreen to `http://127.0.0.1/player`
   - No cursor visible
   - Screen does not blank/sleep

3. **Emergency access:**
   - Press `Ctrl+Alt+T` for terminal (if configured in `rc.xml`)
   - SSH from another machine: `ssh pi@<pi-ip>`

---

## Rollback

### Disable Kiosk (Keep Trixie)

```bash
echo "ENABLE_KIOSK=0" | sudo tee /opt/pisignage/config/feature_flags
sudo reboot
```

Chromium kiosk will not start. System boots to a console / blank session.

### Full Rollback to Previous Branch

```bash
cd /opt/pisignage
git checkout main  # or previous stable branch
bash install.sh    # Re-run installer
sudo reboot
```

### Uninstall Trixie Packages

```bash
sudo apt remove --purge chromium-browser labwc lightdm plymouth
sudo apt autoremove
sudo reboot
```

---

## Troubleshooting

### Chromium Not Starting

**Check autostart:**
```bash
cat ~/.config/labwc/autostart
```

**Re-generate:**
```bash
bash /opt/pisignage/scripts/kiosk-apply
```

**Check logs:**
```bash
journalctl --user -u labwc -n 50
```

### Black Screen / No Display

1. **Check labwc:**
   ```bash
   pgrep labwc || echo "labwc not running"
   ```

2. **Check Chromium:**
   ```bash
   pgrep -fa chromium
   ```

3. **Restart labwc session:**
   ```bash
   sudo systemctl restart display-manager   # lightdm
   ```

### Swapchain / Graphics Errors (Lite Edition)

**Symptoms:**
- lightdm service fails repeatedly with "start-limit-hit"
- labwc logs show: `Swapchain for output 'HDMI-A-1' failed test`
- Error: `Failed to create allocator` or `unable to create backend`

**Root Cause:**
You are running **Raspberry Pi OS Lite** which lacks critical Wayland/graphics infrastructure.

**Solution:**
⚠️ **Re-flash with Desktop edition:**

1. Download: https://www.raspberrypi.com/software/operating-systems/
2. Choose "Raspberry Pi OS with desktop" (64-bit recommended)
3. Flash to SD card using Raspberry Pi Imager
4. Boot and run install.sh again

**Diagnosis Commands:**
```bash
# Check for swapchain errors:
journalctl -u lightdm -n 100 | grep -i swapchain

# Verify OS edition:
dpkg -l | grep -E "task-desktop|task-gnome|task-lxde"

# If empty output = Lite edition (not supported)
```

### Network Timeout

`kiosk-apply` waits max 20s for network. If timeout occurs:

```bash
# Check network:
ip a

# Restart networking:
sudo systemctl restart NetworkManager

# Re-apply kiosk:
bash /opt/pisignage/scripts/kiosk-apply
```

### API Returns 404

**Verify nginx config:**
```bash
sudo nginx -t
sudo systemctl restart nginx
```

**Check PHP-FPM:**
```bash
sudo systemctl status php8.4-fpm
```

**Test API directly:**
```bash
curl http://localhost/api/kiosk.php
```

---

## Advanced Configuration

### Display Rotation

Using `wlr-randr` (Wayland equivalent of `xrandr`):

```bash
# Install wlr-randr:
sudo apt install wlr-randr

# Check outputs:
wlr-randr

# Rotate 90° (portrait):
wlr-randr --output HDMI-A-1 --transform 90

# Persist rotation in labwc autostart:
echo "wlr-randr --output HDMI-A-1 --transform 90" >> ~/.config/labwc/autostart
```

### 4K Display Optimization

Chromium flags for 4K:
```
--force-device-scale-factor=1.5 --high-dpi-support=1
```

Update:
```bash
echo "--incognito --noerrdialogs --force-device-scale-factor=1.5 --high-dpi-support=1" | \
  sudo tee /opt/pisignage/config/kiosk_flags
bash /opt/pisignage/scripts/kiosk-apply
```

### CEC Control (HDMI-CEC)

**Install cec-utils:**
```bash
sudo apt install cec-utils
```

**Turn on TV on boot:**
Add to `~/.config/labwc/autostart`:
```bash
echo 'on 0' | cec-client -s
```

**Turn off TV on shutdown:**
Create systemd service or add to shutdown script.

### Custom labwc Keybindings

Edit `~/.config/labwc/rc.xml`:

```xml
<!-- Reload Chromium with F5 -->
<keybind key="F5">
  <action name="Execute">
    <command>/opt/pisignage/scripts/kiosk-apply</command>
  </action>
</keybind>

<!-- Emergency exit: Ctrl+Alt+Q -->
<keybind key="C-A-q">
  <action name="Execute">
    <command>pkill chromium</command>
  </action>
</keybind>
```

### Multi-Monitor Setup

**Detect outputs:**
```bash
wlr-randr
```

**Configure in autostart:**
```bash
# Enable second monitor to the right:
wlr-randr --output HDMI-A-1 --mode 1920x1080 --pos 0,0
wlr-randr --output HDMI-A-2 --mode 1920x1080 --pos 1920,0
```

---

## Chromium HTML5 Player

**Version:** 0.12.0+
**Feature:** Native HTML5 media playback in Chromium — the **sole** playback engine (VLC removed in v0.12)

### Overview

Since v0.12, Pi-Signage plays all media through the **Chromium HTML5 Player** (`web/player.php`, served at `http://127.0.0.1/player`). There is no VLC fallback. This provides:

- ✅ **HTML5 `<video>` playback** with hardware acceleration
- ✅ **Unified playlist management** via the `playlists.php` API
- ✅ **Live engine control** through the **Lecteur** (Player) page and `display.php`
- ✅ **Autoplay, loop, mute, fit, transition** configurable per item
- ✅ **Wake Lock API** to prevent screen sleep
- ✅ **Support for MP4, WebM, MKV** formats
- ✅ **Resilience:** splash, offline fallback, anti-flash preloading

### Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ lightdm → labwc → Chromium kiosk (http://127.0.0.1/player)    │
│                                                               │
│  Player Page (HTML5, web/player.php):                        │
│  • Reads /opt/pisignage/media/playlist.json                  │
│  • <video> element with autoplay/loop                        │
│  • Polls GET /api/display.php?action=command every 2s        │
│    (next|prev|play|pause|reload)                             │
│  • Polls active-playlist version every 10s (auto reload)     │
│  • Reports live state via POST /api/display.php?action=state │
│  • Auto-advance, error handling, retry, Wake Lock            │
│                                                               │
│  Backend APIs:                                               │
│  • playlists.php  - unified playlist CRUD + "Diffuser"        │
│  • display.php    - live engine control & state              │
│  • system.php     - ALSA system volume (set/get/toggle_mute) │
└──────────────────────────────────────────────────────────────┘
```

> Volume is the **system (ALSA)** volume via `system.php` (`set_volume`/`get_volume`/`toggle_mute`). There is no separate "VLC volume" anymore.

### Feature Flags

Control kiosk mode with `/opt/pisignage/config/feature_flags`:

```bash
# Enable Chromium kiosk mode (default: 1)
ENABLE_KIOSK=1
```

The `USE_CHROMIUM_PLAYER` / VLC-fallback flag from earlier versions is gone — Chromium HTML5 is the only engine.

**Apply changes:**
```bash
bash /opt/pisignage/scripts/kiosk-apply
sudo systemctl restart display-manager   # lightdm
```

### Playlists & On-Screen Content

Playlists are unified under one source of truth managed by `web/api/playlists.php`
(shared core: `web/api/playlists-core.php`):

- **Library:** `/opt/pisignage/playlists/<slug>.json`
- **Active-playlist pointer:** `/opt/pisignage/config/active-playlist.json`
- **On-screen render file (consumed by the player):** `/opt/pisignage/media/playlist.json`

Hitting "Diffuser à l'écran" (`POST /api/playlists.php?action=activate&name=X`) writes
`/opt/pisignage/media/playlist.json` and bumps its `version`; the player reloads on its own.

**Playlist schema:**
```json
{
  "name": "Lobby",
  "slug": "lobby",
  "version": 3,
  "autoplay": true,
  "autoLoop": true,
  "items": [
    {
      "url": "file:///opt/pisignage/media/video.mp4",
      "type": "video",
      "name": "video.mp4",
      "duration": 0,
      "fit": "contain",
      "mute": false,
      "loop": false,
      "transition": "fade"
    }
  ]
}
```

**Item fields:**
- `url`: File path (`file://`) or HTTP(S) URL
- `type`: `video`, `image`, etc.
- `name`: Display label
- `duration`: Seconds (0 = auto-detect from video)
- `fit`: `contain` (preserve aspect) or `cover` (fill screen)
- `mute`: Boolean, mute audio
- `loop`: Boolean, loop this item indefinitely
- `transition`: Transition effect (e.g. `fade`)
- `autoLoop`: Restart playlist when finished (playlist-level)
- `autoplay`: Start playing immediately on load (playlist-level)

### Web UI Pages (v0.12)

The interface is consolidated. Each concern lives on a single page:

1. **Playlists** (`playlists.php`) — compose playlists *and* "Diffuser à l'écran" in one place
   - Add/edit/delete/reorder items
   - Upload media files (max 500MB)
   - Activate (push) a playlist to the screen

2. **Lecteur** (Player, `player.php` UI / `display.php` API) — control the real engine
   - Play / Pause / Next / Prev / Reload
   - System (ALSA) volume + mute
   - Live player state

3. **Kiosk** (`kiosk.php`) — **display settings only**
   - Toggle Kiosk ON/OFF
   - Set kiosk URL & edit Chromium flags
   - Scheduled screen blanking
   - Restart Chromium / display session
   - (no playlist editor here — that lives on the Playlists page)

4. **Programmation** (Schedule) — real dayparting (see `scheduler.php`)

### API Endpoints

**Base:** `/api`

#### Playlists API (`/api/playlists.php`) — unified source of truth

```bash
# List playlists + active playlist
curl http://localhost/api/playlists.php

# Get one playlist
curl "http://localhost/api/playlists.php?name=lobby"

# Create / update a playlist
curl -X POST http://localhost/api/playlists.php \
  -H "Content-Type: application/json" \
  -d '{"name":"Lobby","items":[...],"autoplay":true,"autoLoop":true}'

# Activate ("Diffuser à l'écran") — writes media/playlist.json + bumps version
curl -X POST "http://localhost/api/playlists.php?action=activate&name=lobby"

# Delete a playlist
curl -X DELETE "http://localhost/api/playlists.php?name=lobby"
```

> **Deprecated endpoints** (return HTTP 410): `playlist-simple.php`, `player.php`, `player-control.php`.

#### Player control API (`/api/display.php`)

```bash
# Send a command to the engine (player polls every 2s)
curl -X POST "http://localhost/api/display.php?action=command" \
  -H "Content-Type: application/json" \
  -d '{"cmd":"next"}'    # next|prev|play|pause|reload

# Play a single media in isolation
curl -X POST "http://localhost/api/display.php?action=playmedia" \
  -H "Content-Type: application/json" \
  -d '{"file":"clip.mp4"}'

# Read current player state (admin)
curl "http://localhost/api/display.php?action=state"
```

#### System volume API (`/api/system.php`) — ALSA

```bash
curl "http://localhost/api/system.php?action=get_volume"
curl -X POST "http://localhost/api/system.php?action=set_volume" \
  -H "Content-Type: application/json" -d '{"volume":70}'
curl -X POST "http://localhost/api/system.php?action=toggle_mute"
```

#### Kiosk API (`/api/kiosk.php`)

```bash
# Get kiosk status
curl http://localhost/api/kiosk.php

# Enable/disable kiosk mode
curl -X PUT http://localhost/api/kiosk.php/enable \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}'

# Update kiosk URL / flags / restart Chromium
curl -X PUT http://localhost/api/kiosk.php/url \
  -H "Content-Type: application/json" -d '{"url":"http://127.0.0.1/player"}'
```

### Chromium Flags for Player

**Recommended flags** (automatically set by `kiosk-apply`):

```
--ozone-platform=wayland
--enable-features=VaapiVideoDecoder,UseOzonePlatform
--autoplay-policy=no-user-gesture-required
--disable-infobars
--noerrdialogs
--disable-translate
--no-first-run
--ignore-gpu-blocklist
--incognito
```

**Location:** `/opt/pisignage/config/kiosk_flags`

**Note:** Hardware acceleration (VaapiVideoDecoder) works on Pi 4/5 with Mesa drivers.

### Troubleshooting

#### Video not playing

**Check autoplay policy:**
- HTML5 video autoplay may require `mute: true` on first item
- Chromium flag `--autoplay-policy=no-user-gesture-required` should be set

**Check the active playlist:**
```bash
# What the player is currently rendering:
cat /opt/pisignage/media/playlist.json

# What the admin marked active:
cat /opt/pisignage/config/active-playlist.json
```

**Check player logs:**
```bash
# Open browser console (if accessible)
# Or check session/Chromium logs:
journalctl -u lightdm -n 100
```

#### Player shows blank screen

**Verify the on-screen playlist exists:**
```bash
cat /opt/pisignage/media/playlist.json
```

**Check Chromium is running:**
```bash
pgrep -f chromium
```

**Restart Chromium / session:**
```bash
curl -X POST http://localhost/api/kiosk.php/restart
# OR
sudo systemctl restart display-manager   # lightdm
```

#### Switching between Player and Dashboard mode

Kiosk always runs Chromium; the only difference is the URL it loads.

**Player mode** (default) — point the kiosk at the local HTML5 player:
```bash
echo "http://127.0.0.1/player" | sudo tee /opt/pisignage/config/kiosk_url
bash /opt/pisignage/scripts/kiosk-apply
sudo systemctl restart display-manager   # lightdm
```

**Dashboard mode** — show a custom URL instead:
```bash
echo "https://grafana.local" | sudo tee /opt/pisignage/config/kiosk_url
bash /opt/pisignage/scripts/kiosk-apply
sudo systemctl restart display-manager   # lightdm
```

### Supported Media Formats

| Format | Container | Video Codec | Audio Codec | Tested |
|--------|-----------|-------------|-------------|--------|
| **MP4** | MPEG-4 | H.264 | AAC | ✅ |
| **WebM** | WebM | VP8, VP9 | Vorbis, Opus | ✅ |
| **MKV** | Matroska | H.264, VP9 | AAC, Opus | ✅ |
| **MOV** | QuickTime | H.264 | AAC | ⚠️ May require conversion |

**Note:** Hardware acceleration requires H.264 baseline/main profile for best performance.

### Keyboard Shortcuts (Player Page)

- **Ctrl+D** - Toggle debug overlay
- **Ctrl+R** - Reload playlist
- **Ctrl+N** - Skip to next video

### Example Workflows

#### 1. Simple Video Loop

```json
{
  "version": 1,
  "items": [
    {
      "url": "file:///opt/pisignage/media/promo.mp4",
      "mute": false,
      "loop": true,
      "fit": "contain",
      "duration": 0
    }
  ],
  "autoLoop": false,
  "autoplay": true
}
```

#### 2. Multi-Video Rotation

```json
{
  "version": 1,
  "items": [
    {"url": "file:///opt/pisignage/media/video1.mp4", "duration": 30, "fit": "cover"},
    {"url": "file:///opt/pisignage/media/video2.mp4", "duration": 45, "fit": "cover"},
    {"url": "http://cdn.example.com/ad.mp4", "duration": 0, "mute": true}
  ],
  "autoLoop": true,
  "autoplay": true
}
```

#### 3. Mixed Local and Remote

```json
{
  "version": 1,
  "items": [
    {"url": "file:///opt/pisignage/media/local.mp4", "fit": "contain"},
    {"url": "https://cdn.example.com/stream.mp4", "fit": "contain", "mute": true}
  ],
  "autoLoop": true,
  "autoplay": true
}
```

### Performance Tips

1. **Use H.264 video** for hardware acceleration
2. **Keep resolution ≤ 1080p** for Pi 4, ≤ 4K for Pi 5
3. **Limit playlist size** to < 50 items for smooth operation
4. **Use local files** when possible (faster loading)
5. **Enable mute** for silent displays (better autoplay compatibility)

---

## Support & Resources

- **GitHub Issues:** https://github.com/elkir0/Pi-Signage/issues
- **Main README:** [README.md](README.md)
- **API Documentation:** [API_DOCUMENTATION.md](API_DOCUMENTATION.md)
- **Wayland on RPi:** https://wayland.freedesktop.org/
- **labwc Documentation:** https://labwc.github.io/

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.1 | 2026-06-21 | v0.12: greetd → lightdm autologin; VLC removed (Chromium HTML5 sole engine); unified `playlists.php`; live control via `display.php`; ALSA system volume via `system.php`; default kiosk URL `http://127.0.0.1/player` |
| 1.0 | 2025-11-09 | Initial Trixie/Wayland kiosk implementation |

---

**Happy Kiosk-ing! 🚀**
