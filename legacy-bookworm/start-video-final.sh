#!/bin/bash

echo "=== LANCEMENT DE LA VIDEO ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'
# Check current status
echo "Checking current processes..."
ps aux | grep chromium | grep -v grep

# Kill any existing chromium
pkill -f chromium 2>/dev/null

# Launch video player
echo "Starting video player..."
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Start chromium in kiosk mode
DISPLAY=:0 chromium-browser \
    --kiosk \
    --start-fullscreen \
    --window-position=0,0 \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-infobars \
    --noerrdialogs \
    --disable-translate \
    --autoplay-policy=no-user-gesture-required \
    file:///opt/videos/player.html &

sleep 5

# Check if running
echo ""
echo "=== STATUS ==="
ps aux | grep chromium | grep -v grep | head -1
echo ""
echo "La vidéo devrait maintenant être visible sur votre TV!"
echo ""
echo "Pour que cela démarre automatiquement au boot,"
echo "le fichier autostart a été configuré."
EOF