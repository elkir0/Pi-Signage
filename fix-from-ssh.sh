#!/bin/bash

# Réparation rapide depuis SSH

echo "=== Réparation rapide Pi Signage ==="

# 1. Arrêter tous les services
echo "Arrêt des services..."
sudo systemctl stop chromium-kiosk 2>/dev/null || true
sudo systemctl stop vlc-signage 2>/dev/null || true
sudo systemctl stop lightdm 2>/dev/null || true
sudo systemctl stop pi-signage-startup 2>/dev/null || true

# 2. Désactiver temporairement le boot manager
echo "Désactivation du boot manager..."
sudo systemctl disable pi-signage-startup

# 3. Vérifier les erreurs
echo ""
echo "=== Erreurs système ==="
sudo journalctl -b -p err | tail -50

echo ""
echo "=== Services en échec ==="
sudo systemctl list-units --failed

echo ""
echo "=== Contenu de config.txt ==="
cat /boot/config.txt | grep -E "(hdmi|gpu|dtoverlay)"

echo ""
echo "Pour réparer :"
echo "1. Exécutez: sudo raspi-config"
echo "   - Advanced Options > GL Driver > G2 GL (Fake KMS)"
echo "   - Display Options > Resolution > Mode par défaut"
echo "2. Ou utilisez le mode HDMI sûr :"
echo "   sudo sed -i 's/#hdmi_safe=1/hdmi_safe=1/' /boot/config.txt"
echo "3. Redémarrez : sudo reboot"