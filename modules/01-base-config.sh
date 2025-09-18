#!/bin/bash
# =============================================================================
# Module 01: Configuration de base - PiSignage Desktop v3.0
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/opt/pisignage"
USER="pisignage"
VERBOSE=${VERBOSE:-false}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[BASE-CONFIG] $1"
    fi
}

# Création utilisateur pisignage
create_user() {
    log "Vérification utilisateur $USER..."
    
    if ! id -u "$USER" &>/dev/null; then
        log "Création utilisateur $USER"
        sudo useradd -m -s /bin/bash -G video,audio,gpio "$USER"
        echo "$USER:pisignage" | sudo chpasswd
        echo -e "${GREEN}✓ Utilisateur $USER créé${NC}"
    else
        log "Utilisateur $USER existe déjà"
        # Ajouter aux groupes nécessaires
        sudo usermod -a -G video,audio,gpio "$USER" 2>/dev/null || true
    fi
}

# Configuration hostname (optionnel)
configure_hostname() {
    if [[ -n "${1:-}" ]]; then
        local new_hostname="$1"
        log "Configuration hostname: $new_hostname"
        
        echo "$new_hostname" | sudo tee /etc/hostname > /dev/null
        sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
        echo -e "${GREEN}✓ Hostname configuré: $new_hostname${NC}"
    fi
}

# Installation paquets essentiels
install_packages() {
    log "Installation des paquets essentiels..."
    
    local packages=(
        "nginx"
        "php-fpm"
        "php-sqlite3"
        "php-curl"
        "php-json"
        "sqlite3"
        "yt-dlp"
        "jq"
        "curl"
        "wget"
        "git"
        "unclutter"
        "xdotool"
    )
    
    # Mise à jour des sources
    sudo apt-get update -qq
    
    # Installation
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            log "Installation de $pkg..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg"
        fi
    done
    
    echo -e "${GREEN}✓ Paquets essentiels installés${NC}"
}

# Configuration GPU
configure_gpu() {
    log "Configuration GPU pour performances vidéo..."
    
    local config_file="/boot/firmware/config.txt"
    if [[ ! -f "$config_file" ]]; then
        config_file="/boot/config.txt"
    fi
    
    if [[ -f "$config_file" ]]; then
        # Sauvegarder la config
        sudo cp "$config_file" "${config_file}.backup.$(date +%Y%m%d)"
        
        # GPU memory
        if ! grep -q "^gpu_mem=" "$config_file"; then
            echo "gpu_mem=128" | sudo tee -a "$config_file" > /dev/null
        else
            sudo sed -i 's/^gpu_mem=.*/gpu_mem=128/' "$config_file"
        fi
        
        # HDMI settings
        if ! grep -q "^hdmi_force_hotplug=" "$config_file"; then
            echo "hdmi_force_hotplug=1" | sudo tee -a "$config_file" > /dev/null
        fi
        
        echo -e "${GREEN}✓ Configuration GPU optimisée${NC}"
    else
        echo -e "${YELLOW}⚠ Fichier config.txt non trouvé${NC}"
    fi
}

# Création structure dossiers
create_directories() {
    log "Création de la structure de dossiers..."
    
    local dirs=(
        "$BASE_DIR/videos"
        "$BASE_DIR/config"
        "$BASE_DIR/logs"
        "$BASE_DIR/scripts"
        "$BASE_DIR/backups"
        "/var/www/pisignage"
    )
    
    for dir in "${dirs[@]}"; do
        sudo mkdir -p "$dir"
        sudo chown -R "$USER:$USER" "$dir"
        log "Créé: $dir"
    done
    
    # Permissions spéciales pour www
    sudo chown -R www-data:www-data /var/www/pisignage
    sudo chmod -R 755 /var/www/pisignage
    
    echo -e "${GREEN}✓ Structure de dossiers créée${NC}"
}

# Configuration des permissions
set_permissions() {
    log "Configuration des permissions..."
    
    # Scripts exécutables
    find "$SCRIPT_DIR/.." -name "*.sh" -type f -exec chmod +x {} \;
    
    # Permissions pisignage
    sudo chown -R "$USER:$USER" "$BASE_DIR"
    
    # Sudo pour contrôle services
    echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl" | sudo tee /etc/sudoers.d/pisignage > /dev/null
    
    echo -e "${GREEN}✓ Permissions configurées${NC}"
}

# Main
main() {
    echo "Module 1: Configuration de base"
    echo "================================"
    
    create_user
    configure_hostname "${1:-}"
    install_packages
    configure_gpu
    create_directories
    set_permissions
    
    echo ""
    echo -e "${GREEN}✓ Module de configuration de base terminé${NC}"
    
    return 0
}

# Exécution
main "$@"