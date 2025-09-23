#!/bin/bash

# PiSignage v0.9.0 - Script de Monitoring Post-Déploiement
# Surveillance continue du système et alertes automatiques

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MONITOR_LOG="/opt/pisignage/logs/monitor.log"
ALERT_LOG="/opt/pisignage/logs/alerts.log"
MONITOR_INTERVAL=60  # secondes
ALERT_COOLDOWN=300   # 5 minutes entre les alertes du même type
PISIGNAGE_URL="http://localhost"
PISIGNAGE_DIR="/opt/pisignage"

# Seuils d'alerte
CPU_TEMP_WARNING=70
CPU_TEMP_CRITICAL=80
LOAD_WARNING=2.0
LOAD_CRITICAL=4.0
MEMORY_WARNING=80
MEMORY_CRITICAL=90
DISK_WARNING=80
DISK_CRITICAL=90
RESPONSE_TIME_WARNING=3.0
RESPONSE_TIME_CRITICAL=10.0

# Variables de suivi des alertes
declare -A last_alert_time

# Fonction de log
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "ALERT")
            echo -e "${RED}[ALERT]${NC} $message"
            echo "[$timestamp] [ALERT] $message" >> "$ALERT_LOG"
            ;;
    esac
    echo "[$timestamp] [$level] $message" >> "$MONITOR_LOG"
}

# Fonction pour vérifier le cooldown des alertes
can_send_alert() {
    local alert_type="$1"
    local current_time=$(date +%s)
    local last_time=${last_alert_time[$alert_type]:-0}

    if [[ $((current_time - last_time)) -gt $ALERT_COOLDOWN ]]; then
        last_alert_time[$alert_type]=$current_time
        return 0
    else
        return 1
    fi
}

# Fonction d'envoi d'alerte
send_alert() {
    local alert_type="$1"
    local message="$2"
    local severity="$3"

    if can_send_alert "$alert_type"; then
        log "ALERT" "[$severity] $alert_type: $message"

        # Optionnel: envoyer par email, webhook, etc.
        # curl -X POST "webhook_url" -d "alert=$message" &>/dev/null || true
    fi
}

# Monitoring de la température CPU
monitor_cpu_temperature() {
    if command -v vcgencmd &>/dev/null; then
        local temp_raw=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
        local temp_int=${temp_raw%.*}

        echo "cpu_temp:$temp_raw"

        if [[ $temp_int -ge $CPU_TEMP_CRITICAL ]]; then
            send_alert "cpu_temperature" "Température CPU critique: ${temp_raw}°C" "CRITICAL"
        elif [[ $temp_int -ge $CPU_TEMP_WARNING ]]; then
            send_alert "cpu_temperature" "Température CPU élevée: ${temp_raw}°C" "WARNING"
        fi
    else
        echo "cpu_temp:N/A"
    fi
}

# Monitoring de la charge système
monitor_system_load() {
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    echo "load_avg:$load_avg"

    if (( $(echo "$load_avg > $LOAD_CRITICAL" | bc -l) )); then
        send_alert "system_load" "Charge système critique: $load_avg" "CRITICAL"
    elif (( $(echo "$load_avg > $LOAD_WARNING" | bc -l) )); then
        send_alert "system_load" "Charge système élevée: $load_avg" "WARNING"
    fi
}

# Monitoring de la mémoire
monitor_memory_usage() {
    local mem_info=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    echo "memory_usage:${mem_info}%"

    local mem_int=${mem_info%.*}
    if [[ $mem_int -ge $MEMORY_CRITICAL ]]; then
        send_alert "memory_usage" "Utilisation mémoire critique: ${mem_info}%" "CRITICAL"
    elif [[ $mem_int -ge $MEMORY_WARNING ]]; then
        send_alert "memory_usage" "Utilisation mémoire élevée: ${mem_info}%" "WARNING"
    fi
}

# Monitoring de l'espace disque
monitor_disk_usage() {
    local disk_usage=$(df "$PISIGNAGE_DIR" | awk 'NR==2 {print $5}' | tr -d '%')
    echo "disk_usage:${disk_usage}%"

    if [[ $disk_usage -ge $DISK_CRITICAL ]]; then
        send_alert "disk_usage" "Espace disque critique: ${disk_usage}%" "CRITICAL"
    elif [[ $disk_usage -ge $DISK_WARNING ]]; then
        send_alert "disk_usage" "Espace disque faible: ${disk_usage}%" "WARNING"
    fi
}

# Monitoring des services
monitor_services() {
    local services=("nginx" "php7.4-fpm" "pisignage")
    local services_status=""

    for service in "${services[@]}"; do
        if systemctl is-active "$service" &>/dev/null; then
            services_status="${services_status}${service}:active "
        else
            services_status="${services_status}${service}:inactive "
            send_alert "service_down" "Service arrêté: $service" "CRITICAL"
        fi
    done

    echo "services:$services_status"
}

# Monitoring de l'interface web
monitor_web_interface() {
    local start_time=$(date +%s.%N)
    local response_code
    local response_time

    response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "$PISIGNAGE_URL" 2>/dev/null)
    local end_time=$(date +%s.%N)
    response_time=$(echo "$end_time - $start_time" | bc)

    echo "web_response_code:$response_code"
    echo "web_response_time:${response_time}s"

    # Vérifier le code de réponse
    if [[ "$response_code" != "200" ]]; then
        send_alert "web_interface" "Interface web non accessible (HTTP $response_code)" "CRITICAL"
    fi

    # Vérifier le temps de réponse
    if (( $(echo "$response_time > $RESPONSE_TIME_CRITICAL" | bc -l) )); then
        send_alert "web_performance" "Temps de réponse critique: ${response_time}s" "CRITICAL"
    elif (( $(echo "$response_time > $RESPONSE_TIME_WARNING" | bc -l) )); then
        send_alert "web_performance" "Temps de réponse lent: ${response_time}s" "WARNING"
    fi
}

# Monitoring des APIs
monitor_apis() {
    local api_endpoints=("/api/system.php" "/api/media.php")
    local api_status=""

    for endpoint in "${api_endpoints[@]}"; do
        local api_response
        api_response=$(curl -s --connect-timeout 5 --max-time 15 "$PISIGNAGE_URL$endpoint" 2>/dev/null)

        if echo "$api_response" | jq -e '.status' &>/dev/null; then
            api_status="${api_status}${endpoint}:ok "
        else
            api_status="${api_status}${endpoint}:error "
            send_alert "api_error" "API non fonctionnelle: $endpoint" "WARNING"
        fi
    done

    echo "apis:$api_status"
}

# Monitoring des processus
monitor_processes() {
    local high_cpu_procs=$(ps aux | awk '$3 > 50 {print $11}' | head -3 | tr '\n' ' ')
    local high_mem_procs=$(ps aux | awk '$4 > 20 {print $11}' | head -3 | tr '\n' ' ')

    if [[ -n "$high_cpu_procs" ]]; then
        echo "high_cpu_processes:$high_cpu_procs"
        send_alert "high_cpu_usage" "Processus à forte charge CPU: $high_cpu_procs" "WARNING"
    else
        echo "high_cpu_processes:none"
    fi

    if [[ -n "$high_mem_procs" ]]; then
        echo "high_mem_processes:$high_mem_procs"
        send_alert "high_memory_usage" "Processus à forte charge mémoire: $high_mem_procs" "WARNING"
    else
        echo "high_mem_processes:none"
    fi
}

# Monitoring de l'espace disque des logs
monitor_log_size() {
    local log_size=$(du -sh "$PISIGNAGE_DIR/logs" 2>/dev/null | cut -f1)
    local log_size_mb=$(du -sm "$PISIGNAGE_DIR/logs" 2>/dev/null | cut -f1)

    echo "log_size:$log_size"

    if [[ $log_size_mb -gt 1000 ]]; then  # Plus de 1GB
        send_alert "log_size" "Taille des logs importante: $log_size" "WARNING"
    fi
}

# Monitoring de la connectivité réseau
monitor_network() {
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo "internet:connected"
    else
        echo "internet:disconnected"
        send_alert "network_connectivity" "Pas de connectivité Internet" "CRITICAL"
    fi

    local ip_address=$(hostname -I | awk '{print $1}')
    echo "ip_address:$ip_address"
}

# Monitoring GPU (Raspberry Pi)
monitor_gpu() {
    if command -v vcgencmd &>/dev/null; then
        local gpu_mem=$(vcgencmd get_mem gpu | cut -d= -f2)
        echo "gpu_memory:$gpu_mem"

        # Vérifier si la GPU est utilisée
        if lsmod | grep -q vc4; then
            echo "gpu_driver:vc4_loaded"
        else
            echo "gpu_driver:not_loaded"
            send_alert "gpu_driver" "Driver GPU VC4 non chargé" "WARNING"
        fi
    else
        echo "gpu_memory:N/A"
        echo "gpu_driver:N/A"
    fi
}

# Fonction de collecte complète des métriques
collect_metrics() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local metrics=""

    metrics="$metrics timestamp:$timestamp "
    metrics="$metrics $(monitor_cpu_temperature) "
    metrics="$metrics $(monitor_system_load) "
    metrics="$metrics $(monitor_memory_usage) "
    metrics="$metrics $(monitor_disk_usage) "
    metrics="$metrics $(monitor_services) "
    metrics="$metrics $(monitor_web_interface) "
    metrics="$metrics $(monitor_apis) "
    metrics="$metrics $(monitor_processes) "
    metrics="$metrics $(monitor_log_size) "
    metrics="$metrics $(monitor_network) "
    metrics="$metrics $(monitor_gpu) "

    echo "$metrics"
}

# Fonction de rapport de santé
generate_health_report() {
    local report_file="/tmp/pisignage-health-$(date +%Y%m%d-%H%M%S).txt"

    cat << EOF > "$report_file"
PiSignage v0.9.0 - Rapport de Santé Système
===========================================

Date: $(date)
Hostname: $(hostname)
Uptime: $(uptime -p)

MÉTRIQUES ACTUELLES:
-------------------
$(collect_metrics | tr ' ' '\n' | grep -v '^$')

SERVICES:
--------
$(systemctl list-units --state=active --type=service | grep -E "(nginx|php|pisignage)")

ESPACE DISQUE:
--------------
$(df -h)

MÉMOIRE:
--------
$(free -h)

PROCESSUS TOP CPU:
------------------
$(ps aux --sort=-%cpu | head -10)

PROCESSUS TOP MÉMOIRE:
---------------------
$(ps aux --sort=-%mem | head -10)

DERNIÈRES ALERTES:
-----------------
$(tail -10 "$ALERT_LOG" 2>/dev/null || echo "Aucune alerte récente")

LOGS RÉCENTS:
------------
$(tail -20 "$MONITOR_LOG" 2>/dev/null || echo "Aucun log récent")
EOF

    echo "$report_file"
}

# Fonction de nettoyage des logs
cleanup_logs() {
    # Nettoyer les logs de monitoring plus anciens que 7 jours
    find "$PISIGNAGE_DIR/logs" -name "monitor-*.log" -mtime +7 -delete 2>/dev/null || true

    # Nettoyer les logs d'alerte plus anciens que 30 jours
    if [[ -f "$ALERT_LOG" ]]; then
        local temp_alert_log="/tmp/alert_cleanup.log"
        tail -1000 "$ALERT_LOG" > "$temp_alert_log" 2>/dev/null || true
        mv "$temp_alert_log" "$ALERT_LOG" 2>/dev/null || true
    fi

    # Nettoyer les logs de monitoring si trop volumineux
    if [[ -f "$MONITOR_LOG" ]] && [[ $(stat -c%s "$MONITOR_LOG") -gt 10485760 ]]; then  # Plus de 10MB
        local temp_monitor_log="/tmp/monitor_cleanup.log"
        tail -5000 "$MONITOR_LOG" > "$temp_monitor_log" 2>/dev/null || true
        mv "$temp_monitor_log" "$MONITOR_LOG" 2>/dev/null || true
        log "INFO" "Log de monitoring nettoyé (taille trop importante)"
    fi
}

# Fonction de monitoring en boucle
monitoring_loop() {
    log "INFO" "Démarrage du monitoring continu..."
    log "INFO" "Intervalle: ${MONITOR_INTERVAL}s"
    log "INFO" "Log principal: $MONITOR_LOG"
    log "INFO" "Log alertes: $ALERT_LOG"

    local iteration=0

    while true; do
        ((iteration++))

        # Collecte des métriques
        local metrics=$(collect_metrics)
        echo "[$iteration] $metrics" >> "$MONITOR_LOG"

        # Affichage périodique (toutes les 10 itérations)
        if [[ $((iteration % 10)) -eq 0 ]]; then
            log "INFO" "Monitoring actif (itération $iteration)"
            log "INFO" "Dernières métriques: $(echo "$metrics" | cut -c1-100)..."
        fi

        # Nettoyage périodique (toutes les 100 itérations)
        if [[ $((iteration % 100)) -eq 0 ]]; then
            cleanup_logs
        fi

        # Génération de rapport de santé (toutes les 1000 itérations, ~16h)
        if [[ $((iteration % 1000)) -eq 0 ]]; then
            local health_report=$(generate_health_report)
            log "INFO" "Rapport de santé généré: $health_report"
        fi

        sleep "$MONITOR_INTERVAL"
    done
}

# Fonction d'arrêt propre
cleanup_and_exit() {
    log "INFO" "Arrêt du monitoring (signal reçu)"
    exit 0
}

# Fonction d'aide
show_help() {
    cat << EOF
PiSignage v0.9.0 - Monitoring Post-Déploiement

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Afficher cette aide
    -i, --interval SEC  Intervalle de monitoring (défaut: $MONITOR_INTERVAL)
    -r, --report        Générer un rapport de santé uniquement
    -c, --check         Vérification unique (pas de boucle)
    -l, --logs          Afficher les derniers logs

EXEMPLES:
    $0                  # Monitoring continu
    $0 --interval 30    # Monitoring toutes les 30 secondes
    $0 --report         # Générer un rapport de santé
    $0 --check          # Vérification unique
    $0 --logs           # Afficher les logs récents

Le monitoring surveille en continu:
- Température CPU et charge système
- Utilisation mémoire et disque
- Services (nginx, php, pisignage)
- Interface web et APIs
- Connectivité réseau
- GPU et drivers

Les alertes sont générées automatiquement en cas de problème
et sauvegardées dans $ALERT_LOG.

EOF
}

# Fonction principale
main() {
    echo "PiSignage v0.9.0 - Monitoring Post-Déploiement"
    echo "=============================================="
    echo

    # Créer les répertoires de logs
    mkdir -p "$(dirname "$MONITOR_LOG")"
    mkdir -p "$(dirname "$ALERT_LOG")"

    # Gérer les signaux pour arrêt propre
    trap cleanup_and_exit SIGTERM SIGINT

    log "INFO" "Initialisation du monitoring..."
    log "INFO" "PID: $$"

    # Vérification initiale
    log "INFO" "=== VÉRIFICATION INITIALE ==="
    local initial_metrics=$(collect_metrics)
    log "INFO" "Métriques: $initial_metrics"

    monitoring_loop
}

# Parsing des arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -r|--report)
        report_file=$(generate_health_report)
        echo "Rapport de santé généré: $report_file"
        cat "$report_file"
        exit 0
        ;;
    -c|--check)
        echo "=== VÉRIFICATION UNIQUE ==="
        collect_metrics | tr ' ' '\n'
        exit 0
        ;;
    -l|--logs)
        echo "=== LOGS DE MONITORING ==="
        tail -50 "$MONITOR_LOG" 2>/dev/null || echo "Aucun log trouvé"
        echo
        echo "=== LOGS D'ALERTES ==="
        tail -20 "$ALERT_LOG" 2>/dev/null || echo "Aucune alerte trouvée"
        exit 0
        ;;
    -i|--interval)
        MONITOR_INTERVAL="$2"
        shift 2
        ;;
esac

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi