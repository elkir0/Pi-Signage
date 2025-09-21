#!/bin/bash

# VLC with framebuffer output for headless systems

# Kill existing players
pkill -9 vlc mplayer mpv ffplay 2>/dev/null

VIDEO_FILE="/opt/pisignage/media/sintel.mp4"

# Start VLC with framebuffer output
# Using fb video output for direct framebuffer access
exec cvlc \
    --intf dummy \
    --vout fb \
    --fbdev /dev/fb0 \
    --no-audio \
    --loop \
    "$VIDEO_FILE"