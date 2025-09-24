#!/bin/bash

# PiSignage - Script VLC SIMPLE et FONCTIONNEL
# Pas de MPV, pas de complexité, juste VLC qui marche

MEDIA_DIR="/opt/pisignage/media"
VIDEO_FILE="$MEDIA_DIR/Big_Buck_Bunny_720_10s_30MB.mp4"
FALLBACK_IMAGE="$MEDIA_DIR/fallback-logo.jpg"

# Tuer tout ce qui tourne
pkill -f vlc
pkill -f mpv
pkill -f feh

# Attendre un peu
sleep 2

# Si la vidéo existe, la jouer avec VLC
if [ -f "$VIDEO_FILE" ]; then
    # Options VLC simples qui fonctionnent sur Pi
    DISPLAY=:0 cvlc \
        --fullscreen \
        --loop \
        --no-video-title-show \
        --quiet \
        "$VIDEO_FILE" &

# Sinon afficher l'image
elif [ -f "$FALLBACK_IMAGE" ]; then
    DISPLAY=:0 feh --fullscreen --hide-pointer "$FALLBACK_IMAGE" &

# Sinon créer et afficher une image basique
else
    convert -size 1920x1080 xc:blue \
            -fill white -gravity center -pointsize 100 \
            -annotate +0+0 "PiSignage v0.8.0" \
            "$FALLBACK_IMAGE"

    DISPLAY=:0 feh --fullscreen --hide-pointer "$FALLBACK_IMAGE" &
fi