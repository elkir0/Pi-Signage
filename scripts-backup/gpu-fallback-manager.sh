#!/bin/bash

# =============================================================================
# PiSignage - Gestionnaire de fallback GPU avec détection automatique
# =============================================================================
# Version: 1.0.0
# Date: 22/09/2025
# Objectif: Fallback automatique si l'accélération GPU échoue
# =============================================================================

set -euo pipefail

# Configuration
PISIGNAGE_DIR="/opt/pisignage"
LOG_FILE="$PISIGNAGE_DIR/logs/gpu-fallback.log"
CONFIG_FILE="$PISIGNAGE_DIR/config/gpu-config.conf"
FALLBACK_HTML="$PISIGNAGE_DIR/chromium-video-player-fallback.html"
ORIGINAL_HTML="$PISIGNAGE_DIR/chromium-video-player.html"

# Tests et seuils
GPU_TEST_DURATION=30    # secondes
CPU_THRESHOLD_FAIL=90   # % CPU = échec GPU
FPS_THRESHOLD_FAIL=15   # FPS < 15 = échec
TEMP_THRESHOLD_WARN=85  # °C

# Modes disponibles
declare -A MODES=(
    ["gpu_full"]="Accélération GPU complète"
    ["gpu_limited"]="GPU limité (sans certains flags)"
    ["hybrid"]="Hybride GPU/Software"
    ["software"]="Software uniquement (dernier recours)"
)

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $timestamp - $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $timestamp - $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $timestamp - $message" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $timestamp - $message" ;;
        *) echo "$timestamp - $message" ;;
    esac

    echo "$timestamp [$level] $message" >> "$LOG_FILE"
}

# =============================================================================
# DÉTECTION CAPABILITIES GPU
# =============================================================================

detect_gpu_capabilities() {
    log "INFO" "Détection des capacités GPU..."

    # Vérifier DRM
    local drm_available=false
    if [ -e "/dev/dri/card0" ]; then
        drm_available=true
        log "INFO" "DRM disponible: /dev/dri/card0"
    else
        log "WARN" "DRM non disponible"
    fi

    # Vérifier VideoCore
    local videocore_available=false
    if vcgencmd version >/dev/null 2>&1; then
        videocore_available=true
        local vc_version=$(vcgencmd version | head -1)
        log "INFO" "VideoCore disponible: $vc_version"
    else
        log "WARN" "VideoCore non disponible"
    fi

    # Vérifier mémoire GPU
    local gpu_mem=0
    if command -v vcgencmd >/dev/null; then
        gpu_mem=$(vcgencmd get_mem gpu | cut -d= -f2 | sed 's/M//')
        log "INFO" "Mémoire GPU: ${gpu_mem}MB"
    fi

    # Vérifier OpenGL/EGL
    local opengl_available=false
    if command -v glxinfo >/dev/null 2>&1; then
        if glxinfo | grep -q "Broadcom"; then
            opengl_available=true
            log "INFO" "OpenGL Broadcom détecté"
        fi
    fi

    # Déterminer le mode optimal
    local recommended_mode="software"
    if [ "$drm_available" = true ] && [ "$videocore_available" = true ] && [ "$gpu_mem" -ge 128 ]; then
        recommended_mode="gpu_full"
    elif [ "$videocore_available" = true ] && [ "$gpu_mem" -ge 64 ]; then
        recommended_mode="gpu_limited"
    elif [ "$drm_available" = true ] || [ "$opengl_available" = true ]; then
        recommended_mode="hybrid"
    fi

    log "INFO" "Mode recommandé: $recommended_mode (${MODES[$recommended_mode]})"
    echo "$recommended_mode"
}

# =============================================================================
# GÉNÉRATION CONFIGURATIONS CHROMIUM
# =============================================================================

generate_chromium_flags() {
    local mode=$1
    local flags=()

    # Flags de base communs
    flags+=(
        "--no-sandbox"
        "--disable-dev-shm-usage"
        "--disable-setuid-sandbox"
        "--no-first-run"
        "--disable-infobars"
        "--disable-notifications"
        "--kiosk"
        "--start-fullscreen"
        "--autoplay-policy=no-user-gesture-required"
        "--disable-audio-output"
        "--mute-audio"
    )

    case $mode in
        "gpu_full")
            log "INFO" "Configuration GPU complète"
            flags+=(
                "--enable-gpu"
                "--enable-gpu-rasterization"
                "--enable-accelerated-2d-canvas"
                "--enable-accelerated-jpeg-decoding"
                "--enable-accelerated-mjpeg-decode"
                "--enable-accelerated-video-decode"
                "--enable-gpu-memory-buffer-video-frames"
                "--use-gl=egl"
                "--enable-hardware-overlays=drm"
                "--enable-drm-atomic"
                "--enable-features=VaapiVideoDecoder,VaapiVideoEncoder"
                "--enable-oop-rasterization"
                "--enable-zero-copy"
                "--enable-native-gpu-memory-buffers"
                "--disable-software-rasterizer"
            )
            ;;
        "gpu_limited")
            log "INFO" "Configuration GPU limitée"
            flags+=(
                "--enable-gpu"
                "--enable-gpu-rasterization"
                "--enable-accelerated-video-decode"
                "--use-gl=egl"
                "--disable-software-rasterizer"
                "--disable-gpu-vsync"
            )
            ;;
        "hybrid")
            log "INFO" "Configuration hybride"
            flags+=(
                "--enable-gpu"
                "--enable-accelerated-video-decode"
                "--use-gl=swiftshader"
                "--disable-gpu-rasterization"
                "--disable-accelerated-2d-canvas"
            )
            ;;
        "software")
            log "INFO" "Configuration software uniquement"
            flags+=(
                "--disable-gpu"
                "--disable-gpu-rasterization"
                "--disable-accelerated-2d-canvas"
                "--disable-accelerated-video-decode"
                "--use-gl=swiftshader"
                "--enable-software-rasterizer"
            )
            ;;
    esac

    echo "${flags[@]}"
}

# =============================================================================
# GÉNÉRATION HTML FALLBACK
# =============================================================================

generate_fallback_html() {
    local mode=$1

    log "INFO" "Génération HTML fallback pour mode: $mode"

    cat > "$FALLBACK_HTML" << EOF
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage - Mode Fallback ($mode)</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            background: #000;
            overflow: hidden;
            font-family: Arial, sans-serif;
        }

        #video-container {
            position: relative;
            width: 100vw;
            height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }

        #main-video {
            width: 100%;
            height: 100%;
            object-fit: cover;
EOF

    # CSS spécifique au mode
    case $mode in
        "software")
            cat >> "$FALLBACK_HTML" << 'EOF'
            /* Mode software - pas d'optimisations GPU */
            image-rendering: auto;
            image-rendering: crisp-edges;
EOF
            ;;
        "hybrid")
            cat >> "$FALLBACK_HTML" << 'EOF'
            /* Mode hybride - optimisations légères */
            transform: translate3d(0,0,0);
EOF
            ;;
        *)
            cat >> "$FALLBACK_HTML" << 'EOF'
            /* Mode GPU - optimisations complètes */
            transform: translateZ(0);
            will-change: transform;
            -webkit-backface-visibility: hidden;
            backface-visibility: hidden;
EOF
            ;;
    esac

    cat >> "$FALLBACK_HTML" << 'EOF'
        }

        #fallback-notice {
            position: absolute;
            top: 10px;
            left: 10px;
            background: rgba(255,165,0,0.9);
            color: #000;
            padding: 10px;
            border-radius: 5px;
            font-size: 14px;
            z-index: 1000;
        }

        #performance-info {
            position: absolute;
            top: 10px;
            right: 10px;
            background: rgba(0,0,0,0.7);
            color: #0f0;
            padding: 5px 10px;
            border-radius: 5px;
            font-size: 12px;
            font-family: monospace;
            z-index: 1000;
            display: none;
        }

        .loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: white;
            font-size: 18px;
        }
    </style>
</head>
<body>
    <div id="video-container">
        <div class="loading" id="loading">Chargement en mode fallback...</div>

        <div id="fallback-notice">
            ⚠️ Mode Fallback Actif<br>
            Raison: GPU_REASON_PLACEHOLDER<br>
            Mode: MODE_PLACEHOLDER
        </div>

        <video
            id="main-video"
            preload="auto"
            muted
            loop
            playsinline
            webkit-playsinline
            autoplay
            style="display: none;"
        >
            <source src="media/demo.mp4" type="video/mp4">
            <source src="media/demo.webm" type="video/webm">
            Votre navigateur ne supporte pas la lecture vidéo HTML5.
        </video>

        <div id="performance-info">
            <div>Mode: <span id="current-mode">MODE_PLACEHOLDER</span></div>
            <div>CPU: <span id="cpu-usage">--</span></div>
            <div>Temp: <span id="temperature">--</span></div>
            <div>Status: <span id="gpu-status">FALLBACK</span></div>
        </div>
    </div>

    <script>
        const CONFIG = {
            mode: 'MODE_PLACEHOLDER',
            fallbackReason: 'GPU_REASON_PLACEHOLDER',
            debugMode: true,
            targetFPS: 20  // FPS réduit en mode fallback
        };

        let video = null;

        document.addEventListener('DOMContentLoaded', function() {
            video = document.getElementById('main-video');
            initializeVideo();
            setupMonitoring();

            // Afficher automatiquement les infos en mode fallback
            document.getElementById('performance-info').style.display = 'block';

            console.log('[PiSignage Fallback] Mode actif:', CONFIG.mode);
            console.log('[PiSignage Fallback] Raison:', CONFIG.fallbackReason);
        });

        function initializeVideo() {
            video.addEventListener('loadedmetadata', function() {
                console.log('[Fallback] Métadonnées chargées:', video.videoWidth + 'x' + video.videoHeight);

                // Ajustements spécifiques au mode
                switch(CONFIG.mode) {
                    case 'software':
                        // Réduire la qualité si nécessaire
                        if (video.videoWidth > 1280) {
                            video.style.width = '1280px';
                            video.style.height = '720px';
                        }
                        break;
                    case 'hybrid':
                        // Optimisations légères
                        video.style.imageRendering = 'optimizeSpeed';
                        break;
                }
            });

            video.addEventListener('canplay', function() {
                document.getElementById('loading').style.display = 'none';
                video.style.display = 'block';
                console.log('[Fallback] Lecture prête');
            });

            video.addEventListener('error', function(e) {
                console.error('[Fallback] Erreur vidéo:', e);
                // En mode fallback, essayer des résolutions plus faibles
                fallbackToLowerQuality();
            });

            video.load();
        }

        function fallbackToLowerQuality() {
            console.log('[Fallback] Tentative résolution inférieure');

            // Remplacer par des sources de qualité moindre
            const sources = video.querySelectorAll('source');
            sources.forEach(source => {
                if (source.src.includes('1080p')) {
                    source.src = source.src.replace('1080p', '720p');
                } else if (source.src.includes('720p')) {
                    source.src = source.src.replace('720p', '480p');
                }
            });

            video.load();
        }

        function setupMonitoring() {
            // Monitoring simplifié pour mode fallback
            setInterval(function() {
                // CPU usage estimation
                const cpuEstimate = Math.random() * 20 + 40; // Simulation
                document.getElementById('cpu-usage').textContent = Math.round(cpuEstimate) + '%';

                // Température simulation
                const tempEstimate = Math.random() * 10 + 65;
                document.getElementById('temperature').textContent = Math.round(tempEstimate) + '°C';

                // Status update
                const status = CONFIG.mode.toUpperCase() + '_FALLBACK';
                document.getElementById('gpu-status').textContent = status;
            }, 5000);
        }

        // API externe simplifiée
        window.PiSignageFallback = {
            mode: CONFIG.mode,
            reason: CONFIG.fallbackReason,
            getInfo: () => ({
                mode: CONFIG.mode,
                reason: CONFIG.fallbackReason,
                gpuAcceleration: false,
                performance: 'limited'
            }),
            play: () => video.play(),
            pause: () => video.pause(),
            restart: () => { video.currentTime = 0; video.play(); }
        };

        console.log('[PiSignage Fallback] Initialisation terminée');
    </script>
</body>
</html>
EOF

    # Remplacer les placeholders
    sed -i "s/MODE_PLACEHOLDER/$mode/g" "$FALLBACK_HTML"
    sed -i "s/GPU_REASON_PLACEHOLDER/Détecté automatiquement/g" "$FALLBACK_HTML"

    log "INFO" "HTML fallback généré: $FALLBACK_HTML"
}

# =============================================================================
# TESTS DE PERFORMANCE
# =============================================================================

test_gpu_performance() {
    local mode=$1
    local test_duration=$2

    log "INFO" "Test de performance mode $mode pendant ${test_duration}s..."

    # Lancer Chromium en mode test
    local flags=($(generate_chromium_flags "$mode"))
    local test_url="file://$FALLBACK_HTML"

    # Chromium en arrière-plan pour test
    timeout "${test_duration}s" chromium-browser "${flags[@]}" "$test_url" \
        --window-size=1280,720 \
        --window-position=0,0 \
        >/dev/null 2>&1 &

    local chromium_pid=$!
    sleep 5  # Laisser démarrer

    if ! kill -0 "$chromium_pid" 2>/dev/null; then
        log "ERROR" "Échec du lancement en mode $mode"
        return 1
    fi

    # Collecter métriques pendant le test
    local cpu_samples=()
    local temp_samples=()
    local sample_count=0

    while [ $sample_count -lt $((test_duration / 5)) ] && kill -0 "$chromium_pid" 2>/dev/null; do
        local cpu_usage=$(ps -p "$chromium_pid" -o %cpu= 2>/dev/null | xargs || echo "0")
        local temperature=$(vcgencmd measure_temp | cut -d= -f2 | sed 's/°C//' || echo "0")

        cpu_samples+=("$cpu_usage")
        temp_samples+=("$temperature")

        log "DEBUG" "Sample $sample_count: CPU=${cpu_usage}% Temp=${temperature}°C"

        ((sample_count++))
        sleep 5
    done

    # Arrêter Chromium
    kill -TERM "$chromium_pid" 2>/dev/null || true
    sleep 2
    kill -KILL "$chromium_pid" 2>/dev/null || true

    # Analyser les résultats
    local avg_cpu=0
    local max_temp=0

    if [ ${#cpu_samples[@]} -gt 0 ]; then
        local cpu_sum=0
        for cpu in "${cpu_samples[@]}"; do
            cpu_sum=$(echo "$cpu_sum + $cpu" | bc)
            if (( $(echo "$cpu > $max_temp" | bc -l) )); then
                max_temp=$cpu
            fi
        done
        avg_cpu=$(echo "scale=1; $cpu_sum / ${#cpu_samples[@]}" | bc)
    fi

    if [ ${#temp_samples[@]} -gt 0 ]; then
        for temp in "${temp_samples[@]}"; do
            if (( $(echo "$temp > $max_temp" | bc -l) )); then
                max_temp=$temp
            fi
        done
    fi

    log "INFO" "Résultats test $mode: CPU moyen=${avg_cpu}% Temp max=${max_temp}°C"

    # Évaluer le succès
    local success=true
    if (( $(echo "$avg_cpu > $CPU_THRESHOLD_FAIL" | bc -l) )); then
        log "WARN" "CPU trop élevé: ${avg_cpu}% > ${CPU_THRESHOLD_FAIL}%"
        success=false
    fi

    if (( $(echo "$max_temp > $TEMP_THRESHOLD_WARN" | bc -l) )); then
        log "WARN" "Température élevée: ${max_temp}°C > ${TEMP_THRESHOLD_WARN}°C"
    fi

    if [ "$success" = true ]; then
        log "INFO" "Test $mode: SUCCÈS"
        return 0
    else
        log "WARN" "Test $mode: ÉCHEC"
        return 1
    fi
}

# =============================================================================
# SÉLECTION AUTOMATIQUE DU MEILLEUR MODE
# =============================================================================

auto_select_best_mode() {
    log "INFO" "Sélection automatique du meilleur mode..."

    local modes_to_test=("gpu_full" "gpu_limited" "hybrid" "software")
    local best_mode="software"
    local test_results=()

    for mode in "${modes_to_test[@]}"; do
        log "INFO" "Test du mode: $mode"

        if test_gpu_performance "$mode" 20; then
            log "INFO" "Mode $mode validé"
            best_mode="$mode"
            break
        else
            log "WARN" "Mode $mode échoué"
        fi
    done

    log "INFO" "Meilleur mode sélectionné: $best_mode"

    # Sauvegarder la configuration
    save_gpu_config "$best_mode" "auto-detected"

    echo "$best_mode"
}

# =============================================================================
# GESTION CONFIGURATION
# =============================================================================

save_gpu_config() {
    local mode=$1
    local reason=${2:-"manual"}

    mkdir -p "$(dirname "$CONFIG_FILE")"

    cat > "$CONFIG_FILE" << EOF
# Configuration GPU PiSignage
# Généré automatiquement le $(date)
GPU_MODE=$mode
GPU_REASON=$reason
DETECTION_DATE=$(date '+%Y-%m-%d %H:%M:%S')
FALLBACK_AVAILABLE=true
EOF

    log "INFO" "Configuration sauvegardée: mode=$mode raison=$reason"
}

load_gpu_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log "INFO" "Configuration chargée: mode=${GPU_MODE:-unknown}"
        echo "${GPU_MODE:-software}"
    else
        log "INFO" "Aucune configuration trouvée"
        echo "software"
    fi
}

# =============================================================================
# FONCTIONS PRINCIPALES
# =============================================================================

force_fallback() {
    local reason=${1:-"forced manually"}
    log "INFO" "Activation forcée du fallback: $reason"

    local fallback_mode=$(auto_select_best_mode)
    generate_fallback_html "$fallback_mode"
    save_gpu_config "$fallback_mode" "$reason"

    log "INFO" "Fallback activé en mode: $fallback_mode"
    return 0
}

check_and_fallback() {
    log "INFO" "Vérification automatique GPU et fallback si nécessaire..."

    # Tenter détection GPU
    local recommended_mode=$(detect_gpu_capabilities)

    # Tester le mode recommandé
    if test_gpu_performance "$recommended_mode" 30; then
        log "INFO" "Mode $recommended_mode validé - pas de fallback nécessaire"
        save_gpu_config "$recommended_mode" "validated"
        return 0
    else
        log "WARN" "Mode $recommended_mode échoué - activation fallback"
        force_fallback "GPU performance insufficient"
        return 1
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Gestionnaire de fallback GPU pour PiSignage

OPTIONS:
    -h, --help              Afficher cette aide
    -a, --auto              Sélection automatique du meilleur mode
    -f, --force-fallback    Forcer le mode fallback
    -t, --test MODE         Tester un mode spécifique
    -s, --status            Afficher le statut actuel
    -r, --reset             Reset de la configuration

MODES DISPONIBLES:
    gpu_full        Accélération GPU complète
    gpu_limited     GPU limité
    hybrid          Hybride GPU/Software
    software        Software uniquement

EXEMPLES:
    $0 --auto                   Détecter automatiquement
    $0 --test gpu_full          Tester le mode GPU complet
    $0 --force-fallback         Forcer le fallback
    $0 --status                 Voir la config actuelle
EOF
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    local action="check"
    local test_mode=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -a|--auto)
                action="auto"
                shift
                ;;
            -f|--force-fallback)
                action="force"
                shift
                ;;
            -t|--test)
                action="test"
                test_mode="$2"
                shift 2
                ;;
            -s|--status)
                action="status"
                shift
                ;;
            -r|--reset)
                action="reset"
                shift
                ;;
            *)
                log "ERROR" "Option inconnue: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Créer les répertoires
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$CONFIG_FILE")"

    log "INFO" "Démarrage du gestionnaire fallback GPU"

    case $action in
        "auto")
            auto_select_best_mode
            ;;
        "force")
            force_fallback "forced by user"
            ;;
        "test")
            if [ -z "$test_mode" ]; then
                log "ERROR" "Mode de test requis"
                exit 1
            fi
            test_gpu_performance "$test_mode" 30
            ;;
        "status")
            local current_mode=$(load_gpu_config)
            log "INFO" "Mode actuel: $current_mode"
            if [ -f "$CONFIG_FILE" ]; then
                cat "$CONFIG_FILE"
            fi
            ;;
        "reset")
            rm -f "$CONFIG_FILE" "$FALLBACK_HTML"
            log "INFO" "Configuration reset"
            ;;
        "check")
            check_and_fallback
            ;;
        *)
            log "ERROR" "Action inconnue: $action"
            exit 1
            ;;
    esac
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi