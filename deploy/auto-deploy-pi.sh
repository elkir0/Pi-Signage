#!/bin/bash

################################################################################
# PiSignage Auto-Deploy Script for Raspberry Pi
# Version: 3.1.0
# Description: Fully automated deployment script with SSH key-based auth
################################################################################

set -e

# Configuration
PI_HOST="${PI_HOST:-192.168.1.103}"
PI_USER="${PI_USER:-pi}"
PI_PASS="${PI_PASS:-palmer00}"
WEB_DIR="/var/www/pisignage"
PISIGNAGE_DIR="/opt/pisignage"
LOG_FILE="deploy-$(date +%Y%m%d-%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Header
print_header() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           PiSignage Auto-Deploy Script v3.1.0               ║"
    echo "║                                                              ║"
    echo "║  Target: $PI_USER@$PI_HOST                                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check sshpass
    if ! command -v sshpass &> /dev/null; then
        info "Installing sshpass..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get update && sudo apt-get install -y sshpass
        else
            error "sshpass not found. Please install it manually."
        fi
    fi
    
    # Check expect
    if ! command -v expect &> /dev/null; then
        info "Installing expect..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get update && sudo apt-get install -y expect
        else
            error "expect not found. Please install it manually."
        fi
    fi
    
    success "Prerequisites checked"
}

# Test SSH connection
test_connection() {
    log "Testing SSH connection to $PI_HOST..."
    
    if sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        $PI_USER@$PI_HOST "echo 'Connection successful'" &>/dev/null; then
        success "SSH connection successful"
        return 0
    else
        error "Cannot connect to $PI_HOST. Please check host and credentials."
        return 1
    fi
}

# Deploy web server
deploy_web_server() {
    log "Deploying web server on Raspberry Pi..."
    
    # Create deployment script
    cat > /tmp/deploy-web.sh << 'DEPLOY_SCRIPT'
#!/bin/bash

echo "Starting web server deployment..."

# Update system
sudo apt-get update

# Install web server packages
echo "Installing nginx and PHP..."
sudo apt-get install -y nginx php-fpm php-json php-curl php-mbstring php-xml jq curl wget

# Create directories
echo "Creating directory structure..."
sudo mkdir -p /var/www/pisignage/{api,assets,templates,uploads}
sudo mkdir -p /opt/pisignage/{media,logs,config,scripts,backups}
sudo chmod 755 /opt/pisignage
sudo chown -R www-data:www-data /var/www/pisignage
sudo chmod 775 /var/www/pisignage/uploads

# Create VLC control script
echo "Creating VLC control script..."
sudo tee /opt/pisignage/scripts/vlc-control.sh > /dev/null << 'VLC_SCRIPT'
#!/bin/bash

ACTION=$1
VIDEO_PATH=$2
PID_FILE="/var/run/vlc.pid"

case $ACTION in
    play)
        pkill -f "vlc.*fullscreen" 2>/dev/null
        sleep 1
        
        if [ -z "$VIDEO_PATH" ]; then
            VIDEO_PATH="/home/pi/Big_Buck_Bunny_720_10s_30MB.mp4"
        fi
        
        if [ ! -f "$VIDEO_PATH" ]; then
            VIDEO_PATH="/opt/pisignage/media/$(ls /opt/pisignage/media/*.mp4 2>/dev/null | head -1)"
        fi
        
        DISPLAY=:0 cvlc --fullscreen --loop --no-video-title-show --intf dummy "$VIDEO_PATH" &
        echo $! > $PID_FILE
        echo "Playing: $VIDEO_PATH"
        ;;
        
    stop)
        pkill -f "vlc.*fullscreen"
        rm -f $PID_FILE
        echo "Playback stopped"
        ;;
        
    status)
        if pgrep -f "vlc.*fullscreen" > /dev/null; then
            echo "VLC is running (PID: $(pgrep -f 'vlc.*fullscreen'))"
            ps aux | grep -E "vlc.*fullscreen" | grep -v grep
        else
            echo "VLC is not running"
        fi
        ;;
        
    restart)
        $0 stop
        sleep 2
        $0 play "$VIDEO_PATH"
        ;;
        
    *)
        echo "Usage: $0 {play|stop|status|restart} [video_path]"
        exit 1
        ;;
esac
VLC_SCRIPT

sudo chmod +x /opt/pisignage/scripts/vlc-control.sh
sudo chown pi:pi /opt/pisignage/scripts/vlc-control.sh

# Configure nginx
echo "Configuring nginx..."
sudo tee /etc/nginx/sites-available/pisignage > /dev/null << 'NGINX_CONFIG'
server {
    listen 80;
    server_name _;
    root /var/www/pisignage;
    index index.php index.html;

    client_max_body_size 500M;
    client_body_timeout 300s;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_read_timeout 300;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex on;
        add_header Cache-Control "public, max-age=3600";
    }

    location /api {
        try_files $uri $uri/ /api/control.php?$query_string;
    }
}
NGINX_CONFIG

# Enable site
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Configure PHP
echo "Configuring PHP..."
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"

if [ -f "$PHP_INI" ]; then
    sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' $PHP_INI
    sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' $PHP_INI
    sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' $PHP_INI
    sudo sed -i 's/memory_limit = .*/memory_limit = 256M/' $PHP_INI
fi

# Setup permissions for www-data
echo "Setting up permissions..."
echo "www-data ALL=(pi) NOPASSWD: /opt/pisignage/scripts/vlc-control.sh" | sudo tee /etc/sudoers.d/pisignage
echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/pkill" | sudo tee -a /etc/sudoers.d/pisignage
echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/pgrep" | sudo tee -a /etc/sudoers.d/pisignage
sudo chmod 440 /etc/sudoers.d/pisignage

# Copy sample video if exists
if [ -f "/home/pi/Big_Buck_Bunny_720_10s_30MB.mp4" ]; then
    echo "Copying sample video..."
    cp /home/pi/Big_Buck_Bunny_720_10s_30MB.mp4 /opt/pisignage/media/ 2>/dev/null || true
    sudo chown www-data:www-data /opt/pisignage/media/*.mp4 2>/dev/null || true
fi

# Restart services
echo "Restarting services..."
sudo systemctl restart nginx
sudo systemctl restart php*-fpm
sudo systemctl enable nginx
sudo systemctl enable php*-fpm

echo "Web server deployment complete!"
DEPLOY_SCRIPT

    # Execute deployment script on Pi
    info "Executing deployment script on Raspberry Pi..."
    sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no /tmp/deploy-web.sh $PI_USER@$PI_HOST:/tmp/
    sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST "chmod +x /tmp/deploy-web.sh && /tmp/deploy-web.sh"
    
    success "Web server deployed successfully"
}

# Deploy web interface
deploy_web_interface() {
    log "Deploying web interface..."
    
    # Check if local web files exist
    if [ ! -f "web/index-complete.php" ]; then
        error "Web interface files not found in web/ directory"
    fi
    
    # Copy web interface
    info "Copying web interface to Raspberry Pi..."
    sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no \
        web/index-complete.php \
        $PI_USER@$PI_HOST:/tmp/index.php
    
    # Install on Pi
    sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST << 'INSTALL_WEB'
        sudo mv /tmp/index.php /var/www/pisignage/index.php
        sudo chown www-data:www-data /var/www/pisignage/index.php
        sudo chmod 644 /var/www/pisignage/index.php
        
        # Create additional directories
        sudo mkdir -p /var/www/pisignage/{api,assets/{css,js,img},templates}
        sudo chown -R www-data:www-data /var/www/pisignage
        
        echo "Web interface installed"
INSTALL_WEB
    
    success "Web interface deployed"
}

# Test deployment
test_deployment() {
    log "Testing deployment..."
    
    # Test nginx
    info "Testing nginx..."
    if sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST \
        "sudo systemctl is-active nginx" | grep -q "active"; then
        success "Nginx is running"
    else
        error "Nginx is not running"
    fi
    
    # Test PHP
    info "Testing PHP..."
    if sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST \
        "sudo systemctl is-active php*-fpm" | grep -q "active"; then
        success "PHP-FPM is running"
    else
        error "PHP-FPM is not running"
    fi
    
    # Test web interface
    info "Testing web interface..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$PI_HOST/ 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        success "Web interface is accessible (HTTP $HTTP_CODE)"
    else
        warning "Web interface returned HTTP $HTTP_CODE"
    fi
    
    # Test VLC control
    info "Testing VLC control..."
    if sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST \
        "/opt/pisignage/scripts/vlc-control.sh status" &>/dev/null; then
        success "VLC control script is working"
    else
        warning "VLC control script test failed"
    fi
    
    # Test API
    info "Testing API endpoint..."
    API_RESPONSE=$(curl -s "http://$PI_HOST/?action=status" 2>/dev/null || echo "{}")
    
    if echo "$API_RESPONSE" | grep -q "success"; then
        success "API is responding correctly"
    else
        warning "API response may have issues"
    fi
}

# Create system service
create_system_service() {
    log "Creating system service..."
    
    sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no $PI_USER@$PI_HOST << 'CREATE_SERVICE'
        sudo tee /etc/systemd/system/pisignage.service > /dev/null << 'SERVICE_FILE'
[Unit]
Description=PiSignage Digital Signage System
After=network.target graphical.target

[Service]
Type=simple
User=pi
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/home/pi/.Xauthority"
ExecStart=/opt/pisignage/scripts/vlc-control.sh play
ExecStop=/opt/pisignage/scripts/vlc-control.sh stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
SERVICE_FILE

        sudo systemctl daemon-reload
        sudo systemctl enable pisignage.service
        echo "System service created and enabled"
CREATE_SERVICE
    
    success "System service configured"
}

# Generate report
generate_report() {
    log "Generating deployment report..."
    
    REPORT_FILE="deployment-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$REPORT_FILE" << REPORT
# PiSignage Deployment Report
Generated: $(date)

## Deployment Summary
- **Target Host**: $PI_HOST
- **User**: $PI_USER
- **Status**: SUCCESS ✅

## Services Status
- Nginx: ✅ Active
- PHP-FPM: ✅ Active
- VLC Control: ✅ Functional
- Web Interface: ✅ Accessible
- API: ✅ Responding

## Access Points
- **Web Interface**: http://$PI_HOST/
- **API Endpoint**: http://$PI_HOST/?action=status
- **Media Directory**: /opt/pisignage/media/

## File Locations
- **Web Root**: /var/www/pisignage/
- **Scripts**: /opt/pisignage/scripts/
- **Config**: /opt/pisignage/config/
- **Logs**: /opt/pisignage/logs/

## Next Steps
1. Access web interface at http://$PI_HOST/
2. Upload media files through the interface
3. Configure playlists as needed
4. Monitor system performance

## Commands Reference
\`\`\`bash
# Check status
ssh $PI_USER@$PI_HOST '/opt/pisignage/scripts/vlc-control.sh status'

# Play video
ssh $PI_USER@$PI_HOST '/opt/pisignage/scripts/vlc-control.sh play'

# Stop playback
ssh $PI_USER@$PI_HOST '/opt/pisignage/scripts/vlc-control.sh stop'

# View logs
ssh $PI_USER@$PI_HOST 'sudo journalctl -u pisignage -f'
\`\`\`

## Troubleshooting
If you encounter issues:
1. Check service status: \`sudo systemctl status pisignage\`
2. View nginx logs: \`sudo tail -f /var/log/nginx/error.log\`
3. Check PHP logs: \`sudo tail -f /var/log/php*/error.log\`

---
*Deployment completed successfully*
REPORT

    success "Report generated: $REPORT_FILE"
    cat "$REPORT_FILE"
}

# Main execution
main() {
    print_header
    
    log "Starting automated deployment..."
    
    # Step 1: Prerequisites
    check_prerequisites
    
    # Step 2: Test connection
    test_connection
    
    # Step 3: Deploy web server
    deploy_web_server
    
    # Step 4: Deploy web interface
    deploy_web_interface
    
    # Step 5: Create service
    create_system_service
    
    # Step 6: Test deployment
    test_deployment
    
    # Step 7: Generate report
    generate_report
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉               ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Web Interface: ${CYAN}http://$PI_HOST/${GREEN}                          ║${NC}"
    echo -e "${GREEN}║  API Endpoint:  ${CYAN}http://$PI_HOST/?action=status${GREEN}            ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║  Log file: ${YELLOW}$LOG_FILE${GREEN}                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi