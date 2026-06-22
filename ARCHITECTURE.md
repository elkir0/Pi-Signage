# PiSignage v0.12.0 Architecture

Complete system architecture documentation for PiSignage digital signage platform.

## Table of Contents

- [System Overview](#system-overview)
- [Technology Stack](#technology-stack)
- [Directory Structure](#directory-structure)
- [Component Architecture](#component-architecture)
- [Playback Pipeline](#playback-pipeline)
- [Data Flow](#data-flow)
- [Security Architecture](#security-architecture)
- [Deployment Architecture](#deployment-architecture)

---

## System Overview

PiSignage is a digital signage solution running on Raspberry Pi with a **single playback
engine**: a full-screen **Chromium HTML5 player**. Since v0.12 VLC has been removed
entirely — there is no longer a "dual-player" / display-mode switch, no VLC service, and
no VLC HTTP interface.

The browser boots into kiosk mode and loads the local player page
(`http://127.0.0.1/player`), which renders the active playlist
(`/opt/pisignage/media/playlist.json`). Playback is steered remotely through a lightweight
command/state API (`api/display.php`).

### Design Principles

- **Single engine**: One Chromium HTML5 player — fewer moving parts, one code path
- **One source of truth**: Unified playlists in `/opt/pisignage/playlists/`, one active
  pointer, one on-screen file
- **Simplicity**: One-command installation and configuration
- **Modularity**: Independent components with clear interfaces
- **Performance**: Hardware-accelerated decode via Wayland/labwc on Pi 4/5

---

## Technology Stack

### Operating System
- **Raspberry Pi OS Trixie** (Debian 13)
- Linux kernel 6.6+
- systemd for service management

### Display Stack

```
Hardware → DRM/KMS → Wayland → labwc → Chromium (kiosk) → HDMI Output
```

### Backend
- **PHP 8.4-fpm** - Web application and REST API
- **nginx** - HTTP server with FastCGI (PHP-FPM)
- **Bash / POSIX sh** - System scripts and automation

### Frontend
- **Vanilla JavaScript** - No frameworks (lightweight)
- **Adaptive design system** - Light/dark theme, "emerald" accent, local Inter font,
  inline SVG icons (no emoji)
- **HTML5 player** - Chromium player page with Wake Lock API, offline fallback,
  splash/preload (anti-flash), and info overlays (clock/banner/bilingual fr-nl cards/QR)

### Media Player
- **Chromium 120+** - Sole playback engine, kiosk mode, HTML5 video/image rendering

### Display Session
- **lightdm** - Display manager with autologin of user `pi`
- **labwc** - Stacking Wayland compositor
- **seatd** - Seat management daemon

> "Restart the session" = `sudo systemctl restart display-manager` (lightdm).

---

## Directory Structure

```
/opt/pisignage/
├── config/                      # Configuration files
│   ├── active-playlist.json    # Active playlist pointer
│   ├── scheduler-state.json    # Real dayparting state (written by scheduler)
│   ├── kiosk_url               # Chromium kiosk URL (player by default)
│   ├── kiosk_flags             # Chromium flags
│   └── feature_flags           # System feature flags
│
├── bin/                         # Managed binaries
│   └── yt-dlp                  # YouTube downloader (self-updatable from UI)
│
├── scripts/                     # System scripts
│   ├── kiosk-apply             # Generates labwc autostart from config
│   └── ...                     # Install / maintenance helpers
│
├── media/                       # Media storage
│   ├── playlist.json           # ON-SCREEN playlist (what the player renders)
│   ├── videos/                 # Video files
│   ├── images/                 # Image files
│   └── thumbnails/             # Generated thumbnails
│
├── playlists/                   # Unified playlist definitions (<slug>.json)
├── data/
│   └── schedules.json          # Dayparting schedule definitions
├── logs/                        # Application logs
└── backups/                     # Configuration backups

/opt/pisignage/web/
├── api/                         # REST API endpoints
│   ├── display.php             # Player command/state channel + playmedia
│   ├── playlists.php           # Unified playlist API (list/get/save/activate/delete)
│   ├── playlists-core.php      # Shared playlist logic (single source of truth)
│   ├── scheduler.php           # Dayparting executor (CLI, run by cron)
│   ├── media.php               # Media library + reference integrity
│   ├── system.php              # System info + ALSA volume control
│   ├── kiosk.php               # Display/kiosk settings
│   ├── youtube.php             # YouTube download (yt-dlp)
│   ├── upload.php              # File upload
│   └── ...                     # Other endpoints
│
├── includes/                    # Shared components
│   ├── auth.php                # Authentication
│   ├── navigation.php          # Navigation menu
│   └── functions.php           # Utility functions
│
├── config.php                   # App config (aligns PHP timezone to /etc/timezone)
├── dashboard.php                # Main dashboard
├── playlists.php                # Playlist composer + "Diffuser à l'écran"
├── player.php                   # HTML5 player (served on /player) + live engine control
├── media.php                    # Media library
├── settings.php                 # System settings
└── schedule.php                 # Real dayparting UI

# Deprecated endpoints (respond HTTP 410 Gone):
#   api/playlist-simple.php, api/player.php, api/player-control.php

/home/pi/.config/
└── labwc/                       # Wayland compositor config
    ├── autostart               # Chromium autostart (generated by kiosk-apply)
    └── rc.xml                  # labwc configuration

/etc/
├── cron.d/
│   └── pisignage-scheduler     # Runs scheduler.php every minute as www-data
├── asound.conf                  # HDMI audio default
├── timezone                     # System timezone (mirrored into PHP by config.php)
└── sudoers.d/
    └── pisignage               # Minimal sudo for system actions (reboot, etc.)
```

---

## Component Architecture

### 1. Web Interface Layer

```
┌─────────────────────────────────────────────┐
│      Web Interface (adaptive design system)  │
│                                             │
│  Dashboard │ Media │ Playlists │ Lecteur │…  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
         ┌─────────────────┐
         │  REST API (PHP)  │
         └─────────────────┘
```

**Key Pages (consolidated in v0.12):**
- `dashboard.php` - System overview, statistics, quick actions
- `media.php` - Media library browser and uploader
- `playlists.php` - Playlist **composer + "Diffuser à l'écran"** in one place (single
  unified playlist model; no duplicate playlist editor elsewhere)
- `player.php` - The Chromium HTML5 **player** (served on `/player`) AND the
  "Lecteur" admin page that controls the real engine (play/pause/skip/reload, ALSA
  volume, live state)
- `schedule.php` - **Programmation**: real dayparting UI
- Kiosk page - **display-only** settings (kiosk mode, URL, Chromium flags, scheduled
  screen-off, restart) — no playlist editor
- `settings.php` - System configuration

### 2. API Layer

```
┌────────────────────────────────────────────────────────────┐
│                       REST API Layer                        │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐       │
│  │  display.php │  │ playlists.php│  │  media.php  │       │
│  │  (cmd/state) │  │  (unified)   │  │ (+integrity)│       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘       │
│         │                  │                  │             │
│         │          ┌───────┴───────┐          │             │
│         │          │playlists-core │          │             │
│         │          │  (shared)     │          │             │
│         │          └───────┬───────┘          │             │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
    ┌──────────┐      ┌──────────────┐    ┌─────────┐
    │ Chromium │      │ JSON files   │    │  File   │
    │  player  │      │ playlists/ + │    │ System  │
    │ (poll)   │      │ media/       │    │         │
    └──────────┘      └──────────────┘    └─────────┘
```

**API Architecture Patterns:**
- RESTful design with action query parameters
- Standard JSON response format
- Session-based authentication
- Error handling with proper HTTP status codes (deprecated endpoints return 410)
- Shared logic centralised in `playlists-core.php` (one source of truth)

### 3. Player Control Architecture (display.php)

Since v0.12 the player is **driven remotely** through a poll-based command/state channel.
There is no direct socket into the browser — the admin UI writes commands, the player
polls for them, and the player reports its live state back.

```
┌──────────────────────────────────────────────────────┐
│   Admin UI ("Lecteur" page)                          │
│   POST api/display.php?action=command {cmd}           │
│   GET  api/display.php?action=state   (read state)    │
└───────────────────────┬──────────────────────────────┘
                        │
                        ▼
            ┌───────────────────────────┐
            │      api/display.php       │
            │  command queue + state     │
            └───────────┬───────────────┘
                        │
        ┌───────────────┴───────────────┐
        ▼                               ▼
  GET ?action=command              POST ?action=state
  (player polls every 2s)          (player reports state)
        │                               ▲
        └───────────────┬───────────────┘
                        ▼
            ┌───────────────────────────┐
            │  Chromium HTML5 player      │
            │  (player.php on /player)    │
            └───────────────────────────┘
```

**Commands** (`POST ?action=command {cmd:...}`):
- `next` / `prev` - Skip within the active playlist
- `play` / `pause` - Toggle playback
- `reload` - Force the player to reload the on-screen playlist immediately
- `playmedia` (`POST ?action=playmedia {file}`) - Play a single isolated media file

**State:**
- Player reports live state via `POST ?action=state`
- Admin reads it via `GET ?action=state`

**Volume** is the **system ALSA volume**, handled separately by `api/system.php`
(`set_volume` / `get_volume` / `toggle_mute`). There is no per-player ("VLC") volume.

### 4. Playlist Engine (unified, single source of truth)

```
┌──────────────────────────────────────────────────────┐
│  playlists.php (UI)  →  api/playlists.php             │
│      └── shared core: api/playlists-core.php          │
└───────────────────────┬──────────────────────────────┘
                        │  reads/writes
                        ▼
   /opt/pisignage/playlists/<slug>.json   (definitions)
   /opt/pisignage/config/active-playlist.json   (active pointer)
                        │
              "Diffuser à l'écran" (activate)
                        ▼
   /opt/pisignage/media/playlist.json  + version++   (on-screen)
                        │
                        ▼
   Chromium player reloads itself
   (polls version every 10s, reload channel every 2s)
```

**Playlist schema** (`<slug>.json`):
```json
{
  "name": "...", "slug": "...", "version": 3,
  "autoplay": true, "autoLoop": true,
  "items": [
    { "url": "...", "type": "video|image|url",
      "name": "...", "duration": 10, "fit": "contain",
      "mute": false, "loop": false, "transition": "fade" }
  ]
}
```

**API (`api/playlists.php`):**
- `GET` - List playlists + the active one
- `GET ?name=X` - Read one playlist
- `POST {name,items,autoplay,autoLoop}` - Create / update
- `POST ?action=activate&name=X` - "Diffuser à l'écran" (write `media/playlist.json`,
  bump version)
- `DELETE ?name=X` - Delete

### 5. Chromium Kiosk Session

```
┌─────────────────────────────────────────────┐
│  lightdm (Display Manager)                  │
│  • Autologin as pi                          │
│  • Start labwc Wayland session              │
└────────────┬────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────┐
│  labwc (Wayland Compositor)                 │
│  • Window management                        │
│  • DRM/KMS backend                          │
│  • Execute autostart (generated by          │
│    kiosk-apply)                             │
└────────────┬────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────┐
│  Chromium Browser (Kiosk Mode)              │
│  • Fullscreen --kiosk flag                  │
│  • Navigate to http://127.0.0.1/player      │
│  • Hardware video decode                    │
│  • Wake Lock API (prevent sleep)            │
│  • Splash / offline fallback / preload      │
└─────────────────────────────────────────────┘
```

**Chromium Flags:**
```bash
--kiosk
--noerrdialogs
--disable-infobars
--no-first-run
--check-for-update-interval=604800
--disable-session-crashed-bubble
--disable-features=TranslateUI
--disable-component-update
--password-store=basic
--disable-save-password-bubble
```

---

## Playback Pipeline

PiSignage v0.12 has a **single playback engine**: the Chromium HTML5 player. The boot
chain and the kiosk session are managed by the system display manager.

### Boot Chain

```
Boot
 → lightdm (display manager, autologin "pi")
 → labwc (Wayland compositor)
 → Chromium --kiosk http://127.0.0.1/player
 → renders /opt/pisignage/media/playlist.json
```

### Player Capabilities

- HTML5 video/image rendering with hardware decode
- Wake Lock API (prevents the display from sleeping)
- Splash screen, offline fallback, and preloading (anti-flash) for resilience
- Info overlays on videos: clock, banner, bilingual fr-nl cards, QR code
- Self-reload: polls the active-playlist `version` (10s) and the `reload` command
  channel (2s)

### Session Management

- **lightdm** provides autologin and starts the labwc session
- **labwc** is the Wayland compositor (DRM/KMS backend) and runs the autostart script
  generated by `kiosk-apply`
- "Restart the session" maps to `sudo systemctl restart display-manager`
- The kiosk URL, Chromium flags, and scheduled screen-off are configured from the
  **Kiosk** page (display-only settings)

---

## Data Flow

### Media → Playlists → Diffusion → Display Flow

```
1. User uploads media (Media page)
   ↓
2. File saved to /opt/pisignage/media/
   ↓
3. User composes a playlist (Playlists page → api/playlists.php)
   ↓
4. Playlist JSON saved to /opt/pisignage/playlists/<slug>.json (via playlists-core.php)
   ↓
5. User clicks "Diffuser à l'écran" (POST ?action=activate&name=X)
   ↓
6. active-playlist.json updated; media/playlist.json written + version++
   ↓
7. Chromium player notices the new version (poll 10s) or the reload command (2s)
   ↓
8. Player reloads and renders the playlist → HDMI output
```

### Player Command Flow

```
1. Operator clicks play/pause/next/prev/reload (Lecteur page)
   ↓
2. POST api/display.php?action=command {cmd}
   ↓
3. Command queued server-side
   ↓
4. Player polls GET api/display.php?action=command every 2s, executes it
   ↓
5. Player reports new state via POST api/display.php?action=state
   ↓
6. UI reads GET api/display.php?action=state to show live status
```

### Scheduling (Dayparting) Flow

```
1. cron runs api/scheduler.php (CLI) every minute as www-data
   (/etc/cron.d/pisignage-scheduler)
   ↓
2. scheduler.php reads /opt/pisignage/data/schedules.json
   ↓
3. Picks the active playlist by time / day / recurrence / priority (idempotent)
   ↓
4. Activates it (same path as "Diffuser"); reverts at window end
   ↓
5. Writes /opt/pisignage/config/scheduler-state.json (real state, reflected in UI)
```

> `web/config.php` aligns the PHP timezone to `/etc/timezone`, so dayparting compares
> local time to local schedules (no UTC drift).

### File Upload Flow

```
1. User selects file in web UI
   ↓
2. JavaScript FormData POST to /api/upload.php
   ↓
3. PHP validates file (type, size, security)
   ↓
4. Move temp file to /opt/pisignage/media/
   ↓
5. Generate thumbnail (if video/image)
   ↓
6. Update media database/index
   ↓
7. Return file metadata to UI
   ↓
8. UI refreshes media library
```

---

## Security Architecture

### Authentication System

```
┌──────────────────────────────────────┐
│  User Login (login.php)              │
│  • Username/password validation      │
│  • Session creation                  │
└────────────┬─────────────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│  Session Management                  │
│  • PHP Sessions (server-side)        │
│  • Session cookie (HttpOnly)         │
└────────────┬─────────────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│  Protected Pages/APIs                │
│  • Session validation on each request│
│  • Redirect to login if invalid      │
└──────────────────────────────────────┘
```

### Security Measures

**Input Validation:**
- File upload type/size validation
- API parameter sanitization
- SQL injection prevention (prepared statements)
- XSS prevention (output encoding)

**File Upload Security:**
```php
// Allowed types
$allowed = ['video/mp4', 'video/avi', 'image/jpeg', 'image/png'];

// Max size: 500MB
$max_size = 500 * 1024 * 1024;

// Validate extension and MIME type
// Store outside web root
// Generate safe filenames
```

**Sudo Permissions:**
```
# /etc/sudoers.d/pisignage
# Minimal NOPASSWD entries for system actions invoked by the web UI
# (e.g. reboot, restart display-manager)
```
- Minimal sudo access (only specific commands)
- NOPASSWD for automation
- Inputs validated before execution

**Player Control Channel:**
- `api/display.php` is a poll-based command/state channel (no open socket into the
  browser)
- Localhost player binding (`http://127.0.0.1/player`)
- No external internet exposure of the player; admin access governed by web auth

---

## Deployment Architecture

### Single Device Deployment

```
┌────────────────────────────────────────┐
│      Raspberry Pi 4/5                  │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │  nginx + PHP 8.4-fpm + API       │ │
│  └──────────────────────────────────┘ │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │  lightdm → labwc → Chromium kiosk│ │
│  │  (single HTML5 player engine)    │ │
│  └──────────────────────────────────┘ │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │  Media Storage (/opt/pisignage)  │ │
│  └──────────────────────────────────┘ │
└────────────────┬───────────────────────┘
                 │ HDMI
                 ▼
        ┌────────────────┐
        │     Display    │
        └────────────────┘
```

### Multi-Device Deployment

```
┌──────────────────────┐
│   Central Server     │
│   (Optional)         │
│  • Centralized UI    │
│  • Playlist sync     │
│  • Monitoring        │
└────────┬─────────────┘
         │ Network
         ├─────────────┬─────────────┬─────────────┐
         │             │             │             │
         ▼             ▼             ▼             ▼
    ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
    │  Pi 1  │    │  Pi 2  │    │  Pi 3  │    │  Pi N  │
    │ Chrome │    │ Chrome │    │ Chrome │    │ Chrome │
    └────────┘    └────────┘    └────────┘    └────────┘
         │             │             │             │
         ▼             ▼             ▼             ▼
    [Display 1]   [Display 2]   [Display 3]   [Display N]
```

**Network Requirements:**
- HTTP access to each Pi (port 80)
- SSH access for management (port 22)
- Local network or VPN

---

## Performance Considerations

### Chromium HTML5 Player Performance

**Hardware Acceleration:**
- VA-API video decode (if available)
- GPU compositing via Wayland/labwc (DRM/KMS)
- WebGL support

**Resource Usage:**
- CPU: 15-30% during playback
- RAM: ~300MB base + page memory
- Disk I/O: Cache + local storage

**Optimization:**
- Wake Lock API prevents the display from sleeping
- Splash / offline fallback / preloading reduce flashes between items
- Disabled unnecessary Chrome features (via kiosk flags)
- Minimal extensions/plugins

---

## Scalability

### Horizontal Scaling

**Supported:**
- Multiple independent Pi devices
- Each Pi manages own content
- Central control via API calls

**Not Currently Supported:**
- Automatic content distribution
- Centralized playlist management
- Device grouping/zones

### Vertical Scaling

**Resource Limits:**
- Max file size: 500MB per upload
- Max playlist items: ~100 (recommended)
- Concurrent uploads: 3 (recommended)

**Storage:**
- SD card: 32GB minimum, 128GB+ recommended
- External USB storage: Supported (mount to /opt/pisignage/media)

---

## Monitoring and Observability

### Logs

**System Logs:**
```bash
# Display manager / kiosk session
journalctl -u display-manager -f      # lightdm
journalctl --user -u labwc -f         # labwc compositor

# nginx access
tail -f /var/log/nginx/access.log

# nginx errors
tail -f /var/log/nginx/error.log

# Scheduler (dayparting) — run by cron each minute
grep CRON /var/log/syslog
```

**Application Logs:**
```
/opt/pisignage/logs/system.log       # System events
/opt/pisignage/logs/player.log       # Player events
/opt/pisignage/logs/api.log          # API calls
```

### Metrics

**Web UI Dashboard:**
- CPU usage
- Memory usage
- Disk space
- Current playback status
- Network status
- Temperature

**API Endpoint:**
```bash
curl http://192.168.1.62/api/system.php?action=stats
```

---

## Extensibility

### Adding New API Endpoints

1. Create `/opt/pisignage/web/api/myfeature.php`
2. Implement standard response format
3. Add authentication check
4. Document in API_DOCUMENTATION.md

### Adding New UI Pages

1. Create `/opt/pisignage/web/mypage.php`
2. Include `includes/auth.php` for authentication
3. Include `includes/navigation.php` for menu
4. Add menu item in `includes/navigation.php`

### Customizing Kiosk Display Settings

The kiosk display is configured (not "switched between modes") via the Kiosk page /
`api/kiosk.php`:
1. Edit the kiosk URL, Chromium flags, and scheduled screen-off
2. `kiosk-apply` regenerates the labwc autostart from config
3. Restart the session (`sudo systemctl restart display-manager`)

---

## Technology Decisions

### Why a Single Chromium HTML5 Engine?

**Simplicity:** One playback engine means one code path, one playlist model, and one set
of controls — far fewer moving parts than maintaining VLC and a browser side by side.

**Capability:** HTML5 covers video, images and rich web content, plus advanced APIs
(Wake Lock, fullscreen) and the v0.12 features (info overlays, bilingual cards, QR,
offline fallback, anti-flash preload).

**Consistency:** Authoring and the on-screen result use the same web stack, so the UI and
the display behave identically.

**Maintainability:** Removing VLC eliminated the VLC service, the port 8080 HTTP
interface, the VLC password, and the dual-player display-mode switch.

### Why Wayland (labwc) for Chromium?

**X11 Limitations:** X11 on Raspberry Pi has performance issues and complexity (X server,
window manager, etc.).

**Modern Stack:** Wayland offers better hardware integration via DRM/KMS.

**Simplicity:** labwc is lightweight (~50MB RAM) and designed for kiosk use cases.

**Performance:** Direct rendering, lower latency, better frame pacing.

### Why lightdm for the Session?

**Autologin:** lightdm reliably autologins user `pi` and launches the labwc Wayland
session on Trixie.

**Standard control:** "Restart the session" is a single, well-understood command —
`sudo systemctl restart display-manager` — instead of a custom session manager (greetd is
no longer used).

---

## Future Architecture Considerations

### Potential Enhancements

1. **Centralized Management:**
   - Multi-device orchestration
   - Centralized playlist distribution
   - Device grouping and zones

2. **Real-time Monitoring:**
   - WebSocket API for live updates
   - Grafana dashboard integration
   - Alert system for failures

3. **Advanced Scheduling:**
   - Real dayparting is already shipped (see Scheduling flow): cron-driven
     `scheduler.php`, `data/schedules.json`, time/day/recurrence/priority
   - Future: calendar-based scheduling, holiday detection, dynamic content based on
     conditions

4. **Content Management:**
   - CDN integration
   - Automatic content sync
   - Version control for playlists

5. **Analytics:**
   - Playback statistics
   - Display uptime tracking
   - Content performance metrics

---

**Document Version**: 2.0  
**Last Updated**: 2026-06-21  
**PiSignage Version**: v0.12.0
