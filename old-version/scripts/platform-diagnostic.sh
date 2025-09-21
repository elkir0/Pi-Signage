#!/bin/bash

# SCRIPT DE DIAGNOSTIC COMPLET - PERFORMANCE VIDÉO
# Identifie la plateforme et les capacités pour optimiser la lecture vidéo
# Basé sur recherche exhaustive des meilleures pratiques

echo "🔍 DIAGNOSTIC COMPLET - PERFORMANCE VIDÉO"
echo "========================================"
echo "Date: $(date)"
echo

# ============================================================================
# 1. IDENTIFICATION PLATEFORME
# ============================================================================

echo "📱 IDENTIFICATION PLATEFORME:"
ARCH=$(uname -m)
OS_INFO=$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
KERNEL=$(uname -r)

echo "Architecture: $ARCH"
echo "OS: $OS_INFO"
echo "Kernel: $KERNEL"

IS_RASPBERRY_PI=false
IS_ARM=false
IS_X86=false
GPU_TYPE="unknown"

case "$ARCH" in
    armv7l|aarch64)
        IS_ARM=true
        if [ -f /proc/device-tree/model ]; then
            PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null)
            if [[ "$PI_MODEL" == *"Raspberry Pi"* ]]; then
                IS_RASPBERRY_PI=true
                echo "Type: Raspberry Pi ($PI_MODEL)"
                GPU_TYPE="videocore"
            else
                echo "Type: ARM board (non-Pi)"
                GPU_TYPE="arm_generic"
            fi
        else
            echo "Type: ARM architecture"
            GPU_TYPE="arm_generic"
        fi
        ;;
    x86_64)
        IS_X86=true
        echo "Type: x86_64 PC"
        # Détecter le GPU
        if lspci | grep -i nvidia > /dev/null; then
            GPU_TYPE="nvidia"
        elif lspci | grep -i amd > /dev/null; then
            GPU_TYPE="amd"
        elif lspci | grep -i intel > /dev/null; then
            GPU_TYPE="intel"
        else
            GPU_TYPE="generic"
        fi
        echo "GPU détecté: $GPU_TYPE"
        ;;
    *)
        echo "Type: Architecture non reconnue"
        ;;
esac

echo

# ============================================================================
# 2. CAPACITÉS MATÉRIELLES
# ============================================================================

echo "🔧 CAPACITÉS MATÉRIELLES:"

# Mémoire
TOTAL_RAM=$(free -h | grep "Mem:" | awk '{print $2}')
echo "RAM totale: $TOTAL_RAM"

# CPU
CPU_CORES=$(nproc)
CPU_INFO=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)
echo "CPU: $CPU_CORES cores - $CPU_INFO"

# GPU pour Raspberry Pi
if [ "$IS_RASPBERRY_PI" = true ]; then
    if command -v vcgencmd > /dev/null; then
        GPU_MEM=$(vcgencmd get_mem gpu 2>/dev/null | cut -d'=' -f2)
        GPU_TEMP=$(vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2)
        echo "GPU Mémoire: $GPU_MEM"
        echo "GPU Température: $GPU_TEMP"
    fi
fi

# Décodeurs matériels disponibles
echo
echo "🎬 DÉCODEURS MATÉRIELS DISPONIBLES:"

# V4L2 M2M (Linux générique)
V4L2_DEVICES=$(ls /dev/video* 2>/dev/null | wc -l)
if [ $V4L2_DEVICES -gt 0 ]; then
    echo "✅ V4L2 M2M: $V4L2_DEVICES périphériques détectés"
    ls -la /dev/video* 2>/dev/null | head -3
else
    echo "❌ V4L2 M2M: Aucun périphérique détecté"
fi

# VAAPI (Intel/AMD)
if command -v vainfo > /dev/null; then
    echo "✅ VAAPI: Disponible"
    vainfo 2>/dev/null | grep -E "(VAProfile|VAEntrypoint)" | head -3
else
    echo "❌ VAAPI: Non disponible"
fi

# NVENC/NVDEC (NVIDIA)
if command -v nvidia-smi > /dev/null; then
    echo "✅ NVIDIA: Disponible"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1
else
    echo "❌ NVIDIA: Non disponible"
fi

# OpenMAX (Raspberry Pi legacy)
if [ -f /opt/vc/bin/vcgencmd ]; then
    echo "✅ OpenMAX IL: Disponible (legacy Pi)"
else
    echo "❌ OpenMAX IL: Non disponible"
fi

echo

# ============================================================================
# 3. LOGICIELS INSTALLÉS
# ============================================================================

echo "💿 LOGICIELS INSTALLÉS:"

# Players vidéo
declare -A PLAYERS=(
    ["ffmpeg"]="FFmpeg"
    ["vlc"]="VLC"
    ["mpv"]="MPV"
    ["mplayer"]="MPlayer"
    ["omxplayer"]="OMXPlayer"
    ["kodi"]="Kodi"
)

for cmd in "${!PLAYERS[@]}"; do
    if command -v $cmd > /dev/null; then
        version=$($cmd --version 2>/dev/null | head -1 | cut -d' ' -f1-3)
        echo "✅ ${PLAYERS[$cmd]}: $version"
    else
        echo "❌ ${PLAYERS[$cmd]}: Non installé"
    fi
done

echo

# ============================================================================
# 4. CONFIGURATION SYSTÈME
# ============================================================================

echo "⚙️ CONFIGURATION SYSTÈME:"

# Framebuffer
if [ -e /dev/fb0 ]; then
    FB_SIZE=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)
    echo "✅ Framebuffer: $FB_SIZE"
else
    echo "❌ Framebuffer: Non disponible"
fi

# Display
if [ -n "$DISPLAY" ]; then
    echo "✅ X11 Display: $DISPLAY"
    if command -v xrandr > /dev/null; then
        RESOLUTION=$(xrandr | grep '\*' | awk '{print $1}' | head -1)
        echo "   Résolution: $RESOLUTION"
    fi
else
    echo "❌ X11 Display: Non disponible"
fi

# Wayland
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "✅ Wayland: $WAYLAND_DISPLAY"
else
    echo "❌ Wayland: Non détecté"
fi

echo

# ============================================================================
# 5. TESTS DE PERFORMANCE
# ============================================================================

echo "🚀 TESTS DE PERFORMANCE:"

# Test fichier vidéo
TEST_VIDEO="/opt/pisignage/media/sintel.mp4"
if [ -f "$TEST_VIDEO" ]; then
    echo "✅ Fichier test: $TEST_VIDEO"
    
    # Analyser le codec
    if command -v ffprobe > /dev/null; then
        CODEC=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$TEST_VIDEO" 2>/dev/null)
        RESOLUTION=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$TEST_VIDEO" 2>/dev/null)
        FRAMERATE=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$TEST_VIDEO" 2>/dev/null)
        
        echo "   Codec: $CODEC"
        echo "   Résolution: $RESOLUTION"
        echo "   Framerate: $FRAMERATE"
    fi
else
    echo "❌ Fichier test: Non trouvé"
fi

echo

# ============================================================================
# 6. RECOMMANDATIONS BASÉES SUR LA PLATEFORME
# ============================================================================

echo "💡 RECOMMANDATIONS OPTIMALES:"

if [ "$IS_RASPBERRY_PI" = true ]; then
    echo "🥧 RASPBERRY PI DÉTECTÉ:"
    echo "   1. OMXPlayer (32-bit OS) - 0-3% CPU, H264 uniquement"
    echo "   2. VLC fullscreen + MMAL - 10-15% CPU, formats universels"
    echo "   3. Kodi/LibreELEC - Performance optimale pour media center"
    echo
    echo "   Commandes recommandées:"
    echo "   - gpu_mem=256 dans /boot/config.txt"
    echo "   - dtoverlay=vc4-fkms-v3d"
    echo "   - omxplayer --hw video.mp4"
    echo "   - vlc --vout=mmal_xsplitter video.mp4"
    
elif [ "$IS_ARM" = true ]; then
    echo "🔧 ARM BOARD DÉTECTÉ:"
    echo "   1. FFmpeg + h264_v4l2m2m - Si décodeur matériel disponible"
    echo "   2. MPV + hardware decoding - Bon compromis performance/qualité"
    echo "   3. VLC - Compatibilité universelle"
    
elif [ "$IS_X86" = true ]; then
    echo "💻 PC X86_64 DÉTECTÉ:"
    echo "   1. FFmpeg + accélération matérielle selon GPU:"
    case "$GPU_TYPE" in
        "nvidia")
            echo "      - ffmpeg -hwaccel cuda -c:v h264_cuvid"
            echo "      - ffplay -vcodec h264_cuvid"
            ;;
        "intel")
            echo "      - ffmpeg -hwaccel vaapi -vaapi_device /dev/dri/renderD128"
            echo "      - mpv --hwdec=vaapi"
            ;;
        "amd")
            echo "      - ffmpeg -hwaccel vaapi"
            echo "      - mpv --hwdec=vaapi"
            ;;
        *)
            echo "      - ffmpeg optimisé software avec threads multiples"
            echo "      - mpv avec décodage CPU optimisé"
            ;;
    esac
    echo "   2. VLC avec accélération matérielle auto-détectée"
    echo "   3. MPV - Meilleur player moderne pour Linux desktop"
fi

echo

# ============================================================================
# 7. DÉTECTION CAUSES DU PROBLÈME 3 FPS
# ============================================================================

echo "🐛 DIAGNOSTIC PROBLÈME 3 FPS:"

# Vérifications communes
echo "Causes possibles identifiées:"

# 1. Format pixel incorrect
echo "❗ Format pixel: Vérifier bgra vs rgb565le pour framebuffer"

# 2. Pas d'accélération matérielle
if [ $V4L2_DEVICES -eq 0 ] && [ "$GPU_TYPE" = "unknown" ]; then
    echo "❗ Accélération matérielle: Aucune détectée"
fi

# 3. Résolution incorrecte
if [ -e /dev/fb0 ]; then
    echo "❗ Résolution: Vérifier scale filter correspond au framebuffer"
fi

# 4. CPU surchargé
CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d',' -f1 | xargs)
if (( $(echo "$CPU_LOAD > 2.0" | bc -l 2>/dev/null || echo 0) )); then
    echo "❗ CPU: Charge élevée détectée ($CPU_LOAD)"
fi

# 5. Mémoire insuffisante
FREE_MEM=$(free | grep "Mem:" | awk '{printf "%.1f", $7/$2 * 100.0}')
if (( $(echo "$FREE_MEM < 20.0" | bc -l 2>/dev/null || echo 0) )); then
    echo "❗ Mémoire: Moins de 20% libre"
fi

echo

# ============================================================================
# 8. COMMANDES DE TEST RAPIDE
# ============================================================================

echo "🧪 COMMANDES DE TEST RAPIDE:"
echo
echo "# Test performance FFmpeg (10 secondes):"
echo "timeout 10 ffmpeg -i $TEST_VIDEO -f null - 2>&1 | tail -1"
echo
echo "# Test avec accélération matérielle:"
if [ $V4L2_DEVICES -gt 0 ]; then
    echo "timeout 10 ffmpeg -hwaccel v4l2m2m -c:v h264_v4l2m2m -i $TEST_VIDEO -f null -"
fi
echo
echo "# Monitoring CPU en temps réel:"
echo "top -p \$(pgrep ffmpeg) -d 1"
echo

echo "✅ DIAGNOSTIC TERMINÉ"
echo "Utilisez les recommandations ci-dessus pour optimiser la performance vidéo."