# PiSignage - Professional Digital Signage Solution for Raspberry Pi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-4%2B-red.svg)](https://www.raspberrypi.org/)
[![Version](https://img.shields.io/badge/Version-3.1.0-blue.svg)](https://github.com/elkir0/Pi-Signage/releases)
[![Build Status](https://img.shields.io/github/actions/workflow/status/elkir0/Pi-Signage/ci.yml?branch=main)](https://github.com/elkir0/Pi-Signage/actions)

A professional-grade digital signage solution for Raspberry Pi with hardware-accelerated video playback, web-based management interface, and 24/7 reliability.

## 🚀 Features

- **High-Performance Video Playback**: Hardware-accelerated H.264 decoding with 25-30+ FPS
- **Web Management Interface**: Complete control panel for media management and scheduling
- **Multiple Player Engines**: Support for VLC, Chromium Kiosk, and custom players
- **Production Ready**: Designed for 24/7 operation with automatic recovery
- **Easy Installation**: One-command deployment with automated configuration
- **Monitoring & Diagnostics**: Built-in system monitoring and troubleshooting tools
- **RESTful API**: Complete API for remote management and integration
- **Flexible Media Support**: Videos, images, HTML content, and live streams

## 📋 Requirements

- **Raspberry Pi 4** (2GB+ RAM recommended)
- **Raspberry Pi OS** Desktop (Bookworm or Bullseye)
- **Storage**: 16GB+ microSD card or USB SSD (recommended)
- **Power**: Official 5V/3A power supply
- **Display**: HDMI-compatible monitor or TV
- **Network**: Ethernet or Wi-Fi connection

## ⚡ Quick Installation

### 1. Download and Flash Raspberry Pi OS

Download [Raspberry Pi OS Desktop](https://www.raspberrypi.org/software/operating-systems/) and flash to SD card using [Raspberry Pi Imager](https://www.raspberrypi.org/software/).

**Recommended settings:**
- Enable SSH
- Set username: `pi`
- Set password: `your_password`
- Configure Wi-Fi if needed

### 2. Install PiSignage

```bash
# Connect to your Raspberry Pi
ssh pi@YOUR_PI_IP

# Clone the repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Install PiSignage
sudo make install
```

### 3. Access Web Interface

Open your browser and navigate to:
- **Local**: http://YOUR_PI_IP/
- **Management**: http://YOUR_PI_IP/admin/

## 🏗️ Project Structure

```
pisignage/
├── src/                    # Source code
│   ├── scripts/           # Control and utility scripts
│   ├── modules/           # Installation modules
│   ├── config/            # Configuration templates
│   └── systemd/           # Service definitions
├── deploy/                # Deployment scripts
│   ├── install.sh         # Main installer
│   ├── uninstall.sh       # Clean uninstaller
│   └── deploy-web-server.sh # Web server deployment
├── web/                   # Web interface
│   ├── index.php          # Main dashboard
│   ├── api/               # REST API endpoints
│   ├── admin/             # Administration panel
│   └── assets/            # CSS, JS, images
├── docs/                  # Documentation
├── tests/                 # Test suite
├── media/                 # Media storage
├── logs/                  # Application logs
└── archive/               # Legacy files
```

## 🎮 Usage

### Basic Operations

```bash
# Start PiSignage services
make start

# Stop PiSignage services
make stop

# Check service status
make status

# View logs
make logs

# Run tests
make test
```

### Player Control

```bash
# Control media playback
./src/scripts/player-control.sh start
./src/scripts/player-control.sh stop
./src/scripts/player-control.sh restart
./src/scripts/player-control.sh status
```

### Web Interface Features

- **Dashboard**: Real-time system monitoring and player status
- **Media Manager**: Upload, organize, and manage media files
- **Playlist Editor**: Create and schedule playlists
- **System Settings**: Configure display, network, and performance settings
- **Remote Control**: Start, stop, and control playback remotely
- **Logs Viewer**: Monitor system and application logs
- **API Explorer**: Test and integrate with the REST API

## 🔧 Configuration

### Player Selection

Choose your preferred media player:

```bash
# VLC (recommended for stability)
sudo systemctl enable vlc-signage
sudo systemctl start vlc-signage

# Chromium Kiosk (for web content)
sudo systemctl enable chromium-kiosk
sudo systemctl start chromium-kiosk
```

### Performance Optimization

Edit `/boot/config.txt`:

```bash
# GPU memory allocation
gpu_mem=128

# Enable hardware acceleration
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Audio (if needed)
dtparam=audio=on
```

### Network Configuration

Configure static IP in `/etc/dhcpcd.conf`:

```bash
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4
```

## 📊 Performance

### Benchmark Results (Raspberry Pi 4)

| Content Type | Resolution | FPS | CPU Usage | GPU Load | Memory |
|--------------|------------|-----|-----------|----------|---------|
| H.264 Video  | 1080p      | 30  | 15-25%    | Active   | 180MB   |
| H.264 Video  | 720p       | 30  | 8-15%     | Active   | 120MB   |
| HTML Content | 1080p      | 60  | 20-30%    | Active   | 200MB   |
| Image Slideshow | 1080p   | 60  | 5-10%     | Active   | 80MB    |

## 🐛 Troubleshooting

### Common Issues

**Black Screen**
```bash
# Check display configuration
sudo nano /boot/config.txt
# Add: hdmi_force_hotplug=1

# Restart display manager
sudo systemctl restart lightdm
```

**Low Frame Rate**
```bash
# Verify GPU acceleration
glxinfo | grep "OpenGL renderer"

# Check VLC GPU usage
ps aux | grep vlc
```

**Service Not Starting**
```bash
# Check service status
sudo systemctl status vlc-signage

# View detailed logs
sudo journalctl -u vlc-signage -f
```

**Web Interface Not Accessible**
```bash
# Check nginx status
sudo systemctl status nginx

# Check PHP-FPM
sudo systemctl status php8.2-fpm

# Restart web services
make deploy
```

### Diagnostic Tools

```bash
# Run comprehensive diagnostics
./src/scripts/diagnostics.sh

# Test video playback
./tests/test-video-playback.sh

# Check system performance
./src/scripts/performance-monitor.sh
```

## 🔌 API Reference

### REST API Endpoints

```bash
# Get system status
GET /api/status

# Control playback
POST /api/player/start
POST /api/player/stop
POST /api/player/restart

# Manage media
GET /api/media
POST /api/media/upload
DELETE /api/media/{id}

# Playlist management
GET /api/playlists
POST /api/playlists
PUT /api/playlists/{id}
DELETE /api/playlists/{id}
```

### Example Usage

```bash
# Get current status
curl http://YOUR_PI_IP/api/status

# Start playback
curl -X POST http://YOUR_PI_IP/api/player/start

# Upload media
curl -X POST -F "file=@video.mp4" http://YOUR_PI_IP/api/media/upload
```

## 🚀 Development

### Local Development with Docker

```bash
# Start development environment
make dev-start

# View logs
make dev-logs

# Stop development environment
make dev-stop
```

### Running Tests

```bash
# Run all tests
make test

# Run specific test categories
./tests/test-installation.sh
./tests/test-api.sh
./tests/test-performance.sh
```

## 📚 Documentation

- [Installation Guide](docs/INSTALL.md) - Detailed installation instructions
- [User Manual](docs/USER_GUIDE.md) - Complete user guide
- [API Documentation](docs/API.md) - REST API reference
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Development Guide](docs/DEVELOPMENT.md) - Contributing and development setup

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](docs/CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Raspberry Pi Foundation](https://www.raspberrypi.org/) for the amazing hardware
- [VLC Media Player](https://www.videolan.org/vlc/) for reliable media playback
- [Nginx](https://nginx.org/) for high-performance web serving
- The open-source community for continuous inspiration

## 📞 Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/elkir0/Pi-Signage/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/elkir0/Pi-Signage/discussions)
- 📖 **Wiki**: [Project Wiki](https://github.com/elkir0/Pi-Signage/wiki)
- 📧 **Email**: support@pisignage.example.com

## 🌟 Show Your Support

If this project helped you, please consider:
- ⭐ Starring the repository
- 🐛 Reporting bugs and issues
- 💡 Suggesting new features
- 🤝 Contributing code or documentation

---

**Built with ❤️ for the digital signage community**

*Transform your Raspberry Pi into a professional digital signage solution*