#!/bin/bash
################################################################################
#                    RASPBERRY PI OS BOOKWORM - FIX GRAPHICAL WAYLAND
#                           Script complet pour environnement graphique
#                         Compatible Raspberry Pi OS Bookworm (Debian 12)
################################################################################
#
# Description : Script pour configurer complètement l'environnement graphique
#               Wayland sur Raspberry Pi OS Bookworm avec labwc
# Version     : 1.0.0
# Date        : 2025-09-25
# Auteur      : PiSignage Team
#
# PROBLÈME RÉSOLU:
#   - Raspberry Pi OS Bookworm en mode console au lieu du mode graphique
#   - Pas de labwc/wayfire installé pour Wayland
#   - Variables d'environnement manquantes pour Wayland (XDG_RUNTIME_DIR)
#   - Accès aux devices DRM/GBM et V4L2 requis pour les players
#
# SOLUTION ChatGPT pour Bookworm:
#   "Sous Bookworm Desktop, tu es en Wayland (labwc/wayfire). Pour accéder à
#   /dev/dri (DRM/GBM) et aux devices V4L2, le player doit tourner dans la
#   session utilisateur avec XDG_RUNTIME_DIR valide"
#
################################################################################

set -e  # Arrêt en cas d'erreur

# Vérification que le script est exécuté avec bash
if [ -z "$BASH_VERSION" ]; then
    echo "ERREUR: Ce script doit être exécuté avec bash, pas sh ou dash"
    echo "Usage: bash $0 ou sudo bash $0"
    exit 1
fi

# Configuration
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/var/log/fix-graphical-wayland.log"
BACKUP_DIR="/opt/wayland-backup-$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_DIR

# Couleurs pour output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log() {
    local message="$1"
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $message" | tee -a "$LOG_FILE"
}

error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE"
}

info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
}

success() {
    local message="$1"
    echo -e "${GREEN}✓${NC} $message" | tee -a "$LOG_FILE"
}

################################################################################
# PHASE 1: PRÉ-VÉRIFICATIONS
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Ce script doit être exécuté en tant que root (sudo)"
    fi
}

detect_system() {
    log "Détection du système..."

    # OS Detection
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        CODENAME=$VERSION_CODENAME
    else
        error "Impossible de détecter l'OS"
    fi

    # Raspberry Pi Detection
    if grep -q "Raspberry Pi" /proc/cpuinfo; then
        PI_MODEL=$(grep "Model" /proc/cpuinfo | cut -d ':' -f2 | xargs)
        log "Raspberry Pi détecté: $PI_MODEL"
    else
        info "Système générique détecté - pas de Raspberry Pi"
    fi

    log "OS: $OS $VER ($CODENAME)"
    log "Architecture: $(uname -m)"

    # Vérification Bookworm
    if [[ "$CODENAME" != "bookworm" ]]; then
        warning "OS non-Bookworm détecté ($CODENAME). Ce script est optimisé pour Bookworm."
    fi
}

check_current_state() {
    log "Vérification de l'état actuel du système..."

    # Target actuel
    current_target=$(systemctl get-default)
    log "Target actuel: $current_target"

    # Session en cours
    if [ -n "$XDG_SESSION_TYPE" ]; then
        log "Session type: $XDG_SESSION_TYPE"
    fi

    if [ -n "$WAYLAND_DISPLAY" ]; then
        log "Wayland display: $WAYLAND_DISPLAY"
    fi

    if [ -n "$DISPLAY" ]; then
        log "X11 display: $DISPLAY"
    fi

    # Vérification des packages Wayland installés
    info "Vérification des packages Wayland..."
    local wayland_count
    wayland_count=$(dpkg -l | grep -c -i wayland)
    log "Packages Wayland installés: $wayland_count"
}

backup_configs() {
    log "Sauvegarde des configurations existantes..."

    mkdir -p "$BACKUP_DIR"

    # Backup des configurations importantes
    [ -f /etc/lightdm/lightdm.conf ] && cp /etc/lightdm/lightdm.conf "$BACKUP_DIR/"
    if [ -d /home/pi/.config ]; then
        cp -r /home/pi/.config "$BACKUP_DIR/pi-config" 2>/dev/null || true
    fi
    [ -f /boot/config.txt ] && cp /boot/config.txt "$BACKUP_DIR/"

    success "Backup créé dans $BACKUP_DIR"
}

################################################################################
# PHASE 2: INSTALLATION DES PACKAGES GRAPHIQUES BOOKWORM
################################################################################

update_system() {
    log "Mise à jour du système..."
    apt-get update || error "Échec de la mise à jour APT"
    success "Système mis à jour"
}

install_wayland_packages() {
    log "Installation de l'environnement Wayland complet pour Bookworm..."

    local wayland_packages=(
        # Core Wayland
        wayland-protocols
        libwayland-client0
        libwayland-cursor0
        libwayland-egl1
        libwayland-server0

        # Weston (compositeur de référence)
        weston
        weston-common

        # labwc (compositeur recommandé pour Bookworm)
        labwc

        # wayfire (alternative)
        wayfire
        wayfire-plugins-extra

        # Utilitaires Wayland
        wayland-utils
        wlr-randr

        # Support seatd pour l'accès aux devices
        seatd
        libseat1

        # Support XWayland pour compatibilité X11
        xwayland

        # Outils de capture
        grim
        slurp

        # Terminal pour Wayland
        foot
        alacritty
    )

    # Installation des packages Wayland
    apt-get install -y "${wayland_packages[@]}" || error "Échec installation packages Wayland"

    success "Packages Wayland installés"
}

install_xorg_packages() {
    log "Installation des packages X11 (pour compatibilité et fallback)..."

    local xorg_packages=(
        # X11 core
        xorg
        xserver-xorg
        xserver-xorg-core
        xserver-xorg-input-all
        xserver-xorg-video-all

        # Window managers légers
        openbox
        fluxbox

        # Utilitaires X11
        x11-xserver-utils
        x11-utils
        xinit
        xdotool

        # Fonts
        fonts-dejavu-core
        fonts-liberation
    )

    apt-get install -y "${xorg_packages[@]}" || warning "Certains packages X11 n'ont pas pu être installés"
    success "Packages X11 installés"
}

install_display_manager() {
    log "Configuration du display manager (LightDM)..."

    local dm_packages=(
        lightdm
        lightdm-gtk-greeter
        lightdm-gtk-greeter-settings
    )

    apt-get install -y "${dm_packages[@]}" || error "Échec installation LightDM"

    # Activer LightDM comme display manager par défaut
    systemctl enable lightdm

    success "LightDM installé et activé"
}

install_media_packages() {
    log "Installation des packages média optimisés pour Wayland..."

    local media_packages=(
        # Lecteurs vidéo avec support Wayland
        mpv
        vlc

        # Support matériel
        mesa-va-drivers
        mesa-vdpau-drivers
        libva-wayland2
        libva-drm2

        # FFmpeg avec support Wayland
        ffmpeg
        libavcodec-extra

        # Outils de capture pour Wayland
        wf-recorder
    )

    # Packages spécifiques Raspberry Pi
    if [[ -n "$PI_MODEL" ]]; then
        media_packages+=(
            libraspberrypi-bin
            libraspberrypi-dev
            rpi-update
        )
    fi

    apt-get install -y "${media_packages[@]}" || warning "Certains packages média n'ont pas pu être installés"
    success "Packages média installés"
}

################################################################################
# PHASE 3: CONFIGURATION SYSTÈME GRAPHIQUE
################################################################################

configure_systemd_target() {
    log "Configuration du système en mode graphique..."

    # Définir le target par défaut comme graphical
    systemctl set-default graphical.target

    # S'assurer que les services graphiques sont activés
    systemctl enable lightdm

    success "Système configuré en mode graphical.target"
}

setup_user_groups() {
    log "Configuration des groupes utilisateur pour Wayland..."

    # Groupes nécessaires pour l'accès aux devices
    local groups=(
        video
        audio
        render
        input
        seat
        gpio
        spi
        i2c
    )

    # Ajouter www-data aux groupes
    for group in "${groups[@]}"; do
        if getent group "$group" &>/dev/null; then
            usermod -a -G "$group" www-data 2>/dev/null || true
        fi
    done

    # Ajouter pi aux groupes si l'utilisateur existe
    if id -u pi &>/dev/null; then
        for group in "${groups[@]}"; do
            if getent group "$group" &>/dev/null; then
                usermod -a -G "$group" pi 2>/dev/null || true
            fi
        done
        success "Utilisateur 'pi' ajouté aux groupes nécessaires"
    fi

    success "Groupes utilisateur configurés"
}

configure_autologin() {
    log "Configuration de l'autologin pour l'utilisateur pi..."

    # Vérifier que l'utilisateur pi existe
    if ! id -u pi &>/dev/null; then
        warning "Utilisateur 'pi' non trouvé - création de l'utilisateur..."
        useradd -m -s /bin/bash pi
        echo "pi:raspberry" | chpasswd
        usermod -a -G sudo,video,audio,render,input,seat pi
        success "Utilisateur 'pi' créé avec mot de passe 'raspberry'"
    fi

    # Configuration LightDM pour autologin
    cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
user-session=labwc
greeter-session=lightdm-gtk-greeter
session-wrapper=/etc/X11/Xsession
greeter-setup-script=
greeter-hide-users=false
allow-guest=false
EOF

    # Configuration du greeter
    cat > /etc/lightdm/lightdm-gtk-greeter.conf << 'EOF'
[greeter]
theme-name=Adwaita
icon-theme-name=Adwaita
font-name=DejaVu Sans 11
background=#2e2e2e
active-monitor=0
EOF

    success "Autologin configuré pour l'utilisateur pi"
}

################################################################################
# PHASE 4: CONFIGURATION WAYLAND AVEC LABWC
################################################################################

configure_labwc() {
    log "Configuration de labwc (compositeur Wayland pour Bookworm)..."

    # Créer la configuration labwc pour l'utilisateur pi
    local labwc_dir="/home/pi/.config/labwc"
    mkdir -p "$labwc_dir"

    # Configuration rc.xml pour labwc
    cat > "$labwc_dir/rc.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<labwc_config>
  <core>
    <decoration>server</decoration>
    <focus>followMouse</focus>
    <focusNew>yes</focusNew>
  </core>

  <placement>
    <policy>center</policy>
  </placement>

  <theme>
    <name>Clearlooks-3.4</name>
    <cornerRadius>8</cornerRadius>
    <font place="ActiveWindow">
      <name>DejaVu Sans</name>
      <size>10</size>
      <weight>Normal</weight>
      <slant>Normal</slant>
    </font>
  </theme>

  <keyboard>
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>
    <keybind key="W-Return">
      <action name="Execute">
        <command>foot</command>
      </action>
    </keybind>
    <keybind key="A-Tab">
      <action name="NextWindow"/>
    </keybind>
  </keyboard>

  <mouse>
    <mousebind button="A-Left" action="Drag">
      <action name="Move"/>
    </mousebind>
    <mousebind button="A-Right" action="Drag">
      <action name="Resize"/>
    </mousebind>
  </mouse>

  <window>
    <width>1024</width>
    <height>768</height>
  </window>
</labwc_config>
EOF

    # Menu pour labwc
    cat > "$labwc_dir/menu.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu>
  <menu id="root-menu" label="">
    <item label="Terminal">
      <action name="Execute">
        <execute>foot</execute>
      </action>
    </item>
    <item label="VLC Media Player">
      <action name="Execute">
        <execute>vlc</execute>
      </action>
    </item>
    <item label="MPV Player">
      <action name="Execute">
        <execute>mpv</execute>
      </action>
    </item>
    <separator/>
    <item label="Exit">
      <action name="Exit"/>
    </item>
  </menu>
</openbox_menu>
EOF

    # Créer session labwc
    cat > /usr/share/wayland-sessions/labwc.desktop << 'EOF'
[Desktop Entry]
Name=labwc
Comment=Wayland compositor inspired by openbox
Exec=labwc
Type=Application
Keywords=wayland;wm;
EOF

    # Corriger les permissions
    chown -R pi:pi "$labwc_dir"

    success "labwc configuré avec session Wayland"
}

configure_wayland_environment() {
    log "Configuration des variables d'environnement Wayland..."

    # Variables d'environnement pour l'utilisateur pi
    cat > /home/pi/.profile << 'EOF'
# Wayland environment variables for Raspberry Pi OS Bookworm
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_SESSION_TYPE="wayland"
export XDG_SESSION_DESKTOP="labwc"
export XDG_CURRENT_DESKTOP="labwc"

# Wayland display
export WAYLAND_DISPLAY="wayland-0"

# Pour compatibilité Qt et GTK
export QT_QPA_PLATFORM="wayland;xcb"
export GDK_BACKEND="wayland,x11"
export SDL_VIDEODRIVER="wayland"

# Mozilla/Firefox
export MOZ_ENABLE_WAYLAND=1

# Variables pour accès hardware
export LIBSEAT_BACKEND="seatd"

# Path
export PATH="$HOME/.local/bin:$PATH"

# Démarrage automatique de la session si on est sur tty1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    exec labwc
fi
EOF

    # Variables système pour tous les utilisateurs
    cat > /etc/environment << 'EOF'
# Wayland environment variables system-wide
XDG_SESSION_TYPE="wayland"
QT_QPA_PLATFORM="wayland;xcb"
GDK_BACKEND="wayland,x11"
SDL_VIDEODRIVER="wayland"
MOZ_ENABLE_WAYLAND=1
LIBSEAT_BACKEND="seatd"
EOF

    # Script de démarrage Wayland
    cat > /home/pi/.xsessionrc << 'EOF'
#!/bin/bash
# Wayland session startup script

# Créer XDG_RUNTIME_DIR si nécessaire
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

# Démarrer seatd si pas déjà en cours
if ! pgrep -x seatd > /dev/null; then
    sudo seatd &
fi

# Variables Wayland
export WAYLAND_DISPLAY="wayland-0"
export XDG_SESSION_TYPE="wayland"
export XDG_SESSION_DESKTOP="labwc"
export XDG_CURRENT_DESKTOP="labwc"
EOF

    chmod +x /home/pi/.xsessionrc
    chown pi:pi /home/pi/.profile /home/pi/.xsessionrc

    success "Variables d'environnement Wayland configurées"
}

################################################################################
# PHASE 5: CONFIGURATION SEATD POUR ACCÈS HARDWARE
################################################################################

configure_seatd() {
    log "Configuration de seatd pour l'accès aux devices hardware..."

    # Activer et démarrer seatd
    systemctl enable seatd
    systemctl start seatd

    # Configuration seatd
    cat > /etc/seatd.conf << 'EOF'
# Configuration seatd pour accès hardware Wayland
[seat0]
vtnr = 1
user = pi
EOF

    # Créer le groupe seat si nécessaire
    if ! getent group seat &>/dev/null; then
        groupadd seat
    fi

    # Ajouter pi au groupe seat
    usermod -a -G seat pi

    # Règles udev pour accès aux devices
    cat > /etc/udev/rules.d/99-seat.rules << 'EOF'
# Règles udev pour accès devices avec seatd
SUBSYSTEM=="drm", KERNEL=="card[0-9]*", TAG+="seat", TAG+="master-of-seat"
SUBSYSTEM=="input", TAG+="seat"
SUBSYSTEM=="graphics", TAG+="seat"
SUBSYSTEM=="sound", TAG+="seat"
EOF

    udevadm control --reload-rules
    udevadm trigger

    success "seatd configuré pour l'accès hardware"
}

################################################################################
# PHASE 6: CONFIGURATION VLC AUTOSTART AVEC BIG BUCK BUNNY
################################################################################

setup_big_buck_bunny() {
    log "Téléchargement de Big Buck Bunny..."

    local media_dir="/opt/pisignage/media"
    local video_file="$media_dir/big-buck-bunny.mp4"

    mkdir -p "$media_dir"

    # Télécharger Big Buck Bunny si pas déjà présent
    if [ ! -f "$video_file" ]; then
        info "Téléchargement de Big Buck Bunny (400MB)..."
        wget -O "$video_file" "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" || {
            warning "Échec téléchargement Big Buck Bunny - utilisation d'une alternative"
            # Alternative plus petite
            wget -O "$video_file" "http://techslides.com/demos/sample-videos/small.mp4" || {
                warning "Échec téléchargement vidéo de test"
                return 1
            }
        }
    fi

    chmod 644 "$video_file"
    success "Big Buck Bunny disponible dans $video_file"
}

configure_vlc_autostart() {
    log "Configuration du démarrage automatique de VLC..."

    local video_file="/opt/pisignage/media/big-buck-bunny.mp4"

    # Script de démarrage VLC optimisé pour Wayland
    cat > /home/pi/.local/bin/start-vlc-loop.sh << 'EOF'
#!/bin/bash
# Script de démarrage VLC en boucle pour Wayland

# Variables d'environnement Wayland
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WAYLAND_DISPLAY="wayland-0"
export XDG_SESSION_TYPE="wayland"

# Attendre que Wayland soit prêt
sleep 5

while true; do
    if [ -f "/opt/pisignage/media/big-buck-bunny.mp4" ]; then
        # VLC en mode Wayland avec options optimisées
        vlc \
            --intf dummy \
            --fullscreen \
            --no-video-title-show \
            --no-osd \
            --loop \
            --quiet \
            --vout=wayland \
            "/opt/pisignage/media/big-buck-bunny.mp4" \
            2>/dev/null
    else
        # Fallback avec vidéo de test
        vlc \
            --intf dummy \
            --fullscreen \
            --no-video-title-show \
            --no-osd \
            --loop \
            --quiet \
            --vout=wayland \
            "http://techslides.com/demos/sample-videos/small.mp4" \
            2>/dev/null
    fi

    # Si VLC se ferme, attendre 5 secondes et relancer
    sleep 5
done
EOF

    mkdir -p /home/pi/.local/bin
    chmod +x /home/pi/.local/bin/start-vlc-loop.sh
    chown pi:pi /home/pi/.local/bin/start-vlc-loop.sh

    # Autostart VLC via labwc
    mkdir -p /home/pi/.config/autostart
    cat > /home/pi/.config/autostart/vlc-player.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VLC Player Autostart
Comment=Start VLC player automatically
Exec=/home/pi/.local/bin/start-vlc-loop.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=10
EOF

    chown -R pi:pi /home/pi/.config/autostart

    success "VLC configuré pour démarrage automatique avec Big Buck Bunny"
}

################################################################################
# PHASE 7: SERVICES ET FINALISATION
################################################################################

create_wayland_service() {
    log "Création du service de monitoring Wayland..."

    # Service de monitoring pour Wayland
    cat > /etc/systemd/system/wayland-monitor.service << 'EOF'
[Unit]
Description=Wayland Environment Monitor
After=graphical-session.target

[Service]
Type=simple
User=pi
ExecStart=/opt/pisignage/scripts/monitor-wayland.sh
Restart=always
RestartSec=30
Environment=XDG_RUNTIME_DIR=/run/user/1000

[Install]
WantedBy=graphical-session.target
EOF

    # Script de monitoring Wayland
    cat > /opt/pisignage/scripts/monitor-wayland.sh << 'EOF'
#!/bin/bash
# Monitor Wayland environment and restart services if needed

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

while true; do
    # Vérifier si Wayland est actif
    if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
        echo "[$(date)] WARNING: No display server detected" >> /var/log/wayland-monitor.log

        # Tentative de redémarrage de labwc si nécessaire
        if ! pgrep -u pi labwc > /dev/null; then
            echo "[$(date)] Restarting labwc" >> /var/log/wayland-monitor.log
            sudo -u pi labwc &
        fi
    fi

    # Vérifier l'accès aux devices DRM
    if [ ! -r /dev/dri/card0 ]; then
        echo "[$(date)] WARNING: No access to /dev/dri/card0" >> /var/log/wayland-monitor.log
    fi

    # Log de l'état
    echo "[$(date)] Wayland monitor check completed" >> /var/log/wayland-monitor.log

    sleep 60
done
EOF

    chmod +x /opt/pisignage/scripts/monitor-wayland.sh
    systemctl enable wayland-monitor

    success "Service de monitoring Wayland créé"
}

configure_boot_config() {
    log "Configuration finale du boot pour Raspberry Pi..."

    if [[ -n "$PI_MODEL" ]] && [ -f /boot/config.txt ]; then
        # Backup
        cp /boot/config.txt /boot/config.txt.backup-wayland

        # Configuration pour Wayland/DRM
        if ! grep -q "^dtoverlay=vc4-kms-v3d" /boot/config.txt; then
            {
                echo ""
                echo "# Configuration pour Wayland/DRM"
                echo "dtoverlay=vc4-kms-v3d"
                echo "gpu_mem=256"
                echo "hdmi_force_hotplug=1"
            } >> /boot/config.txt
        fi

        success "Configuration boot Raspberry Pi mise à jour"
    fi
}

################################################################################
# PHASE 8: TESTS ET VALIDATION
################################################################################

test_wayland_installation() {
    log "Tests de validation de l'installation Wayland..."

    local tests_passed=0
    local tests_failed=0

    # Test 1: Target graphical
    info "Test du target système..."
    if systemctl get-default | grep -q "graphical.target"; then
        success "Système en mode graphical.target"
        ((tests_passed++))
    else
        warning "Système pas en mode graphical"
        ((tests_failed++))
    fi

    # Test 2: Packages Wayland
    info "Test des packages Wayland..."
    if dpkg -l | grep -q labwc; then
        success "labwc installé"
        ((tests_passed++))
    else
        warning "labwc non installé"
        ((tests_failed++))
    fi

    # Test 3: LightDM
    info "Test de LightDM..."
    if systemctl is-enabled --quiet lightdm; then
        success "LightDM activé"
        ((tests_passed++))
    else
        warning "LightDM non activé"
        ((tests_failed++))
    fi

    # Test 4: Utilisateur pi
    info "Test de l'utilisateur pi..."
    if id -u pi &>/dev/null; then
        success "Utilisateur pi existe"
        ((tests_passed++))
    else
        warning "Utilisateur pi manquant"
        ((tests_failed++))
    fi

    # Test 5: Groupes
    info "Test des groupes..."
    if groups pi | grep -q video; then
        success "Utilisateur pi dans le groupe video"
        ((tests_passed++))
    else
        warning "Problème avec les groupes"
        ((tests_failed++))
    fi

    # Test 6: Seatd
    info "Test de seatd..."
    if systemctl is-enabled --quiet seatd; then
        success "seatd activé"
        ((tests_passed++))
    else
        warning "seatd non activé"
        ((tests_failed++))
    fi

    # Test 7: Vidéo de test
    info "Test de la vidéo Big Buck Bunny..."
    if [ -f "/opt/pisignage/media/big-buck-bunny.mp4" ]; then
        success "Vidéo de test présente"
        ((tests_passed++))
    else
        warning "Vidéo de test manquante"
        ((tests_failed++))
    fi

    # Résumé
    echo ""
    log "========================================="
    log "RÉSULTATS DES TESTS WAYLAND:"
    log "  ✅ Réussis: $tests_passed"
    log "  ❌ Échoués: $tests_failed"
    log "========================================="

    if [ $tests_failed -eq 0 ]; then
        success "TOUS LES TESTS PASSÉS AVEC SUCCÈS!"
        return 0
    else
        warning "Certains tests ont échoué. Vérification manuelle recommandée."
        return 1
    fi
}

################################################################################
# PHASE 9: RAPPORT FINAL
################################################################################

display_final_report() {
    clear
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     🎉 CONFIGURATION WAYLAND BOOKWORM TERMINÉE! 🎉          ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📋 CONFIGURATION APPLIQUÉE:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  🎯 Target: graphical.target"
    echo "  🖥️  Compositeur: labwc (Wayland)"
    echo "  🔓 Autologin: utilisateur 'pi'"
    echo "  🎬 Lecteur: VLC avec Big Buck Bunny"
    echo "  🔧 Hardware: accès DRM/GBM via seatd"
    echo ""
    echo "🔧 SERVICES INSTALLÉS:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  ✅ LightDM (Display Manager)"
    echo "  ✅ labwc (Compositeur Wayland)"
    echo "  ✅ seatd (Accès hardware)"
    echo "  ✅ VLC (Lecture vidéo automatique)"
    echo "  ✅ Wayland Monitor Service"
    echo ""
    echo "🌊 VARIABLES WAYLAND CONFIGURÉES:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  • XDG_RUNTIME_DIR=/run/user/1000"
    echo "  • WAYLAND_DISPLAY=wayland-0"
    echo "  • XDG_SESSION_TYPE=wayland"
    echo "  • XDG_SESSION_DESKTOP=labwc"
    echo "  • LIBSEAT_BACKEND=seatd"
    echo ""
    echo "🎮 COMMANDES UTILES:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  Redémarrer:        sudo reboot"
    echo "  Status Wayland:    systemctl status lightdm"
    echo "  Status seatd:      systemctl status seatd"
    echo "  Logs Wayland:      journalctl -u lightdm -f"
    echo "  Test devices:      ls -la /dev/dri/"
    echo ""
    echo "🚀 PROCHAINES ÉTAPES:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  1. 🔄 REDÉMARRER LE SYSTÈME (obligatoire)"
    echo "  2. ✅ Vérifier l'autologin de l'utilisateur 'pi'"
    echo "  3. 🎬 VLC devrait démarrer automatiquement"
    echo "  4. 🖥️  Interface en Wayland avec labwc"
    echo ""
    echo "⚠️  IMPORTANT:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  Le REDÉMARRAGE est OBLIGATOIRE pour activer:"
    echo "  • Le mode graphical.target"
    echo "  • L'autologin utilisateur 'pi'"
    echo "  • L'environnement Wayland complet"
    echo "  • L'accès aux devices hardware (DRM/GBM)"
    echo ""

    if [ -d "$BACKUP_DIR" ]; then
        echo "💾 BACKUP:"
        echo "════════════════════════════════════════════════════════════════"
        echo "  Configurations sauvegardées dans:"
        echo "  $BACKUP_DIR"
        echo ""
    fi

    echo "✅ Configuration terminée! Redémarrez maintenant."
    echo "════════════════════════════════════════════════════════════════"
    echo ""
}

################################################################################
# FONCTION PRINCIPALE
################################################################################

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║        RASPBERRY PI OS BOOKWORM - FIX GRAPHICAL WAYLAND     ║"
    echo "║                     Script de correction v1.0.0             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # Créer le fichier de log
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    log "Début de la configuration Wayland Bookworm $SCRIPT_VERSION"

    # PHASE 1: Pré-vérifications
    check_root
    detect_system
    check_current_state
    backup_configs

    # PHASE 2: Installation packages
    update_system
    install_wayland_packages
    install_xorg_packages
    install_display_manager
    install_media_packages

    # PHASE 3: Configuration système
    configure_systemd_target
    setup_user_groups
    configure_autologin

    # PHASE 4: Configuration Wayland
    configure_labwc
    configure_wayland_environment

    # PHASE 5: Configuration hardware
    configure_seatd

    # PHASE 6: Configuration VLC
    setup_big_buck_bunny
    configure_vlc_autostart

    # PHASE 7: Services
    create_wayland_service
    configure_boot_config

    # PHASE 8: Tests
    test_wayland_installation

    # PHASE 9: Rapport final
    display_final_report

    log "Configuration Wayland terminée!"
}

# Trap pour gérer les interruptions
trap 'error "Script interrompu!"' INT TERM

# Vérifier les arguments
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "Ce script configure complètement l'environnement graphique Wayland"
    echo "sur Raspberry Pi OS Bookworm avec labwc et VLC en autostart."
    echo ""
    echo "Options:"
    echo "  --help, -h    Afficher cette aide"
    echo ""
    echo "Le script doit être exécuté avec sudo."
    exit 0
fi

# Lancer la configuration
main "$@"

exit 0