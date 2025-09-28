# PiSignage v0.8.3

Digital signage solution for Raspberry Pi with web interface and media management.

## Features

- Web-based management interface
- Multiple media format support (video, images)
- Playlist creation and scheduling
- Real-time system monitoring
- Remote control capabilities
- Hardware acceleration support
- Multi-player support (VLC, MPV)

## Requirements

- Raspberry Pi 3/4/5
- Raspbian OS (Bullseye or newer)
- 2GB+ RAM recommended
- Network connectivity
- Display connected via HDMI

## Installation

### Quick Install
```bash
wget https://raw.githubusercontent.com/your-username/PiSignage/main/install.sh
bash install.sh
```

### Manual Install
```bash
git clone https://github.com/your-username/PiSignage.git
cd PiSignage
sudo ./install.sh
```

## Usage

### Access Web Interface
Open browser and navigate to:
```
http://[raspberry-pi-ip]
```

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

### Project Structure
```
/opt/pisignage/
├── web/           # Web interface
│   ├── api/       # REST API endpoints
│   └── assets/    # CSS, JS, images
├── media/         # Media storage
├── scripts/       # System scripts
├── config/        # Configuration files
└── logs/          # Application logs
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

---
Version 0.8.3 - Production Ready
