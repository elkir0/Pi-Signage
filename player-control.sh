#!/bin/bash

# PiSignage Player Control Script
# Version: 1.0

MEDIA_DIR="/opt/pisignage/media"
LOG_FILE="/opt/pisignage/logs/player.log"
CURRENT_PLAYLIST="/tmp/pisignage_current_playlist"

# Fonctions de contrôle du lecteur
start_player() {
    echo "$(date): Démarrage du lecteur" >> "$LOG_FILE"
    
    # Démarrage de X si nécessaire
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
        startx &
        sleep 5
    fi
    
    # Masquage du curseur
    unclutter -idle 1 &
    
    echo "Lecteur démarré"
}

stop_player() {
    echo "$(date): Arrêt du lecteur" >> "$LOG_FILE"
    
    # Arrêt des processus de lecture
    pkill omxplayer || true
    pkill feh || true
    pkill chromium || true
    
    echo "Lecteur arrêté"
}

play_video() {
    local video_file="$1"
    echo "$(date): Lecture vidéo: $video_file" >> "$LOG_FILE"
    
    if [ -f "$video_file" ]; then
        omxplayer -o hdmi "$video_file" &
    else
        echo "Erreur: Fichier vidéo introuvable: $video_file" >> "$LOG_FILE"
    fi
}

play_image() {
    local image_file="$1"
    local duration="${2:-10}"
    echo "$(date): Affichage image: $image_file" >> "$LOG_FILE"
    
    if [ -f "$image_file" ]; then
        feh --fullscreen --hide-pointer "$image_file" &
        sleep "$duration"
        pkill feh
    else
        echo "Erreur: Fichier image introuvable: $image_file" >> "$LOG_FILE"
    fi
}

# Menu principal
case "$1" in
    start)
        start_player
        ;;
    stop)
        stop_player
        ;;
    restart)
        stop_player
        sleep 2
        start_player
        ;;
    play-video)
        play_video "$2"
        ;;
    play-image)
        play_image "$2" "$3"
        ;;
    status)
        if pgrep -x "omxplayer\|feh\|chromium" > /dev/null; then
            echo "Lecteur actif"
        else
            echo "Lecteur inactif"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|play-video|play-image|status}"
        echo "  play-video <fichier>"
        echo "  play-image <fichier> [durée]"
        exit 1
        ;;
esac