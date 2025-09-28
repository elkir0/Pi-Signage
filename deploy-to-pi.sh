#!/bin/bash
###############################################################################
# PiSignage v0.8.3 - Deployment Script for Raspberry Pi
###############################################################################

set -e

# Configuration
PI_HOST="${1:-raspberrypi.local}"
PI_USER="${2:-pi}"

# Check architecture
ARCH=$(uname -m)

if [[ "$ARCH" == "armv7l" ]] || [[ "$ARCH" == "aarch64" ]]; then
    echo "✓ Running on Raspberry Pi"
    
    # Install dependencies
    sudo apt-get update
    sudo apt-get install -y nginx php-fpm php-cli php-json php-sqlite3 php-gd vlc ffmpeg
    
    # Configure for Pi hardware
    sudo raspi-config nonint do_boot_behaviour B2  # Console Autologin
    
    # Configure VLC for hardware acceleration
    echo "hdmi_force_hotplug=1" | sudo tee -a /boot/config.txt
    echo "gpu_mem=128" | sudo tee -a /boot/config.txt
    
    # Create auto-start script
    sudo tee /etc/systemd/system/pisignage-display.service > /dev/null <<'SERVICE'
[Unit]
Description=PiSignage Display
After=network.target

[Service]
Type=simple
User=pi
Environment="DISPLAY=:0"
ExecStart=/usr/bin/vlc --fullscreen --intf dummy --loop /opt/pisignage/media/
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

    sudo systemctl enable pisignage-display
    echo "✓ Raspberry Pi configuration complete"
else
    echo "→ Deploying from x86_64 to $PI_HOST"
    
    # Package and deploy
    tar czf /tmp/pisignage.tar.gz -C /opt pisignage
    scp /tmp/pisignage.tar.gz $PI_USER@$PI_HOST:/tmp/
    
    ssh $PI_USER@$PI_HOST "sudo tar xzf /tmp/pisignage.tar.gz -C /opt && sudo bash deploy-to-pi.sh"
fi

echo "✓ Deployment complete!"
