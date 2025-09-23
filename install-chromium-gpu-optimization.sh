#!/bin/bash

# =============================================================================
# PiSignage - Installation automatique optimisation Chromium GPU
# =============================================================================
# Version: 1.0.0
# Date: 22/09/2025
# Objectif: Installation complète solution 30+ FPS
# =============================================================================

set -euo pipefail

# Configuration
PISIGNAGE_DIR="/opt/pisignage"
BACKUP_DIR="/opt/pisignage/backups/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/opt/pisignage/logs/gpu-optimization-install.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" ;;
        "STEP")  echo -e "${CYAN}[STEP]${NC} $message" ;;
        *) echo "$message" ;;
    esac

    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$timestamp [$level] $message" >> "$LOG_FILE"
}

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
 ____  _ ____  _
|  _ \(_) ___|(_) __ _ _ __   __ _  __ _  ___
| |_) | \___ \| |/ _` | '_ \ / _` |/ _` |/ _ \
|  __/| |___) | | (_| | | | | (_| | (_| |  __/
|_|   |_|____/|_|\__, |_| |_|\__,_|\__, |\___|
                 |___/             |___/

   Optimisation Chromium GPU pour Raspberry Pi 4
            30+ FPS stable garantis
EOF
    echo -e "${NC}"
}

check_requirements() {
    log "STEP" "Vérification des prérequis..."

    # Vérifier que c'est un Raspberry Pi
    if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
        log "ERROR" "Ce script est conçu pour Raspberry Pi uniquement"
        exit 1
    fi

    # Vérifier Pi 4
    local pi_model=$(grep "Model" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    if [[ ! "$pi_model" =~ "Raspberry Pi 4" ]]; then
        log "WARN" "Ce script est optimisé pour Raspberry Pi 4"
        log "WARN" "Modèle détecté: $pi_model"
        read -p "Continuer quand même ? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Vérifier OS
    if ! grep -q "Raspberry Pi OS" /etc/os-release && ! grep -q "Raspbian" /etc/os-release; then
        log "WARN" "OS non testé - recommandé: Raspberry Pi OS Bullseye"
    fi

    # Vérifier permissions
    if [ "$EUID" -eq 0 ]; then
        log "ERROR" "Ne pas exécuter en tant que root"
        log "INFO" "Utiliser: bash $0"
        exit 1
    fi

    log "INFO" "Prérequis validés"
}

backup_current_config() {
    log "STEP" "Sauvegarde de la configuration actuelle..."

    mkdir -p "$BACKUP_DIR"

    # Sauvegarder /boot/config.txt
    if [ -f "/boot/config.txt" ]; then
        sudo cp /boot/config.txt "$BACKUP_DIR/config.txt.backup"
        log "INFO" "config.txt sauvegardé: $BACKUP_DIR/config.txt.backup"
    fi

    # Sauvegarder configs existantes
    if [ -d "/opt/pisignage/config" ]; then
        cp -r /opt/pisignage/config "$BACKUP_DIR/pisignage-config.backup" 2>/dev/null || true
    fi

    log "INFO" "Sauvegarde terminée: $BACKUP_DIR"
}

install_dependencies() {
    log "STEP" "Installation des dépendances..."

    # Mise à jour système
    log "INFO" "Mise à jour des paquets..."
    sudo apt update

    # Dépendances essentielles
    local packages=(
        "chromium-browser"
        "mesa-utils"
        "egl-utils"
        "bc"
        "glx-utils"
        "lshw"
        "htop"
    )

    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log "INFO" "Installation de $package..."
            sudo apt install -y "$package"
        else
            log "INFO" "$package déjà installé"
        fi
    done

    # Vérifier Chromium
    local chromium_version=$(chromium-browser --version 2>/dev/null | cut -d' ' -f2 || echo "non détecté")
    log "INFO" "Version Chromium: $chromium_version"

    log "INFO" "Dépendances installées"
}

configure_boot_config() {
    log "STEP" "Configuration /boot/config.txt optimisée..."

    # Vérifier existence du fichier source
    if [ ! -f "$PISIGNAGE_DIR/config/boot-config-bullseye.txt" ]; then
        log "ERROR" "Fichier de configuration non trouvé: $PISIGNAGE_DIR/config/boot-config-bullseye.txt"
        exit 1
    fi

    # Appliquer la nouvelle configuration
    log "INFO" "Application de la configuration optimisée..."
    sudo cp "$PISIGNAGE_DIR/config/boot-config-bullseye.txt" /boot/config.txt

    # Vérifier l'application
    if grep -q "gpu_mem=128" /boot/config.txt && grep -q "vc4-fkms-v3d" /boot/config.txt; then
        log "INFO" "Configuration /boot/config.txt appliquée avec succès"
    else
        log "ERROR" "Échec de l'application de la configuration"
        exit 1
    fi

    log "INFO" "Configuration boot terminée"
}

setup_scripts_permissions() {
    log "STEP" "Configuration des permissions des scripts..."

    local scripts=(
        "$PISIGNAGE_DIR/scripts/launch-chromium-optimized.sh"
        "$PISIGNAGE_DIR/scripts/monitor-performance.sh"
        "$PISIGNAGE_DIR/scripts/gpu-fallback-manager.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            log "INFO" "Permissions accordées: $(basename "$script")"
        else
            log "WARN" "Script non trouvé: $script"
        fi
    done

    log "INFO" "Permissions configurées"
}

run_initial_tests() {
    log "STEP" "Tests initiaux de la configuration..."

    # Test 1: Vérification des fichiers
    local required_files=(
        "$PISIGNAGE_DIR/chromium-video-player.html"
        "$PISIGNAGE_DIR/scripts/launch-chromium-optimized.sh"
        "$PISIGNAGE_DIR/scripts/monitor-performance.sh"
        "$PISIGNAGE_DIR/scripts/gpu-fallback-manager.sh"
    )

    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            log "INFO" "✓ $(basename "$file")"
        else
            log "ERROR" "✗ Fichier manquant: $file"
            exit 1
        fi
    done

    # Test 2: Vérification configuration système
    log "INFO" "Test de la configuration système..."
    if "$PISIGNAGE_DIR/scripts/launch-chromium-optimized.sh" --check-only; then
        log "INFO" "✓ Vérifications système OK"
    else
        log "WARN" "⚠ Certaines vérifications ont échoué (normal avant redémarrage)"
    fi

    log "INFO" "Tests initiaux terminés"
}

create_service_files() {
    log "STEP" "Création des fichiers de service systemd..."

    # Service principal PiSignage
    cat > "/tmp/pisignage-gpu.service" << EOF
[Unit]
Description=PiSignage Chromium GPU Optimized
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=pi
Group=pi
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=$PISIGNAGE_DIR/scripts/launch-chromium-optimized.sh
ExecStop=$PISIGNAGE_DIR/scripts/launch-chromium-optimized.sh --kill
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical-session.target
EOF

    # Service monitoring
    cat > "/tmp/pisignage-monitor.service" << EOF
[Unit]
Description=PiSignage Performance Monitor
After=pisignage-gpu.service
Wants=pisignage-gpu.service

[Service]
Type=simple
User=pi
Group=pi
ExecStart=$PISIGNAGE_DIR/scripts/monitor-performance.sh --start
ExecStop=$PISIGNAGE_DIR/scripts/monitor-performance.sh --stop
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Installer les services
    sudo mv /tmp/pisignage-gpu.service /etc/systemd/system/
    sudo mv /tmp/pisignage-monitor.service /etc/systemd/system/
    sudo systemctl daemon-reload

    log "INFO" "Services systemd créés"
}

generate_test_media() {
    log "STEP" "Génération de médias de test..."

    local media_dir="$PISIGNAGE_DIR/media"
    mkdir -p "$media_dir"

    # Créer une vidéo de test simple si aucune n'existe
    if [ ! -f "$media_dir/demo.mp4" ] && command -v ffmpeg >/dev/null; then
        log "INFO" "Génération vidéo de test 720p..."
        ffmpeg -f lavfi -i testsrc=duration=10:size=1280x720:rate=30 \
               -f lavfi -i sine=frequency=1000:duration=10 \
               -c:v libx264 -preset ultrafast -crf 23 \
               -c:a aac -b:a 128k \
               "$media_dir/demo.mp4" -y >/dev/null 2>&1

        if [ -f "$media_dir/demo.mp4" ]; then
            log "INFO" "✓ Vidéo de test créée: demo.mp4"
        else
            log "WARN" "Échec création vidéo de test"
        fi
    elif [ ! -f "$media_dir/demo.mp4" ]; then
        log "WARN" "Aucune vidéo de test disponible"
        log "INFO" "Ajoutez manuellement demo.mp4 dans $media_dir/"
    fi
}

show_next_steps() {
    log "STEP" "Instructions post-installation..."

    echo ""
    echo -e "${YELLOW}🚀 INSTALLATION TERMINÉE !${NC}"
    echo ""
    echo -e "${CYAN}📋 ÉTAPES SUIVANTES OBLIGATOIRES:${NC}"
    echo ""
    echo -e "${GREEN}1. REDÉMARRAGE REQUIS${NC}"
    echo "   sudo reboot"
    echo ""
    echo -e "${GREEN}2. Après redémarrage, valider la configuration:${NC}"
    echo "   vcgencmd get_mem gpu    # Doit afficher 128M"
    echo "   ls /dev/dri/           # Doit contenir card0"
    echo ""
    echo -e "${GREEN}3. Test de la solution optimisée:${NC}"
    echo "   $PISIGNAGE_DIR/scripts/gpu-fallback-manager.sh --auto"
    echo "   $PISIGNAGE_DIR/scripts/launch-chromium-optimized.sh"
    echo ""
    echo -e "${GREEN}4. Démarrer le monitoring (optionnel):${NC}"
    echo "   $PISIGNAGE_DIR/scripts/monitor-performance.sh --start"
    echo ""
    echo -e "${GREEN}5. Services systemd (pour démarrage auto):${NC}"
    echo "   sudo systemctl enable pisignage-gpu.service"
    echo "   sudo systemctl enable pisignage-monitor.service"
    echo ""
    echo -e "${CYAN}📊 OBJECTIFS ATTENDUS:${NC}"
    echo "   • FPS: 30+ en 720p"
    echo "   • CPU: 20-40% en lecture"
    echo "   • Température: <80°C"
    echo "   • Throttling: aucun"
    echo ""
    echo -e "${BLUE}📚 DOCUMENTATION COMPLÈTE:${NC}"
    echo "   $PISIGNAGE_DIR/CHROMIUM-GPU-OPTIMIZATION.md"
    echo ""
    echo -e "${YELLOW}⚠️ IMPORTANT: REDÉMARRAGE OBLIGATOIRE pour activer la config GPU${NC}"
    echo ""
}

rollback_installation() {
    log "STEP" "Rollback de l'installation..."

    # Restaurer config.txt
    if [ -f "$BACKUP_DIR/config.txt.backup" ]; then
        sudo cp "$BACKUP_DIR/config.txt.backup" /boot/config.txt
        log "INFO" "config.txt restauré"
    fi

    # Supprimer services
    sudo systemctl disable pisignage-gpu.service 2>/dev/null || true
    sudo systemctl disable pisignage-monitor.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/pisignage-gpu.service
    sudo rm -f /etc/systemd/system/pisignage-monitor.service
    sudo systemctl daemon-reload

    log "INFO" "Rollback terminé"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    local skip_deps=false
    local auto_reboot=false

    # Parser arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --auto-reboot)
                auto_reboot=true
                shift
                ;;
            --rollback)
                rollback_installation
                exit 0
                ;;
            -h|--help)
                cat << EOF
Usage: $0 [OPTIONS]

Installation automatique optimisation Chromium GPU

OPTIONS:
    --skip-deps       Ignorer installation dépendances
    --auto-reboot     Redémarrer automatiquement
    --rollback        Annuler l'installation
    -h, --help        Afficher cette aide

EXEMPLES:
    $0                Installation complète
    $0 --skip-deps    Installation sans paquets
    $0 --rollback     Annuler installation
EOF
                exit 0
                ;;
            *)
                log "ERROR" "Option inconnue: $1"
                exit 1
                ;;
        esac
    done

    # Trap pour nettoyage en cas d'erreur
    trap 'log "ERROR" "Installation interrompue"; exit 1' ERR

    show_banner

    # Vérifications initiales
    check_requirements

    # Sauvegarde
    backup_current_config

    # Installation
    if [ "$skip_deps" = false ]; then
        install_dependencies
    fi

    configure_boot_config
    setup_scripts_permissions
    run_initial_tests
    create_service_files
    generate_test_media

    # Instructions finales
    show_next_steps

    # Redémarrage automatique si demandé
    if [ "$auto_reboot" = true ]; then
        log "INFO" "Redémarrage automatique dans 10 secondes..."
        sleep 10
        sudo reboot
    fi
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi