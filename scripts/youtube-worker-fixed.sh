#!/bin/bash

QUEUE_FILE="/tmp/pisignage_youtube_queue.json"
LOCK_FILE="/tmp/pisignage_youtube_worker.lock"

# Create lock
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

log "Starting YouTube worker v2"

while true; do
    if [ -f "$QUEUE_FILE" ]; then
        # Find pending downloads
        python3 -c "
import json
import subprocess
import os

try:
    with open('$QUEUE_FILE', 'r') as f:
        queue = json.load(f)
    
    for item in queue:
        if item['status'] == 'pending':
            print(f'Processing: {item[\"id\"]}')
            
            # Update status to downloading
            item['status'] = 'downloading'
            item['started_at'] = '2025-09-20 17:37:42'
            
            # Save updated queue
            with open('$QUEUE_FILE', 'w') as f:
                json.dump(queue, f, indent=2)
            
            # Build command
            cmd = ['/opt/pisignage/scripts/youtube-dl.sh', item['url'], item['quality']]
            if item.get('custom_name'):
                cmd.append(item['custom_name'])
            
            print(f'Executing: {\" \".join(cmd)}')
            
            # Execute download
            try:
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode == 0:
                    output_file = result.stdout.strip()
                    item['status'] = 'completed'
                    item['progress'] = 100
                    item['message'] = 'Download completed'
                    item['output_file'] = output_file
                    print(f'Success: {output_file}')
                else:
                    item['status'] = 'failed' 
                    item['error'] = result.stderr
                    print(f'Failed: {result.stderr}')
            except Exception as e:
                item['status'] = 'failed'
                item['error'] = str(e)
                print(f'Exception: {e}')
            
            item['finished_at'] = '2025-09-20 17:37:42'
            
            # Save final status
            with open('$QUEUE_FILE', 'w') as f:
                json.dump(queue, f, indent=2)
            
            break  # Process one at a time
            
except Exception as e:
    print(f'Error: {e}')
"
    fi
    
    sleep 10
done
