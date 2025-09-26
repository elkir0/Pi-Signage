#!/bin/bash
# PiSignage - Start VLC in capturable mode
# Optimisé pour Raspberry Pi avec support screenshot

VIDEO_FILE="${1:-/opt/pisignage/media/BigBuckBunny_720p.mp4}"

# Kill existing VLC instances
pkill vlc 2>/dev/null
sleep 1

# Detect display environment
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "Starting VLC with Wayland output..."
    VLC_OUTPUT="--vout wayland"
elif [ -n "$DISPLAY" ]; then
    echo "Starting VLC with X11 output..."
    VLC_OUTPUT="--vout x11"
else
    echo "Starting VLC with DRM output (screenshot limited)..."
    VLC_OUTPUT="--vout drm_vout"
fi

# Start VLC with HTTP interface for snapshots
cvlc \
    --intf http \
    --http-host 0.0.0.0 \
    --http-port 8080 \
    --http-password pisignage \
    $VLC_OUTPUT \
    --fullscreen \
    --loop \
    --no-video-title \
    --quiet \
    "$VIDEO_FILE" > /opt/pisignage/logs/vlc.log 2>&1 &

VLC_PID=$!
echo "VLC started with PID: $VLC_PID"
echo "HTTP interface available at: http://localhost:8080 (password: pisignage)"

# Save PID for management
echo $VLC_PID > /tmp/vlc.pid

exit 0