#!/bin/bash

# ===========================================
# MONITOR FPS TEMPS RÉEL - RASPBERRY PI 4
# ===========================================
# Script de monitoring FPS en temps réel pour Chromium
# Version: 1.0.0
# Date: 2025-09-22
# Méthodes: GPU stats, frame counting, performance analysis

set -e

# Configuration
MONITOR_DURATION=${1:-300}  # Durée en secondes (5 min par défaut)
LOG_FILE="/var/log/pisignage/fps-monitoring.log"
STATS_FILE="/var/log/pisignage/fps-stats.json"
ALERT_THRESHOLD=${2:-30}   # Seuil FPS pour alerte

# Créer dossiers si nécessaires
mkdir -p /var/log/pisignage

# Fonction de logging avec timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction pour capturer stats GPU détaillées
get_gpu_stats() {
    local timestamp=$(date '+%s')
    local temp=$(vcgencmd measure_temp | cut -d= -f2 | sed 's/°C//')
    local gpu_mem=$(vcgencmd get_mem gpu | cut -d= -f2 | sed 's/M//')
    local arm_freq=$(vcgencmd measure_clock arm | cut -d= -f2)
    local gpu_freq=$(vcgencmd measure_clock gpu | cut -d= -f2)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

    echo "$timestamp,$temp,$gpu_mem,$arm_freq,$gpu_freq,$cpu_usage"
}

# Fonction pour mesurer FPS via analyse des logs Chromium
measure_fps_chromium() {
    local chromium_pid=$(pgrep -f chromium-browser | head -1)
    if [ -z "$chromium_pid" ]; then
        echo "0"
        return
    fi

    # Méthode 1: Analyse des messages frame dans les logs
    local fps_estimate=0
    local log_fps=$(tail -n 100 /var/log/pisignage/chromium-performance.log.stdout 2>/dev/null | \
                   grep -c "frame\|render\|paint" 2>/dev/null || echo "0")

    if [ "$log_fps" -gt 0 ]; then
        fps_estimate=$((log_fps / 2))  # Estimation approximative
    fi

    echo "$fps_estimate"
}

# Fonction pour mesurer FPS via analyse GPU
measure_fps_gpu() {
    # Compteur de frames GPU via statistiques V3D
    local gpu_frames_before=0
    local gpu_frames_after=0

    # Lecture stats GPU si disponibles
    if [ -f /sys/kernel/debug/dri/0/v3d_perf ]; then
        gpu_frames_before=$(cat /sys/kernel/debug/dri/0/v3d_perf 2>/dev/null | grep -E "(frame|render)" | wc -l || echo "0")
        sleep 1
        gpu_frames_after=$(cat /sys/kernel/debug/dri/0/v3d_perf 2>/dev/null | grep -E "(frame|render)" | wc -l || echo "0")
        echo $((gpu_frames_after - gpu_frames_before))
    else
        echo "0"
    fi
}

# Fonction pour analyser performance réseau/streaming
measure_network_performance() {
    local interface="eth0"  # ou wlan0 pour WiFi
    local rx_before=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo "0")
    sleep 1
    local rx_after=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo "0")
    local bandwidth=$((rx_after - rx_before))
    echo "$bandwidth"
}

# Fonction pour détecter frame drops
detect_frame_drops() {
    local chromium_pid=$(pgrep -f chromium-browser | head -1)
    if [ -z "$chromium_pid" ]; then
        echo "0"
        return
    fi

    # Analyse mémoire GPU pour détecter les frame drops
    local gpu_mem_free=$(vcgencmd get_mem gpu | cut -d= -f2 | sed 's/M//')
    local mem_pressure=0

    if [ "$gpu_mem_free" -lt 128 ]; then
        mem_pressure=1
    fi

    # Analyse CPU load pour frame drops
    local cpu_load=$(cat /proc/loadavg | cut -d' ' -f1)
    local cpu_pressure=0

    if (( $(echo "$cpu_load > 3.0" | bc -l) )); then
        cpu_pressure=1
    fi

    echo "$((mem_pressure + cpu_pressure))"
}

# Fonction pour estimation FPS via méthode hybride
estimate_fps_hybrid() {
    local fps_chromium=$(measure_fps_chromium)
    local fps_gpu=$(measure_fps_gpu)
    local frame_drops=$(detect_frame_drops)

    # Estimation combinée avec correction pour frame drops
    local estimated_fps=0

    if [ "$fps_chromium" -gt 0 ] || [ "$fps_gpu" -gt 0 ]; then
        estimated_fps=$(( (fps_chromium + fps_gpu) / 2 ))

        # Correction pour frame drops
        if [ "$frame_drops" -gt 0 ]; then
            estimated_fps=$((estimated_fps - (frame_drops * 5)))
        fi

        # Limiter entre 0 et 60
        if [ "$estimated_fps" -lt 0 ]; then
            estimated_fps=0
        elif [ "$estimated_fps" -gt 60 ]; then
            estimated_fps=60
        fi
    fi

    echo "$estimated_fps"
}

# Fonction pour générer rapport JSON détaillé
generate_performance_report() {
    local timestamp=$(date '+%s')
    local iso_timestamp=$(date -Iseconds)
    local fps="$1"
    local gpu_stats="$2"
    local network_bw="$3"
    local frame_drops="$4"

    # Parser GPU stats
    IFS=',' read -r ts temp gpu_mem arm_freq gpu_freq cpu_usage <<< "$gpu_stats"

    # Générer JSON
    cat > "$STATS_FILE" <<EOF
{
  "timestamp": $timestamp,
  "iso_timestamp": "$iso_timestamp",
  "performance": {
    "fps_estimated": $fps,
    "frame_drops": $frame_drops,
    "network_bandwidth_bps": $network_bw
  },
  "gpu": {
    "temperature_celsius": $temp,
    "memory_mb": $gpu_mem,
    "frequency_hz": $gpu_freq
  },
  "cpu": {
    "frequency_hz": $arm_freq,
    "usage_percent": $cpu_usage
  },
  "system": {
    "status": "$([ $fps -ge $ALERT_THRESHOLD ] && echo 'optimal' || echo 'degraded')",
    "alert_threshold": $ALERT_THRESHOLD,
    "monitoring_duration": $MONITOR_DURATION
  }
}
EOF
}

# Fonction principale de monitoring
start_monitoring() {
    log "=== DÉMARRAGE MONITORING FPS ==="
    log "Durée: ${MONITOR_DURATION}s | Seuil alerte: ${ALERT_THRESHOLD} FPS"

    local start_time=$(date '+%s')
    local end_time=$((start_time + MONITOR_DURATION))
    local sample_count=0
    local fps_total=0
    local fps_min=999
    local fps_max=0
    local alerts_count=0

    echo "timestamp,fps,temp,gpu_mem,arm_freq,gpu_freq,cpu_usage,network_bw,frame_drops" > "$LOG_FILE.csv"

    while [ $(date '+%s') -lt $end_time ]; do
        # Collecte des métriques
        local fps=$(estimate_fps_hybrid)
        local gpu_stats=$(get_gpu_stats)
        local network_bw=$(measure_network_performance)
        local frame_drops=$(detect_frame_drops)

        # Statistiques FPS
        fps_total=$((fps_total + fps))
        sample_count=$((sample_count + 1))

        if [ "$fps" -lt "$fps_min" ]; then
            fps_min=$fps
        fi

        if [ "$fps" -gt "$fps_max" ]; then
            fps_max=$fps
        fi

        # Alerte si FPS faible
        if [ "$fps" -lt "$ALERT_THRESHOLD" ]; then
            alerts_count=$((alerts_count + 1))
            log "⚠️  ALERTE FPS: $fps FPS (< $ALERT_THRESHOLD)"
        fi

        # Log détaillé
        local timestamp=$(date '+%s')
        echo "$timestamp,$fps,$gpu_stats,$network_bw,$frame_drops" >> "$LOG_FILE.csv"

        # Affichage temps réel
        printf "\r[%3ds] FPS: %2d | Temp: %s | GPU: %s | Alerts: %d" \
               $(($(date '+%s') - start_time)) "$fps" \
               "$(echo $gpu_stats | cut -d, -f2)°C" \
               "$(echo $gpu_stats | cut -d, -f3)MB" \
               "$alerts_count"

        # Générer rapport JSON périodiquement
        if [ $((sample_count % 10)) -eq 0 ]; then
            generate_performance_report "$fps" "$gpu_stats" "$network_bw" "$frame_drops"
        fi

        sleep 2
    done

    echo ""  # Nouvelle ligne après monitoring

    # Calcul moyennes finales
    local fps_avg=$((fps_total / sample_count))

    log "=== RÉSULTATS MONITORING FPS ==="
    log "Échantillons: $sample_count"
    log "FPS Moyen: $fps_avg"
    log "FPS Min: $fps_min"
    log "FPS Max: $fps_max"
    log "Alertes: $alerts_count"
    log "Taux alertes: $(( (alerts_count * 100) / sample_count ))%"

    # Génération rapport final
    generate_performance_report "$fps_avg" "$(get_gpu_stats)" \
                               "$(measure_network_performance)" \
                               "$(detect_frame_drops)"

    # Évaluation performance globale
    if [ "$fps_avg" -ge 50 ]; then
        log "✅ PERFORMANCE EXCELLENTE (>= 50 FPS)"
    elif [ "$fps_avg" -ge 30 ]; then
        log "⚠️  PERFORMANCE ACCEPTABLE (30-49 FPS)"
    else
        log "❌ PERFORMANCE INSUFFISANTE (< 30 FPS)"
    fi

    log "Fichiers générés:"
    log "- Logs: $LOG_FILE"
    log "- CSV: $LOG_FILE.csv"
    log "- Stats JSON: $STATS_FILE"
}

# Fonction d'affichage aide
show_help() {
    cat <<EOF
MONITOR FPS - Raspberry Pi 4 Performance Analysis

Usage: $0 [DURÉE] [SEUIL_FPS]

Arguments:
  DURÉE      Durée du monitoring en secondes (défaut: 300)
  SEUIL_FPS  Seuil FPS pour alertes (défaut: 30)

Exemples:
  $0                    # Monitoring 5 minutes, alerte < 30 FPS
  $0 600 25            # Monitoring 10 minutes, alerte < 25 FPS
  $0 60 45             # Monitoring 1 minute, alerte < 45 FPS

Fichiers de sortie:
  $LOG_FILE           # Logs détaillés
  $LOG_FILE.csv       # Données CSV
  $STATS_FILE         # Rapport JSON

Métriques analysées:
  - FPS estimé (hybride GPU + Chromium)
  - Température GPU
  - Fréquences ARM/GPU
  - Utilisation CPU
  - Bande passante réseau
  - Frame drops détectés
EOF
}

# ===========================================
# SCRIPT PRINCIPAL
# ===========================================

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        start_monitoring
        ;;
esac