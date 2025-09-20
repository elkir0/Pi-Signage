#!/bin/bash

##############################################################################
# PiSignage Installation Script
# Version: 0.9.1
# Date: 2025-09-20
# 
# Description: Complete installation script for PiSignage digital signage
# Usage: sudo ./install.sh
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/pisignage"
WEB_ROOT="/opt/pisignage/web"
USER="pi"
VERSION="0.9.1"

# Functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS version"
    fi
    
    . /etc/os-release
    if [[ "$ID" != "raspbian" && "$ID" != "debian" ]]; then
        warning "This script is designed for Raspberry Pi OS/Debian"
    fi
}

print_header() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           📺 PiSignage v${VERSION} Installation Script          ║"
    echo "║                                                              ║"
    echo "║    High-Performance Digital Signage for Raspberry Pi 4       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# Main installation
main() {
    print_header
    check_root
    check_os
    
    # Step 1: System Update
    log "Step 1/10: Updating system packages..."
    apt-get update
    apt-get upgrade -y
    
    # Step 2: Install Dependencies
    log "Step 2/10: Installing dependencies..."
    apt-get install -y \
        nginx \
        php8.2-fpm php8.2-cli php8.2-gd php8.2-curl php8.2-mbstring \
        vlc \
        xserver-xorg-core xinit \
        scrot imagemagick \
        git curl wget \
        python3 python3-pip \
        ffmpeg \
        chromium-browser \
        --no-install-recommends
    
    # Step 3: Install yt-dlp
    log "Step 3/10: Installing yt-dlp for YouTube downloads..."
    wget -O /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp
    chmod a+rx /usr/local/bin/yt-dlp
    
    # Step 4: Create Directory Structure
    log "Step 4/10: Creating directory structure..."
    mkdir -p $INSTALL_DIR/{scripts,web,media,config,logs,tests}
    mkdir -p $WEB_ROOT/{api,assets/screenshots}
    
    # Step 5: Configure nginx
    log "Step 5/10: Configuring nginx..."
    cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /opt/pisignage/web;
    index index.php index.html;
    
    server_name _;
    
    # Important: Support for large file uploads (500MB)
    client_max_body_size 500M;
    client_body_buffer_size 128k;
    client_body_timeout 300;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
        include fastcgi_params;
    }
    
    location /api/ {
        try_files $uri $uri/ /api/$uri?$args;
    }
}
EOF
    
    # Step 6: Configure PHP
    log "Step 6/10: Configuring PHP for large uploads..."
    cat > /etc/php/8.2/fpm/conf.d/99-pisignage.ini <<'EOF'
; PiSignage PHP Configuration
upload_max_filesize = 500M
post_max_size = 500M
max_execution_time = 300
max_input_time = 300
memory_limit = 256M
max_file_uploads = 20
EOF
    
    # Also update CLI configuration
    cp /etc/php/8.2/fpm/conf.d/99-pisignage.ini /etc/php/8.2/cli/conf.d/
    
    # Step 7: Copy Application Files
    log "Step 7/10: Installing application files..."
    
    # Check if running from git repo
    if [ -d "./scripts" ] && [ -d "./web" ]; then
        cp -r scripts/* $INSTALL_DIR/scripts/
        cp -r web/* $WEB_ROOT/
        [ -d "./media" ] && cp -r media/* $INSTALL_DIR/media/
        [ -d "./config" ] && cp -r config/* $INSTALL_DIR/config/
    else
        warning "Application files not found in current directory"
        info "Files should be manually copied to $INSTALL_DIR"
    fi
    
    # Step 8: Set Permissions
    log "Step 8/10: Setting permissions..."
    chown -R www-data:www-data $WEB_ROOT
    chown -R $USER:$USER $INSTALL_DIR
    chmod -R 755 $INSTALL_DIR
    chmod -R 775 $INSTALL_DIR/media
    chmod -R 775 $INSTALL_DIR/logs
    chmod +x $INSTALL_DIR/scripts/*.sh
    
    # Make media directory writable for web server
    chown -R www-data:www-data $INSTALL_DIR/media
    chown -R www-data:www-data $WEB_ROOT/assets/screenshots
    
    # Step 9: Configure Auto-start
    log "Step 9/10: Configuring auto-start..."
    
    # Create systemd service for VLC
    cat > /etc/systemd/system/pisignage-display.service <<EOF
[Unit]
Description=PiSignage Display Service
After=multi-user.target

[Service]
Type=simple
User=$USER
Environment="DISPLAY=:0"
ExecStart=/opt/pisignage/scripts/vlc-control.sh start
ExecStop=/opt/pisignage/scripts/vlc-control.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Configure auto-login for pi user
    mkdir -p /etc/systemd/system/getty@tty1.service.d/
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF
    
    # Create .xinitrc for auto-start
    cat > /home/$USER/.xinitrc <<'EOF'
#!/bin/bash
# Start VLC in background with dummy interface
exec cvlc --intf dummy --fullscreen --loop /opt/pisignage/media/*.mp4
EOF
    chmod +x /home/$USER/.xinitrc
    chown $USER:$USER /home/$USER/.xinitrc
    
    # Create .bash_profile for auto-startx
    cat > /home/$USER/.bash_profile <<'EOF'
if [ -z "$DISPLAY" ] && [ $(tty) = /dev/tty1 ]; then
    startx
fi
EOF
    chown $USER:$USER /home/$USER/.bash_profile
    
    # Step 10: Download Test Videos
    log "Step 10/10: Downloading test videos..."
    if [ ! -f "$INSTALL_DIR/media/Big_Buck_Bunny.mp4" ]; then
        info "Downloading Big Buck Bunny..."
        wget -q --show-progress -O "$INSTALL_DIR/media/Big_Buck_Bunny.mp4" \
            "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4" || \
        warning "Could not download test video"
    fi
    
    # Create a simple test pattern if no videos
    if [ -z "$(ls -A $INSTALL_DIR/media/*.mp4 2>/dev/null)" ]; then
        warning "No videos found, creating test pattern..."
        ffmpeg -f lavfi -i testsrc=duration=10:size=1920x1080:rate=30 \
               -f lavfi -i sine=frequency=1000:duration=10 \
               -pix_fmt yuv420p "$INSTALL_DIR/media/test_pattern.mp4" -y 2>/dev/null
    fi
    
    # Enable and start services
    log "Enabling services..."
    systemctl daemon-reload
    systemctl enable nginx
    systemctl enable php8.2-fpm
    systemctl enable pisignage-display
    
    # Restart services
    log "Starting services..."
    systemctl restart php8.2-fpm
    systemctl restart nginx
    
    # Create version file
    echo "$VERSION" > $INSTALL_DIR/VERSION
    date >> $INSTALL_DIR/VERSION
    
    # Final message
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              ✅ Installation Complete!                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    info "PiSignage v$VERSION has been successfully installed!"
    echo ""
    echo "📺 Web Interface: http://$(hostname -I | cut -d' ' -f1)/"
    echo "📁 Installation Directory: $INSTALL_DIR"
    echo "🎬 Media Directory: $INSTALL_DIR/media"
    echo ""
    echo "Next steps:"
    echo "1. Reboot your Raspberry Pi: sudo reboot"
    echo "2. Access the web interface from any browser"
    echo "3. Upload your videos or download from YouTube"
    echo ""
    warning "Default credentials: pi / raspberry"
    echo ""
    read -p "Would you like to reboot now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Rebooting system..."
        reboot
    else
        info "Please reboot manually to start PiSignage"
    fi
}

# Run main installation
main "$@"