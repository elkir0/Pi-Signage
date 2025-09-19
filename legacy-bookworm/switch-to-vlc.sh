#!/bin/bash

echo "=== PASSAGE A VLC ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Kill chromium
echo "Arrêt de Chromium..."
pkill -f chromium

# Start VLC instead
echo "Lancement de VLC..."
export DISPLAY=:0

# Test if video file is readable
echo "Test du fichier vidéo..."
file /opt/videos/test.mp4
ls -lh /opt/videos/test.mp4

# Launch VLC with the video
cvlc --fullscreen --loop --intf dummy --vout x11 /opt/videos/test.mp4 2>/dev/null &

sleep 5

# Check if VLC is running
echo ""
echo "Vérification VLC:"
ps aux | grep vlc | grep -v grep

# Alternative: Use omxplayer (optimized for Raspberry Pi)
echo ""
echo "Installation omxplayer (optimisé pour Pi)..."
sudo apt install -y omxplayer

echo ""
echo "Test avec omxplayer..."
pkill -f vlc
omxplayer --loop --blank --no-osd /opt/videos/test.mp4 &

echo ""
echo "Vérifiez votre écran maintenant!"
echo "Vous devriez voir la vidéo Big Buck Bunny."

EOF