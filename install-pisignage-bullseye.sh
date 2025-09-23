#!/bin/bash

# PiSignage v0.9.0 - Installation complète pour Raspberry Pi OS Bullseye
# Objectif : Vidéo en boucle sur écran HDMI + Interface de contrôle web

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║        PiSignage v0.9.0 - Installation Bullseye           ║"
echo "║   Vidéo sur HDMI + Interface contrôle à distance          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 1. Mise à jour système
echo "📦 1/7 - Mise à jour système..."
sudo apt-get update
sudo apt-get upgrade -y

# 2. Installation packages
echo "📦 2/7 - Installation packages..."
sudo apt-get install -y \
    nginx \
    php7.4-fpm php7.4-cli php7.4-curl php7.4-mbstring php7.4-json \
    chromium-browser chromium-codecs-ffmpeg-extra \
    xorg openbox lightdm \
    unclutter \
    git curl wget imagemagick

# 3. Configuration GPU pour Bullseye
echo "🎮 3/7 - Configuration GPU..."
if ! grep -q "PiSignage GPU Configuration" /boot/config.txt; then
    sudo tee -a /boot/config.txt << 'EOF'

# PiSignage GPU Configuration - Bullseye
gpu_mem=128
dtoverlay=vc4-fkms-v3d
hdmi_group=2
hdmi_mode=85
EOF
fi

# 4. Structure PiSignage
echo "📁 4/7 - Création structure..."
sudo mkdir -p /opt/pisignage/{web,scripts,media,logs,screenshots,config}
sudo chown -R pi:pi /opt/pisignage

# 5. Interface de contrôle web
echo "🌐 5/7 - Interface de contrôle..."
cat > /opt/pisignage/web/index.php << 'PHP_END'
<?php
error_reporting(0);
$action = $_GET['action'] ?? '';

switch($action) {
    case 'restart':
        shell_exec('pkill -f chromium; DISPLAY=:0 chromium-browser --kiosk --enable-gpu http://localhost/player.html &');
        $message = "Player redémarré";
        break;
    case 'stop':
        shell_exec('pkill -f chromium');
        $message = "Player arrêté";
        break;
}

$cpu_temp = rtrim(shell_exec("vcgencmd measure_temp | cut -d= -f2"));
$gpu_mem = rtrim(shell_exec("vcgencmd get_mem gpu | cut -d= -f2"));
?>
<!DOCTYPE html>
<html>
<head>
    <title>PiSignage v0.9.0 - Contrôle</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial; background: #1a1a1a; color: white; padding: 20px; }
        .header { background: #2563eb; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: #2a2a2a; padding: 20px; border-radius: 10px; }
        button { background: #2563eb; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; margin: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎬 PiSignage v0.9.0 - Contrôle à distance</h1>
        <p>Vidéo affichée sur écran HDMI en boucle continue</p>
    </div>
    <?php if(isset($message)): ?>
    <div style="background: #10b981; padding: 10px; border-radius: 5px; margin-bottom: 20px;">
        <?= $message ?>
    </div>
    <?php endif; ?>
    <div class="grid">
        <div class="card">
            <h2>📊 État système</h2>
            <p>Température: <?= $cpu_temp ?></p>
            <p>GPU: <?= $gpu_mem ?></p>
        </div>
        <div class="card">
            <h2>🎮 Contrôles</h2>
            <button onclick="window.location.href='?action=restart'">▶️ Redémarrer</button>
            <button onclick="window.location.href='?action=stop'">⏹️ Arrêter</button>
        </div>
    </div>
</body>
</html>
PHP_END

# Player vidéo HTML5
cat > /opt/pisignage/web/player.html << 'HTML_END'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>PiSignage Player</title>
    <style>
        * { margin: 0; padding: 0; overflow: hidden; }
        body { background: #000; }
        video { width: 100vw; height: 100vh; object-fit: cover; }
    </style>
</head>
<body>
    <video autoplay loop muted playsinline>
        <source src="/media/demo.mp4" type="video/mp4">
    </video>
</body>
</html>
HTML_END

# 6. Configuration nginx
echo "⚙️ 6/7 - Configuration nginx..."
sudo tee /etc/nginx/sites-available/pisignage << 'NGINX_END'
server {
    listen 80 default_server;
    root /opt/pisignage/web;
    index index.php index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex on;
    }

    location /screenshots {
        alias /opt/pisignage/screenshots;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
    }
}
NGINX_END

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# 7. Configuration autologin et autostart
echo "🚀 7/7 - Configuration démarrage automatique..."

# LightDM autologin
sudo tee /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
user-session=openbox
EOF

# OpenBox autostart pour lancer Chromium sur HDMI
mkdir -p /home/pi/.config/openbox
cat > /home/pi/.config/openbox/autostart << 'AUTOSTART_END'
# Désactiver économiseur écran
xset s off -dpms
xset s noblank

# Cacher curseur
unclutter -idle 1 &

# Attendre X
sleep 5

# Lancer Chromium en plein écran sur HDMI
chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --no-first-run \
    --enable-gpu \
    --enable-accelerated-video-decode \
    --autoplay-policy=no-user-gesture-required \
    http://localhost/player.html &
AUTOSTART_END

# Télécharger vidéo démo
if [ ! -f /opt/pisignage/media/demo.mp4 ]; then
    echo "📥 Téléchargement vidéo de test..."
    wget -q "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4" \
         -O /opt/pisignage/media/demo.mp4
fi

# Permissions
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R www-data:www-data /opt/pisignage/screenshots
sudo chown -R pi:pi /opt/pisignage/media

echo ""
echo "✅ Installation terminée !"
echo ""
echo "📺 ÉCRAN HDMI : La vidéo sera affichée en boucle après redémarrage"
echo "🌐 CONTRÔLE WEB : http://$(hostname -I | cut -d' ' -f1)"
echo ""
echo "⚠️  Redémarrage nécessaire : sudo reboot"
echo ""