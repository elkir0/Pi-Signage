#!/bin/bash

# Pi-Signage Player Manager v0.8.1
# Gestion intelligente MPV/VLC avec détection Wayland/X11/DRM
# Compatible Raspberry Pi OS Bookworm

set -e

# Configuration
PISIGNAGE_DIR="/opt/pisignage"
CONFIG_DIR="$PISIGNAGE_DIR/config"
LOG_DIR="$PISIGNAGE_DIR/logs"
MEDIA_DIR="$PISIGNAGE_DIR/media"
PLAYLIST_FILE="$MEDIA_DIR/playlist.m3u"

# Logs
LOG_FILE="$LOG_DIR/player-manager.log"
MPV_LOG="$LOG_DIR/mpv.log"
VLC_LOG="$LOG_DIR/vlc.log"

# PID files
PID_FILE="/tmp/pisignage-player.pid"
LOCK_FILE="/tmp/pisignage.lock"

# Préférence du player (peut être overridé)
DEFAULT_PLAYER="${PLAYER:-mpv}"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Détection de l'environnement graphique
detect_environment() {
    if [ -n "$WAYLAND_DISPLAY" ]; then
        echo "wayland"
    elif [ -n "$DISPLAY" ]; then
        echo "x11"
    else
        echo "tty"
    fi
}

# Détection du compositeur Wayland
detect_wayland_compositor() {
    if [ -n "$WAYLAND_DISPLAY" ]; then
        if pgrep -x "labwc" > /dev/null; then
            echo "labwc"
        elif pgrep -x "wayfire" > /dev/null; then
            echo "wayfire"
        elif pgrep -x "weston" > /dev/null; then
            echo "weston"
        elif pgrep -x "sway" > /dev/null; then
            echo "sway"
        else
            echo "unknown"
        fi
    fi
}

# Configuration de l'environnement selon le display server
setup_display_environment() {
    local display_server=$(detect_environment)
    log "Display server détecté: $display_server"

    case "$display_server" in
        wayland)
            local compositor=$(detect_wayland_compositor)
            log "Compositeur Wayland: $compositor"

            export GDK_BACKEND=wayland
            export QT_QPA_PLATFORM=wayland
            export SDL_VIDEODRIVER=wayland
            export CLUTTER_BACKEND=wayland

            # Configuration V4L2 pour l'accélération HW
            export LIBVA_DRIVER_NAME=v4l2_request
            export LIBVA_V4L2_REQUEST_VIDEO_PATH=/dev/video10

            # XDG Runtime pour Wayland
            if [ -z "$XDG_RUNTIME_DIR" ]; then
                export XDG_RUNTIME_DIR="/run/user/$(id -u)"
            fi

            # MPV args spécifiques Wayland
            MPV_DISPLAY_ARGS="--gpu-context=wayland --vo=gpu-next"
            VLC_DISPLAY_ARGS="--vout=gles2 --intf=dummy"
            ;;

        x11)
            log "Mode X11 détecté"

            export GDK_BACKEND=x11
            export QT_QPA_PLATFORM=xcb
            export SDL_VIDEODRIVER=x11

            # MPV args spécifiques X11
            MPV_DISPLAY_ARGS="--gpu-context=x11 --vo=gpu"
            VLC_DISPLAY_ARGS="--vout=xcb_x11 --intf=dummy"
            ;;

        tty)
            log "Mode TTY/DRM direct détecté"

            # Configuration pour DRM direct (kiosk mode)
            export GST_VAAPI_ALL_DRIVERS=1
            export LIBVA_DRIVER_NAME=v4l2_request

            # MPV en mode DRM direct
            MPV_DISPLAY_ARGS="--gpu-context=drm --vo=gpu --drm-connector=HDMI-A-1"
            VLC_DISPLAY_ARGS="--vout=drm --intf=dummy"
            ;;
    esac

    # Variables communes
    export LIBVA_MESSAGING_LEVEL=0
    export MESA_EXTENSION_OVERRIDE="+GL_EXT_gpu_shader4"
}

# Vérification de l'accélération HW
check_hw_acceleration() {
    info "Vérification de l'accélération matérielle..."

    # Test V4L2 devices
    if ls /dev/video* 2>/dev/null | grep -E 'video1[0-9]' > /dev/null; then
        log "Devices V4L2 trouvés pour l'accélération"
        HW_ACCEL_AVAILABLE=true
    else
        warning "Pas de devices V4L2 pour l'accélération"
        HW_ACCEL_AVAILABLE=false
    fi

    # Test ffmpeg avec support V4L2
    if ffmpeg -decoders 2>/dev/null | grep -E 'h264_v4l2m2m|hevc_v4l2m2m' > /dev/null; then
        log "Décodeurs V4L2M2M disponibles dans ffmpeg"
    else
        warning "Pas de décodeurs V4L2M2M dans ffmpeg"
        HW_ACCEL_AVAILABLE=false
    fi

    # Test DRM access
    if [ -r /dev/dri/card0 ] && [ -r /dev/dri/renderD128 ]; then
        log "Accès DRM disponible"
    else
        warning "Accès DRM limité - vérifiez les permissions"
    fi
}

# Configuration MPV selon l'environnement
configure_mpv() {
    log "Configuration de MPV..."

    local mpv_args=(
        # Base args
        "--fullscreen"
        "--keep-open=yes"
        "--loop-playlist=inf"
        "--no-osc"
        "--no-osd-bar"
        "--cursor-autohide=1000"

        # Display args (définis par setup_display_environment)
        $MPV_DISPLAY_ARGS

        # Hardware acceleration
        "--hwdec=auto"
        "--hwdec-codecs=all"

        # Performance
        "--cache=yes"
        "--cache-secs=10"
        "--demuxer-max-bytes=50M"

        # Audio
        "--audio-pitch-correction=yes"
        "--volume=100"

        # Logging
        "--log-file=$MPV_LOG"
        "--msg-level=all=warn"
    )

    # Si pas d'accélération HW, utiliser le software decoding
    if [ "$HW_ACCEL_AVAILABLE" = "false" ]; then
        warning "Désactivation de l'accélération HW pour MPV"
        mpv_args+=("--hwdec=no")
    fi

    # Configuration spécifique Pi 4/5
    if grep -q "Pi [45]" /proc/cpuinfo; then
        mpv_args+=("--profile=gpu-hq")
    fi

    echo "${mpv_args[@]}"
}

# Configuration VLC (fallback)
configure_vlc() {
    log "Configuration de VLC (mode fallback)..."

    local vlc_args=(
        # Base args
        "--fullscreen"
        "--no-video-title-show"
        "--quiet"
        "--loop"

        # Display args
        $VLC_DISPLAY_ARGS

        # Audio
        "--gain=1"

        # Logging
        "--file-logging"
        "--logfile=$VLC_LOG"
    )

    echo "${vlc_args[@]}"
}

# Lancement de MPV
start_mpv() {
    local media="$1"
    log "Démarrage de MPV avec: $media"

    local mpv_args=$(configure_mpv)

    # Vérification que MPV est installé
    if ! command -v mpv &> /dev/null; then
        error "MPV n'est pas installé"
    fi

    # Lancement avec nohup pour détacher du terminal
    nohup mpv $mpv_args "$media" > "$LOG_DIR/mpv-output.log" 2>&1 &
    local pid=$!

    echo $pid > "$PID_FILE"
    log "MPV démarré avec PID: $pid"

    # Vérification que MPV a bien démarré
    sleep 2
    if ! kill -0 $pid 2>/dev/null; then
        error "MPV n'a pas réussi à démarrer"
    fi

    return 0
}

# Lancement de VLC (fallback)
start_vlc() {
    local media="$1"
    log "Démarrage de VLC (fallback) avec: $media"

    local vlc_args=$(configure_vlc)

    # Vérification que VLC est installé
    if ! command -v vlc &> /dev/null; then
        error "VLC n'est pas installé"
    fi

    # Lancement avec nohup
    nohup vlc $vlc_args "$media" > "$LOG_DIR/vlc-output.log" 2>&1 &
    local pid=$!

    echo $pid > "$PID_FILE"
    log "VLC démarré avec PID: $pid"

    # Vérification
    sleep 2
    if ! kill -0 $pid 2>/dev/null; then
        error "VLC n'a pas réussi à démarrer"
    fi

    return 0
}

# Arrêt du player
stop_player() {
    log "Arrêt du player..."

    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            sleep 1
            if kill -0 $pid 2>/dev/null; then
                kill -9 $pid
            fi
            log "Player arrêté (PID: $pid)"
        fi
        rm -f "$PID_FILE"
    fi

    # Nettoyage des processus orphelins
    pkill -f "mpv.*pisignage" 2>/dev/null || true
    pkill -f "vlc.*pisignage" 2>/dev/null || true
}

# Fonction principale de démarrage
start() {
    local media="${1:-$PLAYLIST_FILE}"
    local player="${2:-$DEFAULT_PLAYER}"

    log "=== Démarrage Pi-Signage Player Manager v0.8.1 ==="

    # Vérification du lock
    if [ -f "$LOCK_FILE" ]; then
        error "Une instance est déjà en cours d'exécution"
    fi
    touch "$LOCK_FILE"

    # Configuration de l'environnement
    setup_display_environment

    # Vérification HW
    check_hw_acceleration

    # Vérification du média
    if [ ! -f "$media" ] && [ ! -d "$media" ]; then
        error "Média non trouvé: $media"
    fi

    # Tentative avec le player préféré
    if [ "$player" = "mpv" ]; then
        if start_mpv "$media"; then
            log "MPV démarré avec succès"
        else
            warning "Échec MPV, basculement sur VLC"
            start_vlc "$media"
        fi
    else
        start_vlc "$media"
    fi

    rm -f "$LOCK_FILE"
}

# Statut du player
status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            local player_cmd=$(ps -p $pid -o comm= 2>/dev/null)
            info "Player actif: $player_cmd (PID: $pid)"

            # Info environnement
            info "Environnement: $(detect_environment)"

            # CPU usage
            local cpu=$(ps -p $pid -o %cpu= 2>/dev/null | xargs)
            info "Utilisation CPU: ${cpu}%"

            return 0
        fi
    fi

    info "Aucun player actif"
    return 1
}

# Fonction de test
test_players() {
    log "=== Test des players ==="

    # Création d'une vidéo de test si nécessaire
    local test_video="$MEDIA_DIR/test.mp4"
    if [ ! -f "$test_video" ]; then
        warning "Vidéo de test non trouvée, utilisation de Big Buck Bunny"
        wget -q -O "$test_video" "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" || \
            error "Impossible de télécharger la vidéo de test"
    fi

    # Test MPV
    log "Test de MPV..."
    if timeout 10 mpv --vo=null --ao=null --frames=100 "$test_video" &>/dev/null; then
        log "✓ MPV fonctionne"
    else
        warning "✗ MPV a des problèmes"
    fi

    # Test VLC
    log "Test de VLC..."
    if timeout 10 vlc --intf=dummy --play-and-exit --stop-time=5 "$test_video" vlc://quit &>/dev/null; then
        log "✓ VLC fonctionne"
    else
        warning "✗ VLC a des problèmes"
    fi
}

# Point d'entrée principal
case "${1:-}" in
    start)
        start "${2:-}" "${3:-}"
        ;;
    stop)
        stop_player
        ;;
    restart)
        stop_player
        sleep 2
        start "${2:-}" "${3:-}"
        ;;
    status)
        status
        ;;
    test)
        test_players
        ;;
    env)
        setup_display_environment
        env | grep -E "DISPLAY|WAYLAND|DRM|LIBVA|GDK|QT_QPA|SDL"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|test|env} [media] [player]"
        echo ""
        echo "Options:"
        echo "  media   - Fichier média ou playlist (défaut: $PLAYLIST_FILE)"
        echo "  player  - mpv ou vlc (défaut: mpv)"
        echo ""
        echo "Exemples:"
        echo "  $0 start                    # Démarre avec playlist par défaut"
        echo "  $0 start video.mp4          # Démarre avec vidéo spécifique"
        echo "  $0 start playlist.m3u vlc   # Démarre VLC avec playlist"
        echo "  $0 test                     # Test les players"
        exit 1
        ;;
esac