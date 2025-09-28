# PiSignage - Raspberry Pi Deployment Guide

## Quick Deploy to Raspberry Pi

### From Development Machine (x86_64) to Pi:

```bash
cd /opt/pisignage
./deploy-to-pi.sh raspberrypi.local pi
```

### Direct on Raspberry Pi:

```bash
wget https://raw.githubusercontent.com/your-repo/pisignage/main/deploy-to-pi.sh
sudo bash deploy-to-pi.sh
```

## Test Installation

```bash
sudo /opt/pisignage/test-on-pi.sh
```

## Hardware Configurations

### Raspberry Pi 4/5:
- GPU Memory: 128MB minimum
- Hardware Decoder: DRM/V4L2
- Display: HDMI up to 4K

### Raspberry Pi 3:
- GPU Memory: 128MB
- Hardware Decoder: MMAL
- Display: HDMI 1080p max

## Services

- `pisignage.service` - Core management service
- `pisignage-display.service` - VLC display service

## Troubleshooting

1. No video: Check `tvservice -s`
2. High temp: Check `vcgencmd measure_temp`
3. API issues: Check `curl http://localhost/api/system.php?action=stats`

## Files Locations

- Web Interface: `/opt/pisignage/web/`
- Media Files: `/opt/pisignage/media/`
- Playlists: `/opt/pisignage/playlists/`
- Logs: `/opt/pisignage/logs/`
