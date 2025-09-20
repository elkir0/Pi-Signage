#!/bin/bash

# FFmpeg with correct BGRA pixel format for framebuffer

# Kill existing players  
pkill -9 vlc mplayer mpv ffplay ffmpeg 2>/dev/null

VIDEO_FILE="/opt/pisignage/media/sintel.mp4"

# Use FFmpeg with BGRA format as required by framebuffer
exec ffmpeg -re -i "$VIDEO_FILE" \
    -vf "scale=1920:1080,format=bgra" \
    -pix_fmt bgra \
    -f fbdev \
    /dev/fb0