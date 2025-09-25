#!/bin/bash
# PiSignage - Démarrage MPV Optimisé pour Raspberry Pi

echo "=== Starting Optimized MPV for Raspberry Pi ==="

# Configuration de l'environnement
export XDG_RUNTIME_DIR=/run/user/1000
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Arrêter les players existants
pkill -9 vlc 2>/dev/null
pkill -9 mpv 2>/dev/null
sleep 1

# Détection du modèle de Raspberry Pi
PI_MODEL=$(cat /proc/cpuinfo | grep -E "Model|Hardware" | grep -i "pi")
echo "Modèle détecté: $PI_MODEL"

# Vidéo à lire
VIDEO_DIR="/opt/pisignage/media"
VIDEO_FILE="$VIDEO_DIR/*.{mp4,mkv,avi,mov,webm}"

# Configuration selon le modèle
if [[ "$PI_MODEL" == *"Pi 4"* ]] || [[ "$PI_MODEL" == *"Pi 400"* ]]; then
    echo "Configuration pour Raspberry Pi 4..."

    # Pi 4: Utiliser DRM/KMS avec V4L2 M2M
    MPV_OPTIONS=(
        --vo=gpu
        --gpu-context=drm
        --drm-connector=1.HDMI-A-1
        --hwdec=v4l2m2m-copy
        --hwdec-codecs=all
        --fullscreen
        --loop-playlist=inf
        --no-osc
        --no-input-default-bindings
        --gpu-hwdec-interop=drmprime-drm
        --cache=yes
        --cache-secs=10
        --demuxer-max-bytes=50M
        --video-sync=display-resample
    )

elif [[ "$PI_MODEL" == *"Pi 3"* ]]; then
    echo "Configuration pour Raspberry Pi 3..."

    # Pi 3: Utiliser MMAL
    MPV_OPTIONS=(
        --vo=gpu
        --gpu-context=x11egl
        --hwdec=mmal-copy
        --fullscreen
        --loop-playlist=inf
        --no-osc
        --no-input-default-bindings
        --cache=yes
        --cache-secs=5
        --demuxer-max-bytes=30M
    )

elif [[ "$PI_MODEL" == *"Pi 5"* ]]; then
    echo "Configuration pour Raspberry Pi 5..."

    # Pi 5: Utiliser V4L2 avec le nouveau GPU
    MPV_OPTIONS=(
        --vo=gpu
        --gpu-context=wayland
        --hwdec=v4l2m2m
        --fullscreen
        --loop-playlist=inf
        --no-osc
        --cache=yes
    )

else
    echo "Modèle non reconnu, utilisation config générique..."

    # Configuration générique avec détection auto
    MPV_OPTIONS=(
        --vo=gpu
        --hwdec=auto-safe
        --fullscreen
        --loop-playlist=inf
        --no-osc
    )
fi

# Lancer MPV avec les options optimisées
echo "Lancement de MPV avec accélération matérielle..."
mpv "${MPV_OPTIONS[@]}" $VIDEO_FILE > /opt/pisignage/logs/mpv.log 2>&1 &

MPV_PID=$!
echo "✓ MPV démarré avec PID: $MPV_PID"

# Vérifier que MPV fonctionne
sleep 3
if ps -p $MPV_PID > /dev/null; then
    # Vérifier l'utilisation CPU
    CPU_USAGE=$(ps aux | grep $MPV_PID | grep -v grep | awk '{print $3}')
    echo "✓ MPV fonctionne - Utilisation CPU: ${CPU_USAGE}%"

    # Si CPU > 50%, warning
    if (( $(echo "$CPU_USAGE > 50" | bc -l) )); then
        echo "⚠ Utilisation CPU élevée! L'accélération matérielle pourrait ne pas fonctionner."
        echo "  Vérifiez les logs: /opt/pisignage/logs/mpv.log"
    fi
else
    echo "✗ MPV a échoué, vérifiez les logs"
    tail -20 /opt/pisignage/logs/mpv.log
    exit 1
fi

exit 0