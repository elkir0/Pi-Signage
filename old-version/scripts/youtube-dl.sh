#!/bin/bash

##############################################################################
# PiSignage YouTube Download Script
# Version: 3.1.0
# Date: 2025-09-19
# 
# Description: Télécharge des vidéos YouTube avec yt-dlp et les optimise
# Usage: ./youtube-dl.sh <URL> [quality] [output_name]
##############################################################################

set -e

# Configuration
MEDIA_DIR="/opt/pisignage/media"
TEMP_DIR="/tmp/pisignage_youtube"
LOG_FILE="/opt/pisignage/logs/youtube-download.log"
PROGRESS_FILE="/tmp/pisignage_youtube_progress.json"
MAX_DURATION=3600  # 1 heure maximum
MAX_SIZE="500M"    # 500MB maximum

# Créer les dossiers nécessaires
mkdir -p "$MEDIA_DIR" "$TEMP_DIR" "$(dirname "$LOG_FILE")"

# Fonction de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction de nettoyage
cleanup() {
    rm -rf "$TEMP_DIR"
    rm -f "$PROGRESS_FILE"
}
trap cleanup EXIT

# Fonction d'aide
show_help() {
    echo "Usage: $0 <URL> [quality] [output_name]"
    echo ""
    echo "Arguments:"
    echo "  URL          URL YouTube à télécharger"
    echo "  quality      Qualité vidéo (best, worst, 720p, 480p, 360p) [défaut: 720p]"  
    echo "  output_name  Nom du fichier de sortie (sans extension) [auto]"
    echo ""
    echo "Exemples:"
    echo "  $0 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    echo "  $0 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' 480p"
    echo "  $0 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' 720p ma-video"
    echo ""
    echo "Qualités disponibles:"
    echo "  best    - Meilleure qualité disponible"
    echo "  720p    - HD 720p (recommandé)"
    echo "  480p    - SD 480p"
    echo "  360p    - SD 360p (économie d'espace)"
    echo "  worst   - Plus faible qualité"
}

# Fonction pour créer le fichier de progression
update_progress() {
    local percent="$1"
    local status="$2" 
    local message="$3"
    local eta="$4"
    
    cat > "$PROGRESS_FILE" <<EOF
{
    "percent": "$percent",
    "status": "$status",
    "message": "$message",
    "eta": "$eta",
    "timestamp": "$(date -Is)"
}
EOF
}

# Vérification des paramètres
if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

URL="$1"
QUALITY="${2:-720p}"
OUTPUT_NAME="$3"

# Vérifier que yt-dlp est installé
if ! command -v yt-dlp >/dev/null 2>&1; then
    log "❌ ERREUR: yt-dlp n'est pas installé"
    log "Installation: pip3 install yt-dlp ou apt install yt-dlp"
    update_progress "0" "error" "yt-dlp non installé" ""
    exit 1
fi

# Vérifier que ffmpeg est installé
if ! command -v ffmpeg >/dev/null 2>&1; then
    log "❌ ERREUR: ffmpeg n'est pas installé"
    log "Installation: apt install ffmpeg"
    update_progress "0" "error" "ffmpeg non installé" ""
    exit 1
fi

log "=== Début du téléchargement YouTube ==="
log "URL: $URL"
log "Qualité: $QUALITY"

# Initialiser le progress
update_progress "0" "starting" "Analyse de la vidéo..." ""

# Configuration du format selon la qualité demandée
case "$QUALITY" in
    "best")
        FORMAT="best[ext=mp4]/best"
        ;;
    "720p")
        FORMAT="best[height<=720][ext=mp4]/best[height<=720]/best[ext=mp4]/best"
        ;;
    "480p") 
        FORMAT="best[height<=480][ext=mp4]/best[height<=480]/best[ext=mp4]/best"
        ;;
    "360p")
        FORMAT="best[height<=360][ext=mp4]/best[height<=360]/best[ext=mp4]/best"
        ;;
    "worst")
        FORMAT="worst[ext=mp4]/worst"
        ;;
    *)
        log "❌ Qualité non reconnue: $QUALITY"
        show_help
        exit 1
        ;;
esac

# Obtenir les informations sur la vidéo
log "📊 Analyse de la vidéo..."
INFO_JSON=$(yt-dlp --no-download --print-json "$URL" 2>>"$LOG_FILE" || {
    log "❌ Impossible d'analyser l'URL"
    update_progress "0" "error" "URL invalide ou inaccessible" ""
    exit 1
})

# Extraire les métadonnées
TITLE=$(echo "$INFO_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['title'])" 2>/dev/null || echo "video")
DURATION=$(echo "$INFO_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('duration', 0))" 2>/dev/null || echo "0")
UPLOADER=$(echo "$INFO_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('uploader', 'unknown'))" 2>/dev/null || echo "unknown")

log "📹 Titre: $TITLE"
log "👤 Auteur: $UPLOADER" 
log "⏱️  Durée: ${DURATION}s"

# Vérifier la durée
if [ "$DURATION" -gt "$MAX_DURATION" ]; then
    log "❌ Vidéo trop longue (${DURATION}s > ${MAX_DURATION}s)"
    update_progress "0" "error" "Vidéo trop longue" ""
    exit 1
fi

# Générer le nom de fichier
if [ -n "$OUTPUT_NAME" ]; then
    SAFE_NAME="$OUTPUT_NAME"
else
    # Nettoyer le titre pour créer un nom de fichier sûr
    SAFE_NAME=$(echo "$TITLE" | sed 's/[^a-zA-Z0-9._-]/_/g' | cut -c1-50)
fi

TEMP_FILE="$TEMP_DIR/${SAFE_NAME}_temp.%(ext)s"
FINAL_FILE="$MEDIA_DIR/${SAFE_NAME}.mp4"

# Vérifier si le fichier existe déjà
if [ -f "$FINAL_FILE" ]; then
    log "❌ Le fichier existe déjà: $FINAL_FILE"
    update_progress "0" "error" "Fichier déjà existant" ""
    exit 1
fi

log "💾 Téléchargement vers: $FINAL_FILE"
update_progress "5" "downloading" "Téléchargement en cours..." ""

# Hook de progression pour yt-dlp
PROGRESS_HOOK="/tmp/yt_dlp_progress_$$.py"
cat > "$PROGRESS_HOOK" <<'EOF'
#!/usr/bin/env python3
import json
import sys
import os

def my_hook(d):
    progress_file = os.environ.get('PROGRESS_FILE', '/tmp/pisignage_youtube_progress.json')
    
    if d['status'] == 'downloading':
        percent = d.get('_percent_str', '0%').replace('%', '')
        try:
            percent_num = float(percent)
        except:
            percent_num = 0
            
        eta = d.get('_eta_str', 'Unknown')
        speed = d.get('_speed_str', '')
        
        progress_data = {
            'percent': str(int(percent_num)),
            'status': 'downloading',
            'message': f'Téléchargement... {speed}',
            'eta': eta,
            'timestamp': '$(date -Is)'
        }
        
        with open(progress_file, 'w') as f:
            json.dump(progress_data, f)
            
    elif d['status'] == 'finished':
        progress_data = {
            'percent': '90',
            'status': 'processing', 
            'message': 'Téléchargement terminé, traitement...',
            'eta': '',
            'timestamp': '$(date -Is)'
        }
        
        with open(progress_file, 'w') as f:
            json.dump(progress_data, f)

EOF

chmod +x "$PROGRESS_HOOK"
export PROGRESS_FILE

# Télécharger la vidéo
yt-dlp \
    --format "$FORMAT" \
    --output "$TEMP_FILE" \
    --no-playlist \
    --embed-metadata \
    --add-metadata \
    --write-description \
    --write-info-json \
    --max-filesize "$MAX_SIZE" \
    --progress-template "download:%(progress._percent_str)s %(progress._speed_str)s %(progress._eta_str)s" \
    --exec "python3 $PROGRESS_HOOK" \
    "$URL" 2>>"$LOG_FILE" || {
    log "❌ Échec du téléchargement"
    update_progress "0" "error" "Échec du téléchargement" ""
    exit 1
}

# Trouver le fichier téléchargé
DOWNLOADED_FILE=$(find "$TEMP_DIR" -name "${SAFE_NAME}_temp.*" -not -name "*.description" -not -name "*.info.json" | head -1)

if [ ! -f "$DOWNLOADED_FILE" ]; then
    log "❌ Fichier téléchargé introuvable"
    update_progress "0" "error" "Fichier téléchargé introuvable" ""
    exit 1
fi

log "✅ Téléchargement terminé: $(basename "$DOWNLOADED_FILE")"
update_progress "90" "processing" "Optimisation de la vidéo..." ""

# Optimiser la vidéo avec ffmpeg si nécessaire
log "🔧 Optimisation de la vidéo..."

# Vérifier si le fichier est déjà en MP4 avec les bons codecs
FILE_INFO=$(ffprobe -v quiet -print_format json -show_format -show_streams "$DOWNLOADED_FILE" 2>/dev/null || echo "{}")
NEEDS_CONVERSION=false

# Vérifier le container et les codecs
if [[ "$DOWNLOADED_FILE" != *.mp4 ]] || \
   ! echo "$FILE_INFO" | grep -q '"codec_name": "h264"' || \
   ! echo "$FILE_INFO" | grep -q '"codec_name": "aac"'; then
    NEEDS_CONVERSION=true
fi

if [ "$NEEDS_CONVERSION" = true ]; then
    log "🔄 Conversion nécessaire..."
    
    ffmpeg -i "$DOWNLOADED_FILE" \
           -c:v libx264 \
           -preset fast \
           -crf 23 \
           -c:a aac \
           -b:a 128k \
           -movflags +faststart \
           -pix_fmt yuv420p \
           -y "$FINAL_FILE" 2>>"$LOG_FILE" || {
        log "❌ Échec de la conversion"
        update_progress "0" "error" "Échec de la conversion" ""
        exit 1
    }
else
    log "✅ Aucune conversion nécessaire"
    mv "$DOWNLOADED_FILE" "$FINAL_FILE"
fi

# Vérifier les permissions
chmod 644 "$FINAL_FILE"

# Informations finales
FILE_SIZE=$(du -h "$FINAL_FILE" | cut -f1)
log "✅ Vidéo prête: $FINAL_FILE ($FILE_SIZE)"

update_progress "100" "completed" "Téléchargement terminé avec succès" ""

log "=== Téléchargement YouTube terminé ==="

# Nettoyer les fichiers temporaires de métadonnées
rm -f "$TEMP_DIR"/*.description "$TEMP_DIR"/*.info.json
rm -f "$PROGRESS_HOOK"

echo "$FINAL_FILE"