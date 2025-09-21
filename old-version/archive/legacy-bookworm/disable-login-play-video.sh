#!/bin/bash

echo "=== DESACTIVATION LOGIN ET LECTURE VIDEO DIRECTE ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Stop getty (login prompt) on tty1
echo "1. Désactivation du prompt login..."
sudo systemctl stop getty@tty1.service
sudo systemctl disable getty@tty1.service

# Create a simple boot script that replaces getty
echo "2. Création script de boot direct..."
sudo tee /usr/local/bin/boot-video.sh << 'SCRIPT'
#!/bin/bash
# Clear screen
clear
echo "Chargement vidéo..."
sleep 5

# Play video in loop forever
while true; do
    # Try mplayer first
    if command -v mplayer &> /dev/null; then
        mplayer -vo fbdev2:/dev/fb0 -fs -really-quiet -loop 0 /opt/videos/light-video.mp4 2>/dev/null
    elif command -v vlc &> /dev/null; then
        cvlc --intf dummy --no-audio --loop /opt/videos/light-video.mp4 2>/dev/null
    else
        echo "Aucun lecteur vidéo disponible"
        sleep 10
    fi
    sleep 2
done
SCRIPT

sudo chmod +x /usr/local/bin/boot-video.sh

# Create systemd service to replace getty
echo "3. Création service de remplacement..."
sudo tee /etc/systemd/system/boot-video.service << 'SERVICE'
[Unit]
Description=Boot Video Player
After=multi-user.target
Conflicts=getty@tty1.service

[Service]
Type=simple
ExecStart=/usr/local/bin/boot-video.sh
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Enable new service
echo "4. Activation du nouveau service..."
sudo systemctl daemon-reload
sudo systemctl enable boot-video.service
sudo systemctl start boot-video.service

# Also kill current getty and start video immediately
echo "5. Lancement immédiat..."
sudo pkill -f getty
sudo pkill -f mplayer
sudo /usr/local/bin/boot-video.sh &

echo ""
echo "=== STATUT ==="
sleep 5
ps aux | grep -E "(boot-video|mplayer)" | grep -v grep | head -2
echo ""
echo "Le login devrait être remplacé par la vidéo!"

EOF