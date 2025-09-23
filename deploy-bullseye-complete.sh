#!/bin/bash
# PiSignage v0.8.0 - Déploiement complet pour Raspberry Pi OS Bullseye
# Script d'installation et de configuration automatique

set -e

# Configuration
PISIGNAGE_VERSION="0.8.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/opt/pisignage"
LOG_FILE="$TARGET_DIR/logs/deployment.log"
TEMP_DIR="/tmp/pisignage-deploy"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions d'affichage
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE" >&2
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

# Fonction pour afficher le header
show_header() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║           🎬 PiSignage v0.8.0 Deployment 🎬              ║
║                                                          ║
║        Digital Signage Solution for Raspberry Pi        ║
║              Compatible avec Bullseye                   ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Vérifications préliminaires
check_system() {
    info "Vérification du système..."

    # Vérifier que c'est un Raspberry Pi
    if [[ ! -f /proc/cpuinfo ]] || ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
            warn "Ce script est optimisé pour Raspberry Pi, mais peut fonctionner sur d'autres systèmes"
        fi
    fi

    # Vérifier la version de l'OS
    if [[ -f /etc/os-release ]]; then
        local os_name=$(grep ^NAME= /etc/os-release | cut -d= -f2 | tr -d '"')
        local os_version=$(grep ^VERSION= /etc/os-release | cut -d= -f2 | tr -d '"')
        info "OS détecté: $os_name $os_version"

        if grep -q "bullseye" /etc/os-release; then
            info "✓ Raspberry Pi OS Bullseye détecté"
        else
            warn "⚠ Cette version d'OS n'est pas Bullseye, certaines fonctionnalités peuvent ne pas fonctionner"
        fi
    fi

    # Vérifier les permissions
    if [[ $EUID -eq 0 ]]; then
        info "✓ Exécution en tant que root"
    else
        if command -v sudo >/dev/null 2>&1; then
            info "✓ sudo disponible"
            SUDO="sudo"
        else
            error "Ce script nécessite les privilèges root ou sudo"
            exit 1
        fi
    fi

    # Vérifier l'espace disque
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 1048576 ]]; then  # 1GB en KB
        error "Espace disque insuffisant. Au moins 1GB requis."
        exit 1
    fi

    info "✓ Vérifications système terminées"
}

# Créer la structure de dossiers
create_directory_structure() {
    info "Création de la structure de dossiers..."

    # Créer le dossier principal si nécessaire
    if [[ "$SCRIPT_DIR" != "$TARGET_DIR" ]]; then
        $SUDO mkdir -p "$TARGET_DIR"
        if [[ -d "$SCRIPT_DIR" ]]; then
            info "Copie des fichiers depuis $SCRIPT_DIR vers $TARGET_DIR"
            $SUDO cp -r "$SCRIPT_DIR"/* "$TARGET_DIR/"
        fi
    fi

    # Créer les sous-dossiers
    local directories=(
        "$TARGET_DIR/web"
        "$TARGET_DIR/web/api"
        "$TARGET_DIR/scripts"
        "$TARGET_DIR/media"
        "$TARGET_DIR/config"
        "$TARGET_DIR/config/playlists"
        "$TARGET_DIR/config/schedules"
        "$TARGET_DIR/logs"
        "$TARGET_DIR/screenshots"
        "$TARGET_DIR/media/thumbnails"
    )

    for dir in "${directories[@]}"; do
        $SUDO mkdir -p "$dir"
        info "✓ Créé: $dir"
    done

    # Créer le fichier VERSION
    echo "$PISIGNAGE_VERSION" | $SUDO tee "$TARGET_DIR/VERSION" > /dev/null

    info "✓ Structure de dossiers créée"
}

# Installer les dépendances système
install_system_dependencies() {
    info "Installation des dépendances système..."

    # Mettre à jour les paquets
    log "Mise à jour de la liste des paquets..."
    $SUDO apt-get update -qq

    # Paquets essentiels
    local essential_packages=(
        "nginx"
        "php7.4-fpm"
        "php7.4-sqlite3"
        "php7.4-curl"
        "php7.4-gd"
        "php7.4-xml"
        "php7.4-mbstring"
        "php7.4-json"
        "sqlite3"
        "curl"
        "wget"
        "unzip"
        "git"
        "htop"
        "screen"
        "rsync"
    )

    # Paquets média
    local media_packages=(
        "vlc"
        "ffmpeg"
        "scrot"
        "imagemagick"
        "python3"
        "python3-pip"
    )

    # Installer les paquets essentiels
    for package in "${essential_packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            info "✓ $package déjà installé"
        else
            log "Installation de $package..."
            $SUDO apt-get install -y "$package"
        fi
    done

    # Installer les paquets média
    for package in "${media_packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            info "✓ $package déjà installé"
        else
            log "Installation de $package..."
            $SUDO apt-get install -y "$package"
        fi
    done

    info "✓ Dépendances système installées"
}

# Configurer PHP et Nginx
configure_web_server() {
    info "Configuration du serveur web..."

    # Configuration PHP-FPM
    local php_ini="/etc/php/7.4/fpm/php.ini"
    if [[ -f "$php_ini" ]]; then
        log "Configuration de PHP..."

        # Backup de la configuration originale
        $SUDO cp "$php_ini" "$php_ini.backup.$(date +%Y%m%d)"

        # Modifications PHP pour PiSignage
        $SUDO sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' "$php_ini"
        $SUDO sed -i 's/post_max_size = .*/post_max_size = 500M/' "$php_ini"
        $SUDO sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$php_ini"
        $SUDO sed -i 's/memory_limit = .*/memory_limit = 256M/' "$php_ini"
        $SUDO sed -i 's/max_input_time = .*/max_input_time = 300/' "$php_ini"

        info "✓ PHP configuré"
    fi

    # Configuration Nginx
    local nginx_config="/etc/nginx/sites-available/pisignage"

    cat << 'EOF' | $SUDO tee "$nginx_config" > /dev/null
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php index.html index.htm;

    server_name _;

    # Sécurité
    server_tokens off;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;

    # Gestion des fichiers statiques
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API endpoints
    location /api/ {
        try_files $uri $uri/ =404;
        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
    }

    # Screenshots directory
    location /screenshots/ {
        alias /opt/pisignage/screenshots/;
        autoindex on;
    }

    # Media directory
    location /media/ {
        alias /opt/pisignage/media/;
        autoindex on;
    }

    # PHP handling
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }

    location ~ /(config|logs|scripts)/ {
        deny all;
    }
}
EOF

    # Activer le site
    $SUDO ln -sf "$nginx_config" /etc/nginx/sites-enabled/pisignage
    $SUDO rm -f /etc/nginx/sites-enabled/default

    # Tester la configuration Nginx
    if $SUDO nginx -t; then
        info "✓ Configuration Nginx valide"
    else
        error "Configuration Nginx invalide"
        exit 1
    fi

    info "✓ Serveur web configuré"
}

# Configurer VLC
configure_vlc() {
    info "Configuration de VLC..."

    # Créer le dossier de configuration VLC pour l'utilisateur pi
    $SUDO mkdir -p /home/pi/.config/vlc

    # Configuration VLC pour l'interface HTTP
    cat << 'EOF' | $SUDO tee /home/pi/.config/vlc/vlcrc > /dev/null
[main]
intf=dummy
extraintf=http

[http]
http-host=127.0.0.1
http-port=8080
http-password=vlcpassword
EOF

    # Permissions pour l'utilisateur pi
    $SUDO chown -R pi:pi /home/pi/.config/vlc

    # Script de démarrage VLC
    cat << 'EOF' | $SUDO tee /opt/pisignage/scripts/start-vlc.sh > /dev/null
#!/bin/bash
# Script de démarrage VLC pour PiSignage

export DISPLAY=:0
export PULSE_RUNTIME_PATH=/run/user/1000/pulse

# Tuer les instances VLC existantes
pkill vlc 2>/dev/null || true
sleep 2

# Démarrer VLC avec l'interface HTTP
vlc --intf dummy --extraintf http --http-host 127.0.0.1 --http-port 8080 --http-password vlcpassword \
    --fullscreen --no-video-title-show --loop --no-osd \
    /opt/pisignage/media/ >/dev/null 2>&1 &

echo "VLC started with PID: $!"
EOF

    $SUDO chmod +x /opt/pisignage/scripts/start-vlc.sh

    info "✓ VLC configuré"
}

# Installer yt-dlp
install_ytdlp() {
    info "Installation de yt-dlp..."

    if command -v yt-dlp >/dev/null 2>&1; then
        info "✓ yt-dlp déjà installé"
        return
    fi

    # Installer via pip3
    if command -v pip3 >/dev/null 2>&1; then
        $SUDO pip3 install yt-dlp
        if command -v yt-dlp >/dev/null 2>&1; then
            info "✓ yt-dlp installé via pip3"
            return
        fi
    fi

    # Fallback: installation directe
    log "Installation directe de yt-dlp..."
    $SUDO curl -L "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" -o /usr/local/bin/yt-dlp
    $SUDO chmod +x /usr/local/bin/yt-dlp

    if command -v yt-dlp >/dev/null 2>&1; then
        info "✓ yt-dlp installé via téléchargement direct"
    else
        warn "⚠ Installation de yt-dlp échouée"
    fi
}

# Configurer les permissions
setup_permissions() {
    info "Configuration des permissions..."

    # Propriétaire des fichiers
    $SUDO chown -R www-data:www-data "$TARGET_DIR/web"
    $SUDO chown -R www-data:www-data "$TARGET_DIR/media"
    $SUDO chown -R www-data:www-data "$TARGET_DIR/config"
    $SUDO chown -R www-data:www-data "$TARGET_DIR/logs"
    $SUDO chown -R www-data:www-data "$TARGET_DIR/screenshots"

    # Permissions des dossiers
    $SUDO chmod 755 "$TARGET_DIR"
    $SUDO chmod -R 755 "$TARGET_DIR/web"
    $SUDO chmod -R 755 "$TARGET_DIR/scripts"
    $SUDO chmod -R 775 "$TARGET_DIR/media"
    $SUDO chmod -R 775 "$TARGET_DIR/config"
    $SUDO chmod -R 775 "$TARGET_DIR/logs"
    $SUDO chmod -R 775 "$TARGET_DIR/screenshots"

    # Rendre les scripts exécutables
    $SUDO chmod +x "$TARGET_DIR"/scripts/*.sh 2>/dev/null || true

    info "✓ Permissions configurées"
}

# Configurer les services système
setup_services() {
    info "Configuration des services système..."

    # Service PiSignage
    cat << 'EOF' | $SUDO tee /etc/systemd/system/pisignage.service > /dev/null
[Unit]
Description=PiSignage Digital Signage
After=network.target graphical-session.target

[Service]
Type=forking
User=pi
Group=pi
Environment=DISPLAY=:0
ExecStart=/opt/pisignage/scripts/start-vlc.sh
ExecStop=/usr/bin/pkill vlc
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Recharger systemd
    $SUDO systemctl daemon-reload

    # Activer les services
    $SUDO systemctl enable nginx
    $SUDO systemctl enable php7.4-fpm
    $SUDO systemctl enable pisignage

    info "✓ Services configurés"
}

# Démarrer les services
start_services() {
    info "Démarrage des services..."

    # Démarrer PHP-FPM
    $SUDO systemctl restart php7.4-fpm
    if $SUDO systemctl is-active --quiet php7.4-fpm; then
        info "✓ PHP-FPM démarré"
    else
        error "Échec du démarrage de PHP-FPM"
        exit 1
    fi

    # Démarrer Nginx
    $SUDO systemctl restart nginx
    if $SUDO systemctl is-active --quiet nginx; then
        info "✓ Nginx démarré"
    else
        error "Échec du démarrage de Nginx"
        exit 1
    fi

    # Note: VLC sera démarré manuellement ou au boot selon la configuration

    info "✓ Services démarrés"
}

# Tests de validation
run_tests() {
    info "Exécution des tests de validation..."

    # Test 1: Vérifier que le serveur web répond
    local max_attempts=10
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -s http://localhost >/dev/null 2>&1; then
            info "✓ Serveur web accessible"
            break
        else
            warn "Tentative $attempt/$max_attempts: Serveur web non accessible"
            sleep 2
            ((attempt++))
        fi
    done

    if [[ $attempt -gt $max_attempts ]]; then
        error "Serveur web non accessible après $max_attempts tentatives"
    fi

    # Test 2: Vérifier les APIs
    local apis=("system" "media" "playlist" "upload" "screenshot" "youtube" "player" "scheduler")

    for api in "${apis[@]}"; do
        if curl -s "http://localhost/api/${api}.php" >/dev/null 2>&1; then
            info "✓ API $api accessible"
        else
            warn "⚠ API $api non accessible"
        fi
    done

    # Test 3: Vérifier les permissions d'écriture
    if $SUDO -u www-data touch "$TARGET_DIR/media/test_write" 2>/dev/null; then
        $SUDO rm -f "$TARGET_DIR/media/test_write"
        info "✓ Permissions d'écriture média OK"
    else
        warn "⚠ Problème de permissions d'écriture média"
    fi

    info "✓ Tests de validation terminés"
}

# Créer des fichiers de démonstration
create_demo_content() {
    info "Création du contenu de démonstration..."

    # Créer une playlist de démonstration
    cat << 'EOF' | $SUDO tee "$TARGET_DIR/config/playlists/demo.json" > /dev/null
{
    "name": "demo",
    "description": "Playlist de démonstration",
    "items": [],
    "created_at": "2025-01-01 00:00:00",
    "item_count": 0
}
EOF

    # Créer un fichier de configuration de base
    cat << 'EOF' | $SUDO tee "$TARGET_DIR/config/settings.json" > /dev/null
{
    "version": "0.8.0",
    "display": {
        "resolution": "1920x1080",
        "rotation": 0,
        "brightness": 100
    },
    "audio": {
        "output": "hdmi",
        "volume": 80
    },
    "network": {
        "hostname": "pisignage",
        "timezone": "Europe/Paris"
    },
    "media": {
        "auto_cleanup": true,
        "max_storage": "80%"
    }
}
EOF

    $SUDO chown www-data:www-data "$TARGET_DIR/config"/*.json

    info "✓ Contenu de démonstration créé"
}

# Afficher le résumé final
show_final_summary() {
    local ip_address=$(hostname -I | awk '{print $1}')

    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║           🎉 DÉPLOIEMENT PISIGNAGE TERMINÉ ! 🎉               ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}📋 INFORMATIONS DE CONNEXION:${NC}"
    echo -e "   Interface Web: ${GREEN}http://$ip_address${NC}"
    echo -e "   Interface Web: ${GREEN}http://$(hostname).local${NC}"
    echo
    echo -e "${BLUE}📁 DOSSIERS IMPORTANTS:${NC}"
    echo -e "   Installation: ${GREEN}$TARGET_DIR${NC}"
    echo -e "   Médias: ${GREEN}$TARGET_DIR/media${NC}"
    echo -e "   Logs: ${GREEN}$TARGET_DIR/logs${NC}"
    echo -e "   Configuration: ${GREEN}$TARGET_DIR/config${NC}"
    echo
    echo -e "${BLUE}🔧 COMMANDES UTILES:${NC}"
    echo -e "   Redémarrer Nginx: ${GREEN}sudo systemctl restart nginx${NC}"
    echo -e "   Voir les logs: ${GREEN}tail -f $TARGET_DIR/logs/pisignage.log${NC}"
    echo -e "   Gestion média: ${GREEN}$TARGET_DIR/scripts/media-manager.sh${NC}"
    echo -e "   Installer yt-dlp: ${GREEN}$TARGET_DIR/scripts/install-yt-dlp.sh${NC}"
    echo
    echo -e "${BLUE}📊 APIS DISPONIBLES:${NC}"
    echo -e "   Système: ${GREEN}http://$ip_address/api/system.php${NC}"
    echo -e "   Médias: ${GREEN}http://$ip_address/api/media.php${NC}"
    echo -e "   Playlists: ${GREEN}http://$ip_address/api/playlist.php${NC}"
    echo -e "   Captures: ${GREEN}http://$ip_address/api/screenshot.php${NC}"
    echo
    echo -e "${YELLOW}⚠️  NOTES IMPORTANTES:${NC}"
    echo -e "   - Redémarrez le Pi pour un fonctionnement optimal"
    echo -e "   - Configurez VLC avec: $TARGET_DIR/scripts/start-vlc.sh"
    echo -e "   - Consultez les logs en cas de problème"
    echo
    echo -e "${GREEN}🚀 PiSignage v$PISIGNAGE_VERSION est prêt à l'emploi !${NC}"
    echo
}

# Nettoyage en cas d'erreur
cleanup_on_error() {
    error "Déploiement interrompu à cause d'une erreur"
    warn "Vous pouvez relancer le script pour reprendre l'installation"
    exit 1
}

# Piège pour les erreurs
trap cleanup_on_error ERR

# Fonction principale
main() {
    # Créer le dossier de logs
    mkdir -p "$(dirname "$LOG_FILE")"

    show_header

    log "=== DÉBUT DU DÉPLOIEMENT PISIGNAGE v$PISIGNAGE_VERSION ==="
    log "Timestamp: $(date -Iseconds)"
    log "Système: $(uname -a)"

    check_system
    create_directory_structure
    install_system_dependencies
    configure_web_server
    configure_vlc
    install_ytdlp
    setup_permissions
    setup_services
    start_services
    run_tests
    create_demo_content

    log "=== DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ==="

    show_final_summary
}

# Vérifier si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi