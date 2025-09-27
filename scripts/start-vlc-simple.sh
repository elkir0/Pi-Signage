#!/bin/bash

# PiSignage v0.8.1 - Script de démarrage VLC

# Configuration de l'environnement
export DISPLAY=${DISPLAY:-:0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

# Arrêt des lecteurs existants
pkill -9 vlc mpv 2>/dev/null
sleep 1

# Détection Wayland/X11
if [ -n "$WAYLAND_DISPLAY" ]; then
    VLC_OPTIONS="--intf dummy --vout gles2 --fullscreen --loop --no-video-title-show --quiet"
else
    VLC_OPTIONS="--intf dummy --vout x11 --fullscreen --loop --no-video-title-show --quiet"
fi

# Fichier vidéo
VIDEO="${1:-/opt/pisignage/media/BigBuckBunny_720p.mp4}"

# Démarrer VLC
if [ -f "$VIDEO" ]; then
    cvlc $VLC_OPTIONS "$VIDEO" > /opt/pisignage/logs/vlc.log 2>&1 &
    echo "✓ VLC démarré avec $(basename "$VIDEO")"
else
    echo "✗ Vidéo non trouvée: $VIDEO"
    exit 1
fi
