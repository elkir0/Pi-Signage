#!/bin/bash

echo "=== INSTALLATION RAPIDE CHROMIUM KIOSK + GPU ==="

# Installation des paquets essentiels uniquement
echo "Installation de Chromium et dépendances..."
sudo apt install -y chromium-browser xserver-xorg xinit x11-xserver-utils unclutter

# Configuration autologin
echo "Configuration de l'autologin..."
sudo raspi-config nonint do_boot_behaviour B4

# Création du script kiosk
echo "Création du script de lancement..."
cat > /home/pi/kiosk.sh << 'EOF'
#!/bin/bash
# Désactive l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Cache le curseur
unclutter -idle 0.5 -root &

# Lance Chromium avec GPU
chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --check-for-update-interval=31536000 \
    --disable-pinch \
    --overscroll-history-navigation=0 \
    --enable-gpu-rasterization \
    --enable-accelerated-2d-canvas \
    --enable-accelerated-video-decode \
    --ignore-gpu-blocklist \
    --disable-gpu-sandbox \
    --enable-features=VaapiVideoDecoder \
    --use-gl=egl \
    --disable-features=UseChromeOSDirectVideoDecoder \
    --autoplay-policy=no-user-gesture-required \
    'https://www.youtube.com/watch?v=LXb3EKWsInQ&autoplay=1&loop=1&playlist=LXb3EKWsInQ'
EOF

chmod +x /home/pi/kiosk.sh

# Autostart via .bashrc  
echo "Configuration de l'autostart..."
cat >> /home/pi/.bashrc << 'EOF'

# Auto-start kiosk mode
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ]; then
    [ -z "$DISPLAY" ] && export DISPLAY=:0
    /home/pi/kiosk.sh
fi
EOF

# Autostart via desktop entry
mkdir -p /home/pi/.config/autostart
cat > /home/pi/.config/autostart/kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Kiosk
Exec=/home/pi/kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

echo ""
echo "✓ Installation terminée!"
echo ""
echo "Appuyez sur une touche pour redémarrer..."
read -n 1
sudo reboot