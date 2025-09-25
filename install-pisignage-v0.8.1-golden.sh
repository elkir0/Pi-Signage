#!/bin/bash
################################################################################
#                    PiSignage v0.8.1 GOLDEN - Installation ONE-CLICK
#                         Script d'installation complet et parfait
#                      Compatible Raspberry Pi OS Bookworm (Debian 12)
################################################################################
#
# Description : Script d'installation automatique ONE-CLICK pour PiSignage
# Version     : v0.8.1 GOLDEN (Interface glassmorphisme validée)
# Date        : 2025-09-25
# Auteur      : PiSignage Team
# GitHub      : https://github.com/elkir0/Pi-Signage
#
# UTILISATION:
#   curl -sSL https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install-pisignage-v0.8.1-golden.sh | sudo bash
#   ou
#   sudo ./install-pisignage-v0.8.1-golden.sh
#
################################################################################

set -e  # Arrêt en cas d'erreur

# Configuration
readonly PISIGNAGE_VERSION="v0.8.1-GOLDEN"
readonly GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
readonly INSTALL_DIR="/opt/pisignage"
readonly WEB_ROOT="/opt/pisignage/web"
readonly LOG_FILE="/var/log/pisignage-install.log"
readonly BACKUP_DIR="/opt/pisignage-backup-$(date +%Y%m%d-%H%M%S)"

# Couleurs pour output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging
log() {
    local message="$1"
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $message" | tee -a "$LOG_FILE"
}

error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE"
}

info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
}

success() {
    local message="$1"
    echo -e "${GREEN}✓${NC} $message" | tee -a "$LOG_FILE"
}

################################################################################
# PHASE 1: PRÉ-VÉRIFICATIONS
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Ce script doit être exécuté en tant que root (sudo)"
    fi
}

detect_system() {
    log "Détection du système..."

    # OS Detection
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        CODENAME=$VERSION_CODENAME
    else
        error "Impossible de détecter l'OS"
    fi

    # Raspberry Pi Detection
    if grep -q "Raspberry Pi" /proc/cpuinfo; then
        PI_MODEL=$(grep "Model" /proc/cpuinfo | cut -d ':' -f2 | xargs)
        log "Raspberry Pi détecté: $PI_MODEL"
    else
        warning "Ce n'est pas un Raspberry Pi - installation générique"
    fi

    # Architecture
    ARCH=$(uname -m)
    log "Architecture: $ARCH"

    # Vérification Bookworm
    if [[ "$CODENAME" != "bookworm" ]]; then
        warning "OS non-Bookworm détecté ($CODENAME). Des ajustements peuvent être nécessaires."
    fi
}

check_network() {
    log "Vérification de la connexion réseau..."
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        error "Pas de connexion Internet. Installation impossible."
    fi
    success "Connexion Internet OK"
}

backup_existing() {
    if [ -d "$INSTALL_DIR" ]; then
        warning "Installation existante détectée. Création d'un backup..."
        cp -r "$INSTALL_DIR" "$BACKUP_DIR"
        success "Backup créé dans $BACKUP_DIR"
    fi
}

################################################################################
# PHASE 2: INSTALLATION DES PACKAGES SYSTÈME
################################################################################

update_system() {
    log "Mise à jour du système..."
    apt-get update || error "Échec de la mise à jour APT"
    # apt-get upgrade -y # Optionnel, peut être long
    success "Système mis à jour"
}

install_base_packages() {
    log "Installation des packages de base..."

    local packages=(
        # Outils système
        curl wget git nano htop
        build-essential cmake
        python3 python3-pip
        jq socat netcat-openbsd

        # Réseau et sécurité
        ufw fail2ban
        openssh-server

        # Monitoring
        lm-sensors
        v4l-utils
    )

    apt-get install -y "${packages[@]}" || error "Échec installation packages de base"
    success "Packages de base installés"
}

install_media_packages() {
    log "Installation des packages média..."

    local packages=(
        # Lecteurs vidéo
        mpv
        vlc

        # Codecs et support
        ffmpeg
        libavcodec-extra

        # Accélération matérielle
        mesa-va-drivers
        mesa-vdpau-drivers
        va-driver-all
        vdpau-driver-all

        # Capture d'écran
        scrot
        imagemagick

        # YouTube
        yt-dlp
    )

    # Packages spécifiques Raspberry Pi
    if [[ -n "$PI_MODEL" ]]; then
        packages+=(
            libraspberrypi-bin
            libraspberrypi-dev
            raspberrypi-kernel-headers
        )

        # Tentative d'installation de raspberrypi-ffmpeg
        if apt-cache show raspberrypi-ffmpeg &>/dev/null; then
            packages+=(raspberrypi-ffmpeg)
        fi
    fi

    apt-get install -y "${packages[@]}" || warning "Certains packages média n'ont pas pu être installés"
    success "Packages média installés"
}

install_web_packages() {
    log "Installation des packages web (PHP 8.2 + Nginx)..."

    # Installation PHP 8.2 spécifiquement
    local php_packages=(
        php8.2-fpm
        php8.2-common
        php8.2-cli
        php8.2-curl
        php8.2-gd
        php8.2-mbstring
        php8.2-xml
        php8.2-zip
        php8.2-intl
        php8.2-sqlite3
        php8.2-mysql
        php8.2-bcmath
        php8.2-opcache
    )

    # Installation Nginx
    apt-get install -y nginx || error "Échec installation Nginx"

    # Installation PHP 8.2
    apt-get install -y "${php_packages[@]}" || error "Échec installation PHP 8.2"

    success "Nginx et PHP 8.2 installés"
}

install_display_packages() {
    log "Installation des packages d'affichage..."

    local packages=(
        # Support X11
        xorg
        openbox
        x11-xserver-utils
        xinit

        # Support Wayland
        wayland-protocols
        weston
        seatd

        # Display manager (optionnel)
        lightdm
        lightdm-gtk-greeter
    )

    apt-get install -y "${packages[@]}" || warning "Certains packages display non installés"
    success "Packages display installés"
}

################################################################################
# PHASE 3: CONFIGURATION SYSTÈME
################################################################################

setup_users_groups() {
    log "Configuration des utilisateurs et groupes..."

    # Ajouter l'utilisateur aux groupes nécessaires
    usermod -a -G video,audio,render,input,gpio www-data 2>/dev/null || true

    if id -u pi &>/dev/null; then
        usermod -a -G video,audio,render,input,gpio,www-data pi
    fi

    # Groupe seat pour Wayland
    if getent group seat &>/dev/null; then
        usermod -a -G seat www-data 2>/dev/null || true
        [ -n "$(id -u pi 2>/dev/null)" ] && usermod -a -G seat pi
    fi

    success "Utilisateurs et groupes configurés"
}

configure_gpu() {
    log "Configuration GPU pour Raspberry Pi..."

    if [[ -n "$PI_MODEL" ]] && [ -f /boot/config.txt ]; then
        # Backup config
        cp /boot/config.txt /boot/config.txt.backup

        # Configuration GPU
        if ! grep -q "^gpu_mem=" /boot/config.txt; then
            echo "gpu_mem=256" >> /boot/config.txt
        else
            sed -i 's/^gpu_mem=.*/gpu_mem=256/' /boot/config.txt
        fi

        # Enable camera and display
        if ! grep -q "^start_x=1" /boot/config.txt; then
            echo "start_x=1" >> /boot/config.txt
        fi

        success "Configuration GPU appliquée (redémarrage requis)"
    fi
}

################################################################################
# PHASE 4: DÉPLOIEMENT DE L'APPLICATION
################################################################################

deploy_application() {
    log "Déploiement de l'application PiSignage..."

    # Créer le répertoire d'installation
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    # Cloner depuis GitHub
    if [ ! -d "$INSTALL_DIR/.git" ]; then
        log "Clonage depuis GitHub..."
        git clone "$GITHUB_REPO" "$INSTALL_DIR" || error "Échec du clonage GitHub"
    else
        log "Mise à jour depuis GitHub..."
        git pull origin main || warning "Mise à jour Git échouée"
    fi

    # Créer la structure des répertoires
    mkdir -p "$INSTALL_DIR"/{media,logs,config,screenshots,uploads,scripts,backups}

    success "Application déployée depuis GitHub"
}

configure_permissions() {
    log "Configuration des permissions..."

    # Propriétaire principal
    chown -R www-data:www-data "$INSTALL_DIR"

    # Permissions des répertoires
    find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
    find "$INSTALL_DIR" -type f -exec chmod 644 {} \;

    # Répertoires avec écriture
    chmod 777 "$INSTALL_DIR/media"
    chmod 777 "$INSTALL_DIR/uploads"
    chmod 777 "$INSTALL_DIR/screenshots"
    chmod 777 "$INSTALL_DIR/logs"

    # Scripts exécutables
    find "$INSTALL_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} \;

    success "Permissions configurées"
}

################################################################################
# PHASE 5: CONFIGURATION WEB (NGINX + PHP)
################################################################################

configure_php() {
    log "Configuration de PHP 8.2..."

    local php_ini="/etc/php/8.2/fpm/php.ini"

    if [ -f "$php_ini" ]; then
        # Backup
        cp "$php_ini" "$php_ini.backup"

        # Configuration pour uploads volumineux
        sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' "$php_ini"
        sed -i 's/post_max_size = .*/post_max_size = 500M/' "$php_ini"
        sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$php_ini"
        sed -i 's/max_input_time = .*/max_input_time = 300/' "$php_ini"
        sed -i 's/memory_limit = .*/memory_limit = 256M/' "$php_ini"

        # Timezone
        sed -i "s/;date.timezone =.*/date.timezone = Europe\/Paris/" "$php_ini"

        systemctl restart php8.2-fpm
        success "PHP 8.2 configuré"
    else
        warning "Fichier php.ini non trouvé"
    fi
}

configure_nginx() {
    log "Configuration de Nginx..."

    # Créer la configuration du site
    cat > /etc/nginx/sites-available/pisignage << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /opt/pisignage/web;
    index index.php index.html;

    # Logs
    access_log /opt/pisignage/logs/nginx-access.log;
    error_log /opt/pisignage/logs/nginx-error.log;

    # Upload volumineux
    client_max_body_size 500M;
    client_body_timeout 300s;
    client_header_timeout 300s;

    # Compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # PHP
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
    }

    # API
    location /api/ {
        try_files $uri $uri/ /api/index.php?$query_string;
    }

    # Media files
    location /media/ {
        alias /opt/pisignage/media/;
        add_header Cache-Control "public, max-age=31536000";
    }

    # Screenshots
    location /screenshots/ {
        alias /opt/pisignage/screenshots/;
        add_header Cache-Control "public, max-age=3600";
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

    # Activer le site
    ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # Test configuration
    nginx -t || error "Configuration Nginx invalide"

    systemctl restart nginx
    success "Nginx configuré"
}

################################################################################
# PHASE 6: CONFIGURATION DES LECTEURS VIDÉO
################################################################################

setup_mpv() {
    log "Configuration de MPV..."

    # Configuration MPV pour l'utilisateur
    local mpv_conf_dir="/home/pi/.config/mpv"
    mkdir -p "$mpv_conf_dir"

    cat > "$mpv_conf_dir/mpv.conf" << 'EOF'
# Configuration MPV optimisée pour Raspberry Pi
hwdec=auto-safe
vo=gpu
gpu-context=drm
drm-connector=HDMI-A-1

# Performance
profile=fast
video-sync=audio
framedrop=vo
deinterlace=no

# Cache
cache=yes
cache-secs=10
demuxer-max-bytes=50M
demuxer-readahead-secs=10

# Audio
audio-device=auto
audio-channels=stereo
volume=100
volume-max=100

# Display
fullscreen=yes
keep-open=yes
idle=yes
force-window=yes

# Subtitles
sub-auto=fuzzy
sub-codepage=utf8

# Screenshots
screenshot-directory=/opt/pisignage/screenshots
screenshot-format=png
screenshot-png-compression=7

# OSD
osd-level=1
osd-duration=3000
EOF

    chown -R pi:pi "/home/pi/.config/mpv" 2>/dev/null || true

    # Lien symbolique pour www-data
    ln -sf "$mpv_conf_dir" "/var/www/.config/mpv" 2>/dev/null || true

    success "MPV configuré"
}

setup_vlc() {
    log "Configuration de VLC..."

    # Configuration VLC pour lecture automatique
    local vlc_conf="/usr/share/vlc/lua/http/.hosts"
    if [ -f "$vlc_conf" ]; then
        echo "::1" > "$vlc_conf"
        echo "127.0.0.1" >> "$vlc_conf"
        echo "fc00::/7" >> "$vlc_conf"
        echo "10.0.0.0/8" >> "$vlc_conf"
        echo "192.168.0.0/16" >> "$vlc_conf"
    fi

    success "VLC configuré"
}

################################################################################
# PHASE 7: SERVICES SYSTEMD
################################################################################

install_systemd_services() {
    log "Installation des services systemd..."

    # Service principal PiSignage
    cat > /etc/systemd/system/pisignage.service << 'EOF'
[Unit]
Description=PiSignage Digital Signage System
After=network.target nginx.service php8.2-fpm.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/pisignage
ExecStart=/opt/pisignage/scripts/start-pisignage.sh
ExecStop=/opt/pisignage/scripts/stop-pisignage.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Service de monitoring
    cat > /etc/systemd/system/pisignage-monitor.service << 'EOF'
[Unit]
Description=PiSignage System Monitor
After=pisignage.service

[Service]
Type=simple
User=www-data
ExecStart=/opt/pisignage/scripts/monitor-system.sh
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

    # Timer pour screenshots
    cat > /etc/systemd/system/pisignage-screenshot.timer << 'EOF'
[Unit]
Description=PiSignage Screenshot Timer
Requires=pisignage-screenshot.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

    cat > /etc/systemd/system/pisignage-screenshot.service << 'EOF'
[Unit]
Description=PiSignage Screenshot Service

[Service]
Type=oneshot
User=www-data
ExecStart=/opt/pisignage/scripts/screenshot.sh
EOF

    # Recharger et activer les services
    systemctl daemon-reload
    systemctl enable nginx php8.2-fpm
    systemctl enable pisignage pisignage-monitor
    systemctl enable pisignage-screenshot.timer

    success "Services systemd installés"
}

################################################################################
# PHASE 8: SCRIPTS DE GESTION
################################################################################

create_management_scripts() {
    log "Création des scripts de gestion..."

    # Script de démarrage
    cat > "$INSTALL_DIR/scripts/start-pisignage.sh" << 'EOF'
#!/bin/bash
echo "Démarrage de PiSignage..."

# Vérifier l'environnement d'affichage
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    # Démarrer le player par défaut (MPV)
    /opt/pisignage/scripts/player-manager.sh start &
fi

# Log de démarrage
echo "[$(date)] PiSignage started" >> /opt/pisignage/logs/pisignage.log
EOF

    # Script d'arrêt
    cat > "$INSTALL_DIR/scripts/stop-pisignage.sh" << 'EOF'
#!/bin/bash
echo "Arrêt de PiSignage..."

# Arrêter les players
/opt/pisignage/scripts/player-manager.sh stop

# Log d'arrêt
echo "[$(date)] PiSignage stopped" >> /opt/pisignage/logs/pisignage.log
EOF

    # Script de monitoring
    cat > "$INSTALL_DIR/scripts/monitor-system.sh" << 'EOF'
#!/bin/bash
while true; do
    # CPU Temperature
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_c=$((temp/1000))
        echo "{\"temperature\": $temp_c}" > /opt/pisignage/logs/temperature.json
    fi

    # CPU usage
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo "{\"cpu\": \"$cpu\"}" > /opt/pisignage/logs/cpu.json

    # Memory usage
    mem=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    echo "{\"memory\": \"$mem\"}" > /opt/pisignage/logs/memory.json

    sleep 10
done
EOF

    # Script screenshot
    cat > "$INSTALL_DIR/scripts/screenshot.sh" << 'EOF'
#!/bin/bash
timestamp=$(date +%Y%m%d-%H%M%S)
output="/opt/pisignage/screenshots/screen-$timestamp.png"

# Tentative avec différentes méthodes
if command -v scrot >/dev/null; then
    DISPLAY=:0 scrot "$output" 2>/dev/null
elif command -v import >/dev/null; then
    DISPLAY=:0 import -window root "$output" 2>/dev/null
fi

# Garder seulement les 100 derniers screenshots
find /opt/pisignage/screenshots -name "*.png" -type f | sort -r | tail -n +101 | xargs rm -f 2>/dev/null
EOF

    # Rendre les scripts exécutables
    chmod +x "$INSTALL_DIR/scripts/"*.sh

    success "Scripts de gestion créés"
}

################################################################################
# PHASE 9: TESTS ET VALIDATION
################################################################################

test_installation() {
    log "Tests de validation de l'installation..."

    local tests_passed=0
    local tests_failed=0

    # Test 1: Services actifs
    info "Test des services..."
    for service in nginx php8.2-fpm; do
        if systemctl is-active --quiet "$service"; then
            success "$service actif"
            ((tests_passed++))
        else
            warning "$service inactif"
            ((tests_failed++))
        fi
    done

    # Test 2: Fichiers web
    info "Test des fichiers web..."
    if [ -f "$WEB_ROOT/index.php" ] || [ -f "$WEB_ROOT/index.html" ]; then
        success "Interface web présente"
        ((tests_passed++))
    else
        warning "Interface web manquante"
        ((tests_failed++))
    fi

    # Test 3: Permissions
    info "Test des permissions..."
    if [ -w "$INSTALL_DIR/media" ]; then
        success "Permissions media OK"
        ((tests_passed++))
    else
        warning "Problème permissions media"
        ((tests_failed++))
    fi

    # Test 4: Lecteurs vidéo
    info "Test des lecteurs vidéo..."
    if command -v mpv >/dev/null; then
        success "MPV installé"
        ((tests_passed++))
    else
        warning "MPV non installé"
        ((tests_failed++))
    fi

    if command -v vlc >/dev/null; then
        success "VLC installé"
        ((tests_passed++))
    else
        warning "VLC non installé"
        ((tests_failed++))
    fi

    # Test 5: Accès web
    info "Test d'accès web..."
    if curl -f -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200\|301\|302"; then
        success "Interface web accessible"
        ((tests_passed++))
    else
        warning "Interface web inaccessible"
        ((tests_failed++))
    fi

    # Résumé
    echo ""
    log "========================================="
    log "RÉSULTATS DES TESTS:"
    log "  ✅ Réussis: $tests_passed"
    log "  ❌ Échoués: $tests_failed"
    log "========================================="

    if [ $tests_failed -eq 0 ]; then
        success "TOUS LES TESTS PASSÉS AVEC SUCCÈS!"
        return 0
    else
        warning "Certains tests ont échoué. Vérification manuelle recommandée."
        return 1
    fi
}

################################################################################
# PHASE 10: FINALISATION
################################################################################

display_final_report() {
    local ip=$(hostname -I | awk '{print $1}')

    clear
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     🎉 INSTALLATION PISIGNAGE v0.8.1 GOLDEN TERMINÉE! 🎉    ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📋 INFORMATIONS D'ACCÈS:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  🌐 Interface Web:     http://$ip/"
    echo "  🌐 Interface locale:  http://localhost/"
    echo "  📁 Répertoire:        $INSTALL_DIR"
    echo "  📝 Logs:              $LOG_FILE"
    echo ""
    echo "🔧 SERVICES INSTALLÉS:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  ✅ Nginx (Port 80)"
    echo "  ✅ PHP 8.2-FPM"
    echo "  ✅ MPV (Lecteur principal)"
    echo "  ✅ VLC (Lecteur de secours)"
    echo "  ✅ Service PiSignage"
    echo "  ✅ Service de monitoring"
    echo ""
    echo "🎮 COMMANDES UTILES:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  Statut:     sudo systemctl status pisignage"
    echo "  Démarrer:   sudo systemctl start pisignage"
    echo "  Arrêter:    sudo systemctl stop pisignage"
    echo "  Logs:       sudo journalctl -u pisignage -f"
    echo "  Redémarrer: sudo systemctl restart pisignage"
    echo ""
    echo "📊 CARACTÉRISTIQUES:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  • Interface glassmorphisme 9 sections"
    echo "  • Upload fichiers jusqu'à 500MB"
    echo "  • Dual-player MPV/VLC intelligent"
    echo "  • API REST complète"
    echo "  • Monitoring temps réel"
    echo "  • Captures d'écran automatiques"
    echo ""
    echo "🚀 PROCHAINES ÉTAPES:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  1. Accéder à l'interface: http://$ip/"
    echo "  2. Uploader vos médias"
    echo "  3. Créer vos playlists"
    echo "  4. Configurer la programmation"
    echo ""
    echo "📖 DOCUMENTATION:"
    echo "════════════════════════════════════════════════════════════════"
    echo "  GitHub: https://github.com/elkir0/Pi-Signage"
    echo "  Version: $PISIGNAGE_VERSION"
    echo ""

    if [ -f "$BACKUP_DIR" ]; then
        echo "⚠️  BACKUP:"
        echo "════════════════════════════════════════════════════════════════"
        echo "  Votre ancienne installation a été sauvegardée dans:"
        echo "  $BACKUP_DIR"
        echo ""
    fi

    echo "✅ Installation terminée avec succès!"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
}

cleanup() {
    log "Nettoyage..."
    apt-get autoremove -y
    apt-get autoclean
    success "Nettoyage terminé"
}

################################################################################
# FONCTION PRINCIPALE
################################################################################

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     PISIGNAGE v0.8.1 GOLDEN - INSTALLATION ONE-CLICK        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # Créer le fichier de log
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    log "Début de l'installation PiSignage $PISIGNAGE_VERSION"

    # PHASE 1: Pré-vérifications
    check_root
    detect_system
    check_network
    backup_existing

    # PHASE 2: Installation packages
    update_system
    install_base_packages
    install_media_packages
    install_web_packages
    install_display_packages

    # PHASE 3: Configuration système
    setup_users_groups
    configure_gpu

    # PHASE 4: Déploiement application
    deploy_application
    configure_permissions

    # PHASE 5: Configuration web
    configure_php
    configure_nginx

    # PHASE 6: Configuration lecteurs
    setup_mpv
    setup_vlc

    # PHASE 7: Services
    install_systemd_services

    # PHASE 8: Scripts
    create_management_scripts

    # PHASE 9: Tests
    test_installation

    # PHASE 10: Finalisation
    cleanup
    display_final_report

    log "Installation terminée!"
}

# Trap pour gérer les interruptions
trap 'error "Installation interrompue!"' INT TERM

# Lancer l'installation
main "$@"

exit 0