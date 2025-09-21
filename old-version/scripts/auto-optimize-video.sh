#!/bin/bash

# SCRIPT DE CONFIGURATION AUTOMATIQUE
# Détecte la plateforme et applique la meilleure solution automatiquement
# Basé sur recherche exhaustive des meilleures pratiques

echo "🤖 AUTO-OPTIMISATION VIDÉO INTELLIGENTE"
echo "========================================"
echo "Basé sur recherche exhaustive - Solutions éprouvées"
echo "Date: $(date)"
echo

VIDEO_FILE="${1:-/opt/pisignage/media/sintel.mp4}"
FORCE_SOLUTION="${2:-auto}"

if [ ! -f "$VIDEO_FILE" ]; then
    echo "❌ Erreur: Fichier vidéo non trouvé: $VIDEO_FILE"
    echo "💡 Usage: $0 [video_file] [force_solution]"
    echo "   force_solution: auto|1|2|3|raspberry|test"
    exit 1
fi

echo "📁 Fichier vidéo: $VIDEO_FILE"
echo "🎯 Mode: $FORCE_SOLUTION"
echo

# ============================================================================
# 1. DIAGNOSTIC AUTOMATIQUE
# ============================================================================

echo "🔍 DIAGNOSTIC AUTOMATIQUE:"

# Détecter l'architecture
ARCH=$(uname -m)
IS_RASPBERRY_PI=false
IS_ARM=false
IS_X86=false

case "$ARCH" in
    armv7l|aarch64)
        IS_ARM=true
        if [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
            IS_RASPBERRY_PI=true
            PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null)
            echo "   🥧 Raspberry Pi détecté: $PI_MODEL"
        else
            echo "   🔧 Board ARM générique"
        fi
        ;;
    x86_64)
        IS_X86=true
        echo "   💻 PC x86_64 détecté"
        ;;
    *)
        echo "   ❓ Architecture inconnue: $ARCH"
        ;;
esac

# Détecter les capacités
FFMPEG_AVAILABLE=$(command -v ffmpeg > /dev/null && echo "true" || echo "false")
VLC_AVAILABLE=$(command -v vlc > /dev/null && echo "true" || echo "false")
MPV_AVAILABLE=$(command -v mpv > /dev/null && echo "true" || echo "false")
OMXPLAYER_AVAILABLE=$(command -v omxplayer > /dev/null && echo "true" || echo "false")

echo "   📦 FFmpeg: $FFMPEG_AVAILABLE"
echo "   📦 VLC: $VLC_AVAILABLE"
echo "   📦 MPV: $MPV_AVAILABLE"
echo "   📦 OMXPlayer: $OMXPLAYER_AVAILABLE"

# Détecter accélération matérielle
HW_ACCELERATION=""
if [ -e /dev/dri/renderD128 ]; then
    HW_ACCELERATION="VAAPI"
elif [ -e /dev/video11 ]; then
    HW_ACCELERATION="V4L2_M2M"
elif command -v nvidia-smi > /dev/null 2>&1; then
    HW_ACCELERATION="NVIDIA"
elif [ "$IS_RASPBERRY_PI" = true ]; then
    HW_ACCELERATION="VIDEOCORE"
else
    HW_ACCELERATION="SOFTWARE"
fi
echo "   🚀 Accélération: $HW_ACCELERATION"

echo

# ============================================================================
# 2. SÉLECTION AUTOMATIQUE DE LA MEILLEURE SOLUTION
# ============================================================================

RECOMMENDED_SOLUTION=""
SOLUTION_REASON=""

if [ "$FORCE_SOLUTION" != "auto" ]; then
    case "$FORCE_SOLUTION" in
        "1"|"ffmpeg")
            RECOMMENDED_SOLUTION="1"
            SOLUTION_REASON="Forcé par utilisateur"
            ;;
        "2"|"mpv")
            RECOMMENDED_SOLUTION="2"
            SOLUTION_REASON="Forcé par utilisateur"
            ;;
        "3"|"vlc")
            RECOMMENDED_SOLUTION="3"
            SOLUTION_REASON="Forcé par utilisateur"
            ;;
        "raspberry")
            RECOMMENDED_SOLUTION="raspberry"
            SOLUTION_REASON="Mode Raspberry Pi spécialisé"
            ;;
        "test")
            RECOMMENDED_SOLUTION="test"
            SOLUTION_REASON="Mode test/benchmark"
            ;;
        *)
            echo "❌ Solution forcée invalide: $FORCE_SOLUTION"
            exit 1
            ;;
    esac
else
    # Logique de sélection automatique basée sur recherche
    if [ "$IS_RASPBERRY_PI" = true ]; then
        if [ "$OMXPLAYER_AVAILABLE" = true ]; then
            RECOMMENDED_SOLUTION="raspberry"
            SOLUTION_REASON="Raspberry Pi + OMXPlayer = Performance optimale (0-3% CPU)"
        elif [ "$VLC_AVAILABLE" = true ]; then
            RECOMMENDED_SOLUTION="3"
            SOLUTION_REASON="Raspberry Pi + VLC = Compatibilité universelle"
        elif [ "$FFMPEG_AVAILABLE" = true ]; then
            RECOMMENDED_SOLUTION="1"
            SOLUTION_REASON="Raspberry Pi + FFmpeg = Fallback performant"
        else
            echo "❌ Aucun player vidéo installé sur Raspberry Pi"
            exit 1
        fi
    elif [ "$IS_X86" = true ]; then
        if [ "$HW_ACCELERATION" = "VAAPI" ] && [ "$MPV_AVAILABLE" = true ]; then
            RECOMMENDED_SOLUTION="2"
            SOLUTION_REASON="x86_64 + VAAPI + MPV = Meilleure qualité moderne"
        elif [ "$FFMPEG_AVAILABLE" = true ]; then
            RECOMMENDED_SOLUTION="1"
            SOLUTION_REASON="x86_64 + FFmpeg = Performance éprouvée"
        elif [ "$VLC_AVAILABLE" = true ]; then
            RECOMMENDED_SOLUTION="3"
            SOLUTION_REASON="x86_64 + VLC = Compatibilité universelle"
        else
            echo "❌ Aucun player vidéo installé"
            exit 1
        fi
    else
        # ARM générique ou autre
        if [ "$FFMPEG_AVAILABLE" = true ]; then
            RECOMMENDED_SOLUTION="1"
            SOLUTION_REASON="Architecture générique + FFmpeg = Plus compatible"
        elif [ "$VLC_AVAILABLE" = true ]; then
            RECOMMENDED_SOLUTION="3"
            SOLUTION_REASON="Architecture générique + VLC = Fallback universel"
        else
            echo "❌ Aucun player vidéo approprié installé"
            exit 1
        fi
    fi
fi

echo "🎯 SOLUTION RECOMMANDÉE: $RECOMMENDED_SOLUTION"
echo "📋 Raison: $SOLUTION_REASON"
echo

# ============================================================================
# 3. EXÉCUTION DE LA SOLUTION OPTIMALE
# ============================================================================

case "$RECOMMENDED_SOLUTION" in
    "1")
        echo "🚀 LANCEMENT SOLUTION 1: FFmpeg Optimisé"
        /opt/pisignage/scripts/solution-1-ffmpeg-optimized.sh "$VIDEO_FILE"
        ;;
    "2")
        echo "🚀 LANCEMENT SOLUTION 2: MPV Modern"
        /opt/pisignage/scripts/solution-2-mpv-modern.sh "$VIDEO_FILE"
        ;;
    "3")
        echo "🚀 LANCEMENT SOLUTION 3: VLC Universal"
        /opt/pisignage/scripts/solution-3-vlc-universal.sh "$VIDEO_FILE"
        ;;
    "raspberry")
        echo "🚀 LANCEMENT SOLUTION RASPBERRY PI SPÉCIALISÉE"
        echo
        echo "🥧 OPTIMISATIONS RASPBERRY PI:"
        
        # Vérifier la configuration GPU
        if command -v vcgencmd > /dev/null; then
            GPU_MEM=$(vcgencmd get_mem gpu 2>/dev/null | cut -d'=' -f2)
            echo "   GPU Mémoire: $GPU_MEM"
            if [ "${GPU_MEM%M}" -lt 128 ]; then
                echo "   ⚠️  GPU mémoire faible, recommandé: gpu_mem=256"
            fi
        fi
        
        # Lancer OMXPlayer optimisé
        echo "   🎬 Lancement OMXPlayer optimisé..."
        pkill -9 omxplayer vlc ffmpeg mpv 2>/dev/null
        
        omxplayer \
            --hw \
            --loop \
            --no-osd \
            --aspect-mode stretch \
            --orientation 0 \
            "$VIDEO_FILE" > /opt/pisignage/logs/omxplayer.log 2>&1 &
            
        PLAYER_PID=$!
        echo "   ✅ OMXPlayer démarré (PID: $PLAYER_PID)"
        echo "   📊 CPU attendu: 0-3%"
        ;;
    "test")
        echo "🧪 MODE TEST/BENCHMARK"
        /opt/pisignage/scripts/benchmark-all-solutions.sh "$VIDEO_FILE"
        ;;
    *)
        echo "❌ Solution inconnue: $RECOMMENDED_SOLUTION"
        exit 1
        ;;
esac

echo
echo "✅ AUTO-OPTIMISATION TERMINÉE"
echo
echo "📊 MONITORING RECOMMANDÉ:"
echo "   htop                    # CPU/RAM temps réel"
echo "   iotop                   # I/O disque"
echo "   vcgencmd measure_temp   # Température (Pi uniquement)"
echo
echo "⏹️  ARRÊT:"
echo "   pkill -9 ffmpeg vlc mpv omxplayer"
echo
echo "🔄 REDÉMARRAGE:"
echo "   $0 \"$VIDEO_FILE\" $FORCE_SOLUTION"