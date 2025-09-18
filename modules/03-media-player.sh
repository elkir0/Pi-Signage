#!/bin/bash
# =============================================================================
# Module 03: Media Player - PiSignage Desktop v3.0
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="/opt/pisignage"
USER="pisignage"
VERBOSE=${VERBOSE:-false}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[MEDIA-PLAYER] $1"
    fi
}

# Détection Chromium
detect_chromium() {
    log "Détection de Chromium..."
    
    CHROMIUM_PATHS=(
        "/usr/bin/chromium-browser"
        "/usr/bin/chromium"
        "/snap/bin/chromium"
        "/usr/lib/chromium-browser/chromium-browser"
    )
    
    for path in "${CHROMIUM_PATHS[@]}"; do
        if [[ -x "$path" ]]; then
            CHROMIUM_BIN="$path"
            log "Chromium trouvé: $CHROMIUM_BIN"
            echo -e "${GREEN}✓ Chromium détecté: $CHROMIUM_BIN${NC}"
            return 0
        fi
    done
    
    echo -e "${YELLOW}⚠ Chromium non trouvé, installation...${NC}"
    sudo apt-get install -y chromium-browser || sudo apt-get install -y chromium
    
    # Nouvelle tentative
    for path in "${CHROMIUM_PATHS[@]}"; do
        if [[ -x "$path" ]]; then
            CHROMIUM_BIN="$path"
            echo -e "${GREEN}✓ Chromium installé: $CHROMIUM_BIN${NC}"
            return 0
        fi
    done
    
    echo -e "${RED}✗ Impossible de trouver Chromium${NC}"
    return 1
}

# Créer script de contrôle unifié
create_control_script() {
    log "Création du script de contrôle unifié..."
    
    cat > "$BASE_DIR/scripts/player-control.sh" << 'EOF'
#!/bin/bash
#
# Script de contrôle unifié pour PiSignage Desktop v3.0
#

ACTION="${1:-status}"
VIDEO="${2:-}"
CHROMIUM_BIN=$(which chromium-browser || which chromium || echo "/usr/bin/chromium")
PID_FILE="/var/run/pisignage-player.pid"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Fonction pour démarrer le player
start_player() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
        echo -e "${YELLOW}Player déjà en cours d'exécution${NC}"
        return 1
    fi
    
    # Préparer l'environnement
    export DISPLAY=:0
    xset -dpms 2>/dev/null || true
    xset s noblank 2>/dev/null || true
    xset s off 2>/dev/null || true
    unclutter -idle 0.5 -root &
    
    # URL ou vidéo à lire
    if [[ -n "$VIDEO" ]]; then
        TARGET="file:///opt/pisignage/videos/$VIDEO"
    else
        TARGET="http://localhost/"
    fi
    
    # Lancer Chromium en mode kiosk
    $CHROMIUM_BIN \
        --kiosk \
        --noerrdialogs \
        --disable-infobars \
        --disable-session-crashed-bubble \
        --disable-features=TranslateUI \
        --disable-component-update \
        --autoplay-policy=no-user-gesture-required \
        --enable-features=OverlayScrollbar \
        --enable-gpu-rasterization \
        --enable-accelerated-video-decode \
        --ignore-gpu-blocklist \
        "$TARGET" &
    
    echo $! > "$PID_FILE"
    echo -e "${GREEN}✓ Player démarré (PID: $(cat $PID_FILE))${NC}"
}

# Fonction pour arrêter le player
stop_player() {
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            rm -f "$PID_FILE"
            echo -e "${GREEN}✓ Player arrêté${NC}"
        else
            echo -e "${YELLOW}Player non actif${NC}"
            rm -f "$PID_FILE"
        fi
    else
        pkill -f chromium 2>/dev/null || true
        echo -e "${GREEN}✓ Tous les processus Chromium arrêtés${NC}"
    fi
}

# Fonction pour redémarrer le player
restart_player() {
    stop_player
    sleep 2
    start_player
}

# Fonction pour afficher le status
show_status() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
        echo -e "${GREEN}● Player actif (PID: $(cat $PID_FILE))${NC}"
        ps aux | grep -E "$(cat $PID_FILE)" | grep -v grep
    else
        echo -e "${RED}● Player inactif${NC}"
    fi
}

# Menu principal
case "$ACTION" in
    start)
        start_player
        ;;
    stop)
        stop_player
        ;;
    restart)
        restart_player
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status} [video_file]"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$BASE_DIR/scripts/player-control.sh"
    
    # Créer lien symbolique pour accès facile
    sudo ln -sf "$BASE_DIR/scripts/player-control.sh" /usr/local/bin/pisignage-player
    
    echo -e "${GREEN}✓ Script de contrôle créé${NC}"
}

# Configuration autostart
configure_autostart() {
    log "Configuration de l'autostart..."
    
    # Déterminer l'utilisateur avec session graphique
    DESKTOP_USER="${SUDO_USER:-$USER}"
    AUTOSTART_DIR="/home/$DESKTOP_USER/.config/autostart"
    
    # Créer le répertoire autostart
    mkdir -p "$AUTOSTART_DIR"
    
    # Créer fichier .desktop
    cat > "$AUTOSTART_DIR/pisignage-player.desktop" << EOF
[Desktop Entry]
Type=Application
Name=PiSignage Player
Comment=Démarre le lecteur PiSignage au démarrage
Exec=$BASE_DIR/scripts/player-control.sh start
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=AudioVideo;Player;
Icon=video-display
EOF
    
    # Permissions
    chown "$DESKTOP_USER:$DESKTOP_USER" "$AUTOSTART_DIR/pisignage-player.desktop"
    chmod 644 "$AUTOSTART_DIR/pisignage-player.desktop"
    
    echo -e "${GREEN}✓ Autostart configuré pour l'utilisateur $DESKTOP_USER${NC}"
}

# Configuration VLC fallback
configure_vlc_fallback() {
    log "Configuration VLC en fallback..."
    
    # Vérifier si VLC est installé
    if ! command -v vlc &>/dev/null; then
        log "Installation de VLC..."
        sudo apt-get install -y vlc
    fi
    
    # Créer script VLC
    cat > "$BASE_DIR/scripts/vlc-player.sh" << 'EOF'
#!/bin/bash
#
# Script VLC fallback pour PiSignage Desktop
#

VIDEO_DIR="/opt/pisignage/videos"
PLAYLIST="$VIDEO_DIR/playlist.m3u"

# Créer playlist
ls -1 "$VIDEO_DIR"/*.{mp4,avi,mkv,mov,webm} 2>/dev/null > "$PLAYLIST"

# Lancer VLC
cvlc \
    --fullscreen \
    --no-video-title-show \
    --loop \
    --intf dummy \
    "$PLAYLIST"
EOF
    
    chmod +x "$BASE_DIR/scripts/vlc-player.sh"
    
    echo -e "${GREEN}✓ VLC configuré comme lecteur fallback${NC}"
}

# Créer vidéo de test
create_test_video() {
    log "Création d'une vidéo de test..."
    
    # Créer une vidéo de test simple si ffmpeg est disponible
    if command -v ffmpeg &>/dev/null; then
        ffmpeg -f lavfi -i testsrc=duration=10:size=1920x1080:rate=30 \
               -f lavfi -i sine=frequency=1000:duration=10 \
               -pix_fmt yuv420p \
               "$BASE_DIR/videos/test_pisignage.mp4" \
               -y -loglevel error 2>/dev/null
        
        echo -e "${GREEN}✓ Vidéo de test créée${NC}"
    else
        echo -e "${YELLOW}⚠ ffmpeg non disponible, pas de vidéo de test${NC}"
    fi
}

# Main
main() {
    echo "Module 3: Media Player"
    echo "======================"
    
    detect_chromium
    create_control_script
    configure_autostart
    configure_vlc_fallback
    create_test_video
    
    echo ""
    echo -e "${GREEN}✓ Module media player terminé${NC}"
    echo "  Contrôle: pisignage-player {start|stop|restart|status}"
    
    return 0
}

# Exécution
main "$@"