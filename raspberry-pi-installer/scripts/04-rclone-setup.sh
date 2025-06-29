#!/usr/bin/env bash

# =============================================================================
# Module 04 - Installation et Configuration rclone
# Version: 2.0.0
# Description: Installation rclone pour synchronisation Google Drive
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly SYNC_SCRIPT="/opt/scripts/sync-videos.sh"
readonly RCLONE_CONFIG_DIR="/home/signage/.config/rclone"

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
    echo -e "${GREEN}[RCLONE]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[RCLONE]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[RCLONE]${NC} $*" >&2
}

# =============================================================================
# CHARGEMENT DE LA CONFIGURATION
# =============================================================================

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "Configuration chargée"
    else
        log_error "Fichier de configuration introuvable"
        return 1
    fi
}

# =============================================================================
# INSTALLATION DE RCLONE
# =============================================================================

install_rclone() {
    log_info "Installation de rclone..."
    
    # Télécharger et installer la dernière version de rclone
    local temp_dir="/tmp/rclone-install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Détection de l'architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        "armv7l"|"armv6l")
            arch="linux-arm"
            ;;
        "aarch64")
            arch="linux-arm64"
            ;;
        "x86_64")
            arch="linux-amd64"
            ;;
        *)
            log_error "Architecture non supportée: $arch"
            return 1
            ;;
    esac
    
    log_info "Architecture détectée: $arch"
    
    # Téléchargement de rclone
    local rclone_url="https://downloads.rclone.org/rclone-current-${arch}.zip"
    
    if wget -q "$rclone_url" -O rclone.zip; then
        log_info "rclone téléchargé"
    else
        log_error "Échec du téléchargement de rclone"
        return 1
    fi
    
    # Installation d'unzip si nécessaire
    if ! command -v unzip >/dev/null 2>&1; then
        apt-get install -y unzip
    fi
    
    # Extraction et installation
    if unzip -q rclone.zip; then
        local rclone_dir
        rclone_dir=$(find . -name "rclone-*" -type d | head -1)
        
        if [[ -n "$rclone_dir" && -f "$rclone_dir/rclone" ]]; then
            # Installation de l'exécutable
            cp "$rclone_dir/rclone" /usr/local/bin/
            chmod +x /usr/local/bin/rclone
            
            # Installation de la page de manuel
            mkdir -p /usr/local/share/man/man1/
            cp "$rclone_dir/rclone.1" /usr/local/share/man/man1/ 2>/dev/null || true
            
            log_info "rclone installé dans /usr/local/bin/"
        else
            log_error "Fichier rclone introuvable dans l'archive"
            return 1
        fi
    else
        log_error "Échec de l'extraction de l'archive rclone"
        return 1
    fi
    
    # Nettoyage
    cd /
    rm -rf "$temp_dir"
    
    # Vérification de l'installation
    if command -v rclone >/dev/null 2>&1; then
        local rclone_version
        rclone_version=$(rclone version 2>/dev/null | head -1 || echo "Version inconnue")
        log_info "rclone installé: $rclone_version"
    else
        log_error "rclone non disponible après installation"
        return 1
    fi
}

# =============================================================================
# PRÉPARATION DE LA CONFIGURATION RCLONE
# =============================================================================

prepare_rclone_config() {
    log_info "Préparation de la configuration rclone..."
    
    # Créer le répertoire de configuration pour l'utilisateur signage
    mkdir -p "$RCLONE_CONFIG_DIR"
    chown signage:signage "$RCLONE_CONFIG_DIR"
    
    # Créer un fichier de configuration de base
    cat > "$RCLONE_CONFIG_DIR/rclone.conf" << 'EOF'
# Configuration rclone pour Digital Signage
# Le remote Google Drive sera configuré manuellement
EOF
    
    chown signage:signage "$RCLONE_CONFIG_DIR/rclone.conf"
    
    log_info "Répertoire de configuration rclone créé"
}

# =============================================================================
# CRÉATION DU SCRIPT DE SYNCHRONISATION
# =============================================================================

create_sync_script() {
    log_info "Création du script de synchronisation..."
    
    cat > "$SYNC_SCRIPT" << 'EOF'
#!/bin/bash

# =============================================================================
# Script de Synchronisation Google Drive vers Videos Local
# =============================================================================

# Configuration
REMOTE_NAME="gdrive"
GDRIVE_FOLDER="Signage"
LOCAL_VIDEO_DIR="/opt/videos"
LOG_FILE="/var/log/pi-signage/sync.log"
RCLONE_CONFIG="/home/signage/.config/rclone/rclone.conf"

# Chargement de la configuration
if [[ -f "/etc/pi-signage/config.conf" ]]; then
    source "/etc/pi-signage/config.conf"
fi

# Fonction de logging
log_sync() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Fonction de vérification de la connectivité
check_connectivity() {
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_sync "ERREUR: Pas de connexion internet"
        return 1
    fi
    
    if ! rclone --config="$RCLONE_CONFIG" listremotes | grep -q "${REMOTE_NAME}:"; then
        log_sync "ERREUR: Remote Google Drive non configuré"
        return 1
    fi
    
    return 0
}

# Fonction de synchronisation
sync_videos() {
    log_sync "=== Début de synchronisation ==="
    
    # Vérifier la connectivité
    if ! check_connectivity; then
        log_sync "Synchronisation annulée - problème de connectivité"
        return 1
    fi
    
    # Créer le répertoire local s'il n'existe pas
    mkdir -p "$LOCAL_VIDEO_DIR"
    
    # Options de synchronisation rclone
    local rclone_options=(
        "--config=$RCLONE_CONFIG"
        "--verbose"
        "--transfers=2"
        "--checkers=2"
        "--timeout=300s"
        "--retries=3"
        "--low-level-retries=3"
        "--stats=1m"
        "--exclude=.DS_Store"
        "--exclude=Thumbs.db"
        "--exclude=*.tmp"
        "--size-only"
        "--no-traverse"
    )
    
    # Synchronisation depuis Google Drive
    log_sync "Synchronisation depuis ${REMOTE_NAME}:${GDRIVE_FOLDER}/ vers $LOCAL_VIDEO_DIR"
    
    if rclone sync \
        "${rclone_options[@]}" \
        "${REMOTE_NAME}:${GDRIVE_FOLDER}/" \
        "$LOCAL_VIDEO_DIR" \
        2>>"$LOG_FILE"; then
        
        log_sync "Synchronisation réussie"
        
        # Compter les fichiers vidéo
        local video_count
        video_count=$(find "$LOCAL_VIDEO_DIR" -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" | wc -l)
        log_sync "Nombre de vidéos synchronisées: $video_count"
        
        # Notification pour redémarrage VLC si nécessaire
        if systemctl is-active vlc-signage.service >/dev/null 2>&1; then
            log_sync "Redémarrage du service VLC pour prendre en compte les nouvelles vidéos"
            systemctl restart vlc-signage.service
        fi
        
        return 0
    else
        log_sync "ERREUR: Échec de la synchronisation"
        return 1
    fi
}

# Fonction de nettoyage (suppression des fichiers locaux qui ne sont plus sur Drive)
cleanup_local() {
    log_sync "Nettoyage des fichiers locaux obsolètes"
    
    # Cette fonction est optionnelle et peut être activée si nécessaire
    # Pour l'instant, on garde tous les fichiers locaux pour éviter les pertes
    
    log_sync "Nettoyage terminé"
}

# Fonction de vérification de l'espace disque
check_disk_space() {
    local available_space
    available_space=$(df "$LOCAL_VIDEO_DIR" | awk 'NR==2 {print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    log_sync "Espace disque disponible: ${available_gb}GB"
    
    if [[ $available_gb -lt 1 ]]; then
        log_sync "AVERTISSEMENT: Espace disque faible (moins de 1GB)"
        return 1
    fi
    
    return 0
}

# Fonction de rapport de synchronisation
generate_sync_report() {
    local video_count total_size
    
    video_count=$(find "$LOCAL_VIDEO_DIR" -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" | wc -l)
    total_size=$(du -sh "$LOCAL_VIDEO_DIR" 2>/dev/null | cut -f1 || echo "0")
    
    log_sync "=== Rapport de synchronisation ==="
    log_sync "Nombre total de vidéos: $video_count"
    log_sync "Taille totale: $total_size"
    log_sync "Répertoire: $LOCAL_VIDEO_DIR"
    log_sync "Remote Google Drive: ${REMOTE_NAME}:${GDRIVE_FOLDER}/"
}

# Fonction principale
main() {
    # Créer le répertoire de logs
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Vérifier l'espace disque
    if ! check_disk_space; then
        log_sync "Synchronisation annulée - espace disque insuffisant"
        exit 1
    fi
    
    # Effectuer la synchronisation
    if sync_videos; then
        log_sync "Synchronisation terminée avec succès"
        generate_sync_report
        exit 0
    else
        log_sync "Synchronisation échouée"
        exit 1
    fi
}

# Point d'entrée
main "$@"
EOF
    
    # Rendre le script exécutable
    chmod +x "$SYNC_SCRIPT"
    
    log_info "Script de synchronisation créé: $SYNC_SCRIPT"
}

# =============================================================================
# CRÉATION DES SCRIPTS D'AIDE RCLONE
# =============================================================================

create_rclone_helpers() {
    log_info "Création des scripts d'aide rclone..."
    
    # Script de configuration interactive
    cat > "/opt/scripts/setup-gdrive.sh" << 'EOF'
#!/bin/bash

# Script d'aide pour configurer Google Drive avec rclone

echo "=== Configuration Google Drive pour Digital Signage ==="
echo
echo "Ce script va vous aider à configurer l'accès à Google Drive."
echo "Vous aurez besoin :"
echo "  - D'un navigateur web"
echo "  - D'un compte Google"
echo "  - Du nom du dossier Google Drive contenant vos vidéos"
echo
read -p "Appuyez sur Entrée pour continuer..."

# Lancement de la configuration rclone
sudo -u signage rclone config --config=/home/signage/.config/rclone/rclone.conf

echo
echo "Configuration terminée !"
echo "Pour tester la synchronisation, exécutez :"
echo "  sudo /opt/scripts/sync-videos.sh"
EOF
    
    # Script de test de connexion
    cat > "/opt/scripts/test-gdrive.sh" << 'EOF'
#!/bin/bash

# Script de test de la connexion Google Drive

RCLONE_CONFIG="/home/signage/.config/rclone/rclone.conf"
REMOTE_NAME="gdrive"

echo "=== Test de la connexion Google Drive ==="

# Vérifier que rclone est configuré
if ! rclone --config="$RCLONE_CONFIG" listremotes | grep -q "${REMOTE_NAME}:"; then
    echo "ERREUR: Remote 'gdrive' non configuré"
    echo "Exécutez: sudo /opt/scripts/setup-gdrive.sh"
    exit 1
fi

# Tester la connexion
echo "Test de connexion..."
if rclone --config="$RCLONE_CONFIG" lsd "${REMOTE_NAME}:" 2>/dev/null; then
    echo "✓ Connexion Google Drive réussie"
    
    # Vérifier le dossier Signage
    if rclone --config="$RCLONE_CONFIG" lsd "${REMOTE_NAME}:" | grep -q "Signage"; then
        echo "✓ Dossier 'Signage' trouvé"
        
        # Lister les vidéos
        echo
        echo "Vidéos dans le dossier Signage :"
        rclone --config="$RCLONE_CONFIG" ls "${REMOTE_NAME}:Signage/" | grep -E '\.(mp4|avi|mkv|mov)$' || echo "Aucune vidéo trouvée"
    else
        echo "⚠ Dossier 'Signage' non trouvé"
        echo "Créez le dossier 'Signage' dans votre Google Drive et ajoutez-y vos vidéos"
    fi
else
    echo "✗ Échec de la connexion Google Drive"
    echo "Vérifiez votre configuration avec: sudo /opt/scripts/setup-gdrive.sh"
    exit 1
fi
EOF
    
    # Rendre les scripts exécutables
    chmod +x /opt/scripts/setup-gdrive.sh
    chmod +x /opt/scripts/test-gdrive.sh
    
    log_info "Scripts d'aide rclone créés"
}

# =============================================================================
# CONFIGURATION DES PERMISSIONS
# =============================================================================

configure_rclone_permissions() {
    log_info "Configuration des permissions rclone..."
    
    # Permissions sur les répertoires et fichiers
    chown -R signage:signage "$RCLONE_CONFIG_DIR"
    chown signage:signage "$SYNC_SCRIPT"
    
    # Permettre à l'utilisateur signage d'exécuter rclone
    if ! groups signage | grep -q "video"; then
        usermod -a -G video signage
    fi
    
    log_info "Permissions rclone configurées"
}

# =============================================================================
# VALIDATION DE L'INSTALLATION RCLONE
# =============================================================================

validate_rclone_installation() {
    log_info "Validation de l'installation rclone..."
    
    local errors=0
    
    # Vérification de rclone
    if command -v rclone >/dev/null 2>&1; then
        log_info "✓ rclone installé"
    else
        log_error "✗ rclone manquant"
        ((errors++))
    fi
    
    # Vérification du script de synchronisation
    if [[ -f "$SYNC_SCRIPT" && -x "$SYNC_SCRIPT" ]]; then
        log_info "✓ Script de synchronisation créé"
    else
        log_error "✗ Script de synchronisation manquant"
        ((errors++))
    fi
    
    # Vérification du répertoire de configuration
    if [[ -d "$RCLONE_CONFIG_DIR" ]]; then
        log_info "✓ Répertoire de configuration rclone présent"
    else
        log_error "✗ Répertoire de configuration rclone manquant"
        ((errors++))
    fi
    
    # Vérification des scripts d'aide
    if [[ -f "/opt/scripts/setup-gdrive.sh" && -x "/opt/scripts/setup-gdrive.sh" ]]; then
        log_info "✓ Scripts d'aide créés"
    else
        log_error "✗ Scripts d'aide manquants"
        ((errors++))
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Installation rclone ==="
    
    # Chargement de la configuration
    if ! load_config; then
        return 1
    fi
    
    # Étapes d'installation
    local steps=(
        "install_rclone"
        "prepare_rclone_config"
        "create_sync_script"
        "create_rclone_helpers"
        "configure_rclone_permissions"
    )
    
    local failed_steps=()
    
    for step in "${steps[@]}"; do
        log_info "Exécution: $step"
        if ! "$step"; then
            log_error "Échec de l'étape: $step"
            failed_steps+=("$step")
        fi
    done
    
    # Validation
    if validate_rclone_installation; then
        log_info "rclone installé et configuré avec succès"
    else
        log_warn "rclone installé avec des avertissements"
    fi
    
    # Instructions pour la suite
    log_info "Instructions pour configurer Google Drive :"
    log_info "1. Exécutez: sudo /opt/scripts/setup-gdrive.sh"
    log_info "2. Suivez les instructions pour l'authentification OAuth2"
    log_info "3. Testez avec: sudo /opt/scripts/test-gdrive.sh"
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Installation rclone ==="
    return 0
}

# =============================================================================
# EXÉCUTION
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

main "$@"