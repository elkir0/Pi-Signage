#!/bin/bash

# SOLUTION 1: FFmpeg Optimisé pour PC x86_64
# Basé sur recherche exhaustive - Meilleure performance générale
# Cible: 25-60 FPS, 15-25% CPU sur x86_64

echo "🚀 SOLUTION 1: FFmpeg Optimisé x86_64"
echo "====================================="

VIDEO_FILE="${1:-/opt/pisignage/media/sintel.mp4}"
LOGFILE="/opt/pisignage/logs/ffmpeg-optimized.log"

# Vérifications préalables
if [ ! -f "$VIDEO_FILE" ]; then
    echo "❌ Erreur: Fichier vidéo non trouvé: $VIDEO_FILE"
    exit 1
fi

# Créer le répertoire de logs
mkdir -p "$(dirname "$LOGFILE")"

echo "📁 Fichier vidéo: $VIDEO_FILE"
echo "📝 Logs: $LOGFILE"

# Tuer les processus existants
pkill -9 ffmpeg vlc mplayer mpv 2>/dev/null
sleep 1

# Obtenir les informations du framebuffer
if [ -e /dev/fb0 ]; then
    FB_SIZE=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo "1280,800")
    FB_WIDTH=$(echo $FB_SIZE | cut -d',' -f1)
    FB_HEIGHT=$(echo $FB_SIZE | cut -d',' -f2)
    echo "📺 Framebuffer: ${FB_WIDTH}x${FB_HEIGHT}"
else
    FB_WIDTH=1280
    FB_HEIGHT=800
    echo "📺 Framebuffer par défaut: ${FB_WIDTH}x${FB_HEIGHT}"
fi

# ============================================================================
# OPTIMISATIONS BASÉES SUR RECHERCHE
# ============================================================================

echo
echo "🔧 OPTIMISATIONS APPLIQUÉES:"
echo "   ✅ Threads multiples (CPU cores automatique)"
echo "   ✅ Format pixel correct (rgb565le pour framebuffer)"
echo "   ✅ Résolution dynamique"
echo "   ✅ Boucle infinie optimisée (-stream_loop -1)"
echo "   ✅ Préchargement des données (-probesize, -analyzeduration)"
echo "   ✅ Buffer d'entrée optimisé"

# Détecter les capacités d'accélération matérielle
HW_ACCEL=""
HW_DECODER=""

# Test VAAPI pour Intel/AMD
if [ -e /dev/dri/renderD128 ]; then
    echo "   🎯 Test VAAPI (Intel/AMD)..."
    if timeout 5 ffmpeg -hwaccel vaapi -vaapi_device /dev/dri/renderD128 -i "$VIDEO_FILE" -t 1 -f null - 2>/dev/null; then
        HW_ACCEL="-hwaccel vaapi -vaapi_device /dev/dri/renderD128"
        HW_DECODER="-c:v h264_vaapi"
        echo "   ✅ VAAPI activé"
    else
        echo "   ❌ VAAPI non fonctionnel"
    fi
fi

# Test VDPAU pour NVIDIA legacy
if [ -z "$HW_ACCEL" ] && command -v nvidia-smi > /dev/null 2>&1; then
    echo "   🎯 Test VDPAU (NVIDIA)..."
    if timeout 5 ffmpeg -hwaccel vdpau -i "$VIDEO_FILE" -t 1 -f null - 2>/dev/null; then
        HW_ACCEL="-hwaccel vdpau"
        HW_DECODER="-c:v h264_vdpau"
        echo "   ✅ VDPAU activé"
    else
        echo "   ❌ VDPAU non fonctionnel"
    fi
fi

# Fallback: optimisations software
if [ -z "$HW_ACCEL" ]; then
    echo "   🔄 Mode software optimisé"
    # Utiliser tous les cores CPU disponibles
    CPU_THREADS=$(nproc)
    SOFTWARE_OPTS="-threads $CPU_THREADS"
else
    echo "   🚀 Accélération matérielle: $HW_ACCEL"
    SOFTWARE_OPTS=""
fi

echo
echo "🎬 DÉMARRAGE DE LA LECTURE..."

# ============================================================================
# COMMANDE FFMPEG OPTIMISÉE FINALE
# ============================================================================

# Version avec accélération matérielle si disponible
if [ -n "$HW_ACCEL" ]; then
    echo "Commande utilisée (Hardware):"
    echo "ffmpeg $HW_ACCEL $HW_DECODER -i \"$VIDEO_FILE\" \\"
    echo "       -vf \"scale=${FB_WIDTH}:${FB_HEIGHT}:flags=bilinear\" \\"
    echo "       -pix_fmt rgb565le -f fbdev -stream_loop -1 /dev/fb0"
    
    ffmpeg \
        $HW_ACCEL \
        $HW_DECODER \
        -probesize 50M \
        -analyzeduration 50M \
        -i "$VIDEO_FILE" \
        -vf "scale=${FB_WIDTH}:${FB_HEIGHT}:flags=bilinear" \
        -pix_fmt rgb565le \
        -f fbdev \
        -stream_loop -1 \
        -loglevel warning \
        /dev/fb0 > "$LOGFILE" 2>&1 &
        
else
    # Version software optimisée
    echo "Commande utilisée (Software optimisé):"
    echo "ffmpeg -re $SOFTWARE_OPTS -i \"$VIDEO_FILE\" \\"
    echo "       -vf \"scale=${FB_WIDTH}:${FB_HEIGHT}:flags=fast_bilinear\" \\"
    echo "       -pix_fmt rgb565le -f fbdev -stream_loop -1 /dev/fb0"
    
    ffmpeg \
        -re \
        $SOFTWARE_OPTS \
        -probesize 50M \
        -analyzeduration 50M \
        -i "$VIDEO_FILE" \
        -vf "scale=${FB_WIDTH}:${FB_HEIGHT}:flags=fast_bilinear" \
        -pix_fmt rgb565le \
        -f fbdev \
        -stream_loop -1 \
        -loglevel warning \
        /dev/fb0 > "$LOGFILE" 2>&1 &
fi

FFMPEG_PID=$!
echo "✅ FFmpeg démarré (PID: $FFMPEG_PID)"
echo

# ============================================================================
# MONITORING DE PERFORMANCE
# ============================================================================

echo "📊 MONITORING (30 secondes)..."
sleep 5

for i in {1..6}; do
    if ps -p $FFMPEG_PID > /dev/null; then
        CPU_USAGE=$(ps -p $FFMPEG_PID -o %cpu --no-headers 2>/dev/null | xargs)
        MEM_USAGE=$(ps -p $FFMPEG_PID -o %mem --no-headers 2>/dev/null | xargs)
        
        echo "[$i/6] CPU: ${CPU_USAGE}% | MEM: ${MEM_USAGE}%"
        
        # Vérifier les FPS dans les logs
        if [ -f "$LOGFILE" ]; then
            FPS_LINE=$(tail -10 "$LOGFILE" 2>/dev/null | grep -o "fps=[0-9.]*" | tail -1)
            if [ -n "$FPS_LINE" ]; then
                echo "       $FPS_LINE"
            fi
        fi
    else
        echo "❌ Processus FFmpeg arrêté de manière inattendue"
        break
    fi
    sleep 5
done

echo
echo "🎯 RÉSULTATS ATTENDUS:"
echo "   • Framerate: 24-60 FPS (selon vidéo source)"
echo "   • CPU usage: 15-25% sur x86_64"
echo "   • Qualité: Fluide sans saccades"
echo
echo "📝 Logs complets: $LOGFILE"
echo "⏹️  Pour arrêter: pkill -9 ffmpeg"

echo
echo "✅ SOLUTION 1 DÉPLOYÉE - FFmpeg Optimisé"