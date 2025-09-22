#!/bin/bash

# PiSignage v0.8.0 - Script de démarrage principal
# Gestion du démarrage de l'affichage digital
# Auteur: Claude Code
# Date: 22/09/2025

set -e

# Variables
PISIGNAGE_DIR="/opt/pisignage"
MEDIA_DIR="$PISIGNAGE_DIR/media"
LOG_DIR="$PISIGNAGE_DIR/logs"
SCRIPTS_DIR="$PISIGNAGE_DIR/scripts"
PID_FILE="/tmp/pisignage.pid"
LOG_FILE="$LOG_DIR/pisignage.log"

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Initialisation
initialize() {
    log "🚀 Démarrage PiSignage v0.8.0"

    # Création des répertoires nécessaires
    mkdir -p "$LOG_DIR"
    mkdir -p "$MEDIA_DIR/playlists"

    # Vérification de l'affichage
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
        log "DISPLAY configuré sur :0"
    fi

    # Attendre que X11 soit prêt
    local count=0
    while ! xset q &>/dev/null && [ $count -lt 30 ]; do
        log "Attente X11... ($count/30)"
        sleep 2
        count=$((count + 1))
    done

    if ! xset q &>/dev/null; then
        log "ERROR: X11 non disponible après 60s"
        exit 1
    fi

    log "✅ X11 disponible"
}

# Configuration de l'écran
setup_display() {
    log "Configuration de l'écran..."

    # Désactiver l'économiseur d'écran
    xset s noblank
    xset s off
    xset -dpms

    # Masquer le curseur
    if command -v unclutter >/dev/null 2>&1; then
        unclutter -idle 0.5 -root &
        log "✅ Curseur masqué"
    fi

    # Configuration fullscreen
    if command -v xdotool >/dev/null 2>&1; then
        # Attendre un peu pour que les fenêtres se stabilisent
        sleep 2
        # Mettre toutes les fenêtres en fullscreen
        xdotool search --onlyvisible --class "" windowstate --add FULLSCREEN 2>/dev/null || true
    fi

    log "✅ Écran configuré"
}

# Démarrage du media player
start_media_player() {
    log "Démarrage du lecteur média..."

    # Fichier par défaut ou playlist
    local media_file=""
    local playlist_file="$MEDIA_DIR/playlists/current.m3u"
    local default_video="$MEDIA_DIR/default.mp4"
    local test_video="$MEDIA_DIR/test.mp4"

    # Priorité: playlist > default.mp4 > test.mp4 > vidéo de démonstration
    if [ -f "$playlist_file" ] && [ -s "$playlist_file" ]; then
        log "Playlist trouvée: $playlist_file"
        media_file="$playlist_file"
    elif [ -f "$default_video" ]; then
        log "Vidéo par défaut trouvée: $default_video"
        media_file="$default_video"
    elif [ -f "$test_video" ]; then
        log "Vidéo de test trouvée: $test_video"
        media_file="$test_video"
    else
        log "Aucun média trouvé, création d'une démo..."
        create_demo_content
        media_file="$MEDIA_DIR/demo.mp4"
    fi

    # Démarrage VLC
    if [ -x "$SCRIPTS_DIR/vlc-control.sh" ]; then
        "$SCRIPTS_DIR/vlc-control.sh" start "$media_file"
        log "✅ VLC démarré avec: $(basename "$media_file")"
    else
        log "ERROR: Script vlc-control.sh non trouvé"
        # Démarrage VLC direct en fallback
        start_vlc_fallback "$media_file"
    fi
}

# Démarrage VLC de secours
start_vlc_fallback() {
    local media_file="$1"

    log "Démarrage VLC en mode fallback..."

    cvlc \
        --intf dummy \
        --fullscreen \
        --loop \
        --no-osd \
        --no-video-title-show \
        --vout mmal_vout \
        --aout pulse \
        --avcodec-hw mmal \
        --quiet \
        "$media_file" &

    echo $! > "/tmp/vlc-pisignage.pid"
    log "✅ VLC fallback démarré"
}

# Création de contenu de démonstration
create_demo_content() {
    log "Création de contenu de démonstration..."

    local demo_file="$MEDIA_DIR/demo.mp4"

    # Créer une vidéo de démonstration avec ffmpeg si disponible
    if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -f lavfi -i "testsrc2=duration=10:size=1920x1080:rate=30" \
               -f lavfi -i "sine=frequency=1000:duration=10" \
               -c:v libx264 -preset ultrafast -c:a aac \
               -y "$demo_file" 2>/dev/null || {
            log "Échec création vidéo FFmpeg, utilisation d'une image statique"
            create_static_demo
        }
    else
        create_static_demo
    fi
}

# Création de démonstration statique
create_static_demo() {
    local demo_image="$MEDIA_DIR/demo.png"

    # Créer une image de démonstration
    if command -v convert >/dev/null 2>&1; then
        convert -size 1920x1080 xc:blue \
                -pointsize 72 -fill white -gravity center \
                -annotate +0-100 "PiSignage v0.8.0" \
                -pointsize 36 -annotate +0+50 "Système d'affichage digital" \
                -pointsize 24 -annotate +0+100 "$(date '+%Y-%m-%d %H:%M:%S')" \
                "$demo_image" 2>/dev/null || {
            log "Échec création image, utilisation de feh"
        }

        # Afficher l'image avec feh en boucle
        if command -v feh >/dev/null 2>&1; then
            feh --fullscreen --auto-zoom --slideshow-delay 5 "$demo_image" &
            echo $! > "/tmp/feh-pisignage.pid"
            log "✅ Démonstration statique démarrée"
        fi
    fi
}

# Surveillance et monitoring
start_monitoring() {
    log "Démarrage du monitoring..."

    # Script de surveillance en arrière-plan
    (
        while true; do
            sleep 60

            # Vérifier que VLC tourne
            if [ -f "/tmp/vlc-pisignage.pid" ]; then
                local vlc_pid=$(cat "/tmp/vlc-pisignage.pid")
                if ! kill -0 "$vlc_pid" 2>/dev/null; then
                    log "WARNING: VLC arrêté, redémarrage..."
                    start_media_player
                fi
            fi

            # Log des ressources système
            local temp=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2 | cut -d\' -f1 || echo "N/A")
            local mem_usage=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
            log "STATUS: Temp=${temp}°C, RAM=${mem_usage}%"

        done
    ) &

    echo $! > "/tmp/pisignage-monitor.pid"
    log "✅ Monitoring démarré"
}

# Enregistrement du PID principal
save_main_pid() {
    echo $$ > "$PID_FILE"
    log "✅ PID principal enregistré: $$"
}

# Fonction principale
main() {
    save_main_pid
    initialize
    setup_display
    start_media_player
    start_monitoring

    log "🎉 PiSignage v0.8.0 démarré avec succès!"

    # Garder le script en vie
    while true; do
        sleep 300  # 5 minutes
        if [ ! -f "$PID_FILE" ]; then
            log "PID file supprimé, arrêt du service"
            break
        fi
    done
}

# Gestion des signaux
trap 'log "Signal reçu, arrêt..."; rm -f "$PID_FILE"; exit 0' TERM INT

# Exécution
main "$@"