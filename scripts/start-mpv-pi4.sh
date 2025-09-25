#!/bin/bash
# PiSignage - MPV Optimisé pour Raspberry Pi 4

echo "=== Starting MPV for Raspberry Pi 4 ==="

# Configuration de l'environnement
export XDG_RUNTIME_DIR=/run/user/1000
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Arrêter les players existants
pkill -9 vlc 2>/dev/null
pkill -9 mpv 2>/dev/null
sleep 1

# Trouver une vidéo
VIDEO=$(ls /opt/pisignage/media/*.mp4 2>/dev/null | head -1)
if [ -z "$VIDEO" ]; then
    echo "Aucune vidéo trouvée!"
    exit 1
fi

echo "Lecture de: $(basename "$VIDEO")"

# Lancer MPV avec accélération V4L2 pour Pi 4
# V4L2 M2M est le décodeur hardware pour le Pi 4
mpv \
    --vo=gpu \
    --gpu-context=x11egl \
    --hwdec=v4l2m2m-copy \
    --fullscreen \
    --loop-playlist=inf \
    --no-osc \
    --no-input-default-bindings \
    --cache=yes \
    --cache-secs=5 \
    --really-quiet \
    "$VIDEO" > /opt/pisignage/logs/mpv.log 2>&1 &

MPV_PID=$!
echo "✓ MPV démarré (PID: $MPV_PID)"

# Vérifier après 3 secondes
sleep 3
if ps -p $MPV_PID > /dev/null; then
    CPU=$(ps aux | grep $MPV_PID | grep -v grep | awk '{print $3}')
    echo "✓ MPV fonctionne - CPU: ${CPU}%"

    # Si CPU > 40%, essayer sans hwdec
    if (( $(echo "$CPU > 40" | bc -l 2>/dev/null || echo 1) )); then
        echo "⚠ CPU élevé, test sans accélération hardware..."
        kill -9 $MPV_PID
        sleep 1

        # Essayer avec rendu GPU mais sans décodage hardware
        mpv \
            --vo=gpu \
            --gpu-context=x11egl \
            --hwdec=no \
            --fullscreen \
            --loop-playlist=inf \
            --no-osc \
            --really-quiet \
            "$VIDEO" > /opt/pisignage/logs/mpv.log 2>&1 &

        echo "MPV relancé sans hwdec"
    fi
else
    echo "✗ MPV a échoué"
    tail -20 /opt/pisignage/logs/mpv.log
fi

exit 0