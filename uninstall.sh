#!/bin/bash
#
# Uninstall Script for PiSignage Desktop v3.0
#

set -e

# Configuration
BASE_DIR="/opt/pisignage"
WEB_DIR="/var/www/pisignage"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Options
KEEP_VIDEOS=false
KEEP_CONFIG=false

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-videos)
            KEEP_VIDEOS=true
            shift
            ;;
        --keep-config)
            KEEP_CONFIG=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --keep-videos    Conserver les vidéos"
            echo "  --keep-config    Conserver la configuration"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

echo "╔═══════════════════════════════════════════╗"
echo "║   Désinstallation PiSignage Desktop v3.0  ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# Confirmation
read -p "Êtes-vous sûr de vouloir désinstaller PiSignage? [o/N]: " confirm
if [[ ! "${confirm,,}" =~ ^(o|oui|y|yes)$ ]]; then
    echo "Désinstallation annulée"
    exit 0
fi

# Arrêt des services
echo "Arrêt des services..."
systemctl stop pisignage 2>/dev/null || true
systemctl stop pisignage-watchdog 2>/dev/null || true
systemctl disable pisignage 2>/dev/null || true
systemctl disable pisignage-watchdog 2>/dev/null || true

# Suppression des services
echo "Suppression des services systemd..."
rm -f /etc/systemd/system/pisignage.service
rm -f /etc/systemd/system/pisignage-watchdog.service
systemctl daemon-reload

# Suppression configuration nginx
echo "Suppression configuration web..."
rm -f /etc/nginx/sites-enabled/pisignage
rm -f /etc/nginx/sites-available/pisignage
rm -rf "$WEB_DIR"
systemctl reload nginx 2>/dev/null || true

# Suppression des liens symboliques
echo "Suppression des commandes..."
rm -f /usr/local/bin/pisignage-*

# Suppression fichiers
echo "Suppression des fichiers..."
if [[ "$KEEP_VIDEOS" == true ]]; then
    echo "  Conservation des vidéos..."
    mv "$BASE_DIR/videos" /tmp/pisignage_videos_backup 2>/dev/null || true
fi

if [[ "$KEEP_CONFIG" == true ]]; then
    echo "  Conservation de la configuration..."
    mv "$BASE_DIR/config" /tmp/pisignage_config_backup 2>/dev/null || true
fi

rm -rf "$BASE_DIR"

# Restauration si demandé
if [[ "$KEEP_VIDEOS" == true ]] && [[ -d /tmp/pisignage_videos_backup ]]; then
    mkdir -p "$BASE_DIR"
    mv /tmp/pisignage_videos_backup "$BASE_DIR/videos"
    echo -e "${GREEN}✓ Vidéos conservées dans $BASE_DIR/videos${NC}"
fi

if [[ "$KEEP_CONFIG" == true ]] && [[ -d /tmp/pisignage_config_backup ]]; then
    mkdir -p "$BASE_DIR"
    mv /tmp/pisignage_config_backup "$BASE_DIR/config"
    echo -e "${GREEN}✓ Configuration conservée dans $BASE_DIR/config${NC}"
fi

# Suppression utilisateur (optionnel)
read -p "Supprimer l'utilisateur pisignage? [o/N]: " del_user
if [[ "${del_user,,}" =~ ^(o|oui|y|yes)$ ]]; then
    userdel pisignage 2>/dev/null || true
    echo "✓ Utilisateur pisignage supprimé"
fi

# Suppression des logs
rm -f /var/log/pisignage*.log
rm -f /etc/logrotate.d/pisignage

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Désinstallation terminée${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

if [[ "$KEEP_VIDEOS" == true ]] || [[ "$KEEP_CONFIG" == true ]]; then
    echo "Données conservées dans $BASE_DIR"
fi

echo "Merci d'avoir utilisé PiSignage Desktop!"
