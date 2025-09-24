#!/bin/bash
# PiSignage - Start VLC on framebuffer/DRM

MEDIA_DIR="/opt/pisignage/media"
LOG_FILE="/opt/pisignage/logs/vlc.log"

# Kill any existing VLC
pkill -f vlc 2>/dev/null
sleep 1

# Try different video output modules
echo "Starting VLC with framebuffer/DRM output..." > $LOG_FILE

# Option 1: Try DRM output (direct rendering)
cvlc --fullscreen \
     --intf dummy \
     --no-video-title-show \
     --vout drm_vout \
     --drm-vout-display HDMI-A-1 \
     --loop \
     "$MEDIA_DIR"/*.mp4 \
     >> $LOG_FILE 2>&1 &

VLC_PID=$!
sleep 3

# Check if VLC is still running
if ! kill -0 $VLC_PID 2>/dev/null; then
    echo "DRM output failed, trying framebuffer..." >> $LOG_FILE

    # Option 2: Try framebuffer output
    cvlc --fullscreen \
         --intf dummy \
         --no-video-title-show \
         --vout fb \
         --fbdev /dev/fb0 \
         --loop \
         "$MEDIA_DIR"/*.mp4 \
         >> $LOG_FILE 2>&1 &

    VLC_PID=$!
    sleep 3
fi

# Check if VLC is still running
if ! kill -0 $VLC_PID 2>/dev/null; then
    echo "Framebuffer output failed, trying mmal..." >> $LOG_FILE

    # Option 3: Try MMAL (Raspberry Pi specific)
    cvlc --fullscreen \
         --intf dummy \
         --no-video-title-show \
         --vout mmal_vout \
         --loop \
         "$MEDIA_DIR"/*.mp4 \
         >> $LOG_FILE 2>&1 &

    VLC_PID=$!
    sleep 3
fi

# Check if VLC is still running
if ! kill -0 $VLC_PID 2>/dev/null; then
    echo "MMAL output failed, trying without display..." >> $LOG_FILE

    # Option 4: Try without DISPLAY variable
    unset DISPLAY
    cvlc --fullscreen \
         --intf dummy \
         --no-video-title-show \
         --loop \
         "$MEDIA_DIR"/*.mp4 \
         >> $LOG_FILE 2>&1 &

    VLC_PID=$!
fi

echo "VLC started with PID: $VLC_PID" >> $LOG_FILE
echo "VLC started"