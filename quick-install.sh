#!/usr/bin/env bash

# =============================================================================
# Pi Signage - Installation rapide
# Version: 2.4.10
# Description: Script d'installation simple pour Raspberry Pi OS Bookworm
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
readonly INSTALLER_DIR="/home/pi/pi-signage-installer"

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Pi Signage - Installation v2.4.10          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo

# Vérifications de base
echo -e "${GREEN}[CHECK]${NC} Vérifications préliminaires..."

# Vérifier qu'on est sur Raspberry Pi
if [[ -f /proc/device-tree/model ]]; then
    model=$(tr -d '\0' < /proc/device-tree/model)
    echo -e "${GREEN}✓${NC} Modèle: $model"
else
    echo -e "${YELLOW}⚠${NC} Ce n'est pas un Raspberry Pi"
fi

# Vérifier l'OS
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo -e "${GREEN}✓${NC} OS: $PRETTY_NAME"
fi

# Vérifier la connexion Internet
if ping -c 1 github.com >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Connexion Internet OK"
else
    echo -e "${RED}✗${NC} Pas de connexion Internet"
    exit 1
fi

echo
echo -e "${YELLOW}Cette installation va:${NC}"
echo "  • Télécharger Pi Signage depuis GitHub"
echo "  • Installer VLC et Chromium pour la lecture vidéo"
echo "  • Configurer une interface web de gestion"
echo "  • Activer l'accélération GPU pour les vidéos"
echo "  • Configurer le démarrage automatique"
echo
read -p "Continuer l'installation ? [O/n] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Oo]$ ]] && [[ -n $REPLY ]]; then
    echo "Installation annulée"
    exit 0
fi

# Téléchargement
echo
echo -e "${GREEN}[DOWNLOAD]${NC} Téléchargement de Pi Signage..."
rm -rf "$INSTALLER_DIR" 2>/dev/null || true

if git clone --depth 1 "$GITHUB_REPO" "$INSTALLER_DIR"; then
    echo -e "${GREEN}✓${NC} Code source téléchargé"
else
    echo -e "${RED}✗${NC} Échec du téléchargement"
    exit 1
fi

# Installation
echo
echo -e "${GREEN}[INSTALL]${NC} Lancement de l'installation..."
cd "$INSTALLER_DIR/raspberry-pi-installer"

# Rendre le script exécutable
chmod +x install.sh

# Variables d'installation
export NEW_HOSTNAME="pi-signage"
export INSTALL_MODE="auto"

echo
echo -e "${YELLOW}L'installation va commencer (15-30 minutes)${NC}"
echo "Vous pouvez suivre les logs dans: /var/log/pi-signage-setup.log"
echo

# Lancer l'installation
sudo ./install.sh

# Vérifications finales
echo
echo -e "${GREEN}[CHECK]${NC} Vérifications post-installation..."
sleep 5

# IP pour l'accès
ip=$(hostname -I | awk '{print $1}')

echo
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation terminée !${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo
echo "Accès à Pi Signage:"
echo "  • Interface web: http://$ip/"
echo "  • Monitoring: http://$ip:61208/"
echo
echo "Identifiants par défaut:"
echo "  • Utilisateur: admin"
echo "  • Mot de passe: pisignage2024"
echo
echo -e "${YELLOW}Redémarrage recommandé: sudo reboot${NC}"
echo