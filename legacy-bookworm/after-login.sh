#!/bin/bash

echo "=== LANCEMENT VIDEO APRES CONNEXION MANUELLE ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Check if user is logged in graphically
echo "Vérification de la session graphique..."
who

# Launch video on the graphical session
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Kill old instances
pkill -f vlc 2>/dev/null
pkill -f chromium 2>/dev/null

# Launch simple video player
echo "Lancement de la vidéo..."
cvlc --fullscreen --loop --intf dummy /opt/videos/light-video.mp4 > /dev/null 2>&1 &

echo ""
echo "La vidéo devrait maintenant s'afficher après votre connexion!"
echo ""
echo "Pour automatiser au prochain redémarrage, je vais créer un autostart."

# Create autostart for next boot
mkdir -p /home/pi/.config/autostart
cat > /home/pi/.config/autostart/video.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Video Player
Exec=cvlc --fullscreen --loop --intf dummy /opt/videos/light-video.mp4
Hidden=false
X-GNOME-Autostart-enabled=true
DESKTOP

echo "✓ Autostart configuré pour les prochains démarrages"

EOF