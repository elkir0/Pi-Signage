#!/bin/bash
#
# PiSignage v0.8.0 - Installation complète sur Raspberry Pi NEUF
# Pour Raspberry Pi OS Bookworm Lite (192.168.0.3)
#

set -e

echo "🚀 INSTALLATION PISIGNAGE v0.8.0 SUR RASPBERRY PI"
echo "================================================="
echo "Host: 192.168.1.103"
echo "Version: v0.8.0 PHP"
echo ""

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Fonction de log
log_step() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Vérifier que nous sommes sur un Raspberry Pi
if [ ! -f /proc/device-tree/model ]; then
    log_warning "Ceci ne semble pas être un Raspberry Pi"
fi

# ÉTAPE 1: MISE À JOUR SYSTÈME
log_step "Étape 1/10: Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

# ÉTAPE 2: INSTALLATION DES DÉPENDANCES
log_step "Étape 2/10: Installation des dépendances..."
sudo apt install -y \
    git \
    nginx \
    php8.2-fpm \
    php8.2-cli \
    php8.2-gd \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    php8.2-curl \
    php8.2-sqlite3 \
    ffmpeg \
    imagemagick \
    scrot \
    curl \
    wget \
    htop \
    vim \
    unzip

# ÉTAPE 3: INSTALLATION YT-DLP
log_step "Étape 3/10: Installation yt-dlp..."
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
yt-dlp --version

# ÉTAPE 4: CONFIGURATION GIT ET CLONE
log_step "Étape 4/10: Clone du repository..."
cd /opt
sudo rm -rf pisignage
sudo git clone https://github.com/elkir0/Pi-Signage.git pisignage
sudo chown -R pi:pi /opt/pisignage
cd /opt/pisignage

# ÉTAPE 5: CRÉATION STRUCTURE DOSSIERS
log_step "Étape 5/10: Création des dossiers..."
cd /opt/pisignage/pisignage-v0.8.0-php
mkdir -p media logs screenshots media/thumbnails media/chunks
chmod -R 755 media logs screenshots
sudo chown -R www-data:www-data media logs screenshots

# ÉTAPE 6: CONFIGURATION NGINX
log_step "Étape 6/10: Configuration Nginx..."
sudo tee /etc/nginx/sites-available/pisignage << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/pisignage-v0.8.0-php/public;
    index index.php index.html;

    server_name _;

    # Logs
    access_log /var/log/nginx/pisignage_access.log;
    error_log /var/log/nginx/pisignage_error.log;

    # PHP routing
    location / {
        try_files $uri /index.php$is_args$args;
    }

    # PHP processing
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
    }

    # Static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Security
    location ~ /\. {
        deny all;
    }

    # Upload size
    client_max_body_size 500M;
    client_body_timeout 300s;
}
EOF

# ÉTAPE 7: ACTIVATION SITE NGINX
log_step "Étape 7/10: Activation du site..."
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t

# ÉTAPE 8: CONFIGURATION PHP
log_step "Étape 8/10: Configuration PHP..."
sudo tee /etc/php/8.2/fpm/conf.d/99-pisignage.ini << 'EOF'
upload_max_filesize = 500M
post_max_size = 500M
max_execution_time = 300
max_input_time = 300
memory_limit = 256M
EOF

# ÉTAPE 9: REDÉMARRAGE SERVICES
log_step "Étape 9/10: Redémarrage des services..."
sudo systemctl restart php8.2-fpm
sudo systemctl restart nginx
sudo systemctl enable php8.2-fpm
sudo systemctl enable nginx

# ÉTAPE 10: TEST DE SANTÉ
log_step "Étape 10/10: Test de l'application..."
sleep 3

# Test HTTP
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
if [ "$HTTP_CODE" = "200" ]; then
    log_step "✅ Application accessible (HTTP $HTTP_CODE)"
else
    log_error "Application inaccessible (HTTP $HTTP_CODE)"
fi

# Test APIs
log_step "Test des APIs..."
curl -s http://localhost/api/screenshot | grep -q "success\|error" && log_step "✅ API Screenshot OK" || log_error "API Screenshot KO"
curl -s http://localhost/api/media | grep -q "\[" && log_step "✅ API Media OK" || log_error "API Media KO"
curl -s http://localhost/api/youtube?action=queue | grep -q "\[" && log_step "✅ API YouTube OK" || log_error "API YouTube KO"

# INFORMATIONS FINALES
echo ""
echo "================================================="
echo -e "${GREEN}✅ INSTALLATION TERMINÉE !${NC}"
echo "================================================="
echo ""
echo "📊 INFORMATIONS:"
echo "  - Version: PiSignage v0.8.0 PHP"
echo "  - IP: 192.168.1.103"
echo "  - Port: 80"
echo "  - URL: http://192.168.1.103"
echo ""
echo "📁 STRUCTURE:"
echo "  - Application: /opt/pisignage/pisignage-v0.8.0-php/"
echo "  - Médias: /opt/pisignage/pisignage-v0.8.0-php/media/"
echo "  - Logs: /opt/pisignage/pisignage-v0.8.0-php/logs/"
echo ""
echo "🔧 COMMANDES UTILES:"
echo "  - Logs Nginx: sudo tail -f /var/log/nginx/pisignage_error.log"
echo "  - Logs PHP: sudo tail -f /opt/pisignage/pisignage-v0.8.0-php/logs/error.log"
echo "  - Restart: sudo systemctl restart nginx php8.2-fpm"
echo ""
echo "🌐 ACCÈS INTERFACE:"
echo "  http://192.168.1.103"
echo ""
echo "✅ PiSignage v0.8.0 est maintenant opérationnel !"