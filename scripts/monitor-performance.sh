#!/bin/bash

# =============================================================================
# PiSignage - Script de monitoring performance pour optimisation GPU
# =============================================================================
# Version: 1.0.0
# Date: 22/09/2025
# Objectif: Monitoring FPS, CPU, température et GPU en temps réel
# =============================================================================

set -euo pipefail

# Configuration
PISIGNAGE_DIR="/opt/pisignage"
LOG_DIR="$PISIGNAGE_DIR/logs"
MONITOR_LOG="$LOG_DIR/performance-monitor.log"
ALERT_LOG="$LOG_DIR/performance-alerts.log"
PID_FILE="/tmp/pisignage-monitor.pid"
REPORT_FILE="$LOG_DIR/performance-report.html"

# Seuils d'alerte
CPU_THRESHOLD=85
TEMP_THRESHOLD=78
FPS_MIN_THRESHOLD=25
MEMORY_THRESHOLD=80

# Configuration monitoring
INTERVAL=5
SAMPLES_PER_REPORT=12  # 1 minute à 5s d'intervalle
MAX_LOG_LINES=1000

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $timestamp - $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $timestamp - $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $timestamp - $message" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $timestamp - $message" ;;
        "ALERT") echo -e "${RED}[ALERT]${NC} $timestamp - $message" ;;
        *) echo "$timestamp - $message" ;;
    esac

    echo "$timestamp [$level] $message" >> "$MONITOR_LOG"
}

# =============================================================================
# FONCTIONS DE COLLECTE MÉTRIQUES
# =============================================================================

get_cpu_usage() {
    # CPU global
    local cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | sed 's/%id,//')
    if [ -n "$cpu_idle" ]; then
        echo "scale=1; 100 - $cpu_idle" | bc
    else
        echo "0"
    fi
}

get_chromium_cpu() {
    # CPU spécifique à Chromium
    local chromium_cpu=$(ps aux | grep "[c]hromium.*pisignage" | awk '{cpu+=$3} END {printf "%.1f", cpu}')
    echo "${chromium_cpu:-0}"
}

get_memory_usage() {
    # Mémoire globale
    local mem_info=$(free | grep "Mem:")
    local total=$(echo $mem_info | awk '{print $2}')
    local used=$(echo $mem_info | awk '{print $3}')
    echo "scale=1; $used * 100 / $total" | bc
}

get_chromium_memory() {
    # Mémoire Chromium en MB
    local chromium_mem=$(ps aux | grep "[c]hromium.*pisignage" | awk '{mem+=$6} END {printf "%.0f", mem/1024}')
    echo "${chromium_mem:-0}"
}

get_gpu_memory() {
    # Mémoire GPU
    local gpu_mem=$(vcgencmd get_mem gpu | cut -d= -f2 | sed 's/M//')
    echo "$gpu_mem"
}

get_temperature() {
    # Température CPU
    local temp=$(vcgencmd measure_temp | cut -d= -f2 | sed 's/°C//')
    echo "$temp"
}

get_throttling_status() {
    # État du throttling
    local throttled=$(vcgencmd get_throttled | cut -d= -f2)
    if [ "$throttled" = "0x0" ]; then
        echo "OK"
    else
        echo "THROTTLED:$throttled"
    fi
}

get_gpu_usage() {
    # Fréquence GPU actuelle
    local gpu_freq=$(vcgencmd measure_clock gpu | cut -d= -f2)
    echo "scale=0; $gpu_freq / 1000000" | bc
}

estimate_fps() {
    # Estimation FPS via monitoring processus
    local chromium_pid=$(pgrep -f "chromium.*pisignage" | head -1)
    if [ -n "$chromium_pid" ]; then
        # Méthode approximative: basée sur l'activité CPU
        local cpu_usage=$(ps -p "$chromium_pid" -o %cpu= | xargs)
        if (( $(echo "$cpu_usage > 10" | bc -l) )); then
            # Si CPU > 10%, probablement en lecture
            echo "~30"
        else
            echo "~0"
        fi
    else
        echo "N/A"
    fi
}

get_network_usage() {
    # Usage réseau (si streaming)
    local rx_bytes=$(cat /proc/net/dev | grep wlan0 | awk '{print $2}' || echo "0")
    local tx_bytes=$(cat /proc/net/dev | grep wlan0 | awk '{print $10}' || echo "0")
    echo "$rx_bytes,$tx_bytes"
}

# =============================================================================
# FONCTIONS D'ALERTE
# =============================================================================

check_alerts() {
    local cpu=$1
    local temp=$2
    local fps=$3
    local memory=$4
    local throttled=$5

    local alerts=""

    # CPU élevé
    if (( $(echo "$cpu > $CPU_THRESHOLD" | bc -l) )); then
        alerts="$alerts CPU_HIGH:${cpu}% "
        log "ALERT" "CPU élevé: ${cpu}% (seuil: ${CPU_THRESHOLD}%)"
    fi

    # Température élevée
    if (( $(echo "$temp > $TEMP_THRESHOLD" | bc -l) )); then
        alerts="$alerts TEMP_HIGH:${temp}°C "
        log "ALERT" "Température élevée: ${temp}°C (seuil: ${TEMP_THRESHOLD}°C)"
    fi

    # FPS faible
    if [[ "$fps" =~ ^[0-9]+$ ]] && [ "$fps" -lt "$FPS_MIN_THRESHOLD" ]; then
        alerts="$alerts FPS_LOW:${fps} "
        log "ALERT" "FPS faible: ${fps} (seuil: ${FPS_MIN_THRESHOLD})"
    fi

    # Mémoire élevée
    if (( $(echo "$memory > $MEMORY_THRESHOLD" | bc -l) )); then
        alerts="$alerts MEM_HIGH:${memory}% "
        log "ALERT" "Mémoire élevée: ${memory}% (seuil: ${MEMORY_THRESHOLD}%)"
    fi

    # Throttling
    if [ "$throttled" != "OK" ]; then
        alerts="$alerts THROTTLING "
        log "ALERT" "Throttling détecté: $throttled"
    fi

    echo "${alerts:-OK}"
}

# =============================================================================
# GÉNÉRATION RAPPORTS
# =============================================================================

generate_html_report() {
    local data_file="$1"

    cat > "$REPORT_FILE" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>PiSignage - Performance Monitor</title>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="30">
    <style>
        body { font-family: monospace; background: #1a1a1a; color: #00ff00; margin: 20px; }
        .header { text-align: center; color: #00ffff; margin-bottom: 20px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .metric-box { border: 1px solid #333; padding: 15px; background: #2a2a2a; }
        .metric-title { color: #ffff00; font-weight: bold; margin-bottom: 10px; }
        .metric-value { font-size: 1.2em; margin: 5px 0; }
        .alert { color: #ff4444; font-weight: bold; }
        .ok { color: #44ff44; }
        .warn { color: #ffaa44; }
        .chart { width: 100%; height: 200px; border: 1px solid #333; margin: 10px 0; }
        .status-bar { position: fixed; bottom: 0; left: 0; right: 0; background: #333; padding: 10px; text-align: center; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎯 PiSignage Performance Monitor</h1>
        <p>Raspberry Pi 4 - Chromium GPU Acceleration</p>
        <p id="timestamp">Dernière mise à jour: TIMESTAMP_PLACEHOLDER</p>
    </div>

    <div class="metrics">
        <div class="metric-box">
            <div class="metric-title">🔥 CPU & Température</div>
            <div class="metric-value">CPU Global: <span id="cpu-global">CPU_GLOBAL%</span></div>
            <div class="metric-value">CPU Chromium: <span id="cpu-chromium">CPU_CHROMIUM%</span></div>
            <div class="metric-value">Température: <span id="temperature">TEMPERATURE°C</span></div>
            <div class="metric-value">Throttling: <span id="throttling">THROTTLING_STATUS</span></div>
        </div>

        <div class="metric-box">
            <div class="metric-title">🧠 Mémoire</div>
            <div class="metric-value">RAM Usage: <span id="memory-usage">MEMORY_USAGE%</span></div>
            <div class="metric-value">Chromium RAM: <span id="chromium-memory">CHROMIUM_MEMORY MB</span></div>
            <div class="metric-value">GPU Memory: <span id="gpu-memory">GPU_MEMORY MB</span></div>
        </div>

        <div class="metric-box">
            <div class="metric-title">🎮 GPU & Vidéo</div>
            <div class="metric-value">GPU Freq: <span id="gpu-freq">GPU_FREQ MHz</span></div>
            <div class="metric-value">FPS Estimé: <span id="fps-estimate">FPS_ESTIMATE</span></div>
            <div class="metric-value">Résolution: <span id="resolution">1920x1080</span></div>
        </div>

        <div class="metric-box">
            <div class="metric-title">⚠️ Alertes</div>
            <div class="metric-value" id="alerts">ALERTS_PLACEHOLDER</div>
        </div>
    </div>

    <div class="status-bar">
        Status: <span id="overall-status">OVERALL_STATUS</span> |
        Uptime: <span id="uptime">UPTIME_PLACEHOLDER</span> |
        Surveillance active depuis MONITOR_START
    </div>

    <script>
        // Auto-refresh des métriques
        function refreshMetrics() {
            fetch('/api/performance')
                .then(response => response.json())
                .then(data => {
                    // Mise à jour des valeurs
                    document.getElementById('timestamp').textContent = 'Dernière mise à jour: ' + new Date().toLocaleString();
                })
                .catch(console.error);
        }

        // Refresh toutes les 5 secondes
        setInterval(refreshMetrics, 5000);

        // Couleurs dynamiques
        function updateColors() {
            const temp = parseFloat(document.getElementById('temperature').textContent);
            const cpu = parseFloat(document.getElementById('cpu-global').textContent);

            if (temp > 75) document.getElementById('temperature').className = 'alert';
            else if (temp > 65) document.getElementById('temperature').className = 'warn';
            else document.getElementById('temperature').className = 'ok';

            if (cpu > 80) document.getElementById('cpu-global').className = 'alert';
            else if (cpu > 60) document.getElementById('cpu-global').className = 'warn';
            else document.getElementById('cpu-global').className = 'ok';
        }

        updateColors();
    </script>
</body>
</html>
EOF

    # Remplacer les placeholders avec les données actuelles
    if [ -f "$data_file" ]; then
        local last_line=$(tail -1 "$data_file")
        # Parser et remplacer...
        sed -i "s/TIMESTAMP_PLACEHOLDER/$(date)/" "$REPORT_FILE"
        sed -i "s/MONITOR_START/$(date)/" "$REPORT_FILE"
    fi

    log "INFO" "Rapport HTML généré: $REPORT_FILE"
}

# =============================================================================
# BOUCLE PRINCIPALE DE MONITORING
# =============================================================================

start_monitoring() {
    log "INFO" "Démarrage du monitoring performance..."

    local data_file="$LOG_DIR/performance-data.csv"
    local sample_count=0

    # Créer le fichier CSV avec headers
    echo "timestamp,cpu_global,cpu_chromium,memory_usage,chromium_memory,gpu_memory,temperature,throttling,gpu_freq,fps_estimate,alerts" > "$data_file"

    while true; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        # Collecter toutes les métriques
        local cpu_global=$(get_cpu_usage)
        local cpu_chromium=$(get_chromium_cpu)
        local memory_usage=$(get_memory_usage)
        local chromium_memory=$(get_chromium_memory)
        local gpu_memory=$(get_gpu_memory)
        local temperature=$(get_temperature)
        local throttling=$(get_throttling_status)
        local gpu_freq=$(get_gpu_usage)
        local fps_estimate=$(estimate_fps)

        # Vérifier les alertes
        local alerts=$(check_alerts "$cpu_global" "$temperature" "${fps_estimate//~}" "$memory_usage" "$throttling")

        # Enregistrer dans le CSV
        echo "$timestamp,$cpu_global,$cpu_chromium,$memory_usage,$chromium_memory,$gpu_memory,$temperature,$throttling,$gpu_freq,$fps_estimate,$alerts" >> "$data_file"

        # Affichage console avec couleurs
        printf "${CYAN}[%s]${NC} " "$timestamp"
        printf "CPU: ${GREEN}%.1f%%${NC} " "$cpu_global"
        printf "Temp: ${YELLOW}%.1f°C${NC} " "$temperature"
        printf "FPS: ${BLUE}%s${NC} " "$fps_estimate"
        printf "GPU: ${GREEN}%sMHz${NC} " "$gpu_freq"
        printf "Alerts: "
        if [ "$alerts" = "OK" ]; then
            printf "${GREEN}%s${NC}\n" "$alerts"
        else
            printf "${RED}%s${NC}\n" "$alerts"
        fi

        # Générer rapport HTML périodiquement
        ((sample_count++))
        if [ $((sample_count % SAMPLES_PER_REPORT)) -eq 0 ]; then
            generate_html_report "$data_file"
        fi

        # Limiter la taille du log
        if [ $(wc -l < "$data_file") -gt $MAX_LOG_LINES ]; then
            tail -$((MAX_LOG_LINES / 2)) "$data_file" > "$data_file.tmp"
            mv "$data_file.tmp" "$data_file"
        fi

        sleep $INTERVAL
    done
}

# =============================================================================
# FONCTIONS DE CONTRÔLE
# =============================================================================

stop_monitoring() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "INFO" "Arrêt du monitoring (PID: $pid)"
            kill -TERM "$pid"
            rm -f "$PID_FILE"
        else
            log "WARN" "PID obsolète trouvé: $pid"
            rm -f "$PID_FILE"
        fi
    else
        log "INFO" "Aucun monitoring en cours"
    fi
}

show_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "INFO" "Monitoring actif (PID: $pid)"
            if [ -f "$LOG_DIR/performance-data.csv" ]; then
                log "INFO" "Dernières métriques:"
                tail -3 "$LOG_DIR/performance-data.csv" | while IFS=, read timestamp cpu_global cpu_chromium memory_usage chromium_memory gpu_memory temperature throttling gpu_freq fps_estimate alerts; do
                    echo "  $timestamp - CPU:${cpu_global}% Temp:${temperature}°C FPS:${fps_estimate} Alerts:${alerts}"
                done
            fi
        else
            log "WARN" "PID obsolète: $pid"
            rm -f "$PID_FILE"
        fi
    else
        log "INFO" "Monitoring inactif"
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Monitoring performance temps réel pour PiSignage

OPTIONS:
    -h, --help          Afficher cette aide
    -s, --start         Démarrer le monitoring (daemon)
    -k, --stop          Arrêter le monitoring
    -t, --status        Afficher le statut
    -r, --report        Générer rapport HTML
    -d, --debug         Mode debug

EXEMPLES:
    $0 --start          Démarrer le monitoring
    $0 --status         Voir le statut actuel
    $0 --stop           Arrêter le monitoring

FICHIERS:
    Data: $LOG_DIR/performance-data.csv
    Logs: $MONITOR_LOG
    Report: $REPORT_FILE
EOF
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    local action="start"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--start)
                action="start"
                shift
                ;;
            -k|--stop)
                action="stop"
                shift
                ;;
            -t|--status)
                action="status"
                shift
                ;;
            -r|--report)
                action="report"
                shift
                ;;
            -d|--debug)
                set -x
                shift
                ;;
            *)
                log "ERROR" "Option inconnue: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Créer les répertoires
    mkdir -p "$LOG_DIR"

    case $action in
        "start")
            if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
                log "ERROR" "Monitoring déjà en cours"
                exit 1
            fi

            echo $$ > "$PID_FILE"
            trap 'rm -f "$PID_FILE"; exit' SIGINT SIGTERM
            start_monitoring
            ;;
        "stop")
            stop_monitoring
            ;;
        "status")
            show_status
            ;;
        "report")
            generate_html_report "$LOG_DIR/performance-data.csv"
            ;;
        *)
            log "ERROR" "Action inconnue: $action"
            exit 1
            ;;
    esac
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi