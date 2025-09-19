#!/bin/bash

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'
echo "=== CONFIGURATION AUTOLOGIN SIMPLE ==="

# Create lightdm config directory if not exists
sudo mkdir -p /etc/lightdm/lightdm.conf.d/

# Create autologin config
sudo bash -c 'cat > /etc/lightdm/lightdm.conf.d/01-autologin.conf << EOL
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
user-session=LXDE-pi
greeter-session=lightdm-gtk-greeter
EOL'

# Backup and modify main config
sudo cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup 2>/dev/null

# Check if file exists, if not create it
if [ ! -f /etc/lightdm/lightdm.conf ]; then
    sudo bash -c 'cat > /etc/lightdm/lightdm.conf << EOL
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
EOL'
fi

# Use raspi-config for desktop autologin
sudo raspi-config nonint do_boot_behaviour B4

# Show config
echo ""
echo "=== Configuration actuelle ==="
echo "LightDM config.d:"
ls -la /etc/lightdm/lightdm.conf.d/ 2>/dev/null
cat /etc/lightdm/lightdm.conf.d/01-autologin.conf 2>/dev/null

echo ""
echo "=== Redémarrage du service ==="
sudo systemctl restart lightdm

echo ""
echo "Autologin configuré! Redémarrez le Pi pour tester."
echo "sudo reboot"

EOF