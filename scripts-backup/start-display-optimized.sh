#!/bin/bash

# PiSignage Optimized Display Manager for Raspberry Pi
# Utilise l'accélération matérielle pour 30 FPS stable

MEDIA_DIR="/opt/pisignage/media"
VIDEO_FILE="$MEDIA_DIR/Big_Buck_Bunny_720_10s_30MB.mp4"
FALLBACK_IMAGE="$MEDIA_DIR/fallback-logo.jpg"
LOG_FILE="/opt/pisignage/logs/display.log"

# Logger
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Tuer les processus existants
pkill -f mpv
pkill -f vlc
pkill -f feh
sleep 1

# Détection du modèle Pi pour optimisations
PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')
log "Modèle détecté: $PI_MODEL"

# Si la vidéo existe, la lire avec accélération hardware
if [ -f "$VIDEO_FILE" ]; then
    log "Lecture vidéo optimisée: $VIDEO_FILE"

    # Options MPV optimisées pour Raspberry Pi
    MPV_OPTIONS=(
        --fullscreen
        --loop=inf
        --no-osc
        --no-input-terminal
        --really-quiet
        --hwdec=v4l2m2m-copy    # Accélération hardware Pi
        --vo=gpu                 # Sortie GPU optimisée
        --gpu-context=drm        # Context DRM pour Pi
        --drm-connector=HDMI-A-1 # Sortie HDMI directe
        --video-sync=display-resample
        --framedrop=decoder      # Drop frames si nécessaire
        --deinterlace=no        # Pas de désentrelacement
        --vd-lavc-dr=yes        # Direct rendering
        --vd-lavc-threads=4     # Utiliser tous les cores
        --cache=yes
        --cache-secs=10
        --demuxer-readahead-secs=10
        --video-latency-hacks=yes
    )

    # Vérifier si v4l2m2m est disponible
    if mpv --hwdec=help 2>&1 | grep -q "v4l2m2m"; then
        log "Utilisation accélération v4l2m2m"
    else
        # Fallback sur d'autres méthodes
        log "v4l2m2m non disponible, essai avec mmal"
        MPV_OPTIONS[5]="--hwdec=mmal-copy"

        # Si mmal non disponible, essayer sans hwdec mais avec optimisations
        if ! mpv --hwdec=help 2>&1 | grep -q "mmal"; then
            log "Pas d'accélération hardware, optimisation software"
            MPV_OPTIONS[5]="--hwdec=no"
            MPV_OPTIONS+=("--vf=scale=1280:720")  # Réduire résolution si nécessaire
        fi
    fi

    export DISPLAY=:0
    mpv "${MPV_OPTIONS[@]}" "$VIDEO_FILE" &
    MPV_PID=$!

    # Régler la priorité du processus
    sleep 2
    if ps -p $MPV_PID > /dev/null; then
        sudo renice -5 $MPV_PID 2>/dev/null
        log "MPV lancé avec PID $MPV_PID et priorité élevée"
    fi

# Sinon afficher l'image de fallback
elif [ -f "$FALLBACK_IMAGE" ]; then
    log "Affichage image avec feh: $FALLBACK_IMAGE"
    DISPLAY=:0 feh --fullscreen --auto-zoom --hide-pointer --no-menus "$FALLBACK_IMAGE" &

else
    # Créer et afficher une image de fallback
    log "Création image fallback"
    convert -size 1920x1080 gradient:'#667eea-#764ba2' \
            -fill white -gravity center -pointsize 100 \
            -annotate +0+0 "PiSignage v0.8.0" \
            "$FALLBACK_IMAGE"

    DISPLAY=:0 feh --fullscreen --auto-zoom --hide-pointer --no-menus "$FALLBACK_IMAGE" &
fi

log "Display optimisé démarré"