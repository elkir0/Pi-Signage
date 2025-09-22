#!/bin/bash

# PiSignage v0.8.0 - Configuration VLC
# Optimisation GPU/mémoire et paramètres vidéo
# Auteur: Claude Code
# Date: 22/09/2025

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
PISIGNAGE_USER="pi"
VLC_CONFIG_DIR="/home/$PISIGNAGE_USER/.config/vlc"
SCRIPTS_DIR="/opt/pisignage/scripts"

log() {
    echo -e "${GREEN}[VLC] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[VLC] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[VLC] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[VLC] INFO: $1${NC}"
}

# Configuration GPU et mémoire
configure_gpu_memory() {
    log "Configuration GPU et mémoire..."

    # Backup config.txt
    sudo cp /boot/config.txt /boot/config.txt.backup.$(date +%Y%m%d_%H%M%S)

    # Configuration GPU memory split
    if ! grep -q "gpu_mem=" /boot/config.txt; then
        echo "gpu_mem=128" | sudo tee -a /boot/config.txt
        log "✅ GPU memory configurée (128MB)"
    else
        sudo sed -i 's/gpu_mem=.*/gpu_mem=128/' /boot/config.txt
        log "✅ GPU memory mise à jour (128MB)"
    fi

    # Activation accélération matérielle
    if ! grep -q "dtoverlay=vc4-fkms-v3d" /boot/config.txt; then
        echo "dtoverlay=vc4-fkms-v3d" | sudo tee -a /boot/config.txt
        log "✅ Accélération matérielle activée"
    fi

    # Configuration additionnelle pour VLC
    if ! grep -q "hdmi_force_hotplug=1" /boot/config.txt; then
        echo "hdmi_force_hotplug=1" | sudo tee -a /boot/config.txt
        log "✅ HDMI hotplug forcé"
    fi

    if ! grep -q "hdmi_drive=2" /boot/config.txt; then
        echo "hdmi_drive=2" | sudo tee -a /boot/config.txt
        log "✅ HDMI audio activé"
    fi

    log "✅ Configuration GPU terminée"
}

# Configuration VLC
configure_vlc() {
    log "Configuration VLC..."

    # Création du répertoire de configuration
    sudo -u $PISIGNAGE_USER mkdir -p "$VLC_CONFIG_DIR"

    # Configuration VLC optimisée pour Raspberry Pi
    cat << 'EOF' | sudo -u $PISIGNAGE_USER tee "$VLC_CONFIG_DIR/vlcrc" > /dev/null
[main]
# Interface
intf=dummy
extraintf=

# Vidéo
vout=mmal_vout
mmal-display=hdmi-1
mmal-layer=1
avcodec-hw=mmal
avcodec-threads=4

# Audio
aout=pulse
alsa-audio-device=default

# Performance
mmx=1
3dn=1
sse=1
sse2=1
sse3=1
ssse3=1
sse41=1
sse42=1

# Cache
file-caching=3000
network-caching=3000
sout-mux-caching=3000

# Fullscreen par défaut
fullscreen=1
video-on-top=1

# Désactiver contrôles
qt-start-minimized=1
qt-system-tray=0
qt-notification=0

# Loop par défaut
loop=1
repeat=1

# OSD désactivé
osd=0
video-title-show=0

# Désactiver screensaver
disable-screensaver=1
EOF

    log "✅ Configuration VLC créée"
}

# Scripts de contrôle VLC
create_vlc_scripts() {
    log "Création des scripts de contrôle VLC..."

    sudo mkdir -p "$SCRIPTS_DIR"

    # Script de contrôle VLC principal
    cat << 'EOF' | sudo tee "$SCRIPTS_DIR/vlc-control.sh" > /dev/null
#!/bin/bash

# PiSignage VLC Control Script v0.8.0

VLC_PID_FILE="/tmp/vlc-pisignage.pid"
MEDIA_DIR="/opt/pisignage/media"
LOG_FILE="/opt/pisignage/logs/vlc.log"

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Démarrer VLC
start_vlc() {
    local media_file="$1"

    if [ -z "$media_file" ]; then
        log "ERROR: Aucun fichier média spécifié"
        exit 1
    fi

    if [ ! -f "$media_file" ]; then
        log "ERROR: Fichier non trouvé: $media_file"
        exit 1
    fi

    # Arrêter VLC existant
    stop_vlc

    # Démarrer nouveau VLC
    log "Démarrage VLC avec: $media_file"

    DISPLAY=:0 cvlc \
        --intf dummy \
        --fullscreen \
        --loop \
        --no-osd \
        --no-video-title-show \
        --vout mmal_vout \
        --aout pulse \
        --avcodec-hw mmal \
        --file-caching 3000 \
        --network-caching 3000 \
        --quiet \
        "$media_file" &

    echo $! > "$VLC_PID_FILE"
    log "VLC démarré avec PID: $(cat $VLC_PID_FILE)"
}

# Arrêter VLC
stop_vlc() {
    if [ -f "$VLC_PID_FILE" ]; then
        local pid=$(cat "$VLC_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "Arrêt VLC PID: $pid"
            kill "$pid"
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid"
                log "VLC forcé à s'arrêter"
            fi
        fi
        rm -f "$VLC_PID_FILE"
    fi

    # Nettoyage des processus VLC restants
    pkill -f vlc 2>/dev/null || true
    log "VLC arrêté"
}

# Status VLC
status_vlc() {
    if [ -f "$VLC_PID_FILE" ]; then
        local pid=$(cat "$VLC_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "VLC actif (PID: $pid)"
            return 0
        else
            echo "VLC inactif (PID file obsolète)"
            rm -f "$VLC_PID_FILE"
            return 1
        fi
    else
        echo "VLC inactif"
        return 1
    fi
}

# Commandes
case "$1" in
    start)
        start_vlc "$2"
        ;;
    stop)
        stop_vlc
        ;;
    restart)
        stop_vlc
        sleep 1
        start_vlc "$2"
        ;;
    status)
        status_vlc
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status} [fichier_media]"
        echo "Exemples:"
        echo "  $0 start /opt/pisignage/media/video.mp4"
        echo "  $0 stop"
        echo "  $0 status"
        exit 1
        ;;
esac
EOF

    sudo chmod +x "$SCRIPTS_DIR/vlc-control.sh"
    log "✅ Script vlc-control.sh créé"

    # Script de lecture de playlist
    cat << 'EOF' | sudo tee "$SCRIPTS_DIR/vlc-playlist.sh" > /dev/null
#!/bin/bash

# PiSignage VLC Playlist Script v0.8.0

PLAYLIST_FILE="/opt/pisignage/media/playlists/current.m3u"
LOG_FILE="/opt/pisignage/logs/vlc-playlist.log"
VLC_PID_FILE="/tmp/vlc-playlist.pid"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

start_playlist() {
    if [ ! -f "$PLAYLIST_FILE" ]; then
        log "ERROR: Playlist non trouvée: $PLAYLIST_FILE"
        exit 1
    fi

    # Arrêter VLC existant
    if [ -f "$VLC_PID_FILE" ]; then
        local pid=$(cat "$VLC_PID_FILE")
        kill "$pid" 2>/dev/null || true
        rm -f "$VLC_PID_FILE"
    fi

    log "Démarrage playlist: $PLAYLIST_FILE"

    DISPLAY=:0 cvlc \
        --intf dummy \
        --fullscreen \
        --loop \
        --random \
        --no-osd \
        --no-video-title-show \
        --vout mmal_vout \
        --aout pulse \
        --avcodec-hw mmal \
        --quiet \
        "$PLAYLIST_FILE" &

    echo $! > "$VLC_PID_FILE"
    log "Playlist démarrée avec PID: $(cat $VLC_PID_FILE)"
}

case "$1" in
    start)
        start_playlist
        ;;
    stop)
        if [ -f "$VLC_PID_FILE" ]; then
            local pid=$(cat "$VLC_PID_FILE")
            kill "$pid" 2>/dev/null || true
            rm -f "$VLC_PID_FILE"
            log "Playlist arrêtée"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
EOF

    sudo chmod +x "$SCRIPTS_DIR/vlc-playlist.sh"
    log "✅ Script vlc-playlist.sh créé"
}

# Test VLC
test_vlc() {
    log "Test de VLC..."

    # Vérifier installation VLC
    if ! command -v vlc >/dev/null 2>&1; then
        error "VLC non installé"
    fi

    # Test version VLC
    local vlc_version=$(vlc --version 2>&1 | head -1)
    info "Version VLC: $vlc_version"

    # Test des modules MMAL
    if vlc --list 2>/dev/null | grep -q mmal; then
        log "✅ Module MMAL disponible"
    else
        warn "Module MMAL non trouvé"
    fi

    # Vérifier les scripts
    if [ -x "$SCRIPTS_DIR/vlc-control.sh" ]; then
        log "✅ Script vlc-control.sh créé et exécutable"
    else
        error "Script vlc-control.sh manquant"
    fi

    log "✅ Test VLC terminé"
}

# Fonction principale
main() {
    log "🎬 Configuration VLC pour PiSignage v0.8.0"

    configure_gpu_memory
    configure_vlc
    create_vlc_scripts
    test_vlc

    echo ""
    log "✅ Configuration VLC terminée!"
    warn "⚠️  REDÉMARRAGE REQUIS pour appliquer les changements GPU"
    echo ""
    info "Scripts créés:"
    info "  - $SCRIPTS_DIR/vlc-control.sh"
    info "  - $SCRIPTS_DIR/vlc-playlist.sh"
    echo ""
    info "Commandes utiles:"
    info "  $SCRIPTS_DIR/vlc-control.sh start /path/to/video.mp4"
    info "  $SCRIPTS_DIR/vlc-control.sh stop"
    info "  $SCRIPTS_DIR/vlc-control.sh status"
    echo ""
}

# Exécution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi