#!/bin/bash

# Optimized MPlayer for Raspberry Pi 4
# Using all available performance tricks

# Set CPU to performance mode
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1

# Kill existing players
pkill -9 vlc mplayer mpv ffplay 2>/dev/null

VIDEO_FILE="/opt/pisignage/media/sintel.mp4"

# MPlayer with maximum optimization
# - vo fbdev2: Direct framebuffer for lowest overhead  
# - lavdopts with threads for multi-core
# - cache for smooth playback
# - framedrop to maintain FPS
exec mplayer \
    -vo fbdev2 \
    -vf scale=1920:1080 \
    -lavdopts fast:threads=4 \
    -cache 8192 \
    -cache-min 20 \
    -framedrop \
    -quiet \
    -loop 0 \
    "$VIDEO_FILE"