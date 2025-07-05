#!/usr/bin/env bash

# =============================================================================
# Fix Chromium et Audio - Résolution des derniers problèmes
# Version: 1.0.0
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
# 1. FIX CHROMIUM KIOSK
# =============================================================================

fix_chromium_service() {
    log_info "=== Fix Chromium Kiosk Service ==="
    
    # Vérifier pourquoi le service est inactif
    log_info "État actuel du service:"
    systemctl status chromium-kiosk --no-pager || true
    
    # Vérifier les logs
    log_info "Derniers logs:"
    journalctl -u chromium-kiosk -n 20 --no-pager
    
    # Redémarrer le service
    log_info "Redémarrage du service..."
    systemctl daemon-reload
    systemctl restart chromium-kiosk
    
    # Attendre un peu
    sleep 5
    
    # Vérifier à nouveau
    if systemctl is-active --quiet chromium-kiosk; then
        log_info "✓ Chromium-kiosk actif"
    else
        log_error "Chromium-kiosk toujours inactif, vérification approfondie..."
        
        # Tester le script directement
        log_info "Test direct du script:"
        timeout 10 bash /opt/scripts/chromium-kiosk.sh &
        sleep 5
        pkill -f chromium || true
    fi
}

# =============================================================================
# 2. FIX PULSEAUDIO ACCESS DENIED
# =============================================================================

fix_pulseaudio_access() {
    log_info "=== Fix PulseAudio Access Denied ==="
    
    # Arrêter PulseAudio système (pas recommandé)
    log_info "Arrêt de PulseAudio système..."
    systemctl stop pulseaudio || true
    systemctl disable pulseaudio || true
    
    # Supprimer la config système
    rm -f /etc/systemd/system/pulseaudio.service
    
    # Utiliser PulseAudio en mode utilisateur (recommandé)
    log_info "Configuration PulseAudio en mode utilisateur..."
    
    # S'assurer que l'utilisateur pi peut utiliser PulseAudio
    sudo -u pi bash << 'EOF'
# Créer la config utilisateur
mkdir -p ~/.config/pulse
echo "autospawn = yes" > ~/.config/pulse/client.conf

# Créer le répertoire runtime
mkdir -p ~/.config/systemd/user

# Démarrer PulseAudio pour l'utilisateur
pulseaudio --kill 2>/dev/null || true
pulseaudio --start --log-target=syslog
EOF
    
    # Configuration ALSA simple pour HDMI
    log_info "Configuration ALSA pour HDMI direct..."
    cat > /etc/asound.conf << 'EOF'
# Configuration directe HDMI sans PulseAudio
pcm.!default {
    type hw
    card 0
    device 0
}

ctl.!default {
    type hw
    card 0
}
EOF
    
    # Alternative : utiliser directement ALSA dans Chromium
    log_info "Mise à jour des flags audio Chromium..."
    sed -i 's/--alsa-output-device=default/--alsa-output-device=hw:0,0/' /opt/scripts/chromium-kiosk.sh 2>/dev/null || true
}

# =============================================================================
# 3. FIX AUTOSTART LABWC
# =============================================================================

fix_labwc_autostart() {
    log_info "=== Fix Autostart labwc ==="
    
    # Vérifier si on est en Wayland/labwc
    if [[ -d /etc/xdg/labwc ]]; then
        log_info "Configuration labwc détectée"
        
        # Vérifier l'autostart
        if [[ -f /etc/xdg/labwc/autostart ]]; then
            log_info "Contenu actuel de l'autostart:"
            cat /etc/xdg/labwc/autostart
        fi
        
        # S'assurer que Chromium démarre
        log_info "Mise à jour de l'autostart labwc..."
        cat > /etc/xdg/labwc/autostart << 'EOF'
#!/bin/bash
# Autostart pour labwc

# Attendre que l'environnement soit prêt
sleep 3

# Variables d'environnement
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

# Log
echo "[$(date)] Démarrage autostart labwc" >> /var/log/pi-signage/autostart.log

# Démarrer Chromium
/opt/scripts/chromium-kiosk.sh >> /var/log/pi-signage/chromium-autostart.log 2>&1 &

# Garder labwc actif
exec labwc
EOF
        chmod +x /etc/xdg/labwc/autostart
    fi
}

# =============================================================================
# 4. SOLUTION SIMPLE AUDIO
# =============================================================================

simple_audio_fix() {
    log_info "=== Solution Audio Simple (sans PulseAudio) ==="
    
    # Utiliser directement ALSA
    log_info "Configuration ALSA directe..."
    
    # Forcer HDMI0 comme sortie par défaut
    cat > /etc/asound.conf << 'EOF'
pcm.!default {
    type plug
    slave {
        pcm "hw:0,0"
    }
}

ctl.!default {
    type hw
    card 0
}
EOF
    
    # Test audio direct ALSA
    log_info "Test audio ALSA direct..."
    speaker-test -D hw:0,0 -c 2 -t wav -l 1 || log_warn "Test échoué sur HDMI0"
    
    # Créer un script de test simple
    cat > /opt/scripts/test-audio-simple.sh << 'EOF'
#!/bin/bash
echo "=== Test Audio Simple ALSA ==="
echo
echo "Test sur HDMI0 (vc4-hdmi-0):"
speaker-test -D hw:0,0 -c 2 -t wav -l 1

echo
echo "Test sur Headphones:"
speaker-test -D hw:1,0 -c 2 -t wav -l 1

echo
echo "Pour changer la sortie audio:"
echo "- HDMI0: Modifier /etc/asound.conf -> hw:0,0"
echo "- HDMI1: Modifier /etc/asound.conf -> hw:2,0"  
echo "- Jack:  Modifier /etc/asound.conf -> hw:1,0"
EOF
    chmod +x /opt/scripts/test-audio-simple.sh
}

# =============================================================================
# 5. VÉRIFICATIONS FINALES
# =============================================================================

final_checks() {
    log_info "=== Vérifications finales ==="
    
    echo -e "\n${YELLOW}Services:${NC}"
    for service in chromium-kiosk glances nginx; do
        if systemctl is-active --quiet $service; then
            echo -e "  ${GREEN}✓${NC} $service actif"
        else
            echo -e "  ${RED}✗${NC} $service inactif"
        fi
    done
    
    echo -e "\n${YELLOW}Processus Chromium:${NC}"
    if pgrep -f chromium > /dev/null; then
        echo -e "  ${GREEN}✓${NC} Chromium en cours d'exécution"
        ps aux | grep chromium | grep -v grep | head -2
    else
        echo -e "  ${RED}✗${NC} Chromium non trouvé"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en root"
        exit 1
    fi
    
    log_info "=== Fix Chromium et Audio ==="
    echo
    
    # 1. Fix Chromium
    fix_chromium_service
    echo
    
    # 2. Fix PulseAudio
    fix_pulseaudio_access
    echo
    
    # 3. Fix autostart si nécessaire
    fix_labwc_autostart
    echo
    
    # 4. Audio simple
    simple_audio_fix
    echo
    
    # 5. Vérifications
    final_checks
    echo
    
    log_info "=== Actions recommandées ==="
    echo "1. Si l'écran est toujours noir:"
    echo "   sudo systemctl restart chromium-kiosk"
    echo "   OU"
    echo "   sudo reboot"
    echo
    echo "2. Pour tester l'audio:"
    echo "   sudo /opt/scripts/test-audio-simple.sh"
    echo
    echo "3. Si Chromium ne démarre pas:"
    echo "   Vérifier les logs: journalctl -u chromium-kiosk -f"
}

main "$@"