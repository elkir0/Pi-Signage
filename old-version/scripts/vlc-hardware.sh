#!/bin/bash

# VLC with Raspberry Pi 4 Hardware Acceleration
# Using V4L2 M2M decoder for proper hardware decoding

export DISPLAY=:0

# Kill any existing video players
pkill -9 vlc mplayer mpv ffplay 2>/dev/null

# Video file
VIDEO_FILE="/opt/pisignage/media/Big_Buck_Bunny.mp4"

# Start VLC with Pi 4 specific hardware acceleration
# Using v4l2 decoder which is the proper method for Pi 4
exec cvlc \
    --fullscreen \
    --no-video-title-show \
    --no-osd \
    --intf dummy \
    --codec avcodec \
    --avcodec-hw v4l2m2m \
    --avcodec-codec-h264_v4l2m2m \
    --no-audio \
    --loop \
    "$VIDEO_FILE"