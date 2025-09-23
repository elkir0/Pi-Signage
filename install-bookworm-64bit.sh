#!/bin/bash
#############################################
# PiSignage v0.8.0 - Installation Script
# Pour Raspberry Pi OS Bookworm 64-bit
# VLC uniquement - Interface GOLDEN MASTER
#############################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   PiSignage v0.8.0 Installation       ║${NC}"
echo -e "${GREEN}║   Bookworm 64-bit + VLC Only          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"

# Check if running on Raspberry Pi OS Bookworm
if ! grep -q "bookworm" /etc/os-release; then
    echo -e "${RED}⚠️  ATTENTION: Ce script nécessite Raspberry Pi OS Bookworm${NC}"
    read -p "Continuer quand même? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" ]]; then
    echo -e "${YELLOW}⚠️  Architecture détectée: $ARCH (64-bit recommandé)${NC}"
fi

echo -e "\n${GREEN}📦 Étape 1/8: Mise à jour système...${NC}"
sudo apt update && sudo apt upgrade -y

echo -e "\n${GREEN}📦 Étape 2/8: Installation des dépendances...${NC}"
sudo apt install -y \
    nginx \
    php8.2-fpm \
    php8.2-cli \
    php8.2-common \
    php8.2-sqlite3 \
    php8.2-curl \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    vlc \
    vlc-plugin-base \
    vlc-plugin-video-output \
    git \
    ffmpeg \
    imagemagick \
    fbcat \
    sqlite3 \
    curl \
    wget \
    unzip \
    python3-pip \
    jq \
    htop

echo -e "\n${GREEN}📦 Étape 3/8: Installation yt-dlp...${NC}"
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

echo -e "\n${GREEN}📁 Étape 4/8: Création structure dossiers...${NC}"
sudo mkdir -p /opt/pisignage/{web,media,config,logs,scripts,screenshots,cache}
sudo mkdir -p /opt/pisignage/config/{playlists,schedules}
sudo mkdir -p /dev/shm/pisignage

echo -e "\n${GREEN}⚙️ Étape 5/8: Configuration Nginx...${NC}"
sudo tee /etc/nginx/sites-available/pisignage << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php index.html;

    server_name _;

    # PHP 8.2 configuration
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # API endpoints
    location /api/ {
        try_files $uri $uri/ =404;
    }

    # Media files
    location /media/ {
        alias /opt/pisignage/media/;
        autoindex on;
    }

    # Screenshots
    location /screenshots/ {
        alias /opt/pisignage/screenshots/;
        autoindex on;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    client_max_body_size 500M;
    client_body_timeout 600s;
}
EOF

sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

echo -e "\n${GREEN}⚙️ Étape 6/8: Configuration PHP 8.2...${NC}"
sudo tee /etc/php/8.2/fpm/conf.d/99-pisignage.ini << 'EOF'
upload_max_filesize = 500M
post_max_size = 500M
memory_limit = 256M
max_execution_time = 600
max_input_time = 600
file_uploads = On
allow_url_fopen = On
session.gc_maxlifetime = 1440
opcache.enable = 1
opcache.memory_consumption = 128
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
EOF

echo -e "\n${GREEN}🔧 Étape 7/8: Configuration VLC...${NC}"
sudo tee /opt/pisignage/scripts/vlc-start.sh << 'EOF'
#!/bin/bash
# VLC launcher optimized for Bookworm 64-bit

export DISPLAY=:0
export VLC_VERBOSE=0

# Kill any existing VLC
pkill -f vlc || true
sleep 1

# Start VLC with optimal settings for 64-bit
cvlc \
    --fullscreen \
    --no-video-title-show \
    --no-embedded-video \
    --no-keyboard-events \
    --no-mouse-events \
    --loop \
    --no-osd \
    --intf http \
    --http-password vlcpassword \
    --http-host 127.0.0.1 \
    --http-port 8080 \
    --vout mmal_vout \
    --mmal-display hdmi-1 \
    --mmal-layer 1 \
    --gain 1 \
    --aout alsa \
    --file-caching=1000 \
    --network-caching=1000 \
    --clock-jitter=0 \
    --drop-late-frames \
    --skip-frames \
    --avcodec-hw mmal \
    --codec mmal_codec,any \
    --prefetch-buffer-size=33554432 \
    --prefetch-read-size=16777216 \
    --file-buffer-size=33554432 \
    --h264-fps=30 \
    "$@" &

echo "VLC started with PID: $!"
EOF

sudo chmod +x /opt/pisignage/scripts/vlc-start.sh

echo -e "\n${GREEN}🚀 Étape 8/8: Configuration système...${NC}"

# GPU memory split for VLC
if ! grep -q "gpu_mem=" /boot/config.txt; then
    echo "gpu_mem=128" | sudo tee -a /boot/config.txt
fi

# Temperature management
if ! grep -q "temp_soft_limit=" /boot/config.txt; then
    echo "temp_soft_limit=65" | sudo tee -a /boot/config.txt
fi

# Performance optimizations
if ! grep -q "arm_freq=" /boot/config.txt; then
    cat << EOF | sudo tee -a /boot/config.txt

# PiSignage Performance Settings
arm_freq=1500
core_freq=500
h264_freq=500
v3d_freq=500
over_voltage=2
sdram_freq=500
force_turbo=0
EOF
fi

# Systemd service for PiSignage
sudo tee /etc/systemd/system/pisignage.service << 'EOF'
[Unit]
Description=PiSignage Digital Signage System
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/pisignage
ExecStart=/opt/pisignage/scripts/vlc-start.sh /opt/pisignage/media/
Restart=always
RestartSec=10
StandardOutput=append:/opt/pisignage/logs/vlc.log
StandardError=append:/opt/pisignage/logs/vlc_error.log

[Install]
WantedBy=multi-user.target
EOF

# Permissions
echo -e "\n${GREEN}🔐 Configuration des permissions...${NC}"
sudo chown -R www-data:www-data /opt/pisignage
sudo chmod -R 755 /opt/pisignage
sudo chmod -R 777 /opt/pisignage/screenshots
sudo chmod -R 777 /opt/pisignage/media
sudo chmod -R 777 /opt/pisignage/logs
sudo chmod -R 777 /dev/shm/pisignage

# Add www-data to video group for framebuffer access
sudo usermod -a -G video www-data

# Enable services
echo -e "\n${GREEN}🎯 Activation des services...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable nginx
sudo systemctl enable php8.2-fpm
sudo systemctl enable pisignage

# Restart services
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

echo -e "\n${GREEN}✅ Installation terminée !${NC}"
echo -e "${YELLOW}📝 Notes importantes:${NC}"
echo "  - Interface web: http://$(hostname -I | awk '{print $1}')"
echo "  - Dossier médias: /opt/pisignage/media"
echo "  - Logs: /opt/pisignage/logs"
echo "  - VLC HTTP: http://127.0.0.1:8080 (password: vlcpassword)"
echo ""
echo -e "${YELLOW}⚠️  Redémarrage recommandé pour appliquer tous les paramètres${NC}"
echo -e "${GREEN}Tapez 'sudo reboot' pour redémarrer${NC}"