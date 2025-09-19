#!/bin/bash

# Script de monitoring du système PiSignage
# Version: 1.0

LOG_FILE="/opt/pisignage/logs/monitor.log"
CONFIG_FILE="/opt/pisignage/config/pisignage.conf"

# Fonction de logging
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Vérification de l'état du système
check_system_health() {
    log_message "=== Vérification de l'état du système ==="
    
    # Utilisation CPU
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    log_message "Utilisation CPU: ${cpu_usage}%"
    
    # Utilisation mémoire
    memory_info=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    log_message "Utilisation mémoire: $memory_info"
    
    # Espace disque
    disk_usage=$(df -h /opt/pisignage | awk 'NR==2 {print $5}')
    log_message "Utilisation disque: $disk_usage"
    
    # Température (si disponible)
    if command -v vcgencmd &> /dev/null; then
        temp=$(vcgencmd measure_temp | awk -F= '{print $2}')
        log_message "Température: $temp"
    fi
}

# Vérification des services
check_services() {
    log_message "=== Vérification des services ==="
    
    services=("nginx" "pisignage")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_message "Service $service: ACTIF"
        else
            log_message "Service $service: INACTIF"
        fi
    done
}

# Vérification des processus de lecture
check_media_processes() {
    log_message "=== Vérification des processus multimédia ==="
    
    processes=("omxplayer" "vlc" "mpv" "feh" "chromium")
    
    for process in "${processes[@]}"; do
        if pgrep -x "$process" > /dev/null; then
            log_message "Processus $process: ACTIF"
        else
            log_message "Processus $process: INACTIF"
        fi
    done
}

# Vérification de l'espace disque des médias
check_media_space() {
    log_message "=== Vérification de l'espace médias ==="
    
    media_dir="/opt/pisignage/media"
    if [ -d "$media_dir" ]; then
        file_count=$(find "$media_dir" -type f | wc -l)
        total_size=$(du -sh "$media_dir" | awk '{print $1}')
        log_message "Fichiers médias: $file_count fichiers ($total_size)"
    else
        log_message "Répertoire médias introuvable"
    fi
}

# Nettoyage des logs anciens
cleanup_logs() {
    log_message "=== Nettoyage des logs ==="
    
    log_dir="/opt/pisignage/logs"
    if [ -d "$log_dir" ]; then
        # Suppression des logs de plus de 30 jours
        find "$log_dir" -name "*.log" -mtime +30 -delete
        log_message "Nettoyage des logs terminé"
    fi
}

# Menu principal
case "$1" in
    health)
        check_system_health
        ;;
    services)
        check_services
        ;;
    media)
        check_media_processes
        check_media_space
        ;;
    cleanup)
        cleanup_logs
        ;;
    all|*)
        check_system_health
        check_services
        check_media_processes
        check_media_space
        ;;
esac

log_message "=== Monitoring terminé ===
"