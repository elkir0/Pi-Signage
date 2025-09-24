#!/bin/bash

# VLC Environment Setup for PiSignage v0.8.0
# Complete setup script for optimal VLC configuration on Raspberry Pi

# ================================
# CONFIGURATION
# ================================

PISIGNAGE_DIR="/opt/pisignage"
SCRIPTS_DIR="$PISIGNAGE_DIR/scripts"
CONFIG_DIR="$PISIGNAGE_DIR/config"
LOG_DIR="$PISIGNAGE_DIR/logs"
MEDIA_DIR="$PISIGNAGE_DIR/media"

VLC_CONFIG_FILE="$CONFIG_DIR/vlc-hd-profile.conf"
VLC_USER_CONFIG="/home/pi/.config/vlc/vlcrc"

LOG_FILE="$LOG_DIR/setup.log"

# ================================
# UTILITY FUNCTIONS
# ================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges for system configuration."
        echo "Run: sudo $0"
        exit 1
    fi
}

create_directories() {
    log_message "Creating PiSignage directory structure..."

    mkdir -p "$PISIGNAGE_DIR"
    mkdir -p "$SCRIPTS_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$MEDIA_DIR"
    mkdir -p "$CONFIG_DIR/playlists"

    # Set proper ownership
    chown -R pi:pi "$PISIGNAGE_DIR"

    log_message "Directory structure created"
}

install_vlc_optimized() {
    log_message "Installing VLC with Raspberry Pi optimizations..."

    # Update package list
    apt-get update

    # Install VLC and dependencies
    apt-get install -y \
        vlc \
        vlc-plugin-base \
        vlc-plugin-video-output \
        vlc-data \
        libraspberrypi0 \
        libraspberrypi-dev \
        libraspberrypi-bin

    # Install additional multimedia libraries
    apt-get install -y \
        libvlc-dev \
        libvlccore-dev \
        ffmpeg \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly

    log_message "VLC installation completed"
}

configure_boot_settings() {
    log_message "Configuring boot settings for HD video..."

    local boot_config="/boot/config.txt"
    local boot_cmdline="/boot/cmdline.txt"

    # Backup original files
    if [ -f "$boot_config" ]; then
        cp "$boot_config" "${boot_config}.backup.$(date +%Y%m%d)"
        log_message "Backed up $boot_config"
    fi

    if [ -f "$boot_cmdline" ]; then
        cp "$boot_cmdline" "${boot_cmdline}.backup.$(date +%Y%m%d)"
        log_message "Backed up $boot_cmdline"
    fi

    # Configure /boot/config.txt
    if [ -f "$boot_config" ]; then
        # Remove existing conflicting settings
        sed -i '/^gpu_mem=/d' "$boot_config"
        sed -i '/^gpu_split=/d' "$boot_config"
        sed -i '/^hdmi_force_hotplug=/d' "$boot_config"
        sed -i '/^hdmi_group=/d' "$boot_config"
        sed -i '/^hdmi_mode=/d' "$boot_config"
        sed -i '/^hdmi_drive=/d' "$boot_config"
        sed -i '/^config_hdmi_boost=/d' "$boot_config"
        sed -i '/^start_x=/d' "$boot_config"

        # Add PiSignage optimizations
        cat >> "$boot_config" << 'EOF'

# ================================
# PiSignage VLC HD Optimizations
# ================================

# GPU Memory allocation (128MB for HD video)
gpu_mem=128
gpu_split=128

# HDMI Configuration for 1920x1080
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16
hdmi_drive=2
config_hdmi_boost=4

# Enable camera/GPU firmware
start_x=1

# Disable rainbow splash
disable_splash=1

# Video optimization
disable_overscan=1

# Audio optimization
dtparam=audio=on
audio_pwm_mode=2

# ================================
# End PiSignage Configuration
# ================================
EOF

        log_message "Configured $boot_config for HD video"
    fi

    # Configure /boot/cmdline.txt
    if [ -f "$boot_cmdline" ]; then
        local cmdline=$(cat "$boot_cmdline")

        # Add performance optimizations
        if [[ ! $cmdline == *"cma=128M"* ]]; then
            cmdline="$cmdline cma=128M"
        fi

        if [[ ! $cmdline == *"gpu_mem=128"* ]]; then
            cmdline="$cmdline gpu_mem=128"
        fi

        echo "$cmdline" > "$boot_cmdline"
        log_message "Configured $boot_cmdline for performance"
    fi
}

setup_vlc_user_config() {
    log_message "Setting up VLC user configuration..."

    local vlc_config_dir="/home/pi/.config/vlc"
    mkdir -p "$vlc_config_dir"

    # Copy our optimized configuration
    if [ -f "$VLC_CONFIG_FILE" ]; then
        cp "$VLC_CONFIG_FILE" "$VLC_USER_CONFIG"
        chown pi:pi "$VLC_USER_CONFIG"
        log_message "Copied VLC configuration to user directory"
    else
        log_message "WARNING: VLC configuration file not found: $VLC_CONFIG_FILE"
    fi

    # Create VLC cache directory
    mkdir -p "/home/pi/.cache/vlc"
    chown -R pi:pi "/home/pi/.cache/vlc"

    log_message "VLC user configuration completed"
}

configure_audio() {
    log_message "Configuring audio settings..."

    # Configure ALSA for HDMI audio
    cat > /etc/asound.conf << 'EOF'
# ALSA Configuration for PiSignage
# Forces audio output to HDMI

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

    # Set HDMI audio as default
    if command -v amixer > /dev/null; then
        amixer cset numid=3 2  # Force HDMI audio
        log_message "Set default audio output to HDMI"
    fi

    log_message "Audio configuration completed"
}

setup_systemd_services() {
    log_message "Setting up systemd services..."

    # Create PiSignage service
    cat > /etc/systemd/system/pisignage.service << 'EOF'
[Unit]
Description=PiSignage Digital Signage Player
Documentation=https://github.com/pisignage/pisignage-server
After=network.target sound.service graphical-session.target
Wants=network.target

[Service]
Type=forking
User=pi
Group=pi
WorkingDirectory=/opt/pisignage
Environment=DISPLAY=:0
Environment=HOME=/home/pi

ExecStartPre=/bin/sleep 10
ExecStart=/opt/pisignage/scripts/vlc-control.sh start
ExecStop=/opt/pisignage/scripts/vlc-control.sh stop
ExecReload=/opt/pisignage/scripts/vlc-control.sh restart

Restart=always
RestartSec=10
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

StandardOutput=append:/opt/pisignage/logs/pisignage-service.log
StandardError=append:/opt/pisignage/logs/pisignage-service.log

[Install]
WantedBy=graphical.target
EOF

    # Create monitoring service
    cat > /etc/systemd/system/pisignage-monitor.service << 'EOF'
[Unit]
Description=PiSignage VLC Monitor
After=pisignage.service
Wants=pisignage.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/opt/pisignage
Environment=HOME=/home/pi

ExecStart=/opt/pisignage/scripts/vlc-monitor.sh monitor

Restart=always
RestartSec=30

StandardOutput=append:/opt/pisignage/logs/monitor-service.log
StandardError=append:/opt/pisignage/logs/monitor-service.log

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable services
    systemctl daemon-reload
    systemctl enable pisignage.service
    systemctl enable pisignage-monitor.service

    log_message "Systemd services created and enabled"
}

create_sample_media() {
    log_message "Creating sample media and playlists..."

    # Create a sample video playlist (if no media exists)
    local sample_playlist="$CONFIG_DIR/playlists/default.m3u"

    cat > "$sample_playlist" << 'EOF'
#EXTM3U
#PLAYLIST:Default PiSignage Playlist

# Add your video files here
# Example:
# #EXTINF:30,Sample Video
# file:///opt/pisignage/media/sample.mp4

EOF

    chown pi:pi "$sample_playlist"

    # Create current playlist symlink
    ln -sf "$sample_playlist" "$CONFIG_DIR/current_playlist.m3u"

    log_message "Sample playlists created"
}

optimize_system_performance() {
    log_message "Applying system performance optimizations..."

    # Increase file descriptor limits
    cat >> /etc/security/limits.conf << 'EOF'

# PiSignage optimizations
pi soft nofile 4096
pi hard nofile 8192
EOF

    # Configure kernel parameters
    cat >> /etc/sysctl.conf << 'EOF'

# PiSignage VLC optimizations
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.rmem_max=16777216
net.core.wmem_max=16777216
EOF

    # Add user to required groups
    usermod -a -G video,audio,render pi

    log_message "System performance optimizations applied"
}

create_management_scripts() {
    log_message "Creating management and utility scripts..."

    # Create a simple deployment script
    cat > "$SCRIPTS_DIR/deploy-media.sh" << 'EOF'
#!/bin/bash

# Simple media deployment script
# Usage: ./deploy-media.sh /path/to/media/files

MEDIA_DIR="/opt/pisignage/media"
SOURCE_DIR="$1"

if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
    echo "Usage: $0 /path/to/media/directory"
    exit 1
fi

echo "Copying media files from $SOURCE_DIR to $MEDIA_DIR..."

# Copy all supported video files
find "$SOURCE_DIR" -type f \( \
    -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o \
    -iname "*.mov" -o -iname "*.wmv" -o -iname "*.webm" -o \
    -iname "*.m4v" -o -iname "*.mpg" -o -iname "*.mpeg" \
\) -exec cp {} "$MEDIA_DIR/" \;

echo "Creating new playlist..."
/opt/pisignage/scripts/vlc-playlist-manager.sh create default basic

echo "Restarting VLC..."
/opt/pisignage/scripts/vlc-control.sh restart

echo "Media deployment completed!"
EOF

    chmod +x "$SCRIPTS_DIR/deploy-media.sh"

    # Create status check script
    cat > "$SCRIPTS_DIR/pisignage-status.sh" << 'EOF'
#!/bin/bash

echo "PiSignage System Status"
echo "======================"
echo ""

# VLC Status
echo "VLC Player Status:"
/opt/pisignage/scripts/vlc-control.sh status
echo ""

# System Status
echo "System Information:"
/opt/pisignage/scripts/vlc-monitor.sh status
echo ""

# Service Status
echo "Service Status:"
systemctl is-active pisignage.service
systemctl is-active pisignage-monitor.service
echo ""

# Media Files
echo "Media Files:"
find /opt/pisignage/media -type f | wc -l | xargs echo "Total files:"
echo ""

# Disk Usage
echo "Disk Usage:"
df -h /opt/pisignage
EOF

    chmod +x "$SCRIPTS_DIR/pisignage-status.sh"

    log_message "Management scripts created"
}

show_completion_summary() {
    log_message "=== PISIGNAGE VLC SETUP COMPLETED ==="

    cat << EOF

PiSignage VLC Environment Setup Complete!
=========================================

Installation Summary:
- VLC player with hardware acceleration
- Optimized configuration for 1920x1080 30FPS
- Systemd services for auto-start
- Monitoring and recovery scripts
- Management utilities

Important Files:
- Main control: $SCRIPTS_DIR/vlc-control.sh
- Configuration: $VLC_CONFIG_FILE
- Media directory: $MEDIA_DIR
- Logs: $LOG_DIR

Services Created:
- pisignage.service (main player)
- pisignage-monitor.service (health monitoring)

Next Steps:
1. REBOOT the system: sudo reboot
2. Add media files to: $MEDIA_DIR
3. Create playlists: $SCRIPTS_DIR/vlc-playlist-manager.sh
4. Check status: $SCRIPTS_DIR/pisignage-status.sh

Quick Commands:
- Start VLC: $SCRIPTS_DIR/vlc-control.sh start
- Stop VLC: $SCRIPTS_DIR/vlc-control.sh stop
- Monitor: $SCRIPTS_DIR/vlc-monitor.sh status
- Add media: $SCRIPTS_DIR/deploy-media.sh /path/to/files

IMPORTANT: A reboot is required for all optimizations to take effect!

EOF

    log_message "Setup completed successfully - REBOOT REQUIRED"
}

# ================================
# MAIN INSTALLATION FLOW
# ================================

main() {
    log_message "Starting PiSignage VLC environment setup..."

    check_root
    create_directories
    install_vlc_optimized
    configure_boot_settings
    setup_vlc_user_config
    configure_audio
    optimize_system_performance
    setup_systemd_services
    create_sample_media
    create_management_scripts

    show_completion_summary
}

# ================================
# SCRIPT ENTRY POINT
# ================================

case "${1:-install}" in
    install|setup)
        main
        ;;
    directories)
        create_directories
        ;;
    vlc)
        install_vlc_optimized
        ;;
    boot)
        check_root
        configure_boot_settings
        ;;
    audio)
        check_root
        configure_audio
        ;;
    services)
        check_root
        setup_systemd_services
        ;;
    help|--help|-h)
        cat << EOF
PiSignage VLC Environment Setup Script

Usage: sudo $0 [command]

Commands:
  install     - Full installation (default)
  directories - Create directory structure only
  vlc         - Install VLC packages only
  boot        - Configure boot settings only
  audio       - Configure audio only
  services    - Setup systemd services only
  help        - Show this help

The full installation includes all components and requires a reboot.

EOF
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac

exit $?