#!/bin/bash

# PiSignage v0.8.0 - Script d'arrêt principal
# Arrêt propre de tous les composants
# Auteur: Claude Code
# Date: 22/09/2025

set -e

# Variables
LOG_DIR="/opt/pisignage/logs"
PID_FILE="/tmp/pisignage.pid"
LOG_FILE="$LOG_DIR/pisignage.log"

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Arrêt de VLC
stop_vlc() {
    log "Arrêt de VLC..."

    # Via script de contrôle
    if [ -x "/opt/pisignage/scripts/vlc-control.sh" ]; then
        "/opt/pisignage/scripts/vlc-control.sh" stop
    fi

    # Nettoyage des processus VLC restants
    for pid_file in "/tmp/vlc-pisignage.pid" "/tmp/vlc-playlist.pid"; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                log "Arrêt VLC PID: $pid"
                kill "$pid" 2>/dev/null || true
                sleep 2
                if kill -0 "$pid" 2>/dev/null; then
                    kill -9 "$pid" 2>/dev/null || true
                fi
            fi
            rm -f "$pid_file"
        fi
    done

    # Force kill de tous les processus VLC
    pkill -f vlc 2>/dev/null || true

    log "✅ VLC arrêté"
}

# Arrêt de feh (si utilisé pour images)
stop_feh() {
    if [ -f "/tmp/feh-pisignage.pid" ]; then
        local pid=$(cat "/tmp/feh-pisignage.pid")
        if kill -0 "$pid" 2>/dev/null; then
            log "Arrêt feh PID: $pid"
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "/tmp/feh-pisignage.pid"
    fi

    pkill -f feh 2>/dev/null || true
    log "✅ feh arrêté"
}

# Arrêt du monitoring
stop_monitoring() {
    if [ -f "/tmp/pisignage-monitor.pid" ]; then
        local pid=$(cat "/tmp/pisignage-monitor.pid")
        if kill -0 "$pid" 2>/dev/null; then
            log "Arrêt monitoring PID: $pid"
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "/tmp/pisignage-monitor.pid"
    fi

    log "✅ Monitoring arrêté"
}

# Arrêt d'unclutter (curseur masqué)
stop_unclutter() {
    pkill -f unclutter 2>/dev/null || true
    log "✅ unclutter arrêté"
}

# Nettoyage des fichiers temporaires
cleanup_temp_files() {
    log "Nettoyage des fichiers temporaires..."

    # Suppression des PID files
    rm -f "/tmp/vlc-pisignage.pid"
    rm -f "/tmp/vlc-playlist.pid"
    rm -f "/tmp/feh-pisignage.pid"
    rm -f "/tmp/pisignage-monitor.pid"
    rm -f "$PID_FILE"

    # Nettoyage des sockets temporaires
    rm -f "/tmp/.pisignage-*" 2>/dev/null || true

    log "✅ Fichiers temporaires nettoyés"
}

# Réactivation de l'économiseur d'écran
restore_display() {
    log "Restauration des paramètres d'affichage..."

    if [ -n "$DISPLAY" ] && xset q &>/dev/null; then
        # Réactiver l'économiseur d'écran
        xset s on
        xset +dpms
        log "✅ Économiseur d'écran réactivé"
    fi
}

# Fonction principale
main() {
    log "🛑 Arrêt de PiSignage v0.8.0..."

    stop_vlc
    stop_feh
    stop_monitoring
    stop_unclutter
    restore_display
    cleanup_temp_files

    log "✅ PiSignage v0.8.0 arrêté avec succès"
}

# Exécution
main "$@"