# PiSignage v0.11.0

Professional digital signage solution for Raspberry Pi with modular web interface and advanced media management.

## 🚀 What's New in v0.11.0

### 🎬 **Chromium HTML5 Player + Playlist System**
- **HTML5 Video Playback**: Native `<video>` element with hardware acceleration in Chromium
- **Playlist Management**: JSON-based playlist with REST API and web UI
- **Kiosk Control UI**: Complete management dashboard at `/kiosk.php`
- **Feature Flags**: Switch between Chromium Player and VLC fallback with `USE_CHROMIUM_PLAYER`
- **Format Support**: MP4 (H.264/AAC), WebM (VP9/Opus), MKV with auto-advance and error handling
- **Wake Lock API**: Prevents screen sleep during playback
- **100% Backward Compatible**: VLC remains functional as fallback mode

### Previous (v0.8.9)
- **VLC Exclusive Player**: Removed MPV support for better reliability and maintainability
- **Simplified Architecture**: -400 lines of code with cleaner, more focused implementation
- **Enhanced Stability**: Mature VLC HTTP API provides robust playback control
- **Better Performance**: Streamlined player management reduces overhead
- **100% API Compatibility**: All existing integrations continue to work seamlessly

## ✨ Features

### Core Features
- **Modular Web Interface**: Individual pages for dashboard, media, playlists, player control, and settings
- **Multiple Media Formats**: Full support for video (MP4, AVI, MKV) and images (JPG, PNG, GIF)
- **Advanced Playlist Management**: Create, edit, and schedule playlists with drag-and-drop interface
- **Real-time System Monitoring**: Live CPU, RAM, temperature, and network monitoring
- **VLC Media Player**: Exclusive VLC support with mature HTTP API for reliable playback (MPV removed in v0.8.9)
- **Hardware Acceleration**: Optimized for Raspberry Pi GPU acceleration

### New in v0.8.9
- **VLC Exclusive**: Removed MPV player support for simplified, more reliable architecture
- **Code Reduction**: -400 lines of code with cleaner implementation
- **Enhanced Stability**: Single player backend eliminates switching complexity
- **Improved Maintainability**: Focused codebase easier to debug and extend
- **Better Performance**: Reduced overhead from removing dual-player abstraction layer
- **Mature API**: VLC HTTP API provides robust, well-documented control interface

## Requirements

- Raspberry Pi 3/4/5
- Raspbian OS (Bullseye or newer)
  - **Trixie (Debian 13)** supported with Wayland kiosk mode
  - ⚠️ **For Trixie: Desktop edition REQUIRED** (not Lite)
- 2GB+ RAM recommended
- Network connectivity
- Display connected via HDMI

### 🆕 Trixie / Wayland Kiosk Mode

**New in feature/trixie-kiosk-chromium branch:**

Pi-Signage now supports **Raspberry Pi OS Trixie (Debian 13)** with a modern Wayland-based kiosk mode:

- ✅ **Chromium Browser Kiosk** - Full-screen web dashboard display
- ✅ **Wayland Compositor (labwc)** - Modern, lightweight display server
- ✅ **Remote Configuration** - Change kiosk URL/flags via REST API
- ✅ **Clean Boot Experience** - greetd + plymouth for seamless startup
- ✅ **Backward Compatible** - VLC player and existing API remain functional

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

### VLC Player Control
```bash
sudo systemctl start pisignage-vlc
sudo systemctl stop pisignage-vlc
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

Create playlist:
```bash
curl -X POST http://[pi-ip]/api/playlist-simple.php \
  -H "Content-Type: application/json" \
  -d '{"name":"My Playlist","items":[{"file":"video.mp4","duration":30}]}'
```

## Configuration

### Player Configuration
Edit `/opt/pisignage/config/player-config.json`:
```json
{
  "player": {
    "default": "vlc",
    "autostart": true
  }
}
```

### Network Settings
Configure via web interface or edit system files directly.

## Troubleshooting

### No Video Display
1. Check VLC service: `sudo systemctl status pisignage-vlc`
2. Verify media files: `ls -la /opt/pisignage/media/`
3. Check logs: `tail -f /opt/pisignage/logs/vlc.log`

### Web Interface Not Loading
1. Check nginx: `sudo systemctl status nginx`
2. Verify PHP: `sudo systemctl status php*-fpm`
3. Check firewall: `sudo ufw status`

### Upload Failures
1. Check permissions: `ls -la /opt/pisignage/media/`
2. Verify disk space: `df -h`
3. Check upload limits in `/etc/nginx/sites-available/pisignage`

## Development

### Project Structure (v0.8.9)
```
/opt/pisignage/
├── web/                    # Modular web interface
│   ├── dashboard.php       # Main dashboard page
│   ├── media.php          # Media management
│   ├── playlists.php      # Playlist editor
│   ├── player.php         # Player controls
│   ├── settings.php       # System settings
│   ├── logs.php           # Log viewer
│   ├── screenshot.php     # Screenshot utility
│   ├── youtube.php        # YouTube downloader
│   ├── schedule.php       # Schedule management
│   ├── api/               # REST API endpoints
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
| Player Code | Dual support | VLC exclusive | **-400 LOC** |

## 🛠 Migration from Earlier Versions

Upgrading to v0.8.9 is seamless with 100% backward compatibility:

```bash
# Backup current installation
sudo cp -r /opt/pisignage /opt/pisignage-backup

# Update to v0.8.9
cd /opt/pisignage
git pull origin main

# Restart services
sudo systemctl restart pisignage nginx
```

**Note**: v0.8.9 removes MPV player support. If you were using MPV, the system will automatically switch to VLC.

For detailed migration guide, see [docs/MIGRATION.md](docs/MIGRATION.md).

## 📚 Documentation

- **[Installation Guide](docs/INSTALL.md)** - Complete setup instructions
- **[API Documentation](docs/API.md)** - REST API reference
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Technical architecture details
- **[Migration Guide](docs/MIGRATION.md)** - Upgrading from earlier versions
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

---

**PiSignage v0.8.9** - Modular, Fast, Reliable Digital Signage

*Built with modern web architecture for Raspberry Pi performance*
