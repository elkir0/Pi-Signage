#!/bin/bash

echo "=== SOLUTION FINALE SIMPLE ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Stop nodm which keeps launching Chromium
echo "Désactivation de nodm..."
sudo systemctl stop nodm
sudo systemctl disable nodm

# Kill everything
sudo killall -9 chromium chromium-browser mpv vlc 2>/dev/null
sleep 2

# Use the lightest video
VIDEO="/opt/videos/light-video.mp4"
if [ ! -f "$VIDEO" ]; then
    VIDEO="/opt/videos/ultra-light.mp4"
fi
if [ ! -f "$VIDEO" ]; then
    VIDEO="/opt/videos/test.mp4"
fi

echo "Utilisation de: $VIDEO"
ls -lh $VIDEO

# Try VLC with minimal settings
echo ""
echo "Lancement avec VLC (plus stable)..."
export DISPLAY=:0

cvlc --fullscreen \
     --loop \
     --intf dummy \
     --vout x11 \
     --no-video-title \
     --no-osd \
     $VIDEO > /dev/null 2>&1 &

VLC_PID=$!
sleep 5

if ps -p $VLC_PID > /dev/null; then
    echo "✓ VLC fonctionne!"
else
    echo "VLC a échoué, essai final avec mplayer..."
    sudo apt install -y mplayer
    mplayer -fs -loop 0 -really-quiet $VIDEO &
fi

echo ""
echo "=== STATUT FINAL ==="
ps aux | grep -E "(vlc|mplayer|mpv)" | grep -v grep | head -1
echo ""
echo "nodm est désactivé - plus d'icône Airplay!"
echo "La vidéo devrait tourner en boucle."

EOF