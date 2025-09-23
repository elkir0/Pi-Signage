#!/bin/bash

# PiSignage v0.8.0 - Chromium avec optimisations maximales pour Raspberry Pi 4
# Solution basée sur l'analyse : YouTube fonctionne car il force H.264

# Kill anciennes instances
pkill -f chromium
sleep 2

# Configuration GPU Raspberry Pi 4
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Flags optimisés spécifiquement pour Raspberry Pi 4
chromium-browser \
    --kiosk \
    --start-fullscreen \
    --noerrdialogs \
    --disable-infobars \
    --no-first-run \
    --disable-translate \
    --no-default-browser-check \
    --check-for-update-interval=2592000 \
    --disable-background-timer-throttling \
    --disable-renderer-backgrounding \
    --disable-features=TranslateUI \
    --autoplay-policy=no-user-gesture-required \
    --use-gl=egl \
    --enable-gpu-rasterization \
    --enable-oop-rasterization \
    --ignore-gpu-blocklist \
    --disable-software-rasterizer \
    --enable-native-gpu-memory-buffers \
    --enable-zero-copy \
    --enable-features=CanvasOopRasterization \
    --force-video-overlays \
    --memory-pressure-off \
    --max_old_space_size=512 \
    --disable-dev-shm-usage \
    --disable-extensions \
    --disable-plugins \
    --disable-smooth-scrolling \
    --disable-office-editing-component-extension \
    --disable-background-networking \
    --disable-breakpad \
    --disable-component-extensions-with-background-pages \
    --disable-default-apps \
    --disable-features=AudioServiceOutOfProcess \
    --disable-print-preview \
    --disable-setuid-sandbox \
    --disable-site-isolation-trials \
    --disable-speech-api \
    --disable-sync \
    --disable-web-resources \
    --enable-unsafe-webgpu \
    --in-process-gpu \
    --no-sandbox \
    http://localhost/player-optimized.html &

echo "Chromium lancé avec optimisations maximales pour Raspberry Pi 4"