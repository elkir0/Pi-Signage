#!/bin/bash

# =============================================================================
# PiSignage - Script de lancement Chromium optimisé GPU pour Raspberry Pi 4
# =============================================================================
# Version: 1.0.0
# Date: 22/09/2025
# Objectif: 30+ FPS stable en lecture vidéo 720p
# Hardware: Raspberry Pi 4 + VideoCore VI GPU
# OS: Raspberry Pi OS Bullseye
# =============================================================================

set -euo pipefail

# Configuration
PISIGNAGE_DIR="/opt/pisignage"
HTML_FILE="$PISIGNAGE_DIR/chromium-video-player.html"
LOG_FILE="$PISIGNAGE_DIR/logs/chromium-gpu.log"
PID_FILE="/tmp/pisignage-chromium.pid"
PERFORMANCE_LOG="$PISIGNAGE_DIR/logs/chromium-performance.log"

# Paramètres d'optimisation
TARGET_FPS=30
MAX_MEMORY_MB=512
GPU_MEMORY_KB=131072  # 128MB en KB
DISPLAY=${DISPLAY:-:0}

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

check_hardware() {
    log "INFO" "Vérification de la configuration hardware..."

    # Vérifier le modèle Raspberry Pi
    local pi_model=$(grep "Model" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    log "INFO" "Modèle détecté: $pi_model"

    if [[ ! "$pi_model" =~ "Raspberry Pi 4" ]]; then
        log "WARN" "Ce script est optimisé pour Raspberry Pi 4"
    fi

    # Vérifier la mémoire GPU
    local gpu_mem=$(vcgencmd get_mem gpu | cut -d= -f2 | sed 's/M//')
    log "INFO" "Mémoire GPU: ${gpu_mem}MB"

    if [ "$gpu_mem" -lt 128 ]; then
        log "ERROR" "Mémoire GPU insuffisante: ${gpu_mem}MB (minimum 128MB requis)"
        log "ERROR" "Ajoutez 'gpu_mem=128' dans /boot/config.txt"
        exit 1
    fi

    # Vérifier le driver GPU
    if [ -e /dev/dri/card0 ]; then
        log "INFO" "Driver DRM détecté: /dev/dri/card0"
    else
        log "WARN" "Driver DRM non détecté - performances GPU limitées"
    fi

    # Vérifier la température
    local temp=$(vcgencmd measure_temp | cut -d= -f2 | sed 's/°C//')
    log "INFO" "Température CPU: ${temp}°C"

    if (( $(echo "$temp > 80" | bc -l) )); then
        log "WARN" "Température élevée: ${temp}°C - risque de throttling"
    fi
}

check_dependencies() {
    log "INFO" "Vérification des dépendances..."

    # Vérifier Chromium
    if ! command -v chromium-browser &> /dev/null; then
        log "ERROR" "Chromium non installé"
        log "INFO" "Installation: sudo apt install chromium-browser"
        exit 1
    fi

    local chromium_version=$(chromium-browser --version 2>/dev/null | cut -d' ' -f2)
    log "INFO" "Version Chromium: $chromium_version"

    # Vérifier le fichier HTML
    if [ ! -f "$HTML_FILE" ]; then
        log "ERROR" "Fichier HTML non trouvé: $HTML_FILE"
        exit 1
    fi

    # Vérifier les répertoires
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$PERFORMANCE_LOG")"

    # Vérifier X11
    if [ -z "${DISPLAY:-}" ]; then
        log "ERROR" "Variable DISPLAY non définie"
        exit 1
    fi

    if ! xset q &>/dev/null; then
        log "ERROR" "Serveur X11 non accessible"
        exit 1
    fi
}

cleanup_previous() {
    log "INFO" "Nettoyage des processus précédents..."

    # Arrêter Chromium s'il tourne
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log "INFO" "Arrêt du processus Chromium existant (PID: $old_pid)"
            kill -TERM "$old_pid" 2>/dev/null || true
            sleep 2
            kill -KILL "$old_pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi

    # Killer tous les Chromium restants
    pkill -f "chromium.*pisignage" 2>/dev/null || true
    sleep 1

    # Nettoyer les fichiers temporaires
    rm -rf /tmp/.org.chromium.Chromium.* 2>/dev/null || true
    rm -rf /tmp/chromium-* 2>/dev/null || true
}

setup_environment() {
    log "INFO" "Configuration de l'environnement..."

    # Variables d'environnement GPU
    export LIBGL_ALWAYS_SOFTWARE=0
    export LIBGL_ALWAYS_INDIRECT=0
    export __GL_SYNC_TO_VBLANK=1
    export __GL_SYNC_DISPLAY_DEVICE=HDMI-1

    # Variables Chromium GPU
    export CHROMIUM_FLAGS_GPU="--enable-gpu --enable-gpu-rasterization"
    export CHROMIUM_FLAGS_GPU="$CHROMIUM_FLAGS_GPU --enable-accelerated-2d-canvas"
    export CHROMIUM_FLAGS_GPU="$CHROMIUM_FLAGS_GPU --enable-accelerated-jpeg-decoding"
    export CHROMIUM_FLAGS_GPU="$CHROMIUM_FLAGS_GPU --enable-accelerated-mjpeg-decode"
    export CHROMIUM_FLAGS_GPU="$CHROMIUM_FLAGS_GPU --enable-accelerated-video-decode"
    export CHROMIUM_FLAGS_GPU="$CHROMIUM_FLAGS_GPU --enable-gpu-memory-buffer-video-frames"

    # Optimisations VideoCore VI (Raspberry Pi 4)
    export CHROMIUM_FLAGS_GPU="$CHROMIUM_FLAGS_GPU --use-gl=egl"
    export CHROMIUM_FLAGS_GPU="$CHROMIUM_FLAGS_GPU --enable-hardware-overlays=drm"
    export CHROMIUM_FLAGS_GPU="$CHROMIUM_FLAGS_GPU --enable-drm-atomic"

    # Désactiver les fonctionnalités problématiques
    export CHROMIUM_FLAGS_DISABLE="--disable-software-rasterizer"
    export CHROMIUM_FLAGS_DISABLE="$CHROMIUM_FLAGS_DISABLE --disable-background-timer-throttling"
    export CHROMIUM_FLAGS_DISABLE="$CHROMIUM_FLAGS_DISABLE --disable-backgrounding-occluded-windows"
    export CHROMIUM_FLAGS_DISABLE="$CHROMIUM_FLAGS_DISABLE --disable-renderer-backgrounding"
    export CHROMIUM_FLAGS_DISABLE="$CHROMIUM_FLAGS_DISABLE --disable-features=TranslateUI,VizDisplayCompositor"

    log "DEBUG" "Variables GPU configurées"
}

build_chromium_flags() {
    log "INFO" "Construction des flags Chromium optimisés..."

    # Flags de base
    local flags=(
        "--no-sandbox"
        "--disable-dev-shm-usage"
        "--disable-setuid-sandbox"
        "--no-first-run"
        "--disable-infobars"
        "--disable-notifications"
        "--disable-password-manager-reauthentication"
        "--kiosk"
        "--start-fullscreen"
        "--window-position=0,0"
        "--window-size=1920,1080"
    )

    # Flags GPU (variables exportées précédemment)
    flags+=(${CHROMIUM_FLAGS_GPU})
    flags+=(${CHROMIUM_FLAGS_DISABLE})

    # Optimisations mémoire
    flags+=(
        "--memory-pressure-off"
        "--max_old_space_size=512"
        "--js-flags=--max-old-space-size=512"
    )

    # Optimisations réseau et cache
    flags+=(
        "--disable-background-networking"
        "--disable-background-sync"
        "--disable-client-side-phishing-detection"
        "--disable-default-apps"
        "--disable-extensions"
        "--disable-hang-monitor"
        "--disable-popup-blocking"
        "--disable-prompt-on-repost"
        "--disable-sync"
        "--disable-web-security"
        "--ignore-certificate-errors"
        "--ignore-ssl-errors"
        "--ignore-certificate-errors-spki-list"
        "--ignore-urlfetcher-cert-requests"
    )

    # Optimisations audio/vidéo
    flags+=(
        "--autoplay-policy=no-user-gesture-required"
        "--disable-gesture-requirement-for-media-playback"
        "--disable-audio-output"
        "--mute-audio"
    )

    # Optimisations performances
    flags+=(
        "--max-gum-fps=$TARGET_FPS"
        "--disable-frame-rate-limit"
        "--disable-gpu-vsync"
        "--disable-background-timer-throttling"
    )

    # Flags spécifiques Raspberry Pi 4
    flags+=(
        "--use-cmd-decoder=passthrough"
        "--enable-logging=stderr"
        "--log-level=1"
        "--force-device-scale-factor=1"
        "--force-color-profile=srgb"
    )

    # Flags expérimentaux pour meilleures performances
    flags+=(
        "--enable-features=VaapiVideoDecoder,VaapiVideoEncoder"
        "--enable-features=CanvasOopRasterization"
        "--enable-oop-rasterization"
        "--enable-zero-copy"
        "--enable-native-gpu-memory-buffers"
    )

    echo "${flags[@]}"
}

monitor_performance() {
    local chromium_pid=$1
    log "INFO" "Démarrage du monitoring performance (PID: $chromium_pid)"

    {
        while kill -0 "$chromium_pid" 2>/dev/null; do
            local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            local cpu_usage=$(ps -p "$chromium_pid" -o %cpu= 2>/dev/null | xargs || echo "0")
            local mem_usage=$(ps -p "$chromium_pid" -o %mem= 2>/dev/null | xargs || echo "0")
            local temp=$(vcgencmd measure_temp | cut -d= -f2 | sed 's/°C//')
            local throttled=$(vcgencmd get_throttled)

            echo "$timestamp,CPU:$cpu_usage%,MEM:$mem_usage%,TEMP:$temp°C,THROTTLED:$throttled"
            sleep 5
        done
    } >> "$PERFORMANCE_LOG" &

    local monitor_pid=$!
    echo "$monitor_pid" > "/tmp/pisignage-monitor.pid"
}

launch_chromium() {
    log "INFO" "Lancement de Chromium avec optimisations GPU..."

    local flags=($(build_chromium_flags))
    local url="file://$HTML_FILE"

    log "DEBUG" "URL: $url"
    log "DEBUG" "Flags: ${#flags[@]} flags configurés"

    # Lancement avec redirection des logs
    nohup chromium-browser "${flags[@]}" "$url" \
        > "$LOG_FILE.stdout" 2> "$LOG_FILE.stderr" &

    local chromium_pid=$!
    echo "$chromium_pid" > "$PID_FILE"

    log "INFO" "Chromium lancé (PID: $chromium_pid)"

    # Attendre que Chromium démarre
    sleep 3

    if ! kill -0 "$chromium_pid" 2>/dev/null; then
        log "ERROR" "Échec du lancement de Chromium"
        cat "$LOG_FILE.stderr" | tail -10
        exit 1
    fi

    # Démarrer le monitoring
    monitor_performance "$chromium_pid"

    log "INFO" "Chromium démarré avec succès - monitoring actif"
    return 0
}

check_gpu_acceleration() {
    log "INFO" "Vérification de l'accélération GPU..."

    sleep 10  # Laisser le temps à Chromium de s'initialiser

    # Vérifier via chrome://gpu (complexe à parser)
    # Alternative: vérifier les logs pour des indices

    if grep -q "GPU process" "$LOG_FILE.stderr" 2>/dev/null; then
        log "INFO" "Processus GPU détecté dans les logs"
    else
        log "WARN" "Aucun processus GPU détecté - possible fallback software"
    fi

    # Vérifier l'utilisation du GPU via /sys
    if [ -d "/sys/kernel/debug/dri/0" ]; then
        log "INFO" "Interface DRI disponible"
    fi

    # Monitorer l'usage CPU pendant la lecture
    sleep 5
    local cpu_usage=$(top -bn1 | grep chromium | awk '{print $9}' | head -1)
    if [ -n "$cpu_usage" ]; then
        log "INFO" "Usage CPU Chromium: ${cpu_usage}%"
        if (( $(echo "$cpu_usage > 80" | bc -l) )); then
            log "WARN" "Usage CPU élevé: ${cpu_usage}% - possible absence d'accélération GPU"
        fi
    fi
}

wait_for_signal() {
    log "INFO" "Chromium en cours d'exécution - CTRL+C pour arrêter"

    # Fonction de nettoyage à l'arrêt
    trap 'cleanup_on_exit' SIGINT SIGTERM

    # Attendre indéfiniment
    while true; do
        if [ ! -f "$PID_FILE" ]; then
            log "WARN" "Fichier PID disparu - arrêt détecté"
            break
        fi

        local pid=$(cat "$PID_FILE")
        if ! kill -0 "$pid" 2>/dev/null; then
            log "WARN" "Processus Chromium arrêté (PID: $pid)"
            break
        fi

        sleep 5
    done
}

cleanup_on_exit() {
    log "INFO" "Arrêt demandé - nettoyage en cours..."

    # Arrêter le monitoring
    if [ -f "/tmp/pisignage-monitor.pid" ]; then
        local monitor_pid=$(cat "/tmp/pisignage-monitor.pid")
        kill "$monitor_pid" 2>/dev/null || true
        rm -f "/tmp/pisignage-monitor.pid"
    fi

    # Arrêter Chromium
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "INFO" "Arrêt de Chromium (PID: $pid)"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 3
            kill -KILL "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi

    log "INFO" "Nettoyage terminé"
    exit 0
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Script de lancement Chromium optimisé GPU pour PiSignage

OPTIONS:
    -h, --help          Afficher cette aide
    -d, --debug         Mode debug verbeux
    -c, --check-only    Vérifier la configuration uniquement
    -k, --kill          Arrêter Chromium en cours
    -s, --status        Afficher le statut

EXEMPLES:
    $0                  Lancer Chromium optimisé
    $0 --check-only     Vérifier la config sans lancer
    $0 --kill           Arrêter Chromium
    $0 --status         Voir le statut actuel

LOGS:
    Principal: $LOG_FILE
    Performance: $PERFORMANCE_LOG
EOF
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    local check_only=false
    local kill_only=false
    local status_only=false
    local debug_mode=false

    # Parser les arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -d|--debug)
                debug_mode=true
                set -x
                shift
                ;;
            -c|--check-only)
                check_only=true
                shift
                ;;
            -k|--kill)
                kill_only=true
                shift
                ;;
            -s|--status)
                status_only=true
                shift
                ;;
            *)
                log "ERROR" "Option inconnue: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Initialiser les logs
    echo "=== PiSignage Chromium GPU Launch - $(date) ===" >> "$LOG_FILE"

    log "INFO" "Démarrage du script d'optimisation Chromium GPU"

    # Gestion des modes spéciaux
    if [ "$kill_only" = true ]; then
        cleanup_previous
        log "INFO" "Chromium arrêté"
        exit 0
    fi

    if [ "$status_only" = true ]; then
        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                log "INFO" "Chromium en cours d'exécution (PID: $pid)"
                if [ -f "$PERFORMANCE_LOG" ]; then
                    log "INFO" "Dernières métriques:"
                    tail -3 "$PERFORMANCE_LOG"
                fi
            else
                log "INFO" "Chromium arrêté (PID obsolète: $pid)"
            fi
        else
            log "INFO" "Chromium non démarré"
        fi
        exit 0
    fi

    # Vérifications système
    check_hardware
    check_dependencies

    if [ "$check_only" = true ]; then
        log "INFO" "Vérifications terminées - configuration OK"
        exit 0
    fi

    # Lancement principal
    cleanup_previous
    setup_environment
    launch_chromium

    # Vérifications post-lancement
    check_gpu_acceleration

    # Attendre l'arrêt
    wait_for_signal
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi