#!/bin/bash
# PiSignage Desktop v3.0 - Backup Script
# Sauvegarde la configuration et les playlists

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly BACKUP_DIR="/home/pi/pisignage-backups"
readonly TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Variables
INCLUDE_VIDEOS=false
BACKUP_NAME="pisignage_${TIMESTAMP}"
COMPRESSION=true

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
PiSignage Desktop v3.0 - Backup Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Affiche cette aide
    -v, --include-videos Inclure les vidéos dans la sauvegarde
    -n, --name NAME     Nom de la sauvegarde (défaut: pisignage_TIMESTAMP)
    -d, --dir DIR       Répertoire de sauvegarde (défaut: $BACKUP_DIR)
    --no-compression    Pas de compression

Exemples:
    $0                              # Sauvegarde basique
    $0 -v                          # Avec vidéos
    $0 -n "avant-mise-a-jour"      # Nom personnalisé

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
            -v|--include-videos)
                INCLUDE_VIDEOS=true
                shift
                ;;
            -n|--name)
                BACKUP_NAME="$2"
                shift 2
                ;;
            -d|--dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --no-compression)
                COMPRESSION=false
                shift
                ;;
            *)
                error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Préparation de la sauvegarde
prepare_backup() {
    info "Préparation de la sauvegarde..."
    
    # Création du répertoire de sauvegarde
    mkdir -p "$BACKUP_DIR"
    
    # Nom final avec extension
    if [[ "$COMPRESSION" == true ]]; then
        BACKUP_FILE="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    else
        BACKUP_FILE="$BACKUP_DIR/${BACKUP_NAME}.tar"
    fi
    
    info "Fichier de sauvegarde: $BACKUP_FILE"
}

# Sauvegarde de la configuration
backup_config() {
    info "Sauvegarde de la configuration..."
    
    local temp_dir="/tmp/pisignage-backup-$TIMESTAMP"
    mkdir -p "$temp_dir/config"
    
    # Configuration principale
    if [[ -d "$BASE_DIR/config" ]]; then
        cp -r "$BASE_DIR/config"/* "$temp_dir/config/" 2>/dev/null || true
    fi
    
    # Fichiers de configuration système
    local config_files=(
        "/etc/lightdm/lightdm.conf"
        "/etc/nginx/sites-available/pisignage"
    )
    
    mkdir -p "$temp_dir/system"
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            cp "$config_file" "$temp_dir/system/" 2>/dev/null || true
        fi
    done
    
    # Autostart
    local user_config="/home/pi/.config/autostart/pisignage.desktop"
    if [[ -f "$user_config" ]]; then
        mkdir -p "$temp_dir/autostart"
        cp "$user_config" "$temp_dir/autostart/"
    fi
    
    success "Configuration sauvegardée"
}

# Sauvegarde des playlists
backup_playlists() {
    info "Sauvegarde des playlists..."
    
    local temp_dir="/tmp/pisignage-backup-$TIMESTAMP"
    
    # Playlists locales
    if [[ -d "$BASE_DIR/playlists" ]]; then
        mkdir -p "$temp_dir/playlists"
        cp -r "$BASE_DIR/playlists"/* "$temp_dir/playlists/" 2>/dev/null || true
    fi
    
    # Base de données (si présente)
    if [[ -f "$BASE_DIR/data/pisignage.db" ]]; then
        mkdir -p "$temp_dir/data"
        cp "$BASE_DIR/data/pisignage.db" "$temp_dir/data/"
    fi
    
    success "Playlists sauvegardées"
}

# Sauvegarde des vidéos (optionnel)
backup_videos() {
    if [[ "$INCLUDE_VIDEOS" != true ]]; then
        return 0
    fi
    
    info "Sauvegarde des vidéos..."
    
    local temp_dir="/tmp/pisignage-backup-$TIMESTAMP"
    
    if [[ -d "$BASE_DIR/videos" ]]; then
        local video_count=$(find "$BASE_DIR/videos" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" -o -name "*.webm" \) | wc -l)
        
        if [[ $video_count -gt 0 ]]; then
            info "Sauvegarde de $video_count vidéos..."
            mkdir -p "$temp_dir/videos"
            cp -r "$BASE_DIR/videos"/* "$temp_dir/videos/" 2>/dev/null || true
            success "Vidéos sauvegardées"
        else
            warn "Aucune vidéo trouvée"
        fi
    else
        warn "Répertoire vidéos non trouvé"
    fi
}

# Sauvegarde des logs
backup_logs() {
    info "Sauvegarde des logs..."
    
    local temp_dir="/tmp/pisignage-backup-$TIMESTAMP"
    
    if [[ -d "$BASE_DIR/logs" ]]; then
        mkdir -p "$temp_dir/logs"
        
        # Logs récents seulement (7 derniers jours)
        find "$BASE_DIR/logs" -name "*.log" -mtime -7 -exec cp {} "$temp_dir/logs/" \; 2>/dev/null || true
    fi
    
    success "Logs sauvegardés"
}

# Métadonnées de sauvegarde
create_metadata() {
    info "Création des métadonnées..."
    
    local temp_dir="/tmp/pisignage-backup-$TIMESTAMP"
    local metadata_file="$temp_dir/backup_info.txt"
    
    cat > "$metadata_file" << EOF
PiSignage Desktop v3.0 - Backup Information
===========================================

Date de sauvegarde: $(date)
Hostname: $(hostname)
Version PiSignage: $(cat "$BASE_DIR/VERSION" 2>/dev/null || echo "Inconnue")
Utilisateur: $(whoami)
IP Address: $(hostname -I | awk '{print $1}')

Contenu:
- Configuration: Oui
- Playlists: Oui
- Logs: Oui (7 derniers jours)
- Vidéos: $(if [[ "$INCLUDE_VIDEOS" == true ]]; then echo "Oui"; else echo "Non"; fi)

Répertoires sauvegardés:
$(find "$temp_dir" -type d | sed 's|^/tmp/pisignage-backup-[0-9_]*||' | sort)

Taille totale: $(du -sh "$temp_dir" | cut -f1)
EOF
    
    success "Métadonnées créées"
}

# Création de l'archive
create_archive() {
    info "Création de l'archive..."
    
    local temp_dir="/tmp/pisignage-backup-$TIMESTAMP"
    
    cd "$temp_dir"
    
    if [[ "$COMPRESSION" == true ]]; then
        tar -czf "$BACKUP_FILE" .
    else
        tar -cf "$BACKUP_FILE" .
    fi
    
    # Nettoyage du répertoire temporaire
    rm -rf "$temp_dir"
    
    success "Archive créée: $BACKUP_FILE"
}

# Vérification de l'archive
verify_backup() {
    info "Vérification de l'archive..."
    
    if [[ "$COMPRESSION" == true ]]; then
        if tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
            success "Archive valide"
        else
            error "Archive corrompue"
            exit 1
        fi
    else
        if tar -tf "$BACKUP_FILE" > /dev/null 2>&1; then
            success "Archive valide"
        else
            error "Archive corrompue"
            exit 1
        fi
    fi
    
    # Informations sur l'archive
    local file_size=$(du -h "$BACKUP_FILE" | cut -f1)
    local file_count
    
    if [[ "$COMPRESSION" == true ]]; then
        file_count=$(tar -tzf "$BACKUP_FILE" | wc -l)
    else
        file_count=$(tar -tf "$BACKUP_FILE" | wc -l)
    fi
    
    info "Taille: $file_size"
    info "Fichiers: $file_count"
}

# Affichage final
show_summary() {
    echo
    success "Sauvegarde terminée avec succès!"
    echo
    echo "=== Résumé ==="
    echo "Fichier: $BACKUP_FILE"
    echo "Taille: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo "Date: $(date)"
    echo
    echo "=== Contenu ==="
    echo "✓ Configuration"
    echo "✓ Playlists"
    echo "✓ Logs (7 derniers jours)"
    if [[ "$INCLUDE_VIDEOS" == true ]]; then
        echo "✓ Vidéos"
    else
        echo "✗ Vidéos (non incluses)"
    fi
    echo
    echo "Pour restaurer:"
    echo "$BASE_DIR/scripts/utils/restore.sh $BACKUP_FILE"
}

# Fonction principale
main() {
    echo "=== PiSignage Desktop v3.0 - Backup ==="
    echo
    
    # Parse des arguments
    parse_arguments "$@"
    
    # Vérifications
    if [[ ! -d "$BASE_DIR" ]]; then
        error "Répertoire PiSignage non trouvé: $BASE_DIR"
        exit 1
    fi
    
    # Sauvegarde
    prepare_backup
    backup_config
    backup_playlists
    backup_videos
    backup_logs
    create_metadata
    create_archive
    verify_backup
    show_summary
    
    success "Sauvegarde complète!"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi