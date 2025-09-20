#!/bin/bash

##############################################################################
# PiSignage YouTube Worker - Background Download Processor
# Version: 3.1.1 
# Date: 2025-09-20
# 
# Description: Process YouTube download queue in background
##############################################################################

QUEUE_FILE="/tmp/pisignage_youtube_queue.json"
LOCK_FILE="/tmp/pisignage_youtube_worker.lock"
MEDIA_DIR="/opt/pisignage/media"
MAX_CONCURRENT=2

# Create lock to prevent multiple workers
if [ -f "$LOCK_FILE" ] && kill -0 $(cat "$LOCK_FILE") 2>/dev/null; then
    echo "Worker already running"
    exit 0
fi

echo $$ > "$LOCK_FILE"

cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WORKER: $1"
}

update_queue_item() {
    local id="$1"
    local status="$2"
    local progress="$3"
    local message="$4"
    local error="$5"
    local output_file="$6"
    
    if [ ! -f "$QUEUE_FILE" ]; then
        return
    fi
    
    python3 -c "
import json
import sys

try:
    with open('$QUEUE_FILE', 'r') as f:
        queue = json.load(f)
    
    for item in queue:
        if item['id'] == '$id':
            item['status'] = '$status'
            if '$progress': item['progress'] = int('$progress')
            if '$message': item['message'] = '$message'
            if '$error': item['error'] = '$error'
            if '$output_file': item['output_file'] = '$output_file'
            if '$status' in ['completed', 'failed']:
                item['finished_at'] = '2025-09-20 17:35:49'
            break
    
    with open('$QUEUE_FILE', 'w') as f:
        json.dump(queue, f, indent=2)
        
except Exception as e:
    print(f'Error updating queue: {e}', file=sys.stderr)
"
}

process_queue() {
    if [ ! -f "$QUEUE_FILE" ]; then
        return
    fi
    
    local active_count=0
    local pending_items=()
    
    # Count active downloads and find pending items
    while IFS= read -r line; do
        if [[ $line == *'"status": "downloading"'* ]]; then
            ((active_count++))
        elif [[ $line == *'"status": "pending"'* ]]; then
            # Extract download ID from the line
            local id=$(echo "$line" | grep -o '"id": "[^"]*"' | cut -d'"' -f4)
            if [ -n "$id" ]; then
                pending_items+=("$id")
            fi
        fi
    done < "$QUEUE_FILE"
    
    # Start new downloads if under limit
    for pending_id in "${pending_items[@]}"; do
        if [ $active_count -ge $MAX_CONCURRENT ]; then
            break
        fi
        
        log "Starting download: $pending_id"
        start_download "$pending_id"
        ((active_count++))
    done
}

start_download() {
    local download_id="$1"
    
    # Extract download details from queue
    local download_data=$(python3 -c "
import json
try:
    with open('$QUEUE_FILE', 'r') as f:
        queue = json.load(f)
    for item in queue:
        if item['id'] == '$download_id':
            print(f\"{item['url']}|{item['quality']}|{item.get('custom_name', '')}\")
            break
except:
    pass
")
    
    if [ -z "$download_data" ]; then
        log "Download data not found for $download_id"
        return
    fi
    
    IFS='|' read -r url quality custom_name <<< "$download_data"
    
    update_queue_item "$download_id" "downloading" "0" "Download started" "" ""
    
    # Build command
    local cmd="/opt/pisignage/scripts/youtube-dl.sh '" 
    cmd+="$url"
    cmd+="' '$quality'"
    
    if [ -n "$custom_name" ]; then
        cmd+=" '$custom_name'"
    fi
    
    # Execute download
    log "Executing: $cmd"
    local output_file=$(eval "$cmd" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && [ -f "$output_file" ]; then
        log "Download completed: $output_file"
        update_queue_item "$download_id" "completed" "100" "Download completed" "" "$output_file"
    else
        log "Download failed: $output_file"
        update_queue_item "$download_id" "failed" "0" "Download failed" "$output_file" ""
    fi
}

# Main worker loop
log "Starting YouTube worker"

while true; do
    process_queue
    sleep 5
done
