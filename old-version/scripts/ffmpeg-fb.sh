#!/bin/bash

# FFmpeg direct to framebuffer with hardware decoder for Raspberry Pi 4
# This bypasses X11 entirely for maximum performance

# Kill existing players
pkill -9 vlc mplayer mpv ffplay 2>/dev/null

VIDEO_FILE="/opt/pisignage/media/sintel.mp4"

# Use FFmpeg with V4L2 M2M decoder directly to framebuffer
# This should give us proper 25 FPS hardware accelerated playback
exec ffmpeg \
    -re \
    -c:v h264_v4l2m2m \
    -i "$VIDEO_FILE" \
    -pix_fmt bgra \
    -f fbdev \
    -framerate 25 \
    /dev/fb0