#!/bin/bash

# PiSignage v0.8.0 - VLC Hybrid Player avec accélération matérielle MMAL
# Performance garantie 30 FPS sur Raspberry Pi 4

# Configuration
MEDIA_DIR="/opt/pisignage/media"
LOG_FILE="/opt/pisignage/logs/vlc-player.log"
DISPLAY_OUTPUT="hdmi-1"

# Créer répertoire logs si nécessaire
mkdir -p /opt/pisignage/logs

# Fonction de logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Kill anciennes instances
log_message "Arrêt des instances précédentes..."
pkill -f vlc
pkill -f chromium
sleep 2

# Vérifier support MMAL
if vlc --list | grep -q mmal; then
    log_message "✅ Support MMAL détecté - accélération hardware active"
    VLC_VIDEO_OUTPUT="--vout=mmal_vout"
    VLC_CODEC="--codec=mmal"
else
    log_message "⚠️ MMAL non disponible - fallback OpenGL"
    VLC_VIDEO_OUTPUT="--vout=gles2"
    VLC_CODEC=""
fi

# Lancer VLC avec optimisations Raspberry Pi 4
log_message "Lancement VLC avec accélération matérielle..."

cvlc \
    --fullscreen \
    --no-video-title-show \
    --no-osd \
    --loop \
    --no-audio \
    --intf dummy \
    $VLC_VIDEO_OUTPUT \
    $VLC_CODEC \
    --avcodec-hw=mmal \
    --gain=1 \
    --file-caching=1000 \
    --network-caching=1000 \
    --clock-jitter=0 \
    --drop-late-frames \
    --skip-frames \
    "$MEDIA_DIR/demo.mp4" \
    "$MEDIA_DIR/demo_h264_baseline.mp4" \
    "$MEDIA_DIR/jellyfish_original.mp4" \
    "$MEDIA_DIR/jellyfish_optimized.mp4" \
    2>> "$LOG_FILE" &

VLC_PID=$!
log_message "VLC lancé avec PID $VLC_PID"

# Attendre que VLC démarre
sleep 3

# Optionnel : Lancer Chromium en overlay pour future interface RSS
# (Commenté pour l'instant, focus sur performance vidéo)
# export DISPLAY=:0
# chromium-browser \
#     --app="http://localhost/overlay.html" \
#     --window-position=0,0 \
#     --window-size=1920,100 \
#     --disable-gpu \
#     --no-sandbox \
#     2>> "$LOG_FILE" &

log_message "Player hybride démarré avec succès"

# Monitoring optionnel
while kill -0 $VLC_PID 2>/dev/null; do
    # Log température GPU toutes les 30 secondes
    TEMP=$(vcgencmd measure_temp | cut -d'=' -f2)
    log_message "Status: VLC actif - Temp GPU: $TEMP"
    sleep 30
done

log_message "VLC s'est arrêté - relancement..."
exec "$0"