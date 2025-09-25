#!/bin/bash

# Pi-Signage v0.8.1 - Fix pour Raspberry Pi OS Bookworm
# Script minimal avec SEULEMENT les packages existants
# Date: 2025-09-25

set -e

# Configuration
PISIGNAGE_DIR="/opt/pisignage"
PISIGNAGE_USER="${SUDO_USER:-$USER}"
LOG_FILE="/var/log/pisignage-fix-bookworm.log"

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

log "=== Fix Pi-Signage v0.8.1 pour Bookworm - Mode Minimal ==="

# Mise à jour du système
log "Mise à jour du système..."
apt-get update || error "Échec de la mise à jour APT"
apt-get upgrade -y || warning "Échec partiel de la mise à niveau"

# Installation des packages EXISTANTS seulement
install_minimal_packages() {
    log "Installation des packages minimaux pour Bookworm..."

    # Packages vérifiés comme existants
    MINIMAL_PACKAGES=(
        # Environnement graphique minimal
        "lightdm"
        "lightdm-autologin-greeter"
        "openbox"
        "lxde-core"
        "lxde-common"

        # Lecteurs vidéo
        "vlc"
        "vlc-plugin-base"
        "vlc-plugin-video-output"
        "mpv"

        # Compositeurs Wayland disponibles
        "labwc"
        "weston"

        # Support DRM/KMS
        "libdrm2"
        "mesa-utils"
        "libgl1-mesa-dri"

        # Accélération Raspberry Pi
        "libraspberrypi-bin"
        "v4l-utils"

        # Wayland utilitaires
        "wayland-utils"
        "wlr-randr"

        # Capture d'écran
        "scrot"
        "grim"
        "slurp"

        # Utilitaires système
        "git"
        "curl"
        "wget"
        "unzip"
        "htop"

        # Support audio/vidéo
        "alsa-utils"
        "pulseaudio"
    )

    for package in "${MINIMAL_PACKAGES[@]}"; do
        log "Installation de $package..."
        if apt-get install -y "$package" 2>/dev/null; then
            log "✓ $package installé avec succès"
        else
            warning "✗ Impossible d'installer $package - package introuvable"
        fi
    done

    log "Installation des packages terminée"
}

# Configuration autologin graphique
configure_autologin() {
    log "Configuration de l'autologin graphique..."

    # Configuration de LightDM pour autologin
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/01-pisignage-autologin.conf << EOF
[Seat:*]
autologin-user=$PISIGNAGE_USER
autologin-user-timeout=0
user-session=openbox
greeter-session=lightdm-autologin-greeter
EOF

    # Activation du service LightDM
    systemctl enable lightdm
    systemctl set-default graphical.target

    # Ajout de l'utilisateur au groupe autologin
    groupadd -f autologin
    usermod -a -G autologin "$PISIGNAGE_USER"

    log "Autologin configuré pour l'utilisateur $PISIGNAGE_USER"
}

# Configuration environnement graphique minimal
configure_minimal_desktop() {
    log "Configuration de l'environnement de bureau minimal..."

    # Création du répertoire de configuration utilisateur
    CONF_DIR="/home/$PISIGNAGE_USER/.config"
    sudo -u "$PISIGNAGE_USER" mkdir -p "$CONF_DIR"/{openbox,autostart}

    # Configuration Openbox
    cat > "$CONF_DIR/openbox/rc.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc"
		xmlns:xi="http://www.w3.org/2001/XInclude">
<resistance>
  <strength>10</strength>
  <screen_edge_strength>20</screen_edge_strength>
</resistance>
<focus>
  <focusNew>yes</focusNew>
  <followMouse>no</followMouse>
  <focusLast>yes</focusLast>
  <underMouse>no</underMouse>
  <focusDelay>200</focusDelay>
  <raiseOnFocus>no</raiseOnFocus>
</focus>
<placement>
  <policy>Smart</policy>
  <center>yes</center>
  <monitor>Primary</monitor>
  <primaryMonitor>1</primaryMonitor>
</placement>
<theme>
  <name>Clearlooks</name>
  <titleLayout>NLIMC</titleLayout>
  <keepBorder>yes</keepBorder>
  <animateIconify>yes</animateIconify>
  <font place="ActiveWindow">
    <name>sans</name>
    <size>8</size>
    <weight>bold</weight>
    <slant>normal</slant>
  </font>
</theme>
<desktops>
  <number>1</number>
  <firstdesk>1</firstdesk>
  <names>
    <name>Desktop 1</name>
  </names>
  <popupTime>875</popupTime>
</desktops>
<resize>
  <drawContents>yes</drawContents>
  <popupShow>Nonpixel</popupShow>
  <popupPosition>Center</popupPosition>
  <popupFixedPosition>
    <x>10</x>
    <y>10</y>
  </popupFixedPosition>
</resize>
<applications>
  <application name="vlc">
    <fullscreen>yes</fullscreen>
    <layer>above</layer>
  </application>
  <application name="mpv">
    <fullscreen>yes</fullscreen>
    <layer>above</layer>
  </application>
</applications>
</openbox_config>
EOF

    # Script d'autostart Openbox
    cat > "$CONF_DIR/openbox/autostart" << 'EOF'
#!/bin/bash

# Désactiver l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Cacher le curseur après 2 secondes d'inactivité
unclutter -idle 2 -root &

# Attendre que l'interface graphique soit prête
sleep 3

# Lancer VLC avec Big Buck Bunny en plein écran
vlc --fullscreen --no-video-title-show --loop --intf dummy \
    "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" &
EOF

    chmod +x "$CONF_DIR/openbox/autostart"
    chown -R "$PISIGNAGE_USER:$PISIGNAGE_USER" "$CONF_DIR"

    log "Environnement de bureau minimal configuré"
}

# Configuration VLC pour l'affichage optimal
configure_vlc_optimal() {
    log "Configuration optimale de VLC..."

    # Répertoire de configuration VLC
    VLC_CONF_DIR="/home/$PISIGNAGE_USER/.config/vlc"
    sudo -u "$PISIGNAGE_USER" mkdir -p "$VLC_CONF_DIR"

    # Configuration VLC optimisée pour Raspberry Pi
    cat > "$VLC_CONF_DIR/vlcrc" << 'EOF'
# Configuration VLC pour Pi-Signage Minimal v0.8.1
# Optimisé pour Raspberry Pi OS Bookworm

[main]
intf=dummy
extraintf=
one-instance=0
playlist-enqueue=0
video=1
audio=1

[video]
fullscreen=1
embedded-video=0
video-on-top=1
video-wallpaper=0
disable-screensaver=1
video-title-show=0
video-title-timeout=0
video-title-position=8
snapshot-preview=1
snapshot-sequential=0

[opengl]
opengl=1

[gles2]
gles2=1

[audio]
volume=256
audio-replay-gain-mode=none
audio-replay-gain-preamp=0.000000
audio-replay-gain-default=-7.000000
audio-replay-gain-peak-protection=1
audio-time-stretch=1

[core]
volume-save=1
volume-step=5.000000
audio-language=
sub-language=
preferred-resolution=4

[stream_filter]
stream-filter=
EOF

    chown -R "$PISIGNAGE_USER:$PISIGNAGE_USER" "$VLC_CONF_DIR"

    log "Configuration VLC optimale créée"
}

# Configuration des permissions système
setup_permissions() {
    log "Configuration des permissions système..."

    # Groupes nécessaires pour l'affichage et l'audio
    usermod -a -G video "$PISIGNAGE_USER"
    usermod -a -G audio "$PISIGNAGE_USER"
    usermod -a -G render "$PISIGNAGE_USER"
    usermod -a -G input "$PISIGNAGE_USER"

    # Permissions DRM si disponibles
    if [ -e /dev/dri/card0 ]; then
        chmod 666 /dev/dri/card0
    fi

    if [ -e /dev/dri/renderD128 ]; then
        chmod 666 /dev/dri/renderD128
    fi

    log "Permissions configurées"
}

# Installation de unclutter pour cacher le curseur
install_cursor_hide() {
    log "Installation d'unclutter pour cacher le curseur..."
    apt-get install -y unclutter || warning "unclutter non disponible, curseur visible"
}

# Test de l'installation
test_installation() {
    log "Test de l'installation..."

    # Vérifier que les services nécessaires sont actifs
    if systemctl is-enabled lightdm >/dev/null 2>&1; then
        log "✓ LightDM est activé"
    else
        warning "✗ LightDM n'est pas activé"
    fi

    if systemctl get-default | grep -q "graphical.target"; then
        log "✓ Mode graphique configuré"
    else
        warning "✗ Mode graphique non configuré"
    fi

    if command -v vlc >/dev/null 2>&1; then
        log "✓ VLC disponible"
    else
        warning "✗ VLC non disponible"
    fi

    log "Test d'installation terminé"
}

# Menu principal
main() {
    log "Début de l'installation minimale..."

    install_minimal_packages
    configure_autologin
    configure_minimal_desktop
    configure_vlc_optimal
    setup_permissions
    install_cursor_hide
    test_installation

    log "=== Installation minimale terminée ==="
    log "REDÉMARRAGE NÉCESSAIRE pour activer l'interface graphique"
    echo ""
    echo -e "${GREEN}Installation terminée avec succès !${NC}"
    echo -e "${YELLOW}Pour activer l'affichage automatique :${NC}"
    echo "1. sudo reboot"
    echo "2. L'interface graphique démarrera automatiquement"
    echo "3. VLC lira automatiquement Big Buck Bunny en boucle"
    echo ""
    echo -e "${YELLOW}En cas de problème :${NC}"
    echo "- Logs dans : $LOG_FILE"
    echo "- Configuration VLC : /home/$PISIGNAGE_USER/.config/vlc/"
    echo "- Configuration Openbox : /home/$PISIGNAGE_USER/.config/openbox/"
}

# Exécution
main "$@"