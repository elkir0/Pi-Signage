#!/bin/bash
# PiSignage - Unified Player Control Script
# Interface unique pour contrôler VLC et MPV via API

SCRIPT_DIR="/opt/pisignage/scripts"
CONFIG_FILE="/opt/pisignage/config/player-config.json"
LOG_DIR="/opt/pisignage/logs"

ACTION=$1
PLAYER=$2

# Obtenir le player actuel depuis la configuration
get_current_player() {
    if [ -f "$CONFIG_FILE" ]; then
        jq -r '.player.current' "$CONFIG_FILE" 2>/dev/null || echo "mpv"
    else
        echo "mpv"
    fi
}

# Utiliser player-manager.sh pour toutes les actions
execute_player_action() {
    local action=$1
    local player=$2

    if [ -z "$player" ]; then
        player=$(get_current_player)
    fi

    # Appeler player-manager.sh avec les paramètres
    "$SCRIPT_DIR/player-manager.sh" "$action" "$player"
}

# Actions disponibles
case "$ACTION" in
    play)
        current_player=$(get_current_player)
        execute_player_action "start" "$current_player"
        ;;

    stop)
        current_player=$(get_current_player)
        execute_player_action "stop" "$current_player"
        ;;

    restart)
        current_player=$(get_current_player)
        execute_player_action "restart" "$current_player"
        ;;

    status)
        current_player=$(get_current_player)
        execute_player_action "status" "$current_player"
        ;;

    next)
        # Pour VLC : utiliser HTTP API
        # Pour MPV : utiliser socket IPC
        current_player=$(get_current_player)
        if [ "$current_player" = "vlc" ]; then
            curl -s --user :signage123 "http://localhost:8080/requests/status.json?command=pl_next" > /dev/null
            echo "VLC: Next track"
        else
            echo '{"command": ["playlist-next"]}' | socat - /tmp/mpv-socket 2>/dev/null
            echo "MPV: Next track"
        fi
        ;;

    prev)
        current_player=$(get_current_player)
        if [ "$current_player" = "vlc" ]; then
            curl -s --user :signage123 "http://localhost:8080/requests/status.json?command=pl_previous" > /dev/null
            echo "VLC: Previous track"
        else
            echo '{"command": ["playlist-prev"]}' | socat - /tmp/mpv-socket 2>/dev/null
            echo "MPV: Previous track"
        fi
        ;;

    pause)
        current_player=$(get_current_player)
        if [ "$current_player" = "vlc" ]; then
            curl -s --user :signage123 "http://localhost:8080/requests/status.json?command=pl_pause" > /dev/null
            echo "VLC: Pause/Resume"
        else
            echo '{"command": ["cycle", "pause"]}' | socat - /tmp/mpv-socket 2>/dev/null
            echo "MPV: Pause/Resume"
        fi
        ;;

    volume)
        VOLUME=$3
        current_player=$(get_current_player)
        if [ "$current_player" = "vlc" ] && [ -n "$VOLUME" ]; then
            curl -s --user :signage123 "http://localhost:8080/requests/status.json?command=volume&val=$VOLUME" > /dev/null
            echo "VLC: Volume set to $VOLUME"
        elif [ "$current_player" = "mpv" ] && [ -n "$VOLUME" ]; then
            echo "{\"command\": [\"set_property\", \"volume\", $VOLUME]}" | socat - /tmp/mpv-socket 2>/dev/null
            echo "MPV: Volume set to $VOLUME"
        else
            echo "Usage: $0 volume <0-100>"
        fi
        ;;

    switch)
        # Basculer entre les players
        execute_player_action "switch"
        echo "Player switched successfully"
        ;;

    info)
        # Informations détaillées
        execute_player_action "info"
        ;;

    current)
        # Retourner le player actuel
        echo $(get_current_player)
        ;;

    *)
        echo "Usage: $0 {play|stop|restart|status|next|prev|pause|volume <level>|switch|info|current}"
        echo ""
        echo "Examples:"
        echo "  $0 play          # Start current player"
        echo "  $0 stop          # Stop current player"
        echo "  $0 next          # Next track"
        echo "  $0 pause         # Pause/Resume"
        echo "  $0 volume 50     # Set volume to 50%"
        echo "  $0 switch        # Switch between VLC and MPV"
        echo "  $0 current       # Show current player"
        exit 1
        ;;
esac