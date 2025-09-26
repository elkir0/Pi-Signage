#!/bin/bash

# Script de déploiement rapide des corrections sur Raspberry Pi
# Usage: bash deploy-fix.sh <IP_RASPBERRY>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "\n${BLUE}═══ $1 ═══${NC}\n"; }

# Vérifier l'argument IP
if [ -z "$1" ]; then
    log_error "Usage: bash deploy-fix.sh <IP_RASPBERRY>"
    echo "Exemple: bash deploy-fix.sh 192.168.1.103"
    exit 1
fi

RASPI_IP="$1"
RASPI_USER="pi"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Déploiement des corrections PiSignage v0.8.0              ║${NC}"
echo -e "${BLUE}║                    Raspberry Pi: $RASPI_IP                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo

# Test de connexion
log_step "Test de connexion SSH"
if ssh -o ConnectTimeout=5 ${RASPI_USER}@${RASPI_IP} "echo 'SSH OK'" 2>/dev/null; then
    log_info "Connexion SSH établie"
else
    log_error "Impossible de se connecter au Raspberry Pi"
    echo "Vérifiez que:"
    echo "  1. Le Raspberry Pi est allumé et connecté au réseau"
    echo "  2. L'adresse IP est correcte: $RASPI_IP"
    echo "  3. SSH est activé sur le Raspberry Pi"
    echo "  4. Vous avez configuré l'authentification par clé SSH ou connaissez le mot de passe"
    exit 1
fi

# Copier les fichiers corrigés
log_step "Copie des fichiers corrigés"

# Créer une archive temporaire
TEMP_ARCHIVE="/tmp/pisignage-fix-$(date +%s).tar.gz"
tar -czf $TEMP_ARCHIVE \
    -C /opt/pisignage \
    web/config.php \
    web/api/system.php \
    web/api/media.php \
    web/api/playlist.php \
    web/api/upload.php \
    config/nginx-pisignage.conf \
    config/php-upload.ini \
    install.sh 2>/dev/null || true

# Transférer l'archive
scp -q $TEMP_ARCHIVE ${RASPI_USER}@${RASPI_IP}:/tmp/
log_info "Fichiers transférés"

# Appliquer les corrections sur le Raspberry Pi
log_step "Application des corrections"

ssh ${RASPI_USER}@${RASPI_IP} << 'ENDSCRIPT'
set -e

# Extraire les fichiers
cd /opt/pisignage
sudo tar -xzf /tmp/pisignage-fix-*.tar.gz

# Appliquer la configuration nginx
if [ -f /opt/pisignage/config/nginx-pisignage.conf ]; then
    sudo cp /opt/pisignage/config/nginx-pisignage.conf /etc/nginx/sites-available/pisignage
    sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# Appliquer la configuration PHP
if [ -f /etc/php/8.2/fpm/php.ini ]; then
    sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' /etc/php/8.2/fpm/php.ini
    sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' /etc/php/8.2/fpm/php.ini
    sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini
    sudo sed -i 's/max_input_time = .*/max_input_time = 300/' /etc/php/8.2/fpm/php.ini
    sudo sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.2/fpm/php.ini
fi

# Créer les répertoires nécessaires
sudo mkdir -p /opt/pisignage/data
sudo mkdir -p /opt/pisignage/logs
sudo mkdir -p /opt/pisignage/playlists
sudo mkdir -p /tmp/nginx_upload

# Permissions
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R pi:pi /opt/pisignage/data
sudo chown -R pi:pi /opt/pisignage/logs
sudo chown -R pi:pi /opt/pisignage/playlists
sudo chown www-data:www-data /tmp/nginx_upload

# Installer les extensions PHP manquantes si nécessaire
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    php8.2-sqlite3 \
    php8.2-mbstring \
    php8.2-gd \
    php8.2-xml \
    php8.2-curl \
    sqlite3 2>/dev/null || true

# Redémarrer les services
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

# Nettoyer
rm -f /tmp/pisignage-fix-*.tar.gz

echo "Corrections appliquées avec succès!"
ENDSCRIPT

# Nettoyer l'archive locale
rm -f $TEMP_ARCHIVE

log_info "Corrections déployées avec succès!"

# Test de l'upload
log_step "Test de l'interface web"

# Attendre que les services redémarrent
sleep 3

# Tester l'API
if curl -s "http://${RASPI_IP}/api/system.php?action=stats" | grep -q "success"; then
    log_info "API système fonctionnelle"
else
    log_warn "L'API système pourrait nécessiter une vérification"
fi

if curl -s "http://${RASPI_IP}/api/media.php" | grep -q "success\|data"; then
    log_info "API média fonctionnelle"
else
    log_warn "L'API média pourrait nécessiter une vérification"
fi

echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Déploiement terminé avec succès!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo
echo "Interface web disponible sur:"
echo "  • http://${RASPI_IP}/"
echo
echo "Pour tester l'upload de gros fichiers:"
echo "  1. Ouvrez http://${RASPI_IP}/ dans votre navigateur"
echo "  2. Allez dans 'Gestion des médias'"
echo "  3. Uploadez un fichier jusqu'à 500MB"
echo
echo "Si vous rencontrez encore des problèmes, vérifiez les logs:"
echo "  ssh ${RASPI_USER}@${RASPI_IP} 'tail -f /opt/pisignage/logs/nginx_error.log'"
echo