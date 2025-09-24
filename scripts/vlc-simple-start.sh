#!/bin/bash
# Simple VLC start for Raspberry Pi

pkill -f vlc 2>/dev/null
sleep 1

# Start VLC without X11, direct to framebuffer
cvlc --intf dummy \
     --fullscreen \
     --no-video-title-show \
     --vout drm_vout \
     --loop \
     /opt/pisignage/media/*.mp4 \
     > /opt/pisignage/logs/vlc.log 2>&1 &

echo "VLC started (PID: $!)"