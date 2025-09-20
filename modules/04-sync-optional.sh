#!/bin/bash
# =============================================================================
# Module 04: Synchronisation Cloud (Optionnel) - PiSignage Desktop v3.0
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
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[SYNC-CLOUD] $1"
    fi
}

# Vérifier si l'utilisateur veut installer la sync
check_user_preference() {
    echo ""
    echo -e "${BLUE}Module de synchronisation cloud (optionnel)${NC}"
    echo "Permet de synchroniser vos vidéos avec Google Drive, Dropbox, OneDrive, etc."
    echo ""
    
    read -p "Voulez-vous configurer la synchronisation cloud? [o/N]: " install_sync
    install_sync=${install_sync:-N}
    
    if [[ ! "${install_sync,,}" =~ ^(o|oui|y|yes)$ ]]; then
        echo -e "${YELLOW}⚠ Synchronisation cloud ignorée${NC}"
        return 1
    fi
    
    return 0
}

# Installation rclone
install_rclone() {
    log "Installation de rclone..."
    
    # Vérifier si déjà installé
    if command -v rclone &>/dev/null; then
        echo -e "${GREEN}✓ rclone déjà installé ($(rclone version | head -n1))${NC}"
        return 0
    fi
    
    # Installation via script officiel
    curl https://rclone.org/install.sh | sudo bash
    
    if command -v rclone &>/dev/null; then
        echo -e "${GREEN}✓ rclone installé avec succès${NC}"
    else
        echo -e "${RED}✗ Échec de l'installation de rclone${NC}"
        return 1
    fi
}

# Configuration interactive du cloud
configure_cloud_service() {
    log "Configuration du service cloud..."
    
    echo ""
    echo "Services cloud supportés:"
    echo "  1) Google Drive"
    echo "  2) Dropbox"
    echo "  3) OneDrive"
    echo "  4) Amazon S3"
    echo "  5) FTP/SFTP"
    echo "  6) Autre (configuration manuelle)"
    echo ""
    
    read -p "Choisissez votre service [1-6]: " service_choice
    
    case $service_choice in
        1) SERVICE_NAME="gdrive" ; SERVICE_TYPE="drive" ;;
        2) SERVICE_NAME="dropbox" ; SERVICE_TYPE="dropbox" ;;
        3) SERVICE_NAME="onedrive" ; SERVICE_TYPE="onedrive" ;;
        4) SERVICE_NAME="s3" ; SERVICE_TYPE="s3" ;;
        5) SERVICE_NAME="ftp" ; SERVICE_TYPE="ftp" ;;
        *) SERVICE_NAME="remote" ; SERVICE_TYPE="" ;;
    esac
    
    echo ""
    echo -e "${YELLOW}Configuration interactive de rclone${NC}"
    echo "Suivez les instructions pour configurer votre service cloud."
    echo ""
    
    # Configuration interactive rclone
    sudo -u "$USER" rclone config create "$SERVICE_NAME" "$SERVICE_TYPE"
    
    # Vérifier la configuration
    if sudo -u "$USER" rclone listremotes | grep -q "$SERVICE_NAME:"; then
        echo -e "${GREEN}✓ Service cloud '$SERVICE_NAME' configuré${NC}"
        
        # Sauvegarder le nom du service
        echo "$SERVICE_NAME" > "$BASE_DIR/config/cloud_service.conf"
    else
        echo -e "${RED}✗ Échec de la configuration du service cloud${NC}"
        return 1
    fi
}

# Créer script de synchronisation
create_sync_script() {
    log "Création du script de synchronisation..."
    
    cat > "$BASE_DIR/scripts/sync-media.sh" << 'EOF'
#!/bin/bash
#
# Script de synchronisation cloud pour PiSignage Desktop v3.0
#

BASE_DIR="/opt/pisignage"
LOCAL_DIR="$BASE_DIR/videos"
CONFIG_FILE="$BASE_DIR/config/cloud_service.conf"
LOG_FILE="$BASE_DIR/logs/sync.log"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Lire la configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Erreur: Service cloud non configuré${NC}"
    exit 1
fi

SERVICE_NAME=$(cat "$CONFIG_FILE")
REMOTE_DIR="${SERVICE_NAME}:pisignage"

# Fonction de log
log_sync() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Fonction de synchronisation complète
sync_full() {
    log_sync "Démarrage synchronisation complète..."
    
    # Sync bidirectionnelle
    rclone sync "$REMOTE_DIR" "$LOCAL_DIR" \
        --progress \
        --exclude "*.tmp" \
        --exclude ".*" \
        --log-file="$LOG_FILE" \
        --log-level INFO
    
    if [[ $? -eq 0 ]]; then
        log_sync "✓ Synchronisation complète terminée"
        echo -e "${GREEN}✓ Synchronisation réussie${NC}"
    else
        log_sync "✗ Erreur lors de la synchronisation"
        echo -e "${RED}✗ Échec de la synchronisation${NC}"
        return 1
    fi
}

# Fonction de synchronisation rapide (nouveaux fichiers seulement)
sync_quick() {
    log_sync "Démarrage synchronisation rapide..."
    
    # Copier seulement les nouveaux fichiers
    rclone copy "$REMOTE_DIR" "$LOCAL_DIR" \
        --update \
        --exclude "*.tmp" \
        --exclude ".*" \
        --log-file="$LOG_FILE" \
        --log-level INFO
    
    if [[ $? -eq 0 ]]; then
        log_sync "✓ Synchronisation rapide terminée"
        echo -e "${GREEN}✓ Nouveaux fichiers synchronisés${NC}"
    else
        log_sync "✗ Erreur lors de la synchronisation"
        echo -e "${RED}✗ Échec de la synchronisation${NC}"
        return 1
    fi
}

# Fonction de restauration
sync_restore() {
    log_sync "Restauration depuis le cloud..."
    
    read -p "⚠️ Cela va écraser les fichiers locaux. Continuer? [o/N]: " confirm
    if [[ ! "${confirm,,}" =~ ^(o|oui|y|yes)$ ]]; then
        echo "Restauration annulée"
        return 1
    fi
    
    rclone sync "$REMOTE_DIR" "$LOCAL_DIR" \
        --progress \
        --log-file="$LOG_FILE" \
        --log-level INFO
    
    if [[ $? -eq 0 ]]; then
        log_sync "✓ Restauration terminée"
        echo -e "${GREEN}✓ Fichiers restaurés depuis le cloud${NC}"
    else
        log_sync "✗ Erreur lors de la restauration"
        echo -e "${RED}✗ Échec de la restauration${NC}"
        return 1
    fi
}

# Fonction de status
sync_status() {
    echo "=== Status de synchronisation ==="
    echo "Service: $SERVICE_NAME"
    echo "Dossier local: $LOCAL_DIR"
    echo "Dossier distant: $REMOTE_DIR"
    echo ""
    
    # Compter les fichiers
    LOCAL_COUNT=$(find "$LOCAL_DIR" -type f -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" 2>/dev/null | wc -l)
    echo "Fichiers locaux: $LOCAL_COUNT"
    
    # Lister les fichiers distants
    echo "Vérification du cloud..."
    REMOTE_COUNT=$(rclone ls "$REMOTE_DIR" 2>/dev/null | wc -l)
    echo "Fichiers distants: $REMOTE_COUNT"
    
    # Dernière sync
    if [[ -f "$LOG_FILE" ]]; then
        LAST_SYNC=$(grep "Synchronisation.*terminée" "$LOG_FILE" | tail -n1 | cut -d']' -f1 | tr -d '[')
        echo "Dernière sync: ${LAST_SYNC:-Jamais}"
    fi
}

# Menu principal
case "${1:-status}" in
    full)
        sync_full
        ;;
    quick)
        sync_quick
        ;;
    restore)
        sync_restore
        ;;
    status)
        sync_status
        ;;
    *)
        echo "Usage: $0 {full|quick|restore|status}"
        echo ""
        echo "  full    - Synchronisation bidirectionnelle complète"
        echo "  quick   - Télécharge seulement les nouveaux fichiers"
        echo "  restore - Restaure tous les fichiers depuis le cloud"
        echo "  status  - Affiche le status de synchronisation"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$BASE_DIR/scripts/sync-media.sh"
    
    # Créer lien symbolique
    sudo ln -sf "$BASE_DIR/scripts/sync-media.sh" /usr/local/bin/pisignage-sync
    
    echo -e "${GREEN}✓ Script de synchronisation créé${NC}"
}

# Configuration cron pour synchronisation automatique
configure_cron() {
    log "Configuration de la synchronisation automatique..."
    
    echo ""
    echo "Fréquence de synchronisation:"
    echo "  1) Toutes les heures"
    echo "  2) Toutes les 6 heures"
    echo "  3) Une fois par jour"
    echo "  4) Manuel uniquement"
    echo ""
    
    read -p "Choisissez la fréquence [1-4]: " freq_choice
    
    case $freq_choice in
        1) CRON_SCHEDULE="0 * * * *" ; FREQ_DESC="toutes les heures" ;;
        2) CRON_SCHEDULE="0 */6 * * *" ; FREQ_DESC="toutes les 6 heures" ;;
        3) CRON_SCHEDULE="0 2 * * *" ; FREQ_DESC="tous les jours à 2h" ;;
        4) CRON_SCHEDULE="" ; FREQ_DESC="manuel uniquement" ;;
        *) CRON_SCHEDULE="0 */6 * * *" ; FREQ_DESC="toutes les 6 heures" ;;
    esac
    
    if [[ -n "$CRON_SCHEDULE" ]]; then
        # Ajouter au crontab de l'utilisateur pisignage
        (sudo -u "$USER" crontab -l 2>/dev/null || true; echo "$CRON_SCHEDULE $BASE_DIR/scripts/sync-media.sh quick >> $BASE_DIR/logs/sync.log 2>&1") | sudo -u "$USER" crontab -
        
        echo -e "${GREEN}✓ Synchronisation automatique configurée ($FREQ_DESC)${NC}"
    else
        echo -e "${YELLOW}⚠ Synchronisation manuelle uniquement${NC}"
    fi
}

# Test de connexion
test_cloud_connection() {
    log "Test de connexion au service cloud..."
    
    SERVICE_NAME=$(cat "$BASE_DIR/config/cloud_service.conf" 2>/dev/null || echo "")
    
    if [[ -z "$SERVICE_NAME" ]]; then
        echo -e "${RED}✗ Service cloud non configuré${NC}"
        return 1
    fi
    
    echo -n "Test de connexion à $SERVICE_NAME... "
    
    if sudo -u "$USER" rclone lsd "${SERVICE_NAME}:" &>/dev/null; then
        echo -e "${GREEN}✓ Connexion réussie${NC}"
        
        # Créer le dossier pisignage si nécessaire
        sudo -u "$USER" rclone mkdir "${SERVICE_NAME}:pisignage" 2>/dev/null || true
        
        # Test d'upload
        echo "Test" > /tmp/test_pisignage.txt
        if sudo -u "$USER" rclone copy /tmp/test_pisignage.txt "${SERVICE_NAME}:pisignage/" 2>/dev/null; then
            echo -e "${GREEN}✓ Test d'upload réussi${NC}"
            sudo -u "$USER" rclone delete "${SERVICE_NAME}:pisignage/test_pisignage.txt" 2>/dev/null
        fi
        rm -f /tmp/test_pisignage.txt
        
        return 0
    else
        echo -e "${RED}✗ Échec de connexion${NC}"
        return 1
    fi
}

# Main
main() {
    echo "Module 4: Synchronisation Cloud (Optionnel)"
    echo "============================================"
    
    # Vérifier si l'utilisateur veut la sync
    if ! check_user_preference; then
        echo ""
        echo -e "${YELLOW}Module de synchronisation ignoré${NC}"
        return 0
    fi
    
    install_rclone
    configure_cloud_service
    create_sync_script
    configure_cron
    test_cloud_connection
    
    echo ""
    echo -e "${GREEN}✓ Module de synchronisation cloud terminé${NC}"
    echo "  Commande: pisignage-sync {full|quick|restore|status}"
    
    return 0
}

# Exécution
main "$@"