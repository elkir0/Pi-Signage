b#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════╗
# ║                  PiSignage v0.8.9 - Installation Unifiée             ║
# ║                     Script d'installation ONE-CLICK                   ║
# ║                          Date: 2025-10-01                            ║
# ╚══════════════════════════════════════════════════════════════════════╝

set -e

# Configuration
VERSION="0.8.9"
INSTALL_DIR="/opt/pisignage"
GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
BBB_URL="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonctions d'affichage
log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "\n${BLUE}═══ $1 ═══${NC}\n"; }

# Vérifier si root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Ce script ne doit pas être exécuté en root"
        log_info "Utilisation: bash install.sh"
        exit 1
    fi
}

# Bannière
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║                    🎬 PiSignage v${VERSION} Installer 🎬                   ║"
    echo "║                                                                      ║"
    echo "║                  Digital Signage pour Raspberry Pi                  ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "Ce script va installer:"
    echo "  • Serveur web (nginx/Apache + PHP)"
    echo "  • VLC (lecteur vidéo)"
    echo "  • Interface web glassmorphisme v${VERSION}"
    echo "  • Big Buck Bunny (vidéo de démo)"
    echo "  • Configuration automatique au démarrage"
    echo ""
    # Mode interactif ou automatique
    if [ "$1" != "--auto" ]; then
        read -p "Appuyez sur Entrée pour commencer l'installation..."
    else
        echo "Mode automatique activé"
    fi
}

# Mise à jour du système
update_system() {
    log_step "Mise à jour du système"
    sudo apt-get update -qq
    # Configuration pour éviter les interactions
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    # Forcer les configurations par défaut pour éviter les blocages
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef" || true
    log_info "Système mis à jour"
}

# Installation des dépendances
install_dependencies() {
    log_step "Installation des dépendances"

    # Configuration pour éviter les interactions
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    # Détection automatique de la version PHP
    PHP_VERSION=""
    if command -v php > /dev/null 2>&1; then
        PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)
    fi

    # Utiliser PHP 8.2 par défaut si non détecté
    if [ -z "$PHP_VERSION" ]; then
        PHP_VERSION="8.2"
        log_info "Version PHP non détectée, utilisation de PHP $PHP_VERSION par défaut"
    else
        log_info "Version PHP détectée : $PHP_VERSION"
    fi

    # Packages essentiels uniquement
    local packages=(
        "nginx"
        "php${PHP_VERSION}-fpm"
        "php${PHP_VERSION}-cli"
        "php${PHP_VERSION}-mbstring"
        "php${PHP_VERSION}-gd"
        "php${PHP_VERSION}-sqlite3"
        "php${PHP_VERSION}-xml"
        "php${PHP_VERSION}-curl"
        "php${PHP_VERSION}-zip"
        "sqlite3"
        "vlc"
        "ffmpeg"
        "xinit"
        "x11-xserver-utils"
        "xserver-xorg"
        "grim"
        "fbgrab"
        "scrot"
        "imagemagick"
        "wget"
        "curl"
        "jq"
        "socat"
    )

    log_info "Installation des packages essentiels..."
    for package in "${packages[@]}"; do
        echo -n "  • Installation de $package... "
        if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
            -o Dpkg::Options::="--force-confold" \
            -o Dpkg::Options::="--force-confdef" \
            "$package" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}⚠ Déjà installé ou optionnel${NC}"
        fi
    done

    # Installation de raspi2png si disponible
    if [ -f /usr/bin/raspi2png ]; then
        log_info "raspi2png déjà installé"
    else
        log_warn "Tentative d'installation de raspi2png..."
        cd /tmp
        if git clone https://github.com/AndrewFromMelbourne/raspi2png.git > /dev/null 2>&1; then
            cd raspi2png
            make > /dev/null 2>&1 && sudo make install > /dev/null 2>&1 || true
            cd /tmp && rm -rf raspi2png
        fi
    fi

    log_info "Toutes les dépendances installées"
}

# Création de la structure de dossiers
create_structure() {
    log_step "Création de la structure PiSignage"

    sudo mkdir -p $INSTALL_DIR/{web,media,config,logs,scripts,backups,data}
    sudo mkdir -p $INSTALL_DIR/web/{api,assets,css,js,screenshots}
    sudo mkdir -p /dev/shm/pisignage-screenshots

    # Permissions élargies pour éviter les problèmes
    sudo chown -R www-data:www-data $INSTALL_DIR
    chmod 755 $INSTALL_DIR
    # Permissions spécifiques pour les répertoires critiques
    chmod 777 $INSTALL_DIR/logs
    chmod 777 $INSTALL_DIR/media
    chmod 755 $INSTALL_DIR/web
    chmod 755 $INSTALL_DIR/scripts
    chmod 755 $INSTALL_DIR/config
    chmod 755 $INSTALL_DIR/data
    chmod 777 $INSTALL_DIR/web/screenshots

    # Initialiser la base de données SQLite
    DB_FILE="$INSTALL_DIR/pisignage.db"
    if [ ! -f "$DB_FILE" ]; then
        log_info "Initialisation de la base de données..."
        sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS media (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL,
    path TEXT NOT NULL,
    type TEXT,
    size INTEGER,
    duration INTEGER,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS playlists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS playlist_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id INTEGER,
    media_id INTEGER,
    position INTEGER,
    duration INTEGER,
    FOREIGN KEY(playlist_id) REFERENCES playlists(id),
    FOREIGN KEY(media_id) REFERENCES media(id)
);

CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level TEXT,
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
        chmod 666 "$DB_FILE"
        log_info "Base de données initialisée"
    fi

    log_info "Structure créée dans $INSTALL_DIR"
}

# Cloner depuis GitHub (optionnel)
clone_from_github() {
    log_step "Récupération depuis GitHub (optionnel)"

    if [ -d "$INSTALL_DIR/.git" ]; then
        log_info "Dépôt Git déjà présent"
        cd $INSTALL_DIR
        git pull origin main 2>/dev/null || true
    else
        # Si le dépôt n'existe pas, on continue avec l'installation locale
        log_info "Installation locale"
    fi
}

# Téléchargement de Big Buck Bunny
download_bbb() {
    log_step "Téléchargement de Big Buck Bunny"

    if [ -f "$INSTALL_DIR/media/BigBuckBunny_720p.mp4" ]; then
        log_info "Big Buck Bunny déjà présent"
    else
        log_info "Téléchargement en cours..."
        wget -q --show-progress -O "$INSTALL_DIR/media/BigBuckBunny_720p.mp4" "$BBB_URL" || \
        wget -q --show-progress -O "$INSTALL_DIR/media/BigBuckBunny_720p.mp4" \
            "http://distribution.bbb3d.renderfarming.net/video/mp4/bbb_sunflower_1080p_60fps_normal.mp4"
        log_info "Big Buck Bunny téléchargé"
    fi
}

# Copier les fichiers depuis GitHub
copy_project_files() {
    log_step "Récupération des fichiers du projet"

    # Télécharger depuis GitHub
    log_info "Téléchargement de l'interface web depuis GitHub..."
    wget -q https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web/index.php \
        -O $INSTALL_DIR/web/index.php || true

    mkdir -p $INSTALL_DIR/web/api
    wget -q https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web/api/screenshot-raspi2png.php \
        -O $INSTALL_DIR/web/api/screenshot-raspi2png.php || true

    wget -q https://raw.githubusercontent.com/elkir0/Pi-Signage/main/config/player-config.json \
        -O $INSTALL_DIR/config/player-config.json || true

    wget -q https://raw.githubusercontent.com/elkir0/Pi-Signage/main/CLAUDE.md \
        -O $INSTALL_DIR/CLAUDE.md || true

    log_info "Fichiers récupérés depuis GitHub"

    # Créer le fichier config.php
    cat > $INSTALL_DIR/web/config.php << 'ENDOFCONFIG'
<?php
/**
 * PiSignage - Configuration centrale
 */

// Version
define('PISIGNAGE_VERSION', 'v0.8.9');

// Chemins
define('BASE_DIR', '/opt/pisignage');
define('MEDIA_DIR', BASE_DIR . '/media');
define('MEDIA_PATH', BASE_DIR . '/media'); // Alias pour compatibilité
define('PLAYLISTS_PATH', BASE_DIR . '/playlists');
define('SCREENSHOTS_DIR', BASE_DIR . '/web/screenshots');
define('SCREENSHOTS_PATH', BASE_DIR . '/web/screenshots'); // Alias
define('LOGS_DIR', BASE_DIR . '/logs');
define('LOGS_PATH', BASE_DIR . '/logs'); // Alias
define('DB_PATH', BASE_DIR . '/data/pisignage.db');

// Limites d'upload (500MB)
ini_set('upload_max_filesize', '500M');
ini_set('post_max_size', '500M');
ini_set('max_execution_time', '300');
ini_set('max_input_time', '300');

// Helper functions
function jsonResponse($success, $data = null, $message = '', $httpCode = 200) {
    http_response_code($httpCode);
    header('Content-Type: application/json');

    $response = [
        'success' => $success,
        'data' => $data,
        'message' => $message,
        'timestamp' => date('Y-m-d H:i:s')
    ];

    echo json_encode($response, JSON_PRETTY_PRINT);
    exit;
}

function getMediaFiles() {
    $mediaDir = MEDIA_DIR;
    $files = [];

    if (is_dir($mediaDir)) {
        $items = scandir($mediaDir);
        foreach ($items as $item) {
            if ($item !== '.' && $item !== '..' && !is_dir($mediaDir . '/' . $item)) {
                if (!in_array(pathinfo($item, PATHINFO_EXTENSION), ['m3u', 'db', 'json'])) {
                    $files[] = [
                        'name' => $item,
                        'size' => filesize($mediaDir . '/' . $item),
                        'type' => mime_content_type($mediaDir . '/' . $item)
                    ];
                }
            }
        }
    }

    return $files;
}
?>
ENDOFCONFIG

    log_info "Fichier config.php créé"
}

# Création/mise à jour de player-config.json
create_config() {
    log_step "Configuration du système"

    cat > $INSTALL_DIR/config/player-config.json << 'ENDOFFILE'
{
  "player": {
    "default": "vlc",
    "current": "vlc",
    "available": ["vlc"]
  },
  "vlc": {
    "enabled": true,
    "version": "3.0.18",
    "binary": "/usr/bin/cvlc",
    "config_path": "/home/pi/.config/vlc/vlcrc",
    "http_port": 8080,
    "http_password": "signage123",
    "log_file": "/opt/pisignage/logs/vlc.log"
  },
  "mpv": {
    "enabled": false,
    "note": "MPV support removed in v0.8.9 - VLC exclusive",
    "version": "0.35.0",
    "binary": "/usr/bin/mpv",
    "config_path": "/home/pi/.config/mpv/mpv.conf",
    "socket": "/tmp/mpv-socket",
    "log_file": "/opt/pisignage/logs/mpv.log"
  },
  "system": {
    "pi_model": "auto",
    "display": ":0",
    "autostart": true,
    "watchdog": true
  }
}
ENDOFFILE

    log_info "Configuration créée"
}

# Création du script de démarrage VLC
create_vlc_script() {
    log_step "Création des scripts de contrôle"

    cat > $INSTALL_DIR/scripts/start-vlc.sh << 'ENDOFFILE'
#!/bin/bash

echo "=== PiSignage v0.8.1 - Démarrage VLC ==="

# Arrêt gracieux des lecteurs existants
systemctl --user stop pisignage-vlc.service 2>/dev/null || true
pkill -TERM vlc 2>/dev/null || true
sleep 2

# Configuration de l'environnement
export DISPLAY=${DISPLAY:-:0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

# Détection Wayland/X11
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "Environnement: Wayland"
    VLC_OPTIONS="--intf dummy --vout gles2 --fullscreen --loop --no-video-title-show --quiet"
else
    echo "Environnement: X11"
    VLC_OPTIONS="--intf dummy --vout x11 --fullscreen --loop --no-video-title-show --quiet"
fi

# Fichier vidéo
VIDEO="/opt/pisignage/media/BigBuckBunny_720p.mp4"

# Si pas de BBB, chercher une autre vidéo
if [ ! -f "$VIDEO" ]; then
    VIDEO=$(find /opt/pisignage/media -name "*.mp4" -o -name "*.mkv" | head -1)
fi

# Démarrer VLC avec la commande stabilisée (compatible avec le service unifié)
if [ -n "$VIDEO" ]; then
    # Utilisation de la configuration unifiée avec HTTP interface
    vlc --intf http \
        --extraintf dummy \
        --http-host 0.0.0.0 \
        --http-port 8080 \
        --http-password pisignage \
        --fullscreen \
        --loop \
        --no-video-title-show \
        --video-on-top \
        --no-osd \
        --quiet \
        "$VIDEO" > /opt/pisignage/logs/vlc.log 2>&1 &

    VLC_PID=$!
    echo $VLC_PID > /opt/pisignage/vlc.pid
    echo "✓ VLC démarré avec $(basename "$VIDEO") et HTTP interface (PID: $VLC_PID)"
    echo "  Interface HTTP: http://localhost:8080 (mot de passe: pisignage)"
else
    echo "✗ Aucune vidéo trouvée"
    exit 1
fi
ENDOFFILE

    chmod +x $INSTALL_DIR/scripts/start-vlc.sh

    # Script d'autostart
    cat > $INSTALL_DIR/scripts/autostart.sh << 'ENDOFFILE'
#!/bin/bash

# Attendre que le système soit prêt
sleep 10

# Démarrer le serveur web si nécessaire
if ! systemctl is-active --quiet nginx && ! systemctl is-active --quiet apache2; then
    cd /opt/pisignage/web
    php -S 0.0.0.0:80 index.php > /opt/pisignage/logs/php-server.log 2>&1 &
fi

# Démarrer le service VLC unifié
sudo systemctl start pisignage-vlc.service || true

# Watchdog - vérifier le service VLC
while true; do
    if ! systemctl is-active --quiet pisignage-vlc.service; then
        echo "Service VLC arrêté, redémarrage..."
        sudo systemctl restart pisignage-vlc.service
    fi
    sleep 30
done
ENDOFFILE

    chmod +x $INSTALL_DIR/scripts/autostart.sh

    log_info "Scripts créés"
}

# Configuration du serveur web
configure_webserver() {
    log_step "Configuration du serveur web"

    # Configurer nginx
    if command -v nginx > /dev/null 2>&1; then
        # Supprimer d'abord la config par défaut
        sudo rm -f /etc/nginx/sites-enabled/default

        sudo tee /etc/nginx/sites-available/pisignage > /dev/null << ENDOFFILE
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php index.html;

    server_name _;

    # Configuration des limites d'upload pour 500MB
    client_max_body_size 500M;
    client_body_buffer_size 128k;
    client_body_timeout 300s;

    # Timeouts augmentés pour les gros fichiers
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    send_timeout 300s;

    # Configuration FastCGI pour PHP
    fastcgi_connect_timeout 300s;
    fastcgi_send_timeout 300s;
    fastcgi_read_timeout 300s;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 256 16k;
    fastcgi_busy_buffers_size 256k;

    # Répertoire temporaire pour les uploads
    client_body_temp_path /tmp/nginx_upload 1 2;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # API routes - support PATH_INFO for REST APIs (v0.8.8+)
    location ~ ^/api/(.+\.php)(/.*)?$ {
        fastcgi_split_path_info ^(/api/.+\.php)(/.*)?$;
        set \$script \$fastcgi_script_name;
        set \$path_info \$fastcgi_path_info;

        fastcgi_param SCRIPT_FILENAME \$document_root\$script;
        fastcgi_param PATH_INFO \$path_info;
        fastcgi_param SCRIPT_NAME \$script;

        include fastcgi_params;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;

        # Timeouts spécifiques pour PHP
        fastcgi_read_timeout 300s;
        fastcgi_send_timeout 300s;

        # Buffers pour gérer les gros uploads
        fastcgi_buffer_size 256k;
        fastcgi_buffers 256 256k;
        fastcgi_busy_buffers_size 512k;
        fastcgi_max_temp_file_size 0;
    }

    location /api {
        try_files \$uri \$uri/ /api/index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;

        # Timeouts spécifiques pour PHP
        fastcgi_read_timeout 300s;
        fastcgi_send_timeout 300s;

        # Buffers pour gérer les gros uploads
        fastcgi_buffer_size 256k;
        fastcgi_buffers 256 256k;
        fastcgi_busy_buffers_size 512k;
        fastcgi_max_temp_file_size 0;
    }

    location ~ /\.ht {
        deny all;
    }

    # Logs
    access_log /opt/pisignage/logs/nginx_access.log;
    error_log /opt/pisignage/logs/nginx_error.log warn;
}
ENDOFFILE

        sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/

        # Configurer les limites PHP pour uploads
        # Détecter automatiquement la version PHP
        PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.2")
        PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"

        if [ -f "$PHP_INI" ]; then
            sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' "$PHP_INI"
            sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' "$PHP_INI"
            sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
            sudo sed -i 's/max_input_time = .*/max_input_time = 300/' "$PHP_INI"
            sudo sed -i 's/memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
            log_info "Limites PHP $PHP_VERSION configurées (500MB uploads)"
        else
            log_warn "php.ini non trouvé pour PHP $PHP_VERSION"
        fi

        # Créer le répertoire temporaire pour nginx
        sudo mkdir -p /tmp/nginx_upload
        sudo chown www-data:www-data /tmp/nginx_upload

        # Redémarrer les services avec détection de version PHP
        sudo systemctl restart nginx || true
        PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.2")
        sudo systemctl restart php${PHP_VERSION}-fpm || true
        log_info "Nginx configuré avec PHP $PHP_VERSION"

    # Sinon essayer Apache
    elif command -v apache2 > /dev/null 2>&1; then
        sudo tee /etc/apache2/sites-available/pisignage.conf > /dev/null << ENDOFFILE
<VirtualHost *:80>
    DocumentRoot /opt/pisignage/web

    <Directory /opt/pisignage/web>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/pisignage-error.log
    CustomLog \${APACHE_LOG_DIR}/pisignage-access.log combined
</VirtualHost>
ENDOFFILE

        sudo a2enmod php* rewrite || true
        sudo a2ensite pisignage || true
        sudo a2dissite 000-default || true
        sudo systemctl restart apache2 || true
        log_info "Apache configuré"

    else
        log_warn "Aucun serveur web trouvé, utilisation du serveur PHP intégré"
    fi
}

# Configuration du démarrage automatique
configure_autostart() {
    log_step "Configuration du démarrage automatique"

    # Créer le service systemd
    sudo tee /etc/systemd/system/pisignage.service > /dev/null << ENDOFFILE
[Unit]
Description=PiSignage Digital Signage System
After=network.target graphical.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/pisignage
Environment="DISPLAY=:0"
Environment="XDG_RUNTIME_DIR=/run/user/$(id -u)"
ExecStart=/opt/pisignage/scripts/autostart.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
ENDOFFILE

    # Activer le service
    sudo systemctl daemon-reload
    sudo systemctl enable pisignage.service
    sudo systemctl start pisignage.service || true

    log_info "Service de démarrage automatique configuré"

    # Créer le script de démarrage VLC
    cat > $INSTALL_DIR/scripts/autostart-vlc.sh << 'ENDOFSCRIPT'
#!/bin/bash
# Script de démarrage automatique VLC pour PiSignage

# Attendre que le système soit prêt
sleep 10

# Créer le répertoire runtime si nécessaire
export XDG_RUNTIME_DIR=/run/user/1000
mkdir -p $XDG_RUNTIME_DIR
chown pi:pi $XDG_RUNTIME_DIR

# Arrêter toute instance VLC existante proprement
systemctl --user stop pisignage-vlc.service 2>/dev/null || true
pkill -TERM vlc 2>/dev/null || true
sleep 3

# Démarrer le service VLC unifié (recommandé)
systemctl --user start pisignage-vlc.service 2>/dev/null || \
sudo systemctl start pisignage-vlc.service

echo "Service VLC unifié démarré avec succès"
echo "Interface HTTP disponible sur: http://localhost:8080"
echo "Mot de passe: pisignage"
ENDOFSCRIPT
    chmod +x $INSTALL_DIR/scripts/autostart-vlc.sh

    # Créer le service systemd unifié pour VLC avec interface HTTP
    sudo tee /etc/systemd/system/pisignage-vlc.service > /dev/null << ENDOFSERVICE
[Unit]
Description=PiSignage VLC Media Player with HTTP Interface
After=network.target display-manager.service
Requires=network.target

[Service]
Type=simple
User=pi
Group=video
Environment="DISPLAY=:0"
Environment="HOME=/home/pi"
Environment="XDG_RUNTIME_DIR=/run/user/1000"
WorkingDirectory=/opt/pisignage

# Start VLC with both display output and HTTP interface
ExecStart=/usr/bin/vlc \\
    --intf http \\
    --extraintf dummy \\
    --http-host 0.0.0.0 \\
    --http-port 8080 \\
    --http-password pisignage \\
    --fullscreen \\
    --no-video-title-show \\
    --loop \\
    --playlist-autostart \\
    --video-on-top \\
    --no-osd \\
    /opt/pisignage/media/

# Graceful shutdown - no more pkill/killall conflicts
ExecStop=/bin/kill -TERM \$MAINPID
TimeoutStopSec=15
KillMode=mixed
Restart=on-failure
RestartSec=5
StandardOutput=append:/opt/pisignage/logs/vlc.log
StandardError=append:/opt/pisignage/logs/vlc.log

[Install]
WantedBy=multi-user.target
ENDOFSERVICE

    sudo systemctl daemon-reload
    sudo systemctl enable pisignage-vlc.service
    sudo systemctl start pisignage-vlc.service || true

    log_info "Service VLC configuré pour démarrage automatique"
}

# Configuration des permissions sudo (pour redémarrage)
configure_sudo() {
    log_step "Configuration des permissions"

    echo "$USER ALL=(ALL) NOPASSWD: /sbin/shutdown, /sbin/reboot, /bin/systemctl" | \
        sudo tee /etc/sudoers.d/pisignage > /dev/null

    log_info "Permissions configurées"
}

# Test de l'installation
test_installation() {
    log_step "Test de l'installation"

    # Vérifier que le serveur web répond
    sleep 3
    local ip=$(hostname -I | awk '{print $1}')

    if curl -s "http://localhost" > /dev/null 2>&1; then
        log_info "Serveur web OK"
    else
        log_warn "Serveur web ne répond pas encore"
    fi

    # Vérifier le service VLC unifié
    if systemctl is-active --quiet pisignage-vlc.service; then
        log_info "Service VLC unifié en cours d'exécution"
    else
        log_warn "Service VLC unifié n'est pas encore démarré"
        # Essayer de le démarrer
        sudo systemctl start pisignage-vlc.service || true
    fi

    # Vérifier le service
    if systemctl is-active --quiet pisignage; then
        log_info "Service PiSignage actif"
    else
        log_warn "Service PiSignage inactif"
    fi

    # Vérification finale de la configuration unifiée
    if systemctl is-enabled --quiet pisignage-vlc.service; then
        log_info "✓ Service VLC unifié correctement configuré"
    else
        log_warn "Service VLC unifié non activé"
    fi

    # Vérifier l'interface HTTP
    if curl -s --connect-timeout 5 http://localhost:8080 >/dev/null 2>&1; then
        log_info "✓ Interface HTTP VLC accessible"
    else
        log_warn "Interface HTTP VLC non accessible (normal au premier démarrage)"
    fi

    log_info "Tests terminés"
}

# Fonction principale
main() {
    check_root
    show_banner
    update_system
    install_dependencies
    create_structure
    clone_from_github
    download_bbb
    copy_project_files
    create_config
    create_vlc_script
    configure_webserver
    configure_sudo
    configure_autostart
    test_installation

    local ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                      ║${NC}"
    echo -e "${GREEN}║               🎉 Installation Terminée avec Succès! 🎉              ║${NC}"
    echo -e "${GREEN}║                                                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📋 Informations d'accès:"
    echo "   • Interface Web: http://${ip}"
    echo "   • Version: ${VERSION}"
    echo "   • Dossier: $INSTALL_DIR"
    echo ""
    echo "🚀 PiSignage démarre automatiquement au boot!"
    echo ""
    echo "💡 Commandes utiles:"
    echo "   sudo systemctl status pisignage     # Voir le statut principal"
    echo "   sudo systemctl status pisignage-vlc # Voir le statut VLC"
    echo "   sudo systemctl restart pisignage-vlc # Redémarrer VLC"
    echo "   tail -f $INSTALL_DIR/logs/vlc.log   # Voir les logs VLC"
    echo "   Interface HTTP VLC: http://${ip}:8080 (mot de passe: pisignage)"
    echo ""
    echo "📝 Documentation: $INSTALL_DIR/CLAUDE.md"
    echo ""
}

# Exécuter l'installation
main "$@"