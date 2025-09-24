#!/bin/bash

# VLC Playlist Manager for PiSignage v0.8.0
# Advanced playlist management with transitions and scheduling

# ================================
# CONFIGURATION
# ================================

MEDIA_DIR="/opt/pisignage/media"
CONFIG_DIR="/opt/pisignage/config"
LOG_DIR="/opt/pisignage/logs"

PLAYLIST_DIR="$CONFIG_DIR/playlists"
CURRENT_PLAYLIST="$CONFIG_DIR/current_playlist.m3u"
SCHEDULE_FILE="$CONFIG_DIR/schedule.json"
LOG_FILE="$LOG_DIR/playlist.log"

# Supported video formats
VIDEO_FORMATS=("mp4" "avi" "mkv" "mov" "wmv" "webm" "m4v" "mpg" "mpeg" "ts" "mts")
IMAGE_FORMATS=("jpg" "jpeg" "png" "bmp" "tiff" "gif")

# Default display durations (seconds)
DEFAULT_VIDEO_DURATION=0  # 0 = play full video
DEFAULT_IMAGE_DURATION=10
DEFAULT_TRANSITION_DURATION=1

mkdir -p "$PLAYLIST_DIR" "$LOG_DIR"

# ================================
# LOGGING AND UTILITIES
# ================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_file_type() {
    local file="$1"
    local extension="${file##*.}"
    extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

    for fmt in "${VIDEO_FORMATS[@]}"; do
        if [ "$extension" = "$fmt" ]; then
            echo "video"
            return 0
        fi
    done

    for fmt in "${IMAGE_FORMATS[@]}"; do
        if [ "$extension" = "$fmt" ]; then
            echo "image"
            return 0
        fi
    done

    echo "unknown"
}

get_video_duration() {
    local file="$1"

    # Try to get duration with ffprobe (if available)
    if command -v ffprobe > /dev/null 2>&1; then
        local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
        if [ -n "$duration" ] && [ "$duration" != "N/A" ]; then
            printf "%.0f" "$duration"
            return 0
        fi
    fi

    # Fallback: estimate based on file size (very rough)
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [ -n "$size" ]; then
        # Rough estimate: 1MB per 10 seconds for HD video
        local estimated=$((size / 100000))
        echo "${estimated:-30}"  # Default to 30 seconds if calculation fails
    else
        echo "30"  # Default fallback
    fi
}

# ================================
# PLAYLIST CREATION FUNCTIONS
# ================================

create_basic_playlist() {
    local name="$1"
    local playlist_file="$PLAYLIST_DIR/$name.m3u"

    log_message "Creating basic playlist: $name"

    # Find all media files
    local media_files=()
    while IFS= read -r -d '' file; do
        local file_type=$(get_file_type "$file")
        if [ "$file_type" != "unknown" ]; then
            media_files+=("$file")
        fi
    done < <(find "$MEDIA_DIR" -type f -print0 | sort -z)

    if [ ${#media_files[@]} -eq 0 ]; then
        log_message "ERROR: No media files found in $MEDIA_DIR"
        return 1
    fi

    # Create M3U playlist
    {
        echo "#EXTM3U"
        echo "#PLAYLIST:$name"
        echo ""

        for file in "${media_files[@]}"; do
            local basename=$(basename "$file")
            local file_type=$(get_file_type "$file")

            if [ "$file_type" = "video" ]; then
                local duration=$(get_video_duration "$file")
                echo "#EXTINF:$duration,$basename"
            else
                echo "#EXTINF:$DEFAULT_IMAGE_DURATION,$basename"
            fi

            echo "file://$file"
            echo ""
        done
    } > "$playlist_file"

    log_message "Created playlist with ${#media_files[@]} files: $playlist_file"
    return 0
}

create_advanced_playlist() {
    local name="$1"
    local config_json="$2"
    local playlist_file="$PLAYLIST_DIR/$name.m3u"

    log_message "Creating advanced playlist: $name"

    if [ ! -f "$config_json" ]; then
        log_message "ERROR: Configuration file not found: $config_json"
        return 1
    fi

    # This is a simplified version - in a real implementation,
    # you would parse the JSON configuration
    create_basic_playlist "$name"
}

create_slideshow_playlist() {
    local name="$1"
    local duration="${2:-$DEFAULT_IMAGE_DURATION}"
    local playlist_file="$PLAYLIST_DIR/$name.m3u"

    log_message "Creating slideshow playlist: $name (${duration}s per image)"

    # Find image files only
    local image_files=()
    while IFS= read -r -d '' file; do
        local file_type=$(get_file_type "$file")
        if [ "$file_type" = "image" ]; then
            image_files+=("$file")
        fi
    done < <(find "$MEDIA_DIR" -type f -print0 | sort -z)

    if [ ${#image_files[@]} -eq 0 ]; then
        log_message "ERROR: No image files found in $MEDIA_DIR"
        return 1
    fi

    # Create slideshow playlist with VLC image duration syntax
    {
        echo "#EXTM3U"
        echo "#PLAYLIST:$name (Slideshow)"
        echo ""

        for file in "${image_files[@]}"; do
            local basename=$(basename "$file")
            echo "#EXTINF:$duration,$basename"
            echo "file://$file"
            echo ""
        done
    } > "$playlist_file"

    log_message "Created slideshow with ${#image_files[@]} images: $playlist_file"
    return 0
}

create_mixed_playlist() {
    local name="$1"
    local video_weight="${2:-70}"  # Percentage of videos vs images
    local playlist_file="$PLAYLIST_DIR/$name.m3u"

    log_message "Creating mixed playlist: $name (${video_weight}% videos)"

    # Find all media files
    local video_files=()
    local image_files=()

    while IFS= read -r -d '' file; do
        local file_type=$(get_file_type "$file")
        case "$file_type" in
            "video") video_files+=("$file") ;;
            "image") image_files+=("$file") ;;
        esac
    done < <(find "$MEDIA_DIR" -type f -print0 | sort -z)

    if [ ${#video_files[@]} -eq 0 ] && [ ${#image_files[@]} -eq 0 ]; then
        log_message "ERROR: No media files found"
        return 1
    fi

    # Create mixed playlist
    {
        echo "#EXTM3U"
        echo "#PLAYLIST:$name (Mixed Media)"
        echo ""

        # Calculate how many of each type to include
        local total_items=20  # Target playlist length
        local video_count=$(( (total_items * video_weight) / 100 ))
        local image_count=$(( total_items - video_count ))

        # Add videos
        local count=0
        for file in "${video_files[@]}"; do
            if [ $count -ge $video_count ]; then break; fi

            local basename=$(basename "$file")
            local duration=$(get_video_duration "$file")
            echo "#EXTINF:$duration,$basename"
            echo "file://$file"
            echo ""

            count=$((count + 1))
        done

        # Add images
        count=0
        for file in "${image_files[@]}"; do
            if [ $count -ge $image_count ]; then break; fi

            local basename=$(basename "$file")
            echo "#EXTINF:$DEFAULT_IMAGE_DURATION,$basename"
            echo "file://$file"
            echo ""

            count=$((count + 1))
        done

    } > "$playlist_file"

    log_message "Created mixed playlist: $playlist_file"
    return 0
}

# ================================
# PLAYLIST MANAGEMENT
# ================================

list_playlists() {
    echo "Available playlists:"
    echo "===================="

    if [ ! -d "$PLAYLIST_DIR" ]; then
        echo "No playlists found."
        return 1
    fi

    local count=0
    for playlist in "$PLAYLIST_DIR"/*.m3u; do
        if [ -f "$playlist" ]; then
            local name=$(basename "$playlist" .m3u)
            local file_count=$(grep -c "^file://" "$playlist" 2>/dev/null || echo "0")
            local size=$(du -h "$playlist" 2>/dev/null | cut -f1)
            local modified=$(stat -f%Sm "$playlist" 2>/dev/null || stat -c%y "$playlist" 2>/dev/null | cut -d' ' -f1)

            printf "%-20s %3d files %8s %12s\n" "$name" "$file_count" "$size" "$modified"
            count=$((count + 1))
        fi
    done

    if [ $count -eq 0 ]; then
        echo "No playlists found."
        return 1
    fi

    echo ""
    echo "Current playlist: $(basename "$CURRENT_PLAYLIST" .m3u 2>/dev/null || echo 'None')"
}

activate_playlist() {
    local name="$1"
    local playlist_file="$PLAYLIST_DIR/$name.m3u"

    if [ ! -f "$playlist_file" ]; then
        log_message "ERROR: Playlist not found: $name"
        return 1
    fi

    # Copy to current playlist
    cp "$playlist_file" "$CURRENT_PLAYLIST"
    log_message "Activated playlist: $name"

    # Restart VLC if it's running
    if pgrep -f "vlc\|cvlc" > /dev/null; then
        log_message "Restarting VLC with new playlist..."
        /opt/pisignage/scripts/vlc-control.sh restart
    fi

    return 0
}

delete_playlist() {
    local name="$1"
    local playlist_file="$PLAYLIST_DIR/$name.m3u"

    if [ ! -f "$playlist_file" ]; then
        log_message "ERROR: Playlist not found: $name"
        return 1
    fi

    # Don't delete if it's the current playlist
    if [ "$(readlink -f "$CURRENT_PLAYLIST")" = "$(readlink -f "$playlist_file")" ]; then
        log_message "ERROR: Cannot delete active playlist: $name"
        return 1
    fi

    rm "$playlist_file"
    log_message "Deleted playlist: $name"
    return 0
}

validate_playlist() {
    local playlist_file="$1"

    if [ ! -f "$playlist_file" ]; then
        echo "ERROR: Playlist file not found: $playlist_file"
        return 1
    fi

    local missing_files=0
    local total_files=0

    echo "Validating playlist: $(basename "$playlist_file")"
    echo "========================================"

    while IFS= read -r line; do
        if [[ $line == file://* ]]; then
            local file_path="${line#file://}"
            total_files=$((total_files + 1))

            if [ ! -f "$file_path" ]; then
                echo "MISSING: $file_path"
                missing_files=$((missing_files + 1))
            else
                echo "OK: $(basename "$file_path")"
            fi
        fi
    done < "$playlist_file"

    echo ""
    echo "Summary: $((total_files - missing_files))/$total_files files found"

    if [ $missing_files -gt 0 ]; then
        echo "WARNING: $missing_files files are missing!"
        return 1
    else
        echo "All files are accessible."
        return 0
    fi
}

# ================================
# MAIN SCRIPT LOGIC
# ================================

show_help() {
    cat << EOF
VLC Playlist Manager for PiSignage v0.8.0
Advanced playlist management with transitions and scheduling

Usage: $0 <command> [options]

Commands:
  create <name> [type]     - Create new playlist
    Types: basic (default), slideshow, mixed

  activate <name>          - Set playlist as current
  list                     - List all playlists
  validate <name>          - Check playlist file integrity
  delete <name>           - Delete playlist

  # Advanced playlist creation
  slideshow <name> [duration]  - Create slideshow (default: ${DEFAULT_IMAGE_DURATION}s)
  mixed <name> [video%]        - Create mixed playlist (default: 70% video)

Examples:
  $0 create default basic      # Create basic playlist with all media
  $0 slideshow photos 15       # Create 15-second slideshow
  $0 mixed content 60          # Create playlist with 60% videos, 40% images
  $0 activate default          # Switch to 'default' playlist
  $0 validate current          # Check current playlist

Directories:
  Media:     $MEDIA_DIR
  Playlists: $PLAYLIST_DIR
  Current:   $CURRENT_PLAYLIST

Supported formats:
  Video: ${VIDEO_FORMATS[*]}
  Image: ${IMAGE_FORMATS[*]}

EOF
}

case "${1:-help}" in
    create)
        name="${2:-default}"
        type="${3:-basic}"
        case "$type" in
            basic) create_basic_playlist "$name" ;;
            slideshow) create_slideshow_playlist "$name" ;;
            mixed) create_mixed_playlist "$name" ;;
            *) echo "Unknown playlist type: $type"; exit 1 ;;
        esac
        ;;
    slideshow)
        name="${2:-slideshow}"
        duration="${3:-$DEFAULT_IMAGE_DURATION}"
        create_slideshow_playlist "$name" "$duration"
        ;;
    mixed)
        name="${2:-mixed}"
        video_weight="${3:-70}"
        create_mixed_playlist "$name" "$video_weight"
        ;;
    activate)
        if [ -z "$2" ]; then
            echo "ERROR: Playlist name required"
            exit 1
        fi
        activate_playlist "$2"
        ;;
    list)
        list_playlists
        ;;
    validate)
        if [ -z "$2" ]; then
            validate_playlist "$CURRENT_PLAYLIST"
        else
            validate_playlist "$PLAYLIST_DIR/$2.m3u"
        fi
        ;;
    delete)
        if [ -z "$2" ]; then
            echo "ERROR: Playlist name required"
            exit 1
        fi
        delete_playlist "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Invalid command: $1"
        show_help
        exit 1
        ;;
esac

exit $?