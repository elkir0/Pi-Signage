#!/bin/bash

# PiSignage v0.8.1 GOLDEN - Quick Install Script
# Ce script télécharge et exécute l'installeur complet depuis GitHub

set -e

# Configuration
GITHUB_RAW_URL="https://raw.githubusercontent.com/elkir0/Pi-Signage/main"
INSTALLER_SCRIPT="install-pisignage-v0.8.1-golden.sh"
TEMP_DIR="/tmp/pisignage-install"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
echo -e "${CYAN}"
echo "=================================================================="
echo "     PiSignage v0.8.1 GOLDEN - QUICK INSTALL                     "
echo "=================================================================="
echo "  Téléchargement et installation automatique depuis GitHub       "
echo "=================================================================="
echo -e "${NC}"

# Vérification des prérequis
echo -e "${BLUE}[INFO]${NC} Vérification des prérequis..."

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté avec sudo"
    echo "Usage: sudo $0"
    exit 1
fi

if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} curl ou wget requis pour le téléchargement"
    echo "Installation: sudo apt-get update && sudo apt-get install -y curl"
    exit 1
fi

if ! ping -c 1 google.com &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Connexion Internet requise"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Prérequis validés"

# Création du répertoire temporaire
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo -e "${BLUE}[INFO]${NC} Téléchargement de l'installeur depuis GitHub..."

# Téléchargement avec curl ou wget
if command -v curl &> /dev/null; then
    if curl -sSL -o "$INSTALLER_SCRIPT" "$GITHUB_RAW_URL/$INSTALLER_SCRIPT"; then
        echo -e "${GREEN}[OK]${NC} Installeur téléchargé avec curl"
    else
        echo -e "${RED}[ERROR]${NC} Échec du téléchargement avec curl"
        exit 1
    fi
elif command -v wget &> /dev/null; then
    if wget -q -O "$INSTALLER_SCRIPT" "$GITHUB_RAW_URL/$INSTALLER_SCRIPT"; then
        echo -e "${GREEN}[OK]${NC} Installeur téléchargé avec wget"
    else
        echo -e "${RED}[ERROR]${NC} Échec du téléchargement avec wget"
        exit 1
    fi
fi

# Vérification du fichier téléchargé
if [ ! -f "$INSTALLER_SCRIPT" ] || [ ! -s "$INSTALLER_SCRIPT" ]; then
    echo -e "${RED}[ERROR]${NC} Fichier installeur invalide"
    exit 1
fi

# Validation basique du script (vérification du shebang)
if ! head -1 "$INSTALLER_SCRIPT" | grep -q "#!/bin/bash"; then
    echo -e "${RED}[ERROR]${NC} Fichier installeur corrompu"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Fichier installeur validé"

# Permissions d'exécution
chmod +x "$INSTALLER_SCRIPT"

echo ""
echo -e "${PURPLE}[INFO]${NC} Lancement de l'installation PiSignage v0.8.1 GOLDEN..."
echo -e "${YELLOW}[WARNING]${NC} L'installation peut prendre 10-20 minutes selon votre Pi"
echo ""

# Pause de 3 secondes pour permettre l'annulation
echo -e "${BLUE}Démarrage dans 3 secondes... (Ctrl+C pour annuler)${NC}"
sleep 3

# Exécution de l'installeur
echo -e "${CYAN}=================================================================="
echo "             DÉBUT DE L'INSTALLATION COMPLÈTE"
echo "=================================================================="
echo -e "${NC}"

if bash "$INSTALLER_SCRIPT"; then
    echo ""
    echo -e "${GREEN}=================================================================="
    echo "          INSTALLATION QUICK TERMINÉE AVEC SUCCÈS !"
    echo "=================================================================="
    echo -e "${NC}"

    # Nettoyage
    cd /
    rm -rf "$TEMP_DIR"

    echo -e "${BLUE}[INFO]${NC} Fichiers temporaires nettoyés"
    echo -e "${PURPLE}[SUCCESS]${NC} PiSignage v0.8.1 GOLDEN est maintenant installé et opérationnel !"
    echo ""
    echo -e "${CYAN}Interface web accessible sur: http://$(hostname -I | awk '{print $1}')/${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}=================================================================="
    echo "              ERREUR LORS DE L'INSTALLATION"
    echo "=================================================================="
    echo -e "${NC}"
    echo -e "${RED}[ERROR]${NC} L'installation a échoué. Consultez les logs ci-dessus."
    echo -e "${BLUE}[INFO]${NC} Fichiers de débogage conservés dans: $TEMP_DIR"
    exit 1
fi