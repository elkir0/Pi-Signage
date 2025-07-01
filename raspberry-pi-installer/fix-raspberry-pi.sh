#!/bin/bash

# Script de réparation manuelle pour Raspberry Pi
echo "=== Réparation manuelle du Raspberry Pi ==="
echo ""
echo "Ce script va réparer dpkg et réinstaller les paquets manquants"
echo ""

# 1. Réparer dpkg
echo "1. Réparation de dpkg..."
sudo dpkg --configure -a

# 2. Réparer les dépendances
echo ""
echo "2. Réparation des dépendances..."
sudo apt-get update --fix-missing
sudo apt-get install -f -y

# 3. Nettoyer
echo ""
echo "3. Nettoyage du cache..."
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove -y

# 4. Installer les paquets manquants
echo ""
echo "4. Installation des paquets manquants..."

# PHP et nginx
echo "   - Installation de PHP et nginx..."
sudo apt-get install -y nginx php8.2-fpm php8.2-cli php8.2-common php8.2-curl php8.2-xml php8.2-mbstring php8.2-zip

# Chromium
echo "   - Installation de Chromium..."
sudo apt-get install -y chromium-browser xserver-xorg-core xinit x11-xserver-utils unclutter

# Glances
echo "   - Installation de Glances..."
sudo apt-get install -y glances apache2-utils

# Autres outils
echo "   - Installation des outils..."
sudo apt-get install -y lsof git python3-pip ffmpeg

# 5. Vérifier les services
echo ""
echo "5. Vérification des services..."
sudo systemctl status nginx --no-pager || true
sudo systemctl status php8.2-fpm --no-pager || true

echo ""
echo "=== Réparation terminée ==="
echo ""
echo "Vous pouvez maintenant relancer l'installation :"
echo "cd ~/Pi-Signage/raspberry-pi-installer/scripts"
echo "sudo ./main_orchestrator.sh"