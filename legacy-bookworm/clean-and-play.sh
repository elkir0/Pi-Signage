#!/bin/bash

echo "=== NETTOYAGE ET LANCEMENT PROPRE ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Kill EVERYTHING that could be using the display
echo "Arrêt de tout..."
sudo pkill -f chromium
sudo pkill -f vlc
sudo pkill -f mpv
sudo pkill -f python3
sudo pkill -f firefox
sleep 3

# Check if MPV is installed
if ! command -v mpv &> /dev/null; then
    echo "Installation de MPV en cours..."
    sudo apt install -y mpv
fi

# Clear the display
export DISPLAY=:0
xset -dpms
xset s off
xset s noblank

echo ""
echo "Lancement de la vidéo avec MPV..."
# Launch MPV with the video
mpv --fs --loop-file=inf --no-osc --no-osd-bar --no-input-default-bindings --hwdec=auto --vo=gpu /opt/videos/test.mp4 > /dev/null 2>&1 &

sleep 5

# Check if MPV is running
echo ""
echo "Vérification:"
if pgrep -x "mpv" > /dev/null; then
    echo "✓ MPV est en cours d'exécution"
    ps aux | grep mpv | grep -v grep
else
    echo "✗ MPV n'est pas lancé, essai avec VLC..."
    # Fallback to VLC
    cvlc --fullscreen --loop --intf dummy --no-video-title /opt/videos/test.mp4 > /dev/null 2>&1 &
fi

echo ""
echo "=== STATUT ==="
echo "La vidéo devrait maintenant s'afficher!"
echo "Si vous voyez toujours la page violette:"
echo "1. Attendez 10 secondes"
echo "2. Si rien ne change, redémarrez le Pi"

EOF