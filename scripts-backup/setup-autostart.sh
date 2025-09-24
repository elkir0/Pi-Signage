#!/bin/bash

# Configure le démarrage automatique pour l'utilisateur pi

echo "Configuration autostart pour utilisateur pi..."

# Créer le fichier autostart pour OpenBox (utilisateur pi)
cat << 'EOF' > /tmp/openbox-autostart
# PiSignage Autostart Configuration

# Désactiver économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Cacher le curseur
unclutter -idle 1 -root &

# Permissions X11
xhost +local:

# Attendre un peu pour stabilité
sleep 5

# Lancer le script vidéo
/opt/pisignage/scripts/autostart-video.sh &

EOF

# Copier vers le bon endroit
sudo -u pi mkdir -p /home/pi/.config/openbox
sudo cp /tmp/openbox-autostart /home/pi/.config/openbox/autostart
sudo chown pi:pi /home/pi/.config/openbox/autostart
sudo chmod +x /home/pi/.config/openbox/autostart

# Rendre le script vidéo exécutable
sudo chmod +x /opt/pisignage/scripts/autostart-video.sh
sudo chown pi:pi /opt/pisignage/scripts/autostart-video.sh

# Créer service systemd de backup
cat << 'EOF' > /tmp/pisignage-display.service
[Unit]
Description=PiSignage Display Service
After=graphical.target
Wants=graphical.target

[Service]
Type=simple
User=pi
Environment="DISPLAY=:0"
Environment="HOME=/home/pi"
ExecStartPre=/bin/sleep 10
ExecStart=/opt/pisignage/scripts/autostart-video.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
EOF

sudo cp /tmp/pisignage-display.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pisignage-display.service

echo "✅ Configuration autostart terminée"
echo ""
echo "Le système va maintenant:"
echo "1. Démarrer automatiquement après boot"
echo "2. Lancer MPV en priorité (plus stable)"
echo "3. Fallback sur VLC si MPV échoue"
echo "4. Afficher une image si tout échoue"
echo ""
echo "Redémarrer pour appliquer: sudo reboot"