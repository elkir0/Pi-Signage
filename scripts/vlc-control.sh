#!/bin/bash
# PiSignage - VLC Control Script

MEDIA_DIR="/opt/pisignage/media"
ACTION=$1

case $ACTION in
    start)
        # Kill any existing VLC
        pkill -f vlc 2>/dev/null
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
        ;;

    stop)
        pkill -f vlc
        echo "VLC stopped"
        ;;

    restart)
        $0 stop
        sleep 2
        $0 start
        ;;

    status)
        if pgrep -f vlc > /dev/null; then
            echo "VLC is running"
        else
            echo "VLC is not running"
        fi
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac