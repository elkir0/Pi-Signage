#!/usr/bin/env bash

# =============================================================================
# Fix complet v2 pour tous les problèmes
# Version: 2.0.0
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[FIX]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[FIX]${NC} $*"; }
log_error() { echo -e "${RED}[FIX]${NC} $*" >&2; }

# =============================================================================
# 1. FIX GLANCES DÉFINITIF
# =============================================================================

fix_glances_v2() {
    log_info "=== Fix Glances v2 (solution complète) ==="
    
    # Arrêter Glances
    systemctl stop glances 2>/dev/null || true
    
    # Solution 1: Utiliser Glances en mode standalone (sans proxy)
    log_info "Configuration de Glances en mode web direct..."
    
    # Créer un nouveau service Glances
    cat > /etc/systemd/system/glances.service << 'EOF'
[Unit]
Description=Glances - System Monitoring
Documentation=man:glances(1)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/glances -w --bind 0.0.0.0 --port 61208 --disable-plugin docker
Restart=on-failure
RestartSec=10
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Supprimer la config nginx de Glances si elle existe
    rm -f /etc/nginx/sites-enabled/glances
    rm -f /etc/nginx/sites-available/glances
    
    # Recharger et démarrer
    systemctl daemon-reload
    systemctl enable glances
    systemctl start glances
    
    # Vérifier que Glances écoute
    sleep 2
    if netstat -tlnp | grep -q ":61208"; then
        log_info "✓ Glances écoute sur le port 61208"
    else
        log_error "✗ Glances ne semble pas écouter sur 61208"
        log_info "Vérification des logs..."
        journalctl -u glances -n 20 --no-pager
    fi
    
    # Recharger nginx
    nginx -t && systemctl reload nginx
    
    log_info "✓ Glances configuré en mode standalone sur :61208"
}

# =============================================================================
# 2. FIX PERFORMANCE VIDÉO COMPLET
# =============================================================================

fix_video_performance_v2() {
    log_info "=== Fix Performance Vidéo v2 ==="
    
    # 1. Vérifier que gpu_mem est bien appliqué
    log_info "Vérification de la configuration GPU..."
    
    # Trouver le bon config.txt
    CONFIG_FILE=""
    for path in "/boot/firmware/config.txt" "/boot/config.txt"; do
        if [[ -f "$path" ]]; then
            CONFIG_FILE="$path"
            break
        fi
    done
    
    if [[ -z "$CONFIG_FILE" ]]; then
        log_error "config.txt non trouvé!"
        return 1
    fi
    
    # Vérifier gpu_mem
    if ! grep -q "^gpu_mem=128" "$CONFIG_FILE"; then
        log_error "gpu_mem=128 n'est pas configuré dans $CONFIG_FILE"
        log_warn "Ajout de gpu_mem=128..."
        echo "gpu_mem=128" >> "$CONFIG_FILE"
        log_warn "REDÉMARRAGE REQUIS!"
    else
        log_info "✓ gpu_mem=128 configuré"
    fi
    
    # 2. Vérifier et corriger les flags Chromium
    log_info "Mise à jour complète du script Chromium..."
    
    # Sauvegarder l'original
    cp /opt/scripts/chromium-kiosk.sh /opt/scripts/chromium-kiosk.sh.bak.v2
    
    # Créer une version optimisée complète
    cat > /opt/scripts/chromium-kiosk.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Attendre que le système soit prêt
sleep 5

# Variables d'environnement pour Wayland
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

# Logs
LOG_FILE="/var/log/pi-signage/chromium.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date)] Démarrage Chromium Kiosk" >> "$LOG_FILE"

# URL du player local
PLAYER_URL="http://localhost:8888/player.html"

# Nettoyer les anciens processus
pkill -f chromium || true
sleep 2

# Flags Chromium optimisés pour performance vidéo
CHROMIUM_FLAGS=(
    --kiosk
    --noerrdialogs
    --disable-infobars
    --disable-session-crashed-bubble
    --disable-features=TranslateUI,Translate
    --no-first-run
    --fast
    --fast-start
    --disable-features=AudioServiceOutOfProcess
    --autoplay-policy=no-user-gesture-required
    --window-position=0,0
    --window-size=1920,1080
    --force-device-scale-factor=1
    # Optimisations GPU CRITIQUES
    --use-gl=egl
    --enable-gpu-rasterization
    --enable-accelerated-video-decode
    --enable-features=VaapiVideoDecoder,VaapiVideoEncoder
    --enable-native-gpu-memory-buffers
    --ignore-gpu-blocklist
    --disable-gpu-sandbox
    --disable-software-rasterizer
    # Optimisations mémoire
    --max-old-space-size=512
    --memory-pressure-off
    --disable-background-timer-throttling
    # Audio
    --alsa-output-device=default
    --enable-features=AudioServiceSandbox
)

# Détecter l'environnement
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "[$(date)] Mode Wayland détecté" >> "$LOG_FILE"
    CHROMIUM_FLAGS+=(
        --ozone-platform=wayland
        --enable-features=UseOzonePlatform
    )
elif [[ -n "${DISPLAY:-}" ]]; then
    echo "[$(date)] Mode X11 détecté" >> "$LOG_FILE"
    CHROMIUM_FLAGS+=(
        --display=:0
    )
fi

# Lancer Chromium
echo "[$(date)] Lancement avec flags: ${CHROMIUM_FLAGS[*]}" >> "$LOG_FILE"

while true; do
    chromium-browser "${CHROMIUM_FLAGS[@]}" "$PLAYER_URL" >> "$LOG_FILE" 2>&1
    echo "[$(date)] Chromium terminé, redémarrage dans 5s..." >> "$LOG_FILE"
    sleep 5
done
EOF
    
    chmod +x /opt/scripts/chromium-kiosk.sh
    
    # 3. Vérifier les codecs
    log_info "État des codecs:"
    for codec in H264 MPG2 WVC1; do
        status=$(vcgencmd codec_enabled $codec 2>/dev/null | cut -d= -f2 || echo "non disponible")
        if [[ "$status" == "enabled" ]]; then
            echo -e "  ${GREEN}✓${NC} $codec: enabled"
        else
            echo -e "  ${RED}✗${NC} $codec: $status"
        fi
    done
    
    # Si H264 n'est pas enabled, c'est un problème de gpu_mem
    if ! vcgencmd codec_enabled H264 2>/dev/null | grep -q "enabled"; then
        log_error "H264 non activé! Vérifiez gpu_mem=128 et redémarrez"
    fi
    
    log_info "✓ Script Chromium optimisé pour performance vidéo"
}

# =============================================================================
# 3. FIX AUDIO COMPLET
# =============================================================================

fix_audio_v2() {
    log_info "=== Fix Audio v2 (solution complète) ==="
    
    # 1. Installer les dépendances audio
    log_info "Installation des paquets audio..."
    apt-get update
    apt-get install -y \
        pulseaudio \
        pulseaudio-utils \
        alsa-utils \
        pavucontrol
    
    # 2. Configurer ALSA
    log_info "Configuration ALSA..."
    
    # Forcer la sortie audio (2 = HDMI, 1 = Jack)
    echo -e "${YELLOW}Configuration de la sortie audio:${NC}"
    echo "1) Jack 3.5mm (analogique)"
    echo "2) HDMI"
    read -p "Votre choix [1-2]: " audio_choice
    
    case $audio_choice in
        1) amixer cset numid=3 1 ;;
        2) amixer cset numid=3 2 ;;
        *) log_warn "Choix invalide, utilisation HDMI par défaut"
           amixer cset numid=3 2 ;;
    esac
    
    # 3. Configurer PulseAudio pour l'utilisateur
    log_info "Configuration PulseAudio..."
    
    # S'assurer que PulseAudio démarre pour l'utilisateur
    sudo -u pi bash -c 'mkdir -p ~/.config/pulse'
    sudo -u pi bash -c 'echo "autospawn = yes" > ~/.config/pulse/client.conf'
    
    # 4. Configurer le volume
    log_info "Configuration du volume..."
    amixer set Master 85% unmute
    amixer set PCM 85% unmute
    
    # 5. Créer un script de test audio
    cat > /opt/scripts/test-audio.sh << 'EOF'
#!/bin/bash
echo "Test audio - vous devriez entendre un son..."
speaker-test -t wav -c 2 -l 1
EOF
    chmod +x /opt/scripts/test-audio.sh
    
    # 6. Ajouter l'utilisateur aux groupes audio
    usermod -a -G audio,pulse-access pi 2>/dev/null || usermod -a -G audio pi
    
    log_info "✓ Configuration audio complète"
    log_info "Testez avec: /opt/scripts/test-audio.sh"
}

# =============================================================================
# 4. VÉRIFICATIONS FINALES
# =============================================================================

final_checks() {
    log_info "=== Vérifications finales ==="
    
    echo -e "\n${YELLOW}1. Services:${NC}"
    for service in chromium-kiosk glances nginx php8.2-fpm; do
        if systemctl is-active --quiet $service; then
            echo -e "  ${GREEN}✓${NC} $service: actif"
        else
            echo -e "  ${RED}✗${NC} $service: inactif"
        fi
    done
    
    echo -e "\n${YELLOW}2. Ports:${NC}"
    netstat -tlnp | grep -E "(80|8888|61208)" || echo "Aucun port trouvé"
    
    echo -e "\n${YELLOW}3. GPU/Codecs:${NC}"
    vcgencmd codec_enabled H264 || echo "Impossible de vérifier"
    
    echo -e "\n${YELLOW}4. Mémoire GPU:${NC}"
    vcgencmd get_mem gpu || echo "Impossible de vérifier"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en root"
        exit 1
    fi
    
    log_info "=== Fix complet v2 - Résolution définitive ==="
    echo
    
    # Appliquer tous les fixes
    fix_glances_v2
    echo
    fix_video_performance_v2
    echo
    fix_audio_v2
    echo
    final_checks
    
    # Redémarrer les services
    log_info "Redémarrage des services..."
    systemctl restart chromium-kiosk
    systemctl restart glances
    
    echo
    log_info "=== Actions finales requises ==="
    echo
    echo "1. Si gpu_mem a été ajouté/modifié:"
    echo "   ${RED}sudo reboot${NC}"
    echo
    echo "2. Après redémarrage, vérifier:"
    echo "   - Glances: http://[IP]:61208"
    echo "   - GPU: vcgencmd codec_enabled H264"
    echo "   - Audio: /opt/scripts/test-audio.sh"
    echo
    echo "3. Dans Chromium, vérifier chrome://gpu"
    echo "   'Video Decode' doit être vert"
}

main "$@"