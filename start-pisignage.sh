#!/bin/bash

# PiSignage v0.8.0 - Script de démarrage principal
# Lance VLC en plein écran avec bandeau RSS en overlay

echo "🚀 Démarrage PiSignage v0.8.0..."

# Configuration
MEDIA_DIR="/opt/pisignage/media"
WEB_DIR="/opt/pisignage/web"
LOG_DIR="/opt/pisignage/logs"
PLAYLIST="$MEDIA_DIR/playlist.m3u"

# Créer les répertoires nécessaires
mkdir -p "$LOG_DIR"
mkdir -p "$MEDIA_DIR"

# Arrêter les processus existants
echo "Arrêt des processus existants..."
sudo killall -9 vlc chromium-browser chromium 2>/dev/null
sleep 2

# Créer la playlist par défaut si elle n'existe pas
if [ ! -f "$PLAYLIST" ]; then
    echo "Création de la playlist par défaut..."
    cat > "$PLAYLIST" << EOF
#EXTM3U
#EXTINF:-1,Big Buck Bunny
$MEDIA_DIR/big_buck_bunny_original.mp4
#EXTINF:-1,Big Buck Bunny Optimized
$MEDIA_DIR/big_buck_bunny_optimized.mp4
#EXTINF:-1,Jellyfish Original
$MEDIA_DIR/jellyfish_original.mp4
#EXTINF:-1,Jellyfish Optimized
$MEDIA_DIR/jellyfish_optimized.mp4
EOF
fi

# Vérifier qu'il y a des vidéos
VIDEO_COUNT=$(find "$MEDIA_DIR" -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" 2>/dev/null | wc -l)
if [ "$VIDEO_COUNT" -eq 0 ]; then
    echo "⚠️ Aucune vidéo trouvée dans $MEDIA_DIR"
    echo "Téléchargement d'une vidéo de démonstration..."
    wget -q "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" \
         -O "$MEDIA_DIR/demo.mp4" 2>/dev/null || true
fi

echo "📺 Lancement de VLC avec accélération GPU..."

# Déterminer les options VLC optimales
VLC_OPTIONS=""
if vlc --list 2>/dev/null | grep -q mmal; then
    echo "✅ Accélération MMAL détectée"
    VLC_OPTIONS="--vout=mmal_vout --codec=mmal --avcodec-hw=mmal"
elif vlc --list 2>/dev/null | grep -q gles2; then
    echo "✅ Accélération OpenGL ES détectée"
    VLC_OPTIONS="--vout=gles2"
else
    echo "⚠️ Utilisation du rendu logiciel"
    VLC_OPTIONS=""
fi

# Lancer VLC en plein écran (layer 0)
DISPLAY=:0 cvlc \
    --fullscreen \
    --no-osd \
    --no-video-title-show \
    --loop \
    --no-audio \
    --intf http \
    --http-host 0.0.0.0 \
    --http-password pisignage \
    $VLC_OPTIONS \
    --file-caching=1000 \
    --network-caching=1000 \
    --drop-late-frames \
    --skip-frames \
    "$PLAYLIST" \
    > "$LOG_DIR/vlc.log" 2>&1 &

VLC_PID=$!
echo "VLC lancé (PID: $VLC_PID)"

# Attendre que VLC démarre
sleep 3

# Lancer le bandeau RSS en overlay (layer 1)
echo "🌐 Lancement du bandeau RSS..."

# S'assurer que le serveur web est actif
if ! systemctl is-active --quiet nginx; then
    echo "Démarrage de nginx..."
    sudo systemctl start nginx
fi

# Lancer Chromium avec le bandeau RSS en overlay transparent
DISPLAY=:0 chromium-browser \
    --app="http://localhost/rss-overlay.html" \
    --window-position=0,0 \
    --window-size=1920,30 \
    --kiosk \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu-sandbox \
    --enable-features=VaapiVideoDecoder \
    --disable-features=UseChromeOSDirectVideoDecoder \
    --autoplay-policy=no-user-gesture-required \
    > "$LOG_DIR/chromium-rss.log" 2>&1 &

CHROMIUM_PID=$!
echo "Bandeau RSS lancé (PID: $CHROMIUM_PID)"

echo ""
echo "✅ PiSignage démarré avec succès!"
echo ""
echo "📊 Statut:"
echo "  • VLC: PID $VLC_PID (vidéo plein écran)"
echo "  • RSS: PID $CHROMIUM_PID (bandeau 30px)"
echo "  • Interface: http://$(hostname -I | awk '{print $1}')/"
echo ""
echo "📝 Commandes utiles:"
echo "  • Arrêter: sudo killall vlc chromium-browser"
echo "  • Logs VLC: tail -f $LOG_DIR/vlc.log"
echo "  • Logs RSS: tail -f $LOG_DIR/chromium-rss.log"
echo ""

# Monitoring - relancer si crash
while true; do
    if ! kill -0 $VLC_PID 2>/dev/null; then
        echo "⚠️ VLC s'est arrêté, redémarrage..."
        exec "$0"
    fi
    sleep 10
done