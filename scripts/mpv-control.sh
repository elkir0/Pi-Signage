#!/bin/bash
# PiSignage - MPV Control Script

MEDIA_DIR="/opt/pisignage/media"
ACTION=$1

case $ACTION in
    start)
        # Kill any existing MPV/VLC
        pkill -f mpv 2>/dev/null || true
        pkill -f vlc 2>/dev/null || true
        sleep 1

        # Start MPV in fullscreen
        mpv --fullscreen \
            --loop-playlist=inf \
            --no-audio-display \
            --really-quiet \
            --no-terminal \
            "$MEDIA_DIR"/*.mp4 \
            > /opt/pisignage/logs/mpv.log 2>&1 &

        echo "MPV started"
        exit 0
        ;;

    stop)
        pkill -f mpv 2>/dev/null || true
        echo "MPV stopped"
        exit 0
        ;;

    restart)
        $0 stop
        sleep 2
        $0 start
        exit 0
        ;;

    status)
        if pgrep -f mpv > /dev/null; then
            echo "MPV is running"
        else
            echo "MPV is not running"
        fi
        exit 0
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac