#!/usr/bin/env bash

# =============================================================================
# Module 10 - Gestionnaire de démarrage Pi Signage
# Version: 1.0.0
# Description: Configure un démarrage progressif pour éviter les blocages
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly STARTUP_SERVICE="/etc/systemd/system/pi-signage-startup.service"
readonly STARTUP_SCRIPT="/opt/scripts/pi-signage-startup.sh"

# Charger les fonctions de sécurité
if [[ -f "$SCRIPT_DIR/00-security-utils.sh" ]]; then
    source "$SCRIPT_DIR/00-security-utils.sh"
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
    echo -e "${GREEN}[BOOT]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[BOOT]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[BOOT]${NC} $*" >&2
}

# =============================================================================
# CRÉATION DU SERVICE DE DÉMARRAGE
# =============================================================================

create_startup_service() {
    log_info "Création du service de démarrage progressif..."
    
    cat > "$STARTUP_SERVICE" << 'EOF'
[Unit]
Description=Pi Signage Startup Manager
After=multi-user.target network.target sound.target
Wants=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 10
ExecStart=/opt/scripts/pi-signage-startup.sh
StandardOutput=journal
StandardError=journal
TimeoutStartSec=300

[Install]
WantedBy=default.target
EOF

    log_info "Service de démarrage créé"
}

# =============================================================================
# CRÉATION DU SCRIPT DE DÉMARRAGE
# =============================================================================

create_startup_script() {
    log_info "Création du script de démarrage..."
    
    cat > "$STARTUP_SCRIPT" << 'EOF'
#!/bin/bash

# Script de démarrage progressif Pi Signage
# Version simplifiée - L'affichage est géré par autologin/autostart
LOG_FILE="/var/log/pi-signage-startup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== Démarrage Pi Signage ==="

# Attendre que le système soit stable
log "Attente de la stabilisation du système..."
sleep 5

# Vérifier les services réseau
for i in {1..30}; do
    if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        log "Réseau disponible après $i secondes"
        break
    fi
    sleep 1
done

# Déterminer le mode d'affichage
DISPLAY_MODE="vlc"  # Par défaut
if [[ -f /etc/pi-signage/display-mode.conf ]]; then
    DISPLAY_MODE=$(cat /etc/pi-signage/display-mode.conf)
fi

log "Mode d'affichage détecté: $DISPLAY_MODE"

# Note: L'affichage (VLC/Chromium) est maintenant géré par:
# - Autologin configuré via raspi-config
# - Autostart configuré selon l'environnement (X11/Wayland/labwc)
# - Services utilisateur pour Chromium sur Desktop
# Ce script gère uniquement les services auxiliaires

log "Mode d'affichage configuré: $DISPLAY_MODE"
log "Les services d'affichage seront démarrés par autologin/autostart"

# Démarrer les services auxiliaires
sleep 5

# Glances (si installé)
if systemctl list-unit-files glances.service >/dev/null 2>&1; then
    log "Démarrage de Glances..."
    systemctl start glances || log "Avertissement: Échec du démarrage de Glances"
fi

# Watchdog (si installé)
if systemctl list-unit-files pi-signage-watchdog.service >/dev/null 2>&1; then
    log "Démarrage du watchdog..."
    systemctl start pi-signage-watchdog || log "Avertissement: Échec du démarrage du watchdog"
fi

# Interface web nginx
if systemctl list-unit-files nginx.service >/dev/null 2>&1; then
    if ! systemctl is-active nginx >/dev/null 2>&1; then
        log "Démarrage de nginx..."
        systemctl start nginx || log "Avertissement: Échec du démarrage de nginx"
    fi
fi

log "=== Démarrage Pi Signage terminé ==="

# Afficher l'état final
sleep 2
log ""
log "État des services:"
systemctl is-active lightdm 2>/dev/null && log "  - LightDM: actif" || log "  - LightDM: inactif"
systemctl is-active vlc-signage 2>/dev/null && log "  - VLC: actif" || log "  - VLC: inactif"
systemctl is-active chromium-kiosk 2>/dev/null && log "  - Chromium: actif" || log "  - Chromium: inactif"
systemctl is-active glances 2>/dev/null && log "  - Glances: actif" || log "  - Glances: inactif"
systemctl is-active nginx 2>/dev/null && log "  - Nginx: actif" || log "  - Nginx: inactif"
systemctl is-active pi-signage-watchdog 2>/dev/null && log "  - Watchdog: actif" || log "  - Watchdog: inactif"

exit 0
EOF

    chmod +x "$STARTUP_SCRIPT"
    log_info "Script de démarrage créé"
}

# =============================================================================
# DÉSACTIVATION DES SERVICES AU DÉMARRAGE AUTOMATIQUE
# =============================================================================

disable_auto_start_services() {
    log_info "Configuration des services pour démarrage géré..."
    
    # Avec la nouvelle approche, nous ne désactivons plus les services principaux
    # car ils sont gérés par autologin/autostart ou services utilisateur
    
    log_info "Les services suivants seront gérés automatiquement :"
    log_info "  - Gestionnaires de bureau (lightdm/gdm3) : conservés pour autologin"
    log_info "  - Services d'affichage (vlc/chromium) : démarrés par autostart"
    log_info "  - Services auxiliaires : démarrés par ce script"
    
    # On ne désactive que les services qui pourraient causer des conflits
    local services_to_disable=(
        "x11-kiosk"  # Remplacé par autologin/autostart
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl list-unit-files "$service.service" >/dev/null 2>&1; then
            systemctl disable "$service" 2>/dev/null || true
            log_info "  - $service désactivé (remplacé par nouvelle approche)"
        fi
    done
}

# =============================================================================
# ACTIVATION DU GESTIONNAIRE DE DÉMARRAGE
# =============================================================================

enable_boot_manager() {
    log_info "Activation du gestionnaire de démarrage..."
    
    systemctl daemon-reload
    
    if systemctl enable pi-signage-startup.service; then
        log_info "Service de démarrage activé"
    else
        log_error "Échec de l'activation du service de démarrage"
        return 1
    fi
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_boot_manager() {
    log_info "Validation du gestionnaire de démarrage..."
    
    local errors=0
    
    # Vérifier le service
    if [[ -f "$STARTUP_SERVICE" ]]; then
        log_info "✓ Service de démarrage présent"
    else
        log_error "✗ Service de démarrage manquant"
        ((errors++))
    fi
    
    # Vérifier le script
    if [[ -x "$STARTUP_SCRIPT" ]]; then
        log_info "✓ Script de démarrage présent et exécutable"
    else
        log_error "✗ Script de démarrage manquant ou non exécutable"
        ((errors++))
    fi
    
    # Vérifier l'activation
    if systemctl is-enabled pi-signage-startup.service >/dev/null 2>&1; then
        log_info "✓ Service de démarrage activé"
    else
        log_error "✗ Service de démarrage non activé"
        ((errors++))
    fi
    
    # Vérifier que les services critiques sont désactivés
    if ! systemctl is-enabled lightdm >/dev/null 2>&1; then
        log_info "✓ LightDM correctement désactivé au boot"
    else
        log_warn "⚠ LightDM toujours activé au boot"
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Configuration du gestionnaire de démarrage ==="
    
    # Étapes d'installation
    local steps=(
        "create_startup_service"
        "create_startup_script"
        "disable_auto_start_services"
        "enable_boot_manager"
    )
    
    for step in "${steps[@]}"; do
        log_info "Exécution: $step"
        if ! "$step"; then
            log_error "Échec de l'étape: $step"
            return 1
        fi
    done
    
    # Validation
    if validate_boot_manager; then
        log_info "Gestionnaire de démarrage configuré avec succès"
        log_info ""
        log_info "Nouvelle approche de démarrage :"
        log_info "- Autologin géré par raspi-config"
        log_info "- Affichage démarré par autostart (X11/Wayland/labwc)"
        log_info "- Services auxiliaires gérés par ce script"
        log_info "- Logs disponibles dans /var/log/pi-signage-startup.log"
    else
        log_error "Configuration incomplète du gestionnaire de démarrage"
        return 1
    fi
    
    log_info "=== FIN: Configuration du gestionnaire de démarrage ==="
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