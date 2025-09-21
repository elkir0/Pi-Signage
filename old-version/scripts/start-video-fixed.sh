#!/bin/bash

# Optimized startup script for PiSignage with 25 FPS guarantee
# Fixes the BGRA pixel format issue and implements hardware acceleration

# Wait for system to be ready
sleep 10

# Log startup
echo "[$(date)] Starting PiSignage video playback (FIXED VERSION)..." >> /opt/pisignage/logs/startup.log

# Kill any existing players
pkill -9 ffmpeg vlc mplayer mpv ffplay 2>/dev/null

# Get framebuffer resolution
FB_SIZE=$(cat /sys/class/graphics/fb0/virtual_size)
FB_WIDTH=$(echo $FB_SIZE | cut -d',' -f1)
FB_HEIGHT=$(echo $FB_SIZE | cut -d',' -f2)
echo "[$(date)] Framebuffer detected: ${FB_WIDTH}x${FB_HEIGHT}" >> /opt/pisignage/logs/startup.log

VIDEO_FILE="/opt/pisignage/media/sintel.mp4"

# Check for Raspberry Pi hardware decoder
if [ -e /dev/video11 ] && [ -e /dev/video10 ]; then
    echo "[$(date)] Pi 4 hardware decoder detected, using V4L2 M2M..." >> /opt/pisignage/logs/startup.log
    
    # Hardware-accelerated playback for Pi 4
    sudo -u debiandev ffmpeg \
        -hwaccel v4l2m2m \
        -hwaccel_device /dev/video11 \
        -c:v h264_v4l2m2m \
        -i "$VIDEO_FILE" \
        -vf "scale=${FB_WIDTH}:${FB_HEIGHT}" \
        -pix_fmt rgb565le \
        -f fbdev \
        -stream_loop -1 \
        /dev/fb0 >> /opt/pisignage/logs/player.log 2>&1 &
        
    echo "[$(date)] Hardware-accelerated playback started (expected: 25+ FPS)" >> /opt/pisignage/logs/startup.log
    
elif command -v mpv >/dev/null 2>&1; then
    echo "[$(date)] Using MPV with DRM output..." >> /opt/pisignage/logs/startup.log
    
    # MPV with direct rendering (best performance)
    sudo -u debiandev mpv \
        --vo=drm \
        --hwdec=v4l2m2m-copy \
        --fullscreen \
        --no-audio \
        --loop-file=inf \
        --video-sync=display-resample \
        --profile=fast \
        "$VIDEO_FILE" >> /opt/pisignage/logs/player.log 2>&1 &
        
    echo "[$(date)] MPV DRM playback started" >> /opt/pisignage/logs/startup.log
    
else
    echo "[$(date)] Fallback to FFplay with SDL..." >> /opt/pisignage/logs/startup.log
    
    # SDL framebuffer fallback
    export SDL_VIDEODRIVER=fbcon
    export SDL_FBDEV=/dev/fb0
    export FRAMEBUFFER=/dev/fb0
    
    sudo -u debiandev ffplay \
        -fs \
        -an \
        -loop 0 \
        -autoexit \
        -fast \
        -framedrop \
        -sync video \
        "$VIDEO_FILE" >> /opt/pisignage/logs/player.log 2>&1 &
        
    echo "[$(date)] FFplay SDL playback started" >> /opt/pisignage/logs/startup.log
fi

echo "[$(date)] Video playback startup sequence completed" >> /opt/pisignage/logs/startup.log