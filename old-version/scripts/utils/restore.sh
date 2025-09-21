#!/bin/bash
# PiSignage Desktop v3.0 - Restore Script
# Restaure une sauvegarde PiSignage

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Variables
BACKUP_FILE=""
FORCE=false
RESTORE_VIDEOS=true
RESTORE_CONFIG=true

# Fonctions utilitaires
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Aide
show_help() {
    cat << EOF
PiSignage Desktop v3.0 - Restore Script

Usage: $0 [OPTIONS] BACKUP_FILE

Options:
    -h, --help          Affiche cette aide
    -f, --force         Force la restauration sans confirmation
    --no-videos         Ne pas restaurer les vidéos
    --no-config         Ne pas restaurer la configuration système

Exemples:
    $0 /path/to/backup.tar.gz      # Restauration interactive
    $0 -f backup.tar.gz           # Restauration forcée
    $0 --no-videos backup.tar.gz  # Sans les vidéos

EOF
}

# Parse des arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --no-videos)
                RESTORE_VIDEOS=false
                shift
                ;;
            --no-config)
                RESTORE_CONFIG=false
                shift
                ;;
            -*)
                error "Option inconnue: $1"
                show_help
                exit 1
                ;;
            *)
                BACKUP_FILE="$1"
                shift
                ;;
        esac
    done
}

# Validation du fichier de sauvegarde
validate_backup_file() {
    if [[ -z "$BACKUP_FILE" ]]; then
        error "Fichier de sauvegarde requis"
        show_help
        exit 1
    fi
    
    if [[ ! -f "$BACKUP_FILE" ]]; then
        error "Fichier de sauvegarde non trouvé: $BACKUP_FILE"
        exit 1
    fi
    
    # Test de l'archive
    info "Vérification de l'archive..."
    
    if [[ "$BACKUP_FILE" == *.tar.gz ]]; then
        if ! tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
            error "Archive corrompue ou invalide"
            exit 1
        fi
    elif [[ "$BACKUP_FILE" == *.tar ]]; then
        if ! tar -tf "$BACKUP_FILE" > /dev/null 2>&1; then
            error "Archive corrompue ou invalide"
            exit 1
        fi
    else
        error "Format d'archive non supporté (utilisez .tar ou .tar.gz)"
        exit 1
    fi
    
    success "Archive valide"
}

# Affichage des informations de sauvegarde
show_backup_info() {
    info "Informations sur la sauvegarde..."
    
    local temp_dir="/tmp/pisignage-restore-info-$TIMESTAMP"
    mkdir -p "$temp_dir"
    
    # Extraction des métadonnées
    if [[ "$BACKUP_FILE" == *.tar.gz ]]; then
        tar -xzf "$BACKUP_FILE" -C "$temp_dir" backup_info.txt 2>/dev/null || true
    else
        tar -xf "$BACKUP_FILE" -C "$temp_dir" backup_info.txt 2>/dev/null || true
    fi
    
    if [[ -f "$temp_dir/backup_info.txt" ]]; then
        echo
        cat "$temp_dir/backup_info.txt"
        echo
    else
        warn "Métadonnées de sauvegarde non trouvées"
    fi
    
    rm -rf "$temp_dir"
}

# Confirmation de restauration
confirm_restore() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}ATTENTION: Cette opération va remplacer la configuration actuelle${NC}"
    echo
    read -p "Êtes-vous sûr de vouloir restaurer? (tapez 'oui' pour confirmer): " -r
    if [[ $REPLY != "oui" ]]; then
        info "Restauration annulée"
        exit 0
    fi
}

# Sauvegarde de sécurité avant restauration
create_safety_backup() {
    info "Création d'une sauvegarde de sécurité..."
    
    local safety_backup="/tmp/pisignage-safety-backup-$TIMESTAMP.tar.gz"
    
    if [[ -d "$BASE_DIR/config" ]]; then
        tar -czf "$safety_backup" -C "$BASE_DIR" config 2>/dev/null || true
        info "Sauvegarde de sécurité: $safety_backup"
    fi
}

# Arrêt des services
stop_services() {
    info "Arrêt des services PiSignage..."
    
    # Arrêt du player
    if [[ -f "$BASE_DIR/scripts/control/stop.sh" ]]; then
        "$BASE_DIR/scripts/control/stop.sh" 2>/dev/null || true
    fi
    
    # Arrêt des processus
    pkill -f "pisignage" 2>/dev/null || true
    pkill -f "chromium.*pisignage" 2>/dev/null || true
    
    success "Services arrêtés"
}

# Extraction de l'archive
extract_backup() {
    info "Extraction de la sauvegarde..."
    
    local temp_dir="/tmp/pisignage-restore-$TIMESTAMP"
    mkdir -p "$temp_dir"
    
    if [[ "$BACKUP_FILE" == *.tar.gz ]]; then
        tar -xzf "$BACKUP_FILE" -C "$temp_dir"
    else
        tar -xf "$BACKUP_FILE" -C "$temp_dir"
    fi
    
    EXTRACT_DIR="$temp_dir"
    success "Archive extraite dans: $EXTRACT_DIR"
}

# Restauration de la configuration
restore_config() {
    info "Restauration de la configuration..."
    
    # Configuration principale
    if [[ -d "$EXTRACT_DIR/config" ]]; then
        mkdir -p "$BASE_DIR/config"
        cp -r "$EXTRACT_DIR/config"/* "$BASE_DIR/config/" 2>/dev/null || true
        success "Configuration principale restaurée"
    fi
    
    # Configuration système (si autorisée)
    if [[ "$RESTORE_CONFIG" == true ]]; then
        # lightdm
        if [[ -f "$EXTRACT_DIR/system/lightdm.conf" ]]; then
            sudo cp "$EXTRACT_DIR/system/lightdm.conf" "/etc/lightdm/" 2>/dev/null || true
            info "Configuration lightdm restaurée"
        fi
        
        # nginx
        if [[ -f "$EXTRACT_DIR/system/pisignage" ]]; then
            sudo cp "$EXTRACT_DIR/system/pisignage" "/etc/nginx/sites-available/" 2>/dev/null || true
            sudo ln -sf "/etc/nginx/sites-available/pisignage" "/etc/nginx/sites-enabled/" 2>/dev/null || true
            info "Configuration nginx restaurée"
        fi
        
        # autostart
        if [[ -f "$EXTRACT_DIR/autostart/pisignage.desktop" ]]; then
            local autostart_dir="/home/pi/.config/autostart"
            mkdir -p "$autostart_dir"
            cp "$EXTRACT_DIR/autostart/pisignage.desktop" "$autostart_dir/" 2>/dev/null || true
            chown pi:pi "$autostart_dir/pisignage.desktop" 2>/dev/null || true
            info "Configuration autostart restaurée"
        fi
    fi
    
    success "Configuration restaurée"
}

# Restauration des playlists
restore_playlists() {
    info "Restauration des playlists..."
    
    if [[ -d "$EXTRACT_DIR/playlists" ]]; then
        mkdir -p "$BASE_DIR/playlists"
        cp -r "$EXTRACT_DIR/playlists"/* "$BASE_DIR/playlists/" 2>/dev/null || true
        success "Playlists restaurées"
    fi
    
    # Base de données
    if [[ -f "$EXTRACT_DIR/data/pisignage.db" ]]; then
        mkdir -p "$BASE_DIR/data"
        cp "$EXTRACT_DIR/data/pisignage.db" "$BASE_DIR/data/" 2>/dev/null || true
        info "Base de données restaurée"
    fi
}

# Restauration des vidéos
restore_videos() {
    if [[ "$RESTORE_VIDEOS" != true ]]; then
        return 0
    fi
    
    info "Restauration des vidéos..."
    
    if [[ -d "$EXTRACT_DIR/videos" ]]; then
        local video_count=$(find "$EXTRACT_DIR/videos" -type f | wc -l)
        
        if [[ $video_count -gt 0 ]]; then
            info "Restauration de $video_count fichiers vidéo..."
            mkdir -p "$BASE_DIR/videos"
            cp -r "$EXTRACT_DIR/videos"/* "$BASE_DIR/videos/" 2>/dev/null || true
            success "Vidéos restaurées"
        else
            warn "Aucune vidéo trouvée dans la sauvegarde"
        fi
    else
        warn "Pas de vidéos dans la sauvegarde"
    fi
}

# Restauration des logs
restore_logs() {
    info "Restauration des logs..."
    
    if [[ -d "$EXTRACT_DIR/logs" ]]; then
        mkdir -p "$BASE_DIR/logs"
        cp -r "$EXTRACT_DIR/logs"/* "$BASE_DIR/logs/" 2>/dev/null || true
        success "Logs restaurés"
    fi
}

# Redémarrage des services
restart_services() {
    info "Redémarrage des services..."
    
    # Nginx
    if [[ "$RESTORE_CONFIG" == true ]]; then
        sudo systemctl restart nginx 2>/dev/null || true
    fi
    
    # PiSignage (optionnel)
    read -p "Redémarrer PiSignage maintenant? (o/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        if [[ -f "$BASE_DIR/scripts/control/start.sh" ]]; then
            "$BASE_DIR/scripts/control/start.sh"
        fi
    fi
}

# Nettoyage
cleanup() {
    info "Nettoyage..."
    
    if [[ -n "${EXTRACT_DIR:-}" && -d "$EXTRACT_DIR" ]]; then
        rm -rf "$EXTRACT_DIR"
    fi
    
    success "Nettoyage terminé"
}

# Affichage final
show_summary() {
    echo
    success "Restauration terminée avec succès!"
    echo
    echo "=== Résumé ==="
    echo "✓ Configuration restaurée"
    echo "✓ Playlists restaurées"
    if [[ "$RESTORE_VIDEOS" == true ]]; then
        echo "✓ Vidéos restaurées"
    else
        echo "✗ Vidéos non restaurées"
    fi
    if [[ "$RESTORE_CONFIG" == true ]]; then
        echo "✓ Configuration système restaurée"
    else
        echo "✗ Configuration système non restaurée"
    fi
    echo
    echo "PiSignage Desktop est prêt à être utilisé!"
}

# Fonction principale
main() {
    echo "=== PiSignage Desktop v3.0 - Restore ==="
    echo
    
    # Parse des arguments
    parse_arguments "$@"
    
    # Validation
    validate_backup_file
    show_backup_info
    confirm_restore
    
    # Préparation
    create_safety_backup
    stop_services
    
    # Restauration
    extract_backup
    restore_config
    restore_playlists
    restore_videos
    restore_logs
    
    # Finalisation
    restart_services
    cleanup
    show_summary
    
    success "Restauration complète!"
}

# Gestion des erreurs
trap 'error "Restauration interrompue"; cleanup; exit 1' ERR

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi