#!/bin/bash

# PiSignage v0.8.0 - Installation Script Principal
# Déploiement production Raspberry Pi
# Auteur: Claude Code
# Date: 22/09/2025

set -e  # Exit on error

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuration
PISIGNAGE_USER="pi"
PISIGNAGE_DIR="/opt/pisignage"
WEB_DIR="$PISIGNAGE_DIR/web"
MEDIA_DIR="$PISIGNAGE_DIR/media"
LOGS_DIR="$PISIGNAGE_DIR/logs"
CONFIG_DIR="$PISIGNAGE_DIR/config"
SCRIPTS_DIR="$PISIGNAGE_DIR/scripts"

# Version à installer
VERSION="0.8.0"

# Fonction de logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Vérification OS Raspberry Pi
check_raspberry_pi() {
    log "Vérification du système Raspberry Pi..."

    if [ ! -f /proc/cpuinfo ]; then
        error "Impossible de lire /proc/cpuinfo"
    fi

    if ! grep -q "Raspberry Pi" /proc/cpuinfo && ! grep -q "BCM" /proc/cpuinfo; then
        error "Ce script est conçu pour Raspberry Pi uniquement"
    fi

    # Vérification OS
    if [ ! -f /etc/os-release ]; then
        error "Impossible de détecter l'OS"
    fi

    . /etc/os-release
    if [[ "$ID" != "raspbian" && "$ID" != "debian" ]]; then
        warn "OS détecté: $PRETTY_NAME (non testé officiellement)"
    fi

    log "✅ Raspberry Pi détecté: $(grep "Model" /proc/cpuinfo | cut -d: -f2 | xargs)"
}

# Mise à jour du système
update_system() {
    log "Mise à jour du système..."

    sudo apt update
    sudo apt upgrade -y

    log "✅ Système mis à jour"
}

# Installation des packages principaux
install_packages() {
    log "Installation des packages..."

    # Packages essentiels
    local packages=(
        "nginx"
        "php8.2"
        "php8.2-fpm"
        "php8.2-cli"
        "php8.2-common"
        "php8.2-mysql"
        "php8.2-xml"
        "php8.2-xmlrpc"
        "php8.2-curl"
        "php8.2-gd"
        "php8.2-imagick"
        "php8.2-cli"
        "php8.2-dev"
        "php8.2-imap"
        "php8.2-mbstring"
        "php8.2-opcache"
        "php8.2-soap"
        "php8.2-zip"
        "php8.2-intl"
        "vlc"
        "vlc-bin"
        "vlc-plugin-base"
        "vlc-plugin-video-output"
        "python3"
        "python3-pip"
        "curl"
        "wget"
        "unzip"
        "git"
        "htop"
        "tree"
        "screen"
        "imagemagick"
        "ffmpeg"
        "scrot"
        "feh"
        "chromium-browser"
        "xdotool"
        "x11-xserver-utils"
        "xinit"
    )

    for package in "${packages[@]}"; do
        info "Installation de $package..."
        sudo apt install -y "$package" || warn "Échec installation $package"
    done

    # Installation yt-dlp
    log "Installation de yt-dlp..."
    sudo python3 -m pip install --upgrade yt-dlp

    log "✅ Packages installés"
}

# Création des répertoires
create_directories() {
    log "Création des répertoires..."

    sudo mkdir -p "$PISIGNAGE_DIR"
    sudo mkdir -p "$WEB_DIR"
    sudo mkdir -p "$MEDIA_DIR"
    sudo mkdir -p "$LOGS_DIR"
    sudo mkdir -p "$CONFIG_DIR"
    sudo mkdir -p "$SCRIPTS_DIR"
    sudo mkdir -p "$MEDIA_DIR/images"
    sudo mkdir -p "$MEDIA_DIR/videos"
    sudo mkdir -p "$MEDIA_DIR/playlists"

    # Permissions
    sudo chown -R $PISIGNAGE_USER:$PISIGNAGE_USER "$PISIGNAGE_DIR"
    sudo chmod -R 755 "$PISIGNAGE_DIR"
    sudo chmod -R 777 "$MEDIA_DIR"
    sudo chmod -R 777 "$LOGS_DIR"

    log "✅ Répertoires créés"
}

# Configuration des services
configure_services() {
    log "Configuration des services..."

    # Activation des services
    sudo systemctl enable nginx
    sudo systemctl enable php8.2-fpm

    # Redémarrage
    sudo systemctl restart nginx
    sudo systemctl restart php8.2-fpm

    log "✅ Services configurés"
}

# Installation des scripts de configuration
install_config_scripts() {
    log "Installation des scripts de configuration..."

    # Les scripts doivent être dans le même répertoire
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [ -f "$script_dir/setup-vlc.sh" ]; then
        cp "$script_dir/setup-vlc.sh" "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/setup-vlc.sh"
        log "✅ setup-vlc.sh installé"
    else
        warn "setup-vlc.sh non trouvé dans $script_dir"
    fi

    if [ -f "$script_dir/setup-web.sh" ]; then
        cp "$script_dir/setup-web.sh" "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/setup-web.sh"
        log "✅ setup-web.sh installé"
    else
        warn "setup-web.sh non trouvé dans $script_dir"
    fi

    if [ -f "$script_dir/optimize-pi.sh" ]; then
        cp "$script_dir/optimize-pi.sh" "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/optimize-pi.sh"
        log "✅ optimize-pi.sh installé"
    else
        warn "optimize-pi.sh non trouvé dans $script_dir"
    fi

    if [ -f "$script_dir/pisignage.service" ]; then
        sudo cp "$script_dir/pisignage.service" "/etc/systemd/system/"
        sudo systemctl daemon-reload
        log "✅ pisignage.service installé"
    else
        warn "pisignage.service non trouvé dans $script_dir"
    fi
}

# Exécution des scripts de configuration
run_config_scripts() {
    log "Exécution des scripts de configuration..."

    # Setup Web
    if [ -f "$SCRIPTS_DIR/setup-web.sh" ]; then
        log "Configuration Web..."
        bash "$SCRIPTS_DIR/setup-web.sh"
    fi

    # Setup VLC
    if [ -f "$SCRIPTS_DIR/setup-vlc.sh" ]; then
        log "Configuration VLC..."
        bash "$SCRIPTS_DIR/setup-vlc.sh"
    fi

    # Optimisation Pi
    if [ -f "$SCRIPTS_DIR/optimize-pi.sh" ]; then
        log "Optimisation Raspberry Pi..."
        bash "$SCRIPTS_DIR/optimize-pi.sh"
    fi

    log "✅ Scripts de configuration exécutés"
}

# Activation du service PiSignage
enable_pisignage_service() {
    log "Activation du service PiSignage..."

    if [ -f "/etc/systemd/system/pisignage.service" ]; then
        sudo systemctl enable pisignage.service
        sudo systemctl start pisignage.service
        log "✅ Service PiSignage activé"
    else
        warn "Service PiSignage non trouvé"
    fi
}

# Test final
final_test() {
    log "Tests finaux..."

    # Test nginx
    if systemctl is-active --quiet nginx; then
        log "✅ Nginx actif"
    else
        error "❌ Nginx inactif"
    fi

    # Test PHP-FPM
    if systemctl is-active --quiet php8.2-fpm; then
        log "✅ PHP-FPM actif"
    else
        error "❌ PHP-FPM inactif"
    fi

    # Test VLC
    if command -v vlc >/dev/null 2>&1; then
        log "✅ VLC installé"
    else
        warn "❌ VLC non trouvé"
    fi

    # Test yt-dlp
    if command -v yt-dlp >/dev/null 2>&1; then
        log "✅ yt-dlp installé"
    else
        warn "❌ yt-dlp non trouvé"
    fi

    # Test répertoires
    if [ -d "$PISIGNAGE_DIR" ]; then
        log "✅ Répertoire PiSignage créé"
    else
        error "❌ Répertoire PiSignage manquant"
    fi

    log "✅ Tests finaux terminés"
}

# Affichage des informations finales
show_final_info() {
    echo ""
    echo "=============================================="
    echo "🎉 INSTALLATION PISIGNAGE v$VERSION TERMINÉE"
    echo "=============================================="
    echo ""
    echo "📍 Répertoire principal: $PISIGNAGE_DIR"
    echo "🌐 Répertoire web: $WEB_DIR"
    echo "📁 Médias: $MEDIA_DIR"
    echo "📝 Logs: $LOGS_DIR"
    echo ""
    echo "🔧 Services:"
    echo "   - nginx: $(systemctl is-active nginx)"
    echo "   - php8.2-fpm: $(systemctl is-active php8.2-fpm)"
    echo "   - pisignage: $(systemctl is-active pisignage 2>/dev/null || echo 'non configuré')"
    echo ""
    echo "📋 Prochaines étapes:"
    echo "   1. Déployer le code web dans $WEB_DIR"
    echo "   2. Configurer l'auto-démarrage X11"
    echo "   3. Tester l'interface sur http://$(hostname -I | awk '{print $1}')"
    echo ""
    echo "🔄 Commandes utiles:"
    echo "   sudo systemctl restart nginx"
    echo "   sudo systemctl restart php8.2-fpm"
    echo "   sudo systemctl status pisignage"
    echo ""
    echo "⚡ Installation terminée avec succès !"
    echo "=============================================="
}

# FONCTION PRINCIPALE
main() {
    log "🚀 Démarrage installation PiSignage v$VERSION"

    # Vérification des privilèges
    if [[ $EUID -eq 0 ]]; then
        error "Ne pas exécuter en tant que root. Utilisez 'sudo' quand nécessaire."
    fi

    check_raspberry_pi
    update_system
    install_packages
    create_directories
    configure_services
    install_config_scripts
    run_config_scripts
    enable_pisignage_service
    final_test
    show_final_info

    log "🎉 Installation PiSignage v$VERSION terminée avec succès!"
}

# Exécution si script appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi