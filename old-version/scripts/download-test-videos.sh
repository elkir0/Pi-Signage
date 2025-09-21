#!/bin/bash

##############################################################################
# PiSignage Test Videos Download Script
# Version: 3.1.0
# Date: 2025-09-19
# 
# Description: Télécharge des vidéos de test pour PiSignage
# Usage: ./download-test-videos.sh
##############################################################################

set -e

# Configuration
MEDIA_DIR="/opt/pisignage/media"
TEMP_DIR="/tmp/pisignage_downloads"
LOG_FILE="/opt/pisignage/logs/video-download.log"

# Créer les dossiers nécessaires
mkdir -p "$MEDIA_DIR" "$TEMP_DIR" "$(dirname "$LOG_FILE")"

# Fonction de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction de nettoyage
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

log "=== Début du téléchargement des vidéos de test ==="

# Vidéos de test à télécharger
declare -A TEST_VIDEOS=(
    ["big-buck-bunny.mp4"]="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    ["sintel.mp4"]="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4" 
    ["tears-of-steel.mp4"]="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4"
    ["elephant-dream.mp4"]="https://archive.org/download/ElephantsDream/ed_hd.mp4"
    ["sample-demo.mp4"]="https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4"
)

# URLs alternatives si les principales échouent
declare -A FALLBACK_URLS=(
    ["big-buck-bunny.mp4"]="https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4"
    ["sintel.mp4"]="https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4"
    ["tears-of-steel.mp4"]="https://mango.blender.org/download/"
)

# Fonction de téléchargement avec retry
download_video() {
    local filename="$1"
    local url="$2"
    local output_path="$MEDIA_DIR/$filename"
    local temp_path="$TEMP_DIR/$filename"
    local fallback_url="${FALLBACK_URLS[$filename]}"
    
    # Vérifier si le fichier existe déjà
    if [ -f "$output_path" ]; then
        log "✅ $filename existe déjà, ignoré"
        return 0
    fi
    
    log "📥 Téléchargement de $filename..."
    log "URL: $url"
    
    # Essayer avec curl
    if command -v curl >/dev/null 2>&1; then
        log "Utilisation de curl pour $filename"
        if curl -L -o "$temp_path" \
               --connect-timeout 30 \
               --max-time 600 \
               --retry 3 \
               --retry-delay 5 \
               --fail \
               --progress-bar \
               "$url" 2>>"$LOG_FILE"; then
            mv "$temp_path" "$output_path"
            log "✅ $filename téléchargé avec succès ($(du -h "$output_path" | cut -f1))"
            return 0
        else
            log "❌ Échec de curl pour $filename"
        fi
    fi
    
    # Essayer avec wget
    if command -v wget >/dev/null 2>&1; then
        log "Utilisation de wget pour $filename"
        if wget -O "$temp_path" \
               --timeout=30 \
               --tries=3 \
               --waitretry=5 \
               --progress=bar:force \
               "$url" 2>>"$LOG_FILE"; then
            mv "$temp_path" "$output_path"
            log "✅ $filename téléchargé avec succès ($(du -h "$output_path" | cut -f1))"
            return 0
        else
            log "❌ Échec de wget pour $filename"
        fi
    fi
    
    # Essayer l'URL de fallback si disponible
    if [ -n "$fallback_url" ]; then
        log "🔄 Essai de l'URL de fallback pour $filename"
        log "Fallback URL: $fallback_url"
        
        if command -v curl >/dev/null 2>&1; then
            if curl -L -o "$temp_path" \
                   --connect-timeout 30 \
                   --max-time 600 \
                   --retry 2 \
                   --fail \
                   "$fallback_url" 2>>"$LOG_FILE"; then
                mv "$temp_path" "$output_path"
                log "✅ $filename téléchargé via fallback ($(du -h "$output_path" | cut -f1))"
                return 0
            fi
        fi
    fi
    
    log "❌ Impossible de télécharger $filename"
    return 1
}

# Fonction pour créer une vidéo de test locale si les téléchargements échouent
create_test_video() {
    local filename="$1"
    local output_path="$MEDIA_DIR/$filename"
    
    if ! command -v ffmpeg >/dev/null 2>&1; then
        log "❌ FFmpeg non disponible pour créer des vidéos de test"
        return 1
    fi
    
    log "🎬 Création d'une vidéo de test locale: $filename"
    
    # Créer une vidéo de test colorée avec du texte
    ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30 \
           -f lavfi -i sine=frequency=440:duration=10 \
           -c:v libx264 -preset fast -crf 23 \
           -c:a aac -b:a 128k \
           -t 10 \
           -pix_fmt yuv420p \
           -y "$output_path" 2>>"$LOG_FILE"
    
    if [ -f "$output_path" ]; then
        log "✅ Vidéo de test créée: $filename ($(du -h "$output_path" | cut -f1))"
        return 0
    else
        log "❌ Impossible de créer la vidéo de test: $filename"
        return 1
    fi
}

# Vérifier les outils de téléchargement
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    log "❌ ERREUR: curl et wget ne sont pas disponibles"
    log "Installation requise: sudo apt-get install curl wget"
    exit 1
fi

# Télécharger les vidéos
SUCCESS_COUNT=0
TOTAL_COUNT=${#TEST_VIDEOS[@]}

for filename in "${!TEST_VIDEOS[@]}"; do
    url="${TEST_VIDEOS[$filename]}"
    
    if download_video "$filename" "$url"; then
        ((SUCCESS_COUNT++))
    else
        # Si le téléchargement échoue, essayer de créer une vidéo de test
        log "🎬 Tentative de création d'une vidéo de test pour $filename"
        if create_test_video "$filename"; then
            ((SUCCESS_COUNT++))
        fi
    fi
done

# Créer une vidéo de démonstration personnalisée
DEMO_FILE="$MEDIA_DIR/pisignage-demo.mp4"
if [ ! -f "$DEMO_FILE" ] && command -v ffmpeg >/dev/null 2>&1; then
    log "🎬 Création de la vidéo de démonstration PiSignage..."
    
    ffmpeg -f lavfi -i "color=c=blue:size=1920x1080:duration=5:rate=30" \
           -f lavfi -i "color=c=green:size=1920x1080:duration=5:rate=30" \
           -f lavfi -i "color=c=red:size=1920x1080:duration=5:rate=30" \
           -f lavfi -i "sine=frequency=440:duration=15" \
           -filter_complex "[0:v][1:v][2:v]concat=n=3:v=1:a=0[outv]" \
           -map "[outv]" -map 3:a \
           -c:v libx264 -preset fast -crf 23 \
           -c:a aac -b:a 128k \
           -pix_fmt yuv420p \
           -y "$DEMO_FILE" 2>>"$LOG_FILE"
    
    if [ -f "$DEMO_FILE" ]; then
        log "✅ Vidéo de démonstration créée ($(du -h "$DEMO_FILE" | cut -f1))"
        ((SUCCESS_COUNT++))
        ((TOTAL_COUNT++))
    fi
fi

# Vérifier les permissions
chmod 644 "$MEDIA_DIR"/*.mp4 2>/dev/null || true

# Résumé final
log "=== Résumé du téléchargement ==="
log "✅ Vidéos téléchargées avec succès: $SUCCESS_COUNT/$TOTAL_COUNT"

if [ -d "$MEDIA_DIR" ]; then
    VIDEO_COUNT=$(find "$MEDIA_DIR" -name "*.mp4" -type f | wc -l)
    TOTAL_SIZE=$(du -sh "$MEDIA_DIR" 2>/dev/null | cut -f1 || echo "N/A")
    
    log "📁 Dossier média: $MEDIA_DIR"
    log "🎬 Nombre total de vidéos: $VIDEO_COUNT"
    log "💾 Taille totale: $TOTAL_SIZE"
    
    log ""
    log "📋 Liste des vidéos disponibles:"
    find "$MEDIA_DIR" -name "*.mp4" -type f -exec basename {} \; | sort | while read -r video; do
        size=$(du -h "$MEDIA_DIR/$video" 2>/dev/null | cut -f1 || echo "N/A")
        log "  • $video ($size)"
    done
fi

if [ "$SUCCESS_COUNT" -gt 0 ]; then
    log "✅ Installation des vidéos de test terminée avec succès!"
    exit 0
else
    log "❌ Aucune vidéo n'a pu être installée"
    exit 1
fi