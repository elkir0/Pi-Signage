#!/bin/bash
# PiSignage Desktop v3.0 - Status Script
# Affiche le status du player PiSignage

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly PID_FILE="/tmp/pisignage.pid"

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Fonctions utilitaires
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Vérification du processus principal
check_main_process() {
    echo "=== Status du processus principal ==="
    
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            success "PiSignage en cours d'exécution (PID: $pid)"
            
            # Informations du processus
            local process_info=$(ps -p "$pid" -o pid,ppid,cmd --no-headers)
            echo "Processus: $process_info"
            
            # Utilisation mémoire
            local memory=$(ps -p "$pid" -o rss --no-headers | awk '{print $1/1024 " MB"}')
            echo "Mémoire: $memory"
            
            return 0
        else
            error "Fichier PID présent mais processus absent"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        error "PiSignage non démarré (pas de fichier PID)"
        return 1
    fi
}

# Vérification des services
check_services() {
    echo
    echo "=== Status des services ==="
    
    # Nginx
    if systemctl is-active --quiet nginx; then
        success "Nginx actif"
    else
        warn "Nginx inactif"
    fi
    
    # Interface web
    if curl -sf http://localhost > /dev/null 2>&1; then
        success "Interface web accessible"
    else
        warn "Interface web non accessible"
    fi
}

# Vérification des processus liés
check_related_processes() {
    echo
    echo "=== Processus liés ==="
    
    # Chromium
    local chromium_count=$(pgrep -f "chromium" | wc -l)
    if [[ $chromium_count -gt 0 ]]; then
        success "Chromium: $chromium_count processus"
    else
        warn "Aucun processus Chromium"
    fi
    
    # Unclutter
    if pgrep unclutter > /dev/null; then
        success "Unclutter actif"
    else
        warn "Unclutter inactif"
    fi
}

# Informations système
check_system_info() {
    echo
    echo "=== Informations système ==="
    
    # Adresse IP
    local ip_address=$(hostname -I | awk '{print $1}')
    info "Adresse IP: $ip_address"
    
    # Interface web
    info "Interface web: http://$ip_address"
    
    # Utilisation mémoire globale
    local memory_usage=$(free -h | awk 'NR==2{printf "%.1f%%", $3/$2*100}')
    info "Utilisation mémoire: $memory_usage"
    
    # Charge système
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    info "Charge système:$load_avg"
    
    # Température (Raspberry Pi)
    if [[ -f /opt/vc/bin/vcgencmd ]]; then
        local temp=$(/opt/vc/bin/vcgencmd measure_temp | cut -d= -f2)
        info "Température CPU: $temp"
    fi
}

# Logs récents
show_recent_logs() {
    echo
    echo "=== Logs récents ==="
    
    local log_file="$BASE_DIR/logs/pisignage.log"
    if [[ -f "$log_file" ]]; then
        tail -n 5 "$log_file"
    else
        warn "Fichier de log non trouvé"
    fi
}

# Résumé du status
show_summary() {
    echo
    echo "=== Résumé ==="
    
    local is_running=false
    
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            is_running=true
        fi
    fi
    
    if [[ "$is_running" == true ]]; then
        success "PiSignage Desktop: EN MARCHE"
    else
        error "PiSignage Desktop: ARRÊTÉ"
    fi
    
    echo
    echo "Commandes disponibles:"
    echo "  Démarrer:  $SCRIPT_DIR/start.sh"
    echo "  Arrêter:   $SCRIPT_DIR/stop.sh"
    echo "  Redémarrer: $SCRIPT_DIR/restart.sh"
}

# Fonction principale
main() {
    echo "=== PiSignage Desktop v3.0 - Status ==="
    echo
    
    check_main_process
    check_services
    check_related_processes
    check_system_info
    show_recent_logs
    show_summary
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi