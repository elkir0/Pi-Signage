#!/bin/bash

# PiSignage v0.8.0 - Script de rechargement
# Rechargement à chaud sans redémarrage complet
# Auteur: Claude Code
# Date: 22/09/2025

set -e

# Variables
PISIGNAGE_DIR="/opt/pisignage"
MEDIA_DIR="$PISIGNAGE_DIR/media"
LOG_DIR="$PISIGNAGE_DIR/logs"
SCRIPTS_DIR="$PISIGNAGE_DIR/scripts"
LOG_FILE="$LOG_DIR/pisignage.log"

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Rechargement de la configuration
reload_config() {
    log "Rechargement de la configuration..."

    # Recharger les services web si nécessaire
    if systemctl is-active --quiet nginx; then
        sudo systemctl reload nginx 2>/dev/null || true
        log "✅ Nginx rechargé"
    fi

    if systemctl is-active --quiet php8.2-fpm; then
        sudo systemctl reload php8.2-fpm 2>/dev/null || true
        log "✅ PHP-FPM rechargé"
    fi
}

# Rechargement des médias
reload_media() {
    log "Rechargement des médias..."

    local playlist_file="$MEDIA_DIR/playlists/current.m3u"
    local current_media=""

    # Déterminer le nouveau média à lire
    if [ -f "$playlist_file" ] && [ -s "$playlist_file" ]; then
        current_media="$playlist_file"
        log "Nouvelle playlist détectée: $playlist_file"
    elif [ -f "$MEDIA_DIR/default.mp4" ]; then
        current_media="$MEDIA_DIR/default.mp4"
        log "Utilisation de la vidéo par défaut"
    else
        log "Aucun média trouvé, conservation du média actuel"
        return 0
    fi

    # Redémarrer VLC avec le nouveau média
    if [ -x "$SCRIPTS_DIR/vlc-control.sh" ]; then
        "$SCRIPTS_DIR/vlc-control.sh" restart "$current_media"
        log "✅ VLC redémarré avec nouveau média"
    else
        log "ERROR: Script vlc-control.sh non trouvé"
        return 1
    fi
}

# Rechargement des scripts
reload_scripts() {
    log "Rechargement des scripts..."

    # Recharger les permissions des scripts
    if [ -d "$SCRIPTS_DIR" ]; then
        chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true
        log "✅ Permissions des scripts mises à jour"
    fi

    # Relancer le monitoring si nécessaire
    if [ ! -f "/tmp/pisignage-monitor.pid" ] || ! kill -0 "$(cat /tmp/pisignage-monitor.pid 2>/dev/null)" 2>/dev/null; then
        log "Redémarrage du monitoring..."

        # Arrêter l'ancien monitoring
        pkill -f "pisignage.*monitoring" 2>/dev/null || true

        # Démarrer nouveau monitoring
        (
            while true; do
                sleep 60

                # Vérifier VLC
                if [ -f "/tmp/vlc-pisignage.pid" ]; then
                    local vlc_pid=$(cat "/tmp/vlc-pisignage.pid")
                    if ! kill -0 "$vlc_pid" 2>/dev/null; then
                        log "WARNING: VLC arrêté, redémarrage..."
                        reload_media
                    fi
                fi

                # Log ressources
                local temp=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2 | cut -d\' -f1 || echo "N/A")
                local mem_usage=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
                log "STATUS: Temp=${temp}°C, RAM=${mem_usage}%"

            done
        ) &

        echo $! > "/tmp/pisignage-monitor.pid"
        log "✅ Monitoring redémarré"
    fi
}

# Vérification de l'état du système
check_system_status() {
    log "Vérification de l'état du système..."

    local status_ok=true

    # Vérifier X11
    if [ -n "$DISPLAY" ] && xset q &>/dev/null; then
        log "✅ X11 actif"
    else
        log "❌ X11 inactif"
        status_ok=false
    fi

    # Vérifier VLC
    if [ -f "/tmp/vlc-pisignage.pid" ]; then
        local vlc_pid=$(cat "/tmp/vlc-pisignage.pid")
        if kill -0 "$vlc_pid" 2>/dev/null; then
            log "✅ VLC actif (PID: $vlc_pid)"
        else
            log "❌ VLC inactif"
            status_ok=false
        fi
    else
        log "❌ VLC non démarré"
        status_ok=false
    fi

    # Vérifier les services web
    if systemctl is-active --quiet nginx; then
        log "✅ Nginx actif"
    else
        log "❌ Nginx inactif"
        status_ok=false
    fi

    if systemctl is-active --quiet php8.2-fpm; then
        log "✅ PHP-FPM actif"
    else
        log "❌ PHP-FPM inactif"
        status_ok=false
    fi

    # Rapport final
    if $status_ok; then
        log "✅ Système entièrement opérationnel"
        return 0
    else
        log "⚠️ Problèmes détectés dans le système"
        return 1
    fi
}

# Actions correctives
fix_issues() {
    log "Application des corrections automatiques..."

    # Redémarrer VLC si nécessaire
    if [ ! -f "/tmp/vlc-pisignage.pid" ] || ! kill -0 "$(cat /tmp/vlc-pisignage.pid 2>/dev/null)" 2>/dev/null; then
        log "Correction: Redémarrage de VLC..."
        reload_media
    fi

    # Redémarrer les services web si nécessaire
    if ! systemctl is-active --quiet nginx || ! systemctl is-active --quiet php8.2-fpm; then
        log "Correction: Redémarrage des services web..."
        sudo systemctl restart php8.2-fpm nginx 2>/dev/null || true
    fi

    log "✅ Corrections appliquées"
}

# Fonction principale
main() {
    log "🔄 Rechargement de PiSignage v0.8.0..."

    reload_config
    reload_media
    reload_scripts

    # Vérifier le statut après rechargement
    if ! check_system_status; then
        log "Problèmes détectés, application des corrections..."
        fix_issues

        # Vérification finale
        if check_system_status; then
            log "✅ Problèmes corrigés"
        else
            log "❌ Problèmes persistants, redémarrage complet recommandé"
            exit 1
        fi
    fi

    log "✅ Rechargement de PiSignage v0.8.0 terminé avec succès"
}

# Exécution
main "$@"