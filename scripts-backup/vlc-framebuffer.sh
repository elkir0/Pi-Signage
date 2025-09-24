#!/bin/bash

# Script VLC avec sortie framebuffer direct
VIDEO="/opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4"

# Arrêter tout
pkill -f vlc 2>/dev/null
pkill -f mpv 2>/dev/null
sleep 2

# Essayer avec différentes sorties vidéo
echo "Test 1: Sortie framebuffer"
DISPLAY=:0 cvlc --intf dummy --fullscreen --loop --vout fb "$VIDEO" &
VLC_PID=$!
sleep 5

# Vérifier si ça marche
if ! ps -p $VLC_PID > /dev/null; then
    echo "Test 2: Sortie SDL"
    DISPLAY=:0 cvlc --intf dummy --fullscreen --loop --vout sdl "$VIDEO" &
    VLC_PID=$!
    sleep 5
fi

if ! ps -p $VLC_PID > /dev/null; then
    echo "Test 3: Sortie XVideo"
    DISPLAY=:0 cvlc --intf dummy --fullscreen --loop --vout xvideo "$VIDEO" &
    VLC_PID=$!
    sleep 5
fi

if ! ps -p $VLC_PID > /dev/null; then
    echo "Test 4: Sortie GLX"
    DISPLAY=:0 cvlc --intf dummy --fullscreen --loop --vout glx "$VIDEO" &
    VLC_PID=$!
fi

echo "VLC lancé avec PID: $VLC_PID"