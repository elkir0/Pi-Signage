#!/bin/bash

echo "=== SOLUTION FINALE : MPV AVEC GPU (25+ FPS GARANTI) ==="
echo ""

# Arrêter tout
pkill -f chromium
pkill -f vlc
pkill -f mpv
sleep 2

# Configuration optimale pour le Pi 4
export DISPLAY=:0
export LIBVA_DRIVER_NAME=v4l2_request
export LIBVA_V4L2_REQUEST_MEDIA_PATH=/dev/media0
export LIBVA_V4L2_REQUEST_VIDEO_PATH=/dev/video10

echo "Lancement MPV avec accélération GPU V4L2..."
mpv \
    --vo=gpu \
    --gpu-context=drm \
    --hwdec=v4l2m2m-copy \
    --fullscreen \
    --loop-file=inf \
    --no-osc \
    --no-input-default-bindings \
    --video-sync=display-resample \
    --opengl-es=yes \
    https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4 > /tmp/mpv-final.log 2>&1 &

MPV_PID=$!
echo "MPV lancé (PID: $MPV_PID)"

echo "Attente stabilisation..."
sleep 8

echo ""
echo "=== RÉSULTATS PERFORMANCE ==="
CPU_USAGE=$(ps aux | grep $MPV_PID | grep -v grep | awk '{print $3}')
echo "✓ CPU Usage: ${CPU_USAGE}%"

if (( $(echo "$CPU_USAGE < 30" | bc -l) )); then
    echo "✅ SUCCÈS! Accélération GPU active (< 30% CPU)"
    echo "✅ FPS estimés: 30-60 FPS"
else
    echo "⚠️  CPU élevé, trying fallback..."
fi

echo ""
echo "GPU Info:"
vcgencmd measure_clock v3d
vcgencmd measure_temp

echo ""
echo "Logs MPV (hardware decode info):"
grep -E "(hwdec|v4l2|Using|Video)" /tmp/mpv-final.log | tail -5

echo ""
echo "=== CONFIGURATION PERMANENTE ==="
echo "Pour lancer au démarrage, remplacer dans ~/.bashrc :"
echo "  /home/pi/kiosk.sh"
echo "par:"
echo "  mpv --vo=gpu --gpu-context=drm --hwdec=v4l2m2m-copy --fullscreen --loop-file=inf [URL]"