#!/bin/bash

# PiSignage v0.8.0 - Déploiement Complet sur Bullseye Fresh Install
# Contrôle total pour installation complète et fonctionnelle

set -e

PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║      PiSignage v0.8.0 - DÉPLOIEMENT COMPLET BULLSEYE      ║"
echo "║            Installation complète from scratch              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# 1. Test connexion
echo "🔍 1/12 - Vérification connexion..."
if ! sshpass -p "$PI_PASS" ssh -o ConnectTimeout=5 $PI_USER@$PI_IP "echo 'SSH OK'" > /dev/null 2>&1; then
    echo "❌ Connexion SSH impossible"
    exit 1
fi
echo "✅ Connexion SSH établie"

# 2. Mise à jour système
echo "📦 2/12 - Mise à jour système..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
sudo apt-get update
sudo apt-get upgrade -y
EOF

# 3. Installation packages essentiels
echo "📦 3/12 - Installation packages..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
sudo apt-get install -y \
    nginx \
    php7.4-fpm php7.4-cli php7.4-curl php7.4-mbstring php7.4-json php7.4-sqlite3 \
    chromium-browser chromium-codecs-ffmpeg-extra \
    xorg openbox lightdm \
    unclutter \
    scrot \
    git curl wget htop \
    imagemagick \
    python3-pip \
    sqlite3
EOF

# 4. Configuration GPU SAFE (pas d'overclocking pour éviter crash)
echo "🎮 4/12 - Configuration GPU..."
cat << 'GPU_CONFIG' > /tmp/gpu-config.txt

# PiSignage GPU Configuration - Mode SAFE
gpu_mem=256
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# HDMI Settings
hdmi_group=2
hdmi_mode=82
hdmi_drive=2
disable_overscan=1

# Performance stable (pas d'overclocking)
# arm_freq et gpu_freq laissés par défaut
GPU_CONFIG

sshpass -p "$PI_PASS" scp /tmp/gpu-config.txt $PI_USER@$PI_IP:/tmp/
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
if ! grep -q "PiSignage GPU Configuration" /boot/config.txt; then
    sudo cat /tmp/gpu-config.txt | sudo tee -a /boot/config.txt > /dev/null
    echo "✅ Configuration GPU ajoutée"
else
    echo "⏭️  Configuration GPU déjà présente"
fi
EOF

# 5. Structure PiSignage
echo "📁 5/12 - Création structure..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
sudo mkdir -p /opt/pisignage/{web,scripts,config,media,logs,screenshots,cache}
sudo mkdir -p /opt/pisignage/web/{api,assets/css,assets/js}
sudo chown -R pi:pi /opt/pisignage
EOF

# 6. Installation yt-dlp
echo "📥 6/12 - Installation yt-dlp..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
sudo wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
yt-dlp --version > /dev/null && echo "✅ yt-dlp installé" || echo "⚠️ yt-dlp non disponible"
EOF

# 7. Service nginx persistent
echo "⚙️ 7/12 - Service nginx persistent..."
cat << 'NGINX_SERVICE' > /tmp/nginx-prepare.service
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
NGINX_SERVICE

sshpass -p "$PI_PASS" scp /tmp/nginx-prepare.service $PI_USER@$PI_IP:/tmp/
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
sudo mv /tmp/nginx-prepare.service /etc/systemd/system/
sudo systemctl enable nginx-prepare.service
sudo systemctl start nginx-prepare.service
EOF

# 8. Configuration nginx
echo "🌐 8/12 - Configuration nginx..."
cat << 'NGINX_CONF' > /tmp/pisignage.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php index.html;

    server_name _;

    client_max_body_size 500M;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex on;
    }

    location /screenshots {
        alias /opt/pisignage/screenshots;
    }
}
NGINX_CONF

sshpass -p "$PI_PASS" scp /tmp/pisignage.conf $PI_USER@$PI_IP:/tmp/
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
sudo mv /tmp/pisignage.conf /etc/nginx/sites-available/pisignage
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx
EOF

# 9. Déploiement interface et APIs
echo "🎨 9/12 - Déploiement interface..."

# Copie de tous les fichiers web
for file in web/*.php web/*.html; do
    if [ -f "$file" ]; then
        echo "  Copie $(basename $file)..."
        sshpass -p "$PI_PASS" scp "$file" $PI_USER@$PI_IP:/opt/pisignage/web/ 2>/dev/null || true
    fi
done

# Copie des APIs
for file in web/api/*.php; do
    if [ -f "$file" ]; then
        echo "  Copie API $(basename $file)..."
        sshpass -p "$PI_PASS" scp "$file" $PI_USER@$PI_IP:/opt/pisignage/web/api/ 2>/dev/null || true
    fi
done

# Copie des assets si existants
if [ -d "web/assets" ]; then
    sshpass -p "$PI_PASS" scp -r web/assets $PI_USER@$PI_IP:/opt/pisignage/web/ 2>/dev/null || true
fi

# Si pas d'interface, créer une minimale
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
if [ ! -f /opt/pisignage/web/index.php ]; then
    cat > /opt/pisignage/web/index.php << 'PHP_END'
<!DOCTYPE html>
<html>
<head>
    <title>PiSignage v0.8.0</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 30px;
            color: white;
            text-align: center;
        }
        h1 { font-size: 2.5em; margin-bottom: 10px; }
        .controls {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }
        .btn {
            background: white;
            color: #667eea;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
            text-decoration: none;
            font-weight: 600;
            transition: all 0.3s;
            cursor: pointer;
            border: none;
            font-size: 16px;
        }
        .btn:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        .status {
            background: white;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 30px;
        }
        .stat-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        .stat {
            text-align: center;
            padding: 10px;
            background: #f5f5f5;
            border-radius: 8px;
        }
        .stat-value {
            font-size: 24px;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            font-size: 12px;
            color: #666;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎬 PiSignage v0.8.0</h1>
            <p>Système d'affichage digital pour Raspberry Pi</p>
        </div>

        <div class="status">
            <h2>État du système</h2>
            <div class="stat-grid">
                <div class="stat">
                    <div class="stat-value"><?php echo round(sys_getloadavg()[0], 2); ?></div>
                    <div class="stat-label">CPU Load</div>
                </div>
                <div class="stat">
                    <div class="stat-value"><?php
                        $temp = shell_exec("vcgencmd measure_temp | cut -d= -f2 | cut -d\\' -f1");
                        echo round(floatval($temp), 1) . "°C";
                    ?></div>
                    <div class="stat-label">Température</div>
                </div>
                <div class="stat">
                    <div class="stat-value"><?php
                        echo trim(shell_exec("vcgencmd get_mem gpu | cut -d= -f2"));
                    ?></div>
                    <div class="stat-label">GPU Memory</div>
                </div>
                <div class="stat">
                    <div class="stat-value"><?php
                        $uptime = shell_exec("uptime -p | sed 's/up //'");
                        echo substr($uptime, 0, 10) . "...";
                    ?></div>
                    <div class="stat-label">Uptime</div>
                </div>
            </div>
        </div>

        <div class="controls">
            <button class="btn" onclick="playerAction('restart')">▶️ Redémarrer Player</button>
            <button class="btn" onclick="playerAction('stop')">⏹️ Arrêter Player</button>
            <button class="btn" onclick="takeScreenshot()">📸 Screenshot</button>
            <button class="btn" onclick="location.href='/media'">📁 Voir Médias</button>
            <button class="btn" onclick="reloadPage()">🔄 Rafraîchir</button>
            <button class="btn" onclick="if(confirm('Redémarrer le système?')) systemAction('reboot')">🔌 Reboot</button>
        </div>
    </div>

    <script>
        function playerAction(action) {
            fetch('/api/player.php?action=' + action)
                .then(r => r.json())
                .then(d => {
                    alert(d.success ? 'Action effectuée' : 'Erreur');
                    if(d.success) setTimeout(() => location.reload(), 2000);
                });
        }

        function takeScreenshot() {
            fetch('/api/screenshot.php')
                .then(r => r.json())
                .then(d => alert(d.success ? 'Screenshot pris' : 'Erreur'));
        }

        function systemAction(action) {
            if(action === 'reboot') {
                fetch('/api/system.php?action=reboot');
                alert('Redémarrage en cours...');
            }
        }

        function reloadPage() {
            location.reload();
        }

        // Auto-refresh toutes les 30 secondes
        setTimeout(() => location.reload(), 30000);
    </script>
</body>
</html>
PHP_END
fi

# Créer player.html pour l'affichage HDMI
cat > /opt/pisignage/web/player.html << 'HTML_END'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>PiSignage Player</title>
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

        // Force hardware acceleration
        video.style.transform = 'translateZ(0)';

        // Auto-restart on error
        video.addEventListener('error', () => {
            setTimeout(() => {
                video.load();
                video.play();
            }, 1000);
        });

        // Ensure loop
        video.addEventListener('ended', () => {
            video.currentTime = 0;
            video.play();
        });

        // Start
        video.play().catch(e => {
            console.log('Autoplay blocked, retrying...');
            setTimeout(() => video.play(), 1000);
        });
    </script>
</body>
</html>
HTML_END

# Créer les APIs minimales
mkdir -p /opt/pisignage/web/api

# API player
cat > /opt/pisignage/web/api/player.php << 'API_END'
<?php
header('Content-Type: application/json');
$action = $_GET['action'] ?? '';

switch($action) {
    case 'restart':
        exec("pkill -f chromium; sleep 2; DISPLAY=:0 /opt/pisignage/scripts/start-chromium.sh &");
        echo json_encode(['success' => true]);
        break;
    case 'stop':
        exec("pkill -f chromium");
        echo json_encode(['success' => true]);
        break;
    default:
        echo json_encode(['success' => false]);
}
API_END

# API screenshot
cat > /opt/pisignage/web/api/screenshot.php << 'API_END'
<?php
header('Content-Type: application/json');
$file = '/opt/pisignage/screenshots/screen_' . date('Y-m-d_H-i-s') . '.jpg';
exec("DISPLAY=:0 scrot -q 75 '$file' 2>&1", $output, $return);
echo json_encode([
    'success' => $return === 0,
    'file' => basename($file),
    'url' => '/screenshots/' . basename($file)
]);
API_END

# API system
cat > /opt/pisignage/web/api/system.php << 'API_END'
<?php
header('Content-Type: application/json');
$action = $_GET['action'] ?? '';

if($action === 'reboot') {
    exec("sudo reboot");
    echo json_encode(['success' => true]);
} else {
    echo json_encode([
        'cpu' => sys_getloadavg()[0],
        'temp' => floatval(shell_exec("vcgencmd measure_temp | cut -d= -f2 | cut -d\\' -f1")),
        'gpu' => trim(shell_exec("vcgencmd get_mem gpu | cut -d= -f2"))
    ]);
}
API_END

# Permissions
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R www-data:www-data /opt/pisignage/screenshots
sudo chmod -R 755 /opt/pisignage
EOF

# 10. Script Chromium optimisé
echo "🚀 10/12 - Script Chromium..."
cat << 'CHROMIUM_SCRIPT' > /tmp/start-chromium.sh
#!/bin/bash

# PiSignage Chromium Launcher - Optimized for Bullseye

# Kill existing
pkill -f chromium || true
sleep 2

# Environment
export DISPLAY=:0
export LIBGL_ALWAYS_SOFTWARE=0

URL="http://localhost/player.html"

# Chromium flags optimized for Pi 4
CHROME_FLAGS=(
    --kiosk
    --start-fullscreen
    --window-size=1920,1080
    --window-position=0,0

    # GPU acceleration
    --enable-gpu
    --enable-gpu-rasterization
    --enable-accelerated-video-decode
    --use-gl=egl
    --ignore-gpu-blocklist

    # Performance
    --enable-hardware-overlays=single-fullscreen
    --disable-software-rasterizer
    --disable-background-timer-throttling

    # Memory
    --memory-pressure-off
    --max_old_space_size=512

    # Autoplay
    --autoplay-policy=no-user-gesture-required

    # Misc
    --noerrdialogs
    --disable-infobars
    --no-first-run
    --disable-translate
    --disable-features=TranslateUI
)

# Launch loop
while true; do
    echo "[$(date)] Starting Chromium..."
    chromium-browser "${CHROME_FLAGS[@]}" "$URL"
    echo "[$(date)] Chromium stopped, restarting in 5s..."
    sleep 5
done
CHROMIUM_SCRIPT

sshpass -p "$PI_PASS" scp /tmp/start-chromium.sh $PI_USER@$PI_IP:/opt/pisignage/scripts/
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP "chmod +x /opt/pisignage/scripts/start-chromium.sh"

# 11. Configuration autologin et autostart
echo "🔐 11/12 - Configuration autologin..."
cat << 'LIGHTDM_CONF' > /tmp/lightdm.conf
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
user-session=openbox
LIGHTDM_CONF

sshpass -p "$PI_PASS" scp /tmp/lightdm.conf $PI_USER@$PI_IP:/tmp/
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP "sudo mv /tmp/lightdm.conf /etc/lightdm/lightdm.conf"

# Autostart OpenBox
cat << 'AUTOSTART' > /tmp/autostart
# Désactiver économiseur écran
xset s off -dpms
xset s noblank

# Cacher curseur
unclutter -idle 1 &

# Attendre que X soit prêt
sleep 10

# Lancer Chromium
/opt/pisignage/scripts/start-chromium.sh &
AUTOSTART

sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP "mkdir -p /home/pi/.config/openbox"
sshpass -p "$PI_PASS" scp /tmp/autostart $PI_USER@$PI_IP:/home/pi/.config/openbox/

# 12. Télécharger vidéo démo
echo "📥 12/12 - Vidéo de démonstration..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
if [ ! -f /opt/pisignage/media/demo.mp4 ]; then
    wget -q "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4" \
         -O /opt/pisignage/media/demo.mp4
    echo "✅ Vidéo démo téléchargée"
else
    echo "⏭️  Vidéo démo déjà présente"
fi
EOF

# Permissions finales
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R www-data:www-data /opt/pisignage/logs
sudo chown -R www-data:www-data /opt/pisignage/screenshots
sudo chown -R pi:pi /opt/pisignage/scripts
sudo chown -R pi:pi /opt/pisignage/media
sudo chmod -R 755 /opt/pisignage
sudo systemctl restart nginx php7.4-fpm
EOF

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║          INSTALLATION TERMINÉE AVEC SUCCÈS !              ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Interface Web : http://192.168.1.103                     ║"
echo "║  Écran HDMI : Vidéo en boucle après redémarrage           ║"
echo "║                                                            ║"
echo "║  Configuration GPU : 256MB (mode safe)                    ║"
echo "║  Chromium : Optimisé avec GPU acceleration                ║"
echo "║                                                            ║"
echo "║  ⚠️  REDÉMARRAGE REQUIS : sudo reboot                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Pour redémarrer maintenant :"
echo "  sshpass -p 'raspberry' ssh pi@192.168.1.103 'sudo reboot'"