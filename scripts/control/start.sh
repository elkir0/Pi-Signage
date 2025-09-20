#!/bin/bash
# PiSignage Desktop v3.0 - Start Script
# Démarre le player PiSignage

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly PID_FILE="/tmp/pisignage.pid"
readonly LOG_FILE="$BASE_DIR/logs/pisignage.log"

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Fonctions utilitaires
info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Vérifier si déjà en cours
check_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            warn "PiSignage est déjà en cours d'exécution (PID: $pid)"
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi
}

# Préparation de l'environnement
prepare_environment() {
    info "Préparation de l'environnement..."
    
    # Création des répertoires de logs
    mkdir -p "$BASE_DIR/logs"
    
    # Configuration de l'affichage
    export DISPLAY=${DISPLAY:-:0}
    
    # Désactivation du curseur
    unclutter -display :0 -noevents -grab &
    
    # Configuration GPU (Raspberry Pi)
    if [[ -f /opt/vc/bin/vcgencmd ]]; then
        # Optimisation GPU
        echo "gpu_mem=128" | sudo tee -a /boot/config.txt > /dev/null || true
    fi
}

# Démarrage du player
start_player() {
    info "Démarrage du player PiSignage..."
    
    # Configuration Chromium pour kiosk
    local chromium_flags=(
        "--kiosk"
        "--disable-infobars"
        "--disable-session-crashed-bubble"
        "--disable-component-extensions-with-background-pages"
        "--disable-extensions"
        "--disable-web-security"
        "--disable-features=TranslateUI"
        "--no-first-run"
        "--fast"
        "--fast-start"
        "--disable-default-apps"
        "--disable-popup-blocking"
        "--disable-prompt-on-repost"
        "--no-message-box"
        "--enable-accelerated-video-decode"
        "--enable-gpu-rasterization"
        "--enable-oop-rasterization"
        "--window-position=0,0"
        "--window-size=1920,1080"
        "--autoplay-policy=no-user-gesture-required"
    )
    
    # URL de l'interface web
    local web_url="http://localhost/player"
    
    # Vérification de l'interface web
    if ! curl -sf "$web_url" > /dev/null; then
        warn "Interface web non accessible, utilisation du player local"
        web_url="file://$BASE_DIR/web/player.html"
    fi
    
    # Démarrage de Chromium
    chromium-browser "${chromium_flags[@]}" "$web_url" > "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # Sauvegarde du PID
    echo "$pid" > "$PID_FILE"
    
    info "Player démarré (PID: $pid)"
    info "Logs: $LOG_FILE"
}

# Fonction principale
main() {
    echo "=== PiSignage Desktop v3.0 - Start ==="
    
    check_running
    prepare_environment
    start_player
    
    info "PiSignage Desktop démarré avec succès!"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi