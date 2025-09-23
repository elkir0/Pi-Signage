#!/bin/bash

# Script VLC ultra simple pour Raspberry Pi
# Sans accélération hardware qui cause des problèmes

VIDEO="/opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4"

# Arrêter tout
pkill -f vlc 2>/dev/null
pkill -f mpv 2>/dev/null
sleep 2

# Lancer VLC le plus simplement possible
# Pas d'accélération, pas d'options complexes
export DISPLAY=:0
vlc --fullscreen --loop "$VIDEO" &

echo "VLC lancé en mode basique"