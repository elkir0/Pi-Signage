#!/bin/bash
# PiSignage v0.9.0 - Installation Raspberry Pi OS Bullseye
# Architecture complète avec Chromium Kiosk + GPU Acceleration

set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Vérifications préalables
check_system() {
    log "Vérification du système..."

    # Vérifier OS
    if ! grep -q "bullseye" /etc/os-release; then
        error "Ce script nécessite Raspberry Pi OS Bullseye"
    fi

    # Vérifier architecture
    if ! uname -m | grep -q "armv7l\|aarch64"; then
        error "Architecture ARM requise"
    fi

    # Vérifier Raspberry Pi
    if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
        warn "Non détecté comme Raspberry Pi - continuons quand même"
    fi

    log "Système compatible détecté"
}

# Installation des packages
install_packages() {
    log "Mise à jour du système..."
    sudo apt update && sudo apt upgrade -y

    log "Installation des packages essentiels..."
    sudo apt install -y \
        nginx \
        php7.4-fpm php7.4-cli php7.4-json php7.4-curl php7.4-sqlite3 \
        chromium-browser chromium-codecs-ffmpeg \
        git curl wget unzip jq bc htop \
        ffmpeg libavcodec-extra \
        vim nano screen \
        xserver-xorg xinit openbox \
        sshpass rsync

    log "Suppression des packages problématiques..."
    sudo apt remove -y vlc* omxplayer* 2>/dev/null || true

    log "Nettoyage..."
    sudo apt autoremove -y
    sudo apt autoclean
}

# Configuration du système
configure_system() {
    log "Configuration /boot/config.txt..."

    # Backup
    sudo cp /boot/config.txt /boot/config.txt.backup.$(date +%Y%m%d_%H%M%S)

    # Configuration GPU optimale
    sudo tee /boot/config.txt > /dev/null << 'EOF'
# Configuration PiSignage v0.9.0 - Optimisée Bullseye

# GPU et Mémoire
gpu_mem=128
start_x=1

# Résolution stable
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=85
hdmi_drive=2
hdmi_audio=1

# Performance stable (pas d'overclocking)
arm_freq=1500
core_freq=500
sdram_freq=500
over_voltage=0

# Désactiver Bluetooth
dtoverlay=disable-bt

# Audio et caméra
dtparam=audio=on
camera_auto_detect=1
display_auto_detect=1

# Paramètres kernel
cmdline=dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=PARTUUID=6c586e13-02 rootfstype=ext4 fsck.repair=yes rootwait quiet splash plymouth.ignore-serial-consoles
EOF

    log "Configuration du démarrage automatique X11..."

    # Configuration .xinitrc pour l'utilisateur pi
    cat > /home/pi/.xinitrc << 'EOF'
#!/bin/bash
# .xinitrc pour PiSignage

# Désactiver l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Démarrer openbox en arrière-plan
openbox &

# Attendre un peu
sleep 2

# Démarrer PiSignage
exec /opt/pisignage/scripts/start-kiosk.sh
EOF

    chmod +x /home/pi/.xinitrc

    # Auto-démarrage X11 au login
    echo 'if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then' >> /home/pi/.bashrc
    echo '  exec startx' >> /home/pi/.bashrc
    echo 'fi' >> /home/pi/.bashrc
}

# Configuration nginx
configure_nginx() {
    log "Configuration nginx..."

    # Backup
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

    sudo tee /etc/nginx/sites-available/default > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.html index.php;

    server_name _;

    # Logs persistants
    access_log /opt/pisignage/logs/nginx-access.log;
    error_log /opt/pisignage/logs/nginx-error.log;

    # Gestion des fichiers PHP
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # API REST
    location /api/ {
        try_files $uri $uri/ =404;
    }

    # Fichiers statiques
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Sécurité
    location ~ /\. {
        deny all;
    }
}
EOF

    # Test configuration
    sudo nginx -t || error "Configuration nginx invalide"

    log "Démarrage nginx..."
    sudo systemctl enable nginx
    sudo systemctl enable php7.4-fpm
    sudo systemctl restart nginx
    sudo systemctl restart php7.4-fpm
}

# Création des répertoires
create_directories() {
    log "Création de l'arborescence PiSignage..."

    # Répertoires principaux
    sudo mkdir -p /opt/pisignage/{config,web,scripts,services,media,logs,tmp}
    sudo mkdir -p /opt/pisignage/web/api
    sudo mkdir -p /opt/pisignage/media/{videos,images,playlists}

    # Permissions
    sudo chown -R pi:pi /opt/pisignage
    sudo chmod -R 755 /opt/pisignage
    sudo chmod -R 777 /opt/pisignage/logs
    sudo chmod -R 777 /opt/pisignage/tmp
    sudo chmod -R 755 /opt/pisignage/media

    log "Arborescence créée avec succès"
}

# Création des scripts essentiels
create_scripts() {
    log "Création des scripts système..."

    # Script de démarrage kiosk
    cat > /opt/pisignage/scripts/start-kiosk.sh << 'EOF'
#!/bin/bash
# Démarrage mode kiosk PiSignage v0.9.0

export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Log
exec > /opt/pisignage/logs/kiosk.log 2>&1

echo "[$(date)] Démarrage mode kiosk PiSignage v0.9.0"

# Attendre que X11 soit prêt
while ! xdpyinfo >/dev/null 2>&1; do
    echo "[$(date)] Attente X11..."
    sleep 1
done

echo "[$(date)] X11 prêt, configuration affichage..."

# Configuration affichage
xset s off
xset -dpms
xset s noblank

# Masquer le curseur après 1 seconde
unclutter -idle 1 &

echo "[$(date)] Démarrage Chromium en mode kiosk..."

# Flags Chromium optimisés pour Raspberry Pi + Bullseye
chromium-browser \
    --kiosk \
    --no-sandbox \
    --disable-web-security \
    --disable-features=TranslateUI \
    --disable-ipc-flooding-protection \
    --noerrdialogs \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --disable-background-timer-throttling \
    --disable-renderer-backgrounding \
    --disable-backgrounding-occluded-windows \
    --disable-background-networking \
    --enable-features=VaapiVideoDecoder \
    --use-gl=egl \
    --enable-gpu-rasterization \
    --enable-oop-rasterization \
    --disable-software-rasterizer \
    --disable-dev-shm-usage \
    --memory-pressure-off \
    --max_old_space_size=512 \
    --js-flags="--max-old-space-size=512" \
    http://localhost/
EOF

    # Script de contrôle média
    cat > /opt/pisignage/scripts/media-control.sh << 'EOF'
#!/bin/bash
# Contrôle média via JavaScript injection

DISPLAY=:0
URL="http://localhost/"

case $1 in
    "play")
        chromium-browser --new-window "$URL#play" 2>/dev/null &
        ;;
    "pause")
        chromium-browser --new-window "$URL#pause" 2>/dev/null &
        ;;
    "next")
        chromium-browser --new-window "$URL#next" 2>/dev/null &
        ;;
    "reload")
        pkill chromium-browser
        sleep 2
        /opt/pisignage/scripts/start-kiosk.sh &
        ;;
    *)
        echo "Usage: $0 {play|pause|next|reload}"
        exit 1
        ;;
esac
EOF

    # Script watchdog
    cat > /opt/pisignage/scripts/watchdog.sh << 'EOF'
#!/bin/bash
# Surveillance système PiSignage

LOG_FILE="/opt/pisignage/logs/watchdog.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

while true; do
    # Vérifier Chromium
    if ! pgrep chromium-browser > /dev/null; then
        log "ALERTE: Chromium arrêté, redémarrage..."
        DISPLAY=:0 /opt/pisignage/scripts/start-kiosk.sh &
    fi

    # Vérifier nginx
    if ! systemctl is-active --quiet nginx; then
        log "ALERTE: nginx arrêté, redémarrage..."
        sudo systemctl restart nginx
    fi

    # Vérifier PHP-FPM
    if ! systemctl is-active --quiet php7.4-fpm; then
        log "ALERTE: PHP-FPM arrêté, redémarrage..."
        sudo systemctl restart php7.4-fpm
    fi

    # Vérifier espace disque
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 90 ]; then
        log "ALERTE: Espace disque faible: ${DISK_USAGE}%"
        # Nettoyage automatique
        find /opt/pisignage/logs -name "*.log" -mtime +7 -delete
        find /opt/pisignage/tmp -type f -mtime +1 -delete
    fi

    # Vérifier température
    TEMP=$(vcgencmd measure_temp | grep -o '[0-9]*\.[0-9]*')
    if (( $(echo "$TEMP > 75.0" | bc -l) )); then
        log "ALERTE: Température élevée: ${TEMP}°C"
    fi

    sleep 30
done
EOF

    # Script de capture d'écran
    cat > /opt/pisignage/scripts/screenshot.sh << 'EOF'
#!/bin/bash
# Capture d'écran optimisée

DISPLAY=:0
OUTPUT_FILE="/opt/pisignage/tmp/screenshot_$(date +%Y%m%d_%H%M%S).png"

# Utiliser scrot si disponible, sinon import
if command -v scrot >/dev/null; then
    scrot "$OUTPUT_FILE"
else
    import -window root "$OUTPUT_FILE"
fi

echo "$OUTPUT_FILE"
EOF

    # Rendre tous les scripts exécutables
    chmod +x /opt/pisignage/scripts/*.sh

    log "Scripts créés avec succès"
}

# Installation des services systemd
install_services() {
    log "Installation des services systemd..."

    # Service kiosk
    sudo tee /etc/systemd/system/pisignage-kiosk.service > /dev/null << 'EOF'
[Unit]
Description=PiSignage Kiosk Mode
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=pi
Group=pi
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pi/.Xauthority
ExecStartPre=/bin/sleep 15
ExecStart=/opt/pisignage/scripts/start-kiosk.sh
Restart=always
RestartSec=10
KillMode=process

[Install]
WantedBy=graphical-session.target
EOF

    # Service watchdog
    sudo tee /etc/systemd/system/pisignage-watchdog.service > /dev/null << 'EOF'
[Unit]
Description=PiSignage System Watchdog
After=multi-user.target

[Service]
Type=simple
User=pi
ExecStart=/opt/pisignage/scripts/watchdog.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # Activation des services
    sudo systemctl daemon-reload
    sudo systemctl enable pisignage-kiosk.service
    sudo systemctl enable pisignage-watchdog.service

    log "Services installés avec succès"
}

# Création de l'interface web
create_web_interface() {
    log "Création de l'interface web..."

    # Page principale (lecteur)
    cat > /opt/pisignage/web/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage v0.9.0 Player</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: #000;
            font-family: Arial, sans-serif;
            overflow: hidden;
        }

        #player {
            width: 100vw;
            height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
        }

        video {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }

        .info {
            position: absolute;
            top: 10px;
            right: 10px;
            color: white;
            background: rgba(0,0,0,0.7);
            padding: 5px 10px;
            border-radius: 3px;
            font-size: 12px;
            display: none;
        }

        .loading {
            color: white;
            font-size: 24px;
        }
    </style>
</head>
<body>
    <div id="player">
        <div class="loading" id="loading">Chargement PiSignage v0.9.0...</div>
        <video id="video" autoplay muted loop style="display: none;">
            Votre navigateur ne supporte pas la lecture vidéo.
        </video>
        <div class="info" id="info">PiSignage v0.9.0</div>
    </div>

    <script>
        // Lecteur vidéo optimisé pour Raspberry Pi
        class PiSignagePlayer {
            constructor() {
                this.video = document.getElementById('video');
                this.loading = document.getElementById('loading');
                this.info = document.getElementById('info');
                this.currentMedia = null;
                this.playlist = [];
                this.currentIndex = 0;

                this.init();
            }

            async init() {
                console.log('PiSignage v0.9.0 - Initialisation...');

                // Écouter les événements vidéo
                this.video.addEventListener('loadeddata', () => {
                    this.loading.style.display = 'none';
                    this.video.style.display = 'block';
                    console.log('Vidéo chargée:', this.currentMedia);
                });

                this.video.addEventListener('error', (e) => {
                    console.error('Erreur vidéo:', e);
                    this.loadNextMedia();
                });

                this.video.addEventListener('ended', () => {
                    this.loadNextMedia();
                });

                // Charger la playlist
                await this.loadPlaylist();

                // Démarrer la lecture
                this.play();

                // Écouter les commandes via hash
                window.addEventListener('hashchange', this.handleCommand.bind(this));
            }

            async loadPlaylist() {
                try {
                    const response = await fetch('/api/playlist.php');
                    const data = await response.json();
                    this.playlist = data.playlist || [];
                    console.log('Playlist chargée:', this.playlist.length, 'éléments');
                } catch (error) {
                    console.error('Erreur chargement playlist:', error);
                    // Playlist par défaut
                    this.playlist = ['/media/videos/default.mp4'];
                }
            }

            play() {
                if (this.playlist.length === 0) {
                    console.warn('Playlist vide');
                    return;
                }

                this.currentMedia = this.playlist[this.currentIndex];
                console.log('Lecture:', this.currentMedia);

                this.loading.style.display = 'block';
                this.video.style.display = 'none';
                this.video.src = this.currentMedia;
                this.video.load();
            }

            next() {
                this.currentIndex = (this.currentIndex + 1) % this.playlist.length;
                this.play();
            }

            handleCommand() {
                const command = window.location.hash.substring(1);
                console.log('Commande reçue:', command);

                switch (command) {
                    case 'play':
                        this.video.play();
                        break;
                    case 'pause':
                        this.video.pause();
                        break;
                    case 'next':
                        this.next();
                        break;
                    case 'reload':
                        window.location.reload();
                        break;
                }

                // Nettoyer le hash
                history.replaceState(null, null, window.location.pathname);
            }

            loadNextMedia() {
                setTimeout(() => this.next(), 1000);
            }
        }

        // Démarrer le lecteur
        document.addEventListener('DOMContentLoaded', () => {
            new PiSignagePlayer();
        });

        // Debug info
        setInterval(() => {
            document.getElementById('info').style.display = 'block';
            setTimeout(() => {
                document.getElementById('info').style.display = 'none';
            }, 2000);
        }, 30000);
    </script>
</body>
</html>
EOF

    # Interface d'administration
    cat > /opt/pisignage/web/admin.php << 'EOF'
<?php
// Interface d'administration PiSignage v0.9.0
$version = "0.9.0";
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage v<?= $version ?> - Administration</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007cba; padding-bottom: 10px; }
        .status { display: flex; gap: 20px; margin: 20px 0; }
        .status-item { flex: 1; padding: 15px; background: #f8f9fa; border-radius: 5px; border-left: 4px solid #007cba; }
        .btn { background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; margin: 5px; }
        .btn:hover { background: #005a87; }
        .section { margin: 30px 0; }
        .api-test { background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ PiSignage v<?= $version ?> - Administration</h1>

        <div class="status">
            <div class="status-item">
                <h3>📊 Système</h3>
                <p>Version: <?= $version ?></p>
                <p>Uptime: <?= shell_exec('uptime -p') ?></p>
                <p>Charge: <?= sys_getloadavg()[0] ?></p>
            </div>
            <div class="status-item">
                <h3>🌡️ Hardware</h3>
                <p>Température: <?= rtrim(shell_exec('vcgencmd measure_temp | grep -o "[0-9]*\.[0-9]*"')) ?>°C</p>
                <p>GPU Memory: <?= rtrim(shell_exec('vcgencmd get_mem gpu | cut -d= -f2')) ?></p>
                <p>Throttling: <?= rtrim(shell_exec('vcgencmd get_throttled')) ?></p>
            </div>
            <div class="status-item">
                <h3>🎬 Lecteur</h3>
                <p>Status: <span id="player-status">Vérification...</span></p>
                <p>Chromium: <span id="chromium-status">Vérification...</span></p>
                <p>Nginx: <span id="nginx-status">Vérification...</span></p>
            </div>
        </div>

        <div class="section">
            <h2>🎮 Contrôles</h2>
            <button class="btn" onclick="sendCommand('play')">▶️ Play</button>
            <button class="btn" onclick="sendCommand('pause')">⏸️ Pause</button>
            <button class="btn" onclick="sendCommand('next')">⏭️ Suivant</button>
            <button class="btn" onclick="sendCommand('reload')">🔄 Recharger</button>
            <button class="btn" onclick="restartKiosk()">🚀 Redémarrer Kiosk</button>
        </div>

        <div class="section">
            <h2>🔧 Tests API</h2>
            <div class="api-test">
                <button class="btn" onclick="testApi('system')">Test API Système</button>
                <button class="btn" onclick="testApi('media')">Test API Média</button>
                <button class="btn" onclick="testApi('playlist')">Test API Playlist</button>
                <div id="api-results"></div>
            </div>
        </div>

        <div class="section">
            <h2>📝 Logs Récents</h2>
            <div style="background: #f8f8f8; padding: 15px; border-radius: 5px; font-family: monospace; max-height: 300px; overflow-y: auto;">
                <pre id="logs"><?= htmlspecialchars(shell_exec('tail -20 /opt/pisignage/logs/kiosk.log 2>/dev/null || echo "Aucun log disponible"')) ?></pre>
            </div>
        </div>
    </div>

    <script>
        // Test des services au chargement
        window.onload = function() {
            checkServices();
        };

        function checkServices() {
            // Vérifier Chromium
            fetch('/api/system.php?action=check_chromium')
                .then(r => r.json())
                .then(data => {
                    document.getElementById('chromium-status').textContent = data.running ? '✅ Actif' : '❌ Arrêté';
                });

            // Vérifier Nginx
            fetch('/api/system.php?action=check_nginx')
                .then(r => r.json())
                .then(data => {
                    document.getElementById('nginx-status').textContent = data.running ? '✅ Actif' : '❌ Arrêté';
                });
        }

        function sendCommand(cmd) {
            fetch('/api/player.php', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({command: cmd})
            }).then(r => r.json()).then(data => {
                alert('Commande envoyée: ' + cmd);
            });
        }

        function restartKiosk() {
            if (confirm('Redémarrer le mode kiosk ?')) {
                fetch('/api/system.php', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({action: 'restart_kiosk'})
                });
                alert('Redémarrage en cours...');
            }
        }

        function testApi(api) {
            fetch('/api/' + api + '.php')
                .then(r => r.json())
                .then(data => {
                    document.getElementById('api-results').innerHTML =
                        '<h4>Résultat API ' + api + ':</h4><pre>' + JSON.stringify(data, null, 2) + '</pre>';
                })
                .catch(err => {
                    document.getElementById('api-results').innerHTML =
                        '<h4>Erreur API ' + api + ':</h4><pre>' + err + '</pre>';
                });
        }
    </script>
</body>
</html>
EOF

    log "Interface web créée avec succès"
}

# Création des APIs
create_apis() {
    log "Création des APIs REST..."

    # Configuration PHP
    cat > /opt/pisignage/web/config.php << 'EOF'
<?php
// Configuration PiSignage v0.9.0

define('PISIGNAGE_VERSION', '0.9.0');
define('BASE_PATH', '/opt/pisignage');
define('MEDIA_PATH', BASE_PATH . '/media');
define('LOGS_PATH', BASE_PATH . '/logs');

// Headers CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

// Fonction utilitaire
function jsonResponse($data, $status = 200) {
    http_response_code($status);
    echo json_encode($data);
    exit;
}

function logMessage($message) {
    $log = date('Y-m-d H:i:s') . ' - ' . $message . PHP_EOL;
    file_put_contents(LOGS_PATH . '/web.log', $log, FILE_APPEND);
}
?>
EOF

    # API Système
    cat > /opt/pisignage/web/api/system.php << 'EOF'
<?php
require_once '../config.php';

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

switch ($method) {
    case 'GET':
        switch ($action) {
            case 'info':
                jsonResponse([
                    'version' => PISIGNAGE_VERSION,
                    'uptime' => shell_exec('uptime -s'),
                    'load' => sys_getloadavg(),
                    'temperature' => floatval(shell_exec('vcgencmd measure_temp | grep -o "[0-9]*\\.[0-9]*"')),
                    'gpu_memory' => trim(shell_exec('vcgencmd get_mem gpu')),
                    'disk_usage' => trim(shell_exec('df -h / | awk "NR==2 {print $5}"'))
                ]);
                break;

            case 'check_chromium':
                $running = shell_exec('pgrep chromium-browser') ? true : false;
                jsonResponse(['running' => $running]);
                break;

            case 'check_nginx':
                $running = shell_exec('systemctl is-active nginx') === "active\n";
                jsonResponse(['running' => $running]);
                break;

            default:
                jsonResponse(['error' => 'Action non supportée'], 400);
        }
        break;

    case 'POST':
        $input = json_decode(file_get_contents('php://input'), true);
        $action = $input['action'] ?? '';

        switch ($action) {
            case 'restart_kiosk':
                shell_exec('sudo systemctl restart pisignage-kiosk.service');
                jsonResponse(['success' => true, 'message' => 'Kiosk redémarré']);
                break;

            case 'reboot':
                shell_exec('sudo reboot');
                jsonResponse(['success' => true, 'message' => 'Redémarrage système']);
                break;

            default:
                jsonResponse(['error' => 'Action non supportée'], 400);
        }
        break;

    default:
        jsonResponse(['error' => 'Méthode non supportée'], 405);
}
?>
EOF

    # API Playlist
    cat > /opt/pisignage/web/api/playlist.php << 'EOF'
<?php
require_once '../config.php';

$playlistFile = MEDIA_PATH . '/playlists/current.json';

switch ($_SERVER['REQUEST_METHOD']) {
    case 'GET':
        if (file_exists($playlistFile)) {
            $playlist = json_decode(file_get_contents($playlistFile), true);
        } else {
            // Playlist par défaut
            $playlist = [
                'name' => 'Playlist par défaut',
                'playlist' => ['/media/videos/default.mp4']
            ];

            // Créer le fichier
            if (!is_dir(dirname($playlistFile))) {
                mkdir(dirname($playlistFile), 0755, true);
            }
            file_put_contents($playlistFile, json_encode($playlist, JSON_PRETTY_PRINT));
        }

        jsonResponse($playlist);
        break;

    case 'POST':
        $input = json_decode(file_get_contents('php://input'), true);

        if (!$input || !isset($input['playlist'])) {
            jsonResponse(['error' => 'Données invalides'], 400);
        }

        $playlist = [
            'name' => $input['name'] ?? 'Playlist',
            'updated' => date('Y-m-d H:i:s'),
            'playlist' => $input['playlist']
        ];

        if (!is_dir(dirname($playlistFile))) {
            mkdir(dirname($playlistFile), 0755, true);
        }

        file_put_contents($playlistFile, json_encode($playlist, JSON_PRETTY_PRINT));
        logMessage('Playlist mise à jour: ' . count($playlist['playlist']) . ' éléments');

        jsonResponse(['success' => true, 'message' => 'Playlist sauvegardée']);
        break;

    default:
        jsonResponse(['error' => 'Méthode non supportée'], 405);
}
?>
EOF

    # API Player Control
    cat > /opt/pisignage/web/api/player.php << 'EOF'
<?php
require_once '../config.php';

switch ($_SERVER['REQUEST_METHOD']) {
    case 'POST':
        $input = json_decode(file_get_contents('php://input'), true);
        $command = $input['command'] ?? '';

        switch ($command) {
            case 'play':
            case 'pause':
            case 'next':
            case 'reload':
                shell_exec("/opt/pisignage/scripts/media-control.sh $command");
                logMessage("Commande player: $command");
                jsonResponse(['success' => true, 'command' => $command]);
                break;

            default:
                jsonResponse(['error' => 'Commande inconnue'], 400);
        }
        break;

    default:
        jsonResponse(['error' => 'Méthode non supportée'], 405);
}
?>
EOF

    # API Media
    cat > /opt/pisignage/web/api/media.php << 'EOF'
<?php
require_once '../config.php';

switch ($_SERVER['REQUEST_METHOD']) {
    case 'GET':
        $mediaFiles = [];

        // Scanner les répertoires média
        $dirs = ['videos', 'images'];
        foreach ($dirs as $dir) {
            $path = MEDIA_PATH . '/' . $dir;
            if (is_dir($path)) {
                $files = scandir($path);
                foreach ($files as $file) {
                    if ($file !== '.' && $file !== '..' && !is_dir($path . '/' . $file)) {
                        $mediaFiles[] = [
                            'name' => $file,
                            'type' => $dir,
                            'path' => '/media/' . $dir . '/' . $file,
                            'size' => filesize($path . '/' . $file),
                            'modified' => filemtime($path . '/' . $file)
                        ];
                    }
                }
            }
        }

        jsonResponse(['files' => $mediaFiles]);
        break;

    default:
        jsonResponse(['error' => 'Méthode non supportée'], 405);
}
?>
EOF

    log "APIs créées avec succès"
}

# Fichier de version
create_version_file() {
    echo "0.9.0" > /opt/pisignage/VERSION
    log "Fichier VERSION créé"
}

# Tests post-installation
run_tests() {
    log "Exécution des tests post-installation..."

    # Test nginx
    if ! systemctl is-active --quiet nginx; then
        warn "nginx n'est pas actif"
    else
        log "✅ nginx actif"
    fi

    # Test PHP-FPM
    if ! systemctl is-active --quiet php7.4-fpm; then
        warn "PHP-FPM n'est pas actif"
    else
        log "✅ PHP-FPM actif"
    fi

    # Test répertoires
    if [ -d "/opt/pisignage" ]; then
        log "✅ Répertoire PiSignage créé"
    else
        error "Répertoire PiSignage manquant"
    fi

    # Test scripts
    if [ -x "/opt/pisignage/scripts/start-kiosk.sh" ]; then
        log "✅ Scripts exécutables"
    else
        warn "Scripts non exécutables"
    fi

    log "Tests terminés"
}

# Fonction principale
main() {
    log "🚀 Installation PiSignage v0.9.0 pour Raspberry Pi OS Bullseye"
    log "============================================================"

    check_system
    install_packages
    configure_system
    create_directories
    configure_nginx
    create_scripts
    install_services
    create_web_interface
    create_apis
    create_version_file
    run_tests

    log "============================================================"
    log "✅ Installation terminée avec succès!"
    log ""
    log "🔄 Prochaines étapes:"
    log "1. Redémarrer le système: sudo reboot"
    log "2. Accéder à l'interface: http://<IP_RPI>"
    log "3. Administration: http://<IP_RPI>/admin.php"
    log ""
    log "📁 Répertoires importants:"
    log "- Configuration: /opt/pisignage/config"
    log "- Médias: /opt/pisignage/media"
    log "- Logs: /opt/pisignage/logs"
    log "- Scripts: /opt/pisignage/scripts"
    log ""
    log "🛠️ Services installés:"
    log "- pisignage-kiosk.service (mode kiosk)"
    log "- pisignage-watchdog.service (surveillance)"
    log ""
    log "🎬 Le mode kiosk démarrera automatiquement après redémarrage"

    warn "IMPORTANT: Redémarrez maintenant avec 'sudo reboot'"
}

# Exécution
main "$@"