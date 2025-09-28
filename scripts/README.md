# PiSignage v0.8.5 Scripts

> **Note**: Scripts are fully compatible with the new v0.8.5 modular architecture

## Production Scripts

### player-manager-v0.8.1.sh (Compatible with v0.8.5)
Main player management script that handles VLC and MPV players.
- Controls playback (play, pause, stop, next, previous)
- Manages volume and display settings
- Handles player switching between VLC and MPV
- **v0.8.5**: Integrates seamlessly with new modular player.php interface

### start-vlc-production.sh
Production VLC launcher script.
- Starts VLC in fullscreen loop mode
- Configured for DRM output on Raspberry Pi
- Auto-restarts on failure

### vlc-final.sh
Final VLC configuration and startup script.
- Optimized settings for digital signage
- Hardware acceleration enabled
- Network streaming capabilities

### screenshot.sh
Basic screenshot utility.
- Takes screenshots using available tools
- Supports X11 and framebuffer capture

### screenshot-wayland.sh
Wayland-specific screenshot implementation.
- Uses grim for Wayland compositors
- Fallback to other methods if unavailable

### install-raspi2png.sh
Installer for raspi2png tool.
- Specific to Raspberry Pi hardware
- Enables direct framebuffer capture

## Usage

All scripts should be executed with appropriate permissions:
```bash
sudo ./script-name.sh
```

## Environment Variables

- `DISPLAY`: X11 display (usually :0)
- `XDG_RUNTIME_DIR`: Runtime directory for user session
- `PISIGNAGE_HOME`: Base directory (/opt/pisignage)

## v0.8.5 Integration

All scripts maintain compatibility with the new modular architecture:
- **Web Interface**: Scripts work with individual PHP modules (player.php, media.php, etc.)
- **API Endpoints**: RESTful API calls remain unchanged
- **Performance**: Scripts benefit from 80% faster web interface loading
- **Reliability**: Improved stability due to modular navigation system