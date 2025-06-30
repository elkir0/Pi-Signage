#!/usr/bin/env bash

# =============================================================================
# Pi Signage - Script de synchronisation Google Drive
# Version: 2.3.0
# Description: Synchronise les vidéos depuis Google Drive via rclone
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly RCLONE_CONFIG="/root/.config/rclone/rclone.conf"
readonly VIDEO_DIR="/opt/videos"
readonly SYNC_LOG="/var/log/pi-signage/sync-$(date +%Y%m%d-%H%M%S).log"
readonly LOCK_FILE="/var/run/pi-signage-sync.lock"
readonly PLAYLIST_UPDATE_SCRIPT="/opt/scripts/update-playlist.sh"

# Variables par défaut
GDRIVE_FOLDER_NAME="Signage"
DRY_RUN=false
VERBOSE=false
DELETE_EXTRA=false

# Charger la configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$SYNC_LOG"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1" | tee -a "$SYNC_LOG"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$SYNC_LOG"
}

log_error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$SYNC_LOG"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$SYNC_LOG"
}

# Vérifier les privilèges root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté avec sudo"
        exit 1
    fi
}

# Afficher l'aide
show_help() {
    echo -e "${BLUE}Pi Signage - Synchronisation Google Drive${NC}"
    echo
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Options:"
    echo "  -d, --dry-run     Mode simulation (affiche les changements sans les appliquer)"
    echo "  -v, --verbose     Mode verbeux"
    echo "  -f, --force       Force la synchronisation même si une autre est en cours"
    echo "  --delete          Supprime les fichiers locaux qui n'existent plus sur Drive"
    echo "  -h, --help        Affiche cette aide"
    echo
    echo "Configuration:"
    echo "  Dossier Drive: $GDRIVE_FOLDER_NAME"
    echo "  Dossier local: $VIDEO_DIR"
}

# Vérifier le verrou
check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "inconnu")
        
        # Vérifier si le processus existe encore
        if [[ "$pid" != "inconnu" ]] && kill -0 "$pid" 2>/dev/null; then
            log_error "Une synchronisation est déjà en cours (PID: $pid)"
            log_info "Utilisez --force pour forcer la synchronisation"
            exit 1
        else
            # Le processus n'existe plus, supprimer le verrou
            log_warning "Verrou obsolète détecté, suppression..."
            rm -f "$LOCK_FILE"
        fi
    fi
}

# Créer le verrou
create_lock() {
    echo $$ > "$LOCK_FILE"
}

# Supprimer le verrou
remove_lock() {
    rm -f "$LOCK_FILE"
}

# Nettoyer en cas d'interruption
cleanup() {
    remove_lock
    exit 0
}

# Vérifier rclone
check_rclone() {
    if ! command -v rclone &> /dev/null; then
        log_error "rclone n'est pas installé"
        log_info "Installation: sudo apt-get install rclone"
        exit 1
    fi
    
    if [[ ! -f "$RCLONE_CONFIG" ]]; then
        log_error "Configuration rclone non trouvée"
        log_info "Configurez rclone avec: sudo rclone config"
        exit 1
    fi
    
    # Vérifier si le remote 'gdrive' existe
    if ! rclone listremotes | grep -q "^gdrive:"; then
        log_error "Remote 'gdrive' non configuré dans rclone"
        log_info "Configurez Google Drive avec: sudo rclone config"
        exit 1
    fi
}

# Vérifier la connexion Google Drive
check_gdrive_connection() {
    log_info "Test de la connexion Google Drive..."
    
    if rclone lsd "gdrive:" --max-depth 1 &>/dev/null; then
        log_success "Connexion Google Drive OK"
        return 0
    else
        log_error "Impossible de se connecter à Google Drive"
        return 1
    fi
}

# Vérifier le dossier source
check_source_folder() {
    log_info "Vérification du dossier '$GDRIVE_FOLDER_NAME' sur Google Drive..."
    
    if rclone lsd "gdrive:" | grep -q " $GDRIVE_FOLDER_NAME$"; then
        log_success "Dossier trouvé sur Google Drive"
        
        # Compter les fichiers
        local file_count=$(rclone ls "gdrive:$GDRIVE_FOLDER_NAME" 2>/dev/null | wc -l || echo "0")
        log_info "Fichiers dans le dossier Drive: $file_count"
        
        return 0
    else
        log_error "Dossier '$GDRIVE_FOLDER_NAME' non trouvé sur Google Drive"
        log_info "Dossiers disponibles:"
        rclone lsd "gdrive:" --max-depth 1 | awk '{print "  • " $5}'
        return 1
    fi
}

# Créer le répertoire local si nécessaire
prepare_local_dir() {
    if [[ ! -d "$VIDEO_DIR" ]]; then
        log_info "Création du répertoire $VIDEO_DIR..."
        mkdir -p "$VIDEO_DIR"
        chown www-data:www-data "$VIDEO_DIR"
        chmod 755 "$VIDEO_DIR"
    fi
}

# Afficher les statistiques avant sync
show_pre_sync_stats() {
    echo
    echo -e "${BLUE}=== État avant synchronisation ===${NC}"
    
    # Espace disque
    local disk_usage=$(df -h "$VIDEO_DIR" | tail -1 | awk '{print "Utilisé: " $3 " / " $2 " (" $5 ")"}')
    echo "Espace disque: $disk_usage"
    
    # Vidéos locales
    local local_count=$(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" \) 2>/dev/null | wc -l)
    local local_size=$(du -sh "$VIDEO_DIR" 2>/dev/null | cut -f1)
    echo "Vidéos locales: $local_count fichiers ($local_size)"
    
    echo
}

# Effectuer la synchronisation
perform_sync() {
    log_info "Début de la synchronisation..."
    
    # Options rclone
    local rclone_opts=(
        "--log-file=$SYNC_LOG"
        "--log-level=INFO"
        "--stats=10s"
        "--stats-one-line"
        "--transfers=4"
        "--checkers=8"
    )
    
    if $VERBOSE; then
        rclone_opts+=("--verbose")
    fi
    
    if $DRY_RUN; then
        rclone_opts+=("--dry-run")
        log_warning "MODE SIMULATION - Aucun fichier ne sera modifié"
    fi
    
    if $DELETE_EXTRA; then
        rclone_opts+=("--delete-during")
        log_warning "Les fichiers locaux supprimés sur Drive seront effacés"
    fi
    
    # Exclure certains fichiers
    rclone_opts+=(
        "--exclude=*.tmp"
        "--exclude=*.part"
        "--exclude=.DS_Store"
        "--exclude=Thumbs.db"
    )
    
    # Lancer la synchronisation
    echo
    if rclone sync "gdrive:$GDRIVE_FOLDER_NAME" "$VIDEO_DIR" "${rclone_opts[@]}"; then
        log_success "Synchronisation terminée avec succès"
        return 0
    else
        log_error "Erreur durant la synchronisation"
        return 1
    fi
}

# Mettre à jour les permissions
fix_permissions() {
    log_info "Mise à jour des permissions..."
    
    chown -R www-data:www-data "$VIDEO_DIR"
    find "$VIDEO_DIR" -type f -exec chmod 644 {} \;
    find "$VIDEO_DIR" -type d -exec chmod 755 {} \;
    
    log_success "Permissions mises à jour"
}

# Afficher les statistiques après sync
show_post_sync_stats() {
    echo
    echo -e "${BLUE}=== État après synchronisation ===${NC}"
    
    # Vidéos synchronisées
    local video_count=$(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" \) 2>/dev/null | wc -l)
    local total_size=$(du -sh "$VIDEO_DIR" 2>/dev/null | cut -f1)
    
    echo "Vidéos synchronisées: $video_count fichiers"
    echo "Taille totale: $total_size"
    
    # Liste des vidéos
    if [[ $video_count -gt 0 ]]; then
        echo
        echo "Vidéos disponibles:"
        find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" \) -printf "%f (%s octets)\n" | sort
    fi
    
    echo
}

# Mettre à jour la playlist (mode Chromium)
update_playlist() {
    if [[ -f "$DISPLAY_MODE_FILE" ]] && [[ "$(cat "$DISPLAY_MODE_FILE")" == "chromium" ]]; then
        if [[ -x "$PLAYLIST_UPDATE_SCRIPT" ]]; then
            log_info "Mise à jour de la playlist Chromium..."
            if "$PLAYLIST_UPDATE_SCRIPT"; then
                log_success "Playlist mise à jour"
            else
                log_warning "Erreur lors de la mise à jour de la playlist"
            fi
        fi
    fi
}

# Fonction principale
main() {
    # Traiter les arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                rm -f "$LOCK_FILE"
                shift
                ;;
            --delete)
                DELETE_EXTRA=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Vérifications préliminaires
    check_root
    
    # Créer le répertoire de logs
    mkdir -p "$(dirname "$SYNC_LOG")"
    
    # Header
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}      Pi Signage - Synchronisation Google Drive               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                   Version 2.3.0                              ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Vérifier le verrou
    check_lock
    
    # Configurer le trap pour nettoyer en cas d'interruption
    trap cleanup EXIT INT TERM
    
    # Créer le verrou
    create_lock
    
    # Vérifications
    check_rclone
    
    if ! check_gdrive_connection; then
        exit 1
    fi
    
    if ! check_source_folder; then
        exit 1
    fi
    
    prepare_local_dir
    
    # Afficher l'état avant
    show_pre_sync_stats
    
    # Synchroniser
    if perform_sync; then
        # Corriger les permissions
        if ! $DRY_RUN; then
            fix_permissions
            
            # Mettre à jour la playlist si nécessaire
            update_playlist
        fi
        
        # Afficher l'état après
        show_post_sync_stats
        
        log_success "Synchronisation complète!"
        echo
        echo "Log complet: $SYNC_LOG"
    else
        log_error "La synchronisation a échoué"
        echo
        echo "Consultez le log pour plus de détails: $SYNC_LOG"
        exit 1
    fi
}

# Exécution
main "$@"