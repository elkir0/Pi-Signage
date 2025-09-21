#!/bin/bash

echo "=== CONFIGURATION AUTOLOGIN FORCEE ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Stop lightdm first
echo "1. Arrêt de lightdm..."
sudo systemctl stop lightdm

# Method 1: Configure lightdm autologin properly
echo "2. Configuration LightDM pour autologin..."
sudo mkdir -p /etc/lightdm/lightdm.conf.d/

# Remove all existing configs
sudo rm -f /etc/lightdm/lightdm.conf
sudo rm -f /etc/lightdm/lightdm.conf.d/*

# Create fresh autologin config
sudo tee /etc/lightdm/lightdm.conf << 'LIGHTDM'
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
user-session=LXDE-pi
greeter-session=lightdm-greeter
LIGHTDM

# Method 2: Use getty autologin on tty1
echo "3. Configuration getty autologin..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf << 'GETTY'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I $TERM
Type=idle
GETTY

# Method 3: Create simple kiosk service that doesn't need login
echo "4. Création service kiosk simple..."
sudo tee /etc/systemd/system/pi-kiosk.service << 'SERVICE'
[Unit]
Description=Pi Video Kiosk
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/start-kiosk.sh
Restart=always
User=pi
Group=pi

[Install]
WantedBy=multi-user.target
SERVICE

# Create kiosk script
sudo tee /usr/local/bin/start-kiosk.sh << 'KIOSK'
#!/bin/bash

# Wait for system to be ready
sleep 10

# Start X server on tty1
xinit /usr/local/bin/video-player.sh -- :0 vt1 -nocursor
KIOSK

# Create video player script
sudo tee /usr/local/bin/video-player.sh << 'PLAYER'
#!/bin/bash

# Set display
export DISPLAY=:0

# Disable screensaver
xset s off
xset -dpms
xset s noblank

# Start minimal window manager
openbox &
sleep 2

# Launch video
VIDEO="/opt/videos/light-video.mp4"
if [ ! -f "$VIDEO" ]; then
    VIDEO="/opt/videos/test.mp4"
fi

# Use VLC
cvlc --fullscreen --loop --intf dummy $VIDEO
PLAYER

# Make scripts executable
sudo chmod +x /usr/local/bin/start-kiosk.sh
sudo chmod +x /usr/local/bin/video-player.sh

# Enable services
echo "5. Activation des services..."
sudo systemctl daemon-reload
sudo systemctl enable pi-kiosk.service

# Set to boot to multi-user (no GUI login needed)
sudo systemctl set-default multi-user.target

echo ""
echo "6. Redémarrage du système..."
sudo reboot

EOF