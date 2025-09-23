#!/bin/bash

# PiSignage v0.9.0 - Script de Sauvegarde Système
# Crée une sauvegarde complète avant déploiement avec possibilité de rollback

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BACKUP_BASE_DIR="/opt/pisignage-backups"
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/backup-$BACKUP_DATE"
CURRENT_INSTALL_DIR="/opt/pisignage"
MAX_BACKUPS=5

# Fonction de log
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "[INFO] $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
    esac
}

# Créer la structure de sauvegarde
create_backup_structure() {
    log "INFO" "Création de la structure de sauvegarde..."

    # Créer le répertoire de base
    if ! sudo mkdir -p "$BACKUP_BASE_DIR"; then
        log "ERROR" "Impossible de créer $BACKUP_BASE_DIR"
        return 1
    fi

    # Créer le répertoire de cette sauvegarde
    if ! sudo mkdir -p "$BACKUP_DIR"; then
        log "ERROR" "Impossible de créer $BACKUP_DIR"
        return 1
    fi

    # Créer les sous-répertoires
    local subdirs=("app" "config" "services" "system" "data")
    for subdir in "${subdirs[@]}"; do
        if ! sudo mkdir -p "$BACKUP_DIR/$subdir"; then
            log "ERROR" "Impossible de créer $BACKUP_DIR/$subdir"
            return 1
        fi
    done

    log "SUCCESS" "Structure de sauvegarde créée: $BACKUP_DIR"
    return 0
}

# Sauvegarder l'application existante
backup_application() {
    log "INFO" "Sauvegarde de l'application existante..."

    if [[ -d "$CURRENT_INSTALL_DIR" ]]; then
        log "INFO" "Sauvegarde de $CURRENT_INSTALL_DIR..."
        if sudo cp -r "$CURRENT_INSTALL_DIR" "$BACKUP_DIR/app/pisignage"; then
            log "SUCCESS" "Application sauvegardée"
        else
            log "ERROR" "Échec de la sauvegarde de l'application"
            return 1
        fi
    else
        log "INFO" "Aucune installation existante trouvée"
        # Créer un marqueur pour indiquer l'absence d'installation
        echo "NO_PREVIOUS_INSTALLATION" | sudo tee "$BACKUP_DIR/app/no_previous_install" > /dev/null
    fi

    return 0
}

# Sauvegarder les configurations système
backup_system_configs() {
    log "INFO" "Sauvegarde des configurations système..."

    # Configuration nginx
    if [[ -d /etc/nginx ]]; then
        log "INFO" "Sauvegarde de la configuration nginx..."
        sudo cp -r /etc/nginx "$BACKUP_DIR/config/" 2>/dev/null || log "WARN" "Nginx non configuré"
    fi

    # Configuration PHP
    local php_versions=("7.4" "8.0" "8.1" "8.2")
    for version in "${php_versions[@]}"; do
        if [[ -d "/etc/php/$version" ]]; then
            log "INFO" "Sauvegarde de PHP $version..."
            sudo cp -r "/etc/php/$version" "$BACKUP_DIR/config/php-$version" 2>/dev/null
        fi
    done

    # Configuration systemd services
    log "INFO" "Sauvegarde des services systemd..."
    sudo mkdir -p "$BACKUP_DIR/services"
    if [[ -f /etc/systemd/system/pisignage.service ]]; then
        sudo cp /etc/systemd/system/pisignage.service "$BACKUP_DIR/services/"
    fi
    if [[ -f /etc/systemd/system/pisignage-kiosk.service ]]; then
        sudo cp /etc/systemd/system/pisignage-kiosk.service "$BACKUP_DIR/services/"
    fi

    # Configuration du boot
    if [[ -f /boot/config.txt ]]; then
        log "INFO" "Sauvegarde de /boot/config.txt..."
        sudo cp /boot/config.txt "$BACKUP_DIR/system/"
    fi

    # Configuration réseau
    if [[ -d /etc/dhcpcd.conf ]]; then
        sudo cp /etc/dhcpcd.conf "$BACKUP_DIR/system/" 2>/dev/null || true
    fi

    return 0
}

# Sauvegarder les données utilisateur
backup_user_data() {
    log "INFO" "Sauvegarde des données utilisateur..."

    # Médias existants
    if [[ -d "$CURRENT_INSTALL_DIR/media" ]]; then
        log "INFO" "Sauvegarde des médias..."
        sudo cp -r "$CURRENT_INSTALL_DIR/media" "$BACKUP_DIR/data/" 2>/dev/null || log "WARN" "Pas de médias à sauvegarder"
    fi

    # Logs
    if [[ -d "$CURRENT_INSTALL_DIR/logs" ]]; then
        log "INFO" "Sauvegarde des logs..."
        sudo cp -r "$CURRENT_INSTALL_DIR/logs" "$BACKUP_DIR/data/" 2>/dev/null || log "WARN" "Pas de logs à sauvegarder"
    fi

    # Configuration utilisateur
    if [[ -f "$CURRENT_INSTALL_DIR/config.json" ]]; then
        log "INFO" "Sauvegarde de la configuration utilisateur..."
        sudo cp "$CURRENT_INSTALL_DIR/config.json" "$BACKUP_DIR/data/"
    fi

    return 0
}

# Créer un manifeste de sauvegarde
create_backup_manifest() {
    log "INFO" "Création du manifeste de sauvegarde..."

    local manifest_file="$BACKUP_DIR/MANIFEST"

    # Informations de base
    cat << EOF | sudo tee "$manifest_file" > /dev/null
PiSignage Backup Manifest
========================

Date: $(date)
Hostname: $(hostname)
User: $(whoami)
Backup Directory: $BACKUP_DIR

System Information:
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
- Kernel: $(uname -r)
- Architecture: $(uname -m)
- Uptime: $(uptime)

Previous Installation:
EOF

    # Vérifier la version précédente
    if [[ -f "$CURRENT_INSTALL_DIR/VERSION" ]]; then
        echo "- Version: $(cat $CURRENT_INSTALL_DIR/VERSION)" | sudo tee -a "$manifest_file" > /dev/null
    else
        echo "- Version: Non détectée" | sudo tee -a "$manifest_file" > /dev/null
    fi

    # Services actifs
    echo "" | sudo tee -a "$manifest_file" > /dev/null
    echo "Services Active:" | sudo tee -a "$manifest_file" > /dev/null
    systemctl list-units --state=active --type=service | grep -E "(nginx|php|pisignage)" | sudo tee -a "$manifest_file" > /dev/null || echo "- Aucun service PiSignage actif" | sudo tee -a "$manifest_file" > /dev/null

    # Contenu de la sauvegarde
    echo "" | sudo tee -a "$manifest_file" > /dev/null
    echo "Backup Contents:" | sudo tee -a "$manifest_file" > /dev/null
    sudo find "$BACKUP_DIR" -type f | sudo tee -a "$manifest_file" > /dev/null

    log "SUCCESS" "Manifeste créé: $manifest_file"
    return 0
}

# Nettoyer les anciennes sauvegardes
cleanup_old_backups() {
    log "INFO" "Nettoyage des anciennes sauvegardes..."

    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        log "INFO" "Aucune sauvegarde précédente trouvée"
        return 0
    fi

    # Compter les sauvegardes existantes
    local backup_count=$(sudo find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "backup-*" | wc -l)

    if [[ $backup_count -gt $MAX_BACKUPS ]]; then
        log "INFO" "Suppression des anciennes sauvegardes (gardé: $MAX_BACKUPS)..."

        # Supprimer les plus anciennes
        sudo find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "backup-*" -printf '%T@ %p\n' | \
        sort -n | \
        head -n -$MAX_BACKUPS | \
        cut -d' ' -f2- | \
        while read -r old_backup; do
            log "INFO" "Suppression: $(basename "$old_backup")"
            sudo rm -rf "$old_backup"
        done
    fi

    log "INFO" "Nettoyage terminé"
    return 0
}

# Créer un script de rollback
create_rollback_script() {
    log "INFO" "Création du script de rollback..."

    local rollback_script="$BACKUP_DIR/rollback.sh"

    cat << 'EOF' | sudo tee "$rollback_script" > /dev/null
#!/bin/bash

# Script de rollback automatique
# Généré automatiquement lors de la sauvegarde

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local level=$1
    shift
    echo -e "[$level] $*"
}

BACKUP_DIR="$(dirname "$(readlink -f "$0")")"
CURRENT_INSTALL_DIR="/opt/pisignage"

log "INFO" "Début du rollback depuis $BACKUP_DIR"

# Arrêter les services
log "INFO" "Arrêt des services..."
sudo systemctl stop pisignage 2>/dev/null || true
sudo systemctl stop pisignage-kiosk 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# Restaurer l'application
if [[ -f "$BACKUP_DIR/app/no_previous_install" ]]; then
    log "INFO" "Suppression de l'installation (aucune installation précédente)"
    sudo rm -rf "$CURRENT_INSTALL_DIR"
else
    log "INFO" "Restauration de l'application..."
    sudo rm -rf "$CURRENT_INSTALL_DIR"
    sudo cp -r "$BACKUP_DIR/app/pisignage" "$CURRENT_INSTALL_DIR"
fi

# Restaurer les configurations
log "INFO" "Restauration des configurations..."

# Nginx
if [[ -d "$BACKUP_DIR/config/nginx" ]]; then
    sudo rm -rf /etc/nginx
    sudo cp -r "$BACKUP_DIR/config/nginx" /etc/nginx
fi

# PHP
sudo find "$BACKUP_DIR/config" -name "php-*" -type d | while read -r php_dir; do
    version=$(basename "$php_dir" | cut -d- -f2)
    if [[ -d "/etc/php/$version" ]]; then
        sudo rm -rf "/etc/php/$version"
        sudo cp -r "$php_dir" "/etc/php/$version"
    fi
done

# Services systemd
if [[ -d "$BACKUP_DIR/services" ]]; then
    sudo cp "$BACKUP_DIR/services"/*.service /etc/systemd/system/ 2>/dev/null || true
    sudo systemctl daemon-reload
fi

# Configuration système
if [[ -f "$BACKUP_DIR/system/config.txt" ]]; then
    sudo cp "$BACKUP_DIR/system/config.txt" /boot/
fi

# Redémarrer les services
log "INFO" "Redémarrage des services..."
sudo systemctl enable nginx 2>/dev/null || true
sudo systemctl start nginx 2>/dev/null || true

log "SUCCESS" "Rollback terminé avec succès"
log "INFO" "Redémarrage recommandé: sudo reboot"
EOF

    sudo chmod +x "$rollback_script"
    log "SUCCESS" "Script de rollback créé: $rollback_script"
    return 0
}

# Fonction principale
main() {
    echo "PiSignage v0.9.0 - Sauvegarde Système"
    echo "====================================="
    echo

    log "INFO" "Début de la sauvegarde système..."

    # Vérifier les permissions
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log "ERROR" "Permissions sudo requises pour la sauvegarde"
        return 1
    fi

    # Créer la structure
    if ! create_backup_structure; then
        return 1
    fi

    # Sauvegarder les composants
    backup_application
    backup_system_configs
    backup_user_data

    # Créer les métadonnées
    create_backup_manifest
    create_rollback_script

    # Nettoyer les anciennes sauvegardes
    cleanup_old_backups

    # Résumé
    local backup_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    log "SUCCESS" "Sauvegarde terminée avec succès"
    log "INFO" "Répertoire: $BACKUP_DIR"
    log "INFO" "Taille: $backup_size"
    log "INFO" "Rollback: $BACKUP_DIR/rollback.sh"

    # Créer un lien vers la dernière sauvegarde
    sudo rm -f "$BACKUP_BASE_DIR/latest"
    sudo ln -s "$BACKUP_DIR" "$BACKUP_BASE_DIR/latest"

    return 0
}

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi