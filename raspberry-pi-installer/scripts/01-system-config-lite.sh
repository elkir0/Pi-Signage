#!/usr/bin/env bash

# =============================================================================
# Module 01 - Configuration Système LITE (Version simplifiée)
# Version: 1.0.0
# Description: Configuration minimale pour Raspberry Pi OS Lite
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly BOOT_CONFIG="/boot/config.txt"
readonly BOOT_CMDLINE="/boot/cmdline.txt"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les fonctions de sécurité
if [[ -f "$SCRIPT_DIR/00-security-utils.sh" ]]; then
    source "$SCRIPT_DIR/00-security-utils.sh"
fi

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# =============================================================================
# LOGGING
# =============================================================================

log_info() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [INFO] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${GREEN}[CONFIG-LITE]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[CONFIG-LITE]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[CONFIG-LITE]${NC} $*" >&2
}

# =============================================================================
# CONFIGURATION MINIMALE DE BOOT
# =============================================================================

configure_boot_minimal() {
    log_info "Configuration minimale de boot..."
    
    # Backup de config.txt
    if [[ ! -f "$BOOT_CONFIG.backup-original" ]]; then
        cp "$BOOT_CONFIG" "$BOOT_CONFIG.backup-original"
    fi
    
    # Ajouter seulement les paramètres ESSENTIELS
    log_info "Ajout des paramètres minimaux..."
    
    # Créer une section Pi Signage dans config.txt
    if ! grep -q "### PI SIGNAGE LITE CONFIG ###" "$BOOT_CONFIG"; then
        cat >> "$BOOT_CONFIG" << 'EOF'

### PI SIGNAGE LITE CONFIG ###
# Configuration minimale pour l'affichage
hdmi_force_hotplug=1     # Force la sortie HDMI même sans écran au boot
disable_overscan=1       # Utilise toute la surface de l'écran
boot_delay=0            # Pas de délai au boot
disable_splash=1        # Pas d'écran arc-en-ciel

# Mémoire GPU standard (pas de modification)
# gpu_mem=128           # Commenté - utilise la valeur par défaut

# Audio activé pour le support vidéo
dtparam=audio=on

### FIN PI SIGNAGE LITE CONFIG ###
EOF
    fi
    
    log_info "Configuration boot minimale appliquée"
}

# =============================================================================
# MISE À JOUR DU SYSTÈME (SIMPLIFIÉE)
# =============================================================================

update_system_minimal() {
    log_info "Mise à jour minimale du système..."
    
    # Mise à jour basique
    if safe_execute "apt-get update" 3 10; then
        log_info "Sources de paquets mises à jour"
    else
        log_error "Échec de la mise à jour des sources"
        return 1
    fi
    
    # Pas d'upgrade complet - trop risqué
    log_info "Pas d'upgrade système pour éviter les problèmes"
}

# =============================================================================
# INSTALLATION DES PAQUETS ESSENTIELS UNIQUEMENT
# =============================================================================

install_essential_packages() {
    log_info "Installation des paquets essentiels uniquement..."
    
    local packages=(
        # Outils de base absolument nécessaires
        "curl"
        "wget"
        "git"
        "htop"
        "rsync"
        "unzip"
        "jq"
        "bc"
        "net-tools"
        
        # Pour l'interface graphique minimale
        "xorg"
        "xinit"
        "x11-xserver-utils"
        "xterm"  # Terminal de secours
        
        # VLC et dépendances
        "vlc"
        "vlc-plugin-base"
        
        # Python pour les scripts
        "python3"
        "python3-pip"
    )
    
    # Installation avec gestion d'erreurs
    for package in "${packages[@]}"; do
        log_info "Installation de $package..."
        if ! safe_execute "apt-get install -y $package" 2 30; then
            log_error "Échec de l'installation de $package"
        fi
    done
}

# =============================================================================
# CRÉATION UTILISATEUR SIGNAGE (SIMPLIFIÉE)
# =============================================================================

create_signage_user_minimal() {
    log_info "Création de l'utilisateur signage..."
    
    if id "signage" >/dev/null 2>&1; then
        log_info "L'utilisateur signage existe déjà"
    else
        # Créer l'utilisateur
        useradd -m -s /bin/bash -G video,audio,input signage
        
        # Mot de passe simple
        echo "signage:signage" | chpasswd
        
        log_info "Utilisateur signage créé"
    fi
    
    # Créer les répertoires nécessaires
    mkdir -p /home/signage/.config
    chown -R signage:signage /home/signage
}

# =============================================================================
# CONFIGURATION HOSTNAME
# =============================================================================

configure_hostname() {
    if [[ -n "${NEW_HOSTNAME:-}" ]]; then
        log_info "Configuration du hostname: $NEW_HOSTNAME"
        
        # Mettre à jour /etc/hostname
        echo "$NEW_HOSTNAME" > /etc/hostname
        
        # Mettre à jour /etc/hosts
        sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
        
        # Appliquer immédiatement
        hostname "$NEW_HOSTNAME"
    fi
}

# =============================================================================
# CRÉATION DES RÉPERTOIRES
# =============================================================================

create_directories() {
    log_info "Création des répertoires nécessaires..."
    
    local directories=(
        "/opt/videos"
        "/opt/scripts"
        "/opt/logs"
        "/etc/pi-signage"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done
    
    # Permissions pour le répertoire vidéos
    chown signage:signage /opt/videos
    chmod 775 /opt/videos
}

# =============================================================================
# DÉSACTIVATION DES SERVICES INUTILES (MINIMALE)
# =============================================================================

disable_unnecessary_services() {
    log_info "Désactivation minimale des services inutiles..."
    
    # Désactiver seulement les services vraiment inutiles
    local services=(
        "bluetooth"      # Pas besoin de Bluetooth
        "cups"          # Pas d'imprimante
        "ModemManager"  # Pas de modem
    )
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            systemctl disable "$service" 2>/dev/null || true
            systemctl stop "$service" 2>/dev/null || true
            log_info "Service $service désactivé"
        fi
    done
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_system_config() {
    log_info "Validation de la configuration système..."
    
    local errors=0
    
    # Vérifier l'utilisateur
    if id "signage" >/dev/null 2>&1; then
        log_info "✓ Utilisateur signage présent"
    else
        log_error "✗ Utilisateur signage manquant"
        ((errors++))
    fi
    
    # Vérifier les répertoires
    if [[ -d "/opt/videos" ]] && [[ -d "/opt/scripts" ]]; then
        log_info "✓ Répertoires créés"
    else
        log_error "✗ Répertoires manquants"
        ((errors++))
    fi
    
    # Vérifier les paquets essentiels
    for pkg in vlc xorg xinit; do
        if dpkg -l "$pkg" >/dev/null 2>&1; then
            log_info "✓ Paquet $pkg installé"
        else
            log_error "✗ Paquet $pkg manquant"
            ((errors++))
        fi
    done
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Configuration Système LITE ==="
    
    # Charger la configuration
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    
    # Étapes de configuration MINIMALES
    local steps=(
        "update_system_minimal"
        "configure_boot_minimal"
        "install_essential_packages"
        "create_signage_user_minimal"
        "configure_hostname"
        "create_directories"
        "disable_unnecessary_services"
    )
    
    local failed_steps=()
    
    for step in "${steps[@]}"; do
        log_info "Exécution: $step"
        if ! "$step"; then
            log_error "Échec de l'étape: $step"
            failed_steps+=("$step")
        fi
    done
    
    # Validation
    if validate_system_config; then
        log_info "Configuration système LITE réussie"
    else
        log_warn "Configuration système LITE avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Configuration Système LITE ==="
    return 0
}

# =============================================================================
# EXÉCUTION
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

main "$@"