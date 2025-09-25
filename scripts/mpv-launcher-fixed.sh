#!/bin/bash
# PiSignage - MPV Launcher Fixed for Raspberry Pi
# Lance MPV avec le support DRM direct pour affichage fullscreen

MEDIA_DIR="/opt/pisignage/media"
LOG_DIR="/opt/pisignage/logs"

# Arrêter toute instance existante
echo "Arrêt des instances MPV/VLC existantes..."
pkill -f mpv 2>/dev/null
pkill -f vlc 2>/dev/null
sleep 2

# Détection du modèle Pi
PI_MODEL=$(cat /proc/cpuinfo | grep 'Model' | cut -d: -f2 | xargs)
echo "Modèle détecté: $PI_MODEL"

# Trouver la première vidéo disponible
VIDEO_FILE=$(ls "$MEDIA_DIR"/*.{mp4,mkv,avi,mov} 2>/dev/null | head -1)

if [ -z "$VIDEO_FILE" ]; then
    echo "Erreur: Aucun fichier vidéo trouvé dans $MEDIA_DIR"
    exit 1
fi

echo "Lecture de: $VIDEO_FILE"

# Configuration pour affichage direct DRM (pas besoin de X11)
# Cette méthode fonctionne même en SSH sans display
export TERM=linux

# Lancer MPV avec DRM direct
# --vo=drm utilise le framebuffer directement sans X11
# --drm-connector force l'utilisation du premier connecteur HDMI
echo "Lancement MPV en mode DRM direct..."

sudo mpv \
    --vo=drm \
    --drm-connector=help \
    2>&1 | grep -A5 "Available" > /tmp/drm-connectors.txt

# Obtenir le bon connecteur
CONNECTOR=$(grep "HDMI" /tmp/drm-connectors.txt | head -1 | awk '{print $1}' | tr -d '.')

if [ -z "$CONNECTOR" ]; then
    CONNECTOR="1"
    echo "Utilisation du connecteur par défaut: $CONNECTOR"
else
    echo "Connecteur HDMI trouvé: $CONNECTOR"
fi

# Lancer MPV avec tous les paramètres optimisés
sudo mpv \
    --vo=drm \
    --drm-connector="${CONNECTOR}.HDMI-A-1" \
    --hwdec=auto \
    --fullscreen \
    --loop=inf \
    --no-terminal \
    --no-audio-display \
    --really-quiet \
    --video-unscaled \
    --drm-draw-plane=primary \
    --drm-drmprime-video-plane=overlay \
    "$VIDEO_FILE" \
    > "$LOG_DIR/mpv-drm.log" 2>&1 &

MPV_PID=$!
echo "MPV lancé avec PID: $MPV_PID"

# Attendre un peu pour vérifier que MPV démarre
sleep 3

if ps -p $MPV_PID > /dev/null; then
    echo "✓ MPV fonctionne correctement en mode DRM"
    echo "La vidéo devrait s'afficher en plein écran sur le moniteur HDMI"
else
    echo "✗ Erreur: MPV s'est arrêté. Vérifier les logs:"
    tail -20 "$LOG_DIR/mpv-drm.log"
fi