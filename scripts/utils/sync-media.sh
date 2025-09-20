#!/bin/bash
#
# PiSignage Desktop v3.0 - Media Sync Utility
# Copyright (c) 2024 PiSignage
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PISIGNAGE_HOME="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_FILE="${PISIGNAGE_HOME}/config/default.conf"
SYNC_CONFIG="${PISIGNAGE_HOME}/config/sync/sync.conf"
VIDEO_PATH="${PISIGNAGE_HOME}/videos"
LOG_FILE="${PISIGNAGE_HOME}/logs/sync.log"

# Load configurations
source "${CONFIG_FILE}"
if [ -f "$SYNC_CONFIG" ]; then
    source "${SYNC_CONFIG}"
fi

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to sync media from server
sync_media() {
    if [ -z "$SYNC_SERVER" ] || [ -z "$SYNC_TOKEN" ]; then
        log "Sync server or token not configured"
        return 1
    fi
    
    log "Starting media sync from $SYNC_SERVER"
    
    # Get list of available media files
    local media_list=$(curl -s -H "Authorization: Bearer $SYNC_TOKEN" \
                       "$SYNC_SERVER/api/media/list")
    
    if [ $? -ne 0 ]; then
        log "Failed to get media list from server"
        return 1
    fi
    
    # Parse and download new files
    echo "$media_list" | jq -r '.[].filename' | while read filename; do
        if [ ! -f "$VIDEO_PATH/$filename" ]; then
            log "Downloading new file: $filename"
            curl -s -H "Authorization: Bearer $SYNC_TOKEN" \
                 -o "$VIDEO_PATH/$filename" \
                 "$SYNC_SERVER/api/media/download/$filename"
            
            if [ $? -eq 0 ]; then
                log "Successfully downloaded: $filename"
            else
                log "Failed to download: $filename"
                rm -f "$VIDEO_PATH/$filename"
            fi
        fi
    done
    
    log "Media sync completed"
}

# Main function
main() {
    if [ "$SYNC_ENABLED" != "true" ]; then
        exit 0
    fi
    
    log "Starting sync process"
    sync_media
}

# Run sync
main