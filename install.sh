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
echo "📦 [1/9] Mise à jour système..."
sudo apt-get update
sudo apt-get upgrade -y

# 2. Installation packages essentiels
echo "📦 [2/9] Installation des packages..."
sudo apt-get install -y \
    nginx \
    php8.2-fpm php8.2-cli php8.2-curl php8.2-mbstring php8.2-json php8.2-xml php8.2-sqlite3 \
    mpv vlc \
    socat jq \
    git curl wget \
    imagemagick \
    scrot \
    fbi \
    fbgrab \
    libpng-dev \
    build-essential \
    cmake

# 3. Installation yt-dlp et raspi2png
echo "📦 [3/9] Installation yt-dlp et outils de capture..."
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

# Installation raspi2png pour capture hardware sur Pi
if [[ -f /proc/device-tree/model ]]; then
    echo "🎯 Détection Raspberry Pi - Installation raspi2png..."
    cd /tmp
    rm -rf raspi2png
    git clone https://github.com/AndrewFromMelbourne/raspi2png.git
    cd raspi2png
    mkdir -p build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    echo "✅ raspi2png installé"
    cd /tmp
fi

# 4. Structure PiSignage
echo "📁 [4/9] Création de la structure..."
sudo mkdir -p /opt/pisignage/{web/api,scripts,media,logs,config,screenshots}
sudo mkdir -p /dev/shm/pisignage-screenshots
sudo chown -R www-data:www-data /opt/pisignage
sudo chown www-data:www-data /dev/shm/pisignage-screenshots

# 5. Configuration PHP (upload 100MB)
echo "⚙️  [5/9] Configuration PHP..."
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/8.2/cli/php.ini
sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/8.2/fpm/php.ini

# 6. Configuration Nginx
echo "⚙️  [6/9] Configuration Nginx..."
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

# 7. Activer site Nginx
echo "⚙️  [7/9] Activation du site..."
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t

# 8. Cloner le repository GitHub
echo "📥 [8/9] Téléchargement du projet..."
cd /tmp
rm -rf Pi-Signage
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Copier les fichiers
sudo cp -r web/* /opt/pisignage/web/
sudo cp -r scripts/* /opt/pisignage/scripts/
sudo cp -r config/* /opt/pisignage/config/ 2>/dev/null || true

# 9. Permissions et scripts exécutables
echo "🔐 [9/9] Configuration des permissions..."
sudo chown -R www-data:www-data /opt/pisignage
sudo chmod -R 755 /opt/pisignage
sudo chmod +x /opt/pisignage/scripts/*.sh
sudo usermod -a -G video www-data

# 10. Configuration dual-player et service systemd
echo "⚙️  Configuration dual-player..."

# Créer configuration dual-player par défaut
sudo mkdir -p /opt/pisignage/config
sudo tee /opt/pisignage/config/player-config.json > /dev/null << 'CONFIG_END'
{
  "player": {
    "default": "mpv",
    "current": "mpv",
    "available": ["mpv", "vlc"]
  },
  "mpv": {
    "enabled": true,
    "version": "auto",
    "binary": "/usr/bin/mpv",
    "config_path": "/home/pi/.config/mpv/mpv.conf",
    "socket": "/tmp/mpv-socket",
    "log_file": "/opt/pisignage/logs/mpv.log",
    "optimizations": {
      "pi3": {
        "hwdec": "mmal-copy",
        "vo": "gpu",
        "gpu-context": "drm",
        "cache": "yes",
        "demuxer-max-bytes": "50MiB"
      },
      "pi4": {
        "hwdec": "drm-copy",
        "vo": "gpu",
        "gpu-context": "drm",
        "cache": "yes",
        "demuxer-max-bytes": "100MiB",
        "scale": "ewa_lanczossharp"
      }
    }
  },
  "vlc": {
    "enabled": true,
    "version": "auto",
    "binary": "/usr/bin/cvlc",
    "config_path": "/home/pi/.config/vlc/vlcrc",
    "http_port": 8080,
    "http_password": "signage123",
    "log_file": "/opt/pisignage/logs/vlc.log",
    "optimizations": {
      "pi3": {
        "vout": "mmal_xsplitter",
        "codec": "mmal",
        "h264-fps": 30,
        "file-caching": 2000
      },
      "pi4": {
        "vout": "drm",
        "avcodec-hw": "v4l2m2m",
        "file-caching": 2000,
        "network-caching": 3000
      }
    }
  },
  "system": {
    "pi_model": "auto",
    "display": ":0",
    "audio_device": "alsa/default:CARD=vc4hdmi0",
    "fallback_image": "/opt/pisignage/media/fallback-logo.jpg",
    "autostart": true,
    "watchdog": true
  }
}
CONFIG_END

# Service systemd pour player unifié
echo "⚙️  Création du service systemd unifié..."
sudo tee /etc/systemd/system/pisignage-player.service > /dev/null << 'SERVICE_END'
[Unit]
Description=PiSignage Unified Player (VLC/MPV)
After=graphical.target

[Service]
Type=simple
User=pi
Environment="DISPLAY=:0"
Environment="HOME=/home/pi"
ExecStartPre=/bin/sleep 5
ExecStart=/opt/pisignage/scripts/player-manager.sh start
ExecStop=/opt/pisignage/scripts/player-manager.sh stop
ExecStopPost=/opt/pisignage/scripts/unified-player-control.sh fallback
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SERVICE_END

# 11. Configuration et initialisation des players
echo "⚙️  Configuration des players..."

# Initialiser la configuration VLC et MPV
sudo -u pi /opt/pisignage/scripts/player-manager.sh setup

# 12. Redémarrage des services
echo "🔄 Redémarrage des services..."
sudo systemctl restart php8.2-fpm
sudo systemctl restart nginx
sudo systemctl daemon-reload

# Disable old service if exists
sudo systemctl stop pisignage-mpv 2>/dev/null || true
sudo systemctl disable pisignage-mpv 2>/dev/null || true

# Enable new unified service
sudo systemctl enable pisignage-player

# 12. Télécharger vidéo de test Big Buck Bunny 720p
echo "📥 Téléchargement vidéo de test..."
if [ ! -f "/opt/pisignage/media/BigBuckBunny_720p.mp4" ]; then
    wget -q --show-progress -O /opt/pisignage/media/BigBuckBunny_720p.mp4 \
        "http://distribution.bbb3d.renderfarming.net/video/mp4/bbb_sunflower_1080p_60fps_normal.mp4"
    sudo chown www-data:www-data /opt/pisignage/media/BigBuckBunny_720p.mp4
    echo "✅ Vidéo de test téléchargée"
else
    echo "✅ Vidéo de test déjà présente"
fi

# 13. Démarrer le player unifié avec la vidéo test
echo "🎬 Démarrage du player unifié (MPV par défaut)..."
sudo systemctl start pisignage-player

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║               ✅ INSTALLATION TERMINÉE !                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📌 Interface web : http://$(hostname -I | cut -d' ' -f1)/"
echo "📂 Média : /opt/pisignage/media/"
echo "📊 Logs : /opt/pisignage/logs/pisignage.log"
echo ""
echo "🔄 Contrôle du player : sudo systemctl start/stop/restart pisignage-player"
echo "🎛️  Basculement VLC/MPV : /opt/pisignage/scripts/player-manager.sh switch"
echo "⚠️  Redémarrage recommandé : sudo reboot"
