#!/bin/bash
# PiSignage - Script de lancement vidéo fonctionnel
# Solution validée pour VLC sur Raspberry Pi avec X11

echo "=== Starting PiSignage Video Player ==="

# Configuration de l'environnement
export XDG_RUNTIME_DIR=/run/user/1000
export DISPLAY=:0

# Arrêter les players existants
pkill -9 vlc
pkill -9 mpv
sleep 1

# Vérifier X11
if ! xdpyinfo &>/dev/null; then
    echo "X11 n'est pas disponible, redémarrage de lightdm..."
    sudo systemctl restart lightdm
    sleep 5
fi

# Lancer VLC (solution validée)
VIDEO_FILE="/opt/pisignage/media/BigBuckBunny_720p.mp4"

echo "Lancement de VLC..."
cvlc \
    --intf dummy \
    --vout x11 \
    --fullscreen \
    --loop \
    --no-video-title-show \
    "$VIDEO_FILE" > /opt/pisignage/logs/vlc.log 2>&1 &

VLC_PID=$!
echo "✓ VLC lancé avec succès (PID: $VLC_PID)"
echo "Vidéo en cours de lecture sur l'affichage"

exit 0