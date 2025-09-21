#!/bin/bash

# FFplay with V4L2 M2M hardware decoder for Raspberry Pi 4
# This uses the stateless V4L2 decoder available through /dev/video10-15

export DISPLAY=:0

# Kill existing players
pkill -9 vlc mplayer mpv ffplay 2>/dev/null

VIDEO_FILE="/opt/pisignage/media/Big_Buck_Bunny.mp4"

# Use ffplay with V4L2 M2M hardware decoder
# The h264_v4l2m2m codec uses the Pi's hardware decoder
exec ffplay \
    -fs \
    -an \
    -loop 0 \
    -vcodec h264_v4l2m2m \
    -framerate 25 \
    -framedrop \
    -infbuf \
    "$VIDEO_FILE"