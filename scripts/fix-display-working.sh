#!/bin/bash
# PiSignage - Fix display pour VLC et MPV sur Raspberry Pi 4

echo "=== Fixing PiSignage Display Output ==="

# Arrêter les players existants
echo "Arrêt des players..."
pkill -9 vlc
pkill -9 mpv
sleep 2

# Configuration de l'environnement X11
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Vérifier que X11 fonctionne
if ! xdpyinfo &>/dev/null; then
    echo "X11 n'est pas disponible, démarrage de X..."
    sudo systemctl restart lightdm
    sleep 5
fi

# Installation des dépendances manquantes si nécessaire
echo "Vérification des dépendances..."
if ! command -v glxinfo &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y mesa-utils libgl1-mesa-dri libgles2-mesa
fi

VIDEO_FILE="/opt/pisignage/media/BigBuckBunny_720p.mp4"

echo "=== Test 1: MPV avec rendu logiciel X11 ==="
# Essayer MPV avec rendu purement logiciel (plus lent mais plus compatible)
LIBGL_ALWAYS_SOFTWARE=1 DISPLAY=:0 mpv \
    --vo=x11 \
    --hwdec=no \
    --fullscreen \
    --loop-playlist=inf \
    --no-osc \
    --no-input-default-bindings \
    "$VIDEO_FILE" > /tmp/mpv-software.log 2>&1 &
MPV_PID=$!
echo "MPV lancé en mode software (PID: $MPV_PID)"

sleep 5
if ps -p $MPV_PID > /dev/null; then
    echo "✓ MPV software fonctionne, capture d'écran..."
    sudo fbgrab /tmp/test-software.png
    echo "Screenshot: /tmp/test-software.png"
    exit 0
fi

echo "=== Test 2: VLC avec sortie OpenGL ==="
pkill -9 mpv
DISPLAY=:0 cvlc \
    --intf dummy \
    --vout glx \
    --gl=any \
    --fullscreen \
    --no-video-title-show \
    --loop \
    "$VIDEO_FILE" > /tmp/vlc-gl.log 2>&1 &
VLC_PID=$!
echo "VLC lancé avec OpenGL (PID: $VLC_PID)"

sleep 5
if ps -p $VLC_PID > /dev/null; then
    echo "✓ VLC OpenGL fonctionne, capture d'écran..."
    sudo fbgrab /tmp/test-gl.png
    echo "Screenshot: /tmp/test-gl.png"
    exit 0
fi

echo "=== Test 3: MPV avec GPU mais sans accélération matérielle ==="
pkill -9 vlc
DISPLAY=:0 mpv \
    --vo=gpu \
    --gpu-context=x11 \
    --hwdec=no \
    --fullscreen \
    --loop-playlist=inf \
    "$VIDEO_FILE" > /tmp/mpv-gpu-no-hwdec.log 2>&1 &
MPV_PID=$!
echo "MPV GPU sans hwdec (PID: $MPV_PID)"

sleep 5
if ps -p $MPV_PID > /dev/null; then
    echo "✓ MPV GPU fonctionne!"
    sudo fbgrab /tmp/test-gpu.png
    echo "Screenshot: /tmp/test-gpu.png"
    exit 0
fi

echo "✗ Échec des tests. Vérifiez les logs dans /tmp/"
exit 1