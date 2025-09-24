#!/bin/bash
# PiSignage - Simple VLC Control Script

MEDIA_DIR="/opt/pisignage/media"
ACTION=$1

case $ACTION in
    start)
        # Kill any existing VLC
        pkill -f vlc 2>/dev/null || true
        sleep 1

        # Start VLC with basic parameters
        DISPLAY=:0 cvlc \
            --fullscreen \
            --loop \
            --no-video-title-show \
            --intf dummy \
            "$MEDIA_DIR"/*.mp4 \
            > /opt/pisignage/logs/vlc.log 2>&1 &

        echo "VLC started"
        exit 0
        ;;

    stop)
        pkill -f vlc 2>/dev/null || true
        echo "VLC stopped"
        exit 0
        ;;

    restart)
        $0 stop
        sleep 2
        $0 start
        exit 0
        ;;

    status)
        if pgrep -f vlc > /dev/null; then
            echo "VLC is running"
        else
            echo "VLC is not running"
        fi
        exit 0
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac