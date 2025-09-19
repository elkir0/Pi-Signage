#!/bin/bash

echo "=== CONFIGURATION NODM DIRECTE ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Configure nodm as default
echo "1. Configuration de nodm..."
sudo bash -c 'echo "2" | dpkg-reconfigure lightdm' 2>/dev/null
sudo bash -c 'echo "/usr/sbin/nodm" > /etc/X11/default-display-manager'

# Enable nodm
sudo sed -i 's/NODM_ENABLED=.*/NODM_ENABLED=true/' /etc/default/nodm
sudo sed -i 's/NODM_USER=.*/NODM_USER=pi/' /etc/default/nodm

# Install openbox for lightweight window manager
sudo apt install -y openbox

# Disable lightdm and enable nodm
echo "2. Switching to nodm..."
sudo systemctl stop lightdm
sudo systemctl disable lightdm
sudo systemctl enable nodm
sudo systemctl start nodm

sleep 5

echo "3. Checking status..."
ps aux | grep -E "(nodm|chromium|Xorg)" | grep -v grep | head -5

echo ""
echo "=== NODM CONFIGURE ==="
echo "Redémarrez maintenant: sudo reboot"
echo "Après redémarrage, la vidéo devrait se lancer automatiquement!"

EOF