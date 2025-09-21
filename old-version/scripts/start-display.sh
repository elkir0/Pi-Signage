#!/bin/bash
# PiSignage Display Script - v3.0.2
# Fixed for Raspberry Pi OS Desktop with X11 and software rendering

# Wait for display to be ready
sleep 10

# Start HTTP server for video files
cd /opt/pisignage/videos
python3 -m http.server 8080 &
sleep 2

# Start Chromium with software rendering
# Software rendering avoids GPU/DMA buffer issues on some Pi configurations
export DISPLAY=:0
export LIBGL_ALWAYS_SOFTWARE=1

chromium-browser --kiosk --noerrdialogs --disable-infobars --no-first-run \
  --disable-gpu --disable-software-rasterizer --disable-gpu-compositing \
  --autoplay-policy=no-user-gesture-required \
  http://localhost:8080/index.html