#!/usr/bin/env bash

# =============================================================================
# Module 03 - Installation et Configuration VLC
# Version: 2.1.0
# Description: Installation VLC avec configuration pour digital signage
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly VLC_SCRIPT="/opt/scripts/vlc-signage.sh"
readonly VLC_SERVICE="/etc/systemd/system/vlc-signage.service"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les fonctions de sécurité
if [[ -f "$SCRIPT_DIR/00-security-utils.sh" ]]; then
    source "$SCRIPT_DIR/00-security-utils.sh"
    # Initialiser et nettoyer dpkg si nécessaire
    init_dpkg_cleanup
else
    echo "ERREUR: Fichier de sécurité manquant: 00-security-utils.sh" >&2
    exit 1
fi

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# =============================================================================
# LOGGING
# =============================================================================

log_info() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [INFO] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${GREEN}[VLC]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[VLC]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[VLC]${NC} $*" >&2
}

# =============================================================================
# CHARGEMENT DE LA CONFIGURATION
# =============================================================================

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "Configuration chargée"
    else
        log_error "Fichier de configuration introuvable"
        return 1
    fi
    
    # Charger aussi l'environnement graphique détecté
    if [[ -f /tmp/gui-environment.conf ]]; then
        source /tmp/gui-environment.conf
        log_info "Environnement graphique: $GUI_TYPE ($GUI_SESSION)"
    fi
}

# =============================================================================
# INSTALLATION DE VLC
# =============================================================================

install_vlc() {
    log_info "Installation de VLC Media Player..."
    
    # Paquets VLC et codecs
    local vlc_packages=(
        "vlc"
        "vlc-plugin-base"
        "vlc-plugin-video-output"
        "vlc-plugin-video-splitter"
        "vlc-plugin-visualization"
        "vlc-l10n"
        "libvlc-dev"
        # ffmpeg déjà installé dans 01-system-config.sh
        "gstreamer1.0-tools"
        "gstreamer1.0-plugins-good"
        "gstreamer1.0-plugins-bad"
        "gstreamer1.0-plugins-ugly"
        "gstreamer1.0-libav"
    )
    
    # Mise à jour de la liste des paquets
    apt-get update
    
    # Installation
    if apt-get install -y "${vlc_packages[@]}"; then
        log_info "VLC installé avec succès"
    else
        log_error "Échec de l'installation de VLC"
        return 1
    fi
    
    # Vérification de l'installation
    if command -v vlc >/dev/null 2>&1; then
        local vlc_version
        vlc_version=$(vlc --version 2>/dev/null | head -n1 || echo "Version inconnue")
        log_info "VLC disponible: $vlc_version"
    else
        log_error "VLC non disponible après installation"
        return 1
    fi
}

# =============================================================================
# CONFIGURATION VLC POUR L'UTILISATEUR SIGNAGE
# =============================================================================

configure_vlc_user() {
    log_info "Configuration de VLC pour l'utilisateur signage..."
    
    local signage_home="/home/signage"
    local vlc_config_dir="$signage_home/.config/vlc"
    
    # Création du répertoire de configuration VLC
    mkdir -p "$vlc_config_dir"
    
    # Configuration VLC pour mode kiosque
    cat > "$vlc_config_dir/vlcrc" << 'EOF'
[main]
# Interface
intf=dummy
extraintf=

# Video
vout=auto
fullscreen=1
video-wallpaper=0
disable-screensaver=1

# Audio 
aout=auto
volume=256
audio=1

# Playlist
random=1
loop=1
repeat=0
play-and-exit=0

# Performance
file-caching=300
network-caching=300
live-caching=300

# Logging (minimal)
verbose=0
quiet=1

# Disable updates and privacy
qt-updates-notif=0
qt-privacy-ask=0
EOF
    
    # Permissions pour l'utilisateur signage
    chown -R signage:signage "$vlc_config_dir"
    
    log_info "Configuration VLC utilisateur créée"
}

# =============================================================================
# CRÉATION DU SCRIPT VLC SIGNAGE
# =============================================================================

create_vlc_script() {
    log_info "Création du script VLC pour digital signage..."
    
    cat > "$VLC_SCRIPT" << 'EOF'
#!/bin/bash

# =============================================================================
# Script VLC Digital Signage
# =============================================================================

# Configuration
VIDEO_DIR="/opt/videos"
LOG_FILE="/var/log/pi-signage/vlc.log"
DISPLAY="${DISPLAY:-:0}"

# Charger l'utilisateur détecté si disponible
if [[ -f /tmp/autologin-detected.conf ]]; then
    source /tmp/autologin-detected.conf
fi

# Fonction de logging
log_vlc() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Fonction de nettoyage à la fermeture
cleanup() {
    log_vlc "Arrêt du processus VLC"
    killall vlc 2>/dev/null || true
    exit 0
}

# Gestionnaire de signaux
trap cleanup SIGTERM SIGINT

# Initialisation
log_vlc "=== Démarrage VLC Digital Signage ==="
export DISPLAY="${DISPLAY:-:0}"
export PULSE_RUNTIME_PATH="/run/user/$(id -u)/pulse"

# Vérifier la présence du répertoire vidéos
if [[ ! -d "$VIDEO_DIR" ]]; then
    log_vlc "ERREUR: Répertoire vidéos introuvable: $VIDEO_DIR"
    exit 1
fi

# Attendre que l'affichage soit prêt
sleep 10
log_vlc "Affichage prêt, démarrage de VLC"

# Fonction de lecture des vidéos
play_videos() {
    local video_files=()
    local supported_formats="*.mp4 *.avi *.mkv *.mov *.wmv *.flv *.webm *.m4v"
    
    # Recherche des fichiers vidéo
    for format in $supported_formats; do
        while IFS= read -r -d '' file; do
            video_files+=("$file")
        done < <(find "$VIDEO_DIR" -name "$format" -type f -print0 2>/dev/null)
    done
    
    # Vérifier s'il y a des vidéos
    if [[ ${#video_files[@]} -eq 0 ]]; then
        log_vlc "Aucune vidéo trouvée dans $VIDEO_DIR"
        
        # Afficher un message d'attente
        show_waiting_message
        return
    fi
    
    log_vlc "Trouvé ${#video_files[@]} vidéo(s)"
    
    # Création de la playlist
    local playlist_file="/tmp/signage-playlist.m3u"
    printf '%s\n' "${video_files[@]}" > "$playlist_file"
    
    # Démarrage de VLC avec la playlist
    log_vlc "Démarrage de VLC avec playlist"
    
    # Adapter la sortie vidéo selon l'environnement
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        VLC_VIDEO_OUTPUT="--vout=gles2"
    else
        VLC_VIDEO_OUTPUT="--vout=gl"
    fi
    
    vlc \
        --intf dummy \
        --extraintf \
        --fullscreen \
        --no-video-title-show \
        --no-osd \
        --loop \
        --random \
        --no-qt-privacy-ask \
        --no-qt-updates-notif \
        --quiet \
        --no-interact \
        --no-stats \
        --no-disable-screensaver \
        --aout=alsa \
        $VLC_VIDEO_OUTPUT \
        "$playlist_file" \
        2>>"$LOG_FILE" &
    
    local vlc_pid=$!
    log_vlc "VLC démarré avec PID: $vlc_pid"
    
    # Surveillance de VLC
    while kill -0 $vlc_pid 2>/dev/null; do
        sleep 30
        
        # Vérifier s'il y a de nouvelles vidéos
        local new_count
        new_count=$(find "$VIDEO_DIR" -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" | wc -l)
        
        if [[ $new_count -ne ${#video_files[@]} ]]; then
            log_vlc "Nouvelles vidéos détectées, redémarrage de VLC"
            kill $vlc_pid 2>/dev/null || true
            sleep 5
            play_videos
            return
        fi
    done
    
    log_vlc "VLC s'est arrêté, redémarrage dans 10 secondes"
    sleep 10
    play_videos
}

# Fonction d'affichage du message d'attente
show_waiting_message() {
    log_vlc "Affichage du message d'attente"
    
    # Créer une image de message d'attente avec ImageMagick ou utiliser VLC
    vlc \
        --intf dummy \
        --extraintf \
        --fullscreen \
        --no-video-title-show \
        --loop \
        --quiet \
        --color 0x000000 \
        --video-filter logo \
        --logo-file /opt/scripts/waiting-message.png \
        --logo-position 5 \
        --logo-opacity 255 \
        fake:// \
        2>>"$LOG_FILE" &
    
    local waiting_pid=$!
    
    # Vérifier périodiquement s'il y a des vidéos
    while true; do
        sleep 30
        if find "$VIDEO_DIR" -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" | grep -q .; then
            log_vlc "Vidéos détectées, arrêt du message d'attente"
            kill $waiting_pid 2>/dev/null || true
            sleep 2
            play_videos
            return
        fi
    done
}

# Démarrage principal
main() {
    # Créer le répertoire de logs
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Attendre que le système soit complètement prêt
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        # Environnement Wayland
        log_vlc "Environnement Wayland détecté"
        sleep 10  # Attendre que Wayland soit prêt
    else
        # Environnement X11
        while ! xset q >/dev/null 2>&1; do
            log_vlc "Attente de l'initialisation de X11..."
            sleep 5
        done
        
        # Désactiver l'économiseur d'écran (X11 uniquement)
        xset s off
        xset -dpms
        xset s noblank
    fi
    
    # Démarrer la lecture
    play_videos
}

# Point d'entrée
main "$@"
EOF
    
    # Rendre le script exécutable
    chmod +x "$VLC_SCRIPT"
    
    log_info "Script VLC créé: $VLC_SCRIPT"
}

# =============================================================================
# CONFIGURATION DU DÉMARRAGE AUTOMATIQUE SELON L'ENVIRONNEMENT
# =============================================================================

# Fonction pour vérifier l'autologin SANS LE CASSER
configure_signage_autologin() {
    log_info "Vérification de l'autologin existant..."
    
    local autologin_user=""
    local autologin_configured=false
    
    # D'ABORD vérifier si un autologin existe déjà
    
    # Vérifier LightDM
    if [[ -f /etc/lightdm/lightdm.conf ]]; then
        if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf; then
            autologin_user=$(grep "^autologin-user=" /etc/lightdm/lightdm.conf | cut -d'=' -f2)
            log_info "Autologin LightDM déjà configuré pour: $autologin_user"
            autologin_configured=true
        fi
    fi
    
    # Vérifier GDM3
    if [[ -f /etc/gdm3/custom.conf ]] && [[ -z "$autologin_user" ]]; then
        if grep -q "AutomaticLoginEnable=true" /etc/gdm3/custom.conf; then
            autologin_user=$(grep "AutomaticLogin=" /etc/gdm3/custom.conf | cut -d'=' -f2)
            log_info "Autologin GDM3 déjà configuré pour: $autologin_user"
            autologin_configured=true
        fi
    fi
    
    # Vérifier l'autologin console (raspi-config / Imager)
    if [[ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]] && [[ -z "$autologin_user" ]]; then
        if grep -q "autologin" /etc/systemd/system/getty@tty1.service.d/autologin.conf; then
            autologin_user=$(grep -oP 'autologin \K\w+' /etc/systemd/system/getty@tty1.service.d/autologin.conf || echo "")
            if [[ -n "$autologin_user" ]]; then
                log_info "Autologin console déjà configuré pour: $autologin_user"
                autologin_configured=true
            fi
        fi
    fi
    
    # IMPORTANT: Si un autologin existe déjà, on l'utilise !
    if [[ $autologin_configured == true ]] && [[ -n "$autologin_user" ]]; then
        if [[ "$autologin_user" != "signage" ]]; then
            log_warn "ATTENTION: L'autologin est configuré pour '$autologin_user', pas 'signage'"
            log_warn "VLC s'exécutera sous l'utilisateur '$autologin_user'"
            
            # On adapte notre configuration
            # Copier la config VLC pour cet utilisateur
            local user_home=$(getent passwd "$autologin_user" | cut -d: -f6)
            if [[ -n "$user_home" ]] && [[ -d "$user_home" ]]; then
                # Sauvegarder la détection pour les autres scripts
                echo "AUTOLOGIN_USER=$autologin_user" > /tmp/autologin-detected.conf
                echo "AUTOLOGIN_HOME=$user_home" >> /tmp/autologin-detected.conf
                log_info "Adaptation de la configuration pour l'utilisateur $autologin_user"
                
                # Copier les fichiers nécessaires
                mkdir -p "$user_home/.config"
                if [[ -d "/home/signage/.config/vlc" ]]; then
                    cp -r "/home/signage/.config/vlc" "$user_home/.config/"
                    chown -R "$autologin_user:$autologin_user" "$user_home/.config/vlc"
                fi
                
                # Créer une variable globale pour usage dans create_vlc_service
                export DETECTED_USER="$autologin_user"
                export DETECTED_USER_HOME="$user_home"
                
                # Ajouter l'utilisateur détecté aux groupes nécessaires
                local groups=(video audio input render gpio dialout)
                for group in "${groups[@]}"; do
                    if getent group "$group" >/dev/null 2>&1; then
                        if usermod -a -G "$group" "$autologin_user" 2>/dev/null; then
                            log_info "Utilisateur $autologin_user ajouté au groupe $group"
                        fi
                    fi
                done
                
                # Ajout du groupe seat pour Wayland
                if getent group "seat" >/dev/null 2>&1; then
                    if usermod -a -G "seat" "$autologin_user" 2>/dev/null; then
                        log_info "Utilisateur $autologin_user ajouté au groupe seat (Wayland)"
                    fi
                fi
            fi
        else
            export DETECTED_USER="signage"
            export DETECTED_USER_HOME="/home/signage"
        fi
    else
        # Seulement si AUCUN autologin n'existe
        log_warn "Aucun autologin détecté. L'utilisateur devra se connecter manuellement."
        log_info "Pour activer l'autologin, utilisez raspi-config ou l'outil de configuration de votre environnement."
    fi
}

configure_vlc_autostart() {
    log_info "Configuration du démarrage automatique de VLC..."
    
    local has_gui="${HAS_GUI:-false}"
    local gui_type="${GUI_TYPE:-none}"
    local gui_session="${GUI_SESSION:-}"
    
    # Toujours configurer l'autologin pour l'utilisateur signage
    configure_signage_autologin
    
    if [[ $has_gui == true ]]; then
        log_info "Configuration pour environnement graphique existant: $gui_type"
        
        case "$gui_type" in
            "lightdm")
                # Pas besoin de configuration supplémentaire, utilise le service systemd
                log_info "LightDM détecté, VLC démarrera via le service systemd"
                ;;
                
            "raspberrypi-desktop")
                # Configuration pour Raspberry Pi Desktop moderne
                if [[ "$gui_session" == "wayfire" ]] || [[ "$gui_session" == "PIXEL" ]]; then
                    # Créer un fichier .desktop pour autostart
                    mkdir -p /home/signage/.config/autostart
                    cat > /home/signage/.config/autostart/vlc-signage.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=VLC Digital Signage
Exec=/opt/scripts/vlc-signage.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=10
EOF
                    chmod +x /home/signage/.config/autostart/vlc-signage.desktop
                    chown -R signage:signage /home/signage/.config
                    log_info "Configuration autostart pour $gui_session"
                fi
                ;;
                
            "gdm3"|"sddm")
                # Configuration générique via systemd user
                mkdir -p /home/signage/.config/systemd/user
                cat > /home/signage/.config/systemd/user/vlc-signage.service << 'EOF'
[Unit]
Description=VLC Digital Signage User Service
After=graphical-session.target

[Service]
Type=simple
ExecStartPre=/bin/sleep 15
ExecStart=/opt/scripts/vlc-signage.sh
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF
                chown -R signage:signage /home/signage/.config
                su - signage -c "systemctl --user enable vlc-signage.service"
                log_info "Service utilisateur configuré pour $gui_type"
                ;;
                
            *)
                log_warn "Type d'interface non reconnu: $gui_type"
                log_info "Utilisation du service systemd standard"
                ;;
        esac
    else
        log_info "Pas d'interface graphique, le service systemd gèrera le démarrage avec LightDM"
    fi
}

# =============================================================================
# CRÉATION DU MESSAGE D'ATTENTE
# =============================================================================

create_waiting_message() {
    log_info "Création du message d'attente..."
    
    # Installer ImageMagick pour créer l'image d'attente
    if ! command -v convert >/dev/null 2>&1; then
        log_info "Installation d'ImageMagick..."
        if ! safe_execute "apt-get install -y imagemagick" 3 10; then
            log_error "Échec de l'installation d'ImageMagick"
            log_warn "Le message d'attente ne sera pas créé"
            return 0  # Ne pas bloquer l'installation
        fi
    fi
    
    # Créer une image de message d'attente
    cat > "/opt/scripts/create-waiting-image.sh" << 'EOF'
#!/bin/bash

# Créer une image de message d'attente
convert -size 1920x1080 xc:black \
    -fill white \
    -pointsize 72 \
    -gravity center \
    -annotate 0 "Digital Signage\n\nEn attente de vidéos...\n\nAjoutez des vidéos dans Google Drive" \
    /opt/scripts/waiting-message.png

echo "Message d'attente créé"
EOF
    
    chmod +x /opt/scripts/create-waiting-image.sh
    /opt/scripts/create-waiting-image.sh
    
    log_info "Message d'attente créé"
}

# =============================================================================
# CRÉATION DU SERVICE SYSTEMD
# =============================================================================

create_vlc_service() {
    log_info "Création du service systemd pour VLC..."
    
    # Adapter selon l'environnement graphique
    local has_gui="${HAS_GUI:-false}"
    local gui_type="${GUI_TYPE:-none}"
    local display_env="DISPLAY=:0"
    local exec_start_pre=""
    
    # Configuration spécifique selon l'environnement
    if [[ $has_gui == true ]]; then
        case "$gui_type" in
            "lightdm")
                display_env="DISPLAY=:0"
                exec_start_pre="ExecStartPre=/bin/bash -c 'until systemctl is-active lightdm.service >/dev/null 2>&1; do sleep 2; done; sleep 5'"
                ;;
            "raspberrypi-desktop")
                display_env="DISPLAY=:0"
                if [[ "$GUI_SESSION" == "wayfire" ]]; then
                    display_env="WAYLAND_DISPLAY=wayland-0"
                fi
                exec_start_pre="ExecStartPre=/bin/sleep 10"
                ;;
            "gdm3"|"sddm")
                display_env="DISPLAY=:0"
                exec_start_pre="ExecStartPre=/bin/sleep 15"
                ;;
            *)
                # Pour les environnements sans GUI, on utilise le display :0 par défaut
                display_env="DISPLAY=:0"
                exec_start_pre="ExecStartPre=/bin/bash -c 'until systemctl is-active lightdm.service >/dev/null 2>&1; do sleep 2; done; sleep 5'"
                ;;
        esac
    else
        # Pas de GUI détecté, on utilise la config classique avec LightDM
        display_env="DISPLAY=:0"
        exec_start_pre="ExecStartPre=/bin/bash -c 'until systemctl is-active lightdm.service >/dev/null 2>&1; do sleep 2; done; sleep 5'"
    fi
    
    # Utiliser l'utilisateur détecté ou signage par défaut
    local service_user="signage"
    local service_home="/home/signage"
    
    # Si un autologin différent est détecté, l'utiliser
    if [[ -f /tmp/autologin-detected.conf ]]; then
        source /tmp/autologin-detected.conf
        if [[ -n "${AUTOLOGIN_USER:-}" ]] && [[ "${AUTOLOGIN_USER}" != "signage" ]]; then
            service_user="$AUTOLOGIN_USER"
            service_home="$AUTOLOGIN_HOME"
            log_info "Utilisation de l'utilisateur autologin: $service_user"
        fi
    fi
    
    local service_uid
    service_uid=$(id -u "$service_user" 2>/dev/null || echo "1001")
    
    log_info "Configuration du service pour l'utilisateur: $service_user"
    
    cat > "$VLC_SERVICE" << EOF
[Unit]
Description=VLC Digital Signage
After=multi-user.target network.target sound.target
Wants=network.target sound.target

[Service]
Type=simple
User=$service_user
Group=$service_user
Environment=$display_env
Environment=HOME=$service_home
Environment=XDG_RUNTIME_DIR=/run/user/$service_uid
$exec_start_pre
ExecStart=/opt/scripts/vlc-signage.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
KillMode=mixed
KillSignal=SIGTERM
TimeoutStartSec=120
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF
    
    # Recharger systemd et activer le service
    systemctl daemon-reload
    
    if systemctl enable vlc-signage.service; then
        log_info "Service VLC activé"
    else
        log_error "Échec de l'activation du service VLC"
        return 1
    fi
    
    log_info "Service systemd VLC créé et activé"
}

# =============================================================================
# CONFIGURATION DES PERMISSIONS
# =============================================================================

configure_permissions() {
    log_info "Configuration des permissions..."
    
    # Vérifier que l'utilisateur signage existe
    if ! id "signage" >/dev/null 2>&1; then
        log_error "Utilisateur signage n'existe pas"
        return 1
    fi
    
    # Ajouter l'utilisateur signage aux groupes nécessaires
    local groups=(video audio input render gpio dialout)
    for group in "${groups[@]}"; do
        if getent group "$group" >/dev/null 2>&1; then
            if usermod -a -G "$group" signage; then
                log_info "Utilisateur signage ajouté au groupe $group"
            else
                log_warn "Impossible d'ajouter signage au groupe $group"
            fi
        fi
    done
    
    # Ajout du groupe seat pour Wayland (si disponible)
    if getent group "seat" >/dev/null 2>&1; then
        if usermod -a -G "seat" signage; then
            log_info "Utilisateur signage ajouté au groupe seat (Wayland)"
        else
            log_warn "Impossible d'ajouter signage au groupe seat"
        fi
    fi
    
    # Permissions sécurisées sur les répertoires
    secure_dir_permissions "/home/signage" "signage" "signage" "750"
    # Le répertoire $VIDEO_DIR est déjà créé dans 01-system-config.sh
    # On ajuste juste les permissions si nécessaire
    if [[ -d "$VIDEO_DIR" ]]; then
        secure_dir_permissions "$VIDEO_DIR" "signage" "signage" "750"
    else
        log_error "Répertoire vidéos non trouvé : $VIDEO_DIR"
    fi
    
    # Permissions pour les logs avec accès restreint
    mkdir -p /var/log/pi-signage
    secure_dir_permissions "/var/log/pi-signage" "signage" "signage" "750"
    
    # Logger l'événement de sécurité
    log_security_event "VLC_PERMISSIONS" "Permissions VLC configurées"
    
    log_info "Permissions configurées"
}

# =============================================================================
# CONFIGURATION ENVIRONNEMENT VLC
# =============================================================================

configure_vlc_environment() {
    log_info "Configuration de l'environnement VLC..."
    
    # Créer un script d'environnement VLC (sans modifications système)
    cat > "/opt/scripts/vlc-env.sh" << 'EOF'
#!/bin/bash

# Variables d'environnement pour VLC

# Réduire la verbosité
export VLC_VERBOSE=0

# Path des plugins VLC
export VLC_PLUGIN_PATH=/usr/lib/vlc/plugins

echo "Environnement VLC configuré"
EOF
    
    chmod +x /opt/scripts/vlc-env.sh
    
    log_info "Configuration d'environnement VLC créée"
}

# =============================================================================
# VALIDATION DE L'INSTALLATION VLC
# =============================================================================

validate_vlc_installation() {
    log_info "Validation de l'installation VLC..."
    
    local errors=0
    
    # Vérification de VLC
    if command -v vlc >/dev/null 2>&1; then
        log_info "✓ VLC installé"
    else
        log_error "✗ VLC manquant"
        ((errors++))
    fi
    
    # Vérification du script
    if [[ -f "$VLC_SCRIPT" && -x "$VLC_SCRIPT" ]]; then
        log_info "✓ Script VLC créé"
    else
        log_error "✗ Script VLC manquant"
        ((errors++))
    fi
    
    # Vérification du service
    if systemctl is-enabled vlc-signage.service >/dev/null 2>&1; then
        log_info "✓ Service VLC activé"
    else
        log_error "✗ Service VLC non activé"
        ((errors++))
    fi
    
    # Vérification du répertoire vidéos
    if [[ -d "$VIDEO_DIR" ]]; then
        log_info "✓ Répertoire vidéos présent"
    else
        log_error "✗ Répertoire vidéos manquant"
        ((errors++))
    fi
    
    # Vérification des permissions utilisateur
    if id "signage" >/dev/null 2>&1; then
        log_info "✓ Utilisateur signage configuré"
    else
        log_error "✗ Utilisateur signage manquant"
        ((errors++))
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Installation VLC ==="
    
    # Chargement de la configuration
    if ! load_config; then
        return 1
    fi
    
    # Étapes d'installation
    local steps=(
        "install_vlc"
        "configure_vlc_user"
        "create_vlc_script"
        "create_waiting_message"
        "create_vlc_service"
        "configure_vlc_autostart"
        "configure_permissions"
        "configure_vlc_environment"
    )
    
    local failed_steps=()
    
    for step in "${steps[@]}"; do
        log_info "Exécution: $step"
        if ! "$step"; then
            log_error "Échec de l'étape: $step"
            failed_steps+=("$step")
        fi
    done
    
    # Validation
    if validate_vlc_installation; then
        log_info "VLC installé et configuré avec succès"
    else
        log_warn "VLC installé avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Installation VLC ==="
    return 0
}

# =============================================================================
# EXÉCUTION
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

main "$@"