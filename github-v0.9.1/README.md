# 📺 PiSignage - Digital Signage Solution for Raspberry Pi

[![Version](https://img.shields.io/badge/version-0.9.1-blue.svg)](https://github.com/elkir0/Pi-Signage/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%204-red.svg)](https://www.raspberrypi.org/)
[![Performance](https://img.shields.io/badge/performance-30%2B%20FPS-success.svg)](docs/PERFORMANCE.md)

**PiSignage** is a high-performance digital signage solution designed specifically for Raspberry Pi 4. It provides a complete web-based interface for managing video content, playlists, and display configurations with minimal resource usage.

## 🎯 Key Features

- **High Performance**: 30+ FPS video playback with only 7% CPU usage
- **Web Management**: Complete 7-tab interface for remote control
- **YouTube Integration**: Direct video download from YouTube
- **Playlist Management**: Drag-and-drop playlist editor with transitions
- **Scheduling**: Weekly calendar for automated content scheduling
- **Multi-Zone Display**: Configure multiple display zones
- **Real-Time Monitoring**: System stats, temperature, and performance metrics
- **Screenshot Capture**: Live display preview in web interface
- **Large File Support**: Upload videos up to 500MB

## 📊 Performance Metrics

| Metric | Value | Status |
|--------|-------|---------|
| CPU Usage | ~7% | ✅ Excellent |
| RAM Usage | <500MB | ✅ Optimal |
| Frame Rate | 30+ FPS | ✅ Smooth |
| Boot Time | <30s | ✅ Fast |
| Temperature | <60°C | ✅ Normal |

## 🚀 Quick Start

### Prerequisites

- Raspberry Pi 4 (2GB+ RAM recommended)
- Raspberry Pi OS Lite (Bookworm)
- Network connection
- SD Card (16GB+ recommended)

### Installation

```bash
# Clone the repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Run the installation script
chmod +x install.sh
sudo ./install.sh

# The system will automatically reboot and start PiSignage
```

### Access the Interface

After installation, access the web interface:
```
http://[YOUR-PI-IP-ADDRESS]/
```

Default credentials (if prompted):
- Username: `pi`
- Password: `raspberry`

## 📁 Project Structure

```
/opt/pisignage/
├── scripts/          # Control and utility scripts
│   ├── vlc-control.sh
│   ├── screenshot.sh
│   └── youtube-dl.sh
├── web/              # Web interface
│   ├── index-complete.php
│   └── api/         # REST APIs
├── media/           # Video storage
├── config/          # Configuration files
└── logs/            # System logs
```

## 🎮 Web Interface Tabs

1. **Dashboard** - System overview and quick controls
2. **Media** - File management and upload
3. **Playlists** - Create and manage playlists
4. **YouTube** - Download videos from YouTube
5. **Schedule** - Program content by time/date
6. **Display** - Configure screen settings
7. **Settings** - System configuration

## 🛠️ API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/control.php` | POST | Video playback control |
| `/api/playlist.php` | GET/POST | Playlist management |
| `/api/youtube.php` | POST | YouTube download |
| `/api/screenshot.php` | GET | Screen capture |
| `/api/upload.php` | POST | Video upload |

## 📋 Requirements

### Hardware
- Raspberry Pi 4 Model B (2GB+ RAM)
- MicroSD card (16GB minimum, 32GB recommended)
- HDMI display
- Power supply (5V 3A official recommended)
- Network connection (Ethernet or WiFi)

### Software Dependencies
- nginx web server
- PHP 8.2 with FPM
- VLC media player
- yt-dlp (YouTube downloader)
- scrot (screenshot tool)
- X11 minimal (display server)

## 🐛 Bug Fixes (v0.9.1)

### Fixed Issues
1. **YouTube downloads failing** - Installed and configured yt-dlp
2. **Screenshot not working** - Added scrot and imagemagick with fallback methods
3. **Upload error 413** - Configured nginx/PHP for 500MB file uploads

## 📝 Configuration

### Video Formats Supported
- MP4 (recommended)
- AVI
- MKV
- MOV
- WebM

### Display Resolutions
- 1920x1080 (Full HD) - Default
- 1280x720 (HD)
- 3840x2160 (4K) - Experimental

## 🧪 Testing

Run the automated tests:
```bash
# Quick API test
/opt/pisignage/scripts/quick-test.sh

# Full Puppeteer test suite
node /opt/pisignage/scripts/test-puppeteer.js
```

## 📚 Documentation

- [Installation Guide](docs/INSTALL.md)
- [API Documentation](docs/API.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Performance Tuning](docs/PERFORMANCE.md)
- [Changelog](CHANGELOG.md)

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- VLC Media Player for reliable video playback
- yt-dlp team for YouTube download functionality
- Raspberry Pi Foundation for excellent hardware
- Open source community for various tools and libraries

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/elkir0/Pi-Signage/issues)
- **Wiki**: [GitHub Wiki](https://github.com/elkir0/Pi-Signage/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/elkir0/Pi-Signage/discussions)

## 🏆 Project Status

- **Current Version**: 0.9.1
- **Status**: Beta - Production Ready
- **Next Release**: 1.0.0 (Target: Q4 2025)

---

**Made with ❤️ for Raspberry Pi enthusiasts**

*Developed by elkir0 with assistance from Claude AI and Happy Engineering*