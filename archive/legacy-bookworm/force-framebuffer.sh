#!/bin/bash

echo "=== FORCE VIDEO SUR FRAMEBUFFER ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Stop everything
echo "1. Arrêt de tout..."
sudo killall -9 vlc mplayer mpv 2>/dev/null
sudo systemctl stop pi-kiosk.service

# Clear the console and switch to tty1
echo "2. Basculement sur tty1..."
sudo chvt 1
sudo chmod 666 /dev/tty1
sudo chmod 666 /dev/fb0

# Hide console cursor and clear
echo "3. Masquage du curseur..."
sudo sh -c 'setterm -cursor off > /dev/tty1'
sudo sh -c 'clear > /dev/tty1'

# Install framebuffer imageviewer for testing
echo "4. Installation outils framebuffer..."
sudo apt install -y fbi

# Test with a static image first
echo "5. Test avec image statique..."
sudo fbi -T 1 -d /dev/fb0 -noverbose -a /usr/share/pixmaps/debian-logo.png 2>/dev/null &
sleep 3
sudo killall fbi 2>/dev/null

# Launch video player on framebuffer
echo "6. Lancement vidéo sur framebuffer..."

# Try with mplayer (better framebuffer support)
if ! command -v mplayer &> /dev/null; then
    sudo apt install -y mplayer
fi

# Launch mplayer directly on framebuffer
sudo mplayer -vo fbdev2 -vf scale=640:480 -zoom -xy 640 -fs -loop 0 /opt/videos/light-video.mp4 > /dev/null 2>&1 &

sleep 5

# If mplayer fails, try vlc
if ! pgrep mplayer > /dev/null; then
    echo "Mplayer échoué, essai avec VLC..."
    sudo cvlc --intf dummy --vout fb --fbdev /dev/fb0 --no-audio --loop /opt/videos/light-video.mp4 > /dev/null 2>&1 &
fi

# Create automatic startup script
echo "7. Création script de démarrage automatique..."
sudo tee /etc/rc.local << 'RCLOCAL'
#!/bin/bash
# Hide login prompt and play video
sleep 10
chvt 1
setterm -cursor off > /dev/tty1
clear > /dev/tty1
mplayer -vo fbdev2 -fs -loop 0 /opt/videos/light-video.mp4 > /dev/null 2>&1 &
exit 0
RCLOCAL

sudo chmod +x /etc/rc.local

echo ""
echo "=== STATUT ==="
ps aux | grep -E "(mplayer|vlc)" | grep -v grep | head -1
echo ""
echo "La vidéo devrait maintenant couvrir l'écran de login!"

EOF