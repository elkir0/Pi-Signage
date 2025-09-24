#!/bin/bash
# PiSignage v0.8.0 - Media Management Script
# Gestion automatisée des fichiers médias

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MEDIA_DIR="$PROJECT_DIR/media"
CONFIG_DIR="$PROJECT_DIR/config"
LOG_FILE="$PROJECT_DIR/logs/media-manager.log"

# Créer les dossiers nécessaires
mkdir -p "$MEDIA_DIR" "$CONFIG_DIR" "$(dirname "$LOG_FILE")"

# Fonctions de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Afficher l'aide
show_help() {
    cat << EOF
PiSignage v0.8.0 - Media Manager

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  scan          Scan media directory and update database
  cleanup       Remove invalid/corrupted files
  optimize      Optimize media files for playback
  thumbnails    Generate thumbnails for all media
  info [FILE]   Show detailed info about a media file
  convert [FILE] [FORMAT]  Convert media file to specified format
  validate      Validate all media files
  stats         Show media directory statistics
  backup        Backup media directory
  restore [PATH] Restore from backup

Options:
  -v, --verbose    Verbose output
  -f, --force      Force operations without confirmation
  -h, --help       Show this help

Examples:
  $0 scan                    # Scan all media files
  $0 cleanup --force         # Remove corrupted files
  $0 info video.mp4          # Show info about video.mp4
  $0 convert video.avi mp4   # Convert AVI to MP4
  $0 thumbnails              # Generate all thumbnails

EOF
}

# Détecter les outils disponibles
detect_tools() {
    TOOLS_AVAILABLE=()

    if command -v ffmpeg >/dev/null 2>&1; then
        TOOLS_AVAILABLE+=("ffmpeg")
        FFMPEG_AVAILABLE=true
    else
        FFMPEG_AVAILABLE=false
    fi

    if command -v ffprobe >/dev/null 2>&1; then
        TOOLS_AVAILABLE+=("ffprobe")
        FFPROBE_AVAILABLE=true
    else
        FFPROBE_AVAILABLE=false
    fi

    if command -v mediainfo >/dev/null 2>&1; then
        TOOLS_AVAILABLE+=("mediainfo")
        MEDIAINFO_AVAILABLE=true
    else
        MEDIAINFO_AVAILABLE=false
    fi

    if command -v convert >/dev/null 2>&1; then
        TOOLS_AVAILABLE+=("imagemagick")
        IMAGEMAGICK_AVAILABLE=true
    else
        IMAGEMAGICK_AVAILABLE=false
    fi

    log "Available tools: ${TOOLS_AVAILABLE[*]}"
}

# Obtenir les informations d'un fichier média
get_media_info() {
    local file="$1"
    local info_method="$2"

    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        return 1
    fi

    case "$info_method" in
        "ffprobe")
            if $FFPROBE_AVAILABLE; then
                ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null
            fi
            ;;
        "mediainfo")
            if $MEDIAINFO_AVAILABLE; then
                mediainfo --Output=JSON "$file" 2>/dev/null
            fi
            ;;
        *)
            # Fallback: informations basiques
            echo "{"
            echo "  \"filename\": \"$(basename "$file")\","
            echo "  \"size\": $(stat -c%s "$file"),"
            echo "  \"modified\": \"$(stat -c%y "$file")\","
            echo "  \"type\": \"$(file -b --mime-type "$file")\""
            echo "}"
            ;;
    esac
}

# Scanner le répertoire média
scan_media() {
    log "Starting media scan..."

    local total_files=0
    local valid_files=0
    local invalid_files=0
    local total_size=0

    # Extensions supportées
    local extensions=("mp4" "avi" "mkv" "mov" "wmv" "flv" "webm" "jpg" "jpeg" "png" "gif" "bmp" "mp3" "wav" "flac" "ogg")

    for ext in "${extensions[@]}"; do
        while IFS= read -r -d '' file; do
            ((total_files++))
            file_size=$(stat -c%s "$file")
            total_size=$((total_size + file_size))

            if validate_media_file "$file"; then
                ((valid_files++))
                if [[ $VERBOSE ]]; then
                    log "✓ Valid: $(basename "$file") ($(format_size $file_size))"
                fi
            else
                ((invalid_files++))
                error "✗ Invalid: $(basename "$file")"
            fi

        done < <(find "$MEDIA_DIR" -iname "*.${ext}" -type f -print0 2>/dev/null)
    done

    log "Scan completed:"
    log "  Total files: $total_files"
    log "  Valid files: $valid_files"
    log "  Invalid files: $invalid_files"
    log "  Total size: $(format_size $total_size)"

    # Sauvegarder les statistiques
    cat > "$CONFIG_DIR/media_stats.json" << EOF
{
    "scan_date": "$(date -Iseconds)",
    "total_files": $total_files,
    "valid_files": $valid_files,
    "invalid_files": $invalid_files,
    "total_size": $total_size,
    "total_size_formatted": "$(format_size $total_size)"
}
EOF
}

# Valider un fichier média
validate_media_file() {
    local file="$1"

    # Vérifications basiques
    if [[ ! -f "$file" ]]; then
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        return 1
    fi

    local file_size=$(stat -c%s "$file")
    if [[ $file_size -eq 0 ]]; then
        return 1
    fi

    # Vérification avec ffprobe si disponible
    if $FFPROBE_AVAILABLE; then
        if ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$file" >/dev/null 2>&1; then
            return 0
        fi

        # Pour les fichiers audio
        if ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$file" >/dev/null 2>&1; then
            return 0
        fi

        # Pour les images
        if ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$file" >/dev/null 2>&1; then
            return 0
        fi

        return 1
    fi

    # Vérification basique par type MIME
    local mime_type=$(file -b --mime-type "$file")
    case "$mime_type" in
        video/*|audio/*|image/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Nettoyer les fichiers invalides
cleanup_media() {
    log "Starting media cleanup..."

    local removed_count=0
    local freed_space=0

    # Scanner tous les fichiers
    while IFS= read -r -d '' file; do
        if ! validate_media_file "$file"; then
            local file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            local filename=$(basename "$file")

            if [[ $FORCE ]] || confirm "Remove invalid file: $filename?"; then
                rm -f "$file"
                ((removed_count++))
                freed_space=$((freed_space + file_size))
                log "Removed: $filename ($(format_size $file_size))"
            fi
        fi
    done < <(find "$MEDIA_DIR" -type f -print0 2>/dev/null)

    log "Cleanup completed:"
    log "  Files removed: $removed_count"
    log "  Space freed: $(format_size $freed_space)"
}

# Optimiser les fichiers média
optimize_media() {
    log "Starting media optimization..."

    if ! $FFMPEG_AVAILABLE; then
        error "ffmpeg is required for optimization"
        return 1
    fi

    local optimized_count=0
    local space_saved=0

    # Optimiser les vidéos
    while IFS= read -r -d '' file; do
        if [[ "$file" =~ \.(mp4|avi|mkv|mov|wmv|flv)$ ]]; then
            optimize_video "$file" && ((optimized_count++))
        fi
    done < <(find "$MEDIA_DIR" -type f -print0 2>/dev/null)

    log "Optimization completed: $optimized_count files optimized"
}

# Optimiser une vidéo
optimize_video() {
    local input_file="$1"
    local filename=$(basename "$input_file")
    local temp_file="${input_file}.tmp"

    log "Optimizing: $filename"

    # Paramètres d'optimisation pour Raspberry Pi
    local ffmpeg_params=(
        -i "$input_file"
        -c:v libx264
        -preset medium
        -crf 23
        -maxrate 2M
        -bufsize 4M
        -c:a aac
        -b:a 128k
        -movflags +faststart
        -y
        "$temp_file"
    )

    if ffmpeg "${ffmpeg_params[@]}" >/dev/null 2>&1; then
        local original_size=$(stat -c%s "$input_file")
        local optimized_size=$(stat -c%s "$temp_file")

        if [[ $optimized_size -lt $original_size ]]; then
            mv "$temp_file" "$input_file"
            local saved=$((original_size - optimized_size))
            log "✓ Optimized: $filename (saved $(format_size $saved))"
            return 0
        else
            rm -f "$temp_file"
            log "! No optimization benefit for: $filename"
            return 1
        fi
    else
        rm -f "$temp_file"
        error "Failed to optimize: $filename"
        return 1
    fi
}

# Générer les miniatures
generate_thumbnails() {
    log "Generating thumbnails..."

    local thumbnail_dir="$MEDIA_DIR/thumbnails"
    mkdir -p "$thumbnail_dir"

    local generated_count=0

    # Générer pour les vidéos
    while IFS= read -r -d '' file; do
        if [[ "$file" =~ \.(mp4|avi|mkv|mov|wmv|flv|webm)$ ]]; then
            generate_video_thumbnail "$file" "$thumbnail_dir" && ((generated_count++))
        elif [[ "$file" =~ \.(jpg|jpeg|png|gif|bmp)$ ]]; then
            generate_image_thumbnail "$file" "$thumbnail_dir" && ((generated_count++))
        fi
    done < <(find "$MEDIA_DIR" -maxdepth 1 -type f -print0 2>/dev/null)

    log "Generated $generated_count thumbnails"
}

# Générer une miniature vidéo
generate_video_thumbnail() {
    local video_file="$1"
    local thumbnail_dir="$2"
    local filename=$(basename "$video_file")
    local thumbnail_file="$thumbnail_dir/${filename%.*}.jpg"

    if [[ -f "$thumbnail_file" ]]; then
        return 0  # Déjà existante
    fi

    if $FFMPEG_AVAILABLE; then
        if ffmpeg -i "$video_file" -ss 00:00:01.000 -vframes 1 -vf scale=200:150 "$thumbnail_file" -y >/dev/null 2>&1; then
            log "✓ Thumbnail: $filename"
            return 0
        fi
    fi

    return 1
}

# Générer une miniature image
generate_image_thumbnail() {
    local image_file="$1"
    local thumbnail_dir="$2"
    local filename=$(basename "$image_file")
    local thumbnail_file="$thumbnail_dir/${filename%.*}.jpg"

    if [[ -f "$thumbnail_file" ]]; then
        return 0  # Déjà existante
    fi

    if $IMAGEMAGICK_AVAILABLE; then
        if convert "$image_file" -resize 200x150^ -gravity center -extent 200x150 "$thumbnail_file" 2>/dev/null; then
            log "✓ Thumbnail: $filename"
            return 0
        fi
    fi

    return 1
}

# Convertir un fichier
convert_media() {
    local input_file="$1"
    local target_format="$2"

    if [[ ! -f "$input_file" ]]; then
        error "Input file not found: $input_file"
        return 1
    fi

    if ! $FFMPEG_AVAILABLE; then
        error "ffmpeg is required for conversion"
        return 1
    fi

    local filename=$(basename "$input_file")
    local name_without_ext="${filename%.*}"
    local output_file="$MEDIA_DIR/${name_without_ext}.${target_format}"

    log "Converting: $filename to $target_format"

    case "$target_format" in
        "mp4")
            ffmpeg -i "$input_file" -c:v libx264 -c:a aac -movflags +faststart "$output_file" -y
            ;;
        "mp3")
            ffmpeg -i "$input_file" -c:a libmp3lame -b:a 192k "$output_file" -y
            ;;
        "jpg"|"jpeg")
            ffmpeg -i "$input_file" -vframes 1 "$output_file" -y
            ;;
        *)
            error "Unsupported format: $target_format"
            return 1
            ;;
    esac

    if [[ $? -eq 0 && -f "$output_file" ]]; then
        log "✓ Conversion completed: $output_file"
        return 0
    else
        error "Conversion failed"
        return 1
    fi
}

# Afficher les statistiques
show_stats() {
    log "Media Directory Statistics"
    log "=========================="

    if [[ -f "$CONFIG_DIR/media_stats.json" ]]; then
        log "Last scan: $(jq -r '.scan_date' "$CONFIG_DIR/media_stats.json" 2>/dev/null || echo 'Never')"
        log "Total files: $(jq -r '.total_files' "$CONFIG_DIR/media_stats.json" 2>/dev/null || echo 'Unknown')"
        log "Valid files: $(jq -r '.valid_files' "$CONFIG_DIR/media_stats.json" 2>/dev/null || echo 'Unknown')"
        log "Total size: $(jq -r '.total_size_formatted' "$CONFIG_DIR/media_stats.json" 2>/dev/null || echo 'Unknown')"
    else
        log "No statistics available. Run 'scan' first."
    fi

    log ""
    log "Current directory size: $(du -sh "$MEDIA_DIR" | cut -f1)"
    log "Available disk space: $(df -h "$MEDIA_DIR" | tail -1 | awk '{print $4}')"
}

# Formater la taille en bytes
format_size() {
    local size=$1
    if [[ $size -lt 1024 ]]; then
        echo "${size}B"
    elif [[ $size -lt 1048576 ]]; then
        echo "$(( size / 1024 ))KB"
    elif [[ $size -lt 1073741824 ]]; then
        echo "$(( size / 1048576 ))MB"
    else
        echo "$(( size / 1073741824 ))GB"
    fi
}

# Demander confirmation
confirm() {
    if [[ $FORCE ]]; then
        return 0
    fi

    local prompt="$1"
    read -p "$prompt (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Afficher les informations détaillées d'un fichier
show_file_info() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        return 1
    fi

    log "File Information: $(basename "$file")"
    log "=================="

    # Informations basiques
    log "Path: $file"
    log "Size: $(format_size $(stat -c%s "$file"))"
    log "Modified: $(stat -c%y "$file")"
    log "Type: $(file -b --mime-type "$file")"

    # Informations détaillées avec ffprobe
    if $FFPROBE_AVAILABLE; then
        log ""
        log "Media Information:"
        log "=================="

        # Format général
        local duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null)
        if [[ -n "$duration" ]] && [[ "$duration" != "N/A" ]]; then
            log "Duration: $(format_duration "$duration")"
        fi

        local bitrate=$(ffprobe -v quiet -show_entries format=bit_rate -of csv=p=0 "$file" 2>/dev/null)
        if [[ -n "$bitrate" ]] && [[ "$bitrate" != "N/A" ]]; then
            log "Bitrate: $(( bitrate / 1000 ))kbps"
        fi

        # Informations vidéo
        local video_codec=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$file" 2>/dev/null)
        if [[ -n "$video_codec" ]]; then
            log "Video codec: $video_codec"

            local resolution=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$file" 2>/dev/null)
            if [[ -n "$resolution" ]]; then
                log "Resolution: $resolution"
            fi

            local fps=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$file" 2>/dev/null)
            if [[ -n "$fps" ]] && [[ "$fps" != "0/0" ]]; then
                log "Frame rate: $fps"
            fi
        fi

        # Informations audio
        local audio_codec=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$file" 2>/dev/null)
        if [[ -n "$audio_codec" ]]; then
            log "Audio codec: $audio_codec"

            local sample_rate=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$file" 2>/dev/null)
            if [[ -n "$sample_rate" ]]; then
                log "Sample rate: ${sample_rate}Hz"
            fi
        fi
    fi
}

# Formater la durée en secondes
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%02d:%02d:%02d" "$hours" "$minutes" "$secs"
    else
        printf "%02d:%02d" "$minutes" "$secs"
    fi
}

# Fonction principale
main() {
    # Initialisation
    detect_tools

    # Traitement des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            scan)
                scan_media
                exit 0
                ;;
            cleanup)
                cleanup_media
                exit 0
                ;;
            optimize)
                optimize_media
                exit 0
                ;;
            thumbnails)
                generate_thumbnails
                exit 0
                ;;
            info)
                if [[ -n "$2" ]]; then
                    show_file_info "$MEDIA_DIR/$2"
                else
                    error "Please specify a file name"
                    exit 1
                fi
                exit 0
                ;;
            convert)
                if [[ -n "$2" && -n "$3" ]]; then
                    convert_media "$MEDIA_DIR/$2" "$3"
                else
                    error "Please specify input file and target format"
                    exit 1
                fi
                exit 0
                ;;
            validate)
                scan_media
                exit 0
                ;;
            stats)
                show_stats
                exit 0
                ;;
            *)
                error "Unknown command: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Si aucune commande n'est spécifiée, afficher l'aide
    show_help
}

# Exécution
main "$@"