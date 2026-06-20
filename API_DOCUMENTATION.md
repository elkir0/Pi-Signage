# PiSignage v0.11.0 API Documentation

> **Note**: API endpoints remain 100% compatible with previous versions. The v0.11.0 architecture provides enhanced features including Display Mode Switcher (VLC/Chromium), improved VLC player control with BUG-013 fix, and comprehensive system management.

## Base URL
```
http://{raspberry_pi_ip}/api/
```

## What's New in v0.11.0

- **Display Mode Switcher**: Toggle between VLC (stable, default) and Chromium kiosk (HTML5, advanced features) via web UI or API
- **BUG-013 Fix**: Single file playback now 100% reliable with 4-step process (clear, enqueue, play, verify)
- **Chromium Kiosk Mode**: Wayland-based fullscreen browser with FPS counter and Wake Lock API
- **HDMI Audio Default**: System-wide HDMI audio output configuration
- **Enhanced VLC Control**: Improved reliability with retry logic and timing delays
- **Legacy Code Cleanup**: Removed unused index-pi.php and youtube-simple.php
- **Maintained Compatibility**: All existing API integrations continue to work without changes

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

---

## Playlist API (`/api/playlist-simple.php`)

### GET /api/playlist-simple.php
Returns all playlists.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "Morning Playlist",
      "items": [
        {"file": "video1.mp4", "duration": 30},
        {"file": "image1.jpg", "duration": 10}
      ],
      "created_at": "2025-01-01 10:00:00"
    }
  ]
}
```

### POST /api/playlist-simple.php
Creates a new playlist.

**Request Body:**
```json
{
  "name": "Evening Playlist",
  "items": [
    {"file": "video2.mp4", "duration": 60}
  ],
  "description": "Content for evening display"
}
```

### DELETE /api/playlist-simple.php
Deletes a playlist.

**Request Body:**
```json
{
  "name": "Morning Playlist"
}
```

---

## Player API (`/api/player.php` & `/api/player-control.php`)

### GET /api/player.php?action=status
Returns current player status.

**Response:**
```json
{
  "success": true,
  "data": {
    "player": "vlc",
    "status": "playing",
    "current_file": "video1.mp4",
    "position": 45,
    "duration": 120,
    "volume": 80
  }
}
```

### POST /api/player.php
Controls the player.

**Request Body:**
```json
{
  "action": "play|pause|stop|next|previous"
}
```

### POST /api/player-control.php?action=play_file 🔧 BUG-013 FIX (v0.11.0)
Play a single file with 100% reliability.

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
  "message": "File playing",
  "file": "video.mp4",
  "state": "playing"
}
```

**BUG-013 Fix Implementation:**
1. **Clear existing playlist** - Removes conflicts from previous playback
2. **Enqueue file** - Adds file to empty playlist with `in_enqueue`
3. **Explicit play command** - Forces playback start with `pl_play`
4. **Verify playback** - Checks state and retries if needed
5. **Timing delays** - Allows VLC HTTP API to process commands (200ms, 100ms delays)

**Previous Issue:**
- VLC's `in_play` command was unreliable
- Files wouldn't start playing consistently
- Existing playlist caused conflicts

**Solution:**
- 4-step reliable playback process
- Retry logic with verification
- Proper timing for VLC API processing

**Note**: VLC is the default and recommended player in v0.11.0 for stability.

### GET /api/player.php?action=current
Returns the current player configuration.

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
      "[2025-01-01 12:00:05] VLC player initialized"
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

## Scheduler API (`/api/scheduler.php`)

### GET /api/scheduler.php
Returns scheduled playlists.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "playlist": "Morning Playlist",
      "start_time": "08:00",
      "end_time": "12:00",
      "days": ["mon", "tue", "wed", "thu", "fri"],
      "active": true
    }
  ]
}
```

### POST /api/scheduler.php
Creates or updates a schedule.

**Request Body:**
```json
{
  "playlist": "Evening Playlist",
  "start_time": "18:00",
  "end_time": "22:00",
  "days": ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
}
```

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
      "default": "vlc",
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

## Display Mode API (`/api/display-mode.php`) 🆕 v0.11.0

> **New in v0.11.0**: Toggle between VLC (stable, default) and Chromium kiosk (HTML5, advanced features) display modes.

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
- For immediate restart: `sudo systemctl restart greetd` or logout/login

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
- **Stack:** greetd → labwc (Wayland) → Chromium
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

## Error Codes

- `200` - Success
- `400` - Bad Request
- `404` - Not Found
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