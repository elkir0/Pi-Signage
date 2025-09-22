#!/bin/bash

# VLC Monitor and Health Check for PiSignage v0.8.0
# Monitors VLC performance, detects issues, and auto-recovers

# ================================
# CONFIGURATION
# ================================

LOG_DIR="/opt/pisignage/logs"
CONFIG_DIR="/opt/pisignage/config"

MONITOR_LOG="$LOG_DIR/vlc-monitor.log"
PERFORMANCE_LOG="$LOG_DIR/vlc-performance.log"
VLC_PID_FILE="$LOG_DIR/vlc.pid"

# Monitoring thresholds
MAX_CPU_USAGE=85          # % CPU usage before warning
MAX_MEMORY_USAGE=512      # MB memory usage before warning
MAX_TEMP=75               # °C CPU temperature before warning
MIN_FPS=25                # Minimum FPS before warning

# Recovery settings
MAX_RESTART_ATTEMPTS=3
RESTART_COOLDOWN=30       # seconds between restart attempts
MONITOR_INTERVAL=10       # seconds between health checks

mkdir -p "$LOG_DIR"

# ================================
# LOGGING AND UTILITIES
# ================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MONITOR_LOG"
}

log_performance() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$PERFORMANCE_LOG"
}

get_vlc_pid() {
    if [ -f "$VLC_PID_FILE" ]; then
        local pid=$(cat "$VLC_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "$pid"
            return 0
        fi
    fi
    return 1
}

get_cpu_usage() {
    local pid="$1"
    if [ -n "$pid" ]; then
        ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1
    fi
}

get_memory_usage() {
    local pid="$1"
    if [ -n "$pid" ]; then
        local mem_kb=$(ps -p "$pid" -o rss= 2>/dev/null | tr -d ' ')
        if [ -n "$mem_kb" ]; then
            echo $((mem_kb / 1024))  # Convert to MB
        fi
    fi
}

get_cpu_temperature() {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo $((temp / 1000))
    fi
}

get_gpu_memory() {
    if command -v vcgencmd > /dev/null 2>&1; then
        vcgencmd get_mem gpu | cut -d= -f2 | tr -d 'M'
    fi
}

get_system_load() {
    local load=$(uptime | awk '{print $10}' | tr -d ',')
    printf "%.2f" "$load" 2>/dev/null || echo "0.00"
}

check_disk_space() {
    local media_usage=$(df "$LOG_DIR" | tail -1 | awk '{print $5}' | tr -d '%')
    echo "$media_usage"
}

# ================================
# VLC HEALTH CHECKS
# ================================

check_vlc_running() {
    local pid=$(get_vlc_pid)
    if [ -n "$pid" ]; then
        return 0  # VLC is running
    else
        return 1  # VLC is not running
    fi
}

check_vlc_responsive() {
    local pid="$1"

    # Check if VLC process is actually doing something
    # (this is a simplified check - could be enhanced with VLC RC interface)

    # Check if process is in running state (not zombie/defunct)
    local state=$(ps -p "$pid" -o state= 2>/dev/null | tr -d ' ')

    case "$state" in
        "R"|"S") return 0 ;;  # Running or Sleeping (normal)
        "Z"|"T"|"D") return 1 ;;  # Zombie, Stopped, or Uninterruptible sleep
        *) return 1 ;;
    esac
}

check_video_output() {
    # Check if there's actually video output
    # This would typically involve checking the display or using hardware detection

    # For now, we'll check if X11 is running and display is active
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        return 0
    fi

    # For headless systems, assume video output is working if VLC is running
    return 0
}

analyze_vlc_performance() {
    local pid="$1"

    if [ -z "$pid" ]; then
        return 1
    fi

    # Get performance metrics
    local cpu_usage=$(get_cpu_usage "$pid")
    local memory_usage=$(get_memory_usage "$pid")
    local cpu_temp=$(get_cpu_temperature)
    local system_load=$(get_system_load)
    local disk_usage=$(check_disk_space)

    # Log performance data
    log_performance "PID:$pid CPU:${cpu_usage}% MEM:${memory_usage}MB TEMP:${cpu_temp}°C LOAD:$system_load DISK:${disk_usage}%"

    # Check thresholds
    local issues=0

    if [ -n "$cpu_usage" ] && [ "$cpu_usage" -gt "$MAX_CPU_USAGE" ]; then
        log_message "WARNING: High CPU usage: ${cpu_usage}%"
        issues=$((issues + 1))
    fi

    if [ -n "$memory_usage" ] && [ "$memory_usage" -gt "$MAX_MEMORY_USAGE" ]; then
        log_message "WARNING: High memory usage: ${memory_usage}MB"
        issues=$((issues + 1))
    fi

    if [ -n "$cpu_temp" ] && [ "$cpu_temp" -gt "$MAX_TEMP" ]; then
        log_message "WARNING: High CPU temperature: ${cpu_temp}°C"
        issues=$((issues + 1))
    fi

    if [ -n "$disk_usage" ] && [ "$disk_usage" -gt 90 ]; then
        log_message "WARNING: Low disk space: ${disk_usage}% used"
        issues=$((issues + 1))
    fi

    return $issues
}

# ================================
# RECOVERY FUNCTIONS
# ================================

restart_vlc() {
    log_message "Attempting to restart VLC..."

    # Use the main control script for restart
    if [ -x "/opt/pisignage/scripts/vlc-control.sh" ]; then
        /opt/pisignage/scripts/vlc-control.sh restart
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            log_message "VLC restarted successfully"
            return 0
        else
            log_message "ERROR: VLC restart failed (exit code: $exit_code)"
            return 1
        fi
    else
        log_message "ERROR: VLC control script not found"
        return 1
    fi
}

force_kill_vlc() {
    log_message "Force killing all VLC processes..."

    pkill -9 -f "vlc\|cvlc" 2>/dev/null
    rm -f "$VLC_PID_FILE"

    sleep 3

    if pgrep -f "vlc\|cvlc" > /dev/null; then
        log_message "ERROR: VLC processes still running after force kill"
        return 1
    else
        log_message "All VLC processes terminated"
        return 0
    fi
}

emergency_recovery() {
    log_message "EMERGENCY: Starting emergency recovery procedure"

    # Stop all VLC processes
    force_kill_vlc

    # Clean up any locks or temp files
    rm -f /tmp/vlc-* 2>/dev/null
    rm -f /tmp/.vlc-* 2>/dev/null

    # Check system resources
    local cpu_temp=$(get_cpu_temperature)
    local system_load=$(get_system_load)

    if [ -n "$cpu_temp" ] && [ "$cpu_temp" -gt "$MAX_TEMP" ]; then
        log_message "EMERGENCY: CPU overheating (${cpu_temp}°C), waiting for cooldown..."
        sleep 60
    fi

    # Restart VLC after cooldown
    log_message "EMERGENCY: Attempting VLC restart after emergency recovery"
    restart_vlc
}

# ================================
# MONITORING LOOP
# ================================

monitor_vlc() {
    local restart_count=0
    local last_restart=0

    log_message "Starting VLC monitoring (interval: ${MONITOR_INTERVAL}s)"

    while true; do
        local current_time=$(date +%s)

        # Check if VLC is running
        if ! check_vlc_running; then
            log_message "VLC is not running, attempting restart..."

            # Check restart cooldown
            if [ $((current_time - last_restart)) -lt $RESTART_COOLDOWN ]; then
                log_message "Restart cooldown active, waiting..."
                sleep $RESTART_COOLDOWN
                continue
            fi

            # Attempt restart
            if restart_vlc; then
                restart_count=$((restart_count + 1))
                last_restart=$current_time
                log_message "VLC restarted successfully (attempt $restart_count)"

                # Reset restart count on successful restart
                if [ $restart_count -ge $MAX_RESTART_ATTEMPTS ]; then
                    restart_count=0
                fi
            else
                restart_count=$((restart_count + 1))
                log_message "VLC restart failed (attempt $restart_count)"

                # Emergency recovery if too many failed attempts
                if [ $restart_count -ge $MAX_RESTART_ATTEMPTS ]; then
                    emergency_recovery
                    restart_count=0
                    last_restart=$current_time
                fi
            fi

            sleep $MONITOR_INTERVAL
            continue
        fi

        # VLC is running, check performance
        local vlc_pid=$(get_vlc_pid)

        if ! check_vlc_responsive "$vlc_pid"; then
            log_message "VLC appears unresponsive, restarting..."
            restart_vlc
            restart_count=$((restart_count + 1))
            last_restart=$current_time
        else
            # Analyze performance
            analyze_vlc_performance "$vlc_pid"
        fi

        # Wait before next check
        sleep $MONITOR_INTERVAL
    done
}

# ================================
# STATUS AND REPORTING
# ================================

show_status() {
    echo "VLC Monitor Status Report"
    echo "========================"
    echo "Timestamp: $(date)"
    echo ""

    # VLC Status
    if check_vlc_running; then
        local vlc_pid=$(get_vlc_pid)
        echo "VLC Status: RUNNING (PID: $vlc_pid)"

        # Performance metrics
        local cpu_usage=$(get_cpu_usage "$vlc_pid")
        local memory_usage=$(get_memory_usage "$vlc_pid")

        echo "CPU Usage: ${cpu_usage:-N/A}%"
        echo "Memory Usage: ${memory_usage:-N/A}MB"

        if check_vlc_responsive "$vlc_pid"; then
            echo "Responsiveness: OK"
        else
            echo "Responsiveness: UNRESPONSIVE"
        fi
    else
        echo "VLC Status: NOT RUNNING"
    fi

    echo ""

    # System metrics
    local cpu_temp=$(get_cpu_temperature)
    local system_load=$(get_system_load)
    local disk_usage=$(check_disk_space)
    local gpu_mem=$(get_gpu_memory)

    echo "System Status:"
    echo "CPU Temperature: ${cpu_temp:-N/A}°C"
    echo "System Load: ${system_load:-N/A}"
    echo "Disk Usage: ${disk_usage:-N/A}%"
    echo "GPU Memory: ${gpu_mem:-N/A}MB"

    echo ""

    # Recent log entries
    echo "Recent Monitor Log (last 5 entries):"
    if [ -f "$MONITOR_LOG" ]; then
        tail -5 "$MONITOR_LOG"
    else
        echo "No log entries found"
    fi
}

show_performance_report() {
    local hours="${1:-24}"

    echo "VLC Performance Report (last $hours hours)"
    echo "========================================"

    if [ ! -f "$PERFORMANCE_LOG" ]; then
        echo "No performance data available"
        return 1
    fi

    # Get entries from the last N hours
    local cutoff_time=$(date -d "$hours hours ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || \
                       date -v-${hours}H '+%Y-%m-%d %H:%M:%S' 2>/dev/null)

    if [ -n "$cutoff_time" ]; then
        awk -v cutoff="$cutoff_time" '$1 " " $2 >= cutoff' "$PERFORMANCE_LOG" | tail -100
    else
        tail -100 "$PERFORMANCE_LOG"
    fi
}

# ================================
# MAIN SCRIPT LOGIC
# ================================

show_help() {
    cat << EOF
VLC Monitor and Health Check for PiSignage v0.8.0
Monitors VLC performance and provides automatic recovery

Usage: $0 <command> [options]

Commands:
  monitor           - Start continuous monitoring (blocks)
  status            - Show current VLC and system status
  performance [hrs] - Show performance report (default: 24 hours)
  check             - Run single health check
  restart           - Force restart VLC
  emergency         - Run emergency recovery procedure

Monitoring Settings:
  Check interval:    ${MONITOR_INTERVAL}s
  CPU threshold:     ${MAX_CPU_USAGE}%
  Memory threshold:  ${MAX_MEMORY_USAGE}MB
  Temp threshold:    ${MAX_TEMP}°C
  Max restarts:      ${MAX_RESTART_ATTEMPTS}
  Restart cooldown:  ${RESTART_COOLDOWN}s

Log Files:
  Monitor:      $MONITOR_LOG
  Performance:  $PERFORMANCE_LOG

EOF
}

case "${1:-help}" in
    monitor)
        monitor_vlc
        ;;
    status)
        show_status
        ;;
    performance)
        show_performance_report "$2"
        ;;
    check)
        if check_vlc_running; then
            vlc_pid=$(get_vlc_pid)
            echo "VLC is running (PID: $vlc_pid)"
            analyze_vlc_performance "$vlc_pid"
        else
            echo "VLC is not running"
            exit 1
        fi
        ;;
    restart)
        restart_vlc
        ;;
    emergency)
        emergency_recovery
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