#!/usr/bin/env bash

# =============================================================================
# Module 01 - Configuration Système de Base (STABLE)
# Version: 2.0.0
# Description: Configuration système sans optimisations agressives
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"

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
    echo -e "${GREEN}[SYSTÈME]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[SYSTÈME]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[SYSTÈME]${NC} $*" >&2
}

# =============================================================================
# CHARGEMENT DE LA CONFIGURATION
# =============================================================================

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "Configuration chargée depuis $CONFIG_FILE"
    else
        log_error "Fichier de configuration introuvable: $CONFIG_FILE"
        return 1
    fi
    
    # Charger les informations du modèle Pi
    if [[ -f "/tmp/pi-model.conf" ]]; then
        source "/tmp/pi-model.conf"
        log_info "Modèle Pi: $PI_MODEL (Génération: $PI_GENERATION)"
    else
        log_warn "Informations modèle Pi non disponibles, utilisation des valeurs par défaut"
        PI_GENERATION="3"
        PI_VARIANT="unknown"
    fi
}

# =============================================================================
# MISE À JOUR DU SYSTÈME
# =============================================================================

update_system() {
    log_info "Mise à jour des paquets système..."
    
    # Mise à jour de la liste des paquets
    if apt-get update; then
        log_info "Liste des paquets mise à jour"
    else
        log_error "Échec de la mise à jour des paquets"
        return 1
    fi
    
    # Mise à jour des paquets installés (sélective)
    log_info "Mise à jour des paquets critiques..."
    if apt-get upgrade -y --with-new-pkgs \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"; then
        log_info "Paquets mis à jour avec succès"
    else
        log_warn "Problème lors de la mise à jour des paquets"
    fi
}

# =============================================================================
# CONFIGURATION DU HOSTNAME
# =============================================================================

configure_hostname() {
    log_info "Configuration du hostname: $NEW_HOSTNAME"
    
    # Changement du hostname
    if echo "$NEW_HOSTNAME" > /etc/hostname; then
        log_info "Hostname défini: $NEW_HOSTNAME"
    else
        log_error "Échec de la définition du hostname"
        return 1
    fi
    
    # Mise à jour de /etc/hosts
    if sed -i "s/raspberrypi/$NEW_HOSTNAME/g" /etc/hosts; then
        log_info "Fichier /etc/hosts mis à jour"
    else
        log_warn "Problème lors de la mise à jour de /etc/hosts"
    fi
    
    # Application immédiate (si possible)
    hostnamectl set-hostname "$NEW_HOSTNAME" 2>/dev/null || true
}

# =============================================================================
# CONFIGURATION DU FUSEAU HORAIRE
# =============================================================================

configure_timezone() {
    log_info "Configuration du fuseau horaire..."
    
    # Configuration pour la France
    if timedatectl set-timezone Europe/Paris; then
        log_info "Fuseau horaire défini: Europe/Paris"
    else
        log_warn "Échec de la configuration du fuseau horaire"
    fi
    
    # Vérification
    local current_tz
    current_tz=$(timedatectl show --property=Timezone --value)
    log_info "Fuseau horaire actuel: $current_tz"
}

# =============================================================================
# DÉSACTIVATION DES SERVICES INUTILES
# =============================================================================

disable_unnecessary_services() {
    log_info "Désactivation des services non nécessaires..."
    
    # Liste des services à désactiver pour un système digital signage
    local services_to_disable=(
        "bluetooth"
        "hciuart" 
        "triggerhappy"
        "avahi-daemon"
        "cups"
        "cups-browsed"
        "ModemManager"
        "wpa_supplicant"  # Optionnel si WiFi configuré ailleurs
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            log_info "Désactivation du service: $service"
            systemctl disable "$service" 2>/dev/null || true
            systemctl stop "$service" 2>/dev/null || true
        else
            log_info "Service $service déjà désactivé ou inexistant"
        fi
    done
}

# =============================================================================
# CONFIGURATION BOOTLOADER (STABLE)
# =============================================================================

configure_boot_stable() {
    log_info "Configuration du bootloader (mode stable)..."
    
    # Détection du chemin de boot
    local boot_path="/boot"
    [[ -d "/boot/firmware" ]] && boot_path="/boot/firmware"
    
    # Sauvegarde du config.txt original
    if [[ -f "$boot_path/config.txt" ]]; then
        cp "$boot_path/config.txt" "$boot_path/config.txt.backup-$(date +%Y%m%d)" 2>/dev/null || true
        log_info "Sauvegarde de config.txt créée"
    fi
    
    # Configuration minimale et stable pour digital signage
    cat >> "$boot_path/config.txt" << 'EOF'

# === Configuration Digital Signage STABLE ===
# GPU memory (conservateur)
gpu_mem=128

# Force HDMI output
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=82  # 1080p 60Hz

# Display
disable_overscan=1

# Hardware acceleration (stable)
dtoverlay=vc4-fkms-v3d
max_framebuffers=2

# Boot optimizations (légères)
disable_splash=1
boot_delay=0

# Disable unnecessary hardware
dtparam=audio=off
camera_auto_detect=0

# === FIN Configuration Digital Signage ===
EOF
    
    log_info "Configuration boot stable appliquée"
}

# =============================================================================
# CONFIGURATION CMDLINE (OPTIMISATIONS LÉGÈRES)
# =============================================================================

configure_cmdline() {
    log_info "Configuration des paramètres de démarrage..."
    
    local boot_path="/boot"
    [[ -d "/boot/firmware" ]] && boot_path="/boot/firmware"
    
    if [[ -f "$boot_path/cmdline.txt" ]]; then
        # Sauvegarde
        cp "$boot_path/cmdline.txt" "$boot_path/cmdline.txt.backup-$(date +%Y%m%d)"
        
        # Optimisations légères pour l'affichage
        if ! grep -q "logo.nologo" "$boot_path/cmdline.txt"; then
            sed -i 's/$/ logo.nologo consoleblank=0/' "$boot_path/cmdline.txt"
            log_info "Optimisations d'affichage ajoutées à cmdline.txt"
        fi
    else
        log_warn "Fichier cmdline.txt introuvable"
    fi
}

# =============================================================================
# CRÉATION DES RÉPERTOIRES
# =============================================================================

create_directories() {
    log_info "Création des répertoires système..."
    
    # Répertoires principaux
    local directories=(
        "/opt/videos"
        "/opt/scripts"
        "/var/log/pi-signage"
        "/etc/pi-signage"
    )
    
    for dir in "${directories[@]}"; do
        if mkdir -p "$dir"; then
            log_info "Répertoire créé: $dir"
            # Permissions appropriées
            case "$dir" in
                "/opt/videos")
                    chmod 755 "$dir"
                    ;;
                "/opt/scripts")
                    chmod 755 "$dir"
                    ;;
                "/var/log/pi-signage")
                    chmod 755 "$dir"
                    ;;
                "/etc/pi-signage")
                    chmod 700 "$dir"
                    ;;
            esac
        else
            log_error "Échec de la création du répertoire: $dir"
            return 1
        fi
    done
}

# =============================================================================
# INSTALLATION DES PAQUETS DE BASE
# =============================================================================

install_base_packages() {
    log_info "Installation des paquets de base..."
    
    # Paquets essentiels pour le système
    local base_packages=(
        "curl"
        "wget"
        "unzip"
        "git"
        "htop"
        "nano"
        "rsync"
        "cron"
        "systemd"
        "dbus"
        "ca-certificates"
        "apt-transport-https"
        "software-properties-common"
    )
    
    # Installation des paquets
    if apt-get install -y "${base_packages[@]}"; then
        log_info "Paquets de base installés avec succès"
    else
        log_error "Échec de l'installation des paquets de base"
        return 1
    fi
}

# =============================================================================
# CONFIGURATION DE LA MÉMOIRE SWAP
# =============================================================================

configure_swap() {
    log_info "Configuration de la mémoire swap..."
    
    # Réduction du swap pour préserver la carte SD
    if [[ -f /etc/dphys-swapfile ]]; then
        # Réduction du swap à 512MB (au lieu de 1GB par défaut)
        sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=512/' /etc/dphys-swapfile
        
        # Redémarrage du service swap
        systemctl restart dphys-swapfile 2>/dev/null || true
        log_info "Swap configuré à 512MB"
    else
        log_warn "Configuration swap non trouvée"
    fi
}

# =============================================================================
# VALIDATION DE LA CONFIGURATION
# =============================================================================

validate_system_config() {
    log_info "Validation de la configuration système..."
    
    local errors=0
    
    # Vérification du hostname
    local current_hostname
    current_hostname=$(hostname)
    if [[ "$current_hostname" == "$NEW_HOSTNAME" ]] || [[ "$current_hostname" == "raspberrypi" ]]; then
        log_info "✓ Hostname configuré"
    else
        log_error "✗ Problème de hostname"
        ((errors++))
    fi
    
    # Vérification des répertoires
    for dir in "/opt/videos" "/opt/scripts" "/etc/pi-signage"; do
        if [[ -d "$dir" ]]; then
            log_info "✓ Répertoire $dir présent"
        else
            log_error "✗ Répertoire $dir manquant"
            ((errors++))
        fi
    done
    
    # Vérification des services désactivés
    if ! systemctl is-enabled bluetooth >/dev/null 2>&1; then
        log_info "✓ Services inutiles désactivés"
    else
        log_warn "⚠ Certains services sont encore actifs"
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Configuration Système ==="
    
    # Chargement de la configuration
    if ! load_config; then
        log_error "Impossible de charger la configuration"
        return 1
    fi
    
    # Étapes de configuration
    local steps=(
        "update_system"
        "install_base_packages"
        "configure_hostname"
        "configure_timezone"
        "disable_unnecessary_services"
        "create_directories"
        "configure_boot_stable"
        "configure_cmdline"
        "configure_swap"
    )
    
    local failed_steps=()
    
    for step in "${steps[@]}"; do
        log_info "Exécution: $step"
        if ! "$step"; then
            log_error "Échec de l'étape: $step"
            failed_steps+=("$step")
        fi
    done
    
    # Validation finale
    if validate_system_config; then
        log_info "Configuration système terminée avec succès"
    else
        log_warn "Configuration système terminée avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Configuration Système ==="
    return 0
}

# =============================================================================
# EXÉCUTION
# =============================================================================

# Vérification des droits root
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Exécution de la fonction principale
main "$@"