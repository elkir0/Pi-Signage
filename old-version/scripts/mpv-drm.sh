#!/bin/bash

# MPV with DRM/KMS direct rendering for Raspberry Pi 4
# This bypasses X11 entirely for maximum performance

# Kill existing players
pkill -9 vlc mplayer mpv ffplay 2>/dev/null

VIDEO_FILE="/opt/pisignage/media/Big_Buck_Bunny.mp4"

# Use MPV with DRM output (direct to framebuffer)
# This is the most efficient method on Pi 4
exec mpv \
    --vo=gpu \
    --gpu-context=drm \
    --drm-connector=1.HDMI-A-1 \
    --hwdec=v4l2m2m-copy \
    --fullscreen \
    --no-audio \
    --loop-file=inf \
    --fps=25 \
    --video-sync=display-resample \
    "$VIDEO_FILE"