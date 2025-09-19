#!/bin/bash
# Solution VLC Kiosk simple et fonctionnelle pour Raspberry Pi

echo "=== Configuration VLC Kiosk pour piSignage ==="

# 1. Créer le répertoire de scripts
sudo mkdir -p /opt/scripts
sudo mkdir -p /opt/videos

# 2. Créer le script de lecture VLC
sudo tee /opt/scripts/start-vlc-kiosk.sh > /dev/null << 'SCRIPT'
#!/bin/bash

# Attendre que le système soit prêt
sleep 5

# Configuration de l'affichage
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Désactiver l'économiseur d'écran si X est disponible
if xset -q &>/dev/null; then
    xset s off
    xset -dpms
    xset s noblank
fi

# Chemins des vidéos
VIDEO_DIR="/opt/videos"
PLAYLIST="/opt/videos/playlist.m3u"

# Créer une playlist si elle n'existe pas
if [ ! -f "$PLAYLIST" ]; then
    find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.webm" \) > "$PLAYLIST"
fi

# Lancer VLC en mode kiosk
cvlc \
    --fullscreen \
    --loop \
    --no-video-title-show \
    --no-mouse-events \
    --no-keyboard-events \
    --intf dummy \
    --vout xcb_x11 \
    "$PLAYLIST" 2>/dev/null
SCRIPT

# 3. Rendre le script exécutable
sudo chmod +x /opt/scripts/start-vlc-kiosk.sh

# 4. Créer le service systemd
sudo tee /etc/systemd/system/vlc-kiosk.service > /dev/null << 'SERVICE'
[Unit]
Description=VLC Kiosk Mode for Pi Signage
After=graphical.target

[Service]
Type=simple
User=pi
Group=pi
Environment="HOME=/home/pi"
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/home/pi/.Xauthority"
ExecStartPre=/bin/sleep 10
ExecStart=/opt/scripts/start-vlc-kiosk.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
SERVICE

# 5. Configurer l'autologin graphique
sudo raspi-config nonint do_boot_behaviour B4

# 6. Configurer l'autostart pour LXDE
mkdir -p /home/pi/.config/autostart
tee /home/pi/.config/autostart/vlc-kiosk.desktop > /dev/null << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=VLC Kiosk
Exec=/opt/scripts/start-vlc-kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
DESKTOP

# 7. Optimiser la mémoire GPU pour le décodage vidéo
if ! grep -q "gpu_mem=" /boot/firmware/config.txt 2>/dev/null && ! grep -q "gpu_mem=" /boot/config.txt 2>/dev/null; then
    CONFIG_FILE="/boot/firmware/config.txt"
    [ ! -f "$CONFIG_FILE" ] && CONFIG_FILE="/boot/config.txt"
    echo "gpu_mem=128" | sudo tee -a "$CONFIG_FILE"
fi

# 8. Recharger systemd et activer le service
sudo systemctl daemon-reload
sudo systemctl enable vlc-kiosk.service

echo "=== Configuration terminée ==="
echo "Le système va redémarrer pour appliquer les changements..."
echo "Après le redémarrage, VLC démarrera automatiquement en mode kiosk"
