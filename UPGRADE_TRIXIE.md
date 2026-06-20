# Pi-Signage Upgrade to Trixie (Debian 13) - Wayland Kiosk Mode

**Version:** 1.0
**Target OS:** Raspberry Pi OS Trixie (Debian 13)
**Target Hardware:** Raspberry Pi 4 / Pi 5
**Display Stack:** Wayland + labwc + Chromium kiosk

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

This upgrade adds **Chromium kiosk mode on Wayland** support for Pi-Signage running on Raspberry Pi OS **Trixie (Debian 13)**. The new stack provides:

- ✅ **Modern display server:** Wayland via `labwc` compositor
- ✅ **Stable kiosk:** Chromium browser in full-screen kiosk mode
- ✅ **Clean boot:** `greetd` + `plymouth` for seamless startup
- ✅ **Scriptable:** All configuration via files in `/opt/pisignage/config`
- ✅ **API-driven:** Remote control of kiosk URL, flags, and restart
- ✅ **Backward compatible:** Existing VLC player and API remain functional

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

### Traditional Stack (Pre-Trixie)
```
┌────────────────────────────────────┐
│  X11 + VLC fullscreen              │
│  (xinit, xserver-xorg)             │
└────────────────────────────────────┘
```

### Trixie Stack (New)
```
┌──────────────────────────────────────────────────────────────┐
│  greetd (init) → labwc (Wayland) → Chromium kiosk            │
│                                                               │
│  • greetd: Auto-login and session manager                    │
│  • labwc: Lightweight Wayland compositor                     │
│  • Chromium: Kiosk browser (configurable URL + flags)        │
│  • VLC: Still available for media playback                   │
└──────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Role | Config File |
|-----------|------|-------------|
| **greetd** | Auto-login & session init | `/etc/greetd/config.toml` |
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
- ✅ Install: `chromium-browser`, `labwc`, `greetd`, `plymouth`
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
dpkg -l | grep -E 'chromium-browser|labwc|greetd'
ls -la /opt/pisignage/config/kiosk_*
cat ~/.config/labwc/autostart
```

---

## Configuration

### Default Files

After installation, these files are created:

| File | Purpose | Default Value |
|------|---------|---------------|
| `/opt/pisignage/config/kiosk_url` | Target URL | `https://time.is` |
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

### Disabling Kiosk Mode (Rollback to VLC)

Set feature flag to `0`:
```bash
echo "ENABLE_KIOSK=0" | sudo tee /opt/pisignage/config/feature_flags
```

Kiosk will not start on next boot. VLC player remains functional.

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
    "url": "https://time.is",
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

**Note:** Chromium restart requires user logout/login or labwc restart for immediate effect.

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
| **1. Boot to greetd** | `systemctl status greetd` | Active (running) |
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
   - Auto-login via greetd
   - labwc starts
   - Chromium opens fullscreen to configured URL
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

Chromium kiosk will not start. System boots to console or VLC player (if configured).

### Full Rollback to Previous Branch

```bash
cd /opt/pisignage
git checkout main  # or previous stable branch
bash install.sh    # Re-run installer
sudo reboot
```

### Uninstall Trixie Packages

```bash
sudo apt remove --purge chromium-browser labwc greetd plymouth
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
   sudo systemctl restart greetd
   ```

### Swapchain / Graphics Errors (Lite Edition)

**Symptoms:**
- greetd service fails repeatedly with "start-limit-hit"
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
journalctl -u greetd -n 100 | grep -i swapchain

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
sudo systemctl status php8.2-fpm
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

**Version:** 0.11.0+
**Feature:** Native HTML5 video playback in Chromium instead of VLC

### Overview

Pi-Signage now includes a **Chromium HTML5 Player** mode that replaces VLC for media playback. This provides:

- ✅ **HTML5 `<video>` playback** with hardware acceleration
- ✅ **Playlist management** via JSON configuration
- ✅ **Web-based control** through Kiosk Control UI
- ✅ **Autoplay, loop, mute** configurable per item
- ✅ **Wake Lock API** to prevent screen sleep
- ✅ **Support for MP4, WebM, MKV** formats

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│ greetd → labwc → Chromium kiosk (http://127.0.0.1/player) │
│                                                          │
│  Player Page (HTML5):                                   │
│  • Reads /opt/pisignage/content/playlist.json           │
│  • <video> element with autoplay/loop                   │
│  • Auto-advance, error handling, retry logic            │
│  • Wake Lock, cursor hiding                             │
│                                                          │
│  Backend APIs:                                          │
│  • GET /api/playlist - Fetch playlist                   │
│  • PUT /api/playlist - Update playlist                  │
│  • POST /api/playlist/validate - Check URLs             │
│  • POST /api/playlist/upload - Upload media             │
└─────────────────────────────────────────────────────────┘
```

### Feature Flags

Control player mode with `/opt/pisignage/config/feature_flags`:

```bash
# Enable Chromium kiosk mode (default: 1)
ENABLE_KIOSK=1

# Use Chromium HTML5 player (default: 1)
USE_CHROMIUM_PLAYER=1  # Chromium plays playlist
USE_CHROMIUM_PLAYER=0  # VLC fallback mode
```

**Apply changes:**
```bash
bash /opt/pisignage/scripts/kiosk-apply
sudo systemctl restart greetd
```

### Playlist Configuration

**Location:** `/opt/pisignage/content/playlist.json`

**Format:**
```json
{
  "version": 1,
  "items": [
    {
      "url": "file:///opt/pisignage/content/video.mp4",
      "mute": false,
      "loop": false,
      "fit": "contain",
      "duration": 0
    },
    {
      "url": "http://example.com/stream.mp4",
      "mute": true,
      "loop": false,
      "fit": "cover",
      "duration": 30
    }
  ],
  "autoLoop": true,
  "autoplay": true
}
```

**Fields:**
- `url`: File path (`file://`) or HTTP(S) URL
- `mute`: Boolean, mute audio
- `loop`: Boolean, loop this item indefinitely
- `fit`: `contain` (preserve aspect) or `cover` (fill screen)
- `duration`: Seconds (0 = auto-detect from video)
- `autoLoop`: Restart playlist when finished
- `autoplay`: Start playing immediately on load

### Kiosk Control UI

**Access:** `http://<pi-ip>/kiosk.php`

**Features:**
1. **Mode Switching**
   - Toggle Kiosk ON/OFF
   - Switch between Chromium Player and VLC fallback

2. **Playlist Management**
   - Add/edit/delete items
   - Reorder with ↑↓ buttons
   - Upload media files (max 500MB)
   - Validate URLs accessibility

3. **Configuration**
   - Set kiosk URL (for dashboard mode)
   - Edit Chromium flags
   - Auto-refresh status (5s interval)

4. **Actions**
   - Restart Chromium
   - Reload playlist
   - Preview player in new window

### API Endpoints

**Base:** `/api`

#### Playlist API (`/api/playlist`)

```bash
# Get current playlist
curl http://localhost/api/playlist

# Update playlist
curl -X PUT http://localhost/api/playlist \
  -H "Content-Type: application/json" \
  -d @playlist.json

# Validate playlist (checks URL accessibility)
curl -X POST http://localhost/api/playlist/validate \
  -H "Content-Type: application/json" \
  -d @playlist.json

# Signal player to reload
curl -X POST http://localhost/api/playlist/refresh

# Upload media file
curl -X POST http://localhost/api/playlist/upload \
  -F "file=@video.mp4"
```

#### Kiosk API (`/api/kiosk`)

```bash
# Get kiosk status (includes player mode)
curl http://localhost/api/kiosk

# Enable/disable kiosk mode
curl -X PUT http://localhost/api/kiosk/enable \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}'

# Switch player mode
curl -X PUT http://localhost/api/kiosk/mode \
  -H "Content-Type: application/json" \
  -d '{"useChromiumPlayer": true}'

# Health check
curl http://localhost/api/kiosk/health
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

**Check file accessibility:**
```bash
# Validate playlist URLs
curl -X POST http://localhost/api/playlist/validate \
  -H "Content-Type: application/json" \
  -d @/opt/pisignage/content/playlist.json
```

**Check player logs:**
```bash
# Open browser console (if accessible)
# Or check Chromium logs:
journalctl -u greetd -n 100
```

#### Player shows blank screen

**Verify playlist exists:**
```bash
cat /opt/pisignage/content/playlist.json
```

**Check Chromium is running:**
```bash
pgrep -f chromium
```

**Restart Chromium:**
```bash
curl -X POST http://localhost/api/kiosk/restart
# OR
sudo systemctl restart greetd
```

#### Switching between Player and Dashboard mode

**Player mode** (default):
```bash
# Edit feature flags
sudo nano /opt/pisignage/config/feature_flags

# Set:
USE_CHROMIUM_PLAYER=1

# Apply:
bash /opt/pisignage/scripts/kiosk-apply
sudo systemctl restart greetd
```

**Dashboard mode** (show custom URL):
```bash
# Edit feature flags
sudo nano /opt/pisignage/config/feature_flags

# Set:
USE_CHROMIUM_PLAYER=0

# Set custom URL:
echo "https://grafana.local" | sudo tee /opt/pisignage/config/kiosk_url

# Apply:
bash /opt/pisignage/scripts/kiosk-apply
sudo systemctl restart greetd
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
      "url": "file:///opt/pisignage/content/promo.mp4",
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
    {"url": "file:///opt/pisignage/content/video1.mp4", "duration": 30, "fit": "cover"},
    {"url": "file:///opt/pisignage/content/video2.mp4", "duration": 45, "fit": "cover"},
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
    {"url": "file:///opt/pisignage/content/local.mp4", "fit": "contain"},
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
| 1.0 | 2025-11-09 | Initial Trixie/Wayland kiosk implementation |

---

**Happy Kiosk-ing! 🚀**
