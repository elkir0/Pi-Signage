#!/usr/bin/env bash

# =============================================================================
# Patch de compatibilité YouTube -> Chromium Kiosk
# Version: 1.0.0
# Description: Modifie yt-dlp pour télécharger en H.264 compatible Chromium
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() {
    echo -e "${GREEN}[PATCH]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[PATCH]${NC} $*"
}

log_error() {
    echo -e "${RED}[PATCH]${NC} $*" >&2
}

# =============================================================================
# CRÉATION DU WRAPPER YT-DLP CHROMIUM
# =============================================================================

create_ytdlp_wrapper() {
    log_info "Création du wrapper yt-dlp pour compatibilité Chromium..."
    
    cat > /usr/local/bin/yt-dlp-chromium << 'EOF'
#!/usr/bin/env bash

# Wrapper yt-dlp pour compatibilité Chromium Kiosk
# Force le téléchargement en H.264/MP4

# Arguments originaux
ARGS=("$@")

# Extraire la qualité demandée
QUALITY=""
OUTPUT=""
URL=""
OTHER_ARGS=()

i=0
while [[ $i -lt ${#ARGS[@]} ]]; do
    case "${ARGS[$i]}" in
        -f|--format)
            # Ignorer le format original, on va le remplacer
            ((i++))
            if [[ "${ARGS[$i]}" =~ ([0-9]+)p ]]; then
                QUALITY="${BASH_REMATCH[1]}"
            fi
            ;;
        -o|--output)
            ((i++))
            OUTPUT="${ARGS[$i]}"
            ;;
        http*|www.*)
            URL="${ARGS[$i]}"
            ;;
        *)
            OTHER_ARGS+=("${ARGS[$i]}")
            ;;
    esac
    ((i++))
done

# Construire le format compatible Chromium
case "$QUALITY" in
    480)
        FORMAT="best[height<=480][ext=mp4]/best[height<=480][vcodec^=avc]/bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[height<=480]"
        ;;
    720)
        FORMAT="best[height<=720][ext=mp4]/best[height<=720][vcodec^=avc]/bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720]"
        ;;
    1080)
        FORMAT="best[height<=1080][ext=mp4]/best[height<=1080][vcodec^=avc]/bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080]"
        ;;
    *)
        # Par défaut, 720p H.264
        FORMAT="best[height<=720][ext=mp4]/best[height<=720][vcodec^=avc]/bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best"
        ;;
esac

# Options supplémentaires pour compatibilité
CHROMIUM_OPTS=(
    # Préférer H.264
    "--recode-video" "mp4"
    # Merge en MP4
    "--merge-output-format" "mp4"
    # Préférer les codecs compatibles
    "--prefer-free-formats"
    # Post-processing pour s'assurer de la compatibilité
    "--postprocessor-args" "-c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -movflags +faststart"
)

# Logger le format utilisé
echo "[YT-DLP-CHROMIUM] Format: $FORMAT" >&2
echo "[YT-DLP-CHROMIUM] Qualité demandée: ${QUALITY:-auto}" >&2

# Construire la commande finale
CMD=(yt-dlp -f "$FORMAT" "${CHROMIUM_OPTS[@]}")

# Ajouter output si spécifié
if [[ -n "$OUTPUT" ]]; then
    CMD+=(-o "$OUTPUT")
fi

# Ajouter les autres arguments
CMD+=("${OTHER_ARGS[@]}")

# Ajouter l'URL
if [[ -n "$URL" ]]; then
    CMD+=("$URL")
fi

# Exécuter
echo "[YT-DLP-CHROMIUM] Commande: ${CMD[*]}" >&2
exec "${CMD[@]}"
EOF

    chmod +x /usr/local/bin/yt-dlp-chromium
    log_info "Wrapper yt-dlp-chromium créé"
}

# =============================================================================
# PATCH DE L'INTERFACE WEB
# =============================================================================

patch_web_interface() {
    log_info "Patch de l'interface web pour utiliser le wrapper..."
    
    local config_file="/var/www/pi-signage/includes/config.php"
    
    if [[ -f "$config_file" ]]; then
        # Sauvegarder
        cp "$config_file" "${config_file}.bak-chromium"
        
        # Remplacer yt-dlp par yt-dlp-chromium si mode Chromium détecté
        if grep -q "DISPLAY_MODE.*chromium" /etc/pi-signage/config.conf 2>/dev/null; then
            sed -i "s|define('YTDLP_BIN', '/usr/local/bin/yt-dlp');|define('YTDLP_BIN', '/usr/local/bin/yt-dlp-chromium');|g" "$config_file"
            log_info "Configuration web patchée pour Chromium"
        else
            log_info "Mode VLC détecté, pas de patch nécessaire"
        fi
    else
        log_warn "Fichier de configuration web non trouvé, patch ignoré"
    fi
}

# =============================================================================
# SCRIPT DE CONVERSION DES VIDÉOS EXISTANTES
# =============================================================================

create_conversion_script() {
    log_info "Création du script de conversion des vidéos existantes..."
    
    cat > /opt/scripts/convert-videos-chromium.sh << 'EOF'
#!/usr/bin/env bash

# Script de conversion des vidéos pour compatibilité Chromium
# Convertit toutes les vidéos non-H.264 en MP4/H.264

VIDEO_DIR="/opt/videos"
LOG_FILE="/var/log/pi-signage/video-conversion.log"

echo "=== Conversion des vidéos pour Chromium ===" | tee -a "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"

# Vérifier ffmpeg
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ERREUR: ffmpeg non installé" | tee -a "$LOG_FILE"
    echo "Installer avec: sudo apt-get install ffmpeg"
    exit 1
fi

# Compter les vidéos
total_videos=$(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" \) | wc -l)
converted=0
skipped=0
failed=0

echo "Vidéos trouvées: $total_videos" | tee -a "$LOG_FILE"

# Parcourir toutes les vidéos
find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" \) | while read -r video; do
    echo -n "Vérification: $(basename "$video")... "
    
    # Vérifier le codec
    codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$video" 2>/dev/null)
    
    if [[ "$codec" == "h264" ]] && [[ "${video##*.}" == "mp4" ]]; then
        echo "OK (déjà H.264)" | tee -a "$LOG_FILE"
        ((skipped++))
    else
        echo "Conversion nécessaire (codec: $codec)" | tee -a "$LOG_FILE"
        
        # Nom temporaire
        temp_file="${video%.*}_chromium.mp4"
        
        # Convertir
        if ffmpeg -i "$video" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -movflags +faststart "$temp_file" -y </dev/null 2>>"$LOG_FILE"; then
            # Remplacer l'original
            mv "$temp_file" "${video%.*}.mp4"
            
            # Supprimer l'original si différent
            if [[ "${video##*.}" != "mp4" ]]; then
                rm "$video"
            fi
            
            echo "  -> Converti avec succès" | tee -a "$LOG_FILE"
            ((converted++))
        else
            echo "  -> ÉCHEC de la conversion" | tee -a "$LOG_FILE"
            rm -f "$temp_file"
            ((failed++))
        fi
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "=== Résumé ===" | tee -a "$LOG_FILE"
echo "Total: $total_videos vidéos" | tee -a "$LOG_FILE"
echo "Converties: $converted" | tee -a "$LOG_FILE"
echo "Déjà OK: $skipped" | tee -a "$LOG_FILE"
echo "Échecs: $failed" | tee -a "$LOG_FILE"

# Mettre à jour la playlist
if command -v /opt/scripts/update-playlist.sh >/dev/null 2>&1; then
    echo "Mise à jour de la playlist..." | tee -a "$LOG_FILE"
    /opt/scripts/update-playlist.sh
fi
EOF

    chmod +x /opt/scripts/convert-videos-chromium.sh
    log_info "Script de conversion créé"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== Patch de compatibilité YouTube -> Chromium ==="
    
    # Vérifier qu'on est en mode Chromium
    if ! grep -q "DISPLAY_MODE.*chromium" /etc/pi-signage/config.conf 2>/dev/null; then
        log_warn "Mode Chromium non détecté, patch optionnel"
        read -p "Appliquer le patch quand même ? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Patch annulé"
            exit 0
        fi
    fi
    
    # Appliquer les patches
    create_ytdlp_wrapper
    patch_web_interface
    create_conversion_script
    
    log_info ""
    log_info "=== Patch appliqué avec succès ==="
    log_info ""
    log_info "Actions effectuées :"
    log_info "- Wrapper yt-dlp-chromium créé pour forcer H.264"
    log_info "- Interface web configurée pour utiliser le wrapper"
    log_info "- Script de conversion créé : /opt/scripts/convert-videos-chromium.sh"
    log_info ""
    log_info "Prochaines étapes :"
    log_info "1. Convertir les vidéos existantes : sudo /opt/scripts/convert-videos-chromium.sh"
    log_info "2. Les nouveaux téléchargements seront automatiquement en H.264"
    log_info ""
}

# Vérifier qu'on est root
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

main "$@"