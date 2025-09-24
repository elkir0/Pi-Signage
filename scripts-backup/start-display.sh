#!/bin/bash

# PiSignage Display Manager
# Utilise feh pour images et mpv pour vidéos

MEDIA_DIR="/opt/pisignage/media"
VIDEO_FILE="$MEDIA_DIR/Big_Buck_Bunny_720_10s_30MB.mp4"
FALLBACK_IMAGE="$MEDIA_DIR/fallback-logo.jpg"
LOG_FILE="/opt/pisignage/logs/display.log"

# Logger
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Tuer les processus existants
pkill -f feh
pkill -f mpv
pkill -f vlc

sleep 1

# Si la vidéo existe, la lire avec mpv
if [ -f "$VIDEO_FILE" ]; then
    log "Lecture vidéo avec mpv: $VIDEO_FILE"
    DISPLAY=:0 mpv --fullscreen --loop=inf --no-osc --no-input-terminal --really-quiet "$VIDEO_FILE" &

# Sinon afficher l'image de fallback
elif [ -f "$FALLBACK_IMAGE" ]; then
    log "Affichage image avec feh: $FALLBACK_IMAGE"
    DISPLAY=:0 feh --fullscreen --auto-zoom --hide-pointer --no-menus "$FALLBACK_IMAGE" &

else
    # Créer et afficher une image de fallback basique
    log "Création image fallback"
    convert -size 1920x1080 gradient:'#667eea-#764ba2' \
            -fill white -gravity center -pointsize 100 \
            -annotate +0+0 "PiSignage v0.8.0" \
            "$FALLBACK_IMAGE"

    DISPLAY=:0 feh --fullscreen --auto-zoom --hide-pointer --no-menus "$FALLBACK_IMAGE" &
fi

log "Display démarré avec succès"