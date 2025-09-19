#!/bin/bash

echo "=== CREATION PLAYER WEB SIMPLE ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Stop everything
pkill -f chromium
pkill -f vlc

# Create a very simple web server to serve the video
echo "Création d'un serveur web local..."

# Install simple http server
sudo apt install -y python3

# Create simple HTML with inline video
cat > /opt/videos/simple.html << 'HTML'
<!DOCTYPE html>
<html style="height:100%;margin:0;padding:0;">
<head>
    <meta charset="UTF-8">
    <title>Video</title>
</head>
<body style="height:100%;margin:0;padding:0;background:black;">
    <video style="width:100%;height:100%;" autoplay loop muted>
        <source src="test.mp4" type="video/mp4">
        Your browser does not support video.
    </video>
</body>
</html>
HTML

# Start simple web server
cd /opt/videos
python3 -m http.server 8080 &

sleep 2

# Launch chromium pointing to local server
export DISPLAY=:0
chromium-browser \
    --kiosk \
    --no-sandbox \
    --disable-web-security \
    --disable-features=TranslateUI \
    --disable-dev-shm-usage \
    --autoplay-policy=no-user-gesture-required \
    http://localhost:8080/simple.html &

echo ""
echo "Serveur web lancé sur port 8080"
echo "Chromium lancé avec http://localhost:8080/simple.html"
echo ""
echo "Vérification:"
ps aux | grep -E "(python3|chromium)" | grep -v grep | head -3

echo ""
echo "La vidéo devrait maintenant s'afficher!"

EOF