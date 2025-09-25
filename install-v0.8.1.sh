#!/bin/bash

# Pi-Signage v0.8.1 - Installation Script
# Optimisé pour Raspberry Pi OS Bookworm avec support Wayland/X11
# Date: 2025-09-25

set -e

# Configuration
PISIGNAGE_DIR="/opt/pisignage"
PISIGNAGE_USER="${SUDO_USER:-$USER}"
PISIGNAGE_GROUP="pisignage"
LOG_FILE="/var/log/pisignage-install.log"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging
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

# Vérification root
if [[ $EUID -ne 0 ]]; then
   error "Ce script doit être exécuté avec sudo"
fi

log "=== Début installation Pi-Signage v0.8.1 ==="

# Détection de l'OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_CODENAME="$VERSION_CODENAME"
    else
        error "Impossible de détecter l'OS"
    fi

    log "OS détecté: $OS_NAME $OS_VERSION ($OS_CODENAME)"

    if [[ "$OS_CODENAME" != "bookworm" ]]; then
        warning "Cette version est optimisée pour Bookworm. Compatibilité limitée sur $OS_CODENAME"
    fi
}

# Détection du modèle de Pi
detect_pi_model() {
    PI_MODEL=$(cat /proc/cpuinfo | grep "Model" | cut -d':' -f2 | xargs)
    log "Modèle Pi détecté: $PI_MODEL"

    # Détection des capacités
    if [[ "$PI_MODEL" == *"Pi 4"* ]] || [[ "$PI_MODEL" == *"Pi 5"* ]]; then
        HW_ACCEL="full"
    elif [[ "$PI_MODEL" == *"Pi 3"* ]] || [[ "$PI_MODEL" == *"Zero 2"* ]]; then
        HW_ACCEL="partial"
    else
        HW_ACCEL="none"
        warning "Accélération HW limitée sur ce modèle"
    fi
}

# Installation des paquets système
install_packages() {
    log "Installation des paquets système..."

    # Mise à jour des sources
    apt-get update || error "Échec mise à jour APT"

    # Paquets essentiels pour Bookworm
    PACKAGES=(
        # Lecteurs vidéo
        "mpv"
        "vlc"

        # Accélération HW Raspberry Pi
        "raspberrypi-ffmpeg"
        "libraspberrypi-bin"

        # Support Wayland/DRM
        "seatd"
        "libdrm2"
        "libdrm-tests"
        "libgl1-mesa-dri"
        "mesa-utils"

        # V4L2 pour accélération vidéo
        "v4l-utils"
        "libv4l-0"

        # Gestion d'affichage
        "wlr-randr"
        "wayland-utils"

        # Outils système
        "git"
        "curl"
        "wget"
        "unzip"
        "python3-pip"
        "python3-venv"
        "nodejs"
        "npm"

        # Capture d'écran
        "scrot"
        "grim"
        "slurp"

        # Monitoring
        "htop"
        "iotop"
        "nethogs"
    )

    for package in "${PACKAGES[@]}"; do
        log "Installation de $package..."
        apt-get install -y "$package" || warning "Impossible d'installer $package"
    done

    log "Paquets système installés"
}

# Configuration des groupes et permissions
setup_permissions() {
    log "Configuration des permissions..."

    # Création du groupe pisignage
    groupadd -f "$PISIGNAGE_GROUP"

    # Ajout de l'utilisateur aux groupes nécessaires
    usermod -aG video "$PISIGNAGE_USER"
    usermod -aG render "$PISIGNAGE_USER"
    usermod -aG audio "$PISIGNAGE_USER"
    usermod -aG input "$PISIGNAGE_USER"
    usermod -aG "$PISIGNAGE_GROUP" "$PISIGNAGE_USER"

    # Permissions pour DRM/KMS
    if [ -e /dev/dri/card0 ]; then
        chmod 660 /dev/dri/card0
        chgrp video /dev/dri/card0
    fi

    if [ -e /dev/dri/renderD128 ]; then
        chmod 660 /dev/dri/renderD128
        chgrp render /dev/dri/renderD128
    fi

    log "Permissions configurées pour l'utilisateur $PISIGNAGE_USER"
}

# Configuration de seatd
setup_seatd() {
    log "Configuration de seatd pour l'accès Wayland..."

    # Activation et démarrage de seatd
    systemctl enable seatd
    systemctl start seatd

    # Ajout de l'utilisateur au groupe seat
    usermod -aG seat "$PISIGNAGE_USER"

    # Configuration seatd
    mkdir -p /etc/seatd
    cat > /etc/seatd/seatd.conf << EOF
# Configuration seatd pour Pi-Signage
[seatd]
loglevel=info
EOF

    log "seatd configuré"
}

# Création de la structure de répertoires
create_directories() {
    log "Création de la structure de répertoires..."

    # Répertoires principaux
    mkdir -p "$PISIGNAGE_DIR"/{scripts,config,media,logs,cache}
    mkdir -p "$PISIGNAGE_DIR"/config/{mpv,vlc}

    # Répertoire utilisateur pour services systemd
    sudo -u "$PISIGNAGE_USER" mkdir -p "/home/$PISIGNAGE_USER/.config/systemd/user"
    sudo -u "$PISIGNAGE_USER" mkdir -p "/home/$PISIGNAGE_USER/.config/mpv"

    # Permissions
    chown -R "$PISIGNAGE_USER:$PISIGNAGE_GROUP" "$PISIGNAGE_DIR"
    chmod 755 "$PISIGNAGE_DIR"
    chmod 755 "$PISIGNAGE_DIR"/scripts

    log "Structure de répertoires créée"
}

# Configuration MPV optimisée pour Bookworm
setup_mpv_config() {
    log "Configuration de MPV pour Bookworm..."

    # Configuration globale MPV
    cat > "$PISIGNAGE_DIR/config/mpv/mpv.conf" << 'EOF'
# Configuration MPV optimisée pour Raspberry Pi OS Bookworm
# v0.8.1 - Support Wayland/X11/DRM

# Accélération matérielle
hwdec=drm
hwdec-codecs=all

# Sortie vidéo
vo=gpu-next
gpu-context=auto

# Qualité
profile=gpu-hq
scale=ewa_lanczossharp
cscale=ewa_lanczossharp
video-sync=display-resample
interpolation=yes
tscale=oversample

# Performance
cache=yes
cache-secs=10
demuxer-max-bytes=50M
demuxer-max-back-bytes=25M

# Audio
audio-pitch-correction=yes
volume=100
volume-max=150

# Affichage
fullscreen=yes
screen=0
cursor-autohide=1000
osd-level=1
osd-duration=2000

# Lecture
loop-playlist=inf
loop-file=inf
keep-open=yes

# Réseau
network-timeout=30
ytdl-format=bestvideo[height<=1080]+bestaudio/best[height<=1080]

# Logs
log-file=/opt/pisignage/logs/mpv.log
msg-level=all=warn,ffmpeg/video=fatal
EOF

    # Configuration utilisateur MPV
    sudo -u "$PISIGNAGE_USER" cp "$PISIGNAGE_DIR/config/mpv/mpv.conf" "/home/$PISIGNAGE_USER/.config/mpv/mpv.conf"

    log "Configuration MPV créée"
}

# Configuration VLC (fallback)
setup_vlc_config() {
    log "Configuration de VLC (mode fallback)..."

    # Configuration VLC pour Wayland
    cat > "$PISIGNAGE_DIR/config/vlc/vlcrc" << 'EOF'
# Configuration VLC pour Pi-Signage v0.8.1
# Mode fallback - pas d'accélération HW sur Bookworm

[main]
intf=dummy
quiet=2

[video]
vout=gles2
fullscreen=1
video-on-top=1
video-title-show=0
video-title-timeout=0
deinterlace=-1
deinterlace-mode=blend

[gles2]
gles2-text-renderer=freetype

[audio]
volume=256
audio-replay-gain-mode=track

[core]
one-instance=0
playlist-enqueue=0
EOF

    log "Configuration VLC créée"
}

# Installation du script de détection d'environnement
install_environment_detector() {
    log "Installation du détecteur d'environnement..."

    cat > "$PISIGNAGE_DIR/scripts/detect-environment.sh" << 'EOF'
#!/bin/bash

# Détection de l'environnement graphique
# Retourne: wayland, x11, ou tty

detect_display_server() {
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
        else
            echo "unknown"
        fi
    fi
}

# Export des variables pour MPV/VLC
setup_player_environment() {
    local display_server=$(detect_display_server)

    case "$display_server" in
        wayland)
            export GDK_BACKEND=wayland
            export QT_QPA_PLATFORM=wayland
            export SDL_VIDEODRIVER=wayland
            export LIBVA_DRIVER_NAME=v4l2_request
            export LIBVA_V4L2_REQUEST_VIDEO_PATH=/dev/video10
            echo "Environment: Wayland"
            ;;
        x11)
            export GDK_BACKEND=x11
            export QT_QPA_PLATFORM=xcb
            export SDL_VIDEODRIVER=x11
            echo "Environment: X11"
            ;;
        tty)
            export GST_VAAPI_ALL_DRIVERS=1
            export LIBVA_DRIVER_NAME=v4l2_request
            echo "Environment: TTY/DRM"
            ;;
    esac
}

# Point d'entrée principal
if [ "$1" == "detect" ]; then
    detect_display_server
elif [ "$1" == "setup" ]; then
    setup_player_environment
else
    echo "Usage: $0 {detect|setup}"
fi
EOF

    chmod +x "$PISIGNAGE_DIR/scripts/detect-environment.sh"
    log "Détecteur d'environnement installé"
}

# Fin de la partie 1...
# Continuer avec player-manager, services, etc.

log "=== Phase 1 d'installation terminée ==="
log "Continuez avec la partie 2 du script..."