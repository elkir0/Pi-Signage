#!/bin/bash

echo "=== UTILISATION DE MPV (SIMPLE ET EFFICACE) ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Kill everything
pkill -f chromium
pkill -f vlc
pkill -f python3

# Install MPV (lightweight video player)
echo "Installation de MPV..."
sudo apt install -y mpv

# Launch MPV in fullscreen
echo "Lancement de MPV..."
export DISPLAY=:0

# Test with MPV
mpv --fullscreen --loop=inf --no-audio-display --really-quiet /opt/videos/test.mp4 &

sleep 3

# Check if running
echo ""
echo "Vérification:"
ps aux | grep mpv | grep -v grep

echo ""
echo "=== MPV LANCE ==="
echo "MPV est un lecteur vidéo simple et efficace."
echo "La vidéo devrait maintenant s'afficher en plein écran!"
echo ""
echo "Si toujours rien, essayez de vous connecter en VNC pour voir."

EOF