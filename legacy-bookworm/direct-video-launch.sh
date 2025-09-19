#!/bin/bash

echo "=== LANCEMENT DIRECT DE LA VIDEO ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Kill everything first
pkill -f chromium
pkill -f python3
pkill -f vlc
sleep 2

# Create a working HTML file with proper permissions
echo "Création du fichier HTML..."
sudo tee /opt/videos/working.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <style>
        * { margin: 0; padding: 0; }
        body { background: black; }
        video { width: 100vw; height: 100vh; }
    </style>
</head>
<body>
    <video autoplay loop muted controls>
        <source src="test.mp4" type="video/mp4">
    </video>
</body>
</html>
HTML

# Fix permissions
sudo chmod 755 /opt/videos
sudo chmod 644 /opt/videos/*

# Start simple HTTP server properly
cd /opt/videos
sudo python3 -m http.server 8000 > /dev/null 2>&1 &
SERVER_PID=$!
echo "Serveur lancé avec PID: $SERVER_PID"

sleep 3

# Test if server is working
echo "Test du serveur:"
curl -I http://localhost:8000/working.html

# Launch Chromium with the local server URL
export DISPLAY=:0
chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --no-first-run \
    --no-sandbox \
    --disable-dev-shm-usage \
    --user-data-dir=/tmp/chrome-kiosk \
    --autoplay-policy=no-user-gesture-required \
    http://localhost:8000/working.html &

echo ""
echo "Chromium lancé!"
echo ""
echo "Si ça ne marche toujours pas, essayons directement le fichier MP4:"
sleep 5

# Alternative: Open video file directly
pkill -f chromium
chromium-browser \
    --kiosk \
    --no-sandbox \
    --disable-dev-shm-usage \
    --user-data-dir=/tmp/chrome-direct \
    --autoplay-policy=no-user-gesture-required \
    file:///opt/videos/test.mp4 &

echo ""
echo "=== STATUT ==="
ps aux | grep -E "(python3|chromium)" | grep -v grep | head -2
echo ""
echo "La vidéo devrait s'afficher maintenant!"

EOF