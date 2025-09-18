#!/bin/bash
#
# Quick Install Script for PiSignage Desktop v3.0
# One-liner installation: curl -sSL [URL] | bash
#

set -e

# Configuration
REPO_URL="https://github.com/elkir0/Pi-Signage.git"
INSTALL_DIR="/opt/pisignage/pisignage-desktop"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Banner
echo -e "${BLUE}"
cat << "BANNER"
╔═══════════════════════════════════════════════════╗
║     PiSignage Desktop v3.0.1                      ║
║     Installation Rapide Automatique               ║
╚═══════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# Vérifications
echo "Vérification des prérequis..."

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Erreur: Ce script doit être exécuté en root${NC}"
   echo "Utilisez: curl -sSL [URL] | sudo bash"
   exit 1
fi

if ! command -v startx &>/dev/null && ! command -v wayfire &>/dev/null; then
   echo -e "${RED}Erreur: Raspberry Pi OS Desktop requis${NC}"
   echo "Version Lite détectée. Installez la version Desktop."
   exit 1
fi

# Installation des outils de base
echo "Installation des outils de base..."
apt-get update -qq
apt-get install -y -qq git curl wget || true

# Clonage du repository
echo "Téléchargement de PiSignage Desktop..."
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Mise à jour de l'installation existante..."
    cd "$INSTALL_DIR"
    git pull || true
else
    echo "Clonage du repository..."
    # Utiliser --depth 1 pour un clone plus rapide et éviter les problèmes
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || {
        # Si git échoue, essayer avec wget
        echo "Téléchargement alternatif..."
        wget -q -O /tmp/pisignage.tar.gz https://github.com/elkir0/Pi-Signage/archive/main.tar.gz
        mkdir -p "$INSTALL_DIR"
        tar -xzf /tmp/pisignage.tar.gz -C "$INSTALL_DIR" --strip-components=1
        rm /tmp/pisignage.tar.gz
    }
    cd "$INSTALL_DIR"
fi

# Rendre les scripts exécutables
chmod +x install.sh
chmod +x modules/*.sh

# Lancer l'installation
echo ""
echo -e "${GREEN}Lancement de l'installation...${NC}"
echo ""

# Lancer l'installation directe (sans interactivité)
./install.sh

# Finalisation
IP=$(hostname -I | cut -d' ' -f1)

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Installation terminée avec succès! 🎉${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "Interface web: http://$IP/"
echo "User: admin / Pass: admin"
echo ""
echo "Redémarrage recommandé: sudo reboot"
echo ""
