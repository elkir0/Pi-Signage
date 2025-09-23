#!/bin/bash

# PiSignage VLC Optimisé pour Raspberry Pi 4
# Utilise l'accélération hardware pour 30 FPS stable

MEDIA_DIR="/opt/pisignage/media"
VIDEO_FILE="$MEDIA_DIR/Big_Buck_Bunny_720_10s_30MB.mp4"
FALLBACK_IMAGE="$MEDIA_DIR/fallback-logo.jpg"
LOG_FILE="/opt/pisignage/logs/display.log"

# Logger
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Tuer les processus existants
pkill -f vlc
pkill -f mpv
pkill -f feh
sleep 1

if [ -f "$VIDEO_FILE" ]; then
    log "Lecture vidéo avec VLC optimisé Pi: $VIDEO_FILE"

    # Options VLC optimisées pour Raspberry Pi 4
    # Utilisation de l'accélération MMAL ou V4L2
    VLC_OPTIONS=(
        --intf dummy                    # Interface sans GUI
        --fullscreen                     # Plein écran
        --loop                           # Lecture en boucle
        --no-video-title-show           # Pas de titre
        --no-osd                        # Pas d'OSD
        --quiet                         # Mode silencieux

        # Accélération hardware Raspberry Pi
        --codec avcodec,mmal_decoder    # Décodeur MMAL
        --vout mmal_vout                # Sortie vidéo MMAL
        --mmal-display hdmi-1           # Sortie HDMI
        --mmal-layer 10                 # Layer élevé

        # Optimisations performance
        --no-audio                      # Désactiver audio si pas nécessaire
        --avcodec-hw=mmal               # Forcer hardware decoding
        --avcodec-threads=4             # Utiliser tous les cores
        --network-caching=1000          # Cache réseau
        --file-caching=1000             # Cache fichier
        --live-caching=1000             # Cache live
        --drop-late-frames              # Drop frames en retard
        --skip-frames                   # Sauter frames si nécessaire

        # Optimisations mémoire
        --no-snapshot-preview
        --no-spu                        # Pas de sous-titres
        --no-sub-autodetect-file
        --no-disable-screensaver
        --video-filter=                # Pas de filtre vidéo
    )

    # Vérifier si on peut utiliser DRM direct (Pi 4 avec KMS)
    if [ -e /dev/dri/card0 ]; then
        log "Utilisation DRM/KMS direct"
        VLC_OPTIONS+=(
            --vout drm_vout              # Sortie DRM directe
            --drm-vout-display=/dev/dri/card0
        )
    fi

    # Configurer l'environnement
    export DISPLAY=:0
    export VLC_VERBOSE=0

    # Lancer VLC avec priorité élevée
    nice -n -5 vlc "${VLC_OPTIONS[@]}" "$VIDEO_FILE" &
    VLC_PID=$!

    sleep 3
    if ps -p $VLC_PID > /dev/null; then
        log "VLC optimisé lancé avec PID $VLC_PID"

        # Monitoring performance
        TEMP=$(vcgencmd measure_temp | cut -d= -f2)
        GPU_MEM=$(vcgencmd get_mem gpu | cut -d= -f2)
        THROTTLED=$(vcgencmd get_throttled | cut -d= -f2)
        log "Performance: Temp=$TEMP, GPU=$GPU_MEM, Throttled=$THROTTLED"
    else
        log "Erreur VLC, fallback sur MPV"
        DISPLAY=:0 mpv --fullscreen --loop=inf --hwdec=auto "$VIDEO_FILE" &
    fi

elif [ -f "$FALLBACK_IMAGE" ]; then
    log "Affichage image: $FALLBACK_IMAGE"
    DISPLAY=:0 feh --fullscreen --auto-zoom --hide-pointer --no-menus "$FALLBACK_IMAGE" &

else
    log "Création image fallback"
    convert -size 1920x1080 gradient:'#667eea-#764ba2' \
            -fill white -gravity center -pointsize 100 \
            -annotate +0+0 "PiSignage v0.8.0" \
            "$FALLBACK_IMAGE"

    DISPLAY=:0 feh --fullscreen --auto-zoom --hide-pointer --no-menus "$FALLBACK_IMAGE" &
fi