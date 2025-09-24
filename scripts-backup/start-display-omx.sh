#!/bin/bash

# PiSignage avec OMXPlayer - Maximum performance pour Raspberry Pi
# OMXPlayer utilise l'accélération GPU native du Pi

MEDIA_DIR="/opt/pisignage/media"
VIDEO_FILE="$MEDIA_DIR/Big_Buck_Bunny_720_10s_30MB.mp4"
FALLBACK_IMAGE="$MEDIA_DIR/fallback-logo.jpg"
LOG_FILE="/opt/pisignage/logs/display.log"

# Logger
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Tuer les processus existants
pkill -f omxplayer
pkill -f mpv
pkill -f vlc
pkill -f feh
sleep 1

# Vérifier si omxplayer est installé
if ! command -v omxplayer &> /dev/null; then
    log "OMXPlayer non installé, installation..."
    sudo apt-get update
    sudo apt-get install -y omxplayer
fi

if [ -f "$VIDEO_FILE" ]; then
    log "Lecture vidéo avec OMXPlayer (GPU accelerated): $VIDEO_FILE"

    # Options OMXPlayer pour performance maximale
    # --loop : lecture en boucle
    # --no-osd : pas d'affichage à l'écran
    # --aspect-mode fill : remplir l'écran
    # --hw : utiliser décodage hardware
    # --layer 10 : layer élevé pour être au dessus

    DISPLAY=:0 omxplayer \
        --loop \
        --no-osd \
        --aspect-mode fill \
        --blank \
        --no-keys \
        --layer 10 \
        --hdmiclocksync \
        "$VIDEO_FILE" &

    OMX_PID=$!
    log "OMXPlayer lancé avec PID $OMX_PID"

    # Monitoring
    sleep 3
    if ps -p $OMX_PID > /dev/null; then
        log "OMXPlayer fonctionne correctement"

        # Afficher stats performance
        TEMP=$(vcgencmd measure_temp | cut -d= -f2)
        GPU_MEM=$(vcgencmd get_mem gpu | cut -d= -f2)
        log "Performance: Temp=$TEMP, GPU_Mem=$GPU_MEM"
    else
        log "Erreur: OMXPlayer ne s'est pas lancé, fallback sur MPV"
        # Fallback sur MPV si omxplayer échoue
        /opt/pisignage/scripts/start-display-optimized.sh
    fi

elif [ -f "$FALLBACK_IMAGE" ]; then
    log "Affichage image avec feh: $FALLBACK_IMAGE"
    DISPLAY=:0 feh --fullscreen --auto-zoom --hide-pointer --no-menus "$FALLBACK_IMAGE" &

else
    log "Création image fallback"
    convert -size 1920x1080 gradient:'#667eea-#764ba2' \
            -fill white -gravity center -pointsize 100 \
            -annotate +0+0 "PiSignage v0.8.0" \
            "$FALLBACK_IMAGE"

    DISPLAY=:0 feh --fullscreen --auto-zoom --hide-pointer --no-menus "$FALLBACK_IMAGE" &
fi