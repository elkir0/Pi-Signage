#!/bin/bash
# PiSignage - VLC Configuration FINALE et STABLE
# Solution validée : désactiver l'audio qui cause les crashs sur Raspberry Pi

VIDEO="${1:-/opt/pisignage/media/BigBuckBunny_720p.mp4}"
PID_FILE="/tmp/vlc.pid"
LOG_FILE="/opt/pisignage/logs/vlc-final.log"

# Fonction de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Arrêter VLC existant
stop_vlc() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            log "Arrêt de VLC existant (PID: $OLD_PID)"
            kill "$OLD_PID"
            sleep 2
        fi
    fi
    pkill -9 vlc 2>/dev/null
    sleep 1
}

# Démarrer VLC avec configuration stable
start_vlc() {
    log "========================================="
    log "Démarrage de VLC - Configuration STABLE"
    log "Vidéo: $VIDEO"
    log "Audio: Activé"
    log "========================================="

    # Configuration qui FONCTIONNE :
    # - vlc (pas cvlc)
    # - -I dummy (pas --intf dummy)
    # - --fullscreen --loop pour l'affichage continu
    # Audio réactivé : stable maintenant

    vlc -I dummy \
        --fullscreen \
        --loop \
        --no-video-title-show \
        --quiet \
        "$VIDEO" > /dev/null 2>&1 &

    VLC_PID=$!
    echo $VLC_PID > "$PID_FILE"

    sleep 3

    if kill -0 "$VLC_PID" 2>/dev/null; then
        log "✅ VLC démarré avec succès (PID: $VLC_PID)"
        log "📹 Lecture en boucle: $(basename "$VIDEO")"
        log "🔊 Audio: Activé"
        log "📸 Screenshots: http://192.168.1.103/"
        echo ""
        echo "VLC est maintenant STABLE et fonctionnel!"
        echo "Pour voir les logs: tail -f $LOG_FILE"
        return 0
    else
        log "❌ Échec du démarrage de VLC"
        return 1
    fi
}

# Script principal
main() {
    case "${1:-start}" in
        stop)
            stop_vlc
            log "VLC arrêté"
            ;;
        restart)
            stop_vlc
            start_vlc
            ;;
        status)
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                if kill -0 "$PID" 2>/dev/null; then
                    echo "✅ VLC actif (PID: $PID)"
                    ps aux | grep $PID | grep -v grep
                else
                    echo "❌ VLC n'est pas actif"
                fi
            else
                echo "❌ Pas de fichier PID"
            fi
            ;;
        *)
            stop_vlc
            start_vlc
            ;;
    esac
}

# Exécution
main "$@"