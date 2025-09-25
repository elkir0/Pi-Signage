#!/bin/bash
# PiSignage - MPV Launcher avec accès GUI
# Lance MPV dans la session graphique existante

MEDIA_DIR="/opt/pisignage/media"
LOG_FILE="/opt/pisignage/logs/mpv.log"

# Arrêter toute instance existante
echo "Arrêt des instances MPV existantes..."
pkill -f mpv 2>/dev/null
sleep 2

# Trouver la vidéo à lire
VIDEO_FILE=$(ls "$MEDIA_DIR"/*.{mp4,mkv,avi,mov} 2>/dev/null | head -1)

if [ -z "$VIDEO_FILE" ]; then
    echo "Erreur: Aucun fichier vidéo trouvé dans $MEDIA_DIR"
    exit 1
fi

echo "Lecture de: $VIDEO_FILE"

# Lancer MPV dans la session graphique de l'utilisateur pi
# systemd-run permet d'exécuter dans le contexte graphique correct
systemd-run --uid=pi --property="Environment=DISPLAY=:0" \
    --property="Environment=XAUTHORITY=/home/pi/.Xauthority" \
    --property="PAMName=login" \
    mpv --vo=x11 --fullscreen --loop=inf --really-quiet \
    "$VIDEO_FILE"

echo "MPV lancé avec systemd-run"