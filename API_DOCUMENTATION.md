# PiSignage v0.12.0 API Documentation

> **Note (v0.12.0)**: VLC has been **removed**. The single playback engine is now **Chromium HTML5** (`web/player.php` served at `/player`, rendering `/opt/pisignage/media/playlist.json`). Player control moved to `/api/display.php` (command/state/playmedia). Playlists are unified under `/api/playlists.php` (one source of truth: `/opt/pisignage/playlists/<slug>.json`). Volume is now **system ALSA volume** via `/api/system.php` (there is no more "VLC volume"). Several legacy endpoints are **deprecated** and respond with **HTTP 410 Gone** (see [Deprecated Endpoints](#deprecated-endpoints-http-410-gone)).

## Base URL
```
http://{raspberry_pi_ip}/api/
```

## What's New in v0.12.0

- **VLC removed**: Single playback engine is now Chromium HTML5. No more `pisignage-vlc` service, no VLC HTTP interface (port 8080), no VLC password.
- **Player control API** (`/api/display.php`): the player polls `?action=command` every 2s and reports `?action=state`; admin sends `command`/`playmedia` and reads `state`.
- **Unified playlists** (`/api/playlists.php`): single CRUD + `activate` ("Diffuser à l'écran"). One schema, one source of truth on disk. Shared core logic in `web/api/playlists-core.php`.
- **Real dayparting**: `/api/scheduler.php` is now a **CLI executor run by cron** (1×/min, as `www-data`) — it is **not** an HTTP endpoint.
- **ALSA volume only**: volume/mute handled by `/api/system.php` (`get_volume`/`set_volume`/`toggle_mute`).
- **Media integrity**: renaming/deleting media propagates and cleans references across all playlists and the on-screen playlist.
- **Deprecated endpoints**: `playlist-simple.php`, `player.php`, `player-control.php` now return **HTTP 410 Gone**.

## Response Format
All API responses follow a standard JSON structure:
```json
{
  "success": boolean,
  "data": mixed,
  "message": string,
  "timestamp": "Y-m-d H:i:s"
}
```

---

## System API (`/api/system.php`)

### GET /api/system.php?action=stats
Returns system statistics including CPU, memory, disk usage.

**Response:**
```json
{
  "success": true,
  "data": {
    "cpu": {
      "usage": 45,
      "load_1min": 1.2,
      "load_5min": 1.1,
      "load_15min": 0.9
    },
    "memory": {
      "total": 4096,
      "used": 2048,
      "free": 2048,
      "percent": 50
    },
    "disk": {
      "total_formatted": "100GB",
      "used_formatted": "20GB",
      "percent": 20
    },
    "temperature": 55.5,
    "uptime": "2 days, 3 hours",
    "network": "192.168.1.100",
    "media_count": 25
  }
}
```

### POST /api/system.php?action=reboot
Reboots the system.

**Response:**
```json
{
  "success": true,
  "message": "System reboot initiated"
}
```

### POST /api/system.php?action=shutdown
Shuts down the system.

### GET /api/system.php?action=get_volume
Returns the current **system (ALSA)** volume and mute state. There is no separate "VLC volume" in v0.12 — this is the only volume control.

**Response:**
```json
{
  "success": true,
  "data": {
    "volume": 80,
    "muted": false
  }
}
```

### POST /api/system.php?action=set_volume
Sets the **system (ALSA)** volume via `amixer` (0-100).

**Request Body:**
```json
{
  "volume": 65
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "volume": 65
  },
  "message": "Volume set"
}
```

### POST /api/system.php?action=toggle_mute
Toggles the **system (ALSA)** mute state.

**Response:**
```json
{
  "success": true,
  "data": {
    "muted": true
  },
  "message": "Mute toggled"
}
```

---

## Media API (`/api/media.php`)

### GET /api/media.php
Lists all media files.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "video1.mp4",
      "size": 10485760,
      "type": "video/mp4",
      "duration": 120,
      "thumbnail": "/thumbnails/video1.jpg"
    }
  ]
}
```

### DELETE /api/media.php
Deletes a media file.

**Request Body:**
```json
{
  "filename": "video1.mp4"
}
```

> **Media integrity (v0.12.0)**: Renaming or deleting a media file propagates/cleans its references across **all** playlists and the on-screen playlist (`/opt/pisignage/media/playlist.json`). Implemented via `web/api/media.php` together with `web/api/playlists-core.php`.

---

## Playlists API (`/api/playlists.php`) 🆕 v0.12.0

> **Unified in v0.12.0**: A single source of truth for playlists. Each playlist is stored as `/opt/pisignage/playlists/<slug>.json`. The active-playlist pointer lives in `/opt/pisignage/config/active-playlist.json`. Shared logic is in `web/api/playlists-core.php`. The legacy `playlist-simple.php` is **deprecated (HTTP 410)**.

**Playlist schema (on disk and in API payloads):**
```json
{
  "name": "Morning Playlist",
  "slug": "morning-playlist",
  "version": 3,
  "autoplay": true,
  "autoLoop": true,
  "items": [
    {
      "url": "video1.mp4",
      "type": "video",
      "name": "Intro clip",
      "duration": 30,
      "fit": "contain",
      "mute": false,
      "loop": false,
      "transition": "fade"
    }
  ]
}
```

### GET /api/playlists.php
Returns the list of playlists and which one is active.

**Response:**
```json
{
  "success": true,
  "data": {
    "playlists": [
      {"name": "Morning Playlist", "slug": "morning-playlist", "items": 5},
      {"name": "Evening Playlist", "slug": "evening-playlist", "items": 3}
    ],
    "active": "morning-playlist"
  }
}
```

### GET /api/playlists.php?name=X
Returns a single playlist by name/slug (full schema, including `items`).

**Response:**
```json
{
  "success": true,
  "data": {
    "name": "Morning Playlist",
    "slug": "morning-playlist",
    "version": 3,
    "autoplay": true,
    "autoLoop": true,
    "items": [
      {"url": "video1.mp4", "type": "video", "name": "Intro clip", "duration": 30, "fit": "contain", "mute": false, "loop": false, "transition": "fade"}
    ]
  }
}
```

### POST /api/playlists.php
Creates or updates a playlist (upsert keyed on `name`/`slug`).

**Request Body:**
```json
{
  "name": "Evening Playlist",
  "autoplay": true,
  "autoLoop": true,
  "items": [
    {"url": "video2.mp4", "type": "video", "duration": 60, "fit": "contain", "mute": false, "loop": false, "transition": "fade"}
  ]
}
```

**Response:**
```json
{
  "success": true,
  "data": {"name": "Evening Playlist", "slug": "evening-playlist"},
  "message": "Playlist saved"
}
```

### POST /api/playlists.php?action=activate&name=X
Activates a playlist ("Diffuser à l'écran"). Writes `/opt/pisignage/media/playlist.json`, updates the active-playlist pointer, and **increments the version** so the player reloads on its own (version poll every 10s, plus the reload channel every 2s — see [Display/Player API](#displayplayer-api-apidisplayphp--v0120)).

**Response:**
```json
{
  "success": true,
  "data": {
    "active": "evening-playlist",
    "version": 4
  },
  "message": "Playlist diffusée à l'écran"
}
```

### DELETE /api/playlists.php?name=X
Deletes a playlist by name/slug.

**Response:**
```json
{
  "success": true,
  "message": "Playlist deleted"
}
```

---

## Display/Player API (`/api/display.php`) 🆕 v0.12.0

> **New in v0.12.0**: The playback engine is the Chromium HTML5 player (`web/player.php` at `/player`). It is controlled through `/api/display.php`. The **player polls** `GET ?action=command` every 2s and reports its live state via `POST ?action=state`; the **admin UI** sends commands with `POST ?action=command`, reads state with `GET ?action=state`, and plays an isolated media with `POST ?action=playmedia`.

### POST /api/display.php?action=command
Sends a control command to the player. (The player consumes it on its next 2s poll.)

**Request Body:**
```json
{
  "cmd": "next"
}
```

**Valid `cmd` values:** `next` | `prev` | `play` | `pause` | `reload`

**Response:**
```json
{
  "success": true,
  "message": "Command queued",
  "cmd": "next"
}
```

### GET /api/display.php?action=command
Polled by the player to fetch the next pending command. Returns the queued command (and clears it) or an empty/`none` command when nothing is pending.

**Response:**
```json
{
  "success": true,
  "data": {
    "cmd": "next"
  }
}
```

### POST /api/display.php?action=playmedia
Plays a single isolated media file on screen (without modifying the active playlist).

**Request Body:**
```json
{
  "file": "video.mp4"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Playing media",
  "file": "video.mp4"
}
```

### GET /api/display.php?action=state
Returns the player's last reported live state (used by the admin UI).

**Response:**
```json
{
  "success": true,
  "data": {
    "playing": true,
    "paused": false,
    "current_item": "video1.mp4",
    "index": 0,
    "playlist": "morning-playlist",
    "version": 4
  }
}
```

### POST /api/display.php?action=state
Reported by the player itself to publish its current live state (consumed by `GET ?action=state`).

**Request Body:**
```json
{
  "playing": true,
  "paused": false,
  "current_item": "video1.mp4",
  "index": 0,
  "playlist": "morning-playlist",
  "version": 4
}
```

**Response:**
```json
{
  "success": true,
  "message": "State updated"
}
```

> **Volume**: Player/system volume is **not** handled here. Use the ALSA volume endpoints on `/api/system.php` (`get_volume` / `set_volume` / `toggle_mute`).

---

## Upload API (`/api/upload.php`)

### POST /api/upload.php
Uploads a media file.

**Request:**
- Method: POST
- Content-Type: multipart/form-data
- Field: file (max 500MB)

**Response:**
```json
{
  "success": true,
  "data": {
    "filename": "video3.mp4",
    "size": 52428800,
    "path": "/opt/pisignage/media/video3.mp4"
  }
}
```

---

## Screenshot API (`/api/screenshot.php`)

### GET /api/screenshot.php
Takes a screenshot of the current display.

**Response:**
```json
{
  "success": true,
  "data": {
    "path": "/screenshots/2025-01-01_120000.png",
    "url": "/screenshots/2025-01-01_120000.png",
    "size": 204800
  }
}
```

---

## Logs API (`/api/logs.php`)

### GET /api/logs.php?type=system
Returns system logs.

**Parameters:**
- type: system|player|web|all
- lines: number (default 100)

**Response:**
```json
{
  "success": true,
  "data": {
    "logs": [
      "[2025-01-01 12:00:00] System started",
      "[2025-01-01 12:00:05] Chromium kiosk player initialized"
    ]
  }
}
```

---

## Performance API (`/api/performance.php`)

### GET /api/performance.php
Returns performance metrics.

**Response:**
```json
{
  "success": true,
  "data": {
    "fps": 30,
    "dropped_frames": 0,
    "network_latency": 5,
    "rendering_time": 16
  }
}
```

---

## Scheduler (`/api/scheduler.php`) — CLI executor, NOT an HTTP endpoint 🆕 v0.12.0

> **Changed in v0.12.0**: `web/api/scheduler.php` is now a **CLI executor run by cron** (1×/minute, as `www-data`, via `/etc/cron.d/pisignage-scheduler`). It is **not** called over HTTP. It performs real dayparting: it reads `/opt/pisignage/data/schedules.json` and designates the active playlist according to time/day/recurrence/priority. It is idempotent and reverts to the default playlist at the end of a window. The resolved state is written to `/opt/pisignage/config/scheduler-state.json` and reflected in the UI.

**Execution:**
```cron
# /etc/cron.d/pisignage-scheduler
* * * * * www-data php /opt/pisignage/web/api/scheduler.php >/dev/null 2>&1
```

**Inputs / outputs:**

| File | Role |
|------|------|
| `/opt/pisignage/data/schedules.json` | Schedule definitions (read) |
| `/opt/pisignage/config/scheduler-state.json` | Resolved active window/state (written) |
| `/opt/pisignage/config/active-playlist.json` | Active-playlist pointer it updates when a window applies |

> **Timezone note**: `web/config.php` aligns the PHP timezone with `/etc/timezone`; otherwise dayparting would compare UTC against local schedule times.

**`schedules.json` entry shape (illustrative):**
```json
[
  {
    "id": 1,
    "playlist": "Morning Playlist",
    "start_time": "08:00",
    "end_time": "12:00",
    "days": ["mon", "tue", "wed", "thu", "fri"],
    "priority": 10,
    "enabled": true
  }
]
```

Schedule **definitions** are managed from the "Programmation" page (UI), not by calling this script over HTTP.

---

## Configuration API (`/api/config.php`)

### GET /api/config.php
Returns system configuration.

**Response:**
```json
{
  "success": true,
  "data": {
    "display": {
      "resolution": "1920x1080",
      "orientation": "landscape",
      "brightness": 80
    },
    "network": {
      "wifi_enabled": true,
      "ethernet_connected": false
    },
    "player": {
      "engine": "chromium",
      "autostart": true
    }
  }
}
```

### POST /api/config.php
Updates configuration settings.

---

## YouTube API (`/api/youtube.php`)

### POST /api/youtube.php
Downloads a YouTube video.

**Request Body:**
```json
{
  "url": "https://youtube.com/watch?v=...",
  "quality": "720p"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "filename": "youtube_video.mp4",
    "title": "Video Title",
    "duration": 180
  }
}
```

---

## Display Mode API (`/api/display-mode.php`) ⚠️ OBSOLETE since v0.12

> **⚠️ OBSOLETE since v0.12 — VLC removed, single engine = Chromium HTML5.**
> There is no longer a VLC/Chromium toggle: the only playback engine is the Chromium HTML5 player. Player control is now on [`/api/display.php`](#displayplayer-api-apidisplayphp--v0120); display/kiosk settings are on [`/api/kiosk.php`](#kiosk-api-apikioskphp-); volume is ALSA via [`/api/system.php`](#system-api-apisystemphp). The section below is kept for historical reference only.

### GET /api/display-mode.php?action=status
Returns current display mode and available modes.

**Response:**
```json
{
  "success": true,
  "current_mode": "vlc",
  "modes": {
    "vlc": {
      "name": "VLC Player (Default)",
      "description": "Stable video player with hardware acceleration",
      "service": "pisignage-vlc",
      "autostart": true,
      "status": "active"
    },
    "chromium": {
      "name": "Chromium Kiosk (HTML5)",
      "description": "Web-based player with FPS counter and advanced features",
      "service": "greetd",
      "autostart": false,
      "status": "inactive"
    }
  },
  "audio": {
    "output": "hdmi",
    "volume": 100
  }
}
```

### POST /api/display-mode.php?action=switch
Switches display mode between VLC and Chromium.

**Request Body:**
```json
{
  "mode": "chromium"
}
```

**Valid modes:**
- `vlc` - VLC Player (default, stable)
- `chromium` - Chromium Kiosk (HTML5, advanced features)

**Response:**
```json
{
  "success": true,
  "message": "Display mode switched to chromium",
  "mode": "chromium",
  "service_status": "active"
}
```

**Implementation:**
- Script: `/opt/pisignage/scripts/switch-display-mode.sh`
- Config: `/opt/pisignage/config/display-mode.json`
- Requires: sudo permissions for www-data user
- Services:
  - VLC mode: `pisignage-vlc` service
  - Chromium mode: `greetd` service (labwc + Chromium)

**Example:**
```bash
# Switch to Chromium kiosk
curl -X POST -H "Content-Type: application/json" \
  -d '{"mode":"chromium"}' \
  http://192.168.1.62/api/display-mode.php?action=switch

# Switch back to VLC (default)
curl -X POST -H "Content-Type: application/json" \
  -d '{"mode":"vlc"}' \
  http://192.168.1.62/api/display-mode.php?action=switch

# Check current mode
curl http://192.168.1.62/api/display-mode.php?action=status
```

---

## Kiosk API (`/api/kiosk.php`) 🆕

> **New in feature/trixie-kiosk-chromium**: Remote management of Chromium kiosk mode on Raspberry Pi OS Trixie (Debian 13) with Wayland.

### GET /api/kiosk.php
Returns kiosk status and configuration.

**Response:**
```json
{
  "success": true,
  "data": {
    "enabled": true,
    "url": "https://time.is",
    "flags": "--incognito --noerrdialogs --disable-translate --no-first-run",
    "chromium_running": true,
    "autostart_exists": true
  },
  "message": "Kiosk status",
  "timestamp": "2025-11-09 12:00:00"
}
```

### GET /api/kiosk.php/url
Returns the current kiosk URL.

**Response:**
```json
{
  "success": true,
  "data": {
    "url": "https://time.is"
  },
  "message": "Current kiosk URL",
  "timestamp": "2025-11-09 12:00:00"
}
```

### PUT /api/kiosk.php/url
Updates the kiosk URL and triggers autostart regeneration.

**Request Body:**
```json
{
  "url": "https://grafana.local/dashboard"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "url": "https://grafana.local/dashboard",
    "applied": true,
    "message": "Autostart regenerated successfully"
  },
  "message": "Kiosk URL updated successfully",
  "timestamp": "2025-11-09 12:00:00"
}
```

**Validation:**
- URL must be valid (checked with `filter_var`)
- Changes are persisted to `/opt/pisignage/config/kiosk_url`
- Script `kiosk-apply` is executed automatically

### GET /api/kiosk.php/flags
Returns the current Chromium flags.

**Response:**
```json
{
  "success": true,
  "data": {
    "flags": "--incognito --noerrdialogs --disable-translate --no-first-run"
  },
  "message": "Current Chromium flags",
  "timestamp": "2025-11-09 12:00:00"
}
```

### PUT /api/kiosk.php/flags
Updates the Chromium flags and triggers autostart regeneration.

**Request Body:**
```json
{
  "flags": "--incognito --noerrdialogs --force-device-scale-factor=1.5"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "flags": "--incognito --noerrdialogs --force-device-scale-factor=1.5",
    "applied": true,
    "message": "Autostart regenerated successfully"
  },
  "message": "Kiosk flags updated successfully",
  "timestamp": "2025-11-09 12:00:00"
}
```

**Validation:**
- Flags are checked for shell injection characters (`;&|$` etc.)
- Changes are persisted to `/opt/pisignage/config/kiosk_flags`
- Script `kiosk-apply` is executed automatically

### POST /api/kiosk.php/restart
Restarts the Chromium kiosk browser.

**Response:**
```json
{
  "success": true,
  "data": {
    "killed": true,
    "applied": true,
    "message": "Chromium killed. Will restart on next labwc session.",
    "note": "For immediate effect, logout/login or restart labwc session"
  },
  "message": "Kiosk restart triggered",
  "timestamp": "2025-11-09 12:00:00"
}
```

**Behavior:**
- Kills all Chromium processes with `pkill -f "/usr/bin/chromium"`
- Executes `kiosk-apply` to regenerate autostart
- Chromium restarts automatically on next labwc session start
- For immediate restart, restart the graphical session: `sudo systemctl restart display-manager` (lightdm) or logout/login

### Kiosk Configuration Files

The kiosk API manages these configuration files:

| File | Purpose | Default Value |
|------|---------|---------------|
| `/opt/pisignage/config/kiosk_url` | Target URL | `https://time.is` |
| `/opt/pisignage/config/kiosk_flags` | Chromium flags | `--incognito --noerrdialogs --disable-translate --no-first-run` |
| `/opt/pisignage/config/feature_flags` | Enable/disable kiosk | `ENABLE_KIOSK=1` |

### Recommended Chromium Flags

**Basic (default):**
```
--incognito --noerrdialogs --disable-translate --no-first-run
```

**Enhanced:**
```
--incognito --noerrdialogs --disable-translate --no-first-run --disable-infobars --disable-session-crashed-bubble
```

**4K Display:**
```
--incognito --noerrdialogs --force-device-scale-factor=1.5 --high-dpi-support=1
```

### Requirements

- **OS:** Raspberry Pi OS Trixie (Debian 13)
- **Hardware:** Raspberry Pi 4 or 5
- **Stack:** lightdm (autologin `pi`) → labwc (Wayland) → Chromium (`--kiosk http://127.0.0.1/player`)
- **Feature flag:** `ENABLE_KIOSK=1` in `/opt/pisignage/config/feature_flags`

### Disable Kiosk Mode

To disable kiosk mode without uninstalling:

```bash
# Via API (if available)
curl -X PUT http://[pi-ip]/api/kiosk.php/flags \
  -H "Content-Type: application/json" \
  -d '{"flags": ""}'

# Or manually
echo "ENABLE_KIOSK=0" | sudo tee /opt/pisignage/config/feature_flags
sudo reboot
```

### See Also

- [UPGRADE_TRIXIE.md](UPGRADE_TRIXIE.md) - Complete Trixie installation guide
- [README.md](README.md#-trixie--wayland-kiosk-mode) - Trixie overview

---

## Deprecated Endpoints (HTTP 410 Gone)

The following endpoints were **removed in v0.12.0** and now respond with **HTTP 410 Gone**. Update integrations to the replacements below.

| Removed endpoint | Replacement |
|------------------|-------------|
| `/api/playlist-simple.php` (GET/POST/DELETE) | [`/api/playlists.php`](#playlists-api-apiplaylistsphp--v0120) (unified CRUD + `activate`) |
| `/api/player.php` (status/control) | [`/api/display.php`](#displayplayer-api-apidisplayphp--v0120) (`command` / `state` / `playmedia`) |
| `/api/player-control.php` (`play_file`, BUG-013) | [`/api/display.php?action=playmedia`](#displayplayer-api-apidisplayphp--v0120) |

> The old VLC-centric concepts that backed these endpoints no longer exist: no `pisignage-vlc` service, no VLC HTTP interface (port 8080), no VLC password, no "VLC volume" (volume is ALSA via `/api/system.php`).

---

## Error Codes

- `200` - Success
- `400` - Bad Request
- `404` - Not Found
- `410` - Gone (deprecated endpoint removed in v0.12.0)
- `500` - Internal Server Error
- `507` - Insufficient Storage

## Rate Limiting

- Maximum 100 requests per minute per IP
- Upload limit: 500MB per file
- Batch operations limited to 50 items

## Authentication

Authentication is now required on all pages via session-based system.

### Security Enhancements in v0.8.9
- **Authentication system**: Session-based auth protecting all pages
- **Improved input validation**: All endpoints validate input data
- **Enhanced file upload security**: Type and size validation
- **Better error handling**: No exposure of system internals
- **Rate limiting capabilities**: Configurable (recommended for production)