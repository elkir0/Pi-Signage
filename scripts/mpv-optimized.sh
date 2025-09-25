#!/bin/bash
# PiSignage - MPV Optimized Control Script (Based on Guide)

MEDIA_DIR="/opt/pisignage/media"
CONFIG_DIR="/home/pi/.config/mpv"
SOCKET="/tmp/mpv-socket"
LOG_FILE="/opt/pisignage/logs/mpv.log"
FALLBACK_IMAGE="$MEDIA_DIR/fallback-logo.jpg"
ACTION=$1

# Detect Raspberry Pi model
get_pi_model() {
    local model=$(cat /proc/cpuinfo | grep 'Model' | cut -d: -f2 | xargs)
    if [[ "$model" == *"Pi 3"* ]]; then
        echo "pi3"
    elif [[ "$model" == *"Pi 4"* ]]; then
        echo "pi4"
    elif [[ "$model" == *"Pi 5"* ]]; then
        echo "pi5"
    else
        echo "pi4"  # Default to Pi 4 config
    fi
}

# Create optimized MPV config based on Pi model
setup_mpv_config() {
    mkdir -p "$CONFIG_DIR"
    local pi_model=$(get_pi_model)

    case $pi_model in
        pi3)
            cat > "$CONFIG_DIR/mpv.conf" << 'EOF'
# Configuration optimale Raspberry Pi 3 - PiSignage
# VideoCore IV - Support H.264 uniquement

# Accélération hardware
hwdec=mmal-copy
vo=gpu
gpu-context=drm

# Optimisations mémoire (Pi3 limité)
gpu-mem=256
cache=yes
demuxer-max-bytes=50MiB
demuxer-max-back-bytes=25MiB

# Signage 24/7
fullscreen=yes
loop-playlist=inf
keep-open=yes
no-osc=yes
no-osd-bar=yes
cursor-autohide=0

# Audio HDMI
audio-device=alsa/default:CARD=vc4hdmi0

# Contrôle IPC
input-ipc-server=/tmp/mpv-socket

# Logging
log-file=/opt/pisignage/logs/mpv.log
msg-level=all=info
quiet=yes

# Fallback si pas de vidéo
image-display-duration=inf
EOF
            ;;

        pi4|pi5)
            cat > "$CONFIG_DIR/mpv.conf" << 'EOF'
# Configuration optimale Raspberry Pi 4/5 - PiSignage
# VideoCore VI - Support H.264 + HEVC 4K

# Accélération hardware moderne
hwdec=drm-copy
vo=gpu
gpu-context=drm

# Cache optimisé Pi 4
cache=yes
demuxer-max-bytes=100MiB
demuxer-max-back-bytes=50MiB

# Signage 24/7
fullscreen=yes
loop-playlist=inf
keep-open=yes
no-osc=yes
no-osd-bar=yes
cursor-autohide=0

# Audio HDMI
audio-device=alsa/default:CARD=vc4hdmi0

# Qualité maximale
profile=high-quality
scale=ewa_lanczossharp

# Contrôle IPC
input-ipc-server=/tmp/mpv-socket

# Stabilité streaming
network-timeout=30
rtsp-transport=tcp

# Logging minimal
log-file=/opt/pisignage/logs/mpv.log
quiet=yes

# Fallback si pas de vidéo
image-display-duration=inf

# Anti-tearing
video-sync=display-resample
interpolation=yes
EOF
            ;;
    esac

    echo "Configuration MPV créée pour $pi_model"
}

# Function to show fallback image when no video
show_fallback() {
    if [ -f "$FALLBACK_IMAGE" ]; then
        echo "Affichage image fallback..." >> $LOG_FILE
        mpv --fullscreen \
            --keep-open=yes \
            --loop-file=inf \
            --no-osc \
            --no-osd-bar \
            --input-ipc-server=$SOCKET \
            "$FALLBACK_IMAGE" \
            >> $LOG_FILE 2>&1 &
    fi
}

# Check if media files exist
check_media() {
    local count=$(ls -1 $MEDIA_DIR/*.{mp4,avi,mkv,mov} 2>/dev/null | wc -l)
    if [ "$count" -eq 0 ]; then
        echo "Aucun fichier média trouvé" >> $LOG_FILE
        show_fallback
        return 1
    fi
    return 0
}

case $ACTION in
    start)
        # Setup config if not exists
        if [ ! -f "$CONFIG_DIR/mpv.conf" ]; then
            setup_mpv_config
        fi

        # Kill any existing MPV
        pkill -f mpv 2>/dev/null || true
        sleep 1

        # Check for media files
        if ! check_media; then
            echo "Fallback mode activé"
            exit 0
        fi

        # Start MPV with optimized settings
        echo "$(date): Démarrage MPV optimisé..." >> $LOG_FILE

        mpv --playlist=- \
            >> $LOG_FILE 2>&1 < <(ls $MEDIA_DIR/*.{mp4,avi,mkv,mov} 2>/dev/null) &

        MPV_PID=$!
        echo "MPV started (PID: $MPV_PID)"

        # Watchdog to restart if crashes
        (
            sleep 5
            while kill -0 $MPV_PID 2>/dev/null; do
                sleep 30
            done
            echo "$(date): MPV crashed, restarting..." >> $LOG_FILE
            $0 start
        ) &

        exit 0
        ;;

    stop)
        pkill -f mpv 2>/dev/null || true
        echo "MPV stopped"
        exit 0
        ;;

    restart)
        $0 stop
        sleep 2
        $0 start
        exit 0
        ;;

    status)
        if pgrep -f mpv > /dev/null; then
            echo "MPV is running"
            # Get current file from socket
            if [ -S "$SOCKET" ]; then
                echo '{"command": ["get_property", "filename"]}' | \
                    socat - "$SOCKET" 2>/dev/null | \
                    python3 -c "import json,sys; print(json.load(sys.stdin).get('data',''))" 2>/dev/null
            fi
        else
            echo "MPV is not running"
        fi
        exit 0
        ;;

    setup)
        setup_mpv_config
        echo "Configuration MPV mise à jour"
        exit 0
        ;;

    fallback)
        pkill -f mpv 2>/dev/null || true
        show_fallback
        echo "Mode fallback activé"
        exit 0
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|status|setup|fallback}"
        exit 1
        ;;
esac