#!/bin/bash
# PiSignage - Universal Player Manager (VLC/MPV)
# Gestion unifiée pour VLC et MPV avec détection automatique Pi3/Pi4

MEDIA_DIR="/opt/pisignage/media"
CONFIG_FILE="/opt/pisignage/config/player-config.json"
LOG_DIR="/opt/pisignage/logs"
SOCKET="/tmp/player-socket"
ACTION=$1
PLAYER=$2

# Si pas de player spécifié, utiliser celui configuré
if [ -z "$PLAYER" ]; then
    PLAYER=$(jq -r '.player.current' "$CONFIG_FILE" 2>/dev/null || echo "mpv")
fi

# Détection modèle Raspberry Pi
get_pi_model() {
    local model=$(cat /proc/cpuinfo | grep 'Model' | cut -d: -f2 | xargs)
    if [[ "$model" == *"Pi 3"* ]]; then
        echo "pi3"
    elif [[ "$model" == *"Pi 4"* ]]; then
        echo "pi4"
    elif [[ "$model" == *"Pi 5"* ]]; then
        echo "pi5"
    else
        echo "pi4"  # Par défaut
    fi
}

PI_MODEL=$(get_pi_model)

# ========== FONCTIONS VLC ==========
setup_vlc_config() {
    echo "Configuration VLC pour $PI_MODEL..."
    mkdir -p ~/.config/vlc

    cat > ~/.config/vlc/vlcrc << 'EOF'
# Configuration VLC Signage - PiSignage
intf=dummy
extraintf=http
video-title-show=0
fullscreen=1
loop=1
random=0
volume=256
http-password=signage123
http-port=8080
playlist-autostart=1
file-caching=2000
network-caching=3000
qt-privacy-ask=0
qt-system-tray=0
EOF

    if [ "$PI_MODEL" = "pi3" ]; then
        cat >> ~/.config/vlc/vlcrc << 'EOF'
# Optimisations Pi 3
vout=mmal_xsplitter
codec=mmal
h264-fps=30
avcodec-skiploopfilter=4
EOF
    else
        cat >> ~/.config/vlc/vlcrc << 'EOF'
# Optimisations Pi 4
vout=drm
avcodec-hw=v4l2m2m
avcodec-hw=drm
EOF
    fi
}

start_vlc() {
    echo "Démarrage VLC ($PI_MODEL)..."
    pkill -f vlc 2>/dev/null
    sleep 1

    if [ "$PI_MODEL" = "pi3" ]; then
        cvlc --vout mmal_xsplitter --codec mmal --h264-fps 30 \
             --fullscreen --loop --no-video-title-show \
             --extraintf http --http-password signage123 \
             "$MEDIA_DIR"/*.{mp4,avi,mkv,mov} 2>/dev/null \
             > "$LOG_DIR/vlc.log" 2>&1 &
    else
        cvlc --vout drm --avcodec-hw v4l2m2m \
             --fullscreen --loop --no-video-title-show \
             --extraintf http --http-password signage123 \
             "$MEDIA_DIR"/*.{mp4,avi,mkv,mov} 2>/dev/null \
             > "$LOG_DIR/vlc.log" 2>&1 &
    fi

    echo "VLC started (PID: $!)"
}

stop_vlc() {
    pkill -f vlc 2>/dev/null || true
    echo "VLC stopped"
}

status_vlc() {
    if pgrep -f vlc > /dev/null; then
        echo "VLC is running"
        # Obtenir le statut via HTTP API
        curl -s --user :signage123 "http://localhost:8080/requests/status.json" 2>/dev/null | \
            jq -r '.information.category.meta.filename' 2>/dev/null
    else
        echo "VLC is not running"
    fi
}

# ========== FONCTIONS MPV ==========
setup_mpv_config() {
    echo "Configuration MPV pour $PI_MODEL..."
    mkdir -p ~/.config/mpv

    if [ "$PI_MODEL" = "pi3" ]; then
        cat > ~/.config/mpv/mpv.conf << 'EOF'
# Configuration MPV Pi 3 - PiSignage
hwdec=mmal-copy
vo=gpu
gpu-context=drm
gpu-mem=256
cache=yes
demuxer-max-bytes=50MiB
demuxer-max-back-bytes=25MiB
fullscreen=yes
loop-playlist=inf
keep-open=yes
osc=no
osd-bar=no
cursor-autohide=0
audio-device=alsa/default:CARD=vc4hdmi0
input-ipc-server=/tmp/mpv-socket
log-file=/opt/pisignage/logs/mpv.log
quiet=yes
image-display-duration=inf
EOF
    else
        cat > ~/.config/mpv/mpv.conf << 'EOF'
# Configuration MPV Pi 4/5 - PiSignage
hwdec=drm-copy
vo=gpu
gpu-context=drm
cache=yes
demuxer-max-bytes=100MiB
demuxer-max-back-bytes=50MiB
fullscreen=yes
loop-playlist=inf
keep-open=yes
osc=no
osd-bar=no
cursor-autohide=0
audio-device=alsa/default:CARD=vc4hdmi0
profile=high-quality
scale=ewa_lanczossharp
input-ipc-server=/tmp/mpv-socket
network-timeout=30
rtsp-transport=tcp
log-file=/opt/pisignage/logs/mpv.log
quiet=yes
image-display-duration=inf
video-sync=display-resample
interpolation=yes
EOF
    fi
}

start_mpv() {
    echo "Démarrage MPV ($PI_MODEL)..."
    pkill -f mpv 2>/dev/null
    sleep 1

    # Configurer l'affichage
    export DISPLAY=:0
    export XAUTHORITY=/home/pi/.Xauthority

    # Créer playlist
    ls "$MEDIA_DIR"/*.{mp4,avi,mkv,mov,jpg,png} 2>/dev/null > /tmp/mpv-playlist.txt

    if [ -s /tmp/mpv-playlist.txt ]; then
        # Lancer MPV avec les bons paramètres pour X11/Wayland
        DISPLAY=:0 mpv \
            --vo=gpu \
            --gpu-context=x11egl \
            --hwdec=auto \
            --fullscreen \
            --loop-playlist=inf \
            --no-osc \
            --no-input-default-bindings \
            --input-ipc-server=/tmp/mpv-socket \
            --playlist=/tmp/mpv-playlist.txt \
            >> "$LOG_DIR/mpv.log" 2>&1 &
        echo "MPV started (PID: $!)"
    else
        echo "Aucun média trouvé, activation mode fallback"
        if [ -f "$MEDIA_DIR/fallback-logo.jpg" ]; then
            DISPLAY=:0 mpv \
                --vo=gpu \
                --gpu-context=x11egl \
                --fullscreen \
                --keep-open=yes \
                --loop-file=inf \
                "$MEDIA_DIR/fallback-logo.jpg" \
                >> "$LOG_DIR/mpv.log" 2>&1 &
        fi
    fi
}

stop_mpv() {
    pkill -f mpv 2>/dev/null || true
    echo "MPV stopped"
}

status_mpv() {
    if pgrep -f mpv > /dev/null; then
        echo "MPV is running"
        # Obtenir le statut via socket IPC
        if [ -S "/tmp/mpv-socket" ]; then
            echo '{"command": ["get_property", "filename"]}' | \
                socat - /tmp/mpv-socket 2>/dev/null | \
                jq -r '.data' 2>/dev/null
        fi
    else
        echo "MPV is not running"
    fi
}

# ========== ACTIONS PRINCIPALES ==========
case "$ACTION" in
    start)
        if [ "$PLAYER" = "vlc" ]; then
            start_vlc
        else
            start_mpv
        fi
        # Sauvegarder le player actuel
        jq ".player.current = \"$PLAYER\"" "$CONFIG_FILE" > /tmp/config.tmp && \
            mv /tmp/config.tmp "$CONFIG_FILE"
        ;;

    stop)
        if [ "$PLAYER" = "vlc" ]; then
            stop_vlc
        else
            stop_mpv
        fi
        ;;

    restart)
        $0 stop "$PLAYER"
        sleep 2
        $0 start "$PLAYER"
        ;;

    status)
        if [ "$PLAYER" = "vlc" ]; then
            status_vlc
        else
            status_mpv
        fi
        ;;

    setup)
        echo "Configuration des deux players..."
        setup_vlc_config
        setup_mpv_config
        echo "Configuration terminée pour VLC et MPV"
        ;;

    switch)
        # Basculer entre VLC et MPV
        CURRENT=$(jq -r '.player.current' "$CONFIG_FILE")
        if [ "$CURRENT" = "vlc" ]; then
            NEW_PLAYER="mpv"
        else
            NEW_PLAYER="vlc"
        fi
        echo "Basculement de $CURRENT vers $NEW_PLAYER..."
        $0 stop "$CURRENT"
        sleep 2
        $0 start "$NEW_PLAYER"
        ;;

    info)
        echo "========== PiSignage Player Info =========="
        echo "Modèle Pi: $PI_MODEL"
        echo "Player actuel: $(jq -r '.player.current' "$CONFIG_FILE")"
        echo "Players disponibles: VLC, MPV"
        echo ""
        echo "Statut VLC:"
        status_vlc
        echo ""
        echo "Statut MPV:"
        status_mpv
        echo "==========================================="
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|status|setup|switch|info} [vlc|mpv]"
        echo ""
        echo "Exemples:"
        echo "  $0 start        # Démarre le player par défaut (MPV)"
        echo "  $0 start vlc    # Démarre VLC"
        echo "  $0 start mpv    # Démarre MPV"
        echo "  $0 switch       # Bascule entre VLC et MPV"
        echo "  $0 setup        # Configure les deux players"
        echo "  $0 info         # Affiche les informations"
        exit 1
        ;;
esac