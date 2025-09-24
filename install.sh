#!/bin/bash

# PiSignage v0.8.0 - Installation complète pour Raspberry Pi OS Bookworm
# Compatible avec Raspberry Pi 3/4/5 - Debian Bookworm 64-bit

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║        PiSignage v0.8.0 - Installation Bookworm           ║"
echo "║      Système d'affichage digital pour Raspberry Pi        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Vérification root
if [[ $EUID -eq 0 ]]; then
   echo "⚠️  Ne pas exécuter en tant que root. Utilisez l'utilisateur pi."
   exit 1
fi

# 1. Mise à jour système
echo "📦 [1/10] Mise à jour système..."
sudo apt-get update
sudo apt-get upgrade -y

# 2. Installation packages essentiels
echo "📦 [2/10] Installation des packages..."
sudo apt-get install -y \
    nginx \
    php8.2-fpm php8.2-cli php8.2-curl php8.2-mbstring php8.2-json php8.2-xml \
    vlc \
    git curl wget \
    python3-pip \
    imagemagick \
    scrot \
    nodejs npm

# 3. Installation yt-dlp
echo "📦 [3/10] Installation yt-dlp..."
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

# 4. Installation Puppeteer (pour tests)
echo "📦 [4/10] Installation Puppeteer pour tests..."
npm install puppeteer

# 5. Structure PiSignage
echo "📁 [5/10] Création de la structure..."
sudo mkdir -p /opt/pisignage/{web/api,scripts,media,logs,config}
sudo chown -R www-data:www-data /opt/pisignage

# 6. Configuration PHP (upload 100MB)
echo "⚙️  [6/10] Configuration PHP..."
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/8.2/cli/php.ini
sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/8.2/fpm/php.ini

# 7. Configuration Nginx
echo "⚙️  [7/10] Configuration Nginx..."
sudo tee /etc/nginx/sites-available/pisignage > /dev/null << 'NGINX_CONFIG'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php;

    server_name _;

    client_max_body_size 100M;
    client_body_timeout 300s;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_read_timeout 300;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex off;
    }
}
NGINX_CONFIG

# 8. Activer site Nginx
echo "⚙️  [8/10] Activation du site..."
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t

# 9. Cloner le repository GitHub
echo "📥 [9/10] Téléchargement du projet..."
cd /tmp
rm -rf Pi-Signage
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Copier les fichiers
sudo cp -r web/* /opt/pisignage/web/
sudo cp -r scripts/* /opt/pisignage/scripts/
sudo cp -r config/* /opt/pisignage/config/ 2>/dev/null || true

# 10. Permissions et scripts exécutables
echo "🔐 [10/10] Configuration des permissions..."
sudo chown -R www-data:www-data /opt/pisignage
sudo chmod -R 755 /opt/pisignage
sudo chmod +x /opt/pisignage/scripts/*.sh
sudo usermod -a -G video www-data

# 11. Service systemd pour VLC
echo "⚙️  Création du service systemd..."
sudo tee /etc/systemd/system/pisignage-vlc.service > /dev/null << 'SERVICE_END'
[Unit]
Description=PiSignage VLC Player
After=graphical.target

[Service]
Type=simple
User=pi
Environment="DISPLAY=:0"
ExecStart=/opt/pisignage/scripts/vlc-control.sh start
ExecStop=/opt/pisignage/scripts/vlc-control.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SERVICE_END

# 12. Redémarrage des services
echo "🔄 Redémarrage des services..."
sudo systemctl restart php8.2-fpm
sudo systemctl restart nginx
sudo systemctl daemon-reload
sudo systemctl enable pisignage-vlc

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║               ✅ INSTALLATION TERMINÉE !                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📌 Interface web : http://$(hostname -I | cut -d' ' -f1)/"
echo "📂 Média : /opt/pisignage/media/"
echo "📊 Logs : /opt/pisignage/logs/pisignage.log"
echo ""
echo "🔄 Pour démarrer VLC : sudo systemctl start pisignage-vlc"
echo "⚠️  Redémarrage recommandé : sudo reboot"
