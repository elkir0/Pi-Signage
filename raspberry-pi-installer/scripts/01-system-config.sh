#!/usr/bin/env bash

# =============================================================================
# Module 01 - Configuration Système de Base (STABLE)
# Version: 2.1.0
# Description: Configuration système sans optimisations agressives
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les fonctions de sécurité
if [[ -f "$SCRIPT_DIR/00-security-utils.sh" ]]; then
    source "$SCRIPT_DIR/00-security-utils.sh"
    # Initialiser et nettoyer dpkg si nécessaire
    init_dpkg_cleanup
else
    echo "ERREUR: Fichier de sécurité manquant: 00-security-utils.sh" >&2
    exit 1
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
    
    # Mise à jour de la liste des paquets avec retry
    local apt_update_cmd="apt-get update"
    if ! safe_execute "$apt_update_cmd" 3 10; then
        log_error "Échec de la mise à jour des paquets après plusieurs tentatives"
        return 1
    fi
    
    log_info "Liste des paquets mise à jour"
    
    # Mise à jour des paquets installés (sélective)
    log_info "Mise à jour des paquets critiques..."
    local apt_upgrade_cmd="apt-get upgrade -y --with-new-pkgs -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'"
    
    if safe_execute "$apt_upgrade_cmd" 2 30; then
        log_info "Paquets mis à jour avec succès"
    else
        log_error "Échec de la mise à jour des paquets"
        # Ne pas bloquer l'installation pour une mise à jour échouée
        log_warn "L'installation continue malgré l'échec de mise à jour"
        return 0
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
    
    # NE PAS MODIFIER /boot/config.txt - Conformément aux exigences
    # Toutes les modifications de boot doivent être faites manuellement
    log_warn "AUCUNE modification de /boot/config.txt effectuée"
    log_info "Si nécessaire, utilisez raspi-config pour configurer:"
    log_info "  - La sortie HDMI : Advanced Options > Resolution"
    log_info "  - L'audio : System Options > Audio"
    log_info "  - L'accélération GPU : Advanced Options > GL Driver"
    
    log_info "Configuration boot stable appliquée"
}

# =============================================================================
# CONFIGURATION GPU POUR VIDÉO (OPTIMISATIONS PRUDENTES)
# =============================================================================

configure_video_optimizations() {
    log_info "Configuration des optimisations vidéo (prudentes)..."
    
    # Détection du chemin de boot
    local boot_path="/boot"
    [[ -d "/boot/firmware" ]] && boot_path="/boot/firmware"
    
    local config_file="$boot_path/config.txt"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Fichier config.txt introuvable à $config_file"
        return 1
    fi
    
    # Vérifier si gpu_mem est déjà configuré
    if grep -q "^gpu_mem=" "$config_file"; then
        local current_gpu_mem
        current_gpu_mem=$(grep "^gpu_mem=" "$config_file" | cut -d'=' -f2)
        log_warn "gpu_mem déjà configuré à ${current_gpu_mem}MB"
        
        if [[ $current_gpu_mem -lt 128 ]]; then
            log_warn "ATTENTION: gpu_mem=$current_gpu_mem est insuffisant pour l'accélération vidéo"
            log_info "Recommandation: gpu_mem=128 pour de meilleures performances vidéo"
            log_info "Pour modifier: sudo sed -i 's/^gpu_mem=.*/gpu_mem=128/' $config_file"
        else
            log_info "✓ gpu_mem=$current_gpu_mem est suffisant pour l'accélération vidéo"
        fi
    else
        log_info "Configuration de gpu_mem pour l'accélération vidéo..."
        # Ajouter gpu_mem=128 pour l'accélération hardware
        echo "" >> "$config_file"
        echo "# Mémoire GPU pour accélération vidéo (Pi Signage)" >> "$config_file"
        echo "gpu_mem=128" >> "$config_file"
        log_info "✓ gpu_mem=128 configuré pour l'accélération vidéo"
    fi
    
    # Vérifier dtoverlay=vc4-kms-v3d
    if ! grep -q "^dtoverlay=vc4-kms-v3d" "$config_file"; then
        log_warn "dtoverlay=vc4-kms-v3d non configuré - nécessaire pour l'accélération GPU"
        log_info "Ajout de dtoverlay=vc4-kms-v3d..."
        echo "dtoverlay=vc4-kms-v3d" >> "$config_file"
        echo "max_framebuffers=2" >> "$config_file"
    else
        log_info "✓ dtoverlay=vc4-kms-v3d déjà configuré"
    fi
    
    # Vérifier le support 4K si nécessaire (optionnel)
    if ! grep -q "^hdmi_enable_4kp60=" "$config_file"; then
        log_info "Support 4K non configuré (optionnel)"
        log_info "Pour activer: echo 'hdmi_enable_4kp60=1' | sudo tee -a $config_file"
    fi
    
    log_info "Optimisations vidéo configurées (redémarrage requis)"
}

# =============================================================================
# CONFIGURATION CMDLINE (OPTIMISATIONS LÉGÈRES)
# =============================================================================

configure_cmdline() {
    log_info "Vérification des paramètres de démarrage..."
    
    # NE PAS MODIFIER /boot/cmdline.txt - Conformément aux exigences
    log_warn "AUCUNE modification de /boot/cmdline.txt effectuée"
    log_info "Les paramètres de boot ne sont pas modifiés par ce script"
}

# =============================================================================
# CRÉATION DES RÉPERTOIRES
# =============================================================================

create_directories() {
    log_info "Création des répertoires système..."
    
    # Répertoires principaux avec permissions sécurisées
    local -A directories=(
        ["/opt/videos"]="www-data:www-data:755"
        ["/opt/scripts"]="root:root:750"
        ["/var/log/pi-signage"]="pi:pi:755"
        ["/etc/pi-signage"]="root:root:700"
    )
    
    # Créer l'utilisateur signage si nécessaire
    if ! id "signage" >/dev/null 2>&1; then
        log_info "Création de l'utilisateur signage"
        useradd -r -s /bin/false -m -d /home/signage -c "Pi Signage System User" signage || {
            log_error "Échec de la création de l'utilisateur signage"
            return 1
        }
        # S'assurer que le home directory a les bonnes permissions
        chmod 750 /home/signage
        chown signage:signage /home/signage
    fi
    
    for dir in "${!directories[@]}"; do
        IFS=':' read -r owner group perms <<< "${directories[$dir]}"
        
        if mkdir -p "$dir"; then
            log_info "Répertoire créé: $dir"
            
            # Appliquer les permissions sécurisées
            if ! secure_dir_permissions "$dir" "$owner" "$group" "$perms"; then
                log_error "Échec de l'application des permissions pour: $dir"
                return 1
            fi
        else
            log_error "Échec de la création du répertoire: $dir"
            return 1
        fi
    done
    
    # Créer les fichiers de log initiaux pour l'utilisateur pi
    if [[ -d "/var/log/pi-signage" ]]; then
        local log_files=(
            "chromium.log"
            "startup.log"
            "sync.log"
            "health.log"
            "playlist-update.log"
        )
        
        for log_file in "${log_files[@]}"; do
            touch "/var/log/pi-signage/$log_file"
            chown pi:pi "/var/log/pi-signage/$log_file"
            chmod 644 "/var/log/pi-signage/$log_file"
        done
        
        log_info "Fichiers de log initialisés"
    fi
    
    # Logger l'événement de sécurité
    log_security_event "DIRECTORIES_CREATED" "Répertoires système créés avec permissions sécurisées"
}

# =============================================================================
# PRÉPARATION DU SYSTÈME
# =============================================================================

prepare_system() {
    log_info "Préparation du système pour l'installation..."
    
    # Vérifier et réparer dpkg si nécessaire
    if command -v check_dpkg_health >/dev/null 2>&1; then
        if ! check_dpkg_health; then
            log_info "Réparation de dpkg avant installation..."
            repair_dpkg
        fi
    fi
    
    # Mettre à jour les listes de paquets
    log_info "Mise à jour des listes de paquets..."
    apt-get update || {
        log_warn "Première mise à jour échouée, nettoyage et réessai..."
        apt-get clean
        rm -rf /var/lib/apt/lists/*
        apt-get update
    }
    
    # Installer les dépendances système critiques en premier
    log_info "Installation des dépendances système critiques..."
    
    # Détecter l'architecture
    local arch=$(dpkg --print-architecture)
    log_info "Architecture: $arch"
    
    local critical_deps=(
        "libgtk-3-common"  # Souvent manquant, bloque Chromium
        "libgtk-3-0"       # Dépendance GTK pour interfaces graphiques
    )
    
    for dep in "${critical_deps[@]}"; do
        # Vérifier si le paquet est installé (avec ou sans architecture)
        if ! dpkg -l "$dep" 2>/dev/null | grep -q "^ii" && 
           ! dpkg -l "$dep:$arch" 2>/dev/null | grep -q "^ii"; then
            log_info "Installation de la dépendance critique: $dep"
            
            # Essayer d'installer avec --fix-broken si nécessaire
            apt-get install -y "$dep" || {
                log_warn "Tentative avec --fix-broken pour $dep"
                apt-get install -y --fix-broken "$dep" || {
                    log_warn "Tentative avec architecture explicite: $dep:$arch"
                    apt-get install -y --fix-broken "$dep:$arch" || true
                }
            }
        else
            log_info "$dep déjà installé"
        fi
    done
    
    # Vérifier spécifiquement que libgtk-3-0 est bien installé
    if ! dpkg -l | grep -q "^ii.*libgtk-3-0"; then
        log_error "libgtk-3-0 toujours manquant après installation!"
        log_info "Tentative de réparation forcée..."
        apt-get update
        apt-get install -f -y
        apt-get install -y --fix-broken libgtk-3-0 || true
    fi
}

# =============================================================================
# INSTALLATION DES PAQUETS DE BASE
# =============================================================================

install_base_packages() {
    log_info "Installation des paquets de base..."
    
    # Préparer le système d'abord
    prepare_system
    
    # Paquets essentiels pour le système (consolidés pour éviter les redondances)
    local base_packages=(
        # Outils système de base
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
        "lsof"
        "ca-certificates"
        "apt-transport-https"
        "software-properties-common"
        
        # Outils supplémentaires souvent réinstallés
        "jq"              # Pour JSON (utilisé par chromium et web)
        "bc"              # Pour calculs (utilisé dans scripts)
        "net-tools"       # Pour diagnostics réseau
        "ffmpeg"          # Pour traitement vidéo (VLC et YouTube)
        "python3"         # Pour scripts
        "python3-pip"     # Pour packages Python
        "alsa-utils"      # Pour gestion audio
    )
    
    # Utiliser la fonction robuste si disponible
    if command -v safe_apt_install >/dev/null 2>&1; then
        if safe_apt_install "${base_packages[@]}"; then
            log_info "Paquets de base installés avec succès"
        else
            log_error "Échec de l'installation des paquets de base"
            return 1
        fi
    else
        # Fallback sur apt-get standard
        if apt-get install -y "${base_packages[@]}"; then
            log_info "Paquets de base installés avec succès"
        else
            log_error "Échec de l'installation des paquets de base"
            return 1
        fi
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
        "configure_video_optimizations"
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