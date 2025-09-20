#!/bin/bash

# Control script for video playback (FFmpeg based)
# Compatible with the web interface expectations

ACTION=${1:-status}

case "$ACTION" in
    start|play)
        # Kill any existing video player
        pkill -9 ffmpeg vlc mplayer mpv ffplay 2>/dev/null
        
        # Start optimized video playback (FIXED for 25 FPS)
        VIDEO_FILE="/opt/pisignage/media/sintel.mp4"
        
        # Get framebuffer resolution dynamically
        FB_SIZE=$(cat /sys/class/graphics/fb0/virtual_size)
        FB_WIDTH=$(echo $FB_SIZE | cut -d',' -f1)
        FB_HEIGHT=$(echo $FB_SIZE | cut -d',' -f2)
        
        # Use hardware acceleration if available (Pi 4)
        if [ -e /dev/video11 ]; then
            # Hardware-accelerated FFmpeg for Raspberry Pi 4
            sudo -u debiandev ffmpeg \
                -hwaccel v4l2m2m \
                -c:v h264_v4l2m2m \
                -i "$VIDEO_FILE" \
                -vf "scale=${FB_WIDTH}:${FB_HEIGHT}" \
                -pix_fmt rgb565le \
                -f fbdev \
                -stream_loop -1 \
                /dev/fb0 > /opt/pisignage/logs/player.log 2>&1 &
        else
            # Fallback to optimized software decoding
            sudo -u debiandev ffmpeg -re -i "$VIDEO_FILE" \
                -vf "scale=${FB_WIDTH}:${FB_HEIGHT}" \
                -pix_fmt rgb565le \
                -f fbdev \
                -stream_loop -1 \
                /dev/fb0 > /opt/pisignage/logs/player.log 2>&1 &
        fi
        
        echo "Video playback started"
        ;;
        
    stop)
        # Stop all video players
        pkill -9 ffmpeg vlc mplayer mpv ffplay 2>/dev/null
        echo "Video playback stopped"
        ;;
        
    status)
        # Check if any video player is running
        if pgrep -x ffmpeg > /dev/null; then
            echo "En lecture"
        elif pgrep -x vlc > /dev/null; then
            echo "En lecture"
        elif pgrep -x mplayer > /dev/null; then
            echo "En lecture"
        else
            echo "Arrêté"
        fi
        ;;
        
    restart)
        $0 stop
        sleep 1
        $0 start
        echo "Video playback restarted"
        ;;
        
    *)
        echo "Usage: $0 {start|stop|status|restart|play}"
        exit 1
        ;;
esac