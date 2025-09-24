#!/bin/bash

# VLC Control Script for PiSignage v0.8.0
# Optimized for Raspberry Pi OS Bookworm 64-bit
# Hardware acceleration with VideoCore VI (64-bit)
# Date: 2025-09-23

# ================================
# CONFIGURATION VARIABLES
# ================================

MEDIA_DIR="/opt/pisignage/media"
CONFIG_DIR="/opt/pisignage/config"
LOG_DIR="/opt/pisignage/logs"
PLAYLIST_FILE="$CONFIG_DIR/current_playlist.m3u"
VLC_LOG="$LOG_DIR/vlc.log"
PID_FILE="$LOG_DIR/vlc.pid"

# Ensure directories exist
mkdir -p "$CONFIG_DIR" "$LOG_DIR"

# ================================
# VLC OPTIMAL PARAMETERS FOR RASPBERRY PI
# ================================

# Base VLC parameters for headless HD playback
VLC_BASE_PARAMS=(
    --intf dummy                           # No interface (headless)
    --fullscreen                          # Fullscreen mode
    --no-video-title-show                 # Hide video title overlay
    --no-osd                              # Disable on-screen display
    --loop                                # Loop playlist
    --repeat                              # Repeat current item
    --no-qt-notification                  # Disable Qt notifications
    --no-qt-privacy-ask                   # No privacy dialog
    --quiet                               # Reduce console output
)

# Hardware acceleration for Raspberry Pi 64-bit Bookworm
VLC_HW_ACCEL=(
    --avcodec-hw=mmal                     # MMAL hardware acceleration (64-bit)
    --mmal-vout                           # MMAL video output optimized
    --codec=avcodec,mmal_decoder          # Use MMAL decoder 64-bit
    --mmal-opaque                         # Use opaque buffers
    --mmal-resize                         # Hardware resize
    --mmal-display=hdmi-1                 # Force HDMI output
    --mmal-layer=1                        # Display layer
)

# HD Video optimization (1920x1080 30FPS)
VLC_VIDEO_OPTS=(
    --vout=mmal_vout                      # MMAL video output
    --aout=alsa                           # ALSA audio output
    --deinterlace=0                       # Disable deinterlacing for progressive
    --video-filter=                       # No video filters
    --sub-filter=                         # No subtitle filters
    --sout-mux-caching=2000              # Output muxer cache (2s)
    --file-caching=2000                   # File cache (2s)
    --network-caching=3000                # Network cache (3s)
    --live-caching=300                    # Live stream cache
)

# Memory and performance optimization
VLC_PERFORMANCE=(
    --prefetch-buffer-size=16777216       # 16MB prefetch buffer
    --file-buffer-size=16777216           # 16MB file buffer
    --threads=4                           # Use 4 threads (Pi 4)
    --high-priority                       # High process priority
    --drop-late-frames                    # Drop late frames to maintain FPS
    --skip-frames                         # Skip frames if needed
)

# Audio optimization
VLC_AUDIO_OPTS=(
    --audio-buffer=500                    # 500ms audio buffer
    --aout-rate=44100                     # Standard sample rate
    --audio-resampler=soxr                # High quality resampling
)

# Combine all parameters
VLC_PARAMS=(
    "${VLC_BASE_PARAMS[@]}"
    "${VLC_HW_ACCEL[@]}"
    "${VLC_VIDEO_OPTS[@]}"
    "${VLC_PERFORMANCE[@]}"
    "${VLC_AUDIO_OPTS[@]}"
)

# ================================
# FUNCTIONS
# ================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$VLC_LOG"
}

check_vlc_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # VLC is running
        else
            rm -f "$PID_FILE"
            return 1  # PID file exists but process is dead
        fi
    fi
    return 1  # No PID file
}

stop_vlc() {
    log_message "Stopping VLC..."

    if check_vlc_running; then
        local pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null

        # Wait up to 10 seconds for graceful shutdown
        local count=0
        while [ $count -lt 10 ] && ps -p "$pid" > /dev/null 2>&1; do
            sleep 1
            count=$((count + 1))
        done

        # Force kill if still running
        if ps -p "$pid" > /dev/null 2>&1; then
            log_message "Force killing VLC process $pid"
            kill -9 "$pid" 2>/dev/null
        fi

        rm -f "$PID_FILE"
    fi

    # Kill any remaining VLC processes
    pkill -f "vlc\|cvlc" 2>/dev/null || true
    log_message "VLC stopped"
}

create_playlist() {
    local media_files=()

    # Find all supported video files in media directory
    while IFS= read -r -d '' file; do
        media_files+=("$file")
    done < <(find "$MEDIA_DIR" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.wmv" -o -iname "*.webm" -o -iname "*.m4v" \) -print0 | sort -z)

    # Create M3U playlist
    {
        echo "#EXTM3U"
        echo "#EXTINF:-1,PiSignage Playlist"
        for file in "${media_files[@]}"; do
            echo "file://$file"
        done
    } > "$PLAYLIST_FILE"

    log_message "Created playlist with ${#media_files[@]} files"
    return ${#media_files[@]}
}

start_vlc() {
    log_message "Starting VLC with HD optimization..."

    # Stop any running VLC instance
    stop_vlc

    # Create/update playlist
    create_playlist
    local file_count=$?

    if [ $file_count -eq 0 ]; then
        log_message "ERROR: No media files found in $MEDIA_DIR"
        return 1
    fi

    # Enable GPU memory split (requires reboot to take effect)
    if [ -f /boot/config.txt ]; then
        if ! grep -q "gpu_mem=128" /boot/config.txt; then
            log_message "WARNING: GPU memory not optimized. Add 'gpu_mem=128' to /boot/config.txt"
        fi
    fi

    # Start VLC with optimized parameters
    log_message "Starting VLC with playlist: $PLAYLIST_FILE"
    log_message "VLC parameters: ${VLC_PARAMS[*]}"

    nohup cvlc "${VLC_PARAMS[@]}" "$PLAYLIST_FILE" \
        >> "$VLC_LOG" 2>&1 &

    local vlc_pid=$!
    echo $vlc_pid > "$PID_FILE"

    # Wait a moment and check if VLC started successfully
    sleep 3
    if ps -p $vlc_pid > /dev/null 2>&1; then
        log_message "VLC started successfully (PID: $vlc_pid)"
        return 0
    else
        log_message "ERROR: VLC failed to start"
        rm -f "$PID_FILE"
        return 1
    fi
}

restart_vlc() {
    log_message "Restarting VLC..."
    stop_vlc
    sleep 2
    start_vlc
}

status_vlc() {
    if check_vlc_running; then
        local pid=$(cat "$PID_FILE")
        echo "VLC is running (PID: $pid)"

        # Show memory usage
        local mem_usage=$(ps -p $pid -o rss= 2>/dev/null | tr -d ' ')
        if [ -n "$mem_usage" ]; then
            local mem_mb=$((mem_usage / 1024))
            echo "Memory usage: ${mem_mb}MB"
        fi

        # Show CPU usage
        local cpu_usage=$(ps -p $pid -o %cpu= 2>/dev/null | tr -d ' ')
        if [ -n "$cpu_usage" ]; then
            echo "CPU usage: ${cpu_usage}%"
        fi

        return 0
    else
        echo "VLC is not running"
        return 1
    fi
}

show_help() {
    cat << EOF
VLC Control Script for PiSignage v0.8.0
Optimized for Raspberry Pi HD playback

Usage: $0 {start|stop|restart|status|help}

Commands:
  start     - Start VLC with HD optimization
  stop      - Stop VLC gracefully
  restart   - Restart VLC
  status    - Show VLC status and resource usage
  help      - Show this help message

Files:
  Media:     $MEDIA_DIR
  Playlist:  $PLAYLIST_FILE
  Log:       $VLC_LOG
  PID:       $PID_FILE

Optimization features:
  - MMAL hardware acceleration
  - HD 1920x1080 30FPS support
  - GPU memory optimization
  - Automatic loop and repeat
  - Performance tuning for Raspberry Pi

EOF
}

# ================================
# MAIN SCRIPT LOGIC
# ================================

case "${1:-help}" in
    start)
        start_vlc
        ;;
    stop)
        stop_vlc
        ;;
    restart)
        restart_vlc
        ;;
    status)
        status_vlc
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Invalid command: $1"
        show_help
        exit 1
        ;;
esac

exit $?