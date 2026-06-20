# PiSignage v0.11.0 Architecture

Complete system architecture documentation for PiSignage digital signage platform.

## Table of Contents

- [System Overview](#system-overview)
- [Technology Stack](#technology-stack)
- [Directory Structure](#directory-structure)
- [Component Architecture](#component-architecture)
- [Display Modes](#display-modes)
- [Data Flow](#data-flow)
- [Security Architecture](#security-architecture)
- [Deployment Architecture](#deployment-architecture)

---

## System Overview

PiSignage is a digital signage solution running on Raspberry Pi with two display modes:

1. **VLC Mode (Default)** - Stable hardware-accelerated video player
2. **Chromium Kiosk Mode** - HTML5 web-based player with advanced features

### Design Principles

- **Stability First**: VLC as default for production reliability
- **Flexibility**: Optional Chromium mode for advanced use cases
- **Simplicity**: One-command installation and configuration
- **Modularity**: Independent components with clear interfaces
- **Performance**: Hardware acceleration and optimized playback

---

## Technology Stack

### Operating System
- **Raspberry Pi OS Trixie** (Debian 13)
- Linux kernel 6.6+
- systemd for service management

### Display Stack

**VLC Mode:**
```
Hardware → Linux Framebuffer → VLC Media Player → HDMI Output
```

**Chromium Kiosk Mode:**
```
Hardware → DRM/KMS → Wayland → labwc → Chromium → HDMI Output
```

### Backend
- **PHP 8.2+** - Web server and API
- **Apache 2.4** - HTTP server with mod_php
- **Bash** - System scripts and automation

### Frontend
- **Vanilla JavaScript** - No frameworks (lightweight)
- **Bootstrap 5.3** - UI components
- **HTML5** - Player page with Wake Lock API

### Media Players
- **VLC 3.0+** - Default video player with HTTP API (port 8080)
- **Chromium 120+** - Kiosk mode browser for HTML5 player

### Display Managers
- **greetd** - Session manager for Wayland (Chromium mode)
- **labwc** - Stacking Wayland compositor
- **seatd** - Seat management daemon

---

## Directory Structure

```
/opt/pisignage/
├── config/                      # Configuration files
│   ├── display-mode.json       # Display mode config (VLC/Chromium)
│   ├── kiosk_url               # Chromium kiosk URL
│   ├── kiosk_flags             # Chromium flags
│   └── feature_flags           # System feature flags
│
├── scripts/                     # System scripts
│   ├── switch-display-mode.sh  # Display mode switcher
│   ├── install-chromium-kiosk.sh # Chromium setup
│   └── install-vlc.sh          # VLC setup
│
├── media/                       # Media storage
│   ├── videos/                 # Video files
│   ├── images/                 # Image files
│   └── thumbnails/             # Generated thumbnails
│
├── playlists/                   # Playlist definitions (JSON)
├── schedules/                   # Schedule definitions (JSON)
├── logs/                        # Application logs
└── backups/                     # Configuration backups

/opt/pisignage/web/
├── api/                         # REST API endpoints
│   ├── player-control.php      # VLC control (BUG-013 fix)
│   ├── display-mode.php        # Display mode API
│   ├── playlist.php            # Playlist management
│   ├── upload.php              # File upload
│   ├── system.php              # System info
│   └── ...                     # Other endpoints (23 total)
│
├── includes/                    # Shared components
│   ├── auth.php                # Authentication
│   ├── db.php                  # Database connection
│   ├── navigation.php          # Navigation menu
│   └── functions.php           # Utility functions
│
├── dashboard.php                # Main dashboard
├── display-mode.php             # Display mode management
├── playlists.php                # Playlist editor
├── media.php                    # Media library
├── settings.php                 # System settings
└── player.php                   # HTML5 player (Chromium mode)

/home/pi/.config/
├── labwc/                       # Wayland compositor config
│   ├── autostart               # Chromium autostart script
│   └── rc.xml                  # labwc configuration
└── greetd/                      # Session manager config

/etc/
├── systemd/system/
│   ├── pisignage-vlc.service   # VLC service
│   └── greetd.service          # Chromium kiosk service
├── asound.conf                  # HDMI audio default
└── sudoers.d/
    └── pisignage-display-mode  # Display mode permissions
```

---

## Component Architecture

### 1. Web Interface Layer

```
┌─────────────────────────────────────────────┐
│         Web Interface (Bootstrap 5)         │
│                                             │
│  Dashboard  │  Media  │  Playlists  │ ...  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
         ┌─────────────────┐
         │  REST API (PHP)  │
         │   23 Endpoints   │
         └─────────────────┘
```

**Key Pages:**
- `dashboard.php` - System overview, statistics, quick actions
- `display-mode.php` - VLC/Chromium mode switcher (NEW in v0.11.0)
- `playlists.php` - Playlist creation and management
- `media.php` - Media library browser and uploader
- `settings.php` - System configuration
- `player.php` - HTML5 video player (Chromium mode)

### 2. API Layer

```
┌───────────────────────────────────────────────────────┐
│                     REST API Layer                     │
│                                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │   Player     │  │   Playlist   │  │   Media     │ │
│  │   Control    │  │   Manager    │  │   Manager   │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘ │
│         │                  │                  │        │
└─────────┼──────────────────┼──────────────────┼────────┘
          │                  │                  │
          ▼                  ▼                  ▼
    ┌─────────┐        ┌─────────┐       ┌─────────┐
    │   VLC   │        │  JSON   │       │  File   │
    │   API   │        │  Files  │       │ System  │
    └─────────┘        └─────────┘       └─────────┘
```

**API Architecture Patterns:**
- RESTful design with action query parameters
- Standard JSON response format
- Session-based authentication
- Error handling with proper HTTP status codes

### 3. Display Mode Architecture (NEW in v0.11.0)

```
┌──────────────────────────────────────────────────────┐
│            Display Mode Switcher                      │
│         (Web UI + API + Bash Script)                  │
└───────────────────┬──────────────────────────────────┘
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
┌─────────────────┐   ┌─────────────────┐
│    VLC Mode     │   │  Chromium Mode  │
│   (Default)     │   │    (Optional)   │
├─────────────────┤   ├─────────────────┤
│ • Hardware acc. │   │ • HTML5 player  │
│ • Stable        │   │ • FPS counter   │
│ • Low latency   │   │ • Wake Lock API │
│ • VLC HTTP API  │   │ • Web content   │
└─────────────────┘   └─────────────────┘
```

**Switching Process:**
1. User selects mode in web UI
2. API call to `display-mode.php?action=switch`
3. Execute `switch-display-mode.sh` with sudo
4. Stop current service (VLC or greetd)
5. Start target service
6. Update config JSON
7. Return success status

### 4. VLC Player Architecture

```
┌──────────────────────────────────────────┐
│      PHP API (player-control.php)        │
│         VLCControl Class                 │
└────────────┬─────────────────────────────┘
             │ HTTP Requests
             ▼
┌──────────────────────────────────────────┐
│     VLC HTTP Interface                   │
│        localhost:8080                    │
│     Password: pisignage                  │
└────────────┬─────────────────────────────┘
             │ Commands
             ▼
┌──────────────────────────────────────────┐
│        VLC Media Player                  │
│  • Hardware decoding (MMAL/V4L2)        │
│  • Playlist management                   │
│  • Status reporting                      │
└──────────────────────────────────────────┘
```

**VLC HTTP API Commands:**
- `status.json` - Get playback state
- `in_enqueue` - Add to playlist
- `pl_play` - Start playback
- `pl_pause` - Pause/Resume
- `pl_stop` - Stop playback
- `pl_next` - Next item
- `pl_previous` - Previous item
- `pl_empty` - Clear playlist

**BUG-013 Fix (v0.11.0):**
```php
// 4-Step Reliable Playback
1. Clear playlist    → pl_empty
2. Enqueue file      → in_enqueue (input=file)
3. Start playback    → pl_play
4. Verify state      → status.json (retry if not playing)
```

### 5. Chromium Kiosk Architecture

```
┌─────────────────────────────────────────────┐
│  greetd (Session Manager)                   │
│  • Auto-login as pi                         │
│  • Start labwc session                      │
└────────────┬────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────┐
│  labwc (Wayland Compositor)                 │
│  • Window management                        │
│  • DRM/KMS backend                          │
│  • Execute autostart script                 │
└────────────┬────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────┐
│  Chromium Browser (Kiosk Mode)              │
│  • Fullscreen --kiosk flag                  │
│  • Navigate to http://localhost/player.php  │
│  • Hardware video decode                    │
│  • Wake Lock API (prevent sleep)            │
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

## Display Modes

### VLC Mode (Default)

**Use Cases:**
- Production digital signage displays
- High-reliability requirements
- Pure video/image playback
- Low-power operation
- Minimal UI/interaction needed

**Advantages:**
- Most stable and reliable
- Lower CPU/memory usage
- Hardware-accelerated video decode
- Battle-tested in production
- Faster startup time

**Limitations:**
- No web content support
- No interactive features
- Limited UI customization

**Service:**
```ini
[Unit]
Description=PiSignage VLC Player
After=network.target

[Service]
Type=simple
User=pi
ExecStart=/usr/bin/cvlc --http-host 0.0.0.0 --http-port 8080 --http-password pisignage
Restart=always

[Install]
WantedBy=multi-user.target
```

### Chromium Kiosk Mode

**Use Cases:**
- Web content display (dashboards, websites)
- Interactive kiosk applications
- HTML5 animations and effects
- Development and testing
- Advanced UI requirements

**Advantages:**
- Full web browser capabilities
- HTML5 video with advanced features
- FPS counter for monitoring
- Wake Lock API prevents sleep
- Flexible content types

**Limitations:**
- Higher resource usage (CPU/RAM)
- Longer startup time
- More complex stack (greetd + labwc)
- Requires Wayland support

**Service:**
```ini
[Unit]
Description=greetd Wayland Session Manager
After=systemd-user-sessions.service

[Service]
Type=idle
ExecStart=/usr/bin/greetd --config /etc/greetd/config.toml
Restart=always

[Install]
WantedBy=graphical.target
```

---

## Data Flow

### Video Playback Flow (VLC Mode)

```
1. User uploads video
   ↓
2. File saved to /opt/pisignage/media/
   ↓
3. User creates/updates playlist
   ↓
4. Playlist JSON saved to /opt/pisignage/playlists/
   ↓
5. User deploys playlist
   ↓
6. API calls VLC HTTP interface
   ↓
7. VLC loads playlist and starts playback
   ↓
8. Video output to HDMI
```

### Display Mode Switch Flow

```
1. User clicks mode button in web UI
   ↓
2. JavaScript sends POST to /api/display-mode.php
   ↓
3. PHP validates mode parameter
   ↓
4. Execute /opt/pisignage/scripts/switch-display-mode.sh
   ↓
5. Bash script stops current service
   ↓
6. Bash script starts target service
   ↓
7. Update /opt/pisignage/config/display-mode.json
   ↓
8. Return success/error to UI
   ↓
9. UI updates status display
```

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
# /etc/sudoers.d/pisignage-display-mode
www-data ALL=(ALL) NOPASSWD: /opt/pisignage/scripts/switch-display-mode.sh
```
- Minimal sudo access (only specific script)
- NOPASSWD for automation
- Script validates input before execution

**VLC HTTP Interface:**
- Password protection (`pisignage`)
- Localhost binding (0.0.0.0 for remote access)
- No external internet exposure

---

## Deployment Architecture

### Single Device Deployment

```
┌────────────────────────────────────────┐
│      Raspberry Pi 4/5                  │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │  Apache + PHP + API              │ │
│  └──────────────────────────────────┘ │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │  VLC Player (Default)            │ │
│  │  OR                              │ │
│  │  Chromium Kiosk (Optional)       │ │
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
    │  VLC   │    │ Chrome │    │  VLC   │    │  VLC   │
    └────────┘    └────────┘    └────────┘    └────────┘
         │             │             │             │
         ▼             ▼             ▼             ▼
    [Display 1]   [Display 2]   [Display 3]   [Display N]
```

**Network Requirements:**
- HTTP access to each Pi (port 80)
- SSH access for management (port 22)
- VLC HTTP interface (port 8080, optional)
- Local network or VPN

---

## Performance Considerations

### VLC Mode Performance

**Hardware Acceleration:**
- MMAL/V4L2 decoding on Pi 4/5
- GPU-accelerated rendering
- Zero-copy video pipeline

**Resource Usage:**
- CPU: 5-15% during playback
- RAM: ~150MB base + video buffers
- Disk I/O: Streaming from local storage

### Chromium Kiosk Performance

**Hardware Acceleration:**
- VA-API video decode (if available)
- GPU compositing via Wayland
- WebGL support

**Resource Usage:**
- CPU: 15-30% during playback
- RAM: ~300MB base + page memory
- Disk I/O: Cache + local storage

**Optimization:**
- FPS counter for monitoring (player.php)
- Wake Lock API prevents sleep
- Disabled unnecessary Chrome features
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
# VLC service
journalctl -u pisignage-vlc -f

# Chromium/greetd service
journalctl -u greetd -f

# Apache access
tail -f /var/log/apache2/access.log

# Apache errors
tail -f /var/log/apache2/error.log
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

### Custom Display Modes

The display mode system supports extending with new modes by:
1. Adding mode definition to `display-mode.json`
2. Creating systemd service for the mode
3. Updating `switch-display-mode.sh` script
4. Adding UI option in `display-mode.php`

---

## Technology Decisions

### Why VLC as Default?

**Stability:** VLC is extremely stable and battle-tested in production environments. It rarely crashes and handles edge cases gracefully.

**Performance:** Hardware acceleration on Raspberry Pi is well-optimized. Lower resource usage than browser-based solutions.

**Simplicity:** Fewer moving parts than Wayland + compositor + browser stack.

**Compatibility:** Works on all Raspberry Pi models (3, 4, 5) without special requirements.

### Why Chromium as Optional?

**Flexibility:** Some users need web content, dashboards, or interactive displays.

**Advanced Features:** HTML5 APIs (Wake Lock, fullscreen, etc.) enable new use cases.

**Development:** Easier to test and develop UI features in browser environment.

**Choice:** Different users have different needs - let them choose.

### Why Wayland for Chromium?

**X11 Limitations:** X11 on Raspberry Pi has performance issues and complexity (X server, window manager, etc.).

**Modern Stack:** Wayland is the future, better hardware integration via DRM/KMS.

**Simplicity:** labwc is lightweight (~50MB RAM) and designed for kiosk use cases.

**Performance:** Direct rendering, lower latency, better frame pacing.

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
   - Calendar-based scheduling
   - Holiday detection
   - Dynamic content based on conditions

4. **Content Management:**
   - CDN integration
   - Automatic content sync
   - Version control for playlists

5. **Analytics:**
   - Playback statistics
   - Display uptime tracking
   - Content performance metrics

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-09  
**PiSignage Version**: v0.11.0
