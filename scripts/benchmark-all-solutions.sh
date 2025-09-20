#!/bin/bash

# BENCHMARK COMPLET - TOUTES LES SOLUTIONS
# Compare les performances de tous les players disponibles
# Génère un rapport détaillé avec recommandations

echo "📊 BENCHMARK COMPLET - SOLUTIONS VIDÉO"
echo "======================================"
echo "Date: $(date)"
echo

VIDEO_FILE="${1:-/opt/pisignage/media/sintel.mp4}"
BENCHMARK_DURATION="${2:-30}"
REPORT_FILE="/opt/pisignage/tests/benchmark-report-$(date +%Y%m%d-%H%M%S).json"

# Créer le répertoire de rapport
mkdir -p "$(dirname "$REPORT_FILE")"

echo "📁 Fichier test: $VIDEO_FILE"
echo "⏱️  Durée test: ${BENCHMARK_DURATION}s par solution"
echo "📄 Rapport: $REPORT_FILE"
echo

if [ ! -f "$VIDEO_FILE" ]; then
    echo "❌ Fichier vidéo non trouvé: $VIDEO_FILE"
    exit 1
fi

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

# Fonction pour mesurer les performances d'un processus
measure_performance() {
    local pid=$1
    local duration=$2
    local solution_name=$3
    
    local total_cpu=0
    local total_mem=0
    local samples=0
    local max_cpu=0
    local max_mem=0
    
    echo "   📊 Mesure performance $solution_name (${duration}s)..."
    
    for ((i=1; i<=duration; i++)); do
        if ps -p $pid > /dev/null 2>&1; then
            local cpu=$(ps -p $pid -o %cpu --no-headers 2>/dev/null | xargs)
            local mem=$(ps -p $pid -o %mem --no-headers 2>/dev/null | xargs)
            
            if [ -n "$cpu" ] && [ -n "$mem" ]; then
                total_cpu=$(echo "$total_cpu + $cpu" | bc -l 2>/dev/null || echo "$total_cpu")
                total_mem=$(echo "$total_mem + $mem" | bc -l 2>/dev/null || echo "$total_mem")
                
                # Mettre à jour les maximums
                if (( $(echo "$cpu > $max_cpu" | bc -l 2>/dev/null || echo 0) )); then
                    max_cpu=$cpu
                fi
                if (( $(echo "$mem > $max_mem" | bc -l 2>/dev/null || echo 0) )); then
                    max_mem=$mem
                fi
                
                ((samples++))
                echo -n "."
            fi
        else
            echo " ❌ Processus arrêté"
            break
        fi
        sleep 1
    done
    
    echo
    
    if [ $samples -gt 0 ]; then
        local avg_cpu=$(echo "scale=2; $total_cpu / $samples" | bc -l 2>/dev/null || echo "0")
        local avg_mem=$(echo "scale=2; $total_mem / $samples" | bc -l 2>/dev/null || echo "0")
        
        echo "   📈 CPU moyen: ${avg_cpu}% | Max: ${max_cpu}%"
        echo "   💾 RAM moyenne: ${avg_mem}% | Max: ${max_mem}%"
        echo "   📝 Échantillons: $samples"
        
        # Retourner les résultats via variables globales
        RESULT_AVG_CPU=$avg_cpu
        RESULT_MAX_CPU=$max_cpu
        RESULT_AVG_MEM=$avg_mem
        RESULT_MAX_MEM=$max_mem
        RESULT_SAMPLES=$samples
        return 0
    else
        echo "   ❌ Aucune donnée collectée"
        return 1
    fi
}

# Fonction pour nettoyer tous les processus
cleanup_players() {
    echo "🧹 Nettoyage des processus..."
    pkill -9 ffmpeg vlc mpv omxplayer mplayer 2>/dev/null
    sleep 2
}

# ============================================================================
# INITIALISATION DU RAPPORT
# ============================================================================

cat > "$REPORT_FILE" << EOF
{
  "benchmark_info": {
    "date": "$(date -Iseconds)",
    "video_file": "$VIDEO_FILE",
    "test_duration": $BENCHMARK_DURATION,
    "system_info": {
      "architecture": "$(uname -m)",
      "os": "$(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')",
      "kernel": "$(uname -r)",
      "cpu_cores": $(nproc),
      "total_ram": "$(free -h | grep Mem | awk '{print $2}')"
    }
  },
  "results": {
EOF

# ============================================================================
# BENCHMARK DES SOLUTIONS
# ============================================================================

TESTED_SOLUTIONS=0
SUCCESSFUL_TESTS=0

echo
echo "🧪 DÉMARRAGE DES TESTS:"
echo

# Test 1: FFmpeg Optimisé
echo "═══════════════════════════════════════"
echo "🔧 TEST 1: FFmpeg Optimisé"
echo "═══════════════════════════════════════"

cleanup_players

if command -v ffmpeg > /dev/null; then
    echo "✅ FFmpeg disponible"
    
    # Démarrer FFmpeg optimisé
    FB_SIZE=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo "1280,800")
    FB_WIDTH=$(echo $FB_SIZE | cut -d',' -f1)
    FB_HEIGHT=$(echo $FB_SIZE | cut -d',' -f2)
    
    ffmpeg -re -threads 0 -i "$VIDEO_FILE" \
        -vf "scale=${FB_WIDTH}:${FB_HEIGHT}:flags=fast_bilinear" \
        -pix_fmt rgb565le -f fbdev \
        -stream_loop -1 /dev/fb0 >/dev/null 2>&1 &
    
    FFMPEG_PID=$!
    sleep 3
    
    if ps -p $FFMPEG_PID > /dev/null; then
        echo "🎬 FFmpeg démarré (PID: $FFMPEG_PID)"
        
        if measure_performance $FFMPEG_PID $BENCHMARK_DURATION "FFmpeg"; then
            ((SUCCESSFUL_TESTS++))
            
            # Ajouter au rapport JSON
            cat >> "$REPORT_FILE" << EOF
    "ffmpeg_optimized": {
      "status": "success",
      "avg_cpu": $RESULT_AVG_CPU,
      "max_cpu": $RESULT_MAX_CPU,
      "avg_memory": $RESULT_AVG_MEM,
      "max_memory": $RESULT_MAX_MEM,
      "samples": $RESULT_SAMPLES,
      "score": $(echo "100 - $RESULT_AVG_CPU" | bc -l 2>/dev/null || echo 50)
    },
EOF
        else
            cat >> "$REPORT_FILE" << EOF
    "ffmpeg_optimized": {
      "status": "failed",
      "error": "Performance measurement failed"
    },
EOF
        fi
        
        pkill -9 ffmpeg 2>/dev/null
    else
        echo "❌ FFmpeg n'a pas pu démarrer"
        cat >> "$REPORT_FILE" << EOF
    "ffmpeg_optimized": {
      "status": "failed",
      "error": "Process failed to start"
    },
EOF
    fi
    ((TESTED_SOLUTIONS++))
else
    echo "❌ FFmpeg non disponible"
    cat >> "$REPORT_FILE" << EOF
    "ffmpeg_optimized": {
      "status": "not_available",
      "error": "FFmpeg not installed"
    },
EOF
fi

sleep 3

# Test 2: MPV Modern
echo
echo "═══════════════════════════════════════"
echo "🎮 TEST 2: MPV Modern"
echo "═══════════════════════════════════════"

cleanup_players

if command -v mpv > /dev/null; then
    echo "✅ MPV disponible"
    
    # Démarrer MPV optimisé
    mpv --no-audio --loop-file=inf --vo=fbdev \
        --hwdec=auto --no-osc --no-osd-bar \
        --quiet "$VIDEO_FILE" >/dev/null 2>&1 &
    
    MPV_PID=$!
    sleep 3
    
    if ps -p $MPV_PID > /dev/null; then
        echo "🎬 MPV démarré (PID: $MPV_PID)"
        
        if measure_performance $MPV_PID $BENCHMARK_DURATION "MPV"; then
            ((SUCCESSFUL_TESTS++))
            
            cat >> "$REPORT_FILE" << EOF
    "mpv_modern": {
      "status": "success",
      "avg_cpu": $RESULT_AVG_CPU,
      "max_cpu": $RESULT_MAX_CPU,
      "avg_memory": $RESULT_AVG_MEM,
      "max_memory": $RESULT_MAX_MEM,
      "samples": $RESULT_SAMPLES,
      "score": $(echo "100 - $RESULT_AVG_CPU" | bc -l 2>/dev/null || echo 50)
    },
EOF
        else
            cat >> "$REPORT_FILE" << EOF
    "mpv_modern": {
      "status": "failed",
      "error": "Performance measurement failed"
    },
EOF
        fi
        
        pkill -9 mpv 2>/dev/null
    else
        echo "❌ MPV n'a pas pu démarrer"
        cat >> "$REPORT_FILE" << EOF
    "mpv_modern": {
      "status": "failed",
      "error": "Process failed to start"
    },
EOF
    fi
    ((TESTED_SOLUTIONS++))
else
    echo "❌ MPV non disponible"
    cat >> "$REPORT_FILE" << EOF
    "mpv_modern": {
      "status": "not_available",
      "error": "MPV not installed"
    },
EOF
fi

sleep 3

# Test 3: VLC Universal
echo
echo "═══════════════════════════════════════"
echo "🎭 TEST 3: VLC Universal"
echo "═══════════════════════════════════════"

cleanup_players

if command -v vlc > /dev/null; then
    echo "✅ VLC disponible"
    
    # Démarrer VLC optimisé
    vlc --intf dummy --vout fb --fbdev /dev/fb0 \
        --no-audio --fullscreen --loop \
        --no-osd --no-video-title-show \
        "$VIDEO_FILE" >/dev/null 2>&1 &
    
    VLC_PID=$!
    sleep 3
    
    if ps -p $VLC_PID > /dev/null; then
        echo "🎬 VLC démarré (PID: $VLC_PID)"
        
        if measure_performance $VLC_PID $BENCHMARK_DURATION "VLC"; then
            ((SUCCESSFUL_TESTS++))
            
            cat >> "$REPORT_FILE" << EOF
    "vlc_universal": {
      "status": "success",
      "avg_cpu": $RESULT_AVG_CPU,
      "max_cpu": $RESULT_MAX_CPU,
      "avg_memory": $RESULT_AVG_MEM,
      "max_memory": $RESULT_MAX_MEM,
      "samples": $RESULT_SAMPLES,
      "score": $(echo "100 - $RESULT_AVG_CPU" | bc -l 2>/dev/null || echo 50)
    }
EOF
        else
            cat >> "$REPORT_FILE" << EOF
    "vlc_universal": {
      "status": "failed",
      "error": "Performance measurement failed"
    }
EOF
        fi
        
        pkill -9 vlc 2>/dev/null
    else
        echo "❌ VLC n'a pas pu démarrer"
        cat >> "$REPORT_FILE" << EOF
    "vlc_universal": {
      "status": "failed",
      "error": "Process failed to start"
    }
EOF
    fi
    ((TESTED_SOLUTIONS++))
else
    echo "❌ VLC non disponible"
    cat >> "$REPORT_FILE" << EOF
    "vlc_universal": {
      "status": "not_available",
      "error": "VLC not installed"
    }
EOF
fi

# Finaliser le rapport JSON
cat >> "$REPORT_FILE" << EOF
  },
  "summary": {
    "tested_solutions": $TESTED_SOLUTIONS,
    "successful_tests": $SUCCESSFUL_TESTS,
    "recommendation": "Based on benchmark results"
  }
}
EOF

cleanup_players

# ============================================================================
# RAPPORT FINAL
# ============================================================================

echo
echo "📊 RAPPORT FINAL"
echo "==============="
echo "Tests exécutés: $TESTED_SOLUTIONS"
echo "Tests réussis: $SUCCESSFUL_TESTS"
echo "Rapport JSON: $REPORT_FILE"
echo

if [ $SUCCESSFUL_TESTS -gt 0 ]; then
    echo "🏆 RECOMMANDATIONS BASÉES SUR LES RÉSULTATS:"
    echo
    
    # Analyser le rapport JSON pour les recommandations
    if command -v jq > /dev/null; then
        echo "   Analyse détaillée disponible avec: jq . $REPORT_FILE"
    else
        echo "   💡 Installez 'jq' pour une analyse JSON avancée"
    fi
    
    echo
    echo "🚀 Pour déployer la meilleure solution:"
    echo "   /opt/pisignage/scripts/auto-optimize-video.sh \"$VIDEO_FILE\""
else
    echo "❌ Aucun test réussi - Vérifiez l'installation des players vidéo"
fi

echo
echo "✅ BENCHMARK TERMINÉ"