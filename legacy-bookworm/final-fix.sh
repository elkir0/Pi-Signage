#!/bin/bash

echo "=== CONFIGURATION FINALE SIMPLE ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Kill any display manager attempts
sudo systemctl stop lightdm 2>/dev/null
sudo systemctl stop nodm 2>/dev/null

# Simple direct approach - use systemd to start X and chromium
echo "Creating simple autologin with systemd..."

# Create a simple service that starts everything
sudo tee /etc/systemd/system/kiosk.service << 'SERVICE'
[Unit]
Description=Kiosk Mode
After=multi-user.target

[Service]
Type=simple
User=pi
Group=pi
PAMName=login
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=tty
ExecStart=/home/pi/kiosk.sh
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

# Create the kiosk script
cat > /home/pi/kiosk.sh << 'KIOSK'
#!/bin/bash

# Start X server
xinit /home/pi/chromium-kiosk.sh -- :0 -nocursor &

# Keep service alive
while true; do
    sleep 10
done
KIOSK

# Create chromium kiosk script
cat > /home/pi/chromium-kiosk.sh << 'CHROMIUM'
#!/bin/bash

# Disable screensaver
xset s off
xset -dpms
xset s noblank

# Start window manager
openbox &

# Wait for desktop
sleep 3

# Start chromium
chromium-browser \
    --kiosk \
    --start-fullscreen \
    --window-position=0,0 \
    --no-first-run \
    --noerrdialogs \
    --disable-infobars \
    --no-default-browser-check \
    --disable-translate \
    --no-sandbox \
    --disable-dev-shm-usage \
    --autoplay-policy=no-user-gesture-required \
    file:///opt/videos/player.html
CHROMIUM

chmod +x /home/pi/kiosk.sh
chmod +x /home/pi/chromium-kiosk.sh

# Disable all display managers
sudo systemctl disable lightdm 2>/dev/null
sudo systemctl disable nodm 2>/dev/null

# Enable our kiosk service
sudo systemctl daemon-reload
sudo systemctl enable kiosk.service

# Set to multi-user target (no GUI login)
sudo systemctl set-default multi-user.target

echo ""
echo "=== CONFIGURATION COMPLETE ==="
echo ""
echo "Le système est configuré pour:"
echo "1. Démarrer en mode console (multi-user)"
echo "2. Lancer automatiquement le service kiosk"
echo "3. Afficher la vidéo en plein écran"
echo ""
echo "Redémarrez maintenant: sudo reboot"
echo ""
echo "Après redémarrage, la vidéo devrait s'afficher directement!"

EOF