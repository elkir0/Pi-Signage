#!/bin/bash

# PiSignage 2.0 - Installation Script for Next.js Version
# This script installs the modern Next.js based PiSignage system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/opt/pisignage"

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}     PiSignage 2.0 - Modern Installation        ${NC}"
echo -e "${GREEN}=================================================${NC}"

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ]; then
    echo -e "${YELLOW}Warning: Not running on a Raspberry Pi${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "\n${GREEN}1. Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

echo -e "\n${GREEN}2. Installing Node.js 20...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo -e "\n${GREEN}3. Installing system dependencies...${NC}"
apt-get install -y \
    git \
    vlc \
    ffmpeg \
    nginx \
    build-essential \
    python3-pip \
    ufw \
    curl \
    wget

echo -e "\n${GREEN}4. Installing PM2 process manager...${NC}"
npm install -g pm2

echo -e "\n${GREEN}5. Cloning PiSignage repository...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    echo "Backing up existing installation..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%s)"
fi

git clone https://github.com/elkir0/Pi-Signage.git "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo -e "\n${GREEN}6. Installing Node.js dependencies...${NC}"
npm install --production

echo -e "\n${GREEN}7. Building Next.js application...${NC}"
npm run build

echo -e "\n${GREEN}8. Setting up environment...${NC}"
cat > .env.local << EOF
# PiSignage 2.0 Environment Configuration
NODE_ENV=production
NEXT_PUBLIC_API_URL=http://localhost:3000/api
NEXT_PUBLIC_WS_URL=ws://localhost:3000

# Media Storage
MEDIA_PATH=/opt/pisignage/media
PLAYLISTS_PATH=/opt/pisignage/playlists
THUMBNAILS_PATH=/opt/pisignage/public/thumbnails

# VLC Configuration
VLC_HTTP_PORT=8080
VLC_HTTP_PASSWORD=vlc
EOF

echo -e "\n${GREEN}9. Creating required directories...${NC}"
mkdir -p /opt/pisignage/media
mkdir -p /opt/pisignage/playlists
mkdir -p /opt/pisignage/public/thumbnails
mkdir -p /opt/pisignage/logs

echo -e "\n${GREEN}10. Setting permissions...${NC}"
chown -R www-data:www-data /opt/pisignage
chmod -R 755 /opt/pisignage
chmod -R 777 /opt/pisignage/media
chmod -R 777 /opt/pisignage/playlists
chmod -R 777 /opt/pisignage/logs

echo -e "\n${GREEN}11. Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/pisignage << 'NGINX'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    client_max_body_size 500M;
}
NGINX

ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo -e "\n${GREEN}12. Setting up PM2 service...${NC}"
cd /opt/pisignage
pm2 start npm --name "pisignage" -- start
pm2 save
pm2 startup systemd -u root --hp /root

echo -e "\n${GREEN}13. Configuring firewall...${NC}"
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 3000/tcp
ufw --force enable

echo -e "\n${GREEN}14. Setting up VLC...${NC}"
mkdir -p /home/pi/.config/vlc
cat > /home/pi/.config/vlc/vlcrc << 'VLC'
[main]
intf=http
http-host=0.0.0.0
http-port=8080
http-password=vlc
VLC

echo -e "\n${GREEN}15. Creating system service...${NC}"
cat > /etc/systemd/system/pisignage-vlc.service << 'SERVICE'
[Unit]
Description=PiSignage VLC Media Player
After=network.target

[Service]
Type=simple
User=pi
ExecStart=/usr/bin/vlc --intf http --http-host 0.0.0.0 --http-port 8080 --http-password vlc --fullscreen --no-video-title-show --loop /opt/pisignage/media/
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable pisignage-vlc
systemctl start pisignage-vlc

# Get IP address
IP_ADDRESS=$(hostname -I | cut -d' ' -f1)

echo -e "\n${GREEN}=================================================${NC}"
echo -e "${GREEN}     Installation Complete!                     ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo -e "\n${GREEN}Access PiSignage at:${NC}"
echo -e "  ${YELLOW}http://${IP_ADDRESS}${NC}"
echo -e "\n${GREEN}Commands:${NC}"
echo -e "  pm2 status          - Check application status"
echo -e "  pm2 logs pisignage  - View application logs"
echo -e "  pm2 restart pisignage - Restart application"
echo -e "\n${GREEN}Default credentials:${NC}"
echo -e "  No authentication required for local access"
echo -e "\n${YELLOW}Reboot recommended to ensure all services start properly${NC}"
echo -e "\n${GREEN}Thank you for using PiSignage 2.0!${NC}\n"