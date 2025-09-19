#!/bin/bash

echo "=== OPTIMISATION VIDEO POUR RASPBERRY PI ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'

# Stop everything first
echo "Arrêt de tout..."
sudo killall chromium 2>/dev/null
sudo killall chromium-browser 2>/dev/null
sudo killall mpv 2>/dev/null
sudo killall vlc 2>/dev/null
sudo systemctl stop nodm 2>/dev/null
sleep 3

# Download a lighter test video optimized for Raspberry Pi
echo ""
echo "Téléchargement d'une vidéo plus légère..."
cd /opt/videos
sudo rm -f light-video.mp4

# Download a 720p 30fps video (much lighter)
sudo wget -O light-video.mp4 "https://sample-videos.com/video321/mp4/480/big_buck_bunny_480p_10mb.mp4" 2>/dev/null || \
sudo wget -O light-video.mp4 "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4" 2>/dev/null

# Check file
ls -lh light-video.mp4

# Convert to even lighter format if needed
if command -v ffmpeg &> /dev/null; then
    echo "Création d'une version ultra-légère..."
    sudo ffmpeg -i light-video.mp4 -vf scale=640:360 -b:v 500k -preset ultrafast -y ultra-light.mp4 2>/dev/null
    VIDEO_FILE="/opt/videos/ultra-light.mp4"
else
    VIDEO_FILE="/opt/videos/light-video.mp4"
fi

# Make sure display is ready
export DISPLAY=:0
xset -dpms 2>/dev/null
xset s off 2>/dev/null
xset s noblank 2>/dev/null

echo ""
echo "Lancement avec paramètres optimisés pour Raspberry Pi..."

# Launch with optimized settings for Raspberry Pi
mpv --vo=gpu \
    --gpu-api=opengl \
    --hwdec=v4l2m2m-copy \
    --fs \
    --loop-file=inf \
    --no-osc \
    --no-osd-bar \
    --no-input-default-bindings \
    --video-sync=audio \
    --framedrop=yes \
    --cache=yes \
    --cache-secs=10 \
    --demuxer-max-bytes=50M \
    --demuxer-readahead-secs=10 \
    $VIDEO_FILE > /dev/null 2>&1 &

MPV_PID=$!
echo "MPV lancé avec PID: $MPV_PID"

sleep 5

# Verify it's running
if ps -p $MPV_PID > /dev/null; then
    echo "✓ MPV fonctionne"
    
    # Get performance info
    echo ""
    echo "Performance:"
    top -b -n1 -p $MPV_PID | tail -2
else
    echo "✗ MPV a crashé, essai avec paramètres minimaux..."
    
    # Ultra simple mode
    mpv --fs --loop-file=inf --really-quiet --vo=x11 $VIDEO_FILE &
fi

echo ""
echo "=== IMPORTANT ==="
echo "La vidéo légère devrait maintenant s'afficher avec un bon framerate!"
echo "Si l'icône Airplay réapparaît, c'est que nodm relance Chromium."
echo "Dans ce cas, désactivez nodm: sudo systemctl disable nodm"

EOF