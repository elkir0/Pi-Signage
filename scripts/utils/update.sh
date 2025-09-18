#!/bin/bash
# PiSignage Desktop v3.0 - Update Script
# Met à jour PiSignage Desktop

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly REPO_URL="https://github.com/elkir0/pisignage-desktop"
readonly BACKUP_DIR="/tmp/pisignage-update-backup"
readonly TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Variables
FORCE=false
BACKUP_BEFORE=true
CHECK_ONLY=false
BRANCH="main"

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
PiSignage Desktop v3.0 - Update Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Affiche cette aide
    -f, --force         Force la mise à jour sans confirmation
    -c, --check         Vérifie seulement les mises à jour disponibles
    --no-backup         Pas de sauvegarde avant mise à jour
    -b, --branch BRANCH Branche à utiliser (défaut: main)

Exemples:
    $0                  # Vérification et mise à jour interactive
    $0 -c               # Vérification seulement
    $0 -f               # Mise à jour forcée

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
            -c|--check)
                CHECK_ONLY=true
                shift
                ;;
            --no-backup)
                BACKUP_BEFORE=false
                shift
                ;;
            -b|--branch)
                BRANCH="$2"
                shift 2
                ;;
            *)
                error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Vérification des prérequis
check_prerequisites() {
    info "Vérification des prérequis..."
    
    # Git requis
    if ! command -v git &> /dev/null; then
        error "Git requis pour la mise à jour"
        exit 1
    fi
    
    # Connexion internet
    if ! ping -c 1 google.com &> /dev/null; then
        error "Connexion internet requise"
        exit 1
    fi
    
    # Droits d'écriture
    if [[ ! -w "$BASE_DIR" ]]; then
        error "Droits d'écriture requis sur $BASE_DIR"
        exit 1
    fi
    
    success "Prérequis validés"
}

# Obtention de la version actuelle
get_current_version() {
    if [[ -f "$BASE_DIR/VERSION" ]]; then
        CURRENT_VERSION=$(cat "$BASE_DIR/VERSION")
    else
        CURRENT_VERSION="Inconnue"
    fi
    
    info "Version actuelle: $CURRENT_VERSION"
}

# Vérification des mises à jour disponibles
check_updates() {
    info "Vérification des mises à jour..."
    
    local temp_dir="/tmp/pisignage-update-check-$TIMESTAMP"
    mkdir -p "$temp_dir"
    
    # Clone superficiel pour récupérer la dernière version
    if ! git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$temp_dir" &>/dev/null; then
        error "Impossible de récupérer les informations de mise à jour"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    if [[ -f "$temp_dir/VERSION" ]]; then
        LATEST_VERSION=$(cat "$temp_dir/VERSION")
    else
        LATEST_VERSION="Inconnue"
    fi
    
    rm -rf "$temp_dir"
    
    info "Version disponible: $LATEST_VERSION"
    
    # Comparaison des versions
    if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
        success "PiSignage Desktop est à jour!"
        if [[ "$CHECK_ONLY" == true ]]; then
            exit 0
        fi
    else
        warn "Mise à jour disponible: $CURRENT_VERSION → $LATEST_VERSION"
    fi
}

# Affichage du changelog
show_changelog() {
    info "Récupération du changelog..."
    
    local temp_dir="/tmp/pisignage-changelog-$TIMESTAMP"
    mkdir -p "$temp_dir"
    
    if git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$temp_dir" &>/dev/null; then
        if [[ -f "$temp_dir/CHANGELOG.md" ]]; then
            echo
            echo "=== Nouveautés ==="
            head -n 20 "$temp_dir/CHANGELOG.md"
            echo
        fi
    fi
    
    rm -rf "$temp_dir"
}

# Confirmation de mise à jour
confirm_update() {
    if [[ "$FORCE" == true || "$CHECK_ONLY" == true ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}Mettre à jour PiSignage Desktop?${NC}"
    echo "Version actuelle: $CURRENT_VERSION"
    echo "Nouvelle version: $LATEST_VERSION"
    echo
    read -p "Continuer? (o/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        info "Mise à jour annulée"
        exit 0
    fi
}

# Sauvegarde avant mise à jour
create_backup() {
    if [[ "$BACKUP_BEFORE" != true ]]; then
        return 0
    fi
    
    info "Création d'une sauvegarde..."
    
    if [[ -f "$BASE_DIR/scripts/utils/backup.sh" ]]; then
        "$BASE_DIR/scripts/utils/backup.sh" -n "before-update-$TIMESTAMP" -d "$BACKUP_DIR"
        success "Sauvegarde créée"
    else
        warn "Script de sauvegarde non trouvé, sauvegarde manuelle..."
        mkdir -p "$BACKUP_DIR"
        tar -czf "$BACKUP_DIR/pisignage-backup-$TIMESTAMP.tar.gz" -C "$(dirname "$BASE_DIR")" "$(basename "$BASE_DIR")"
        info "Sauvegarde manuelle: $BACKUP_DIR/pisignage-backup-$TIMESTAMP.tar.gz"
    fi
}

# Arrêt des services
stop_services() {
    info "Arrêt des services..."
    
    if [[ -f "$BASE_DIR/scripts/control/stop.sh" ]]; then
        "$BASE_DIR/scripts/control/stop.sh" 2>/dev/null || true
    fi
    
    # Arrêt des processus
    pkill -f "pisignage" 2>/dev/null || true
    pkill -f "chromium.*pisignage" 2>/dev/null || true
    
    success "Services arrêtés"
}

# Téléchargement de la mise à jour
download_update() {
    info "Téléchargement de la mise à jour..."
    
    local temp_dir="/tmp/pisignage-update-$TIMESTAMP"
    mkdir -p "$temp_dir"
    
    # Clone de la nouvelle version
    if ! git clone --branch "$BRANCH" "$REPO_URL" "$temp_dir/pisignage-desktop"; then
        error "Échec du téléchargement"
        exit 1
    fi
    
    UPDATE_DIR="$temp_dir/pisignage-desktop"
    success "Mise à jour téléchargée"
}

# Application de la mise à jour
apply_update() {
    info "Application de la mise à jour..."
    
    # Sauvegarde des fichiers utilisateur
    local user_files=(
        "config"
        "videos"
        "playlists"
        "logs"
        "data"
    )
    
    local temp_user_dir="/tmp/pisignage-user-data-$TIMESTAMP"
    mkdir -p "$temp_user_dir"
    
    for file in "${user_files[@]}"; do
        if [[ -d "$BASE_DIR/$file" ]]; then
            cp -r "$BASE_DIR/$file" "$temp_user_dir/" 2>/dev/null || true
        fi
    done
    
    # Suppression de l'ancienne installation (sauf données utilisateur)
    find "$BASE_DIR" -mindepth 1 -maxdepth 1 ! -name "config" ! -name "videos" ! -name "playlists" ! -name "logs" ! -name "data" -exec rm -rf {} + 2>/dev/null || true
    
    # Copie de la nouvelle version
    cp -r "$UPDATE_DIR"/* "$BASE_DIR/"
    
    # Restauration des données utilisateur
    for file in "${user_files[@]}"; do
        if [[ -d "$temp_user_dir/$file" ]]; then
            mkdir -p "$BASE_DIR/$file"
            cp -r "$temp_user_dir/$file"/* "$BASE_DIR/$file/" 2>/dev/null || true
        fi
    done
    
    # Droits d'exécution
    chmod +x "$BASE_DIR"/*.sh 2>/dev/null || true
    chmod +x "$BASE_DIR"/scripts/*/*.sh 2>/dev/null || true
    
    # Nettoyage
    rm -rf "$temp_user_dir"
    rm -rf "$(dirname "$UPDATE_DIR")"
    
    success "Mise à jour appliquée"
}

# Post-traitement de la mise à jour
post_update() {
    info "Post-traitement..."
    
    # Exécution du script de post-update si présent
    if [[ -f "$BASE_DIR/scripts/post-update.sh" ]]; then
        info "Exécution du script post-update..."
        "$BASE_DIR/scripts/post-update.sh" 2>/dev/null || true
    fi
    
    # Mise à jour des dépendances si nécessaire
    if [[ -f "$BASE_DIR/web/package.json" ]]; then
        info "Mise à jour des dépendances web..."
        cd "$BASE_DIR/web"
        npm install --production 2>/dev/null || true
    fi
    
    success "Post-traitement terminé"
}

# Redémarrage des services
restart_services() {
    info "Redémarrage des services..."
    
    # Nginx
    sudo systemctl restart nginx 2>/dev/null || true
    
    # PiSignage
    read -p "Redémarrer PiSignage maintenant? (o/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        if [[ -f "$BASE_DIR/scripts/control/start.sh" ]]; then
            "$BASE_DIR/scripts/control/start.sh"
        fi
    fi
}

# Vérification post-mise à jour
verify_update() {
    info "Vérification de la mise à jour..."
    
    # Vérification de la nouvelle version
    if [[ -f "$BASE_DIR/VERSION" ]]; then
        local new_version=$(cat "$BASE_DIR/VERSION")
        if [[ "$new_version" == "$LATEST_VERSION" ]]; then
            success "Mise à jour réussie: $new_version"
        else
            warn "Version inattendue: $new_version (attendue: $LATEST_VERSION)"
        fi
    fi
    
    # Test des scripts principaux
    local scripts_ok=true
    local test_scripts=(
        "$BASE_DIR/scripts/control/status.sh"
        "$BASE_DIR/scripts/control/start.sh"
        "$BASE_DIR/scripts/control/stop.sh"
    )
    
    for script in "${test_scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            warn "Script non exécutable: $script"
            scripts_ok=false
        fi
    done
    
    if [[ "$scripts_ok" == true ]]; then
        success "Scripts vérifiés"
    fi
}

# Affichage final
show_summary() {
    echo
    success "Mise à jour terminée avec succès!"
    echo
    echo "=== Résumé ==="
    echo "Version précédente: $CURRENT_VERSION"
    echo "Version actuelle: $(cat "$BASE_DIR/VERSION" 2>/dev/null || echo "Inconnue")"
    echo "Date: $(date)"
    echo
    if [[ "$BACKUP_BEFORE" == true ]]; then
        echo "Sauvegarde: $BACKUP_DIR"
    fi
    echo
    echo "PiSignage Desktop est maintenant à jour!"
}

# Fonction principale
main() {
    echo "=== PiSignage Desktop v3.0 - Update ==="
    echo
    
    # Parse des arguments
    parse_arguments "$@"
    
    # Vérifications
    check_prerequisites
    get_current_version
    check_updates
    
    if [[ "$CHECK_ONLY" == true ]]; then
        exit 0
    fi
    
    show_changelog
    confirm_update
    
    # Mise à jour
    create_backup
    stop_services
    download_update
    apply_update
    post_update
    restart_services
    verify_update
    show_summary
    
    success "Mise à jour complète!"
}

# Gestion des erreurs
trap 'error "Mise à jour interrompue"; exit 1' ERR

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi