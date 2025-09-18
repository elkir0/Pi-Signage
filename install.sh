#!/bin/bash
# =============================================================================
# PiSignage Desktop v3.0 - Script d'installation principal
# Pour Raspberry Pi OS Desktop (Bookworm/Bullseye)
# =============================================================================

set -e

# Configuration
VERSION="3.0.1"
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$INSTALL_DIR/modules"
LOG_FILE="/tmp/pisignage-install.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonctions utilitaires
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log "[INFO] $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "[ERROR] $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "[WARNING] $1"
}

print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔════════════════════════════════════════════════════╗
║     PiSignage Desktop v3.0.1                       ║
║     Installation Simplifiée                        ║
╚════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Vérifications préliminaires
check_requirements() {
    info "Vérification des prérequis..."
    
    # Vérifier Raspberry Pi OS Desktop
    if ! command -v startx &>/dev/null && ! command -v wayfire &>/dev/null; then
        error "Raspberry Pi OS Desktop est requis. Version Lite détectée."
    fi
    
    # Vérifier l'espace disque (minimum 1GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then
        error "Espace disque insuffisant. Minimum 1GB requis."
    fi
    
    # Vérifier les privilèges sudo
    if ! sudo -v &>/dev/null; then
        error "Privilèges sudo requis. Exécutez avec un utilisateur ayant les droits sudo."
    fi
    
    info "Prérequis validés ✓"
}

# Installation des modules
install_modules() {
    info "Installation des modules..."
    
    # Module 1: Configuration de base
    if [[ -f "$MODULES_DIR/01-base-config.sh" ]]; then
        info "Module 1/5: Configuration de base"
        sudo bash "$MODULES_DIR/01-base-config.sh"
    fi
    
    # Module 2: Interface web
    if [[ -f "$MODULES_DIR/02-web-interface.sh" ]]; then
        info "Module 2/5: Interface web"
        sudo bash "$MODULES_DIR/02-web-interface.sh"
    fi
    
    # Module 3: Media player
    if [[ -f "$MODULES_DIR/03-media-player.sh" ]]; then
        info "Module 3/5: Media player"
        sudo bash "$MODULES_DIR/03-media-player.sh"
    fi
    
    # Module 5: Services
    if [[ -f "$MODULES_DIR/05-services.sh" ]]; then
        info "Module 5/5: Services système"
        sudo bash "$MODULES_DIR/05-services.sh"
    fi
}

# Tests post-installation
post_install_tests() {
    info "Vérification de l'installation..."
    
    # Test Nginx
    if systemctl is-active --quiet nginx; then
        info "✓ Nginx actif"
    else
        warning "Nginx non actif"
    fi
    
    # Test PHP
    if systemctl is-active --quiet php*-fpm; then
        info "✓ PHP-FPM actif"
    else
        warning "PHP-FPM non actif"
    fi
    
    # Test interface web
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200\|403"; then
        info "✓ Interface web accessible"
    else
        warning "Interface web non accessible"
    fi
    
    # Test Chromium
    if command -v chromium-browser &>/dev/null || command -v chromium &>/dev/null; then
        info "✓ Chromium détecté"
    else
        warning "Chromium non détecté"
    fi
}

# Affichage des informations finales
show_summary() {
    local ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Installation terminée avec succès! 🎉${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo "📍 Interface web : http://${ip}/"
    echo ""
    echo "📋 Commandes disponibles :"
    echo "   pisignage-player start    # Démarrer le lecteur"
    echo "   pisignage-player stop     # Arrêter le lecteur"
    echo "   pisignage-player status   # Voir le status"
    echo ""
    echo "📁 Dossiers importants :"
    echo "   /opt/pisignage/videos/    # Vidéos"
    echo "   /var/www/pisignage/       # Interface web"
    echo ""
    echo "📝 Logs : $LOG_FILE"
    echo ""
}

# Programme principal
main() {
    # Initialisation
    print_banner
    
    # Créer le fichier de log
    touch "$LOG_FILE"
    chmod 666 "$LOG_FILE"
    
    log "Début installation PiSignage Desktop v${VERSION}"
    
    # Vérifications
    check_requirements
    
    # Installation
    install_modules
    
    # Tests
    post_install_tests
    
    # Résumé
    show_summary
    
    log "Installation terminée"
}

# Options de ligne de commande
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo "Options:"
        echo "  --help, -h     Afficher cette aide"
        echo "  --version, -v  Afficher la version"
        exit 0
        ;;
    --version|-v)
        echo "PiSignage Desktop v${VERSION}"
        exit 0
        ;;
esac

# Lancement
main "$@"