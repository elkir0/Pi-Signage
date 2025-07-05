#!/usr/bin/env bash

# =============================================================================
# Fix Audio Final - Solution complète pour Raspberry Pi 4
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[AUDIO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[AUDIO]${NC} $*"; }
log_error() { echo -e "${RED}[AUDIO]${NC} $*" >&2; }

# =============================================================================
# FIX AUDIO COMPLET
# =============================================================================

fix_audio_complete() {
    log_info "=== Configuration Audio Complète ==="
    
    # 1. Détection du hardware audio
    log_info "Détection du hardware audio..."
    aplay -l
    echo
    
    # 2. Configuration ALSA pour Pi 4
    log_info "Configuration ALSA pour Raspberry Pi 4..."
    
    # Créer/mettre à jour asound.conf
    cat > /etc/asound.conf << 'EOF'
pcm.!default {
    type hw
    card 0
}

ctl.!default {
    type hw
    card 0
}
EOF
    
    # 3. Forcer la sortie audio HDMI
    log_info "Configuration de la sortie audio..."
    
    # Pour Pi 4, utiliser raspi-config
    # 0 = Auto, 1 = Force headphones, 2 = Force HDMI
    raspi-config nonint do_audio 2
    
    # 4. Configurer PulseAudio
    log_info "Configuration PulseAudio..."
    
    # Créer la config PulseAudio système
    mkdir -p /etc/pulse
    cat > /etc/pulse/default.pa << 'EOF'
# Configuration PulseAudio pour Pi Signage

# Charger les modules de base
load-module module-device-restore
load-module module-stream-restore
load-module module-card-restore
load-module module-augment-properties
load-module module-switch-on-port-available

# Détection automatique ALSA
load-module module-udev-detect
load-module module-detect

# Support réseau local uniquement
load-module module-native-protocol-unix

# Restauration automatique
load-module module-default-device-restore
load-module module-rescue-streams
load-module module-always-sink
load-module module-intended-roles
load-module module-suspend-on-idle

# Volume par défaut
set-sink-volume @DEFAULT_SINK@ 65536
EOF
    
    # 5. Configuration pour l'utilisateur pi
    log_info "Configuration pour l'utilisateur pi..."
    
    # Créer la config utilisateur
    sudo -u pi mkdir -p /home/pi/.config/pulse
    sudo -u pi bash -c 'cat > /home/pi/.config/pulse/client.conf << EOF
autospawn = yes
daemon-binary = /usr/bin/pulseaudio
EOF'
    
    # 6. S'assurer que l'utilisateur est dans les bons groupes
    usermod -a -G audio,video pi
    
    # 7. Démarrer PulseAudio en mode système
    log_info "Démarrage de PulseAudio..."
    
    # Créer un service PulseAudio système
    cat > /etc/systemd/system/pulseaudio.service << 'EOF'
[Unit]
Description=PulseAudio system server
After=sound.target

[Service]
Type=notify
ExecStart=/usr/bin/pulseaudio --system --disallow-exit --disable-shm
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable pulseaudio
    systemctl restart pulseaudio || true
    
    # 8. Test audio
    log_info "Test audio..."
    sleep 2
    
    # Générer un son de test
    speaker-test -t sine -f 1000 -l 1 -p 1000 || log_warn "Test audio échoué"
    
    log_info "✓ Configuration audio terminée"
}

# =============================================================================
# SCRIPT DE TEST AUDIO
# =============================================================================

create_audio_test() {
    log_info "Création du script de test audio amélioré..."
    
    cat > /opt/scripts/test-audio-complete.sh << 'EOF'
#!/bin/bash

echo "=== Test Audio Complet ==="
echo

# 1. Vérifier les devices
echo "1. Devices audio disponibles:"
aplay -l
echo

# 2. Tester avec aplay
echo "2. Test avec aplay (son simple)..."
(
    DURATION=1
    for i in $(seq 1 $((DURATION*8000))); do
        echo -ne "\x$(printf '%02x' $((128 + 127 * $(bc -l <<< "s($i/1000)"))))"
    done
) | aplay -r 8000 -f U8 -c 1 -q -D default || echo "Échec aplay"

# 3. Tester avec speaker-test
echo
echo "3. Test avec speaker-test..."
speaker-test -t wav -c 2 -l 1 || echo "Échec speaker-test"

# 4. Vérifier PulseAudio
echo
echo "4. État PulseAudio:"
if systemctl is-active --quiet pulseaudio; then
    echo "PulseAudio actif (système)"
    pactl info || echo "Impossible d'obtenir les infos"
else
    echo "PulseAudio non actif en mode système"
    sudo -u pi pactl info 2>/dev/null || echo "PulseAudio non disponible pour l'utilisateur"
fi

echo
echo "Test terminé!"
EOF
    
    chmod +x /opt/scripts/test-audio-complete.sh
}

# =============================================================================
# VÉRIFICATIONS FINALES
# =============================================================================

verify_audio() {
    log_info "=== Vérifications Audio ==="
    
    echo "1. Configuration ALSA:"
    cat /etc/asound.conf 2>/dev/null || echo "Pas de asound.conf"
    
    echo -e "\n2. Sortie audio active:"
    raspi-config nonint get_config_var audio_pwm_mode /boot/firmware/config.txt || echo "Non défini"
    
    echo -e "\n3. Groupes de l'utilisateur pi:"
    groups pi
    
    echo -e "\n4. État PulseAudio:"
    systemctl is-active pulseaudio || echo "Inactif"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en root"
        exit 1
    fi
    
    log_info "=== Fix Audio Final pour Raspberry Pi 4 ==="
    echo
    
    # Appliquer le fix
    fix_audio_complete
    echo
    
    # Créer le script de test
    create_audio_test
    echo
    
    # Vérifications
    verify_audio
    echo
    
    log_info "=== Actions finales ==="
    echo "1. Redémarrer Chromium:"
    echo "   sudo systemctl restart chromium-kiosk"
    echo
    echo "2. Tester l'audio:"
    echo "   sudo /opt/scripts/test-audio-complete.sh"
    echo
    echo "3. Si l'audio ne fonctionne toujours pas:"
    echo "   - Vérifier le câble HDMI"
    echo "   - Vérifier que la TV/moniteur n'est pas en muet"
    echo "   - Essayer la sortie Jack: raspi-config nonint do_audio 1"
}

main "$@"