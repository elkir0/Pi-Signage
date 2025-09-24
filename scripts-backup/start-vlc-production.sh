#!/bin/bash

# PiSignage Production - VLC uniquement, simple et stable
# Pas de MPV, pas d'optimisations complexes

MEDIA_DIR="/opt/pisignage/media"
VIDEO_FILE="$MEDIA_DIR/Big_Buck_Bunny_720_10s_30MB.mp4"

# Arrêt propre des processus existants
pkill -f vlc 2>/dev/null
pkill -f mpv 2>/dev/null
pkill -f feh 2>/dev/null

sleep 2

# Si vidéo existe, lancer VLC avec options basiques
if [ -f "$VIDEO_FILE" ]; then
    # cvlc = VLC sans interface
    # Options minimales pour stabilité
    DISPLAY=:0 cvlc \
        --fullscreen \
        --loop \
        --no-video-title-show \
        --intf dummy \
        --quiet \
        "$VIDEO_FILE" > /dev/null 2>&1 &

    echo "VLC lancé avec $VIDEO_FILE"

else
    # Si pas de vidéo, afficher message simple
    echo "Pas de vidéo trouvée dans $MEDIA_DIR"

    # Créer une image simple noire avec texte
    convert -size 1920x1080 xc:black \
            -fill white -gravity center -pointsize 80 \
            -annotate +0+0 "PiSignage v0.8.0\nAucune vidéo disponible" \
            /tmp/no-video.jpg

    DISPLAY=:0 feh --fullscreen --hide-pointer /tmp/no-video.jpg &
fi