#!/bin/bash
# PiSignage v0.8.0 - YouTube Download Script
# Downloads videos from YouTube using yt-dlp

MEDIA_DIR="/opt/pisignage/media"
LOG_FILE="/opt/pisignage/logs/youtube.log"
TEMP_DIR="/tmp/pisignage-youtube"

# Create directories if they don't exist
mkdir -p "$MEDIA_DIR"
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$TEMP_DIR"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$1"
}

check_dependencies() {
    if ! command -v yt-dlp >/dev/null 2>&1; then
        if command -v youtube-dl >/dev/null 2>&1; then
            YT_DL_CMD="youtube-dl"
            log_message "Using youtube-dl (yt-dlp not found)"
        else
            log_message "Error: Neither yt-dlp nor youtube-dl found"
            echo "Please install yt-dlp or youtube-dl:"
            echo "  sudo pip3 install yt-dlp"
            echo "  # or"
            echo "  sudo apt-get install youtube-dl"
            return 1
        fi
    else
        YT_DL_CMD="yt-dlp"
        log_message "Using yt-dlp"
    fi

    return 0
}

sanitize_filename() {
    local filename="$1"
    # Remove or replace problematic characters
    echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g'
}

get_video_info() {
    local url="$1"

    log_message "Getting video info for: $url"

    if ! check_dependencies; then
        return 1
    fi

    local info_json=$($YT_DL_CMD --dump-json --no-download "$url" 2>/dev/null)

    if [[ $? -ne 0 || -z "$info_json" ]]; then
        log_message "Failed to get video information"
        return 1
    fi

    echo "$info_json"
    return 0
}

download_video() {
    local url="$1"
    local quality="$2"
    local custom_name="$3"

    log_message "Starting download: $url (quality: $quality)"

    if ! check_dependencies; then
        return 1
    fi

    # Validate URL
    if [[ ! "$url" =~ ^https?://(www\.)?(youtube\.com|youtu\.be) ]]; then
        log_message "Error: Invalid YouTube URL"
        return 1
    fi

    # Get video info
    local info_json=$(get_video_info "$url")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Extract title and duration
    local title=$(echo "$info_json" | grep -o '"title": *"[^"]*"' | head -1 | sed 's/"title": *"\(.*\)"/\1/')
    local duration=$(echo "$info_json" | grep -o '"duration": *[0-9]*' | head -1 | sed 's/"duration": *\([0-9]*\)/\1/')

    if [[ -z "$title" ]]; then
        title="youtube_video_$(date +%s)"
    fi

    # Sanitize filename
    local safe_title=$(sanitize_filename "$title")

    # Use custom name if provided
    if [[ -n "$custom_name" ]]; then
        safe_title=$(sanitize_filename "$custom_name")
    fi

    log_message "Video title: $title"
    log_message "Duration: ${duration}s"

    # Set quality format
    local format=""
    case "$quality" in
        "best")
            format="best[ext=mp4]/best"
            ;;
        "worst")
            format="worst[ext=mp4]/worst"
            ;;
        "720p")
            format="best[height<=720][ext=mp4]/best[height<=720]/best[ext=mp4]/best"
            ;;
        "480p")
            format="best[height<=480][ext=mp4]/best[height<=480]/best[ext=mp4]/best"
            ;;
        "360p")
            format="best[height<=360][ext=mp4]/best[height<=360]/best[ext=mp4]/best"
            ;;
        *)
            format="best[ext=mp4]/best"
            ;;
    esac

    # Set output template
    local output_template="$TEMP_DIR/${safe_title}.%(ext)s"

    log_message "Downloading with format: $format"

    # Download the video
    $YT_DL_CMD \
        --format "$format" \
        --output "$output_template" \
        --no-playlist \
        --extract-flat false \
        "$url"

    if [[ $? -ne 0 ]]; then
        log_message "Download failed"
        return 1
    fi

    # Find the downloaded file
    local downloaded_file=$(find "$TEMP_DIR" -name "${safe_title}.*" -type f | head -1)

    if [[ -z "$downloaded_file" || ! -f "$downloaded_file" ]]; then
        log_message "Error: Downloaded file not found"
        return 1
    fi

    # Get file extension
    local extension="${downloaded_file##*.}"

    # Final filename
    local final_filename="${safe_title}.${extension}"
    local final_path="$MEDIA_DIR/$final_filename"

    # Check if file already exists and generate unique name
    local counter=1
    while [[ -f "$final_path" ]]; do
        final_filename="${safe_title}_${counter}.${extension}"
        final_path="$MEDIA_DIR/$final_filename"
        counter=$((counter + 1))
    done

    # Move to media directory
    if mv "$downloaded_file" "$final_path"; then
        log_message "Download completed: $final_filename"
        log_message "File size: $(du -h "$final_path" | cut -f1)"

        # Cleanup temp directory
        rm -rf "$TEMP_DIR"/*

        echo "$final_path"
        return 0
    else
        log_message "Error: Failed to move file to media directory"
        return 1
    fi
}

download_audio() {
    local url="$1"
    local custom_name="$2"

    log_message "Starting audio download: $url"

    if ! check_dependencies; then
        return 1
    fi

    # Get video info
    local info_json=$(get_video_info "$url")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    local title=$(echo "$info_json" | grep -o '"title": *"[^"]*"' | head -1 | sed 's/"title": *"\(.*\)"/\1/')

    if [[ -z "$title" ]]; then
        title="youtube_audio_$(date +%s)"
    fi

    local safe_title=$(sanitize_filename "$title")

    if [[ -n "$custom_name" ]]; then
        safe_title=$(sanitize_filename "$custom_name")
    fi

    local output_template="$TEMP_DIR/${safe_title}.%(ext)s"

    # Download audio only
    $YT_DL_CMD \
        --format "bestaudio[ext=m4a]/bestaudio[ext=mp3]/bestaudio" \
        --extract-audio \
        --audio-format mp3 \
        --audio-quality 0 \
        --output "$output_template" \
        --no-playlist \
        "$url"

    if [[ $? -ne 0 ]]; then
        log_message "Audio download failed"
        return 1
    fi

    # Find the downloaded file
    local downloaded_file=$(find "$TEMP_DIR" -name "${safe_title}.*" -type f | head -1)

    if [[ -z "$downloaded_file" || ! -f "$downloaded_file" ]]; then
        log_message "Error: Downloaded audio file not found"
        return 1
    fi

    local extension="${downloaded_file##*.}"
    local final_filename="${safe_title}.${extension}"
    local final_path="$MEDIA_DIR/$final_filename"

    # Handle existing files
    local counter=1
    while [[ -f "$final_path" ]]; do
        final_filename="${safe_title}_${counter}.${extension}"
        final_path="$MEDIA_DIR/$final_filename"
        counter=$((counter + 1))
    done

    if mv "$downloaded_file" "$final_path"; then
        log_message "Audio download completed: $final_filename"
        rm -rf "$TEMP_DIR"/*
        echo "$final_path"
        return 0
    else
        log_message "Error: Failed to move audio file to media directory"
        return 1
    fi
}

list_formats() {
    local url="$1"

    if ! check_dependencies; then
        return 1
    fi

    log_message "Listing available formats for: $url"

    $YT_DL_CMD --list-formats "$url"
}

update_ytdl() {
    log_message "Updating yt-dlp/youtube-dl"

    if command -v yt-dlp >/dev/null 2>&1; then
        yt-dlp --update
    elif command -v youtube-dl >/dev/null 2>&1; then
        sudo pip3 install --upgrade youtube-dl
    else
        log_message "No YouTube downloader found to update"
        return 1
    fi
}

install_dependencies() {
    log_message "Installing YouTube download dependencies"

    echo "Installing yt-dlp..."
    sudo pip3 install yt-dlp

    if [[ $? -eq 0 ]]; then
        log_message "yt-dlp installed successfully"
    else
        echo "Installing youtube-dl as fallback..."
        sudo apt-get update
        sudo apt-get install -y youtube-dl
        log_message "youtube-dl installed as fallback"
    fi

    # Install ffmpeg for format conversion
    echo "Installing ffmpeg..."
    sudo apt-get install -y ffmpeg
    log_message "ffmpeg installed"
}

show_status() {
    echo "YouTube Downloader Status:"
    echo "========================="
    echo "Media directory: $MEDIA_DIR"
    echo "Log file: $LOG_FILE"
    echo "Temp directory: $TEMP_DIR"
    echo ""

    if command -v yt-dlp >/dev/null 2>&1; then
        echo "✓ yt-dlp: $(yt-dlp --version)"
    elif command -v youtube-dl >/dev/null 2>&1; then
        echo "✓ youtube-dl: $(youtube-dl --version)"
    else
        echo "✗ No YouTube downloader found"
    fi

    if command -v ffmpeg >/dev/null 2>&1; then
        echo "✓ ffmpeg: $(ffmpeg -version | head -1)"
    else
        echo "✗ ffmpeg not found"
    fi

    echo ""
    local video_count=$(find "$MEDIA_DIR" -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" | wc -l)
    local audio_count=$(find "$MEDIA_DIR" -name "*.mp3" -o -name "*.m4a" -o -name "*.ogg" | wc -l)
    echo "Videos in media directory: $video_count"
    echo "Audio files in media directory: $audio_count"
}

# Main script logic
case "$1" in
    download|dl)
        url="$2"
        quality="${3:-best}"
        custom_name="$4"

        if [[ -z "$url" ]]; then
            echo "Error: URL required"
            exit 1
        fi

        download_video "$url" "$quality" "$custom_name"
        ;;
    audio)
        url="$2"
        custom_name="$3"

        if [[ -z "$url" ]]; then
            echo "Error: URL required"
            exit 1
        fi

        download_audio "$url" "$custom_name"
        ;;
    info)
        url="$2"

        if [[ -z "$url" ]]; then
            echo "Error: URL required"
            exit 1
        fi

        get_video_info "$url"
        ;;
    formats)
        url="$2"

        if [[ -z "$url" ]]; then
            echo "Error: URL required"
            exit 1
        fi

        list_formats "$url"
        ;;
    update)
        update_ytdl
        ;;
    install)
        install_dependencies
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {download|audio|info|formats|update|install|status} [url] [quality] [name]"
        echo ""
        echo "Commands:"
        echo "  download <url> [quality] [name]  - Download video"
        echo "  audio <url> [name]               - Download audio only"
        echo "  info <url>                       - Get video information"
        echo "  formats <url>                    - List available formats"
        echo "  update                           - Update yt-dlp/youtube-dl"
        echo "  install                          - Install dependencies"
        echo "  status                           - Show downloader status"
        echo ""
        echo "Quality options: best, worst, 720p, 480p, 360p"
        exit 1
        ;;
esac

exit $?