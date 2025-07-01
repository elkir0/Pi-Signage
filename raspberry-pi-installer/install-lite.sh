#!/usr/bin/env bash

# =============================================================================
# Pi Signage Digital - Installation LITE pour Raspberry Pi OS Lite
# Version: 1.0.0
# Description: Installation minimale sans modifications agressives
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# Constantes
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="/etc/pi-signage"
readonly CONFIG_FILE="$CONFIG_DIR/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# =============================================================================
# BANNIÈRE
# =============================================================================

show_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║      📺 Pi Signage Digital - Installation LITE 📺           ║"
    echo "║                                                              ║"
    echo "║          Version simplifiée pour Raspberry Pi OS Lite        ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# =============================================================================
# VÉRIFICATIONS
# =============================================================================

check_system() {
    log_info "Vérification du système..."
    
    # Vérifier qu'on est root
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
    
    # Vérifier Raspberry Pi OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "OS détecté: $NAME $VERSION"
    fi
    
    # Vérifier l'espace disque
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $free_space -lt 2 ]]; then
        log_error "Espace disque insuffisant (minimum 2GB requis)"
        exit 1
    fi
    
    log_info "Système vérifié avec succès"
}

# =============================================================================
# SÉLECTION DU MODE
# =============================================================================

select_display_mode() {
    echo -e "\n${BLUE}Choisir le mode d'affichage:${NC}"
    echo "1) VLC (lecteur vidéo simple et robuste)"
    echo "2) Chromium (pour HTML5 et interface web)"
    echo
    read -p "Votre choix [1-2]: " choice
    
    case $choice in
        2)
            DISPLAY_MODE="chromium"
            log_info "Mode Chromium sélectionné"
            ;;
        *)
            DISPLAY_MODE="vlc"
            log_info "Mode VLC sélectionné"
            ;;
    esac
    
    # Sauvegarder le choix
    mkdir -p "$CONFIG_DIR"
    echo "$DISPLAY_MODE" > "$CONFIG_DIR/display-mode.conf"
}

# =============================================================================
# CONFIGURATION MINIMALE
# =============================================================================

collect_config() {
    echo -e "\n${BLUE}Configuration minimale:${NC}"
    
    # Hostname
    read -p "Nom de la machine [pi-signage]: " NEW_HOSTNAME
    NEW_HOSTNAME=${NEW_HOSTNAME:-pi-signage}
    
    # Sauvegarder la configuration
    cat > "$CONFIG_FILE" << EOF
# Configuration Pi Signage LITE
NEW_HOSTNAME="$NEW_HOSTNAME"
DISPLAY_MODE="$DISPLAY_MODE"
VIDEO_DIR="/opt/videos"
INSTALL_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
}

# =============================================================================
# INSTALLATION
# =============================================================================

install_modules() {
    log_info "Installation des modules..."
    
    # Rendre les scripts exécutables
    chmod +x "$SCRIPT_DIR/scripts/"*.sh
    
    # 1. Configuration système minimale
    log_info "1/4 Configuration système..."
    if [[ -f "$SCRIPT_DIR/scripts/01-system-config-lite.sh" ]]; then
        bash "$SCRIPT_DIR/scripts/01-system-config-lite.sh"
    else
        # Fallback sur le script standard s'il n'existe pas
        bash "$SCRIPT_DIR/scripts/01-system-config.sh"
    fi
    
    # 2. Configuration X11 minimale
    log_info "2/4 Configuration X11..."
    if [[ -f "$SCRIPT_DIR/scripts/02-x11-minimal.sh" ]]; then
        bash "$SCRIPT_DIR/scripts/02-x11-minimal.sh"
    else
        # Fallback sur display manager si nécessaire
        bash "$SCRIPT_DIR/scripts/02-display-manager.sh"
    fi
    
    # 3. Interface web (optionnelle mais utile)
    log_info "3/4 Interface web..."
    if [[ -f "$SCRIPT_DIR/scripts/09-web-interface-v2.sh" ]]; then
        bash "$SCRIPT_DIR/scripts/09-web-interface-v2.sh"
    fi
    
    # 4. Outils de diagnostic
    log_info "4/4 Outils de diagnostic..."
    if [[ -f "$SCRIPT_DIR/scripts/08-diagnostic-tools.sh" ]]; then
        bash "$SCRIPT_DIR/scripts/08-diagnostic-tools.sh"
    fi
}

# =============================================================================
# POST-INSTALLATION
# =============================================================================

post_install() {
    log_info "Configuration post-installation..."
    
    # Créer une vidéo de test
    if [[ ! -f /opt/videos/test.mp4 ]]; then
        log_info "Création d'une vidéo de test..."
        # Créer une vidéo noire de 10 secondes avec ffmpeg
        if command -v ffmpeg >/dev/null; then
            ffmpeg -f lavfi -i color=black:s=1920x1080:d=10 -c:v libx264 /opt/videos/test.mp4 2>/dev/null || true
        fi
    fi
    
    # Informations de connexion
    local ip_addr=$(hostname -I | awk '{print $1}')
    
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Installation LITE terminée avec succès! 🎉           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Informations importantes:${NC}"
    echo "- Mode d'affichage: $DISPLAY_MODE"
    echo "- Interface web: http://$ip_addr/"
    echo "- Dossier vidéos: /opt/videos/"
    echo "- Logs: /var/log/vlc-signage.log ou /var/log/chromium-kiosk.log"
    echo
    echo -e "${YELLOW}Prochaines étapes:${NC}"
    echo "1. Copier vos vidéos dans /opt/videos/"
    echo "2. Redémarrer: sudo reboot"
    echo "3. L'affichage démarrera automatiquement après ~15 secondes"
    echo
    echo -e "${YELLOW}En cas de problème:${NC}"
    echo "- Connectez-vous en SSH pour déboguer"
    echo "- Consultez /tmp/pi-signage-x11.log"
    echo "- Utilisez: sudo -u signage startx (pour test manuel)"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    # Préparation
    mkdir -p "$(dirname "$LOG_FILE")"
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    # Affichage
    show_banner
    
    # Vérifications
    check_system
    
    # Configuration
    select_display_mode
    collect_config
    
    # Installation
    echo -e "\n${YELLOW}L'installation va commencer...${NC}"
    read -p "Appuyez sur [Entrée] pour continuer..."
    
    install_modules
    
    # Finalisation
    post_install
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi