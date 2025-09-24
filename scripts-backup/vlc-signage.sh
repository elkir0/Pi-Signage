#!/bin/bash

# PiSignage VLC Launcher Script
# Démarre VLC avec playlist ou image de fallback

MEDIA_DIR="/opt/pisignage/media"
PLAYLIST_DIR="/opt/pisignage/config/playlists"
DEFAULT_PLAYLIST="$PLAYLIST_DIR/default.m3u"
FALLBACK_IMAGE="$MEDIA_DIR/fallback-logo.jpg"
LOG_FILE="/opt/pisignage/logs/vlc-signage.log"

# Créer log si nécessaire
mkdir -p $(dirname "$LOG_FILE")

# Fonction pour logger
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Tuer VLC existant
log "Arrêt de VLC existant..."
pkill -f vlc

# Attendre un peu
sleep 2

# Déterminer quoi lire
if [ -f "$DEFAULT_PLAYLIST" ] && [ -s "$DEFAULT_PLAYLIST" ]; then
    # Playlist existe et non vide
    log "Lecture de la playlist: $DEFAULT_PLAYLIST"
    MEDIA_SOURCE="$DEFAULT_PLAYLIST"
elif [ -f "$MEDIA_DIR"/*.mp4 ] 2>/dev/null; then
    # Des vidéos existent
    log "Lecture des vidéos MP4 dans: $MEDIA_DIR"
    MEDIA_SOURCE="$MEDIA_DIR/*.mp4"
elif [ -f "$FALLBACK_IMAGE" ]; then
    # Image de fallback
    log "Affichage de l'image de fallback: $FALLBACK_IMAGE"
    MEDIA_SOURCE="$FALLBACK_IMAGE"
else
    # Créer une image de fallback basique
    log "Création et affichage d'une image de fallback..."
    convert -size 1920x1080 gradient:blue-purple \
            -fill white -gravity center -pointsize 80 \
            -annotate +0+0 "PiSignage v0.8.0\nAucun média disponible" \
            "$FALLBACK_IMAGE"
    MEDIA_SOURCE="$FALLBACK_IMAGE"
fi

# Options VLC optimisées
VLC_OPTIONS=(
    --intf dummy
    --fullscreen
    --loop
    --no-video-title-show
    --no-osd
    --quiet
    --no-audio
    --image-duration=-1  # Pour les images statiques
    --vout x11           # Forcer sortie X11
    --no-xlib            # Désactiver multi-threading X11
)

# Lancer VLC
log "Démarrage de VLC avec: $MEDIA_SOURCE"
export DISPLAY=:0
vlc "${VLC_OPTIONS[@]}" "$MEDIA_SOURCE" &

VLC_PID=$!
log "VLC démarré avec PID: $VLC_PID"

# Vérifier que VLC tourne
sleep 3
if ps -p $VLC_PID > /dev/null; then
    log "VLC fonctionne correctement"
else
    log "ERREUR: VLC ne s'est pas lancé correctement"
fi