#!/bin/bash
# PiSignage v0.8.1 - Display Environment Monitor
# Surveille l'environnement graphique et adapte la configuration automatiquement

LOG_FILE="/opt/pisignage/logs/display-monitor.log"
CONFIG_FILE="/opt/pisignage/config/player-config.json"
MONITOR_INTERVAL=10

# Fonction de logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Fonction de détection de l'environnement graphique
detect_current_environment() {
    # Méthode 1: Variables d'environnement
    if [ -n "$WAYLAND_DISPLAY" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        echo "wayland"
        return
    fi

    if [ -n "$DISPLAY" ] && command -v xrandr >/dev/null 2>&1; then
        if xrandr >/dev/null 2>&1; then
            echo "x11"
            return
        fi
    fi

    # Méthode 2: Processus actifs
    if pgrep -f "wayfire|labwc|weston|sway|river" >/dev/null 2>&1; then
        echo "wayland"
        return
    fi

    if pgrep -f "Xorg|X" >/dev/null 2>&1; then
        echo "x11"
        return
    fi

    # Méthode 3: Sessions actives
    if loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}' | head -1) 2>/dev/null | grep -q "Type=wayland"; then
        echo "wayland"
        return
    fi

    if loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}' | head -1) 2>/dev/null | grep -q "Type=x11"; then
        echo "x11"
        return
    fi

    echo "unknown"
}

# Fonction de vérification du support V4L2-request
check_v4l2_support() {
    # Vérifier les modules kernel
    if lsmod | grep -q "bcm2835_v4l2"; then
        echo "v4l2_legacy"
        return
    fi

    if lsmod | grep -q "bcm2835_codec"; then
        echo "v4l2_request"
        return
    fi

    if ls /dev/video* >/dev/null 2>&1; then
        # Vérifier les capacités V4L2
        for device in /dev/video*; do
            if [ -c "$device" ]; then
                caps=$(v4l2-ctl --device="$device" --list-formats-ext 2>/dev/null | grep -i "h264\|hevc\|codec")
                if [ -n "$caps" ]; then
                    echo "v4l2_detected"
                    return
                fi
            fi
        done
    fi

    echo "none"
}

# Fonction de vérification des permissions DRM
check_drm_permissions() {
    local current_user=$(whoami)

    # Vérifier l'appartenance aux groupes critiques
    if ! id -nG "$current_user" | grep -qw "video"; then
        echo "missing_video_group"
        return
    fi

    if ! id -nG "$current_user" | grep -qw "render"; then
        echo "missing_render_group"
        return
    fi

    # Vérifier l'accès aux périphériques DRM
    if [ -e "/dev/dri/card0" ]; then
        if [ -r "/dev/dri/card0" ] && [ -w "/dev/dri/card0" ]; then
            echo "drm_ok"
        else
            echo "drm_no_access"
        fi
    else
        echo "drm_not_found"
    fi
}

# Fonction de vérification de seatd
check_seatd_status() {
    if systemctl is-active --quiet seatd; then
        if [ -S "/run/seatd.sock" ]; then
            echo "seatd_active"
        else
            echo "seatd_no_socket"
        fi
    else
        echo "seatd_inactive"
    fi
}

# Fonction de mise à jour de la configuration automatique
update_auto_config() {
    local display_env=$1
    local v4l2_support=$2
    local drm_status=$3

    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "⚠️  Fichier de configuration manquant: $CONFIG_FILE"
        return
    fi

    # Mise à jour du JSON avec les détections actuelles
    temp_config=$(mktemp)
    jq ".display_environment.current = \"$display_env\" | \
        .system.display_server = \"$display_env\" | \
        .mpv.v4l2_request_support = $([ "$v4l2_support" = "v4l2_request" ] && echo "true" || echo "false") | \
        .system.drm_permissions = $([ "$drm_status" = "drm_ok" ] && echo "true" || echo "false")" \
        "$CONFIG_FILE" > "$temp_config"

    if [ $? -eq 0 ]; then
        mv "$temp_config" "$CONFIG_FILE"
        log_message "✅ Configuration mise à jour: ENV=$display_env, V4L2=$v4l2_support, DRM=$drm_status"
    else
        rm -f "$temp_config"
        log_message "❌ Erreur mise à jour configuration"
    fi
}

# Fonction de diagnostic complet
run_full_diagnostic() {
    local display_env=$(detect_current_environment)
    local v4l2_support=$(check_v4l2_support)
    local drm_status=$(check_drm_permissions)
    local seatd_status=$(check_seatd_status)

    log_message "=== Diagnostic PiSignage v0.8.1 ==="
    log_message "Display Environment: $display_env"
    log_message "V4L2 Support: $v4l2_support"
    log_message "DRM Permissions: $drm_status"
    log_message "Seatd Status: $seatd_status"
    log_message "XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-not set}"
    log_message "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-not set}"
    log_message "DISPLAY: ${DISPLAY:-not set}"
    log_message "=================================="

    # Mise à jour automatique de la configuration
    update_auto_config "$display_env" "$v4l2_support" "$drm_status"

    # Alertes et recommandations
    case "$display_env" in
        "unknown")
            log_message "⚠️  Environnement graphique non détecté - vérifier la session"
            ;;
        "x11")
            log_message "ℹ️  Mode X11 détecté - support complet"
            ;;
        "wayland")
            log_message "✅ Mode Wayland détecté - configuration native"
            ;;
    esac

    case "$v4l2_support" in
        "none")
            log_message "❌ V4L2 non disponible - performance dégradée"
            ;;
        "v4l2_legacy")
            log_message "⚠️  V4L2 legacy - mise à jour vers raspberrypi-ffmpeg recommandée"
            ;;
        "v4l2_request")
            log_message "✅ V4L2-request disponible - accélération optimale"
            ;;
    esac

    case "$drm_status" in
        "missing_video_group")
            log_message "❌ Utilisateur non membre du groupe 'video'"
            ;;
        "missing_render_group")
            log_message "❌ Utilisateur non membre du groupe 'render'"
            ;;
        "drm_no_access")
            log_message "❌ Pas d'accès aux périphériques DRM"
            ;;
        "drm_not_found")
            log_message "❌ Périphériques DRM non trouvés"
            ;;
        "drm_ok")
            log_message "✅ Permissions DRM correctes"
            ;;
    esac

    if [ "$seatd_status" != "seatd_active" ]; then
        log_message "⚠️  Seatd non actif - permissions DRM pourraient être limitées"
    fi
}

# Fonction de surveillance continue
monitor_environment() {
    log_message "🔍 Démarrage surveillance environnement display (intervalle: ${MONITOR_INTERVAL}s)"

    local last_display_env=""
    local last_v4l2_support=""

    while true; do
        current_display_env=$(detect_current_environment)
        current_v4l2_support=$(check_v4l2_support)

        # Détecter les changements
        if [ "$current_display_env" != "$last_display_env" ] || [ "$current_v4l2_support" != "$last_v4l2_support" ]; then
            log_message "🔄 Changement détecté - diagnostic complet"
            run_full_diagnostic

            # Notification si changement critique
            if [ "$current_display_env" != "$last_display_env" ] && [ -n "$last_display_env" ]; then
                log_message "🔥 CHANGEMENT CRITIQUE: $last_display_env → $current_display_env"
                # Redémarrer le player si nécessaire
                if systemctl --user is-active --quiet pisignage-player; then
                    log_message "🔄 Redémarrage du player pour adaptation à $current_display_env"
                    systemctl --user restart pisignage-player
                fi
            fi

            last_display_env="$current_display_env"
            last_v4l2_support="$current_v4l2_support"
        fi

        sleep "$MONITOR_INTERVAL"
    done
}

# Fonction principale
main() {
    case "${1:-monitor}" in
        "monitor")
            monitor_environment
            ;;
        "diagnostic"|"diag")
            run_full_diagnostic
            ;;
        "detect")
            echo "Display Environment: $(detect_current_environment)"
            echo "V4L2 Support: $(check_v4l2_support)"
            echo "DRM Status: $(check_drm_permissions)"
            echo "Seatd Status: $(check_seatd_status)"
            ;;
        "fix-permissions")
            log_message "🔧 Tentative correction des permissions..."

            # Ajouter aux groupes si nécessaire
            if ! id -nG | grep -qw "video"; then
                sudo usermod -a -G video $(whoami)
                log_message "✅ Ajouté au groupe video"
            fi

            if ! id -nG | grep -qw "render"; then
                sudo usermod -a -G render $(whoami)
                log_message "✅ Ajouté au groupe render"
            fi

            # Redémarrer seatd si nécessaire
            if ! systemctl is-active --quiet seatd; then
                sudo systemctl restart seatd
                log_message "🔄 Seatd redémarré"
            fi

            log_message "⚠️  Déconnexion/reconnexion requise pour appliquer les groupes"
            ;;
        *)
            echo "PiSignage Display Monitor v0.8.1"
            echo "Usage: $0 [monitor|diagnostic|detect|fix-permissions]"
            echo ""
            echo "Commands:"
            echo "  monitor        - Surveillance continue (défaut)"
            echo "  diagnostic     - Diagnostic complet ponctuel"
            echo "  detect         - Détection simple"
            echo "  fix-permissions - Correction des permissions"
            ;;
    esac
}

# Créer le répertoire de logs si nécessaire
mkdir -p "$(dirname "$LOG_FILE")"

# Lancer la fonction principale
main "$@"