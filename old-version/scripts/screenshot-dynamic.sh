#!/bin/bash

# Script de capture dynamique pour Pi-Signage
OUTPUT="${1:-/opt/pisignage/web/assets/screenshots/current.png}"

# Trouver quelle vidéo est en cours
CURRENT_VIDEO=$(ps aux | grep -E "vlc.*\.mp4" | grep -v grep | sed -n 's/.*\(\/opt\/pisignage\/media\/[^ ]*\.mp4\).*/\1/p' | head -1)

if [ -z "$CURRENT_VIDEO" ]; then
    CURRENT_VIDEO=$(ls /opt/pisignage/media/*.mp4 2>/dev/null | head -1)
fi

if [ -n "$CURRENT_VIDEO" ] && [ -f "$CURRENT_VIDEO" ]; then
    echo "[$(date)] Extracting frame from: $CURRENT_VIDEO" >&2
    
    # Obtenir la durée de la vidéo
    DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$CURRENT_VIDEO" 2>/dev/null | cut -d'.' -f1)
    
    if [ -z "$DURATION" ] || [ "$DURATION" -lt 2 ]; then
        POSITION="00:00:01"
    else
        # Position aléatoire dans la vidéo (pas au début ni à la fin)
        SAFE_DURATION=$((DURATION - 2))
        RANDOM_POS=$((1 + RANDOM % SAFE_DURATION))
        POSITION=$(printf "%02d:%02d:%02d" $((RANDOM_POS/3600)) $((RANDOM_POS%3600/60)) $((RANDOM_POS%60)))
    fi
    
    # Supprimer l'ancienne image pour forcer la mise à jour
    rm -f "$OUTPUT" 2>/dev/null
    
    # Extraire la frame
    if ffmpeg -ss "$POSITION" -i "$CURRENT_VIDEO" -vframes 1 -q:v 2 -y "$OUTPUT" 2>/dev/null; then
        chmod 644 "$OUTPUT"
        echo "[$(date)] SUCCESS: Frame extracted at $POSITION" >&2
        # Ajouter un timestamp pour forcer le rechargement
        echo "$OUTPUT?t=$(date +%s)"
        exit 0
    fi
fi

# Fallback avec info mise à jour
echo "[$(date)] Creating info image" >&2
VIDEO_NAME=$(basename "$CURRENT_VIDEO" 2>/dev/null || echo "Aucune vidéo")
TIMESTAMP=$(date '+%H:%M:%S')

convert -size 1280x720 xc:'#1e3a5f' \
    -gravity north -font Arial -pointsize 72 -fill white \
    -annotate +0+100 "Pi-Signage" \
    -gravity center -pointsize 36 \
    -annotate +0+0 "Capture: $TIMESTAMP\n$VIDEO_NAME" \
    -gravity south -pointsize 24 \
    -annotate +0+50 "http://192.168.1.103" \
    "$OUTPUT" 2>/dev/null

chmod 644 "$OUTPUT"
echo "$OUTPUT?t=$(date +%s)"
exit 0
