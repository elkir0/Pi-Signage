#!/bin/bash
#
# PiSignage Desktop v3.0 - Web Service Control Script
# Copyright (c) 2024 PiSignage
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PISIGNAGE_HOME="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_FILE="${PISIGNAGE_HOME}/config/default.conf"
LOG_FILE="${PISIGNAGE_HOME}/logs/web-service.log"

# Load configuration
source "${CONFIG_FILE}"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to check web service health
check_health() {
    if curl -s http://localhost:${WEB_PORT}/api/health > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Main service loop
main() {
    log "Starting PiSignage Web Service"
    
    while true; do
        # Check if nginx is running
        if ! systemctl is-active --quiet nginx; then
            log "Nginx is not running, attempting to start"
            systemctl start nginx
        fi
        
        # Check if PHP-FPM is running
        if ! systemctl is-active --quiet php8.2-fpm; then
            log "PHP-FPM is not running, attempting to start"
            systemctl start php8.2-fpm
        fi
        
        # Health check
        if ! check_health; then
            log "Web service health check failed"
        fi
        
        sleep 30
    done
}

# Start the service monitor
main