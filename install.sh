#!/bin/bash

# ===============================================================================
# Pi-Signage Installation Script v0.8.1 COMPLET - ONE CLICK INSTALL
# ===============================================================================
# Script unique pour installer Pi-Signage sur Raspberry Pi OS Bookworm
# Support: Pi 3, Pi 4, Pi 5, Zero 2 W
# ===============================================================================

set -e

# =============== CONFIGURATION ===============
PISIGNAGE_VERSION="0.8.1"
PISIGNAGE_DIR="/opt/pisignage"
PISIGNAGE_USER="${SUDO_USER:-$USER}"
PISIGNAGE_GROUP="pisignage"
LOG_FILE="/var/log/pisignage-install.log"
GITHUB_REPO="https://github.com/elkiro/Pi-Signage.git"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============== FONCTIONS UTILITAIRES ===============
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# =============== VÉRIFICATIONS PRÉLIMINAIRES ===============
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Ce script doit être exécuté avec sudo"
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_CODENAME="$VERSION_CODENAME"
    else
        error "Impossible de détecter l'OS"
    fi

    log "OS détecté: $OS_NAME $OS_VERSION ($OS_CODENAME)"

    if [[ "$OS_CODENAME" != "bookworm" ]]; then
        warning "Cette version est optimisée pour Bookworm. Compatibilité limitée sur $OS_CODENAME"
    fi
}

detect_pi_model() {
    PI_MODEL=$(cat /proc/cpuinfo | grep "Model" | cut -d':' -f2 | xargs || echo "Unknown")
    log "Modèle Pi détecté: $PI_MODEL"

    if [[ "$PI_MODEL" == *"Pi 5"* ]]; then
        HW_ACCEL="pi5"
        GPU_MEM="256"
    elif [[ "$PI_MODEL" == *"Pi 4"* ]]; then
        HW_ACCEL="pi4"
        GPU_MEM="256"
    elif [[ "$PI_MODEL" == *"Pi 3"* ]] || [[ "$PI_MODEL" == *"Zero 2"* ]]; then
        HW_ACCEL="pi3"
        GPU_MEM="128"
    else
        HW_ACCEL="none"
        GPU_MEM="64"
        warning "Accélération HW limitée sur ce modèle"
    fi

    log "Configuration HW: $HW_ACCEL, GPU Memory: ${GPU_MEM}MB"
}

# =============== INSTALLATION DES PAQUETS ===============
install_packages() {
    log "Mise à jour des sources APT..."

    # Configuration APT pour mode non-interactif
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    apt-get update || error "Échec mise à jour APT"

    log "Installation des paquets système..."

    # Liste des paquets par catégorie
    PACKAGES=(
        # === Lecteurs vidéo ===
        "mpv"
        "vlc"

        # === Accélération HW ===
        "ffmpeg"
        "libraspberrypi-bin"

        # === Support graphique ===
        "xorg"
        "openbox"
        "x11-xserver-utils"
        "lightdm"

        # === Support Wayland/DRM ===
        "seatd"
        "libdrm2"
        "libdrm-tests"
        "libgl1-mesa-dri"
        "mesa-utils"

        # === V4L2 pour accélération vidéo ===
        "v4l-utils"
        "libv4l-0"

        # === Gestion d'affichage ===
        "wlr-randr"
        "wayland-utils"

        # === Serveur web et API ===
        "nginx"
        "php8.2-fpm"
        "php8.2-cli"
        "php8.2-curl"
        "php8.2-mbstring"
        "php8.2-xml"
        "php8.2-zip"

        # === Node.js et npm ===
        "nodejs"
        "npm"

        # === Outils système ===
        "git"
        "curl"
        "wget"
        "unzip"
        "python3-pip"
        "python3-venv"
        "jq"
        "bc"
        "socat"

        # === Capture d'écran ===
        "scrot"
        "grim"
        "slurp"
        "imagemagick"

        # === Monitoring ===
        "htop"
        "iotop"
        "nethogs"

        # === Outils réseau ===
        "net-tools"
        "wireless-tools"
        "wpasupplicant"

        # === Autres ===
        "unclutter"
        "fbi"
        "fbgrab"
    )

    # Installation avec gestion d'erreurs
    for package in "${PACKAGES[@]}"; do
        if apt-cache show "$package" &>/dev/null; then
            log "Installation de $package..."
            apt-get install -y "$package" 2>/dev/null || warning "Paquet optionnel non installé: $package"
        else
            info "Paquet $package non disponible sur cette architecture"
        fi
    done

    log "Paquets système installés avec succès"
}

# =============== CONFIGURATION SYSTÈME ===============
setup_permissions() {
    log "Configuration des permissions..."

    # Création du groupe pisignage
    groupadd -f "$PISIGNAGE_GROUP"

    # Ajout de l'utilisateur aux groupes nécessaires
    usermod -aG video "$PISIGNAGE_USER"
    usermod -aG render "$PISIGNAGE_USER" 2>/dev/null || true
    usermod -aG audio "$PISIGNAGE_USER"
    usermod -aG input "$PISIGNAGE_USER"
    usermod -aG "$PISIGNAGE_GROUP" "$PISIGNAGE_USER"
    usermod -aG www-data "$PISIGNAGE_USER"

    # Permissions pour DRM/KMS
    if [ -e /dev/dri/card0 ]; then
        chmod 660 /dev/dri/card0
        chgrp video /dev/dri/card0
    fi

    if [ -e /dev/dri/renderD128 ]; then
        chmod 660 /dev/dri/renderD128
        chgrp render /dev/dri/renderD128 2>/dev/null || true
    fi

    log "Permissions configurées"
}

setup_gpu() {
    log "Configuration GPU pour $HW_ACCEL..."

    # Configuration config.txt pour GPU
    CONFIG_FILE="/boot/firmware/config.txt"
    [ ! -f "$CONFIG_FILE" ] && CONFIG_FILE="/boot/config.txt"

    if [ -f "$CONFIG_FILE" ]; then
        # Sauvegarde
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d)"

        # Suppression des anciennes configs GPU
        sed -i '/^gpu_mem=/d' "$CONFIG_FILE"
        sed -i '/^dtoverlay=vc4-/d' "$CONFIG_FILE"
        sed -i '/^max_framebuffers=/d' "$CONFIG_FILE"

        # Nouvelle configuration selon le modèle
        case "$HW_ACCEL" in
            pi5|pi4)
                echo "" >> "$CONFIG_FILE"
                echo "# Pi-Signage GPU Configuration" >> "$CONFIG_FILE"
                echo "gpu_mem=$GPU_MEM" >> "$CONFIG_FILE"
                echo "dtoverlay=vc4-kms-v3d" >> "$CONFIG_FILE"
                echo "max_framebuffers=2" >> "$CONFIG_FILE"
                echo "hdmi_force_hotplug=1" >> "$CONFIG_FILE"
                echo "hdmi_group=2" >> "$CONFIG_FILE"
                echo "hdmi_mode=82" >> "$CONFIG_FILE"  # 1080p 60Hz
                ;;
            pi3)
                echo "" >> "$CONFIG_FILE"
                echo "# Pi-Signage GPU Configuration" >> "$CONFIG_FILE"
                echo "gpu_mem=$GPU_MEM" >> "$CONFIG_FILE"
                echo "dtoverlay=vc4-fkms-v3d" >> "$CONFIG_FILE"
                ;;
        esac

        log "Configuration GPU appliquée"
    else
        warning "Fichier config.txt non trouvé"
    fi
}

# =============== CRÉATION DE LA STRUCTURE ===============
create_directory_structure() {
    log "Création de la structure de répertoires..."

    # Répertoires principaux
    mkdir -p "$PISIGNAGE_DIR"/{scripts,config,media,logs,cache,web,tmp}
    mkdir -p "$PISIGNAGE_DIR"/config/{mpv,vlc,nginx,php}
    mkdir -p "$PISIGNAGE_DIR"/web/{api,assets,uploads}
    mkdir -p "$PISIGNAGE_DIR"/media/{videos,images,playlists}

    # Répertoire utilisateur
    sudo -u "$PISIGNAGE_USER" mkdir -p "/home/$PISIGNAGE_USER/.config/systemd/user"
    sudo -u "$PISIGNAGE_USER" mkdir -p "/home/$PISIGNAGE_USER/.config/mpv"
    sudo -u "$PISIGNAGE_USER" mkdir -p "/home/$PISIGNAGE_USER/.config/vlc"

    # Permissions
    chown -R "$PISIGNAGE_USER:$PISIGNAGE_GROUP" "$PISIGNAGE_DIR"
    chmod 755 "$PISIGNAGE_DIR"
    chmod 755 "$PISIGNAGE_DIR"/scripts
    chmod 777 "$PISIGNAGE_DIR"/tmp
    chmod 777 "$PISIGNAGE_DIR"/logs

    log "Structure de répertoires créée"
}

# =============== CONFIGURATION MPV ===============
setup_mpv_config() {
    log "Configuration de MPV..."

    cat > "$PISIGNAGE_DIR/config/mpv/mpv.conf" << 'EOF'
# Pi-Signage MPV Configuration v0.8.1

# Accélération matérielle selon le modèle
hwdec=auto-safe
hwdec-codecs=all

# Sortie vidéo optimisée
vo=gpu
gpu-context=x11
gpu-api=opengl

# Performance
cache=yes
cache-secs=10
demuxer-max-bytes=100M
demuxer-max-back-bytes=50M

# Qualité vidéo
profile=gpu-hq
scale=bilinear
dscale=bilinear
video-sync=display-resample

# Audio
audio-pitch-correction=yes
volume=100
volume-max=150

# Affichage
fullscreen=yes
screen=0
cursor-autohide=1000
osd-level=0

# Lecture
loop-playlist=inf
loop-file=inf
keep-open=yes

# Logs
log-file=/opt/pisignage/logs/mpv.log
msg-level=all=warn
EOF

    # Copie config utilisateur
    sudo -u "$PISIGNAGE_USER" cp "$PISIGNAGE_DIR/config/mpv/mpv.conf" \
        "/home/$PISIGNAGE_USER/.config/mpv/mpv.conf"

    log "Configuration MPV créée"
}

# =============== CONFIGURATION VLC ===============
setup_vlc_config() {
    log "Configuration de VLC..."

    mkdir -p "$PISIGNAGE_DIR/config/vlc"

    cat > "$PISIGNAGE_DIR/config/vlc/vlcrc" << 'EOF'
# Pi-Signage VLC Configuration v0.8.1

[main]
intf=dummy
quiet=2

[video]
vout=gles2
fullscreen=1
video-on-top=1
video-title-show=0
video-title-timeout=0
deinterlace=-1
deinterlace-mode=blend

[audio]
volume=256
audio-replay-gain-mode=track

[core]
one-instance=0
playlist-enqueue=0
EOF

    log "Configuration VLC créée"
}

# =============== SCRIPTS PRINCIPAUX ===============
install_player_manager() {
    log "Installation du gestionnaire de lecture..."

    cat > "$PISIGNAGE_DIR/scripts/player-manager.sh" << 'EOF'
#!/bin/bash

# Pi-Signage Player Manager v0.8.1

PISIGNAGE_DIR="/opt/pisignage"
LOG_DIR="$PISIGNAGE_DIR/logs"
CONFIG_DIR="$PISIGNAGE_DIR/config"
MEDIA_DIR="$PISIGNAGE_DIR/media"

# Détection du player optimal
detect_player() {
    # MPV prioritaire si disponible
    if command -v mpv &>/dev/null; then
        echo "mpv"
    elif command -v vlc &>/dev/null; then
        echo "vlc"
    else
        echo "none"
    fi
}

# Log fonction
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/player.log"
}

# Lecture avec MPV
play_with_mpv() {
    local file="$1"
    log "Lecture MPV: $file"

    export DISPLAY=:0
    mpv --config-dir="$CONFIG_DIR/mpv" \
        --fullscreen \
        --loop-playlist=inf \
        "$file" &> "$LOG_DIR/mpv.log" &

    echo $! > /tmp/pisignage_player.pid
}

# Lecture avec VLC
play_with_vlc() {
    local file="$1"
    log "Lecture VLC: $file"

    export DISPLAY=:0
    cvlc --config "$CONFIG_DIR/vlc/vlcrc" \
         --fullscreen \
         --loop \
         --intf dummy \
         "$file" &> "$LOG_DIR/vlc.log" &

    echo $! > /tmp/pisignage_player.pid
}

# Arrêt du lecteur
stop_player() {
    if [ -f /tmp/pisignage_player.pid ]; then
        local pid=$(cat /tmp/pisignage_player.pid)
        kill -TERM $pid 2>/dev/null
        rm -f /tmp/pisignage_player.pid
        log "Lecteur arrêté (PID: $pid)"
    fi
}

# Lecture d'un fichier ou playlist
play() {
    local media="$1"

    # Fichier par défaut si aucun argument
    if [ -z "$media" ]; then
        media="$MEDIA_DIR/videos/default.mp4"
    fi

    if [ ! -e "$media" ]; then
        log "Média introuvable: $media"
        exit 1
    fi

    stop_player

    local player=$(detect_player)

    case "$player" in
        mpv)
            play_with_mpv "$media"
            ;;
        vlc)
            play_with_vlc "$media"
            ;;
        *)
            log "Aucun lecteur disponible"
            exit 1
            ;;
    esac
}

# Point d'entrée
case "$1" in
    play)
        play "$2"
        ;;
    stop)
        stop_player
        ;;
    restart)
        stop_player
        sleep 2
        play "$2"
        ;;
    status)
        if [ -f /tmp/pisignage_player.pid ]; then
            echo "Lecteur actif (PID: $(cat /tmp/pisignage_player.pid))"
        else
            echo "Aucun lecteur actif"
        fi
        ;;
    *)
        echo "Usage: $0 {play|stop|restart|status} [fichier]"
        exit 1
        ;;
esac
EOF

    chmod +x "$PISIGNAGE_DIR/scripts/player-manager.sh"
    log "Player manager installé"
}

install_screenshot_service() {
    log "Installation du service de capture d'écran..."

    cat > "$PISIGNAGE_DIR/scripts/screenshot.sh" << 'EOF'
#!/bin/bash

# Pi-Signage Screenshot Service v0.8.1

SCREENSHOT_DIR="/opt/pisignage/web/uploads"
SCREENSHOT_FILE="$SCREENSHOT_DIR/screenshot.jpg"

# Créer le répertoire si nécessaire
mkdir -p "$SCREENSHOT_DIR"

# Capture d'écran selon l'environnement
if [ -n "$DISPLAY" ]; then
    # X11 environment
    export DISPLAY=:0
    scrot -q 75 "$SCREENSHOT_FILE" 2>/dev/null || \
    import -window root -quality 75 "$SCREENSHOT_FILE" 2>/dev/null
elif [ -n "$WAYLAND_DISPLAY" ]; then
    # Wayland environment
    grim "$SCREENSHOT_FILE" 2>/dev/null
else
    # Framebuffer fallback
    fbgrab -d /dev/fb0 "$SCREENSHOT_FILE" 2>/dev/null
fi

# Vérifier le succès et ajuster les permissions
if [ -f "$SCREENSHOT_FILE" ]; then
    chmod 644 "$SCREENSHOT_FILE"
    echo "Screenshot saved: $SCREENSHOT_FILE"
else
    echo "Screenshot failed"
    exit 1
fi
EOF

    chmod +x "$PISIGNAGE_DIR/scripts/screenshot.sh"
    log "Service de capture d'écran installé"
}

# =============== CONFIGURATION NGINX ===============
setup_nginx() {
    log "Configuration de Nginx..."

    # Configuration PHP-FPM
    cat > "$PISIGNAGE_DIR/config/php/pool.conf" << EOF
[pisignage]
user = www-data
group = www-data
listen = /run/php/php8.2-fpm-pisignage.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 500
EOF

    # Configuration Nginx
    cat > /etc/nginx/sites-available/pisignage << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php index.html;

    server_name _;

    client_max_body_size 100M;
    client_body_timeout 300s;

    # API endpoints
    location /api/ {
        try_files $uri $uri/ /api/index.php?$query_string;
    }

    # PHP processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_read_timeout 300;
    }

    # Static files
    location /uploads/ {
        alias /opt/pisignage/web/uploads/;
        expires 1h;
        add_header Cache-Control "public, immutable";
    }

    # Media files
    location /media/ {
        alias /opt/pisignage/media/;
        autoindex off;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
}
EOF

    # Activation du site
    ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # Configuration PHP
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' /etc/php/8.2/fpm/php.ini
    sed -i 's/post_max_size = .*/post_max_size = 100M/' /etc/php/8.2/fpm/php.ini
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini
    sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/8.2/fpm/php.ini

    # Redémarrage des services
    systemctl restart php8.2-fpm
    systemctl restart nginx
    systemctl enable nginx
    systemctl enable php8.2-fpm

    log "Nginx configuré"
}

# =============== API WEB ===============
create_web_api() {
    log "Création de l'API Web..."

    # Page d'accueil
    cat > "$PISIGNAGE_DIR/web/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi-Signage v0.8.1</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #1a1a1a;
            color: #fff;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        h1 {
            color: #4CAF50;
        }
        .status {
            background: #2a2a2a;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .button {
            background: #4CAF50;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            margin: 5px;
        }
        .button:hover {
            background: #45a049;
        }
        .screenshot {
            max-width: 100%;
            margin: 20px 0;
            border: 2px solid #4CAF50;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Pi-Signage Control Panel v0.8.1</h1>
        <div class="status">
            <h2>État du système</h2>
            <p id="player-status">Chargement...</p>
        </div>

        <div class="controls">
            <button class="button" onclick="controlPlayer('play')">Lecture</button>
            <button class="button" onclick="controlPlayer('stop')">Arrêt</button>
            <button class="button" onclick="controlPlayer('restart')">Redémarrer</button>
            <button class="button" onclick="takeScreenshot()">Capture d'écran</button>
        </div>

        <div id="screenshot-container"></div>
    </div>

    <script>
        function controlPlayer(action) {
            fetch('/api/player.php?action=' + action)
                .then(response => response.json())
                .then(data => {
                    alert(data.message);
                    updateStatus();
                });
        }

        function takeScreenshot() {
            fetch('/api/screenshot.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        document.getElementById('screenshot-container').innerHTML =
                            '<img src="/uploads/screenshot.jpg?' + Date.now() + '" class="screenshot">';
                    }
                });
        }

        function updateStatus() {
            fetch('/api/status.php')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('player-status').textContent =
                        'Lecteur: ' + data.player_status;
                });
        }

        // Mise à jour automatique toutes les 5 secondes
        setInterval(updateStatus, 5000);
        updateStatus();
    </script>
</body>
</html>
EOF

    # API Player
    cat > "$PISIGNAGE_DIR/web/api/player.php" << 'EOF'
<?php
header('Content-Type: application/json');

$action = $_GET['action'] ?? 'status';
$script = '/opt/pisignage/scripts/player-manager.sh';

switch($action) {
    case 'play':
        exec("sudo $script play", $output);
        echo json_encode(['success' => true, 'message' => 'Lecture démarrée']);
        break;

    case 'stop':
        exec("sudo $script stop", $output);
        echo json_encode(['success' => true, 'message' => 'Lecture arrêtée']);
        break;

    case 'restart':
        exec("sudo $script restart", $output);
        echo json_encode(['success' => true, 'message' => 'Lecture redémarrée']);
        break;

    default:
        exec("$script status", $output);
        echo json_encode(['success' => true, 'status' => implode("\n", $output)]);
}
?>
EOF

    # API Screenshot
    cat > "$PISIGNAGE_DIR/web/api/screenshot.php" << 'EOF'
<?php
header('Content-Type: application/json');

$script = '/opt/pisignage/scripts/screenshot.sh';
exec("sudo $script", $output, $return);

if ($return === 0) {
    echo json_encode(['success' => true, 'message' => 'Capture réussie']);
} else {
    echo json_encode(['success' => false, 'message' => 'Échec de la capture']);
}
?>
EOF

    # API Status
    cat > "$PISIGNAGE_DIR/web/api/status.php" << 'EOF'
<?php
header('Content-Type: application/json');

// État du lecteur
exec('/opt/pisignage/scripts/player-manager.sh status', $player_output);

// Informations système
$load = sys_getloadavg();
$memory = memory_get_usage(true);
$disk = disk_free_space('/');

echo json_encode([
    'player_status' => implode(' ', $player_output),
    'system' => [
        'load' => $load[0],
        'memory_mb' => round($memory / 1024 / 1024),
        'disk_free_gb' => round($disk / 1024 / 1024 / 1024, 2)
    ],
    'version' => '0.8.1'
]);
?>
EOF

    # API Index
    cat > "$PISIGNAGE_DIR/web/api/index.php" << 'EOF'
<?php
// API Router
header('Content-Type: application/json');

$endpoints = [
    'player' => 'Control player (play/stop/restart/status)',
    'screenshot' => 'Take a screenshot',
    'status' => 'Get system status'
];

echo json_encode([
    'version' => '0.8.1',
    'endpoints' => $endpoints
]);
?>
EOF

    # Permissions
    chown -R www-data:www-data "$PISIGNAGE_DIR/web"

    log "API Web créée"
}

# =============== SERVICES SYSTEMD ===============
install_systemd_services() {
    log "Installation des services systemd..."

    # Service principal Pi-Signage
    cat > /etc/systemd/system/pisignage.service << EOF
[Unit]
Description=Pi-Signage Display Service
After=network.target graphical.target
Wants=graphical.target

[Service]
Type=simple
User=$PISIGNAGE_USER
Group=$PISIGNAGE_GROUP
WorkingDirectory=$PISIGNAGE_DIR

Environment="DISPLAY=:0"
Environment="HOME=/home/$PISIGNAGE_USER"
Environment="XDG_RUNTIME_DIR=/run/user/$(id -u $PISIGNAGE_USER)"

ExecStart=$PISIGNAGE_DIR/scripts/player-manager.sh play
ExecStop=$PISIGNAGE_DIR/scripts/player-manager.sh stop

Restart=always
RestartSec=10

StandardOutput=append:$PISIGNAGE_DIR/logs/pisignage.log
StandardError=append:$PISIGNAGE_DIR/logs/pisignage-error.log

[Install]
WantedBy=default.target
EOF

    # Service de démarrage automatique
    cat > /etc/systemd/system/pisignage-autostart.service << EOF
[Unit]
Description=Pi-Signage Auto Start
After=graphical.target

[Service]
Type=oneshot
User=$PISIGNAGE_USER
Environment="DISPLAY=:0"
ExecStart=/bin/bash -c 'sleep 10 && $PISIGNAGE_DIR/scripts/player-manager.sh play'

[Install]
WantedBy=graphical.target
EOF

    # Configuration sudoers pour www-data
    cat > /etc/sudoers.d/pisignage << EOF
www-data ALL=(ALL) NOPASSWD: $PISIGNAGE_DIR/scripts/player-manager.sh
www-data ALL=(ALL) NOPASSWD: $PISIGNAGE_DIR/scripts/screenshot.sh
EOF

    # Activation des services
    systemctl daemon-reload
    systemctl enable pisignage.service
    systemctl enable pisignage-autostart.service

    log "Services systemd installés"
}

# =============== CONFIGURATION BOOT ===============
configure_boot() {
    log "Configuration du boot..."

    # Configuration LightDM pour auto-login
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/60-pisignage.conf << EOF
[SeatDefaults]
autologin-user=$PISIGNAGE_USER
autologin-user-timeout=0
xserver-command=X -nocursor
EOF

    # Configuration Openbox autostart
    mkdir -p "/home/$PISIGNAGE_USER/.config/openbox"
    cat > "/home/$PISIGNAGE_USER/.config/openbox/autostart" << EOF
# Pi-Signage Autostart
xset s off
xset -dpms
xset s noblank

# Masquer le curseur
unclutter -idle 1 &

# Démarrage du player après 10 secondes
(sleep 10 && $PISIGNAGE_DIR/scripts/player-manager.sh play) &
EOF

    chown -R "$PISIGNAGE_USER:$PISIGNAGE_USER" "/home/$PISIGNAGE_USER/.config"

    # Configuration boot silencieux
    CMDLINE="/boot/firmware/cmdline.txt"
    [ ! -f "$CMDLINE" ] && CMDLINE="/boot/cmdline.txt"

    if [ -f "$CMDLINE" ]; then
        # Sauvegarde
        cp "$CMDLINE" "${CMDLINE}.backup.$(date +%Y%m%d)"

        # Boot silencieux
        if ! grep -q "logo.nologo" "$CMDLINE"; then
            sed -i '$ s/$/ logo.nologo quiet splash loglevel=0/' "$CMDLINE"
        fi

        # Console sur tty3 au lieu de tty1
        sed -i 's/console=tty1/console=tty3/g' "$CMDLINE"
    fi

    # Activation de LightDM
    systemctl enable lightdm
    systemctl set-default graphical.target

    log "Configuration boot appliquée"
}

# =============== INSTALLATION YT-DLP ===============
install_ytdlp() {
    log "Installation de yt-dlp..."

    curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
    chmod a+rx /usr/local/bin/yt-dlp

    log "yt-dlp installé"
}

# =============== TÉLÉCHARGEMENT MÉDIA TEST ===============
download_test_media() {
    log "Téléchargement du média de test..."

    # Création du fichier de test si pas de connexion
    if ! wget -q --spider https://sample-videos.com; then
        warning "Pas de connexion internet, création d'un fichier de test local"

        # Création d'une vidéo de test avec ffmpeg
        ffmpeg -f lavfi -i testsrc2=duration=10:size=1920x1080:rate=30 \
               -f lavfi -i sine=frequency=1000:duration=10 \
               -c:v libx264 -preset ultrafast -c:a aac \
               "$PISIGNAGE_DIR/media/videos/default.mp4" -y 2>/dev/null || \
        touch "$PISIGNAGE_DIR/media/videos/default.mp4"
    else
        # Téléchargement Big Buck Bunny
        wget -q -O "$PISIGNAGE_DIR/media/videos/default.mp4" \
            "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_10mb.mp4" || \
        wget -q -O "$PISIGNAGE_DIR/media/videos/default.mp4" \
            "https://www.w3schools.com/html/mov_bbb.mp4" || \
        warning "Impossible de télécharger la vidéo de test"
    fi

    chown -R "$PISIGNAGE_USER:$PISIGNAGE_GROUP" "$PISIGNAGE_DIR/media"

    log "Média de test prêt"
}

# =============== CLONE GITHUB (OPTIONNEL) ===============
clone_github_repo() {
    log "Clonage du repository GitHub..."

    if [ -d "/tmp/Pi-Signage" ]; then
        rm -rf /tmp/Pi-Signage
    fi

    # Clone le repo si disponible
    if git clone "$GITHUB_REPO" /tmp/Pi-Signage 2>/dev/null; then
        # Copie des fichiers existants depuis le repo
        if [ -d "/tmp/Pi-Signage/web" ]; then
            cp -r /tmp/Pi-Signage/web/* "$PISIGNAGE_DIR/web/" 2>/dev/null || true
        fi
        if [ -d "/tmp/Pi-Signage/scripts" ]; then
            cp -r /tmp/Pi-Signage/scripts/* "$PISIGNAGE_DIR/scripts/" 2>/dev/null || true
        fi
        if [ -d "/tmp/Pi-Signage/config" ]; then
            cp -r /tmp/Pi-Signage/config/* "$PISIGNAGE_DIR/config/" 2>/dev/null || true
        fi
        chmod +x "$PISIGNAGE_DIR"/scripts/*.sh 2>/dev/null || true
        log "Repository GitHub cloné"
    else
        warning "Repository GitHub non disponible, utilisation de la configuration par défaut"
    fi

    rm -rf /tmp/Pi-Signage
}

# =============== VALIDATION ===============
validate_installation() {
    log "Validation de l'installation..."

    local errors=0

    # Vérification des répertoires
    for dir in scripts config media logs web; do
        if [ ! -d "$PISIGNAGE_DIR/$dir" ]; then
            warning "Répertoire manquant: $PISIGNAGE_DIR/$dir"
            ((errors++))
        fi
    done

    # Vérification des scripts
    for script in player-manager.sh screenshot.sh; do
        if [ ! -x "$PISIGNAGE_DIR/scripts/$script" ]; then
            warning "Script manquant ou non exécutable: $script"
            ((errors++))
        fi
    done

    # Vérification des services
    if ! systemctl list-unit-files | grep -q pisignage.service; then
        warning "Service systemd non installé"
        ((errors++))
    fi

    # Vérification de Nginx
    if ! nginx -t 2>/dev/null; then
        warning "Configuration Nginx invalide"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        log "✓ Installation validée avec succès!"
        return 0
    else
        warning "⚠ Installation terminée avec $errors avertissements"
        return 1
    fi
}

# =============== FONCTION PRINCIPALE ===============
main() {
    log "╔════════════════════════════════════════════════════════╗"
    log "║     Pi-Signage v$PISIGNAGE_VERSION - Installation Complète      ║"
    log "╚════════════════════════════════════════════════════════╝"

    # Vérifications préliminaires
    check_root
    detect_os
    detect_pi_model

    # Installation
    log "▶ Phase 1: Installation des paquets"
    install_packages

    log "▶ Phase 2: Configuration système"
    setup_permissions
    setup_gpu

    log "▶ Phase 3: Création de la structure"
    create_directory_structure

    log "▶ Phase 4: Configuration des lecteurs"
    setup_mpv_config
    setup_vlc_config

    log "▶ Phase 5: Installation des scripts"
    install_player_manager
    install_screenshot_service

    log "▶ Phase 6: Configuration Web"
    setup_nginx
    create_web_api

    log "▶ Phase 7: Services systemd"
    install_systemd_services

    log "▶ Phase 8: Configuration boot"
    configure_boot

    log "▶ Phase 9: Outils supplémentaires"
    install_ytdlp

    log "▶ Phase 10: Clone GitHub (optionnel)"
    clone_github_repo

    log "▶ Phase 11: Média de test"
    download_test_media

    log "▶ Phase 12: Validation"
    validate_installation

    # Résumé final
    log ""
    log "╔════════════════════════════════════════════════════════╗"
    log "║         Installation Pi-Signage Terminée !              ║"
    log "╚════════════════════════════════════════════════════════╝"
    log ""
    log "📺 Interface Web:     http://$(hostname -I | cut -d' ' -f1)"
    log "📁 Répertoire:        $PISIGNAGE_DIR"
    log "📝 Logs:              $PISIGNAGE_DIR/logs/"
    log ""
    log "🎬 Commandes disponibles:"
    log "  - Démarrer:    sudo systemctl start pisignage"
    log "  - Arrêter:     sudo systemctl stop pisignage"
    log "  - Statut:      sudo systemctl status pisignage"
    log "  - Logs:        tail -f $PISIGNAGE_DIR/logs/pisignage.log"
    log ""
    log "⚠️  IMPORTANT: Redémarrez le système pour appliquer toutes les modifications"
    log "  sudo reboot"
    log ""
}

# =============== EXÉCUTION ===============
main "$@"