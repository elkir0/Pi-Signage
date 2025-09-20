#!/bin/bash
#
# PiSignage Desktop v3.0 - Media Player Control Script
# Copyright (c) 2024 PiSignage
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PISIGNAGE_HOME="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_FILE="${PISIGNAGE_HOME}/config/default.conf"
VIDEO_PATH="${PISIGNAGE_HOME}/videos"
LOG_FILE="${PISIGNAGE_HOME}/logs/player.log"

# Load configuration
source "${CONFIG_FILE}"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to play videos with VLC
play_with_vlc() {
    local video_file="$1"
    log "Playing video with VLC: $video_file"
    
    vlc --intf dummy \
        --no-video-title-show \
        --fullscreen \
        --no-osd \
        --loop \
        "$video_file" \
        2>> "$LOG_FILE"
}

# Function to play videos with MPV
play_with_mpv() {
    local video_file="$1"
    log "Playing video with MPV: $video_file"
    
    mpv --no-terminal \
        --fullscreen \
        --loop \
        --no-osc \
        --no-input-default-bindings \
        "$video_file" \
        2>> "$LOG_FILE"
}

# Main player loop
main() {
    log "Starting PiSignage Player"
    
    # Wait for display to be ready
    sleep 5
    
    # Hide cursor
    unclutter -display :0 -noevents -grab &
    
    while true; do
        # Get list of video files
        video_files=($(find "$VIDEO_PATH" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" -o -name "*.webm" \) 2>/dev/null))
        
        if [ ${#video_files[@]} -eq 0 ]; then
            log "No video files found in $VIDEO_PATH"
            sleep 10
            continue
        fi
        
        # Play videos
        for video in "${video_files[@]}"; do
            case "$DEFAULT_PLAYER" in
                "vlc")
                    play_with_vlc "$video"
                    ;;
                "mpv")
                    play_with_mpv "$video"
                    ;;
                *)
                    log "Unknown player: $DEFAULT_PLAYER, defaulting to VLC"
                    play_with_vlc "$video"
                    ;;
            esac
            
            # Check if we should continue
            if [ ! -f "$video" ]; then
                log "Video file removed: $video"
                break
            fi
        done
        
        sleep 2
    done
}

# Start the player
main