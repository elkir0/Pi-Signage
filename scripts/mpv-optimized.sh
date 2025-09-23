#!/bin/bash

# Script MPV optimisé pour Raspberry Pi 4
# Basé sur le rapport technique pour 30+ FPS

VIDEO="/opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4"

# Arrêter tout
pkill -f vlc 2>/dev/null
pkill -f mpv 2>/dev/null
sleep 2

echo "🚀 Lancement MPV avec accélération GPU"

# Options selon le rapport:
# --hwdec=drm-copy : Décodage hardware avec copie DRM
# --vo=gpu : Sortie vidéo GPU
# --gpu-context=drm : Contexte DRM direct
# --fullscreen : Plein écran obligatoire
# --loop=inf : Boucle infinie

DISPLAY=:0 mpv \
    --fullscreen \
    --loop=inf \
    --hwdec=auto \
    --vo=gpu \
    --gpu-context=auto \
    --no-audio \
    --really-quiet \
    "$VIDEO" > /tmp/mpv.log 2>&1 &

MPV_PID=$!
echo "MPV lancé avec PID: $MPV_PID"

sleep 3

if ps -p $MPV_PID > /dev/null; then
    echo "✅ MPV fonctionne!"

    # Stats performance
    CPU=$(ps aux | grep $MPV_PID | grep -v grep | awk '{print $3}')
    echo "📊 CPU: ${CPU}%"

    TEMP=$(vcgencmd measure_temp | cut -d= -f2)
    echo "🌡️  Temp: $TEMP"
else
    echo "❌ MPV a crashé. Essai sans accélération hardware..."

    DISPLAY=:0 mpv \
        --fullscreen \
        --loop=inf \
        --no-audio \
        "$VIDEO" &

    echo "MPV relancé en mode software"
fi