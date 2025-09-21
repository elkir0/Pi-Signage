#!/bin/bash

# MPV with V4L2 M2M hardware acceleration for Raspberry Pi 4
# This is the correct hardware decoder for Pi 4

export DISPLAY=:0

# Kill existing players
pkill -9 vlc mplayer mpv ffplay 2>/dev/null

VIDEO_FILE="/opt/pisignage/media/sintel.mp4"

# Start MPV with V4L2 M2M hardware decoder
exec mpv \
    --hwdec=v4l2m2m-copy \
    --vo=x11 \
    --fullscreen \
    --no-audio \
    --loop-file=inf \
    --framedrop=no \
    "$VIDEO_FILE"