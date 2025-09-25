#!/bin/bash
# PiSignage - Fix video display pour Raspberry Pi
# Script pour faire fonctionner VLC/MPV avec affichage réel

echo "=== Fixing PiSignage Video Display ==="

# Arrêter tout
echo "Arrêt des players existants..."
sudo pkill -9 vlc
sudo pkill -9 mpv
sudo pkill -9 omxplayer
sleep 2

# Détection du modèle Pi
PI_MODEL=$(cat /proc/cpuinfo | grep 'Model' | cut -d: -f2 | xargs)
echo "Modèle détecté: $PI_MODEL"

# Vérifier si on a une vidéo
VIDEO_FILE="/opt/pisignage/media/BigBuckBunny_720p.mp4"
if [ ! -f "$VIDEO_FILE" ]; then
    echo "Erreur: Fichier vidéo non trouvé: $VIDEO_FILE"
    exit 1
fi

# Option 1: Essayer omxplayer (le plus fiable sur Pi)
echo "Test 1: omxplayer..."
if command -v omxplayer &> /dev/null; then
    omxplayer --loop --blank --no-osd -o hdmi "$VIDEO_FILE" &
    PLAYER_PID=$!
    echo "omxplayer lancé (PID: $PLAYER_PID)"
    exit 0
else
    echo "omxplayer non installé, installation..."
    sudo apt-get update && sudo apt-get install -y omxplayer
    if [ $? -eq 0 ]; then
        omxplayer --loop --blank --no-osd -o hdmi "$VIDEO_FILE" &
        PLAYER_PID=$!
        echo "omxplayer installé et lancé (PID: $PLAYER_PID)"
        exit 0
    fi
fi

# Option 2: VLC avec sortie MMAL pour Raspberry Pi
echo "Test 2: VLC avec MMAL..."
if [[ "$PI_MODEL" == *"Pi 3"* ]] || [[ "$PI_MODEL" == *"Pi 4"* ]]; then
    # Configuration spéciale pour Pi avec hardware acceleration
    cvlc --intf dummy \
         --vout mmal_vout \
         --mmal-display hdmi-1 \
         --mmal-layer 10 \
         --fullscreen \
         --no-video-title-show \
         --loop \
         "$VIDEO_FILE" > /tmp/vlc-mmal.log 2>&1 &
    PLAYER_PID=$!
    echo "VLC MMAL lancé (PID: $PLAYER_PID)"

    # Vérifier si ça fonctionne
    sleep 3
    if ps -p $PLAYER_PID > /dev/null; then
        echo "✓ VLC MMAL fonctionne!"
        exit 0
    else
        echo "✗ VLC MMAL a échoué"
    fi
fi

# Option 3: MPV avec DRM direct (sans X11)
echo "Test 3: MPV avec DRM..."
# Arrêter X11 temporairement pour DRM
sudo systemctl stop lightdm 2>/dev/null
sleep 2

sudo mpv --vo=drm \
     --drm-connector=1.HDMI-A-1 \
     --hwdec=auto \
     --fullscreen \
     --loop=inf \
     "$VIDEO_FILE" > /tmp/mpv-drm.log 2>&1 &
PLAYER_PID=$!
echo "MPV DRM lancé (PID: $PLAYER_PID)"

# Vérifier si ça fonctionne
sleep 3
if ps -p $PLAYER_PID > /dev/null; then
    echo "✓ MPV DRM fonctionne!"
    exit 0
else
    echo "✗ MPV DRM a échoué"
    # Redémarrer X11
    sudo systemctl start lightdm
fi

# Option 4: VLC classique avec framebuffer
echo "Test 4: VLC framebuffer..."
sudo chmod 666 /dev/fb0 2>/dev/null
FRAMEBUFFER=/dev/fb0 cvlc --intf dummy \
    --vout fb \
    --fbdev /dev/fb0 \
    --fullscreen \
    --loop \
    "$VIDEO_FILE" > /tmp/vlc-fb.log 2>&1 &
PLAYER_PID=$!
echo "VLC framebuffer lancé (PID: $PLAYER_PID)"

sleep 3
if ps -p $PLAYER_PID > /dev/null; then
    echo "✓ VLC framebuffer fonctionne!"
    exit 0
fi

echo "✗ ÉCHEC: Aucune méthode n'a fonctionné!"
echo "Vérifiez les logs dans /tmp/"
exit 1