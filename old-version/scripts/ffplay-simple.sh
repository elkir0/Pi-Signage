#!/bin/bash

# Simple FFplay with SDL framebuffer output

# Kill existing players
pkill -9 vlc mplayer mpv ffplay 2>/dev/null

VIDEO_FILE="/opt/pisignage/media/sintel.mp4"

# Use FFplay with SDL framebuffer driver
export SDL_VIDEODRIVER=fbcon
export SDL_FBDEV=/dev/fb0

exec ffplay \
    -fs \
    -an \
    -loop 0 \
    -autoexit \
    -fast \
    "$VIDEO_FILE"