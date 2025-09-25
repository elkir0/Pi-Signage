#!/bin/bash

# Pi-Signage v0.8.1 - Script de validation des packages Bookworm
# Teste si tous les packages nécessaires sont disponibles AVANT installation
# Date: 2025-09-25

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Test de disponibilité des packages
test_packages() {
    log "Test de disponibilité des packages..."

    # Packages à tester (même liste que le script principal)
    PACKAGES_TO_TEST=(
        "lightdm"
        "lightdm-autologin-greeter"
        "openbox"
        "lxde-core"
        "lxde-common"
        "vlc"
        "vlc-plugin-base"
        "vlc-plugin-video-output"
        "mpv"
        "labwc"
        "weston"
        "libdrm2"
        "mesa-utils"
        "libgl1-mesa-dri"
        "libraspberrypi-bin"
        "v4l-utils"
        "wayland-utils"
        "wlr-randr"
        "scrot"
        "grim"
        "slurp"
        "alsa-utils"
        "pulseaudio"
        "unclutter"
    )

    local available_count=0
    local total_count=${#PACKAGES_TO_TEST[@]}

    for package in "${PACKAGES_TO_TEST[@]}"; do
        if apt-cache show "$package" >/dev/null 2>&1; then
            success "$package - disponible"
            ((available_count++))
        else
            error "$package - NON DISPONIBLE"
        fi
    done

    log "Résultat: $available_count/$total_count packages disponibles"

    if [ $available_count -eq $total_count ]; then
        success "Tous les packages sont disponibles !"
        return 0
    else
        warning "Certains packages ne sont pas disponibles"
        return 1
    fi
}

# Test des services système
test_services() {
    log "Test des services système..."

    # Test systemctl
    if command -v systemctl >/dev/null 2>&1; then
        success "systemctl disponible"
    else
        error "systemctl non disponible"
        return 1
    fi

    # Test des targets systemd
    if systemctl list-unit-files | grep -q "graphical.target"; then
        success "graphical.target disponible"
    else
        error "graphical.target non disponible"
    fi

    # Test du service getty pour autologin
    if systemctl list-unit-files | grep -q "getty@.service"; then
        success "getty service disponible pour autologin"
    else
        warning "getty service non trouvé"
    fi
}

# Test de l'environnement Raspberry Pi
test_raspberry_pi() {
    log "Test de l'environnement Raspberry Pi..."

    # Test du modèle Pi
    if [ -f /proc/cpuinfo ]; then
        local pi_model=$(grep "Model" /proc/cpuinfo | cut -d':' -f2 | xargs)
        if [ -n "$pi_model" ]; then
            success "Modèle Pi détecté: $pi_model"
        else
            warning "Modèle Pi non détecté"
        fi
    else
        error "/proc/cpuinfo non accessible"
    fi

    # Test des devices DRM/KMS
    if [ -e /dev/dri/card0 ]; then
        success "Device DRM /dev/dri/card0 présent"
    else
        warning "Device DRM /dev/dri/card0 absent"
    fi

    # Test du GPU
    if [ -e /opt/vc/bin/vcgencmd ]; then
        success "Outils GPU Raspberry Pi disponibles"
    else
        warning "Outils GPU Raspberry Pi non trouvés"
    fi
}

# Test de l'OS
test_os() {
    log "Test de l'OS..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        success "OS: $NAME $VERSION_ID ($VERSION_CODENAME)"

        if [ "$VERSION_CODENAME" = "bookworm" ]; then
            success "Raspberry Pi OS Bookworm confirmé"
        else
            warning "OS n'est pas Bookworm (détecté: $VERSION_CODENAME)"
        fi
    else
        error "Impossible de détecter l'OS"
        return 1
    fi
}

# Test des permissions utilisateur
test_user_permissions() {
    log "Test des permissions utilisateur..."

    local test_user="${SUDO_USER:-$USER}"

    if [ "$test_user" = "root" ]; then
        warning "Exécuté en tant que root - utilisateur cible non défini"
        return 1
    fi

    success "Utilisateur cible: $test_user"

    # Test de l'existence de l'utilisateur
    if id "$test_user" >/dev/null 2>&1; then
        success "Utilisateur $test_user existe"
    else
        error "Utilisateur $test_user n'existe pas"
        return 1
    fi

    # Test du répertoire home
    local home_dir="/home/$test_user"
    if [ -d "$home_dir" ]; then
        success "Répertoire home $home_dir existe"
    else
        error "Répertoire home $home_dir n'existe pas"
        return 1
    fi
}

# Test de connectivité réseau
test_network() {
    log "Test de connectivité réseau..."

    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        success "Connectivité réseau OK"
    else
        warning "Pas de connectivité réseau - téléchargement Big Buck Bunny impossible"
    fi

    # Test de l'URL Big Buck Bunny
    if curl -s --head "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" | head -n 1 | grep -q "200 OK"; then
        success "Big Buck Bunny accessible"
    else
        warning "Big Buck Bunny non accessible - utiliser un fichier local"
    fi
}

# Rapport final
generate_report() {
    echo ""
    log "=== RAPPORT DE VALIDATION ==="
    echo ""

    if test_os && test_raspberry_pi && test_user_permissions && test_services && test_packages; then
        echo -e "${GREEN}✓ VALIDATION RÉUSSIE${NC}"
        echo "Le script fix-wayland-bookworm-minimal.sh peut être exécuté en toute sécurité."
        echo ""
        echo "Commandes pour lancer l'installation :"
        echo "  sudo /opt/pisignage/fix-wayland-bookworm-minimal.sh"
        echo "  sudo reboot"
        return 0
    else
        echo -e "${RED}✗ VALIDATION ÉCHOUÉE${NC}"
        echo "Certains prérequis ne sont pas remplis."
        echo "Vérifiez les messages d'erreur ci-dessus avant de continuer."
        return 1
    fi
}

# Fonction principale
main() {
    log "Début de la validation pour Raspberry Pi OS Bookworm"
    echo ""

    # Mise à jour du cache APT
    log "Mise à jour du cache APT..."
    apt-get update >/dev/null 2>&1 || warning "Échec de la mise à jour APT"

    # Tests
    test_os
    echo ""
    test_raspberry_pi
    echo ""
    test_user_permissions
    echo ""
    test_services
    echo ""
    test_packages
    echo ""
    test_network

    # Rapport final
    generate_report
}

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
    error "Ce script doit être exécuté avec sudo pour tester les packages"
    exit 1
fi

# Exécution
main "$@"