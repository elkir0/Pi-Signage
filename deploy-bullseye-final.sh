#!/bin/bash

# PiSignage v0.9.0 - Déploiement Final sur Raspberry Pi OS Bullseye
# Optimisé pour Chromium Kiosk 30+ FPS
# IP cible: 192.168.1.103

set -e

# Configuration
PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"
VERSION="0.9.0"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     PiSignage v${VERSION} - Déploiement Bullseye Final     ║"
echo "║         Chromium Kiosk Optimisé 30+ FPS                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Fonctions utilitaires
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_info() { echo -e "${YELLOW}ℹ️  $1${NC}"; }

# Vérification connexion
echo "🔍 Vérification connexion au Raspberry Pi..."
if ping -c 1 $PI_IP > /dev/null 2>&1; then
    log_success "Pi accessible à $PI_IP"
else
    log_error "Pi non accessible à $PI_IP"
    exit 1
fi

# Test SSH
if sshpass -p "$PI_PASS" ssh -o ConnectTimeout=5 $PI_USER@$PI_IP "echo 'OK'" > /dev/null 2>&1; then
    log_success "Connexion SSH établie"
else
    log_error "Connexion SSH impossible"
    exit 1
fi

# Vérification Bullseye
log_info "Vérification OS..."
OS_VERSION=$(sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP "cat /etc/os-release | grep VERSION_CODENAME | cut -d= -f2")
if [[ "$OS_VERSION" == "bullseye" ]]; then
    log_success "Raspberry Pi OS Bullseye détecté"
else
    log_error "OS incorrect: $OS_VERSION (Bullseye requis)"
    echo "Installer Raspberry Pi OS Bullseye 32-bit d'abord"
    exit 1
fi

# Création script d'installation distant
log_info "Création du script d'installation..."
cat << 'INSTALL_SCRIPT' > /tmp/install-pisignage.sh
#!/bin/bash

# Installation PiSignage v0.9.0 sur Bullseye
set -e

VERSION="0.9.0"
INSTALL_DIR="/opt/pisignage"

echo "📦 Installation PiSignage v${VERSION}..."

# 1. Mise à jour système
echo "1/8 - Mise à jour système..."
sudo apt-get update
sudo apt-get upgrade -y

# 2. Installation packages (PHP 7.4 pour Bullseye)
echo "2/8 - Installation packages..."
sudo apt-get install -y \
    nginx \
    php7.4-fpm php7.4-cli php7.4-curl php7.4-mbstring php7.4-json \
    chromium-browser chromium-codecs-ffmpeg chromium-codecs-ffmpeg-extra \
    xorg openbox lightdm \
    unclutter \
    scrot \
    git curl wget htop \
    imagemagick

# 3. Configuration GPU pour Bullseye (CRITICAL)
echo "3/8 - Configuration GPU..."
sudo tee /tmp/config-gpu.txt << 'EOF'

# PiSignage GPU Configuration - Bullseye
gpu_mem=128
dtoverlay=vc4-fkms-v3d
hdmi_group=2
hdmi_mode=85
hdmi_drive=2
disable_overscan=1
EOF

# Ajouter seulement si pas déjà présent
if ! grep -q "PiSignage GPU Configuration" /boot/config.txt; then
    sudo cat /tmp/config-gpu.txt | sudo tee -a /boot/config.txt
fi

# 4. Création structure
echo "4/8 - Création structure..."
sudo mkdir -p $INSTALL_DIR/{web,scripts,config,media,logs,screenshots,services}
sudo chown -R pi:pi $INSTALL_DIR

# 5. Configuration nginx
echo "5/8 - Configuration nginx..."
sudo tee /etc/nginx/sites-available/pisignage << 'NGINX_CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php index.html;

    server_name _;

    # Compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex on;
    }

    location /screenshots {
        alias /opt/pisignage/screenshots;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
}
NGINX_CONF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/

# 6. Service nginx persistent (résout le problème /var/log/nginx)
echo "6/8 - Service nginx persistent..."
sudo tee /etc/systemd/system/nginx-prepare.service << 'EOF'
[Unit]
Description=Prepare nginx directories
Before=nginx.service

[Service]
Type=oneshot
ExecStart=/bin/mkdir -p /var/log/nginx /opt/pisignage/logs
ExecStart=/bin/chown -R www-data:adm /var/log/nginx
RemainAfterExit=yes

[Install]
RequiredBy=nginx.service
EOF

sudo systemctl enable nginx-prepare.service

# 7. Configuration autologin LightDM
echo "7/8 - Configuration autologin..."
sudo tee /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
user-session=openbox
EOF

# 8. Script de démarrage Chromium optimisé
echo "8/8 - Script Chromium..."
tee $INSTALL_DIR/scripts/start-chromium-kiosk.sh << 'CHROMIUM_SCRIPT'
#!/bin/bash

# PiSignage Chromium Kiosk - Optimisé 30+ FPS Bullseye

# Attendre X11
sleep 10

# Variables
URL="http://localhost/player.html"
CHROME_FLAGS=(
    --kiosk
    --noerrdialogs
    --disable-infobars
    --no-first-run
    --disable-translate

    # GPU Acceleration Bullseye
    --enable-gpu
    --enable-gpu-rasterization
    --enable-accelerated-video-decode
    --use-gl=egl
    --ignore-gpu-blocklist

    # Performance
    --enable-hardware-overlays=single-fullscreen
    --disable-software-rasterizer
    --disable-background-timer-throttling

    # Mémoire
    --memory-pressure-off
    --max_old_space_size=512

    # Autoplay
    --autoplay-policy=no-user-gesture-required
)

# Arrêt ancien processus
pkill -f chromium

# Environnement
export DISPLAY=:0

# Lancement avec monitoring
while true; do
    chromium-browser "${CHROME_FLAGS[@]}" "$URL"
    sleep 5
done
CHROMIUM_SCRIPT

chmod +x $INSTALL_DIR/scripts/start-chromium-kiosk.sh

# Autostart OpenBox
mkdir -p /home/pi/.config/openbox
tee /home/pi/.config/openbox/autostart << 'EOF'
# Désactiver économiseur écran
xset s off -dpms
xset s noblank

# Cacher curseur
unclutter -idle 1 &

# Lancer Chromium
/opt/pisignage/scripts/start-chromium-kiosk.sh &
EOF

echo "✅ Installation complète!"
INSTALL_SCRIPT

# Copie et exécution du script
log_info "Copie du script d'installation..."
sshpass -p "$PI_PASS" scp /tmp/install-pisignage.sh $PI_USER@$PI_IP:/tmp/

log_info "Exécution de l'installation (peut prendre 5-10 minutes)..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP "chmod +x /tmp/install-pisignage.sh && /tmp/install-pisignage.sh"

# Création interface web
log_info "Déploiement interface web..."
cat << 'HTML_PLAYER' > /tmp/player.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage Player v0.9.0</title>
    <style>
        * { margin: 0; padding: 0; overflow: hidden; }
        body { background: #000; }
        video {
            width: 100vw;
            height: 100vh;
            object-fit: cover;
        }
    </style>
</head>
<body>
    <video id="player" autoplay loop muted playsinline>
        <source src="/media/demo.mp4" type="video/mp4">
    </video>
    <script>
        const video = document.getElementById('player');

        // Force GPU acceleration
        video.style.transform = 'translateZ(0)';
        video.style.willChange = 'transform';

        // Auto-restart on error
        video.addEventListener('error', () => {
            setTimeout(() => {
                video.load();
                video.play();
            }, 1000);
        });

        // Loop fallback
        video.addEventListener('ended', () => {
            video.currentTime = 0;
            video.play();
        });

        // Start playback
        video.play().catch(e => {
            console.log('Autoplay blocked, retrying...');
            setTimeout(() => video.play(), 1000);
        });
    </script>
</body>
</html>
HTML_PLAYER

# Interface d'administration
cat << 'PHP_ADMIN' > /tmp/index.php
<?php
// PiSignage v0.9.0 - Interface Administration
header('Content-Type: text/html; charset=UTF-8');

$version = "0.9.0";
$cpu_usage = sys_getloadavg()[0];
$memory = round(memory_get_usage() / 1024 / 1024, 2);
$temp = rtrim(shell_exec("vcgencmd measure_temp | cut -d= -f2"));
?>
<!DOCTYPE html>
<html>
<head>
    <title>PiSignage v<?=$version?> - Admin</title>
    <meta charset="UTF-8">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        h1 { margin-bottom: 20px; }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat {
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        .stat h3 { font-size: 14px; opacity: 0.8; }
        .stat p { font-size: 24px; margin-top: 5px; }
        .actions {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        button {
            padding: 12px 24px;
            background: white;
            color: #764ba2;
            border: none;
            border-radius: 5px;
            font-weight: 600;
            cursor: pointer;
        }
        button:hover { opacity: 0.9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎬 PiSignage v<?=$version?> - Bullseye Edition</h1>

        <div class="stats">
            <div class="stat">
                <h3>CPU Usage</h3>
                <p><?=$cpu_usage?>%</p>
            </div>
            <div class="stat">
                <h3>Memory</h3>
                <p><?=$memory?> MB</p>
            </div>
            <div class="stat">
                <h3>Temperature</h3>
                <p><?=$temp?></p>
            </div>
            <div class="stat">
                <h3>Status</h3>
                <p>✅ Running</p>
            </div>
        </div>

        <div class="actions">
            <button onclick="location.href='/player.html'">View Player</button>
            <button onclick="fetch('/api/restart.php')">Restart Player</button>
            <button onclick="fetch('/api/screenshot.php')">Take Screenshot</button>
        </div>
    </div>
</body>
</html>
PHP_ADMIN

# Copie des fichiers web
sshpass -p "$PI_PASS" scp /tmp/player.html $PI_USER@$PI_IP:/opt/pisignage/web/
sshpass -p "$PI_PASS" scp /tmp/index.php $PI_USER@$PI_IP:/opt/pisignage/web/

# Téléchargement vidéo de test
log_info "Téléchargement vidéo de démonstration..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP \
    "wget -q 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4' \
     -O /opt/pisignage/media/demo.mp4"

# Correction permissions
log_info "Configuration permissions..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R www-data:www-data /opt/pisignage/logs
sudo chown -R www-data:www-data /opt/pisignage/screenshots
sudo chown -R pi:pi /opt/pisignage/scripts
sudo chown -R pi:pi /opt/pisignage/media
sudo chmod -R 755 /opt/pisignage
EOF

# Restart services
log_info "Redémarrage des services..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP "sudo systemctl restart nginx php7.4-fpm"

# Test final
echo ""
log_info "Test de l'interface..."
if curl -s -o /dev/null -w "%{http_code}" http://$PI_IP | grep -q "200"; then
    log_success "Interface web accessible!"
else
    log_error "Interface web inaccessible"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║               DÉPLOIEMENT TERMINÉ !                       ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Interface Admin : http://$PI_IP                         ║"
echo "║  Player Vidéo   : http://$PI_IP/player.html              ║"
echo "║                                                           ║"
echo "║  Configuration GPU : gpu_mem=128, vc4-fkms-v3d           ║"
echo "║  Performance cible : 720p @ 30+ FPS                      ║"
echo "║                                                           ║"
echo "║  ⚠️  Redémarrage requis pour appliquer config GPU        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Commande pour redémarrer le Pi:"
echo "  sshpass -p '$PI_PASS' ssh $PI_USER@$PI_IP 'sudo reboot'"
echo ""