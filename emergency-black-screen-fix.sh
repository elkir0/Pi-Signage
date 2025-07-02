#!/bin/bash

# Script de réparation d'urgence pour écran noir au boot

echo "=== Réparation d'urgence - Écran noir au boot ==="

# 1. Désactiver tous les services qui pourraient bloquer
echo "Désactivation des services problématiques..."
sudo systemctl disable lightdm 2>/dev/null || true
sudo systemctl disable gdm3 2>/dev/null || true
sudo systemctl disable chromium-kiosk 2>/dev/null || true
sudo systemctl disable vlc-signage 2>/dev/null || true
sudo systemctl disable pi-signage-startup 2>/dev/null || true

# 2. Restaurer la configuration boot basique
echo "Restauration de /boot/config.txt..."
sudo cp /boot/config.txt /boot/config.txt.backup.$(date +%s)

# Configuration minimale sûre
sudo tee /boot/config.txt << 'EOF'
# Configuration minimale pour Raspberry Pi
[all]
dtparam=audio=on
start_x=1
gpu_mem=128

# HDMI sûr
hdmi_safe=1
hdmi_force_hotplug=1
config_hdmi_boost=4

# Désactiver l'overscan
disable_overscan=1

[pi4]
dtoverlay=vc4-fkms-v3d
max_framebuffers=2

[pi3]
dtoverlay=vc4-fkms-v3d
EOF

# 3. Réparer cmdline.txt
echo "Vérification de /boot/cmdline.txt..."
if grep -q "plymouth" /boot/cmdline.txt; then
    echo "Suppression de plymouth..."
    sudo sed -i 's/splash plymouth.ignore-serial-consoles//g' /boot/cmdline.txt
    sudo sed -i 's/quiet//g' /boot/cmdline.txt
fi

# 4. Forcer le mode console d'abord
echo "Configuration du mode console..."
sudo systemctl set-default multi-user.target

# 5. Créer un service de diagnostic
sudo tee /etc/systemd/system/boot-diagnostic.service << 'EOF'
[Unit]
Description=Boot Diagnostic Service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo "System booted at $(date)" > /tmp/boot-diagnostic.log; systemctl list-units --failed >> /tmp/boot-diagnostic.log'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable boot-diagnostic.service

echo ""
echo "=== Actions effectuées ==="
echo "1. Services graphiques désactivés"
echo "2. Configuration boot restaurée (mode HDMI sûr)"
echo "3. Plymouth désactivé"
echo "4. Mode console activé"
echo "5. Service de diagnostic créé"
echo ""
echo "Redémarrez maintenant avec: sudo reboot"
echo ""
echo "Après redémarrage, vous devriez avoir accès en mode console."
echo "Connectez-vous et exécutez:"
echo "  sudo journalctl -b -p err"
echo "  sudo cat /tmp/boot-diagnostic.log"