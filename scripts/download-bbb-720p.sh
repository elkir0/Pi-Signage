#!/bin/bash
# Download Big Buck Bunny in 720p for PiSignage

MEDIA_DIR="/opt/pisignage/media"
LOG_FILE="/opt/pisignage/logs/download.log"

echo "📥 Téléchargement Big Buck Bunny 720p HD..."

# Create logs directory if needed
mkdir -p /opt/pisignage/logs

# Remove old 320x180 version if exists
if [ -f "$MEDIA_DIR/BigBuckBunny.mp4" ]; then
    echo "Suppression ancienne version 320x180..."
    rm -f "$MEDIA_DIR/BigBuckBunny.mp4"
fi

# Download 720p version
echo "Téléchargement version 720p (60fps)..."
wget -O "$MEDIA_DIR/BigBuckBunny_720p.mp4" \
     --progress=bar:force \
     "https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_720p60.mp4" 2>&1 | \
     tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Téléchargement réussi : BigBuckBunny_720p.mp4"
    echo "📊 Taille : $(du -h "$MEDIA_DIR/BigBuckBunny_720p.mp4" | cut -f1)"

    # Set permissions
    chown www-data:www-data "$MEDIA_DIR/BigBuckBunny_720p.mp4"
    chmod 644 "$MEDIA_DIR/BigBuckBunny_720p.mp4"
else
    echo "❌ Erreur lors du téléchargement"
    exit 1
fi