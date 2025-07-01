#!/usr/bin/env bash

# =============================================================================
# Script de correction de l'ordre de boot pour Pi Signage
# Version: 1.0.0
# Description: Corrige les problèmes de blocage au démarrage
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== Correction de l'ordre de boot Pi Signage ==="
    
    # Vérifier qu'on est root
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
    
    # 1. Désactiver temporairement tous les services Pi Signage
    log_info "Désactivation temporaire des services Pi Signage..."
    
    local services=(
        "vlc-signage"
        "chromium-kiosk"
        "pi-signage-watchdog"
        "lightdm"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            systemctl disable "$service" || true
            log_info "  - $service désactivé"
        fi
    done
    
    # 2. Corriger les dépendances des services
    log_info "Correction des dépendances des services..."
    
    # VLC service
    if [[ -f /etc/systemd/system/vlc-signage.service ]]; then
        log_info "Correction du service VLC..."
        sed -i 's/After=graphical-session.target/After=multi-user.target/' /etc/systemd/system/vlc-signage.service
        sed -i 's/WantedBy=multi-user.target/WantedBy=default.target/' /etc/systemd/system/vlc-signage.service
    fi
    
    # Watchdog service
    if [[ -f /etc/systemd/system/pi-signage-watchdog.service ]]; then
        log_info "Correction du service watchdog..."
        sed -i 's/PrivateTmp=yes/PrivateTmp=no/' /etc/systemd/system/pi-signage-watchdog.service
        sed -i 's/WantedBy=multi-user.target/WantedBy=default.target/' /etc/systemd/system/pi-signage-watchdog.service
    fi
    
    # 3. Créer un service de démarrage retardé
    log_info "Création d'un service de démarrage retardé..."
    
    cat > /etc/systemd/system/pi-signage-startup.service << 'EOF'
[Unit]
Description=Pi Signage Startup Manager
After=multi-user.target network.target
Wants=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 10
ExecStart=/opt/scripts/pi-signage-startup.sh
TimeoutStartSec=300

[Install]
WantedBy=default.target
EOF

    # 4. Créer le script de démarrage
    cat > /opt/scripts/pi-signage-startup.sh << 'EOF'
#!/bin/bash

# Script de démarrage progressif Pi Signage
echo "=== Démarrage Pi Signage ==="

# Attendre que le système soit stable
sleep 5

# Déterminer le mode d'affichage
DISPLAY_MODE="vlc"  # Par défaut
if [[ -f /etc/pi-signage/display-mode.conf ]]; then
    DISPLAY_MODE=$(cat /etc/pi-signage/display-mode.conf)
fi

echo "Mode d'affichage: $DISPLAY_MODE"

# Démarrer les services selon le mode
case "$DISPLAY_MODE" in
    vlc)
        # Démarrer lightdm d'abord
        if systemctl is-enabled lightdm &>/dev/null; then
            echo "Démarrage de LightDM..."
            systemctl start lightdm
            sleep 10
        fi
        
        # Puis VLC
        if [[ -f /etc/systemd/system/vlc-signage.service ]]; then
            echo "Démarrage de VLC..."
            systemctl start vlc-signage
        fi
        ;;
        
    chromium)
        # Démarrer Chromium Kiosk
        if [[ -x /opt/scripts/chromium-kiosk.sh ]]; then
            echo "Démarrage de Chromium Kiosk..."
            /opt/scripts/chromium-kiosk.sh &
        fi
        ;;
esac

# Démarrer le watchdog
if systemctl is-enabled pi-signage-watchdog &>/dev/null; then
    echo "Démarrage du watchdog..."
    systemctl start pi-signage-watchdog
fi

echo "=== Démarrage Pi Signage terminé ==="
EOF

    chmod +x /opt/scripts/pi-signage-startup.sh
    
    # 5. Activer uniquement le service de démarrage
    log_info "Activation du service de démarrage..."
    systemctl daemon-reload
    systemctl enable pi-signage-startup.service
    
    # 6. Nettoyer les caches
    log_info "Nettoyage des caches..."
    rm -rf /tmp/*
    journalctl --vacuum-size=50M
    
    log_info ""
    log_info "=== Correction terminée ==="
    log_info ""
    log_info "Le système a été reconfiguré pour éviter les blocages au démarrage."
    log_info "Au prochain redémarrage :"
    log_info "- Les services démarreront progressivement"
    log_info "- Un délai de 10-15 secondes est normal avant l'affichage"
    log_info ""
    log_info "Redémarrez maintenant avec: sudo reboot"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi