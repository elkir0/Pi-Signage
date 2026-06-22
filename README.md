# PiSignage v0.12.0

Professional digital signage solution for Raspberry Pi with a single Chromium HTML5 playback engine, unified playlist publishing, and a modern modular web interface.

## 🚀 What's New in v0.12.0

### 🎬 **Single Chromium HTML5 Engine**
- **VLC Removed**: One playback engine only — Chromium in kiosk mode renders the player page (`web/player.php` served at `/player`)
- **Unified Source of Truth**: The player reads `/opt/pisignage/media/playlist.json` and reloads itself automatically
- **No More VLC**: No `pisignage-vlc` service, no VLC HTTP interface, no VLC port, no VLC password
- **System Volume Only**: Audio is the ALSA system volume via `web/api/system.php` (`set_volume`/`get_volume`/`toggle_mute`)

### 📺 **Unified Playlist Publishing**
- **Single API**: `web/api/playlists.php` handles list, read, create/update, activate, and delete
- **One JSON Schema**: `/opt/pisignage/playlists/<slug>.json` with `{name, slug, version, autoplay, autoLoop, items[...]}`
- **"Diffuser à l'écran"**: Activating a playlist writes `/opt/pisignage/media/playlist.json` and bumps `version` — the player reloads on its own
- **Active Pointer**: `/opt/pisignage/config/active-playlist.json` tracks the playlist on screen
- **Shared Core**: Common logic in `web/api/playlists-core.php`

### 🖥️ **Player Control API**
- **`web/api/display.php`**: `POST ?action=command {cmd:next|prev|play|pause|reload}`; the player polls `GET ?action=command` every 2s
- **Live State**: The player reports state via `POST ?action=state`; the admin reads it with `GET ?action=state`
- **Isolated Playback**: `POST ?action=playmedia {file}` to play a single media item

### ⏰ **Real Dayparting (Scheduler)**
- **CLI Executor**: `web/api/scheduler.php` runs once per minute via cron (as `www-data`, `/etc/cron.d/pisignage-scheduler`)
- **Schedule-driven**: Reads `/opt/pisignage/data/schedules.json` and picks the active playlist by time/day/recurrence/priority (idempotent, reverts at window end)
- **State Tracking**: Real state written to `/opt/pisignage/config/scheduler-state.json` and reflected in the UI
- **Timezone Fix**: `web/config.php` aligns PHP timezone with `/etc/timezone`

### 🎨 **UI Redesign**
- **Adaptive Light/Dark Design System**: Emerald accent, local Inter font, SVG icons (no emoji)
- **Consolidated Pages**: Playlists (compose + publish), Player (real engine control + ALSA volume + live state), Kiosk (display settings only), Programmation (real dayparting)
- **Video Info Overlays**: Clock, ticker, bilingual fr-nl cards, QR codes
- **Player Resilience**: Splash, offline fallback, anti-flash preloading
- **YouTube**: Live progress bar and 1-click yt-dlp update (yt-dlp managed in `/opt/pisignage/bin`)

### 🧩 **Media Integrity**
- **Reference Propagation**: Renaming or deleting a media item updates/cleans references across all playlists and the playlist on screen (`web/api/media.php` + `playlists-core.php`)

### 📚 **Documentation**
- **API Documentation**: Complete REST API reference with examples ([API_DOCUMENTATION.md](API_DOCUMENTATION.md))
- **Architecture Guide**: Full system architecture documentation ([ARCHITECTURE.md](ARCHITECTURE.md))
- **Migration Guide**: Step-by-step upgrade instructions ([MIGRATION.md](MIGRATION.md))

### Previous (v0.11.0)
- **Display Mode Switcher** (now removed): toggled between VLC and Chromium kiosk
- **Code Cleanup**: Removed legacy `index-pi.php` and `youtube-simple.php`

## ✨ Features

### Core Features
- **Modular Web Interface**: Individual pages for dashboard, media, playlists, player control, kiosk, and settings
- **Multiple Media Formats**: Full support for video (MP4, AVI, MKV) and images (JPG, PNG, GIF), rendered as HTML5
- **Unified Playlist Management**: Create, edit, schedule, and publish playlists to the screen from one place
- **Real-time System Monitoring**: Live CPU, RAM, temperature, and network monitoring
- **Single Chromium HTML5 Engine**: One playback engine — Chromium kiosk renders the player page (VLC removed in v0.12.0)
- **System (ALSA) Volume Control**: Independent system volume and mute via `web/api/system.php`
- **Hardware Acceleration**: Optimized for Raspberry Pi GPU acceleration under Wayland

### New in v0.12.0
- **VLC Removed**: A single Chromium HTML5 playback engine replaces VLC entirely (no `pisignage-vlc` service, no VLC HTTP port, no VLC password)
- **Unified Playlists**: One JSON schema and one API (`playlists.php` + `playlists-core.php`); "Diffuser à l'écran" publishes to the player which reloads itself
- **Real Dayparting**: `scheduler.php` runs via cron once per minute and selects the active playlist by schedule
- **Media Integrity**: Renaming/deleting media propagates across all playlists and the live screen
- **UI Redesign**: Adaptive light/dark design system, emerald accent, local Inter font, SVG icons (no emoji)

## Requirements

- Raspberry Pi 4 / 5
- **Raspberry Pi OS Trixie (Debian 13)** with Wayland (labwc)
  - ⚠️ **Desktop edition REQUIRED** (not Lite)
- 2GB+ RAM recommended
- Network connectivity
- Display connected via HDMI

### 🆕 Trixie / Wayland Kiosk Mode

Pi-Signage targets **Raspberry Pi OS Trixie (Debian 13)** with a modern Wayland-based kiosk mode as its single playback engine:

- ✅ **Chromium HTML5 Engine** - Full-screen kiosk renders the player page (`http://127.0.0.1/player`)
- ✅ **Wayland Compositor (labwc)** - Modern, lightweight display server
- ✅ **Autologin via lightdm** - The `pi` session starts labwc, then Chromium kiosk
- ✅ **Remote Configuration** - Change kiosk URL/flags via REST API and the Kiosk page
- ✅ **Restart the Session** - `sudo systemctl restart display-manager`

**Target Hardware:** Raspberry Pi 4 / Pi 5

**Requirements:**
- ⚠️ **Desktop edition REQUIRED** - Raspberry Pi OS with desktop
- Lite edition lacks Wayland graphics infrastructure and will fail

**See:** [UPGRADE_TRIXIE.md](UPGRADE_TRIXIE.md) for complete installation and configuration guide.

## Installation

### Quick Install (Recommended)
```bash
wget https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install.sh
bash install.sh
```

### Manual Install
```bash
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage
bash install.sh
```

**Note:** The script should NOT be run with `sudo` - it will request privileges when needed.

## Usage

### Access Web Interface
Open browser and navigate to:
```
http://[raspberry-pi-ip]
```

**Default Login Credentials:**
- Username: `admin`
- Password: `signage2025`

⚠️ **IMPORTANT**: Change the password immediately after first login (Settings > Security)

See [Authentication Documentation](docs/AUTHENTICATION.md) for more details.

### Default Directories
- Media files: `/opt/pisignage/media/`
- Configuration: `/opt/pisignage/config/`
- Logs: `/opt/pisignage/logs/`
- Scripts: `/opt/pisignage/scripts/`

### Starting the Service
```bash
sudo systemctl start pisignage
sudo systemctl enable pisignage  # Auto-start on boot
```

### Display / Kiosk Session
The display engine is the Chromium kiosk started by the autologin session (lightdm → labwc → Chromium). To restart the on-screen display:
```bash
sudo systemctl restart display-manager
```

## API Documentation

See [API_DOCUMENTATION.md](API_DOCUMENTATION.md) for complete API reference.

### Quick API Examples

Get system stats:
```bash
curl http://[pi-ip]/api/system.php?action=stats
```

Upload media:
```bash
curl -X POST -F "file=@video.mp4" http://[pi-ip]/api/upload.php
```

Create / update a playlist:
```bash
curl -X POST http://[pi-ip]/api/playlists.php \
  -H "Content-Type: application/json" \
  -d '{"name":"My Playlist","autoplay":true,"autoLoop":true,"items":[{"url":"video.mp4","type":"video","duration":30}]}'
```

Publish a playlist to the screen ("Diffuser"):
```bash
curl -X POST "http://[pi-ip]/api/playlists.php?action=activate&name=My%20Playlist"
```

Control the player:
```bash
curl -X POST http://[pi-ip]/api/display.php?action=command \
  -H "Content-Type: application/json" \
  -d '{"cmd":"next"}'   # next | prev | play | pause | reload
```

## Configuration

### Active Playlist
The playlist on screen is published to `/opt/pisignage/media/playlist.json` and tracked by `/opt/pisignage/config/active-playlist.json`. Use the Playlists page ("Diffuser à l'écran") or the API rather than editing these by hand.

### Kiosk / Display Configuration
```bash
/opt/pisignage/config/kiosk_url       # Target URL (default: http://127.0.0.1/player)
/opt/pisignage/config/kiosk_flags     # Chromium flags
/opt/pisignage/config/feature_flags   # ENABLE_KIOSK=1 or 0
```

### Network Settings
Configure via web interface or edit system files directly.

## Troubleshooting

### No Video Display
1. Check the kiosk session: `sudo systemctl status display-manager`
2. Verify the published playlist: `cat /opt/pisignage/media/playlist.json`
3. Verify media files: `ls -la /opt/pisignage/media/`
4. Reload the player: `curl -X POST http://localhost/api/display.php?action=command -d '{"cmd":"reload"}'`

### Web Interface Not Loading
1. Check nginx: `sudo systemctl status nginx`
2. Verify PHP: `sudo systemctl status php*-fpm`
3. Check firewall: `sudo ufw status`

### Upload Failures
1. Check permissions: `ls -la /opt/pisignage/media/`
2. Verify disk space: `df -h`
3. Check upload limits in `/etc/nginx/sites-available/pisignage`

## Development

### Project Structure (v0.12.0)
```
/opt/pisignage/
├── web/                    # Modular web interface
│   ├── dashboard.php       # Main dashboard page
│   ├── media.php          # Media management
│   ├── playlists.php      # Playlist composer + "Diffuser à l'écran"
│   ├── player.php         # Chromium HTML5 player page (served at /player)
│   ├── player-control-ui.php # Player engine control (play/pause/skip/reload + ALSA volume)
│   ├── kiosk.php          # Display/kiosk settings only
│   ├── schedule.php       # Real dayparting (scheduler)
│   ├── settings.php       # System settings
│   ├── logs.php           # Log viewer
│   ├── screenshot.php     # Screenshot utility
│   ├── youtube.php        # YouTube downloader
│   ├── api/               # REST API endpoints
│   │   ├── playlists.php      # Unified playlists API
│   │   ├── playlists-core.php # Shared playlist logic
│   │   ├── display.php        # Player command/state channel
│   │   ├── scheduler.php      # CLI dayparting executor (cron)
│   │   ├── media.php          # Media + reference integrity
│   │   └── system.php         # System stats + ALSA volume
│   ├── assets/
│   │   ├── css/           # Modular CSS files
│   │   │   ├── main.css
│   │   │   ├── core.css
│   │   │   ├── layout.css
│   │   │   ├── components.css
│   │   │   ├── responsive.css
│   │   │   └── modern-ui.css
│   │   └── js/            # JavaScript modules
│   │       ├── core.js
│   │       ├── api.js
│   │       ├── dashboard.js
│   │       ├── media.js
│   │       ├── playlists.js
│   │       └── player.js
│   └── includes/          # Shared components
│       ├── header.php
│       ├── navigation.php
│       └── auth.php
├── media/                 # Media storage
├── scripts/               # System scripts
├── config/                # Configuration files
├── logs/                  # Application logs
└── docs/                  # Documentation
    ├── ARCHITECTURE.md
    └── MIGRATION.md
```

### Contributing
1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## License

MIT License - see LICENSE file for details.

## Support

For issues and questions:
- GitHub Issues: https://github.com/your-username/PiSignage/issues
- Documentation: https://github.com/your-username/PiSignage/wiki

## Credits

Developed for reliable digital signage on Raspberry Pi hardware.

## 📊 Performance Improvements

### v0.8.9 vs v0.8.3 Comparison

| Metric | v0.8.3 (SPA) | v0.8.9 (MPA) | Improvement |
|--------|---------------|---------------|-------------|
| Initial Load Time | 5s (200KB) | 1s (40KB) | **80% faster** |
| Memory Usage | 150MB constant | 40MB per page | **73% less** |
| JS Parsing Time | 3s | 0.5s | **83% faster** |
| Navigation | Instant (when working) | 1s | Reliable |
| File Size | 4,724 lines | ~500 lines/page | **90% more manageable** |
| Maintainability | 2/10 | 9/10 | **450% improvement** |

*(Historical comparison; v0.12.0 later removed VLC entirely in favor of a single Chromium HTML5 engine.)*

## 🛠 Migration from Earlier Versions

```bash
# Backup current installation
sudo cp -r /opt/pisignage /opt/pisignage-backup

# Update to v0.12.0
cd /opt/pisignage
git pull origin main

# Restart services and the kiosk session
sudo systemctl restart pisignage nginx
sudo systemctl restart display-manager
```

**Note**: v0.12.0 removes VLC entirely. The single Chromium HTML5 engine renders the player page and reads `/opt/pisignage/media/playlist.json`. The `pisignage-vlc` service, the VLC HTTP interface, and the VLC password no longer exist. Deprecated playlist/player endpoints (`playlist-simple.php`, `player.php` API, `player-control.php`) now respond with HTTP 410.

For detailed migration guide, see [docs/MIGRATION.md](docs/MIGRATION.md).

## 📚 Documentation

- **[Installation Guide](docs/INSTALL.md)** - Complete setup instructions
- **[API Documentation](docs/API.md)** - REST API reference
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Technical architecture details
- **[Migration Guide](docs/MIGRATION.md)** - Upgrading from earlier versions
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

---

**PiSignage v0.12.0** - Modular, Fast, Reliable Digital Signage

*Built with modern web architecture for Raspberry Pi performance*
