#!/bin/bash

echo "=== RELANCEMENT INTERFACE GRAPHIQUE AVEC VIDEO ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Start X server and desktop
echo "Démarrage de l'interface graphique..."
sudo systemctl start lightdm

sleep 5

# Check if X is running
if pgrep -x "Xorg" > /dev/null; then
    echo "✓ Interface graphique démarrée"
else
    echo "Tentative avec startx..."
    # If not root, switch to pi user context
    sudo -u pi startx &
    sleep 5
fi

# Now launch the video
echo ""
echo "Lancement de la vidéo..."
export DISPLAY=:0

# Kill any previous video player
pkill -f vlc 2>/dev/null
pkill -f mpv 2>/dev/null

# Use the light video
VIDEO="/opt/videos/light-video.mp4"
if [ ! -f "$VIDEO" ]; then
    VIDEO="/opt/videos/test.mp4"
fi

# Launch VLC
sudo -u pi DISPLAY=:0 cvlc --fullscreen --loop --intf dummy --no-video-title $VIDEO > /dev/null 2>&1 &

sleep 3

echo ""
echo "=== STATUT ==="
ps aux | grep -E "(Xorg|vlc)" | grep -v grep | head -3
echo ""
echo "L'interface graphique devrait être revenue avec la vidéo en lecture!"

EOF