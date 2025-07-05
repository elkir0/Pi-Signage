#!/usr/bin/env bash

# =============================================================================
# Script de réparation pour Pi Signage v2.4.12
# Corrige les problèmes d'installation sur système existant
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly WEB_ROOT="/var/www/pi-signage"
readonly NGINX_CONFIG="/etc/nginx/sites-available/pi-signage"
readonly GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
readonly WEB_INTERFACE_DIR="web-interface"

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Réparation Pi Signage v2.4.12                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo

# Vérification root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

# 1. Déployer l'interface web
echo -e "\n${GREEN}[1/4]${NC} Déploiement de l'interface web..."

# Créer un répertoire temporaire
temp_dir="/tmp/pi-signage-repair-$(date +%s)"

# Cloner le dépôt
echo "Téléchargement depuis GitHub..."
if git clone --depth 1 "$GITHUB_REPO" "$temp_dir"; then
    echo -e "${GREEN}✓${NC} Code source téléchargé"
else
    echo -e "${RED}✗${NC} Échec du téléchargement"
    exit 1
fi

# Copier les fichiers web
echo "Installation de l'interface web..."
mkdir -p "$WEB_ROOT"

if [[ -d "$temp_dir/$WEB_INTERFACE_DIR" ]]; then
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/public" "$WEB_ROOT/" 2>/dev/null || true
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/includes" "$WEB_ROOT/" 2>/dev/null || true
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/api" "$WEB_ROOT/" 2>/dev/null || true
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/assets" "$WEB_ROOT/" 2>/dev/null || true
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/templates" "$WEB_ROOT/" 2>/dev/null || true
    
    # Créer config.php si manquant
    if [[ ! -f "$WEB_ROOT/includes/config.php" ]] && [[ -f "$temp_dir/$WEB_INTERFACE_DIR/includes/config.template.php" ]]; then
        cp "$temp_dir/$WEB_INTERFACE_DIR/includes/config.template.php" "$WEB_ROOT/includes/config.php"
        
        # Générer un mot de passe par défaut
        default_password="pisignage2024"
        password_hash=$(echo -n "$default_password" | sha512sum | cut -d' ' -f1)
        sed -i "s|{{WEB_ADMIN_PASSWORD_HASH}}|$password_hash|g" "$WEB_ROOT/includes/config.php"
        
        echo -e "${YELLOW}[INFO]${NC} Mot de passe par défaut: $default_password"
    fi
    
    echo -e "${GREEN}✓${NC} Interface web installée"
else
    echo -e "${RED}✗${NC} Dossier web-interface non trouvé"
fi

# Nettoyer
rm -rf "$temp_dir"

# 2. Corriger les permissions
echo -e "\n${GREEN}[2/4]${NC} Configuration des permissions..."

chown -R www-data:www-data "$WEB_ROOT" 2>/dev/null || true
chmod -R 755 "$WEB_ROOT" 2>/dev/null || true

# Créer les répertoires nécessaires
mkdir -p "$WEB_ROOT/temp" /opt/videos /tmp/pi-signage-progress
chmod 777 /tmp/pi-signage-progress
chown www-data:www-data "$WEB_ROOT/temp"

echo -e "${GREEN}✓${NC} Permissions configurées"

# 3. Corriger la configuration nginx
echo -e "\n${GREEN}[3/4]${NC} Configuration de nginx..."

# Détecter la version PHP
php_version=""
if grep -q "bookworm" /etc/os-release 2>/dev/null; then
    php_version="8.2"
elif grep -q "bullseye" /etc/os-release 2>/dev/null; then
    php_version="7.4"
elif command -v php >/dev/null 2>&1; then
    php_version=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null || echo "8.2")
else
    php_version="8.2"
fi

# Vérifier que le site par défaut est désactivé
if [[ -L /etc/nginx/sites-enabled/default ]]; then
    rm -f /etc/nginx/sites-enabled/default
    echo "Site par défaut désactivé"
fi

# Activer le site Pi Signage
if [[ -f "$NGINX_CONFIG" ]] && [[ ! -L /etc/nginx/sites-enabled/pi-signage ]]; then
    ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/pi-signage
    echo "Site Pi Signage activé"
fi

# Vérifier et redémarrer nginx
if nginx -t 2>/dev/null; then
    systemctl restart nginx
    echo -e "${GREEN}✓${NC} Nginx configuré et redémarré"
else
    echo -e "${RED}✗${NC} Configuration nginx invalide"
fi

# 4. Vérification finale
echo -e "\n${GREEN}[4/4]${NC} Vérification finale..."

# IP de la machine
ip_addr=$(hostname -I | awk '{print $1}')

# Test de l'interface
if curl -s -o /dev/null -w "%{http_code}" "http://localhost/" | grep -q "200\|302"; then
    echo -e "${GREEN}✓${NC} Interface web accessible"
else
    echo -e "${RED}✗${NC} Interface web non accessible"
fi

# Résumé
echo
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Réparation terminée !${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo
echo "Interface web : http://$ip_addr/"
echo "Utilisateur : admin"
echo "Mot de passe : pisignage2024"
echo
echo -e "${YELLOW}Note:${NC} Si l'interface n'est pas accessible, vérifiez :"
echo "  - Le service nginx : sudo systemctl status nginx"
echo "  - Les logs : sudo tail -f /var/log/nginx/error.log"
echo "  - Le pare-feu : sudo ufw status"
echo