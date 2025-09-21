#!/bin/bash

# PiSignage v4.0 - VLC Engine Optimisé
# Architecture nouvelle génération pour 30+ FPS garantis
# Compatible Raspberry Pi 4 + x86_64 avec accélération matérielle

set -euo pipefail

# Configuration
VIDEO_ENGINE_VERSION="4.0.0"
LOG_FILE="/opt/pisignage/logs/vlc-engine.log"
PID_FILE="/opt/pisignage/run/vlc-engine.pid"
CONFIG_FILE="/opt/pisignage/config/vlc-engine.conf"

# Créer les répertoires nécessaires
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")" "$(dirname "$CONFIG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Fonction de nettoyage
cleanup() {
    log "🧹 Nettoyage des processus vidéo..."
    pkill -f "vlc.*pisignage" 2>/dev/null || true
    pkill -f "ffmpeg.*pisignage" 2>/dev/null || true
    rm -f "$PID_FILE"
}

# Détection de l'architecture et capacités
detect_platform() {
    local arch=$(uname -m)
    local platform="unknown"
    local gpu_accel=""
    local video_output=""
    
    log "🔍 Détection plateforme..."
    log "   Architecture: $arch"
    
    case "$arch" in
        "aarch64"|"armv7l"|"armv6l")
            # Raspberry Pi
            if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
                platform="raspberry_pi"
                # Détection Pi 4 vs versions antérieures
                if grep -q "Raspberry Pi 4" /proc/device-tree/model 2>/dev/null; then
                    gpu_accel="mmal_v4l2"
                    video_output="mmal_vout"
                    log "   🥧 Raspberry Pi 4 détecté - Accélération MMAL/V4L2"
                else
                    gpu_accel="mmal"
                    video_output="mmal_vout"
                    log "   🥧 Raspberry Pi < 4 détecté - Accélération MMAL"
                fi
            else
                platform="arm_generic"
                gpu_accel="auto"
                video_output="fb"
                log "   🔧 ARM générique détecté"
            fi
            ;;
        "x86_64")
            platform="x86_64"
            # Détection GPU Intel/AMD/NVIDIA
            if lspci | grep -i "vga.*intel" >/dev/null 2>&1; then
                gpu_accel="vaapi"
                video_output="gl"
                log "   💻 Intel GPU détecté - Accélération VAAPI"
            elif lspci | grep -i "vga.*amd\|vga.*ati" >/dev/null 2>&1; then
                gpu_accel="vaapi"
                video_output="gl"
                log "   💻 AMD GPU détecté - Accélération VAAPI"
            elif lspci | grep -i "vga.*nvidia" >/dev/null 2>&1; then
                gpu_accel="vdpau"
                video_output="gl"
                log "   💻 NVIDIA GPU détecté - Accélération VDPAU"
            else
                gpu_accel="auto"
                video_output="x11"
                log "   💻 x86_64 sans GPU dédié - Mode software optimisé"
            fi
            ;;
        *)
            platform="generic"
            gpu_accel="auto"
            video_output="fb"
            log "   ⚠️ Plateforme générique - Mode fallback"
            ;;
    esac
    
    # Vérification framebuffer si nécessaire
    if [[ "$video_output" == "fb" ]] && [[ ! -e /dev/fb0 ]]; then
        video_output="x11"
        log "   ⚠️ Framebuffer non disponible, basculement vers X11"
    fi
    
    # Export des variables pour utilisation
    export PISIGNAGE_PLATFORM="$platform"
    export PISIGNAGE_GPU_ACCEL="$gpu_accel"
    export PISIGNAGE_VIDEO_OUTPUT="$video_output"
    
    log "   ✅ Configuration: $platform / $gpu_accel / $video_output"
}

# Configuration VLC optimisée selon la plateforme
build_vlc_command() {
    local video_file="$1"
    local vlc_cmd="vlc"
    local vlc_opts=()
    
    # Options de base optimisées pour signage numérique
    vlc_opts+=(
        "--intf" "dummy"                    # Interface minimale
        "--no-video-title-show"             # Pas de titre affiché
        "--no-audio"                        # Pas d'audio pour signage
        "--fullscreen"                      # Mode plein écran
        "--no-osd"                          # Pas d'affichage à l'écran
        "--no-spu"                          # Pas de sous-titres
        "--no-snapshot-preview"             # Pas d'aperçu screenshot
        "--no-stats"                        # Pas de statistiques
        "--no-sub-autodetect-file"          # Pas de détection sous-titres
        "--no-inhibit"                      # Pas d'inhibition économiseur
        "--no-xlib"                         # Pas de vérifications XLib superflues
        "--loop"                            # Boucle infinie
        "--quiet"                           # Mode silencieux
    )
    
    # Cache optimisé pour lecture fluide
    vlc_opts+=(
        "--file-caching" "5000"             # Cache fichier 5s
        "--network-caching" "10000"         # Cache réseau 10s
        "--clock-jitter" "0"                # Réduction jitter
        "--clock-synchro" "1"               # Synchro horloge active
    )
    
    # Threading optimisé
    vlc_opts+=(
        "--threads" "0"                     # Auto-détection threads
        "--thread-type" "2"                 # Threads optimisés
    )
    
    # Configuration spécifique par plateforme
    case "$PISIGNAGE_PLATFORM" in
        "raspberry_pi")
            vlc_opts+=("--vout" "$PISIGNAGE_VIDEO_OUTPUT")
            
            # Configuration spécifique Pi 4
            if [[ "$PISIGNAGE_GPU_ACCEL" == "mmal_v4l2" ]]; then
                vlc_opts+=(
                    "--codec" "mmal"
                    "--mmal-display" "hdmi-1"
                    "--mmal-layer" "10"
                    "--mmal-adjust-refreshrate"
                    "--avcodec-hw" "mmal"
                )
                log "   🚀 Configuration Pi 4 avec MMAL + V4L2"
            else
                vlc_opts+=(
                    "--codec" "mmal"
                    "--mmal-display" "hdmi-1"
                    "--mmal-layer" "10"
                )
                log "   🚀 Configuration Pi classique avec MMAL"
            fi
            ;;
            
        "x86_64")
            vlc_opts+=("--vout" "$PISIGNAGE_VIDEO_OUTPUT")
            
            if [[ "$PISIGNAGE_GPU_ACCEL" != "auto" ]]; then
                vlc_opts+=(
                    "--avcodec-hw" "$PISIGNAGE_GPU_ACCEL"
                    "--vout-display-wrapper" "any"
                )
                log "   🚀 Configuration x86_64 avec accélération $PISIGNAGE_GPU_ACCEL"
            else
                vlc_opts+=(
                    "--avcodec-threads" "$(nproc)"
                    "--avcodec-skiploopfilter" "0"
                    "--avcodec-fast"
                )
                log "   🚀 Configuration x86_64 software optimisé"
            fi
            ;;
            
        *)
            vlc_opts+=("--vout" "$PISIGNAGE_VIDEO_OUTPUT")
            vlc_opts+=("--avcodec-hw" "auto")
            log "   🚀 Configuration générique"
            ;;
    esac
    
    # Optimisations finales selon le format vidéo
    if [[ "$video_file" =~ \.(h264|mp4|mkv)$ ]]; then
        vlc_opts+=("--avcodec-skiploopfilter" "0")  # Qualité maximale H264
    fi
    
    # Construction de la commande finale
    vlc_opts+=("$video_file")
    
    echo "${vlc_opts[@]}"
}

# Fonction de démarrage du moteur VLC
start_engine() {
    local video_file="${1:-/opt/pisignage/media/default.mp4}"
    
    if [[ ! -f "$video_file" ]]; then
        log "❌ Fichier vidéo non trouvé: $video_file"
        return 1
    fi
    
    log "🎬 Démarrage PiSignage VLC Engine v${VIDEO_ENGINE_VERSION}"
    log "   Fichier: $video_file"
    
    # Nettoyage préalable
    cleanup
    
    # Détection plateforme
    detect_platform
    
    # Construction de la commande VLC
    local vlc_command
    vlc_command=($(build_vlc_command "$video_file"))
    
    log "   Commande: ${vlc_command[*]}"
    
    # Démarrage avec gestion des erreurs
    if "${vlc_command[@]}" >/dev/null 2>&1 &
    then
        local vlc_pid=$!
        echo "$vlc_pid" > "$PID_FILE"
        log "✅ VLC Engine démarré (PID: $vlc_pid)"
        
        # Vérification du démarrage
        sleep 3
        if kill -0 "$vlc_pid" 2>/dev/null; then
            log "✅ Moteur stable - Lecture en cours"
            
            # Monitoring initial des performances
            monitor_performance "$vlc_pid" 10
            
            return 0
        else
            log "❌ Le moteur s'est arrêté de manière inattendue"
            return 1
        fi
    else
        log "❌ Impossible de démarrer VLC"
        return 1
    fi
}

# Monitoring des performances
monitor_performance() {
    local pid="$1"
    local duration="${2:-30}"
    
    log "📊 Monitoring performances ($duration secondes)..."
    
    local total_cpu=0
    local samples=0
    local max_cpu=0
    
    for ((i=1; i<=duration; i++)); do
        if kill -0 "$pid" 2>/dev/null; then
            local cpu mem
            cpu=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | xargs)
            mem=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | xargs)
            
            if [[ -n "$cpu" && -n "$mem" ]]; then
                total_cpu=$(echo "$total_cpu + $cpu" | bc -l 2>/dev/null || echo "$total_cpu")
                ((samples++))
                
                if (( $(echo "$cpu > $max_cpu" | bc -l 2>/dev/null || echo 0) )); then
                    max_cpu=$cpu
                fi
                
                if (( i % 5 == 0 )); then
                    log "   [$i/$duration] CPU: ${cpu}% | RAM: ${mem}%"
                fi
            fi
        else
            log "❌ Processus arrêté pendant le monitoring"
            return 1
        fi
        sleep 1
    done
    
    if (( samples > 0 )); then
        local avg_cpu
        avg_cpu=$(echo "scale=2; $total_cpu / $samples" | bc -l 2>/dev/null || echo "0")
        log "📈 Performance finale:"
        log "   CPU moyen: ${avg_cpu}%"
        log "   CPU max: ${max_cpu}%"
        log "   Échantillons: $samples"
        
        # Évaluation performance
        if (( $(echo "$avg_cpu < 25" | bc -l 2>/dev/null || echo 0) )); then
            log "🎯 EXCELLENT: Accélération matérielle active - 30+ FPS garantis"
        elif (( $(echo "$avg_cpu < 50" | bc -l 2>/dev/null || echo 0) )); then
            log "✅ BON: Performance optimale - 25+ FPS probables"
        else
            log "⚠️ ATTENTION: CPU élevé - Vérifier configuration accélération"
        fi
    fi
}

# Fonction d'arrêt
stop_engine() {
    log "⏹️ Arrêt du moteur VLC..."
    
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
            log "✅ Moteur arrêté"
        fi
        rm -f "$PID_FILE"
    fi
    
    cleanup
}

# Fonction de status
status_engine() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            local cpu mem
            cpu=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | xargs)
            mem=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | xargs)
            echo "✅ RUNNING (PID: $pid) - CPU: ${cpu}% - RAM: ${mem}%"
            return 0
        else
            echo "❌ STOPPED (PID file exists but process dead)"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        echo "❌ STOPPED"
        return 1
    fi
}

# Interface en ligne de commande
case "${1:-start}" in
    start)
        start_engine "${2:-}"
        ;;
    stop)
        stop_engine
        ;;
    restart)
        stop_engine
        sleep 2
        start_engine "${2:-}"
        ;;
    status)
        status_engine
        ;;
    monitor)
        if [[ -f "$PID_FILE" ]]; then
            pid=$(cat "$PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                monitor_performance "$pid" "${2:-30}"
            else
                echo "❌ Moteur non actif"
                exit 1
            fi
        else
            echo "❌ Moteur non démarré"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|monitor} [video_file|duration]"
        echo ""
        echo "PiSignage VLC Engine v${VIDEO_ENGINE_VERSION}"
        echo "Moteur vidéo haute performance pour affichage numérique"
        echo ""
        echo "Commandes:"
        echo "  start [file]     - Démarrer le moteur avec fichier optionnel"
        echo "  stop             - Arrêter le moteur"
        echo "  restart [file]   - Redémarrer le moteur"
        echo "  status           - Afficher le statut"
        echo "  monitor [sec]    - Surveiller les performances"
        exit 1
        ;;
esac