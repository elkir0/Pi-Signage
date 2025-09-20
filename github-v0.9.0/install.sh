#!/bin/bash

# Pi-Signage v0.9.0 - Installation Script
# https://github.com/elkir0/Pi-Signage

set -e

VERSION="0.9.0"
INSTALL_DIR="/opt/pisignage"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Pi-Signage v${VERSION} Installation        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Vérifications
if [ "$EUID" -ne 0 ]; then
   echo -e "${RED}❌ Ce script doit être exécuté en root (sudo)${NC}"
   exit 1
fi

if [ ! -f /proc/device-tree/model ]; then
    echo -e "${YELLOW}⚠️ Attention: Ce script est optimisé pour Raspberry Pi${NC}"
fi

echo -e "${YELLOW}Cette installation va configurer Pi-Signage v${VERSION}${NC}"
echo -e "${YELLOW}Temps estimé: 5 minutes${NC}"
echo ""
read -p "Continuer? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Sauvegarde config boot
if [ ! -f /boot/firmware/config.txt.backup ]; then
    cp /boot/firmware/config.txt /boot/firmware/config.txt.backup 2>/dev/null || true
fi

# Installation dépendances
echo -e "${BLUE}📦 Installation des dépendances...${NC}"
apt-get update
apt-get install -y --no-install-recommends \
    vlc vlc-plugin-base \
    nginx php-fpm php-gd php-curl php-json \
    xserver-xorg-core xserver-xorg-video-fbdev \
    xinit x11-xserver-utils unclutter \
    ffmpeg git bc

# Structure
echo -e "${BLUE}📁 Création de la structure...${NC}"
mkdir -p ${INSTALL_DIR}/{scripts,web/api,config,media,logs}
chown -R pi:pi ${INSTALL_DIR}

# Copie des fichiers
echo -e "${BLUE}📋 Installation des fichiers...${NC}"
cp -r scripts/* ${INSTALL_DIR}/scripts/ 2>/dev/null || true
cp -r web/* ${INSTALL_DIR}/web/ 2>/dev/null || true
cp -r config/* ${INSTALL_DIR}/config/ 2>/dev/null || true

# Configuration auto-login
echo -e "${BLUE}🔧 Configuration auto-démarrage...${NC}"
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AUTO'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I $TERM
AUTO

# Script de démarrage vidéo
cat > /home/pi/start-video.sh << 'VIDEO'
#!/bin/bash
sleep 3
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
    xset s off 2>/dev/null
    xset -dpms 2>/dev/null
    xset s noblank 2>/dev/null
    unclutter -idle 0.5 -root &
fi
exec cvlc --intf dummy --fullscreen --no-video-title-show --loop --quiet ${INSTALL_DIR}/media/*.mp4
VIDEO
chmod +x /home/pi/start-video.sh

# xinitrc
cat > /home/pi/.xinitrc << 'XINIT'
#!/bin/bash
exec /home/pi/start-video.sh
XINIT
chmod +x /home/pi/.xinitrc

# Auto-start X
cat > /home/pi/.bash_profile << 'PROFILE'
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    exec startx
fi
PROFILE

# Configuration nginx
echo -e "${BLUE}🌐 Configuration serveur web...${NC}"
cat > /etc/nginx/sites-enabled/default << 'NGINX'
server {
    listen 80 default_server;
    root /opt/pisignage/web;
    index index.php index.html;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
}
NGINX

systemctl restart nginx php*-fpm

# Permissions
chown -R www-data:www-data ${INSTALL_DIR}/web
chown -R www-data:www-data ${INSTALL_DIR}/media
chmod -R 775 ${INSTALL_DIR}/media

# Vidéo de test
if [ ! -f ${INSTALL_DIR}/media/*.mp4 ]; then
    echo -e "${BLUE}📹 Création vidéo de test...${NC}"
    ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30:duration=10 \
           -c:v h264 -b:v 2M -pix_fmt yuv420p \
           ${INSTALL_DIR}/media/test.mp4 -y 2>/dev/null
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ Installation terminée avec succès!      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Interface web:${NC} http://$(hostname -I | cut -d' ' -f1)/"
echo ""
echo -e "${YELLOW}Redémarrez pour démarrer la vidéo:${NC}"
echo -e "${GREEN}sudo reboot${NC}"
echo ""
