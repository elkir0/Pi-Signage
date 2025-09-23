#!/bin/bash
# PiSignage v0.8.0 - System Monitor Script
# Surveillance système pour Raspberry Pi

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/system-monitor.log"
ALERT_FILE="$PROJECT_DIR/logs/system-alerts.log"
STATUS_FILE="$PROJECT_DIR/config/system-status.json"

# Configuration des seuils
CPU_THRESHOLD=80        # %
MEMORY_THRESHOLD=85     # %
DISK_THRESHOLD=90       # %
TEMP_THRESHOLD=70       # °C
UPTIME_MIN=300          # 5 minutes

# Créer les dossiers nécessaires
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$STATUS_FILE")"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonctions de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1" | tee -a "$ALERT_FILE" >&2
}

# Obtenir les statistiques CPU
get_cpu_stats() {
    # Utiliser le load average sur 1 minute
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
    local cpu_cores=$(nproc)
    local cpu_percent=$(echo "scale=1; $load_avg * 100 / $cpu_cores" | bc -l 2>/dev/null || echo "0")

    # S'assurer que le résultat est un nombre valide
    if ! [[ "$cpu_percent" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        cpu_percent="0"
    fi

    echo "$cpu_percent"
}

# Obtenir les statistiques mémoire
get_memory_stats() {
    local mem_info=$(cat /proc/meminfo)
    local mem_total=$(echo "$mem_info" | grep MemTotal | awk '{print $2}')
    local mem_available=$(echo "$mem_info" | grep MemAvailable | awk '{print $2}')

    if [[ -n "$mem_total" && -n "$mem_available" ]]; then
        local mem_used=$((mem_total - mem_available))
        local mem_percent=$(echo "scale=1; $mem_used * 100 / $mem_total" | bc -l)
        echo "$mem_percent"
    else
        echo "0"
    fi
}

# Obtenir la température
get_temperature() {
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp_millicelsius=$(cat /sys/class/thermal/thermal_zone0/temp)
        local temp_celsius=$(echo "scale=1; $temp_millicelsius / 1000" | bc -l)
        echo "$temp_celsius"
    else
        echo "0"
    fi
}

# Obtenir l'utilisation disque
get_disk_usage() {
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "$disk_usage"
}

# Obtenir l'uptime
get_uptime() {
    local uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
    echo "$uptime_seconds"
}

# Vérifier l'état des services
check_services() {
    local services=("nginx" "php7.4-fpm")
    local service_status=()

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            service_status+=("\"$service\":\"active\"")
        else
            service_status+=("\"$service\":\"inactive\"")
            alert "Service $service is not running"
        fi
    done

    echo "{$(IFS=,; echo "${service_status[*]}")}"
}

# Vérifier l'état de VLC
check_vlc_status() {
    if pgrep vlc >/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

# Vérifier l'état du réseau
check_network() {
    local interfaces=()
    local gateway_reachable="false"

    # Vérifier les interfaces réseau
    while IFS= read -r interface; do
        if [[ -n "$interface" && "$interface" != "lo" ]]; then
            local ip=$(ip addr show "$interface" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
            if [[ -n "$ip" ]]; then
                interfaces+=("\"$interface\":\"$ip\"")
            fi
        fi
    done < <(ls /sys/class/net/)

    # Vérifier la connectivité gateway
    if ping -c 1 -W 2 $(ip route | grep default | awk '{print $3}' | head -1) >/dev/null 2>&1; then
        gateway_reachable="true"
    fi

    local network_json="{"
    network_json+="\"interfaces\":{$(IFS=,; echo "${interfaces[*]}")},"
    network_json+="\"gateway_reachable\":$gateway_reachable"
    network_json+="}"

    echo "$network_json"
}

# Obtenir les informations système
get_system_info() {
    local hostname=$(hostname)
    local kernel=$(uname -r)
    local os_info=""

    if [[ -f /etc/os-release ]]; then
        os_info=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    fi

    local system_json="{"
    system_json+="\"hostname\":\"$hostname\","
    system_json+="\"kernel\":\"$kernel\","
    system_json+="\"os\":\"$os_info\""
    system_json+="}"

    echo "$system_json"
}

# Vérifier les processus PiSignage
check_pisignage_processes() {
    local processes=()

    # Chercher les processus liés à PiSignage
    if pgrep -f "nginx.*pisignage" >/dev/null; then
        processes+=("\"nginx\":\"running\"")
    else
        processes+=("\"nginx\":\"stopped\"")
    fi

    if pgrep -f "php.*fpm" >/dev/null; then
        processes+=("\"php-fpm\":\"running\"")
    else
        processes+=("\"php-fpm\":\"stopped\"")
    fi

    local vlc_status=$(check_vlc_status)
    processes+=("\"vlc\":\"$vlc_status\"")

    echo "{$(IFS=,; echo "${processes[*]}")}"
}

# Analyser les logs récents
analyze_recent_logs() {
    local error_count=0
    local warning_count=0

    if [[ -f "$PROJECT_DIR/logs/pisignage.log" ]]; then
        # Compter les erreurs et warnings des dernières 24h
        local recent_logs=$(find "$PROJECT_DIR/logs" -name "*.log" -mtime -1)

        for log_file in $recent_logs; do
            if [[ -f "$log_file" ]]; then
                error_count=$((error_count + $(grep -c "ERROR" "$log_file" 2>/dev/null || echo 0)))
                warning_count=$((warning_count + $(grep -c "WARNING\|WARN" "$log_file" 2>/dev/null || echo 0)))
            fi
        done
    fi

    local log_analysis="{"
    log_analysis+="\"errors_24h\":$error_count,"
    log_analysis+="\"warnings_24h\":$warning_count"
    log_analysis+="}"

    echo "$log_analysis"
}

# Collecter toutes les métriques
collect_metrics() {
    local timestamp=$(date -Iseconds)
    local cpu_usage=$(get_cpu_stats)
    local memory_usage=$(get_memory_stats)
    local temperature=$(get_temperature)
    local disk_usage=$(get_disk_usage)
    local uptime_seconds=$(get_uptime)
    local services=$(check_services)
    local network=$(check_network)
    local system_info=$(get_system_info)
    local processes=$(check_pisignage_processes)
    local log_analysis=$(analyze_recent_logs)

    # Vérifier les seuils et générer des alertes
    check_thresholds "$cpu_usage" "$memory_usage" "$temperature" "$disk_usage"

    # Générer le JSON de statut
    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$timestamp",
    "version": "0.8.0",
    "metrics": {
        "cpu_usage": $cpu_usage,
        "memory_usage": $memory_usage,
        "temperature": $temperature,
        "disk_usage": $disk_usage,
        "uptime_seconds": $uptime_seconds
    },
    "services": $services,
    "network": $network,
    "system": $system_info,
    "processes": $processes,
    "logs": $log_analysis,
    "health_status": "$(determine_health_status "$cpu_usage" "$memory_usage" "$temperature" "$disk_usage")"
}
EOF

    log "Metrics collected - CPU: ${cpu_usage}%, MEM: ${memory_usage}%, TEMP: ${temperature}°C, DISK: ${disk_usage}%"
}

# Vérifier les seuils et alerter
check_thresholds() {
    local cpu="$1"
    local memory="$2"
    local temp="$3"
    local disk="$4"

    # Convertir en entiers pour la comparaison
    local cpu_int=$(echo "$cpu" | cut -d. -f1)
    local memory_int=$(echo "$memory" | cut -d. -f1)
    local temp_int=$(echo "$temp" | cut -d. -f1)

    if [[ $cpu_int -gt $CPU_THRESHOLD ]]; then
        alert "High CPU usage: ${cpu}% (threshold: ${CPU_THRESHOLD}%)"
    fi

    if [[ $memory_int -gt $MEMORY_THRESHOLD ]]; then
        alert "High memory usage: ${memory}% (threshold: ${MEMORY_THRESHOLD}%)"
    fi

    if [[ $temp_int -gt $TEMP_THRESHOLD ]]; then
        alert "High temperature: ${temp}°C (threshold: ${TEMP_THRESHOLD}°C)"
    fi

    if [[ $disk -gt $DISK_THRESHOLD ]]; then
        alert "High disk usage: ${disk}% (threshold: ${DISK_THRESHOLD}%)"
    fi
}

# Déterminer l'état de santé général
determine_health_status() {
    local cpu="$1"
    local memory="$2"
    local temp="$3"
    local disk="$4"

    local cpu_int=$(echo "$cpu" | cut -d. -f1)
    local memory_int=$(echo "$memory" | cut -d. -f1)
    local temp_int=$(echo "$temp" | cut -d. -f1)

    # Vérifier les conditions critiques
    if [[ $cpu_int -gt 90 || $memory_int -gt 95 || $temp_int -gt 80 || $disk -gt 95 ]]; then
        echo "critical"
    elif [[ $cpu_int -gt $CPU_THRESHOLD || $memory_int -gt $MEMORY_THRESHOLD || $temp_int -gt $TEMP_THRESHOLD || $disk -gt $DISK_THRESHOLD ]]; then
        echo "warning"
    else
        echo "healthy"
    fi
}

# Afficher les métriques en temps réel
show_realtime_metrics() {
    while true; do
        clear
        echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                PiSignage System Monitor                      ║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo

        local cpu=$(get_cpu_stats)
        local memory=$(get_memory_stats)
        local temp=$(get_temperature)
        local disk=$(get_disk_usage)
        local uptime=$(get_uptime)

        # Formatage uptime
        local days=$((uptime / 86400))
        local hours=$(((uptime % 86400) / 3600))
        local minutes=$(((uptime % 3600) / 60))

        echo -e "${GREEN}System Information:${NC}"
        echo -e "  Hostname: $(hostname)"
        echo -e "  Uptime: ${days}d ${hours}h ${minutes}m"
        echo

        echo -e "${GREEN}Resource Usage:${NC}"

        # CPU avec couleur
        if [[ $(echo "$cpu" | cut -d. -f1) -gt $CPU_THRESHOLD ]]; then
            echo -e "  CPU: ${RED}${cpu}%${NC}"
        else
            echo -e "  CPU: ${GREEN}${cpu}%${NC}"
        fi

        # Mémoire avec couleur
        if [[ $(echo "$memory" | cut -d. -f1) -gt $MEMORY_THRESHOLD ]]; then
            echo -e "  Memory: ${RED}${memory}%${NC}"
        else
            echo -e "  Memory: ${GREEN}${memory}%${NC}"
        fi

        # Température avec couleur
        if [[ $(echo "$temp" | cut -d. -f1) -gt $TEMP_THRESHOLD ]]; then
            echo -e "  Temperature: ${RED}${temp}°C${NC}"
        else
            echo -e "  Temperature: ${GREEN}${temp}°C${NC}"
        fi

        # Disque avec couleur
        if [[ $disk -gt $DISK_THRESHOLD ]]; then
            echo -e "  Disk: ${RED}${disk}%${NC}"
        else
            echo -e "  Disk: ${GREEN}${disk}%${NC}"
        fi

        echo

        echo -e "${GREEN}Services Status:${NC}"
        if systemctl is-active --quiet nginx; then
            echo -e "  Nginx: ${GREEN}Active${NC}"
        else
            echo -e "  Nginx: ${RED}Inactive${NC}"
        fi

        if systemctl is-active --quiet php7.4-fpm; then
            echo -e "  PHP-FPM: ${GREEN}Active${NC}"
        else
            echo -e "  PHP-FPM: ${RED}Inactive${NC}"
        fi

        if pgrep vlc >/dev/null; then
            echo -e "  VLC: ${GREEN}Running${NC}"
        else
            echo -e "  VLC: ${YELLOW}Stopped${NC}"
        fi

        echo
        echo -e "${BLUE}Press Ctrl+C to exit${NC}"

        sleep 5
    done
}

# Générer un rapport de santé
generate_health_report() {
    collect_metrics

    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                PiSignage Health Report                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo

    if [[ -f "$STATUS_FILE" ]]; then
        local health_status=$(jq -r '.health_status' "$STATUS_FILE" 2>/dev/null || echo "unknown")
        local cpu=$(jq -r '.metrics.cpu_usage' "$STATUS_FILE" 2>/dev/null || echo "0")
        local memory=$(jq -r '.metrics.memory_usage' "$STATUS_FILE" 2>/dev/null || echo "0")
        local temp=$(jq -r '.metrics.temperature' "$STATUS_FILE" 2>/dev/null || echo "0")
        local disk=$(jq -r '.metrics.disk_usage' "$STATUS_FILE" 2>/dev/null || echo "0")

        case "$health_status" in
            "healthy")
                echo -e "${GREEN}Overall Health: HEALTHY ✓${NC}"
                ;;
            "warning")
                echo -e "${YELLOW}Overall Health: WARNING ⚠${NC}"
                ;;
            "critical")
                echo -e "${RED}Overall Health: CRITICAL ✗${NC}"
                ;;
            *)
                echo -e "${BLUE}Overall Health: UNKNOWN${NC}"
                ;;
        esac

        echo
        echo -e "${GREEN}Current Metrics:${NC}"
        echo -e "  CPU Usage: $cpu%"
        echo -e "  Memory Usage: $memory%"
        echo -e "  Temperature: $temp°C"
        echo -e "  Disk Usage: $disk%"
        echo
        echo -e "${GREEN}Thresholds:${NC}"
        echo -e "  CPU: $CPU_THRESHOLD%"
        echo -e "  Memory: $MEMORY_THRESHOLD%"
        echo -e "  Temperature: $TEMP_THRESHOLD°C"
        echo -e "  Disk: $DISK_THRESHOLD%"
        echo

        # Vérifier les alertes récentes
        if [[ -f "$ALERT_FILE" ]]; then
            local recent_alerts=$(tail -10 "$ALERT_FILE" 2>/dev/null || echo "")
            if [[ -n "$recent_alerts" ]]; then
                echo -e "${YELLOW}Recent Alerts (last 10):${NC}"
                echo "$recent_alerts"
            else
                echo -e "${GREEN}No recent alerts${NC}"
            fi
        fi

        echo
        echo -e "Full status: ${YELLOW}$STATUS_FILE${NC}"
        echo -e "Alert log: ${YELLOW}$ALERT_FILE${NC}"
    else
        echo -e "${RED}No status file found. Run monitoring first.${NC}"
    fi
}

# Afficher l'aide
show_help() {
    cat << EOF
PiSignage v0.8.0 System Monitor

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  monitor        Collect metrics once and exit
  watch          Show real-time metrics (refresh every 5s)
  report         Generate and display health report
  daemon         Run as background daemon (collect every minute)
  stop-daemon    Stop the monitoring daemon
  configure      Configure monitoring thresholds

Options:
  --cpu-threshold NUM     CPU usage threshold (default: $CPU_THRESHOLD%)
  --memory-threshold NUM  Memory usage threshold (default: $MEMORY_THRESHOLD%)
  --temp-threshold NUM    Temperature threshold (default: $TEMP_THRESHOLD°C)
  --disk-threshold NUM    Disk usage threshold (default: $DISK_THRESHOLD%)
  -h, --help             Show this help

Examples:
  $0 monitor                    # Collect metrics once
  $0 watch                      # Real-time monitoring
  $0 report                     # Show health report
  $0 daemon                     # Start background monitoring
  $0 --cpu-threshold 90 monitor # Use custom CPU threshold

Files:
  Status: $STATUS_FILE
  Alerts: $ALERT_FILE
  Logs: $LOG_FILE

EOF
}

# Fonction daemon
run_daemon() {
    local pid_file="/var/run/pisignage-monitor.pid"

    # Vérifier si le daemon est déjà en cours
    if [[ -f "$pid_file" ]]; then
        local existing_pid=$(cat "$pid_file")
        if kill -0 "$existing_pid" 2>/dev/null; then
            echo "Monitor daemon is already running (PID: $existing_pid)"
            exit 1
        else
            rm -f "$pid_file"
        fi
    fi

    # Démarrer le daemon
    echo $$ > "$pid_file"
    log "System monitor daemon started (PID: $$)"

    # Boucle principale du daemon
    while true; do
        collect_metrics
        sleep 60  # Collecter toutes les minutes
    done
}

# Arrêter le daemon
stop_daemon() {
    local pid_file="/var/run/pisignage-monitor.pid"

    if [[ -f "$pid_file" ]]; then
        local daemon_pid=$(cat "$pid_file")
        if kill -0 "$daemon_pid" 2>/dev/null; then
            kill "$daemon_pid"
            rm -f "$pid_file"
            echo "Monitor daemon stopped (PID: $daemon_pid)"
        else
            echo "Monitor daemon is not running"
            rm -f "$pid_file"
        fi
    else
        echo "Monitor daemon is not running"
    fi
}

# Traitement des arguments
main() {
    # Vérifier les dépendances
    if ! command -v bc >/dev/null 2>&1; then
        echo "Warning: 'bc' is not installed. Some calculations may not work properly."
    fi

    # Traitement des options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cpu-threshold)
                CPU_THRESHOLD="$2"
                shift 2
                ;;
            --memory-threshold)
                MEMORY_THRESHOLD="$2"
                shift 2
                ;;
            --temp-threshold)
                TEMP_THRESHOLD="$2"
                shift 2
                ;;
            --disk-threshold)
                DISK_THRESHOLD="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            monitor)
                collect_metrics
                echo "Metrics collected successfully"
                exit 0
                ;;
            watch)
                show_realtime_metrics
                exit 0
                ;;
            report)
                generate_health_report
                exit 0
                ;;
            daemon)
                run_daemon
                exit 0
                ;;
            stop-daemon)
                stop_daemon
                exit 0
                ;;
            configure)
                echo "Current thresholds:"
                echo "  CPU: $CPU_THRESHOLD%"
                echo "  Memory: $MEMORY_THRESHOLD%"
                echo "  Temperature: $TEMP_THRESHOLD°C"
                echo "  Disk: $DISK_THRESHOLD%"
                echo
                echo "Use --cpu-threshold, --memory-threshold, --temp-threshold, --disk-threshold to modify"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Si aucune commande n'est spécifiée, collecter les métriques une fois
    collect_metrics
    echo "Metrics collected. Use '$0 report' to see the health report."
}

# Gestion des signaux pour le daemon
trap 'log "Monitor daemon stopping..."; exit 0' SIGTERM SIGINT

# Exécution
main "$@"