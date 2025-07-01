#!/usr/bin/env bash

# =============================================================================
# Module 02 - Configuration X11 Minimale (sans display manager)
# Version: 1.0.0
# Description: Configure X11 pour démarrer directement sans LightDM
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly XINITRC="/home/signage/.xinitrc"
readonly BASH_PROFILE="/home/signage/.bash_profile"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo -e "${GREEN}[X11-MIN]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[X11-MIN]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[X11-MIN]${NC} $*" >&2
}

# =============================================================================
# CONFIGURATION AUTO-LOGIN CONSOLE
# =============================================================================

configure_autologin() {
    log_info "Configuration de l'auto-login console..."
    
    # Créer le répertoire override pour getty@tty1
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    
    # Configurer l'auto-login sur tty1
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin signage --noclear %I $TERM
EOF
    
    systemctl daemon-reload
    systemctl enable getty@tty1.service
    
    log_info "Auto-login configuré pour l'utilisateur signage"
}

# =============================================================================
# CONFIGURATION XINITRC
# =============================================================================

create_xinitrc() {
    log_info "Création du fichier .xinitrc..."
    
    cat > "$XINITRC" << 'EOF'
#!/bin/bash

# Fichier .xinitrc pour Pi Signage (mode minimal)

# Variables d'environnement
export DISPLAY=:0
export HOME=/home/signage

# Log de démarrage
echo "[$(date)] Démarrage X11 pour Pi Signage" >> /tmp/pi-signage-x11.log

# Désactiver l'économiseur d'écran et DPMS
xset s off
xset -dpms
xset s noblank

# Masquer le curseur après 1 seconde d'inactivité
unclutter -idle 1 &

# Attendre un peu que X soit complètement prêt
sleep 2

# Déterminer le mode d'affichage
DISPLAY_MODE="vlc"
if [[ -f /etc/pi-signage/display-mode.conf ]]; then
    DISPLAY_MODE=$(cat /etc/pi-signage/display-mode.conf)
fi

echo "[$(date)] Mode d'affichage: $DISPLAY_MODE" >> /tmp/pi-signage-x11.log

# Lancer l'application selon le mode
case "$DISPLAY_MODE" in
    vlc)
        # Lancer VLC directement
        if [[ -x /opt/scripts/vlc-signage.sh ]]; then
            exec /opt/scripts/vlc-signage.sh
        else
            echo "[$(date)] ERREUR: Script VLC non trouvé" >> /tmp/pi-signage-x11.log
            exec xterm  # Terminal de secours
        fi
        ;;
        
    chromium)
        # Lancer Chromium directement
        if [[ -x /opt/scripts/chromium-kiosk.sh ]]; then
            exec /opt/scripts/chromium-kiosk.sh
        else
            echo "[$(date)] ERREUR: Script Chromium non trouvé" >> /tmp/pi-signage-x11.log
            exec xterm  # Terminal de secours
        fi
        ;;
        
    *)
        echo "[$(date)] Mode inconnu: $DISPLAY_MODE" >> /tmp/pi-signage-x11.log
        exec xterm  # Terminal de secours
        ;;
esac
EOF
    
    # Permissions
    chown signage:signage "$XINITRC"
    chmod +x "$XINITRC"
    
    log_info "Fichier .xinitrc créé"
}

# =============================================================================
# CONFIGURATION BASH_PROFILE
# =============================================================================

create_bash_profile() {
    log_info "Configuration du démarrage automatique de X11..."
    
    cat > "$BASH_PROFILE" << 'EOF'
# .bash_profile pour auto-démarrage X11

# Si on est sur tty1 et pas déjà dans X
if [[ -z "$DISPLAY" ]] && [[ "$XDG_VTNR" -eq 1 ]]; then
    echo "Démarrage automatique de X11..."
    sleep 2
    exec startx > /tmp/startx.log 2>&1
fi
EOF
    
    # Permissions
    chown signage:signage "$BASH_PROFILE"
    
    log_info "Auto-démarrage X11 configuré"
}

# =============================================================================
# CONFIGURATION X11 MINIMALE
# =============================================================================

configure_x11_permissions() {
    log_info "Configuration des permissions X11..."
    
    # Permettre à l'utilisateur signage d'utiliser X
    if [[ ! -f /etc/X11/Xwrapper.config ]]; then
        cat > /etc/X11/Xwrapper.config << 'EOF'
allowed_users=anybody
needs_root_rights=yes
EOF
    fi
    
    # S'assurer que l'utilisateur est dans les bons groupes
    usermod -a -G video,audio,input,tty signage
    
    log_info "Permissions X11 configurées"
}

# =============================================================================
# CRÉATION DU SCRIPT DE DÉMARRAGE VLC SIMPLIFIÉ
# =============================================================================

create_vlc_startup_script() {
    log_info "Création du script de démarrage VLC simplifié..."
    
    cat > /opt/scripts/vlc-signage.sh << 'EOF'
#!/bin/bash

# Script de démarrage VLC simplifié
LOG_FILE="/var/log/vlc-signage.log"
PLAYLIST_FILE="/opt/videos/playlist.m3u"
VIDEO_DIR="/opt/videos"

echo "[$(date)] Démarrage VLC Signage" >> "$LOG_FILE"

# Créer la playlist si elle n'existe pas
if [[ ! -f "$PLAYLIST_FILE" ]] || [[ ! -s "$PLAYLIST_FILE" ]]; then
    echo "[$(date)] Création de la playlist..." >> "$LOG_FILE"
    find "$VIDEO_DIR" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" \) | sort > "$PLAYLIST_FILE"
fi

# Attendre que X soit prêt
for i in {1..10}; do
    if xset q &>/dev/null; then
        echo "[$(date)] X11 prêt après $i tentatives" >> "$LOG_FILE"
        break
    fi
    sleep 1
done

# Lancer VLC en plein écran
exec vlc \
    --fullscreen \
    --no-video-title-show \
    --no-mouse-events \
    --no-keyboard-events \
    --loop \
    --no-osd \
    --intf dummy \
    "$PLAYLIST_FILE" \
    >> "$LOG_FILE" 2>&1
EOF
    
    chmod +x /opt/scripts/vlc-signage.sh
    chown signage:signage /opt/scripts/vlc-signage.sh
    
    log_info "Script VLC créé"
}

# =============================================================================
# CRÉATION DU SCRIPT DE DÉMARRAGE CHROMIUM SIMPLIFIÉ
# =============================================================================

create_chromium_startup_script() {
    log_info "Création du script de démarrage Chromium simplifié..."
    
    cat > /opt/scripts/chromium-kiosk.sh << 'EOF'
#!/bin/bash

# Script de démarrage Chromium simplifié
LOG_FILE="/var/log/chromium-kiosk.log"
PLAYER_URL="http://localhost:8888/player.html"

echo "[$(date)] Démarrage Chromium Kiosk" >> "$LOG_FILE"

# Créer le répertoire de cache
mkdir -p /home/signage/.cache/chromium
chown signage:signage /home/signage/.cache/chromium

# Attendre que X soit prêt
for i in {1..10}; do
    if xset q &>/dev/null; then
        echo "[$(date)] X11 prêt après $i tentatives" >> "$LOG_FILE"
        break
    fi
    sleep 1
done

# Attendre que l'interface web soit prête
for i in {1..30}; do
    if curl -s "$PLAYER_URL" >/dev/null; then
        echo "[$(date)] Interface web prête après $i tentatives" >> "$LOG_FILE"
        break
    fi
    sleep 1
done

# Lancer Chromium en mode kiosque
exec chromium-browser \
    --kiosk \
    --no-first-run \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI \
    --check-for-update-interval=31536000 \
    --autoplay-policy=no-user-gesture-required \
    "$PLAYER_URL" \
    >> "$LOG_FILE" 2>&1
EOF
    
    chmod +x /opt/scripts/chromium-kiosk.sh
    chown signage:signage /opt/scripts/chromium-kiosk.sh
    
    log_info "Script Chromium créé"
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_x11_config() {
    log_info "Validation de la configuration X11..."
    
    local errors=0
    
    # Vérifier les fichiers
    local files=("$XINITRC" "$BASH_PROFILE" "/opt/scripts/vlc-signage.sh")
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "✓ Fichier $file présent"
        else
            log_error "✗ Fichier $file manquant"
            ((errors++))
        fi
    done
    
    # Vérifier l'auto-login
    if [[ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]]; then
        log_info "✓ Auto-login configuré"
    else
        log_error "✗ Auto-login non configuré"
        ((errors++))
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Configuration X11 Minimale ==="
    
    # Étapes de configuration
    local steps=(
        "configure_autologin"
        "create_xinitrc"
        "create_bash_profile"
        "configure_x11_permissions"
        "create_vlc_startup_script"
        "create_chromium_startup_script"
    )
    
    for step in "${steps[@]}"; do
        log_info "Exécution: $step"
        if ! "$step"; then
            log_error "Échec de l'étape: $step"
            return 1
        fi
    done
    
    # Validation
    if validate_x11_config; then
        log_info "Configuration X11 minimale réussie"
        log_info ""
        log_info "Au prochain redémarrage :"
        log_info "- Auto-login sur tty1"
        log_info "- X11 démarre automatiquement"
        log_info "- VLC ou Chromium se lance en plein écran"
    else
        log_error "Configuration X11 incomplète"
        return 1
    fi
    
    log_info "=== FIN: Configuration X11 Minimale ==="
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