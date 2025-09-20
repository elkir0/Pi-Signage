#!/bin/bash

# VLC for x86_64 Linux with proper configuration
# This system is NOT a Raspberry Pi!

export DISPLAY=:0

# Kill existing players
pkill -9 vlc mplayer mpv ffplay 2>/dev/null

VIDEO_FILE="/opt/pisignage/media/sintel.mp4"

# Start VLC with x86 optimizations
# No Pi-specific hardware acceleration needed
exec cvlc \
    --fullscreen \
    --no-video-title-show \
    --no-osd \
    --intf dummy \
    --vout x11 \
    --no-audio \
    --loop \
    "$VIDEO_FILE"