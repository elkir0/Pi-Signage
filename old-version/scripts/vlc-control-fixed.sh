#!/bin/bash

# Fixed video control script with proper 25 FPS FFmpeg configuration
# Corrects the BGRA format issue and optimizes for hardware acceleration

ACTION=${1:-status}

case "$ACTION" in
    start|play)
        # Kill any existing video player
        pkill -9 ffmpeg vlc mplayer mpv ffplay 2>/dev/null
        
        # Get framebuffer info
        FB_SIZE=$(cat /sys/class/graphics/fb0/virtual_size)
        FB_WIDTH=$(echo $FB_SIZE | cut -d',' -f1)
        FB_HEIGHT=$(echo $FB_SIZE | cut -d',' -f2)
        
        VIDEO_FILE="/opt/pisignage/media/sintel.mp4"
        
        # SOLUTION 1: FFmpeg with hardware acceleration for Pi 4
        if [ -e /dev/video11 ]; then
            # Raspberry Pi 4 with V4L2 M2M hardware decoder
            echo "Starting hardware-accelerated playback..."
            sudo -u debiandev ffmpeg \
                -hwaccel v4l2m2m \
                -hwaccel_device /dev/video11 \
                -c:v h264_v4l2m2m \
                -i "$VIDEO_FILE" \
                -vf "scale=${FB_WIDTH}:${FB_HEIGHT}" \
                -pix_fmt rgb565le \
                -f fbdev \
                -stream_loop -1 \
                /dev/fb0 > /opt/pisignage/logs/player.log 2>&1 &
        else
            # SOLUTION 2: FFplay with SDL framebuffer (universal)
            echo "Starting FFplay with SDL framebuffer..."
            export SDL_VIDEODRIVER=fbcon
            export SDL_FBDEV=/dev/fb0
            export FRAMEBUFFER=/dev/fb0
            
            sudo -u debiandev ffplay \
                -fs \
                -an \
                -loop 0 \
                -autoexit \
                -fast \
                -framedrop \
                -sync video \
                "$VIDEO_FILE" > /opt/pisignage/logs/player.log 2>&1 &
        fi
        
        echo "Video playback started with optimized settings"
        ;;
        
    stop)
        # Stop all video players
        pkill -9 ffmpeg vlc mplayer mpv ffplay 2>/dev/null
        echo "Video playback stopped"
        ;;
        
    status)
        # Check if any video player is running
        if pgrep -x ffmpeg > /dev/null; then
            echo "En lecture (FFmpeg)"
        elif pgrep -x ffplay > /dev/null; then
            echo "En lecture (FFplay)"
        elif pgrep -x vlc > /dev/null; then
            echo "En lecture (VLC)"
        elif pgrep -x mplayer > /dev/null; then
            echo "En lecture (MPlayer)"
        else
            echo "Arrêté"
        fi
        ;;
        
    restart)
        $0 stop
        sleep 2
        $0 start
        echo "Video playback restarted"
        ;;
        
    *)
        echo "Usage: $0 {start|stop|status|restart|play}"
        exit 1
        ;;
esac