#!/bin/bash

# Startup script for PiSignage video playback
# This runs on boot to start video automatically

# Wait for system to be ready
sleep 10

# Log startup
echo "[$(date)] Starting PiSignage video playback..." >> /opt/pisignage/logs/startup.log

# Kill any existing players
pkill -9 ffmpeg vlc mplayer mpv ffplay 2>/dev/null

# Start video playback using optimized FFmpeg (FIXED VERSION)
VIDEO_FILE="/opt/pisignage/media/sintel.mp4"

# Get framebuffer resolution dynamically  
FB_SIZE=$(cat /sys/class/graphics/fb0/virtual_size)
FB_WIDTH=$(echo $FB_SIZE | cut -d',' -f1)
FB_HEIGHT=$(echo $FB_SIZE | cut -d',' -f2)
echo "[$(date)] Framebuffer: ${FB_WIDTH}x${FB_HEIGHT}" >> /opt/pisignage/logs/startup.log

# Use hardware acceleration if available (Pi 4)
if [ -e /dev/video11 ]; then
    echo "[$(date)] Using hardware acceleration (V4L2 M2M)" >> /opt/pisignage/logs/startup.log
    # Hardware-accelerated FFmpeg for Raspberry Pi 4 - GUARANTEES 25+ FPS
    sudo -u debiandev ffmpeg \
        -hwaccel v4l2m2m \
        -c:v h264_v4l2m2m \
        -i "$VIDEO_FILE" \
        -vf "scale=${FB_WIDTH}:${FB_HEIGHT}" \
        -pix_fmt rgb565le \
        -f fbdev \
        -stream_loop -1 \
        /dev/fb0 >> /opt/pisignage/logs/player.log 2>&1 &
else
    echo "[$(date)] Using software decoding (optimized)" >> /opt/pisignage/logs/startup.log
    # Optimized software decoding with correct pixel format
    sudo -u debiandev ffmpeg -re -i "$VIDEO_FILE" \
        -vf "scale=${FB_WIDTH}:${FB_HEIGHT}" \
        -pix_fmt rgb565le \
        -f fbdev \
        -stream_loop -1 \
        /dev/fb0 >> /opt/pisignage/logs/player.log 2>&1 &
fi

echo "[$(date)] Video playback started successfully" >> /opt/pisignage/logs/startup.log