#!/bin/bash

echo "=== Installation environnement X11 minimal ==="

# Installer X11 et lightdm
sudo apt-get update
sudo apt-get install -y xserver-xorg x11-xserver-utils xinit lightdm openbox

# Configurer autologin pour lightdm
sudo tee /etc/lightdm/lightdm.conf > /dev/null << 'CONFIG'
[SeatDefaults]
autologin-user=pi
autologin-user-timeout=0
user-session=openbox
CONFIG

# Créer la session openbox
sudo mkdir -p /home/pi/.config/openbox
sudo tee /home/pi/.config/openbox/autostart > /dev/null << 'AUTOSTART'
#!/bin/bash
# Désactiver économiseur écran
xset s off
xset -dpms
xset s noblank

# Lancer VLC après 5 secondes
sleep 5
/opt/scripts/start-vlc-kiosk.sh &
AUTOSTART

sudo chmod +x /home/pi/.config/openbox/autostart
sudo chown -R pi:pi /home/pi/.config

# Activer lightdm
sudo systemctl enable lightdm
sudo systemctl set-default graphical.target

echo "Installation terminée. Redémarrage nécessaire."
