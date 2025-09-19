#!/bin/bash

echo "=== CONFIGURATION AUTOSTART FINAL ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'
# Kill any running video
pkill -f chromium 2>/dev/null
pkill -f vlc 2>/dev/null

# Check if desktop session is running
echo "Desktop session check:"
loginctl show-session $(loginctl | grep pi | awk '{print $1}') | grep Type

# Launch from the graphical session directly
echo "Launching video on display..."

# Method 1: Through systemd user service
systemctl --user start pi-video-kiosk.service 2>/dev/null

# Method 2: Direct launch on local display
sudo -u pi bash -c 'DISPLAY=:0 chromium-browser --kiosk --no-sandbox --disable-dev-shm-usage --autoplay-policy=no-user-gesture-required file:///opt/videos/player.html' &

echo ""
echo "Vérification dans 5 secondes..."
sleep 5

ps aux | grep -E "(chromium|vlc)" | grep -v grep | head -2

echo ""
echo "=== IMPORTANT ==="
echo "Vérifiez votre TV maintenant!"
echo "La vidéo Big Buck Bunny devrait être en lecture."
echo ""
echo "Si vous voyez toujours le bureau au lieu de la vidéo,"
echo "connectez-vous physiquement sur le Pi (clavier/souris)"
echo "ou utilisez VNC pour lancer manuellement."
EOF