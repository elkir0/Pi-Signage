#!/bin/bash
#
# PiSignage v0.8.0 - Deploy Screenshot Fix
# Déploiement des corrections pour l'API screenshot et playlist
#

set -e

# Configuration
PI_HOST="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================="
echo "PiSignage - Déploiement Corrections"
echo "========================================="

# Test connexion
echo -e "${YELLOW}Test connexion au Pi...${NC}"
sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" "echo 'Connexion OK'" || {
    echo -e "${RED}Erreur de connexion${NC}"
    exit 1
}

# Copier les fichiers
echo -e "${YELLOW}Copie des fichiers...${NC}"

# APIs
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no \
    web/api/playlist-simple.php \
    web/api/screenshot-raspi2png.php \
    "$PI_USER@$PI_HOST:/opt/pisignage/web/api/"

# Script d'installation raspi2png
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no \
    scripts/install-raspi2png.sh \
    "$PI_USER@$PI_HOST:/opt/pisignage/scripts/"

# Interface mise à jour
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no \
    web/index.php \
    "$PI_USER@$PI_HOST:/opt/pisignage/web/"

# Installer raspi2png
echo -e "${YELLOW}Installation de raspi2png...${NC}"
sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_HOST" << 'EOF'
cd /opt/pisignage
chmod +x scripts/install-raspi2png.sh
sudo scripts/install-raspi2png.sh

# Fix permissions
sudo chown -R www-data:www-data /opt/pisignage/web/api/
sudo chmod 755 /opt/pisignage/web/api/*.php

# Create cache directories
sudo mkdir -p /dev/shm/pisignage-screenshots
sudo chown www-data:www-data /dev/shm/pisignage-screenshots

# Add www-data to video group for framebuffer access
sudo usermod -a -G video www-data

# Restart services
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

echo "Installation terminée"
EOF

# Test des APIs
echo -e "${YELLOW}Test des APIs...${NC}"

# Test playlist API
echo "Test API Playlist..."
curl -s "http://$PI_HOST/api/playlist-simple.php" | jq . || echo "API playlist simple OK"

# Test screenshot API status
echo "Test API Screenshot..."
curl -s "http://$PI_HOST/api/screenshot-raspi2png.php?action=status" | jq . || echo "API screenshot status"

echo ""
echo "========================================="
echo -e "${GREEN}Déploiement terminé!${NC}"
echo "========================================="
echo ""
echo "APIs déployées:"
echo "  - /api/playlist-simple.php"
echo "  - /api/screenshot-raspi2png.php"
echo ""
echo "Ouvrir: http://$PI_HOST/"
echo ""