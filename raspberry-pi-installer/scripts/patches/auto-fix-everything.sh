#!/usr/bin/env bash

# =============================================================================
# Script de réparation automatique complète
# Version: 1.0.0
# Description: Détecte et corrige automatiquement tous les problèmes
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Log file
LOG_FILE="/tmp/pi-signage-autofix-$(date +%Y%m%d-%H%M%S).log"

# Fonction de log
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() { log "${GREEN}[INFO]${NC} $*"; }
log_warn() { log "${YELLOW}[WARN]${NC} $*"; }
log_error() { log "${RED}[ERROR]${NC} $*"; }
log_fix() { log "${BLUE}[FIX]${NC} $*"; }

# =============================================================================
# COLLECTE D'INFORMATIONS
# =============================================================================

collect_system_info() {
    log_info "=== Collecte des informations système ==="
    
    {
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "IP: $(hostname -I)"
        echo "OS: $(lsb_release -d | cut -f2)"
        echo "Kernel: $(uname -r)"
        echo "Pi Model: $(grep Model /proc/cpuinfo | cut -d: -f2 | xargs)"
        echo "Uptime: $(uptime -p)"
        echo
        echo "=== Espace disque ==="
        df -h /
        echo
        echo "=== Mémoire ==="
        free -h
        echo
        echo "=== Services Pi Signage ==="
        for service in chromium-kiosk glances nginx php8.2-fpm pulseaudio; do
            status="inactive"
            systemctl is-active --quiet $service 2>/dev/null && status="active"
            echo "$service: $status"
        done
        echo
        echo "=== Processus ==="
        ps aux | grep -E "(chromium|glances|nginx|php)" | grep -v grep || echo "Aucun processus trouvé"
    } >> "$LOG_FILE" 2>&1
}

# =============================================================================
# FIXES AUTOMATIQUES
# =============================================================================

fix_log_permissions() {
    log_fix "Correction des permissions des logs..."
    
    # Créer les répertoires nécessaires
    mkdir -p /var/log/pi-signage
    
    # Déterminer l'utilisateur qui doit posséder les logs
    local log_user="pi"
    if grep -q "User=signage" /etc/systemd/system/chromium-kiosk.service 2>/dev/null; then
        log_user="signage"
    fi
    
    # Corriger les permissions
    chown -R $log_user:$log_user /var/log/pi-signage
    chmod 755 /var/log/pi-signage
    
    # Créer les fichiers de log s'ils n'existent pas
    touch /var/log/pi-signage/{chromium,startup,sync,health}.log
    chown $log_user:$log_user /var/log/pi-signage/*.log
    chmod 644 /var/log/pi-signage/*.log
    
    log_info "✓ Permissions des logs corrigées pour l'utilisateur: $log_user"
}

fix_chromium_service() {
    log_fix "Correction du service Chromium..."
    
    # Vérifier quel utilisateur doit être utilisé
    local service_user="pi"
    
    # Vérifier si le service existe et quel utilisateur il utilise
    if [[ -f /etc/systemd/system/chromium-kiosk.service ]]; then
        current_user=$(grep "^User=" /etc/systemd/system/chromium-kiosk.service | cut -d= -f2 || echo "")
        
        if [[ -n "$current_user" && "$current_user" != "pi" ]]; then
            log_warn "Service configuré pour l'utilisateur: $current_user"
            
            # Vérifier si cet utilisateur existe
            if ! id "$current_user" &>/dev/null; then
                log_error "L'utilisateur $current_user n'existe pas!"
                log_fix "Changement vers l'utilisateur pi..."
                sed -i 's/^User=.*/User=pi/' /etc/systemd/system/chromium-kiosk.service
                service_user="pi"
            else
                service_user="$current_user"
            fi
        fi
    fi
    
    # S'assurer que l'utilisateur est dans les bons groupes
    usermod -a -G video,audio,input,render $service_user 2>/dev/null || true
    
    # Corriger les permissions pour cet utilisateur
    chown -R $service_user:$service_user /var/log/pi-signage
    
    # Recharger et redémarrer
    systemctl daemon-reload
    systemctl restart chromium-kiosk
    
    sleep 5
    
    if systemctl is-active --quiet chromium-kiosk; then
        log_info "✓ Service Chromium actif"
    else
        log_error "Service Chromium toujours inactif"
        log_warn "Tentative de démarrage en mode utilisateur..."
        
        # Créer un service utilisateur
        mkdir -p /home/pi/.config/systemd/user
        cp /etc/systemd/system/chromium-kiosk.service /home/pi/.config/systemd/user/ 2>/dev/null || true
        
        # Activer pour l'utilisateur
        sudo -u pi systemctl --user daemon-reload
        sudo -u pi systemctl --user enable chromium-kiosk
        sudo -u pi systemctl --user start chromium-kiosk
    fi
}

fix_audio_alsa() {
    log_fix "Configuration audio ALSA..."
    
    # Arrêter PulseAudio s'il cause des problèmes
    if systemctl is-active --quiet pulseaudio; then
        systemctl stop pulseaudio
        systemctl disable pulseaudio
        log_info "PulseAudio système désactivé"
    fi
    
    # Configuration ALSA simple
    cat > /etc/asound.conf << 'EOF'
# Configuration ALSA pour HDMI principal
pcm.!default {
    type plug
    slave.pcm "hdmi"
}

pcm.hdmi {
    type hw
    card 0
    device 0
}

ctl.!default {
    type hw
    card 0
}
EOF
    
    # Test audio
    log_info "Test audio..."
    if speaker-test -D default -c 2 -t wav -l 1 &>/dev/null; then
        log_info "✓ Audio fonctionnel"
    else
        log_warn "Audio non fonctionnel, essai sur autres sorties..."
        
        # Essayer toutes les sorties
        for card in 0 1 2; do
            for device in 0; do
                if speaker-test -D hw:$card,$device -c 2 -t wav -l 1 &>/dev/null; then
                    log_info "✓ Audio fonctionnel sur hw:$card,$device"
                    
                    # Mettre à jour asound.conf
                    sed -i "s/card 0/card $card/" /etc/asound.conf
                    break 2
                fi
            done
        done
    fi
}

fix_glances() {
    log_fix "Vérification de Glances..."
    
    if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:61208/ | grep -q "200"; then
        log_warn "Glances non accessible, redémarrage..."
        systemctl restart glances
        sleep 3
    fi
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:61208/ | grep -q "200"; then
        log_info "✓ Glances accessible"
    else
        log_error "Glances toujours inaccessible"
    fi
}

fix_gpu_performance() {
    log_fix "Vérification performance GPU..."
    
    # Vérifier H264
    if ! vcgencmd codec_enabled H264 2>/dev/null | grep -q "enabled"; then
        log_warn "Codec H264 non activé"
        
        # Vérifier gpu_mem
        for config in /boot/firmware/config.txt /boot/config.txt; do
            if [[ -f "$config" ]]; then
                if ! grep -q "^gpu_mem=128" "$config"; then
                    log_fix "Ajout de gpu_mem=128 dans $config"
                    echo "gpu_mem=128" >> "$config"
                    log_warn "REDÉMARRAGE REQUIS pour activer l'accélération GPU"
                fi
                break
            fi
        done
    else
        log_info "✓ Codec H264 activé"
    fi
}

# =============================================================================
# RAPPORT FINAL
# =============================================================================

generate_report() {
    log_info "=== Rapport de réparation ==="
    
    echo
    echo "Vérifications finales:" | tee -a "$LOG_FILE"
    echo "---------------------" | tee -a "$LOG_FILE"
    
    # Services
    for service in chromium-kiosk glances nginx php8.2-fpm; do
        if systemctl is-active --quiet $service; then
            echo -e "${GREEN}✓${NC} $service: actif" | tee -a "$LOG_FILE"
        else
            echo -e "${RED}✗${NC} $service: inactif" | tee -a "$LOG_FILE"
        fi
    done
    
    # GPU
    if vcgencmd codec_enabled H264 2>/dev/null | grep -q "enabled"; then
        echo -e "${GREEN}✓${NC} Accélération GPU H264: activée" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}✗${NC} Accélération GPU H264: désactivée (redémarrage requis)" | tee -a "$LOG_FILE"
    fi
    
    # URLs
    echo | tee -a "$LOG_FILE"
    echo "URLs d'accès:" | tee -a "$LOG_FILE"
    echo "-------------" | tee -a "$LOG_FILE"
    local ip=$(hostname -I | awk '{print $1}')
    echo "Interface web: http://$ip/" | tee -a "$LOG_FILE"
    echo "Glances: http://$ip:61208" | tee -a "$LOG_FILE"
    
    echo | tee -a "$LOG_FILE"
    echo "Log complet sauvegardé dans: $LOG_FILE" | tee -a "$LOG_FILE"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ce script doit être exécuté en root${NC}"
        exit 1
    fi
    
    log_info "=== Démarrage de la réparation automatique ==="
    log_info "Log: $LOG_FILE"
    echo
    
    # Collecte d'infos
    collect_system_info
    
    # Application des fixes
    fix_log_permissions
    fix_chromium_service
    fix_audio_alsa
    fix_glances
    fix_gpu_performance
    
    # Rapport
    generate_report
    
    echo
    log_info "=== Réparation terminée ==="
    
    # Actions finales
    if grep -q "REDÉMARRAGE REQUIS" "$LOG_FILE"; then
        echo
        log_warn "Un redémarrage est nécessaire pour appliquer tous les changements"
        read -p "Redémarrer maintenant ? (o/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Oo]$ ]]; then
            log_info "Redémarrage..."
            reboot
        fi
    fi
}

# Capture Ctrl+C
trap 'echo -e "\n${RED}Interrompu par l'utilisateur${NC}"; exit 1' INT

# Lancer
main "$@"