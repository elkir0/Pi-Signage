#!/bin/bash

# PiSignage v0.9.0 - Script de Rollback Automatique
# Système de rollback intelligent avec détection automatique des sauvegardes

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ROLLBACK_LOG="/tmp/pisignage-rollback.log"
BACKUP_BASE_DIR="/opt/pisignage-backups"
CURRENT_DIR="/opt/pisignage"
INTERACTIVE=true

# Fonction de log
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$ROLLBACK_LOG"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$ROLLBACK_LOG"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$ROLLBACK_LOG"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$ROLLBACK_LOG"
            ;;
    esac
    echo "[$timestamp] [$level] $message" >> "$ROLLBACK_LOG"
}

# Fonction pour lister les sauvegardes disponibles
list_available_backups() {
    log "INFO" "Recherche des sauvegardes disponibles..."

    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        log "ERROR" "Aucun répertoire de sauvegarde trouvé: $BACKUP_BASE_DIR"
        return 1
    fi

    local backups=()
    while IFS= read -r -d '' backup; do
        backups+=("$backup")
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "backup-*" -print0 | sort -z)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log "ERROR" "Aucune sauvegarde trouvée"
        return 1
    fi

    echo
    echo "Sauvegardes disponibles:"
    echo "========================"

    local i=1
    for backup in "${backups[@]}"; do
        local backup_name=$(basename "$backup")
        local backup_date=$(echo "$backup_name" | sed 's/backup-//; s/-/ /g; s/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\) \([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
        local backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)

        # Lire le manifeste si disponible
        local version="Inconnue"
        local manifest_file="$backup/MANIFEST"
        if [[ -f "$manifest_file" ]]; then
            version=$(grep "Version:" "$manifest_file" 2>/dev/null | cut -d: -f2 | xargs || echo "Inconnue")
        fi

        echo "$i) $backup_name"
        echo "   Date: $backup_date"
        echo "   Taille: $backup_size"
        echo "   Version: $version"
        echo "   Chemin: $backup"
        echo

        ((i++))
    done

    return 0
}

# Fonction pour sélectionner une sauvegarde
select_backup() {
    local backups=()
    while IFS= read -r -d '' backup; do
        backups+=("$backup")
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "backup-*" -print0 | sort -z)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log "ERROR" "Aucune sauvegarde disponible"
        return 1
    fi

    # Mode non-interactif: prendre la plus récente
    if [[ "$INTERACTIVE" == "false" ]]; then
        selected_backup="${backups[-1]}"
        log "INFO" "Sélection automatique: $(basename "$selected_backup")"
        return 0
    fi

    # Mode interactif
    echo "Sélectionnez une sauvegarde (1-${#backups[@]}) ou 'latest' pour la plus récente:"
    read -r choice

    if [[ "$choice" == "latest" ]]; then
        selected_backup="${backups[-1]}"
        log "INFO" "Sélection: plus récente ($(basename "$selected_backup"))"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#backups[@]} ]]; then
        selected_backup="${backups[$((choice-1))]}"
        log "INFO" "Sélection: $(basename "$selected_backup")"
    else
        log "ERROR" "Sélection invalide"
        return 1
    fi

    return 0
}

# Fonction de validation de la sauvegarde
validate_backup() {
    local backup_dir="$1"

    log "INFO" "Validation de la sauvegarde: $(basename "$backup_dir")"

    # Vérifier la structure de base
    local required_dirs=("app" "config" "services" "system")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$backup_dir/$dir" ]]; then
            log "WARN" "Répertoire manquant dans la sauvegarde: $dir"
        fi
    done

    # Vérifier le manifeste
    if [[ ! -f "$backup_dir/MANIFEST" ]]; then
        log "WARN" "Manifeste de sauvegarde manquant"
    else
        log "INFO" "Manifeste trouvé"
        # Afficher quelques infos du manifeste
        local backup_date=$(grep "Date:" "$backup_dir/MANIFEST" | cut -d: -f2- | xargs)
        local backup_hostname=$(grep "Hostname:" "$backup_dir/MANIFEST" | cut -d: -f2 | xargs)
        log "INFO" "Date de sauvegarde: $backup_date"
        log "INFO" "Hostname: $backup_hostname"
    fi

    # Vérifier le script de rollback
    if [[ -x "$backup_dir/rollback.sh" ]]; then
        log "SUCCESS" "Script de rollback trouvé et exécutable"
    else
        log "WARN" "Script de rollback manquant ou non exécutable"
    fi

    return 0
}

# Fonction d'arrêt des services
stop_services() {
    log "INFO" "Arrêt des services PiSignage..."

    local services=("pisignage-kiosk" "pisignage" "pisignage-monitor")

    for service in "${services[@]}"; do
        if systemctl is-active "$service" &>/dev/null; then
            log "INFO" "Arrêt du service: $service"
            if sudo systemctl stop "$service"; then
                log "SUCCESS" "Service $service arrêté"
            else
                log "WARN" "Problème lors de l'arrêt de $service"
            fi
        else
            log "INFO" "Service $service déjà arrêté"
        fi
    done

    # Arrêter nginx et php temporairement
    log "INFO" "Arrêt temporaire de nginx et php-fpm..."
    sudo systemctl stop nginx php7.4-fpm || log "WARN" "Problème lors de l'arrêt nginx/php"

    return 0
}

# Fonction de sauvegarde de l'état actuel
backup_current_state() {
    log "INFO" "Sauvegarde de l'état actuel avant rollback..."

    local emergency_backup="$BACKUP_BASE_DIR/emergency-backup-$(date +%Y%m%d-%H%M%S)"

    if sudo mkdir -p "$emergency_backup"; then
        # Sauvegarder l'installation actuelle
        if [[ -d "$CURRENT_DIR" ]]; then
            sudo cp -r "$CURRENT_DIR" "$emergency_backup/current-install" 2>/dev/null || log "WARN" "Sauvegarde partielle de l'installation actuelle"
        fi

        # Sauvegarder les configurations critiques
        sudo mkdir -p "$emergency_backup/config"
        sudo cp -r /etc/nginx "$emergency_backup/config/" 2>/dev/null || true
        sudo cp -r /etc/php/7.4 "$emergency_backup/config/php-7.4" 2>/dev/null || true
        sudo cp /boot/config.txt "$emergency_backup/config/" 2>/dev/null || true

        # Créer un manifeste d'urgence
        cat << EOF | sudo tee "$emergency_backup/EMERGENCY_MANIFEST" > /dev/null
Emergency Backup Before Rollback
===============================

Date: $(date)
Hostname: $(hostname)
Reason: Rollback operation safety backup

This backup was created automatically before rollback operation.
It contains the current state before the rollback was performed.

Target rollback: $(basename "$selected_backup")
EOF

        log "SUCCESS" "Sauvegarde d'urgence créée: $emergency_backup"
    else
        log "WARN" "Impossible de créer la sauvegarde d'urgence"
    fi

    return 0
}

# Fonction de restauration de l'application
restore_application() {
    local backup_dir="$1"

    log "INFO" "Restauration de l'application..."

    # Supprimer l'installation actuelle
    if [[ -d "$CURRENT_DIR" ]]; then
        log "INFO" "Suppression de l'installation actuelle..."
        sudo rm -rf "$CURRENT_DIR" || {
            log "ERROR" "Impossible de supprimer l'installation actuelle"
            return 1
        }
    fi

    # Restaurer l'application
    if [[ -f "$backup_dir/app/no_previous_install" ]]; then
        log "INFO" "Aucune installation précédente (suppression uniquement)"
    elif [[ -d "$backup_dir/app/pisignage" ]]; then
        log "INFO" "Restauration de l'application depuis la sauvegarde..."
        if sudo cp -r "$backup_dir/app/pisignage" "$CURRENT_DIR"; then
            log "SUCCESS" "Application restaurée"
        else
            log "ERROR" "Échec de la restauration de l'application"
            return 1
        fi
    else
        log "ERROR" "Données d'application manquantes dans la sauvegarde"
        return 1
    fi

    return 0
}

# Fonction de restauration des configurations
restore_configurations() {
    local backup_dir="$1"

    log "INFO" "Restauration des configurations..."

    # Restaurer nginx
    if [[ -d "$backup_dir/config/nginx" ]]; then
        log "INFO" "Restauration de la configuration nginx..."
        sudo rm -rf /etc/nginx
        sudo cp -r "$backup_dir/config/nginx" /etc/nginx
        log "SUCCESS" "Configuration nginx restaurée"
    fi

    # Restaurer PHP
    sudo find "$backup_dir/config" -name "php-*" -type d | while read -r php_dir; do
        local version=$(basename "$php_dir" | cut -d- -f2)
        if [[ -d "/etc/php/$version" ]]; then
            log "INFO" "Restauration de PHP $version..."
            sudo rm -rf "/etc/php/$version"
            sudo cp -r "$php_dir" "/etc/php/$version"
            log "SUCCESS" "PHP $version restauré"
        fi
    done

    # Restaurer les services systemd
    if [[ -d "$backup_dir/services" ]]; then
        log "INFO" "Restauration des services systemd..."
        sudo cp "$backup_dir/services"/*.service /etc/systemd/system/ 2>/dev/null || log "WARN" "Aucun service à restaurer"
        sudo systemctl daemon-reload
        log "SUCCESS" "Services systemd restaurés"
    fi

    # Restaurer la configuration boot
    if [[ -f "$backup_dir/system/config.txt" ]]; then
        log "INFO" "Restauration de /boot/config.txt..."
        sudo cp "$backup_dir/system/config.txt" /boot/
        log "SUCCESS" "Configuration boot restaurée"
    fi

    return 0
}

# Fonction de restauration des données utilisateur
restore_user_data() {
    local backup_dir="$1"

    log "INFO" "Restauration des données utilisateur..."

    # Restaurer les médias
    if [[ -d "$backup_dir/data/media" ]]; then
        log "INFO" "Restauration des médias..."
        sudo mkdir -p "$CURRENT_DIR/media"
        sudo cp -r "$backup_dir/data/media"/* "$CURRENT_DIR/media/" 2>/dev/null || log "INFO" "Aucun média à restaurer"
    fi

    # Restaurer les logs (optionnel)
    if [[ -d "$backup_dir/data/logs" ]]; then
        log "INFO" "Restauration des logs..."
        sudo mkdir -p "$CURRENT_DIR/logs"
        sudo cp -r "$backup_dir/data/logs"/* "$CURRENT_DIR/logs/" 2>/dev/null || log "INFO" "Aucun log à restaurer"
    fi

    # Restaurer la configuration utilisateur
    if [[ -f "$backup_dir/data/config.json" ]]; then
        log "INFO" "Restauration de la configuration utilisateur..."
        sudo cp "$backup_dir/data/config.json" "$CURRENT_DIR/"
    fi

    return 0
}

# Fonction de redémarrage des services
restart_services() {
    log "INFO" "Redémarrage des services..."

    # Redémarrer les services de base
    local base_services=("nginx" "php7.4-fpm")
    for service in "${base_services[@]}"; do
        log "INFO" "Redémarrage de $service..."
        if sudo systemctl restart "$service"; then
            log "SUCCESS" "Service $service redémarré"
        else
            log "ERROR" "Échec du redémarrage de $service"
        fi
    done

    # Attendre un peu
    sleep 5

    # Redémarrer les services PiSignage
    local pisignage_services=("pisignage" "pisignage-monitor")
    for service in "${pisignage_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service.service"; then
            log "INFO" "Redémarrage de $service..."
            if sudo systemctl restart "$service"; then
                log "SUCCESS" "Service $service redémarré"
            else
                log "WARN" "Problème avec le service $service"
            fi
        fi
    done

    return 0
}

# Fonction de validation post-rollback
validate_rollback() {
    log "INFO" "Validation du rollback..."

    # Attendre que les services soient prêts
    sleep 10

    # Test de connectivité HTTP
    if curl -s http://localhost >/dev/null; then
        log "SUCCESS" "Interface web accessible après rollback"
    else
        log "ERROR" "Interface web non accessible après rollback"
        return 1
    fi

    # Vérifier la version
    if [[ -f "$CURRENT_DIR/VERSION" ]]; then
        local restored_version=$(cat "$CURRENT_DIR/VERSION")
        log "INFO" "Version restaurée: $restored_version"
    fi

    # Test des services
    local critical_services=("nginx" "php7.4-fpm")
    for service in "${critical_services[@]}"; do
        if systemctl is-active "$service" &>/dev/null; then
            log "SUCCESS" "Service $service actif après rollback"
        else
            log "ERROR" "Service $service inactif après rollback"
        fi
    done

    return 0
}

# Fonction d'utilisation du script de rollback dédié
use_dedicated_rollback_script() {
    local backup_dir="$1"
    local rollback_script="$backup_dir/rollback.sh"

    if [[ -x "$rollback_script" ]]; then
        log "INFO" "Utilisation du script de rollback dédié..."

        if sudo bash "$rollback_script"; then
            log "SUCCESS" "Script de rollback dédié exécuté avec succès"
            return 0
        else
            log "ERROR" "Échec du script de rollback dédié"
            return 1
        fi
    else
        log "INFO" "Pas de script de rollback dédié, utilisation de la méthode standard"
        return 1
    fi
}

# Fonction principale de rollback
perform_rollback() {
    local backup_dir="$selected_backup"

    log "INFO" "========================================"
    log "INFO" "DÉBUT DU ROLLBACK PISIGNAGE"
    log "INFO" "========================================"
    log "INFO" "Source: $(basename "$backup_dir")"

    # Validation de la sauvegarde
    if ! validate_backup "$backup_dir"; then
        log "ERROR" "Validation de la sauvegarde échouée"
        return 1
    fi

    # Tentative avec le script dédié d'abord
    if use_dedicated_rollback_script "$backup_dir"; then
        log "SUCCESS" "Rollback réussi avec le script dédié"
        return 0
    fi

    # Méthode standard
    log "INFO" "Rollback avec la méthode standard..."

    # Étapes du rollback
    local rollback_steps=(
        "stop_services"
        "backup_current_state"
        "restore_application"
        "restore_configurations"
        "restore_user_data"
        "restart_services"
        "validate_rollback"
    )

    for step in "${rollback_steps[@]}"; do
        log "INFO" "Exécution: $step"
        if ! $step "$backup_dir"; then
            log "ERROR" "Échec à l'étape: $step"
            return 1
        fi
        echo
    done

    log "SUCCESS" "Rollback terminé avec succès"
    return 0
}

# Fonction d'aide
show_help() {
    cat << EOF
PiSignage v0.9.0 - Script de Rollback Automatique

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Afficher cette aide
    -l, --list          Lister les sauvegardes disponibles
    -a, --auto          Mode automatique (non-interactif)
    -b, --backup DIR    Utiliser une sauvegarde spécifique

EXEMPLES:
    $0                  # Rollback interactif
    $0 --list           # Lister les sauvegardes
    $0 --auto           # Rollback automatique (plus récente)
    $0 --backup /opt/pisignage-backups/backup-20250922-150000

Le script propose une liste des sauvegardes disponibles et permet
de sélectionner celle à restaurer. En mode automatique, la plus
récente est utilisée.

EOF
}

# Fonction principale
main() {
    echo "PiSignage v0.9.0 - Rollback Automatique"
    echo "======================================="
    echo

    log "INFO" "Début du processus de rollback..."
    log "INFO" "Log détaillé: $ROLLBACK_LOG"

    # Vérifier les permissions
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log "ERROR" "Permissions sudo requises"
        return 1
    fi

    # Lister les sauvegardes
    if ! list_available_backups; then
        return 1
    fi

    # Sélectionner une sauvegarde
    if ! select_backup; then
        return 1
    fi

    # Confirmation en mode interactif
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo
        echo -e "${YELLOW}ATTENTION:${NC} Cette opération va:"
        echo "  - Arrêter les services PiSignage"
        echo "  - Sauvegarder l'état actuel"
        echo "  - Restaurer la sauvegarde sélectionnée"
        echo "  - Redémarrer les services"
        echo
        echo -e "Rollback vers: ${GREEN}$(basename "$selected_backup")${NC}"
        echo
        read -p "Continuer? (oui/non): " confirm

        if [[ "$confirm" != "oui" ]]; then
            log "INFO" "Rollback annulé par l'utilisateur"
            return 0
        fi
    fi

    # Exécuter le rollback
    if perform_rollback; then
        echo
        log "SUCCESS" "========================================"
        log "SUCCESS" "ROLLBACK RÉUSSI !"
        log "SUCCESS" "========================================"
        log "INFO" "Interface accessible: http://localhost"
        log "INFO" "Redémarrage recommandé: sudo reboot"
        return 0
    else
        echo
        log "ERROR" "========================================"
        log "ERROR" "ROLLBACK ÉCHOUÉ !"
        log "ERROR" "========================================"
        log "ERROR" "Consultez le log: $ROLLBACK_LOG"
        return 1
    fi
}

# Parsing des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            list_available_backups
            exit 0
            ;;
        -a|--auto)
            INTERACTIVE=false
            shift
            ;;
        -b|--backup)
            selected_backup="$2"
            INTERACTIVE=false
            shift 2
            ;;
        *)
            log "ERROR" "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi