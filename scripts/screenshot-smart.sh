#!/bin/bash

# Script intelligent de capture pour Pi-Signage
# Extrait une frame de la vidéo en cours au lieu de capturer l'écran

OUTPUT="${1:-/opt/pisignage/web/assets/screenshots/current.png}"

# Trouver quelle vidéo est en cours de lecture
CURRENT_VIDEO=$(ps aux | grep -E "vlc.*\.mp4" | grep -v grep | sed -n 's/.*\(\/opt\/pisignage\/media\/[^ ]*\.mp4\).*/\1/p' | head -1)

if [ -z "$CURRENT_VIDEO" ]; then
    # Si aucune vidéo, prendre la première du dossier
    CURRENT_VIDEO=$(ls /opt/pisignage/media/*.mp4 2>/dev/null | head -1)
fi

if [ -n "$CURRENT_VIDEO" ] && [ -f "$CURRENT_VIDEO" ]; then
    echo "[$(date)] Extracting frame from: $CURRENT_VIDEO" >&2
    
    # Extraire une frame au milieu de la vidéo
    DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$CURRENT_VIDEO" 2>/dev/null | cut -d'.' -f1)
    if [ -z "$DURATION" ] || [ "$DURATION" -lt 2 ]; then
        POSITION="00:00:01"
    else
        MIDDLE=$((DURATION / 2))
        POSITION=$(printf "%02d:%02d:%02d" $((MIDDLE/3600)) $((MIDDLE%3600/60)) $((MIDDLE%60)))
    fi
    
    # Extraire la frame avec ffmpeg
    if ffmpeg -ss "$POSITION" -i "$CURRENT_VIDEO" -vframes 1 -q:v 2 -y "$OUTPUT" 2>/dev/null; then
        chmod 644 "$OUTPUT"
        echo "[$(date)] SUCCESS: Frame extracted at $POSITION" >&2
        echo "$OUTPUT"
        exit 0
    fi
fi

# Fallback: générer une image avec les infos de la vidéo
echo "[$(date)] Creating info image" >&2
VIDEO_NAME=$(basename "$CURRENT_VIDEO" 2>/dev/null || echo "Aucune vidéo")

convert -size 1280x720 xc:'#1e3a5f' \
    -gravity north -font Arial -pointsize 72 -fill white \
    -annotate +0+100 "Pi-Signage" \
    -gravity center -pointsize 36 \
    -annotate +0+0 "Lecture en cours:\n$VIDEO_NAME\n\n$(date '+%H:%M:%S')" \
    -gravity south -pointsize 24 \
    -annotate +0+50 "http://192.168.1.103" \
    "$OUTPUT" 2>/dev/null

chmod 644 "$OUTPUT"
echo "$OUTPUT"
exit 0
