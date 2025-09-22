#!/bin/bash

# VLC Configuration Optimizer for Raspberry Pi
# PiSignage v0.8.0
# Optimizes system settings for HD video playback

# ================================
# SYSTEM CONFIGURATION
# ================================

LOG_FILE="/opt/pisignage/logs/vlc-optimizer.log"
BOOT_CONFIG="/boot/config.txt"
BOOT_CMDLINE="/boot/cmdline.txt"

mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Please run with sudo."
        exit 1
    fi
}

backup_config() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_message "Backed up $file"
    fi
}

optimize_gpu_memory() {
    log_message "Optimizing GPU memory split..."

    if [ ! -f "$BOOT_CONFIG" ]; then
        log_message "WARNING: $BOOT_CONFIG not found, skipping GPU optimization"
        return 1
    fi

    backup_config "$BOOT_CONFIG"

    # Remove existing gpu_mem settings
    sed -i '/^gpu_mem=/d' "$BOOT_CONFIG"

    # Add optimized GPU memory setting
    echo "" >> "$BOOT_CONFIG"
    echo "# PiSignage HD Video Optimization" >> "$BOOT_CONFIG"
    echo "gpu_mem=128" >> "$BOOT_CONFIG"
    echo "gpu_split=128" >> "$BOOT_CONFIG"

    log_message "Set GPU memory to 128MB for HD video acceleration"
}

optimize_video_settings() {
    log_message "Optimizing video settings in $BOOT_CONFIG..."

    if [ ! -f "$BOOT_CONFIG" ]; then
        return 1
    fi

    # Remove existing settings
    sed -i '/^hdmi_force_hotplug=/d' "$BOOT_CONFIG"
    sed -i '/^hdmi_group=/d' "$BOOT_CONFIG"
    sed -i '/^hdmi_mode=/d' "$BOOT_CONFIG"
    sed -i '/^hdmi_drive=/d' "$BOOT_CONFIG"
    sed -i '/^config_hdmi_boost=/d' "$BOOT_CONFIG"

    # Add HD video settings
    cat >> "$BOOT_CONFIG" << EOF

# HD Video Output Settings (PiSignage)
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16
hdmi_drive=2
config_hdmi_boost=4

# Video decoder settings
decode_MPG2=0x12345678
decode_WVC1=0x12345678
EOF

    log_message "Configured HDMI for 1920x1080 60Hz output"
}

optimize_system_performance() {
    log_message "Optimizing system performance..."

    if [ ! -f "$BOOT_CMDLINE" ]; then
        log_message "WARNING: $BOOT_CMDLINE not found"
        return 1
    fi

    backup_config "$BOOT_CMDLINE"

    # Read current cmdline
    local cmdline=$(cat "$BOOT_CMDLINE")

    # Add performance optimizations if not present
    if [[ ! $cmdline == *"cma=128M"* ]]; then
        cmdline="$cmdline cma=128M"
        log_message "Added CMA=128M for better memory management"
    fi

    if [[ ! $cmdline == *"gpu_mem=128"* ]]; then
        cmdline="$cmdline gpu_mem=128"
        log_message "Added GPU memory setting to cmdline"
    fi

    echo "$cmdline" > "$BOOT_CMDLINE"
}

install_required_packages() {
    log_message "Installing required packages for HD video..."

    apt-get update
    apt-get install -y \
        vlc \
        vlc-plugin-base \
        vlc-plugin-video-output \
        libraspberrypi0 \
        libraspberrypi-dev \
        libraspberrypi-doc \
        libraspberrypi-bin

    log_message "VLC and Raspberry Pi libraries installed"
}

create_vlc_config() {
    log_message "Creating optimized VLC configuration..."

    local vlc_config_dir="/home/pi/.config/vlc"
    local vlc_config_file="$vlc_config_dir/vlcrc"

    mkdir -p "$vlc_config_dir"

    cat > "$vlc_config_file" << 'EOF'
# VLC Configuration for PiSignage HD Video
# Optimized for Raspberry Pi hardware acceleration

[core]
intf=dummy
aout=alsa
vout=mmal_vout

[avcodec]
avcodec-hw=mmal
avcodec-threads=4
avcodec-skip-frame=0
avcodec-skip-idct=0

[mmal]
mmal-opaque=1
mmal-resize=1
mmal-vout=1

[filesystem]
file-caching=2000

[access]
network-caching=3000
live-caching=300

[video]
fullscreen=1
video-title-show=0
osd=0

[audio]
audio-buffer=500
aout-rate=44100
audio-resampler=soxr
EOF

    chown -R pi:pi "$vlc_config_dir"
    log_message "Created VLC configuration file"
}

optimize_audio() {
    log_message "Optimizing audio settings..."

    # Set audio output to HDMI by default
    if command -v amixer > /dev/null; then
        amixer cset numid=3 2  # Force HDMI audio
        log_message "Set audio output to HDMI"
    fi

    # Create asound.conf for better audio
    cat > /etc/asound.conf << 'EOF'
pcm.!default {
    type hw
    card 1
    device 0
}
ctl.!default {
    type hw
    card 1
}
EOF

    log_message "Configured ALSA for HDMI audio"
}

enable_hardware_acceleration() {
    log_message "Enabling hardware video acceleration..."

    # Add pi user to video group
    usermod -a -G video pi

    # Enable GPU firmware
    if [ -f "$BOOT_CONFIG" ]; then
        if ! grep -q "start_x=1" "$BOOT_CONFIG"; then
            echo "start_x=1" >> "$BOOT_CONFIG"
            log_message "Enabled camera/GPU firmware"
        fi
    fi

    log_message "Hardware acceleration enabled"
}

create_systemd_service() {
    log_message "Creating systemd service for PiSignage..."

    cat > /etc/systemd/system/pisignage.service << 'EOF'
[Unit]
Description=PiSignage Digital Signage
After=network.target sound.service
Wants=network.target

[Service]
Type=forking
User=pi
Group=pi
WorkingDirectory=/opt/pisignage
ExecStart=/opt/pisignage/scripts/vlc-control.sh start
ExecStop=/opt/pisignage/scripts/vlc-control.sh stop
ExecReload=/opt/pisignage/scripts/vlc-control.sh restart
Restart=always
RestartSec=10
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable pisignage.service
    log_message "Created and enabled PiSignage systemd service"
}

show_system_info() {
    log_message "=== RASPBERRY PI SYSTEM INFORMATION ==="

    # CPU info
    if [ -f /proc/cpuinfo ]; then
        local cpu_model=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | xargs)
        log_message "CPU: $cpu_model"
    fi

    # Memory info
    local total_mem=$(free -m | grep "Mem:" | awk '{print $2}')
    log_message "Total RAM: ${total_mem}MB"

    # GPU memory
    if command -v vcgencmd > /dev/null; then
        local gpu_mem=$(vcgencmd get_mem gpu | cut -d= -f2)
        log_message "GPU Memory: $gpu_mem"
    fi

    # Temperature
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        local temp_c=$((temp / 1000))
        log_message "CPU Temperature: ${temp_c}°C"
    fi

    # Video codec support
    if command -v vcgencmd > /dev/null; then
        local codec_h264=$(vcgencmd codec_enabled H264)
        local codec_mpg2=$(vcgencmd codec_enabled MPG2)
        log_message "H.264 Codec: $codec_h264"
        log_message "MPEG2 Codec: $codec_mpg2"
    fi
}

run_full_optimization() {
    log_message "=== STARTING FULL RASPBERRY PI OPTIMIZATION ==="

    check_root

    show_system_info

    install_required_packages
    optimize_gpu_memory
    optimize_video_settings
    optimize_system_performance
    optimize_audio
    enable_hardware_acceleration
    create_vlc_config
    create_systemd_service

    log_message "=== OPTIMIZATION COMPLETE ==="
    log_message "IMPORTANT: Reboot required for all changes to take effect"
    log_message "Run: sudo reboot"
}

show_help() {
    cat << EOF
VLC Configuration Optimizer for PiSignage v0.8.0
Optimizes Raspberry Pi for HD video playback

Usage: sudo $0 [option]

Options:
  full      - Run complete optimization (REQUIRES REBOOT)
  gpu       - Optimize GPU memory only
  video     - Optimize video settings only
  audio     - Optimize audio settings only
  packages  - Install required packages only
  service   - Create systemd service only
  info      - Show system information
  help      - Show this help

WARNING: This script modifies system configuration files.
Backups are created automatically with timestamp.

Files modified:
  - $BOOT_CONFIG
  - $BOOT_CMDLINE
  - /etc/asound.conf
  - /home/pi/.config/vlc/vlcrc
  - /etc/systemd/system/pisignage.service

EOF
}

# ================================
# MAIN SCRIPT LOGIC
# ================================

case "${1:-help}" in
    full)
        run_full_optimization
        ;;
    gpu)
        check_root
        optimize_gpu_memory
        ;;
    video)
        check_root
        optimize_video_settings
        ;;
    audio)
        check_root
        optimize_audio
        ;;
    packages)
        check_root
        install_required_packages
        ;;
    service)
        check_root
        create_systemd_service
        ;;
    info)
        show_system_info
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Invalid option: $1"
        show_help
        exit 1
        ;;
esac

exit $?