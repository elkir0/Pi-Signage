#!/bin/bash

# Script VLC simple et fonctionnel
VIDEO="/opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4"

# Arrêter tout
pkill -f vlc 2>/dev/null
pkill -f mpv 2>/dev/null
sleep 2

# Test si DISPLAY est accessible
if ! DISPLAY=:0 xset -q > /dev/null 2>&1; then
    echo "Erreur : DISPLAY :0 non accessible"
    exit 1
fi

# Lancer VLC avec options minimales qui fonctionnent sur Pi 4
# cvlc = sans interface
# --intf dummy = interface sans GUI
# --fullscreen = plein écran (OBLIGATOIRE pour performances)

echo "Lancement VLC..."
DISPLAY=:0 cvlc \
    --intf dummy \
    --fullscreen \
    --loop \
    --no-video-title-show \
    "$VIDEO" > /tmp/vlc-simple.log 2>&1 &

VLC_PID=$!
echo "VLC lancé avec PID: $VLC_PID"

sleep 3

# Vérifier si VLC tourne
if ps -p $VLC_PID > /dev/null; then
    echo "✅ VLC fonctionne!"
    ps aux | grep $VLC_PID | grep -v grep
else
    echo "❌ VLC a crashé. Logs:"
    tail -20 /tmp/vlc-simple.log
fi