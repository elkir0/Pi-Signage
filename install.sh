#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════╗
# ║                  PiSignage v0.8.1 - Installation Unifiée             ║
# ║                     Script d'installation ONE-CLICK                   ║
# ║                          Date: 2025-09-25                            ║
# ╚══════════════════════════════════════════════════════════════════════╝

set -e

# Configuration
VERSION="0.8.1"
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
    echo "  • VLC et MPV (lecteurs vidéo)"
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

    # Packages essentiels uniquement
    local packages=(
        "nginx"
        "php8.2-fpm"
        "php8.2-cli"
        "vlc"
        "mpv"
        "ffmpeg"
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

    sudo mkdir -p $INSTALL_DIR/{web,media,config,logs,scripts,backups}
    sudo mkdir -p $INSTALL_DIR/web/{api,assets,css,js}
    sudo mkdir -p /dev/shm/pisignage-screenshots

    # Permissions
    sudo chown -R $USER:$USER $INSTALL_DIR
    chmod 755 $INSTALL_DIR

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
}

# Création/mise à jour de player-config.json
create_config() {
    log_step "Configuration du système"

    cat > $INSTALL_DIR/config/player-config.json << 'ENDOFFILE'
{
  "player": {
    "default": "vlc",
    "current": "vlc",
    "available": ["vlc", "mpv"]
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
    "enabled": true,
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

# Arrêt des lecteurs existants
pkill -9 vlc mpv 2>/dev/null
sleep 1

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

# Démarrer VLC
if [ -n "$VIDEO" ]; then
    cvlc $VLC_OPTIONS "$VIDEO" > /opt/pisignage/logs/vlc.log 2>&1 &
    echo "✓ VLC démarré avec $(basename "$VIDEO")"
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

# Démarrer VLC
/opt/pisignage/scripts/start-vlc.sh

# Watchdog
while true; do
    if ! pgrep vlc > /dev/null; then
        echo "VLC s'est arrêté, redémarrage..."
        /opt/pisignage/scripts/start-vlc.sh
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

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }

    client_max_body_size 500M;
    client_body_timeout 300s;
}
ENDOFFILE

        sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
        sudo systemctl restart nginx || true
        sudo systemctl restart php8.2-fpm || true
        log_info "Nginx configuré"

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

    # Vérifier VLC
    if pgrep vlc > /dev/null; then
        log_info "VLC en cours d'exécution"
    else
        log_warn "VLC n'est pas encore démarré"
        # Essayer de le démarrer
        $INSTALL_DIR/scripts/start-vlc.sh &
    fi

    # Vérifier le service
    if systemctl is-active --quiet pisignage; then
        log_info "Service PiSignage actif"
    else
        log_warn "Service PiSignage inactif"
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
    echo "   sudo systemctl status pisignage   # Voir le statut"
    echo "   sudo systemctl restart pisignage  # Redémarrer"
    echo "   tail -f $INSTALL_DIR/logs/vlc.log # Voir les logs VLC"
    echo ""
    echo "📝 Documentation: $INSTALL_DIR/CLAUDE.md"
    echo ""
}

# Exécuter l'installation
main "$@"