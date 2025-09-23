#!/bin/bash

# PiSignage v0.9.0 - Script d'Installation des Packages
# Installation optimisée pour Raspberry Pi OS Bullseye

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTALL_LOG="/tmp/pisignage-package-install.log"
RETRY_COUNT=3
RETRY_DELAY=5

# Fonction de log
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$INSTALL_LOG"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$INSTALL_LOG"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$INSTALL_LOG"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$INSTALL_LOG"
            ;;
    esac
    echo "[$timestamp] [$level] $message" >> "$INSTALL_LOG"
}

# Fonction d'exécution avec retry
execute_with_retry() {
    local command="$1"
    local description="$2"
    local attempt=1

    while [[ $attempt -le $RETRY_COUNT ]]; do
        log "INFO" "[$attempt/$RETRY_COUNT] $description"

        if eval "$command" >> "$INSTALL_LOG" 2>&1; then
            log "SUCCESS" "$description réussi"
            return 0
        else
            log "WARN" "Tentative $attempt échouée pour: $description"
            if [[ $attempt -lt $RETRY_COUNT ]]; then
                log "INFO" "Nouvelle tentative dans ${RETRY_DELAY}s..."
                sleep $RETRY_DELAY
            fi
            ((attempt++))
        fi
    done

    log "ERROR" "Échec après $RETRY_COUNT tentatives: $description"
    return 1
}

# Mise à jour du système
update_system() {
    log "INFO" "Mise à jour du système..."

    # Mise à jour de la liste des packages
    if ! execute_with_retry "sudo apt-get update" "Mise à jour de la liste des packages"; then
        log "ERROR" "Impossible de mettre à jour la liste des packages"
        return 1
    fi

    # Mise à jour des packages installés (optionnel, peut être long)
    log "INFO" "Mise à jour des packages système (peut prendre du temps)..."
    if ! execute_with_retry "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y" "Mise à jour des packages"; then
        log "WARN" "Mise à jour des packages échouée (non critique)"
    fi

    log "SUCCESS" "Mise à jour du système terminée"
    return 0
}

# Installation des packages de base
install_base_packages() {
    log "INFO" "Installation des packages de base..."

    local base_packages=(
        "curl"
        "wget"
        "unzip"
        "git"
        "htop"
        "nano"
        "tree"
        "rsync"
        "bc"
        "jq"
        "sqlite3"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
    )

    local packages_to_install=()

    # Vérifier quels packages sont manquants
    for package in "${base_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$package "; then
            packages_to_install+=("$package")
        else
            log "INFO" "Package '$package' déjà installé"
        fi
    done

    # Installer les packages manquants
    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        local packages_str=$(IFS=' '; echo "${packages_to_install[*]}")
        if ! execute_with_retry "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $packages_str" "Installation packages de base"; then
            log "ERROR" "Échec de l'installation des packages de base"
            return 1
        fi
    else
        log "INFO" "Tous les packages de base sont déjà installés"
    fi

    return 0
}

# Installation de Nginx
install_nginx() {
    log "INFO" "Installation de Nginx..."

    # Vérifier si nginx est déjà installé
    if systemctl is-enabled nginx &>/dev/null; then
        log "INFO" "Nginx déjà installé et activé"
        return 0
    fi

    # Installer nginx
    if ! execute_with_retry "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx" "Installation Nginx"; then
        log "ERROR" "Échec de l'installation de Nginx"
        return 1
    fi

    # Activer et démarrer nginx
    if ! execute_with_retry "sudo systemctl enable nginx" "Activation Nginx"; then
        log "ERROR" "Impossible d'activer Nginx"
        return 1
    fi

    if ! execute_with_retry "sudo systemctl start nginx" "Démarrage Nginx"; then
        log "ERROR" "Impossible de démarrer Nginx"
        return 1
    fi

    log "SUCCESS" "Nginx installé et configuré"
    return 0
}

# Installation de PHP 7.4 (optimisé pour Pi)
install_php() {
    log "INFO" "Installation de PHP 7.4..."

    # Packages PHP requis
    local php_packages=(
        "php7.4"
        "php7.4-fpm"
        "php7.4-common"
        "php7.4-mysql"
        "php7.4-xml"
        "php7.4-xmlrpc"
        "php7.4-curl"
        "php7.4-gd"
        "php7.4-imagick"
        "php7.4-cli"
        "php7.4-dev"
        "php7.4-imap"
        "php7.4-mbstring"
        "php7.4-opcache"
        "php7.4-soap"
        "php7.4-zip"
        "php7.4-intl"
        "php7.4-json"
        "php7.4-sqlite3"
    )

    # Vérifier si PHP est déjà installé
    if command -v php7.4 &>/dev/null; then
        log "INFO" "PHP 7.4 déjà installé"
        local current_version=$(php7.4 -v | head -n1)
        log "INFO" "Version: $current_version"
    else
        # Installer PHP
        local packages_str=$(IFS=' '; echo "${php_packages[*]}")
        if ! execute_with_retry "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $packages_str" "Installation PHP 7.4"; then
            log "ERROR" "Échec de l'installation de PHP"
            return 1
        fi
    fi

    # Activer et démarrer PHP-FPM
    if ! execute_with_retry "sudo systemctl enable php7.4-fpm" "Activation PHP-FPM"; then
        log "ERROR" "Impossible d'activer PHP-FPM"
        return 1
    fi

    if ! execute_with_retry "sudo systemctl start php7.4-fpm" "Démarrage PHP-FPM"; then
        log "ERROR" "Impossible de démarrer PHP-FPM"
        return 1
    fi

    log "SUCCESS" "PHP 7.4 installé et configuré"
    return 0
}

# Installation de Chromium optimisé pour Pi
install_chromium() {
    log "INFO" "Installation de Chromium pour Raspberry Pi..."

    # Packages Chromium et dépendances
    local chromium_packages=(
        "chromium-browser"
        "xserver-xorg"
        "xinit"
        "xfce4"
        "xfce4-terminal"
        "lightdm"
        "mesa-utils"
        "x11-xserver-utils"
        "unclutter"
        "sed"
    )

    # Vérifier si Chromium est déjà installé
    if command -v chromium-browser &>/dev/null; then
        log "INFO" "Chromium déjà installé"
        local chromium_version=$(chromium-browser --version 2>/dev/null || echo "Version inconnue")
        log "INFO" "Version: $chromium_version"
    else
        # Installer Chromium et dépendances
        local packages_str=$(IFS=' '; echo "${chromium_packages[*]}")
        if ! execute_with_retry "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $packages_str" "Installation Chromium"; then
            log "ERROR" "Échec de l'installation de Chromium"
            return 1
        fi
    fi

    # Configurer le démarrage automatique de X11
    if ! execute_with_retry "sudo systemctl enable lightdm" "Activation LightDM"; then
        log "WARN" "Impossible d'activer LightDM (non critique)"
    fi

    log "SUCCESS" "Chromium installé et configuré"
    return 0
}

# Installation des outils de développement
install_dev_tools() {
    log "INFO" "Installation des outils de développement..."

    local dev_packages=(
        "nodejs"
        "npm"
        "python3"
        "python3-pip"
        "python3-venv"
        "ffmpeg"
        "imagemagick"
        "youtube-dl"
    )

    # Vérifier et installer Node.js
    if ! command -v node &>/dev/null; then
        # Installer Node.js via NodeSource (version plus récente)
        log "INFO" "Installation de Node.js via NodeSource..."
        execute_with_retry "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -" "Ajout du dépôt NodeSource"
        execute_with_retry "sudo apt-get install -y nodejs" "Installation Node.js"
    else
        log "INFO" "Node.js déjà installé: $(node --version)"
    fi

    # Installer les autres packages
    local packages_to_install=()
    for package in "${dev_packages[@]}"; do
        if [[ "$package" == "nodejs" ]] || [[ "$package" == "npm" ]]; then
            continue # Déjà traité
        fi
        if ! dpkg -l | grep -q "^ii.*$package "; then
            packages_to_install+=("$package")
        fi
    done

    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        local packages_str=$(IFS=' '; echo "${packages_to_install[*]}")
        execute_with_retry "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $packages_str" "Installation outils de développement"
    fi

    # Installer yt-dlp (remplaçant moderne de youtube-dl)
    if ! command -v yt-dlp &>/dev/null; then
        log "INFO" "Installation de yt-dlp..."
        execute_with_retry "sudo pip3 install yt-dlp" "Installation yt-dlp"
    fi

    log "SUCCESS" "Outils de développement installés"
    return 0
}

# Installation des packages multimédia
install_multimedia_packages() {
    log "INFO" "Installation des packages multimédia..."

    local multimedia_packages=(
        "vlc"
        "vlc-plugin-base"
        "vlc-plugin-video-output"
        "gstreamer1.0-tools"
        "gstreamer1.0-plugins-base"
        "gstreamer1.0-plugins-good"
        "gstreamer1.0-plugins-bad"
        "gstreamer1.0-plugins-ugly"
        "gstreamer1.0-libav"
        "libav-tools"
    )

    local packages_to_install=()
    for package in "${multimedia_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$package "; then
            packages_to_install+=("$package")
        fi
    done

    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        local packages_str=$(IFS=' '; echo "${packages_to_install[*]}")
        if ! execute_with_retry "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $packages_str" "Installation packages multimédia"; then
            log "WARN" "Certains packages multimédia ont échoué (non critique)"
        fi
    else
        log "INFO" "Packages multimédia déjà installés"
    fi

    log "SUCCESS" "Packages multimédia installés"
    return 0
}

# Installation des dépendances GPU pour Raspberry Pi
install_gpu_dependencies() {
    log "INFO" "Installation des dépendances GPU..."

    # Packages pour l'accélération GPU
    local gpu_packages=(
        "mesa-va-drivers"
        "mesa-vdpau-drivers"
        "va-driver-all"
        "vdpau-driver-all"
        "libva2"
        "libvdpau1"
        "rpi-eeprom"
        "libraspberrypi-bin"
        "libraspberrypi-dev"
        "libraspberrypi0"
    )

    local packages_to_install=()
    for package in "${gpu_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$package "; then
            packages_to_install+=("$package")
        fi
    done

    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
        local packages_str=$(IFS=' '; echo "${packages_to_install[*]}")
        if ! execute_with_retry "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $packages_str" "Installation dépendances GPU"; then
            log "WARN" "Certaines dépendances GPU ont échoué (peut être normal sur non-Pi)"
        fi
    else
        log "INFO" "Dépendances GPU déjà installées"
    fi

    log "SUCCESS" "Dépendances GPU installées"
    return 0
}

# Nettoyage post-installation
cleanup_after_install() {
    log "INFO" "Nettoyage post-installation..."

    # Nettoyer le cache apt
    execute_with_retry "sudo apt-get autoremove -y" "Suppression packages orphelins"
    execute_with_retry "sudo apt-get autoclean" "Nettoyage cache APT"

    # Vérifier l'espace disque
    local available_space=$(df / | awk 'NR==2 {print int($4/1024)}')
    log "INFO" "Espace disque disponible après installation: ${available_space}MB"

    if [[ $available_space -lt 500 ]]; then
        log "WARN" "Espace disque faible après installation"
    fi

    log "SUCCESS" "Nettoyage terminé"
    return 0
}

# Vérification post-installation
verify_installation() {
    log "INFO" "Vérification de l'installation..."

    local services_to_check=("nginx" "php7.4-fpm")
    local commands_to_check=("nginx" "php7.4" "chromium-browser" "node" "npm")

    # Vérifier les services
    for service in "${services_to_check[@]}"; do
        if systemctl is-active "$service" &>/dev/null; then
            log "SUCCESS" "Service '$service' actif"
        else
            log "ERROR" "Service '$service' inactif"
        fi
    done

    # Vérifier les commandes
    for command in "${commands_to_check[@]}"; do
        if command -v "$command" &>/dev/null; then
            local version=$($command --version 2>/dev/null | head -n1 || echo "Version inconnue")
            log "SUCCESS" "Commande '$command' disponible: $version"
        else
            log "ERROR" "Commande '$command' non trouvée"
        fi
    done

    return 0
}

# Fonction principale
main() {
    echo "PiSignage v0.9.0 - Installation des Packages"
    echo "============================================"
    echo

    log "INFO" "Début de l'installation des packages..."
    log "INFO" "Log détaillé: $INSTALL_LOG"

    # Vérifier les permissions
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log "ERROR" "Permissions sudo requises"
        return 1
    fi

    # Étapes d'installation
    local steps=(
        "update_system"
        "install_base_packages"
        "install_nginx"
        "install_php"
        "install_chromium"
        "install_dev_tools"
        "install_multimedia_packages"
        "install_gpu_dependencies"
        "cleanup_after_install"
        "verify_installation"
    )

    for step in "${steps[@]}"; do
        log "INFO" "Exécution: $step"
        if ! $step; then
            log "ERROR" "Échec à l'étape: $step"
            return 1
        fi
        echo
    done

    log "SUCCESS" "Installation des packages terminée avec succès"
    log "INFO" "Redémarrage recommandé pour finaliser la configuration"

    return 0
}

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi