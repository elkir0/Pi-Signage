#!/bin/bash

echo "=== FORCER CHROMIUM À UTILISER LE GPU ==="
echo ""

# Tuer tous les Chromium
pkill -f chromium
sleep 2

# Variables d'environnement pour forcer le GPU hardware
export DISPLAY=:0
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_GL_VERSION_OVERRIDE=3.3
export CHROMIUM_FLAGS="--use-gl=desktop --enable-gpu"

# Lancer Chromium avec les bons flags SANS que Chromium les override
/usr/lib/chromium/chromium \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --autoplay-policy=no-user-gesture-required \
    --enable-gpu \
    --use-gl=desktop \
    --enable-gpu-rasterization \
    --enable-accelerated-2d-canvas \
    --enable-accelerated-video-decode \
    --ignore-gpu-blocklist \
    --disable-software-rasterizer \
    --enable-native-gpu-memory-buffers \
    --enable-features=VaapiVideoDecoder \
    --disable-features=UseChromeOSDirectVideoDecoder \
    --show-fps-counter \
    --no-sandbox \
    file:///home/pi/video-test.html 2>&1 | grep -E "(FPS|GL|GPU|angle)" &

echo "Chromium lancé avec --use-gl=desktop (pas swiftshader!)"
echo ""
echo "Vérification dans 5 secondes..."
sleep 5

echo "Process GPU:"
ps aux | grep chromium | grep gpu | head -2

echo ""
echo "Si ça utilise encore SwiftShader, on teste avec Firefox:"
echo "firefox-esr --kiosk file:///home/pi/video-test.html"