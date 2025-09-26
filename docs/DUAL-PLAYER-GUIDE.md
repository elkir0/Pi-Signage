# Dual-Player Guide - PiSignage v0.8.1

## Overview

PiSignage v0.8.1 includes a dual-player system that allows dynamic switching between VLC and MPV media players. This architecture provides flexibility and hardware-specific optimizations for different Raspberry Pi models.

### Dual-Player System

The dual-player system automatically adapts player configuration based on the detected environment:

- **Automatic detection**: Wayland, X11 or direct DRM
- **Hardware optimization**: Tailored settings for Pi 3, 4 or 5
- **Seamless switching**: No service interruption during player changes
- **Centralized config**: Unified settings in `player-config.json`

### Player Comparison

| Feature | VLC | MPV |
|---------|-----|-----|
| **Performance** | Good, moderate CPU usage | Excellent, GPU-optimized |
| **API** | Complete HTTP REST | Socket IPC + JSON |
| **Compatibility** | Broad format support | Modern formats, high performance |
| **Configuration** | Built-in interface | Text file + command line |
| **Best Use** | Advanced control, streaming | Continuous high-performance display |
| **System Default** | VLC (compatibility) | - |

---

## System Architecture

### File Structure

```
/opt/pisignage/
├── config/
│   └── player-config.json              # Centralized dual-player config
├── scripts/
│   └── player-manager-v0.8.1.sh        # VLC/MPV management script
├── web/
│   ├── index.php                       # Web interface with dynamic switching
│   └── api/
│       ├── player.php                  # Unified control API
│       └── system.php                  # System API with dual support
└── logs/
    ├── vlc.log                         # VLC-specific logs
    ├── mpv.log                         # MPV-specific logs
    └── pisignage.log                   # System logs
```

### Key Components

#### Main Management Script
The `/opt/pisignage/scripts/player-manager-v0.8.1.sh` file is the core of the dual-player system:

- **Environment detection**: Wayland, X11, or TTY/DRM
- **Automatic configuration**: Environment-optimized arguments
- **Lifecycle management**: Start, stop, switching
- **Monitoring**: Watchdog and health monitoring

#### Centralized Configuration
The `/opt/pisignage/config/player-config.json` file defines:

```json
{
  "player": {
    "default": "vlc",                    // Default player
    "current": "vlc",                    // Currently active player
    "available": ["vlc", "mpv"]          // Available players
  },
  "vlc": {
    "enabled": true,
    "binary": "/usr/bin/cvlc",
    "http_port": 8080,
    "http_password": "signage123",
    "log_file": "/opt/pisignage/logs/vlc.log"
  },
  "mpv": {
    "enabled": true,
    "binary": "/usr/bin/mpv",
    "socket": "/tmp/mpv-socket",
    "log_file": "/opt/pisignage/logs/mpv.log"
  }
}
```

---

## Environment Detection and Adaptation

### Supported Environments

PiSignage v0.8.1 automatically detects the graphics environment:

#### Wayland (Raspberry Pi OS Bookworm)
- **Supported compositors**: labwc, wayfire, weston, sway
- **MPV configuration**: `--gpu-context=wayland --vo=gpu-next`
- **VLC configuration**: `--vout=gles2 --intf=dummy`
- **Environment variables**:
  ```bash
  export GDK_BACKEND=wayland
  export QT_QPA_PLATFORM=wayland
  export SDL_VIDEODRIVER=wayland
  ```

#### X11 (Raspberry Pi OS Legacy)
- **MPV configuration**: `--gpu-context=x11 --vo=gpu`
- **VLC configuration**: `--vout=xcb_x11 --intf=dummy`
- **Environment variables**:
  ```bash
  export GDK_BACKEND=x11
  export QT_QPA_PLATFORM=xcb
  ```

#### TTY/DRM (Kiosk Mode)
- **MPV configuration**: `--vo=drm --gpu-context=drm`
- **VLC configuration**: `--vout=drm --intf=dummy`
- **Hardware acceleration**:
  ```bash
  export LIBVA_DRIVER_NAME=v4l2_request
  export GST_VAAPI_ALL_DRIVERS=1
  ```

### Pi Model Optimizations

#### Raspberry Pi 3/3B+
```json
{
  "mpv_args": "--hwdec=mmal-copy --vo=gpu --cache=yes --demuxer-max-bytes=50MiB",
  "vlc_args": "--vout=mmal_xsplitter --codec=mmal --file-caching=2000"
}
```

#### Raspberry Pi 4/5
```json
{
  "mpv_args": "--hwdec=drm-copy --vo=gpu --cache=yes --demuxer-max-bytes=100MiB --scale=ewa_lanczossharp",
  "vlc_args": "--vout=drm --avcodec-hw=v4l2m2m --file-caching=2000"
}
```

---

## Practical Usage

### Web Interface

#### Access and Navigation
1. **Access URL**: `http://[RASPBERRY-IP]/`
2. **Player Section**: Dedicated tab for player management
3. **Status Indicator**: Real-time display of active player
4. **Switch Button**: One-click VLC ↔ MPV switching

#### Interface Features
- **Visual selection**: Radio buttons showing current player
- **Real-time feedback**: Playback status and media information
- **Unified controls**: Same Play/Stop/Pause buttons for both players
- **Smart switching**: Media and position preservation during switch

### Command Line

#### Main Manager
```bash
# Central management script
/opt/pisignage/scripts/player-manager-v0.8.1.sh [action]

# System actions
start               # Start configured player
stop                # Stop all players
restart             # Restart current player
switch              # Switch VLC ↔ MPV
status              # Detailed system status
test                # Functionality tests
```

#### Usage Examples
```bash
# Service startup
sudo systemctl start pisignage
sudo journalctl -u pisignage -f

# Manual switching
sudo -u pi /opt/pisignage/scripts/player-manager-v0.8.1.sh switch
sudo -u pi /opt/pisignage/scripts/player-manager-v0.8.1.sh status

# Individual tests
sudo -u pi /opt/pisignage/scripts/player-manager-v0.8.1.sh test
```

### Systemd Service

The `pisignage` service automatically manages the dual-player:

```bash
# Service control
sudo systemctl start pisignage         # Start
sudo systemctl stop pisignage          # Stop
sudo systemctl restart pisignage       # Restart
sudo systemctl status pisignage        # Detailed status

# Service configuration
sudo systemctl enable pisignage        # Enable at boot
sudo systemctl disable pisignage       # Disable at boot

# Monitoring
sudo journalctl -u pisignage -f        # Real-time logs
sudo journalctl -u pisignage --since "1 hour ago"  # Recent logs
```

---

## Control API

### Player Management Endpoints

#### GET /api/player.php
Returns complete dual-player system status.

**Response:**
```json
{
  "success": true,
  "data": {
    "current_player": "vlc",
    "available_players": ["vlc", "mpv"],
    "status": "VLC running",
    "running": true,
    "media_info": {
      "current_file": "BigBuckBunny_720p.mp4",
      "duration": 596.0,
      "position": 125.7
    }
  }
}
```

#### GET /api/player.php?action=current
Returns only the current player.

**Response:
```json
{
  "success": true,
  "current_player": "vlc"
}
```

#### POST /api/player.php
Player control and switching.

**Available actions:**

##### Player switching
```json
{
  "action": "switch"
}
```

##### Playback control
```json
{
  "action": "play"     // Start playback
}
```

```json
{
  "action": "stop"     // Stop playback
}
```

```json
{
  "action": "pause"    // Pause playback
}
```

##### Media control
```json
{
  "action": "next"     // Next media
}
```

```json
{
  "action": "previous" // Previous media
}
```

##### Volume control
```json
{
  "action": "volume",
  "value": 75          // Volume from 0 to 100
}
```

#### POST /api/system.php
Advanced system actions.

```json
{
  "action": "switch-player"    // System switching
}
```

```json
{
  "action": "restart-player"   // Restart current player
}
```

### Integration Examples

#### Modern JavaScript
```javascript
// Dual-player management class
class PiSignagePlayer {
    constructor(baseUrl = '') {
        this.baseUrl = baseUrl;
    }

    async getCurrentPlayer() {
        const response = await fetch(`${this.baseUrl}/api/player.php?action=current`);
        const data = await response.json();
        return data.current_player;
    }

    async switchPlayer() {
        const response = await fetch(`${this.baseUrl}/api/player.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'switch' })
        });
        return response.json();
    }

    async controlPlayback(action, value = null) {
        const payload = { action };
        if (value !== null) payload.value = value;

        const response = await fetch(`${this.baseUrl}/api/player.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        return response.json();
    }
}

// Usage
const player = new PiSignagePlayer();
await player.switchPlayer();
await player.controlPlayback('play');
await player.controlPlayback('volume', 80);
```

#### Python for Automation
```python
import requests
import json

class PiSignageController:
    def __init__(self, host):
        self.base_url = f"http://{host}"

    def get_player_status(self):
        response = requests.get(f"{self.base_url}/api/player.php")
        return response.json()

    def switch_player(self):
        response = requests.post(
            f"{self.base_url}/api/player.php",
            json={"action": "switch"}
        )
        return response.json()

    def control_playback(self, action, **kwargs):
        payload = {"action": action, **kwargs}
        response = requests.post(
            f"{self.base_url}/api/player.php",
            json=payload
        )
        return response.json()

# Usage
controller = PiSignageController("192.168.1.100")
status = controller.get_player_status()
print(f"Current player: {status['data']['current_player']}")

# Automatic context-based switching
if status['data']['current_player'] == 'vlc':
    controller.switch_player()  # Switch to MPV for performance
```

---

## Advanced Configuration

### Custom Player Configurations

#### Custom VLC Configuration
```bash
# Create optimized VLC configuration
mkdir -p /home/pi/.config/vlc
cat > /home/pi/.config/vlc/vlcrc << 'EOF'
[core]
intf=dummy
vout=drm
fullscreen=1
loop=1
no-video-title-show=1
quiet=1
file-caching=3000
network-caching=5000

[http]
http-host=0.0.0.0
http-port=8080
http-password=signage123
EOF
```

#### Custom MPV Configuration
```bash
# High-performance MPV configuration
mkdir -p /home/pi/.config/mpv
cat > /home/pi/.config/mpv/mpv.conf << 'EOF'
# Video optimizations
vo=drm
hwdec=drm-copy
fullscreen=yes
loop-playlist=inf

# Performance optimizations
cache=yes
demuxer-max-bytes=100MiB
cache-default=8000

# Image quality
scale=ewa_lanczossharp
video-sync=display-resample
interpolation=yes

# Interface
quiet=yes
no-terminal=yes
no-input-default-bindings=yes

# Logs
log-file=/opt/pisignage/logs/mpv.log
EOF
```

### Automatic Switching Scripts

#### Media Type-Based Switching
```bash
#!/bin/bash
# Intelligent content-based switching script

MEDIA_PATH="/opt/pisignage/media"
CURRENT_MEDIA=$(ls "$MEDIA_PATH" | head -1)

case "$CURRENT_MEDIA" in
    *.mp4|*.mkv|*.avi)
        # Videos: use MPV for performance
        /opt/pisignage/scripts/player-manager-v0.8.1.sh switch-to mpv
        ;;
    *.jpg|*.png|*.gif)
        # Images: use VLC for compatibility
        /opt/pisignage/scripts/player-manager-v0.8.1.sh switch-to vlc
        ;;
    *)
        # Default: VLC
        /opt/pisignage/scripts/player-manager-v0.8.1.sh switch-to vlc
        ;;
esac
```

#### Time-Based Switching
```bash
#!/bin/bash
# Time-based switching (example: MPV at night for power saving)

HOUR=$(date +%H)

if [ "$HOUR" -ge 22 ] || [ "$HOUR" -le 6 ]; then
    # Night: MPV more power efficient
    DESIRED_PLAYER="mpv"
else
    # Day: VLC more versatile
    DESIRED_PLAYER="vlc"
fi

CURRENT_PLAYER=$(curl -s http://localhost/api/player.php?action=current | jq -r .current_player)

if [ "$CURRENT_PLAYER" != "$DESIRED_PLAYER" ]; then
    curl -X POST http://localhost/api/player.php \
         -H "Content-Type: application/json" \
         -d '{"action": "switch"}'
    echo "Switched to $DESIRED_PLAYER"
fi
```

---

## Monitoring and Surveillance

### Real-Time Monitoring

#### System Monitoring Script
```bash
#!/bin/bash
# Real-time dual-player monitoring

while true; do
    clear
    echo "=== PiSignage Dual-Player Monitor ==="
    echo "$(date)"
    echo ""

    # Player status
    echo "=== Players ==="
    VLC_PID=$(pgrep vlc)
    MPV_PID=$(pgrep mpv)

    if [ -n "$VLC_PID" ]; then
        echo "✓ VLC: Active (PID: $VLC_PID)"
        VLC_CPU=$(ps -p "$VLC_PID" -o %cpu --no-headers 2>/dev/null || echo "N/A")
        VLC_MEM=$(ps -p "$VLC_PID" -o %mem --no-headers 2>/dev/null || echo "N/A")
        echo "  CPU: ${VLC_CPU}% | RAM: ${VLC_MEM}%"
    else
        echo "✗ VLC: Inactive"
    fi

    if [ -n "$MPV_PID" ]; then
        echo "✓ MPV: Active (PID: $MPV_PID)"
        MPV_CPU=$(ps -p "$MPV_PID" -o %cpu --no-headers 2>/dev/null || echo "N/A")
        MPV_MEM=$(ps -p "$MPV_PID" -o %mem --no-headers 2>/dev/null || echo "N/A")
        echo "  CPU: ${MPV_CPU}% | RAM: ${MPV_MEM}%"
    else
        echo "✗ MPV: Inactive"
    fi

    # System
    echo ""
    echo "=== System ==="
    echo "Temperature: $(vcgencmd measure_temp)"
    echo "GPU Memory: $(vcgencmd get_config gpu_mem)MB"
    echo "Throttling: $(vcgencmd get_throttled)"

    # API Test
    echo ""
    echo "=== API ==="
    CURRENT_PLAYER=$(curl -s http://localhost/api/player.php?action=current 2>/dev/null | jq -r .current_player 2>/dev/null || echo "N/A")
    echo "Current player: $CURRENT_PLAYER"

    sleep 5
done
```

### Centralized Logging

#### Advanced Logging Configuration
```bash
# Create rotating log system
cat > /etc/logrotate.d/pisignage << 'EOF'
/opt/pisignage/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        systemctl reload pisignage 2>/dev/null || true
    endscript
}
EOF
```

#### Log Analysis
```bash
#!/bin/bash
# Dual-player log analyzer

LOG_DIR="/opt/pisignage/logs"

echo "=== PiSignage Log Analysis ==="
echo ""

# Recent errors
echo "Recent errors (last 24h):"
find "$LOG_DIR" -name "*.log" -mtime -1 -exec grep -l "ERROR\|CRITICAL\|FATAL" {} \; | \
while read logfile; do
    echo "- $(basename "$logfile"):"
    grep "ERROR\|CRITICAL\|FATAL" "$logfile" | tail -3 | sed 's/^/  /'
done

# Player switches
echo ""
echo "Recent switches:"
grep -h "switch\|basculement\|Switching" "$LOG_DIR"/*.log 2>/dev/null | tail -5

# Performance
echo ""
echo "Player performance:"
for player in vlc mpv; do
    logfile="$LOG_DIR/${player}.log"
    if [ -f "$logfile" ]; then
        errors=$(grep -c "error\|failed" "$logfile" 2>/dev/null || echo "0")
        warnings=$(grep -c "warning\|warn" "$logfile" 2>/dev/null || echo "0")
        echo "$player: $errors errors, $warnings warnings"
    fi
done
```

---

## Specialized Troubleshooting

### Switching Issues

#### Switching Not Working
```bash
# Step-by-step diagnostic
echo "=== Dual-player switching diagnostic ==="

# 1. Check configuration
echo "1. Current configuration:"
cat /opt/pisignage/config/player-config.json | jq .player

# 2. Test switching API
echo "2. Switching API test:"
curl -X POST http://localhost/api/player.php \
     -H "Content-Type: application/json" \
     -d '{"action": "switch"}' | jq .

# 3. Check permissions
echo "3. Script permissions:"
ls -la /opt/pisignage/scripts/player-manager-v0.8.1.sh

# 4. Manual script test
echo "4. Manual test:"
sudo -u pi /opt/pisignage/scripts/player-manager-v0.8.1.sh switch
```

#### Players Won't Start After Switching
```bash
# Complete dual-player reset
#!/bin/bash

echo "Resetting dual-player system..."

# 1. Complete shutdown
sudo systemctl stop pisignage
sudo pkill -9 vlc mpv
sleep 2

# 2. Clean temporary files
sudo rm -f /tmp/mpv-socket
sudo rm -f /tmp/vlc-*.sock
sudo rm -f /var/run/pisignage.*

# 3. Reset configurations
sudo -u pi mkdir -p /home/pi/.config/{vlc,mpv}
wget -O /tmp/vlcrc https://raw.githubusercontent.com/elkir0/Pi-Signage/main/config/vlc-default.conf
wget -O /tmp/mpv.conf https://raw.githubusercontent.com/elkir0/Pi-Signage/main/config/mpv-default.conf
sudo -u pi cp /tmp/vlcrc /home/pi/.config/vlc/vlcrc
sudo -u pi cp /tmp/mpv.conf /home/pi/.config/mpv/mpv.conf

# 4. Service restart
sudo systemctl start pisignage
echo "Reset complete. Check logs:"
echo "sudo journalctl -u pisignage -f"
```

### Performance Issues

#### Stuttering Playback Despite Optimization
```bash
# In-depth performance diagnostic
#!/bin/bash

echo "=== Player performance diagnostic ==="

# GPU capabilities test
echo "1. GPU capabilities:"
vcgencmd get_config gpu_mem
vcgencmd measure_clock gpu
vcgencmd measure_temp

# MPV hardware acceleration test
echo "2. MPV acceleration test:"
timeout 10s mpv --hwdec=drm-copy --vo=drm /opt/pisignage/media/*.mp4 --really-quiet --length=5 2>&1 | \
    grep -E "(hwdec|vo|ERROR)" || echo "Test OK"

# VLC hardware acceleration test
echo "3. VLC acceleration test:"
timeout 10s cvlc --vout=drm --avcodec-hw=v4l2m2m /opt/pisignage/media/*.mp4 --run-time=5 \
    --intf=dummy 2>&1 | grep -E "(mmal|v4l2|error)" || echo "Test OK"

# Codec verification
echo "4. Codec support:"
ffmpeg -codecs 2>/dev/null | grep -E "(h264|hevc)" | head -3
```

#### Automatic Pi-Based Optimization
```bash
#!/bin/bash
# Automatic optimization script based on Pi model

PI_MODEL=$(grep Model /proc/cpuinfo | cut -d: -f2 | xargs)
echo "Detected Pi model: $PI_MODEL"

case "$PI_MODEL" in
    *"Pi 3"*)
        echo "Configuring Pi 3..."
        # Pi 3 optimizations
        cat > /home/pi/.config/mpv/mpv.conf << 'EOF'
vo=drm
hwdec=mmal-copy
cache=yes
demuxer-max-bytes=50MiB
scale=bilinear
EOF

        cat > /home/pi/.config/vlc/vlcrc << 'EOF'
[core]
vout=mmal_xsplitter
codec=mmal
file-caching=2000
EOF
        ;;

    *"Pi 4"*|*"Pi 5"*)
        echo "Configuring Pi 4/5..."
        # Pi 4/5 optimizations
        cat > /home/pi/.config/mpv/mpv.conf << 'EOF'
vo=drm
hwdec=drm-copy
cache=yes
demuxer-max-bytes=100MiB
scale=ewa_lanczossharp
video-sync=display-resample
EOF

        cat > /home/pi/.config/vlc/vlcrc << 'EOF'
[core]
vout=drm
avcodec-hw=v4l2m2m
file-caching=2000
network-caching=3000
EOF
        ;;
esac

echo "Configuration applied. Restarting service..."
sudo systemctl restart pisignage
```

---

## Support and Resources

### Reference Documentation

- **System configuration**: `/opt/pisignage/config/player-config.json`
- **Main script**: `/opt/pisignage/scripts/player-manager-v0.8.1.sh`
- **API endpoints**: `/opt/pisignage/docs/API.md`
- **System logs**: `/opt/pisignage/logs/`

### Quick Diagnostic Commands

```bash
# Complete dual-player system status
curl -s http://localhost/api/player.php | jq .

# Real-time logs
sudo journalctl -u pisignage -f

# Switching test
curl -X POST http://localhost/api/player.php -d '{"action":"switch"}' -H "Content-Type: application/json"

# Active processes
ps aux | grep -E "(vlc|mpv)" | grep -v grep
```

### Community Support

- **GitHub Issues**: https://github.com/elkir0/Pi-Signage/issues
- **Discussions**: Create an issue with "question" label
- **Contributions**: Pull requests welcome to improve dual-player system

### Final Validation Checklist

#### Successful Dual-Player Installation
- [ ] VLC and MPV installed (`cvlc --version && mpv --version`)
- [ ] Systemd service active (`systemctl status pisignage`)
- [ ] Web interface accessible (`curl -I http://localhost`)
- [ ] Valid JSON configuration (`jq . /opt/pisignage/config/player-config.json`)

#### Operational Features
- [ ] Web interface switching functional
- [ ] REST API switching functional (`POST /api/player.php`)
- [ ] Video playback working with both players
- [ ] Logs written correctly (`ls -la /opt/pisignage/logs/`)

#### Performance and Stability
- [ ] No errors in system logs (`journalctl -u pisignage`)
- [ ] Pi temperature within limits (`vcgencmd measure_temp`)
- [ ] Hardware acceleration active (player logs)
- [ ] Switching without service interruption

The PiSignage v0.8.1 dual-player system provides a modern, flexible approach to multimedia playback on Raspberry Pi, intelligently adapting configuration to hardware capabilities and usage requirements.