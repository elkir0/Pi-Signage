#!/bin/bash
# PiSignage - Display Manager with Fallback

MEDIA_DIR="/opt/pisignage/media"
FALLBACK_IMAGE="$MEDIA_DIR/fallback-logo.jpg"
LOG_FILE="/opt/pisignage/logs/display.log"

# Function to show fallback image
show_fallback() {
    echo "$(date): Showing fallback image" >> $LOG_FILE

    # Kill any existing fbi process
    pkill -f fbi 2>/dev/null

    # Check if fbi is installed
    if ! command -v fbi &> /dev/null; then
        echo "$(date): fbi not installed, installing..." >> $LOG_FILE
        sudo apt-get install -y fbi
    fi

    # Display fallback image on framebuffer
    if [ -f "$FALLBACK_IMAGE" ]; then
        sudo fbi -T 1 -noverbose -a "$FALLBACK_IMAGE" 2>/dev/null &
        echo "$(date): Fallback image displayed" >> $LOG_FILE
    else
        echo "$(date): Fallback image not found at $FALLBACK_IMAGE" >> $LOG_FILE
    fi
}

# Function to hide fallback when VLC starts
hide_fallback() {
    echo "$(date): Hiding fallback image" >> $LOG_FILE
    sudo pkill -f fbi 2>/dev/null
}

# Main logic
case "$1" in
    start)
        show_fallback
        ;;
    stop)
        hide_fallback
        ;;
    check)
        # Check if VLC is running
        if ! pgrep -f vlc > /dev/null; then
            show_fallback
        else
            hide_fallback
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|check}"
        exit 1
        ;;
esac