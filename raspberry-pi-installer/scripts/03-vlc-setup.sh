#!/usr/bin/env bash

# =============================================================================
# Module 03 - Installation et Configuration VLC
# Version: 2.0.0
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
        "ffmpeg"
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
DISPLAY=:7.0

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
export DISPLAY=:7.0
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
        --vout=gl \
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
    while ! xset q >/dev/null 2>&1; do
        log_vlc "Attente de l'initialisation de X11..."
        sleep 5
    done
    
    # Désactiver l'économiseur d'écran
    xset s off
    xset -dpms
    xset s noblank
    
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
# CRÉATION DU MESSAGE D'ATTENTE
# =============================================================================

create_waiting_message() {
    log_info "Création du message d'attente..."
    
    # Installer ImageMagick pour créer l'image d'attente
    if ! command -v convert >/dev/null 2>&1; then
        apt-get install -y imagemagick
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
    
    cat > "$VLC_SERVICE" << 'EOF'
[Unit]
Description=VLC Digital Signage
After=graphical-session.target lightdm.service
Wants=graphical-session.target

[Service]
Type=simple
User=signage
Group=signage
Environment=DISPLAY=:7.0
Environment=HOME=/home/signage
Environment=XDG_RUNTIME_DIR=/run/user/1001
ExecStartPre=/bin/sleep 30
ExecStart=/opt/scripts/vlc-signage.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
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
    
    # Ajouter l'utilisateur signage aux groupes nécessaires
    usermod -a -G video,audio,input,render,gpio,dialout signage
    
    # Permissions sur les répertoires
    chown -R signage:signage /home/signage
    chown signage:signage "$VIDEO_DIR"
    
    # Permissions pour les logs
    mkdir -p /var/log/pi-signage
    chown signage:signage /var/log/pi-signage
    
    log_info "Permissions configurées"
}

# =============================================================================
# OPTIMISATIONS VLC POUR RASPBERRY PI
# =============================================================================

optimize_vlc_pi() {
    log_info "Application des optimisations VLC pour Raspberry Pi..."
    
    # Créer un script d'optimisation GPU
    cat > "/opt/scripts/vlc-optimize.sh" << 'EOF'
#!/bin/bash

# Optimisations pour VLC sur Raspberry Pi

# GPU Memory
if [[ -f /boot/config.txt ]]; then
    if ! grep -q "gpu_mem=" /boot/config.txt; then
        echo "gpu_mem=128" >> /boot/config.txt
    fi
fi

# Codec optimizations
export VLC_VERBOSE=0
export VLC_PLUGIN_PATH=/usr/lib/vlc/plugins

echo "Optimisations VLC appliquées"
EOF
    
    chmod +x /opt/scripts/vlc-optimize.sh
    
    log_info "Optimisations VLC créées"
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
        "configure_permissions"
        "optimize_vlc_pi"
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