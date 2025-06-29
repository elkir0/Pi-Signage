#!/usr/bin/env bash

# =============================================================================
# Pi Signage Web Interface - Installation Autonome
# Version: 2.0.0
# Description: Script d'installation complet pour l'interface web
# Compatible avec: Debian/Ubuntu, Raspberry Pi OS
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly WEB_ROOT="/var/www/pi-signage"
readonly TEMP_DIR="/tmp/pi-signage-web-install"
readonly GITHUB_REPO="https://github.com/votre-username/pi-signage-web"

# =============================================================================
# FONCTIONS
# =============================================================================

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Ce script doit être exécuté en tant que root"
        echo "Utilisez: sudo $0"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        print_success "OS détecté: $PRETTY_NAME"
    else
        print_warning "Impossible de détecter l'OS"
    fi
}

check_prerequisites() {
    print_header "Vérification des prérequis"
    
    local missing_deps=()
    
    # Vérifier les commandes nécessaires
    local required_commands=("curl" "wget" "git" "nginx" "php")
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            print_success "$cmd installé"
        else
            print_warning "$cmd manquant"
            missing_deps+=("$cmd")
        fi
    done
    
    # Vérifier PHP version
    if command -v php >/dev/null 2>&1; then
        local php_version=$(php -v | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        if [[ $(echo "$php_version >= 8.0" | bc) -eq 1 ]]; then
            print_success "PHP version $php_version"
        else
            print_error "PHP 8.0+ requis, version actuelle: $php_version"
            missing_deps+=("php8.2")
        fi
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_header "Installation des dépendances manquantes"
        apt-get update
        
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "nginx")
                    apt-get install -y nginx
                    ;;
                "php")
                    apt-get install -y php8.2-fpm php8.2-cli php8.2-common \
                        php8.2-json php8.2-curl php8.2-xml php8.2-mbstring php8.2-zip
                    ;;
                *)
                    apt-get install -y "$dep"
                    ;;
            esac
        done
    fi
}

install_ytdlp() {
    print_header "Installation de yt-dlp"
    
    if command -v yt-dlp >/dev/null 2>&1; then
        print_success "yt-dlp déjà installé"
        yt-dlp -U  # Mise à jour
    else
        print_warning "Installation de yt-dlp..."
        curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
        chmod a+rx /usr/local/bin/yt-dlp
        print_success "yt-dlp installé"
    fi
    
    # Vérifier l'installation
    local version=$(yt-dlp --version 2>/dev/null || echo "Inconnue")
    print_success "yt-dlp version: $version"
}

download_web_interface() {
    print_header "Téléchargement de l'interface web"
    
    # Créer le répertoire temporaire
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Télécharger depuis GitHub
    if [[ -d "pi-signage-web" ]]; then
        print_warning "Répertoire existant, mise à jour..."
        cd pi-signage-web
        git pull
    else
        print_warning "Clonage du repository..."
        git clone "$GITHUB_REPO"
        cd pi-signage-web
    fi
    
    print_success "Interface web téléchargée"
}

install_web_files() {
    print_header "Installation des fichiers web"
    
    # Créer le répertoire web
    mkdir -p "$WEB_ROOT"
    
    # Copier les fichiers
    if [[ -d "$TEMP_DIR/pi-signage-web/src" ]]; then
        cp -r "$TEMP_DIR/pi-signage-web/src/"* "$WEB_ROOT/"
        print_success "Fichiers copiés vers $WEB_ROOT"
    else
        print_error "Fichiers source non trouvés"
        exit 1
    fi
    
    # Créer les répertoires nécessaires
    mkdir -p "$WEB_ROOT/temp"
    mkdir -p "$WEB_ROOT/api"
    mkdir -p "/var/log/pi-signage"
    mkdir -p "/opt/videos"
    
    # Permissions
    chown -R www-data:www-data "$WEB_ROOT"
    chmod -R 755 "$WEB_ROOT"
    chmod -R 775 "$WEB_ROOT/temp"
    chown www-data:www-data "/opt/videos"
    
    print_success "Permissions configurées"
}

configure_nginx() {
    print_header "Configuration de nginx"
    
    # Configuration nginx
    cat > /etc/nginx/sites-available/pi-signage << 'EOF'
server {
    listen 80;
    listen [::]:80;
    
    server_name _;
    root /var/www/pi-signage;
    index index.php index.html;
    
    # Logs
    access_log /var/log/nginx/pi-signage-access.log;
    error_log /var/log/nginx/pi-signage-error.log;
    
    # Limite upload
    client_max_body_size 100M;
    
    # Sécurité
    add_header X-Frame-Options "DENY";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    
    # Interdire accès aux includes
    location ~ ^/includes/ {
        deny all;
    }
    
    # PHP
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }
    
    # Fichiers statiques
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1d;
        add_header Cache-Control "public, immutable";
    }
    
    # API
    location /api/ {
        try_files $uri $uri/ /api/index.php?$query_string;
    }
}
EOF
    
    # Activer le site
    ln -sf /etc/nginx/sites-available/pi-signage /etc/nginx/sites-enabled/
    
    # Désactiver le site par défaut
    rm -f /etc/nginx/sites-enabled/default
    
    # Test de configuration
    if nginx -t; then
        print_success "Configuration nginx valide"
        systemctl restart nginx
    else
        print_error "Configuration nginx invalide"
        exit 1
    fi
}

configure_phpfpm() {
    print_header "Configuration de PHP-FPM"
    
    # Pool PHP-FPM dédié
    cat > /etc/php/8.2/fpm/pool.d/pi-signage.conf << 'EOF'
[pi-signage]
user = www-data
group = www-data
listen = /run/php/php8.2-fpm-pi-signage.sock
listen.owner = www-data
listen.group = www-data

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 500

php_admin_value[memory_limit] = 64M
php_admin_value[upload_max_filesize] = 100M
php_admin_value[post_max_size] = 100M
php_admin_value[max_execution_time] = 300

php_admin_value[session.save_path] = /var/lib/php/sessions/pi-signage
php_admin_value[session.cookie_httponly] = 1
php_admin_value[session.use_only_cookies] = 1

php_admin_value[error_log] = /var/log/pi-signage/php-error.log
php_admin_flag[log_errors] = on
php_admin_flag[display_errors] = off
EOF
    
    # Créer le répertoire de sessions
    mkdir -p /var/lib/php/sessions/pi-signage
    chown www-data:www-data /var/lib/php/sessions/pi-signage
    chmod 700 /var/lib/php/sessions/pi-signage
    
    # Redémarrer PHP-FPM
    systemctl restart php8.2-fpm
    
    print_success "PHP-FPM configuré"
}

configure_sudoers() {
    print_header "Configuration des permissions sudo"
    
    # Permissions pour contrôler VLC
    cat > /etc/sudoers.d/pi-signage-web << 'EOF'
# Permissions pour l'interface web Pi Signage
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl start vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl status vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /opt/scripts/sync-videos.sh
EOF
    
    chmod 440 /etc/sudoers.d/pi-signage-web
    
    print_success "Permissions sudo configurées"
}

setup_credentials() {
    print_header "Configuration des identifiants"
    
    # Demander les identifiants
    read -p "Nom d'utilisateur administrateur [admin]: " admin_user
    admin_user=${admin_user:-admin}
    
    read -sp "Mot de passe administrateur: " admin_password
    echo
    
    while [[ ${#admin_password} -lt 6 ]]; do
        print_error "Le mot de passe doit contenir au moins 6 caractères"
        read -sp "Mot de passe administrateur: " admin_password
        echo
    done
    
    # Créer/Mettre à jour la configuration
    if [[ -f "/etc/pi-signage/config.conf" ]]; then
        # Mettre à jour la config existante
        sed -i "s/^WEB_ADMIN_USER=.*/WEB_ADMIN_USER=\"$admin_user\"/" /etc/pi-signage/config.conf
        sed -i "s/^WEB_ADMIN_PASSWORD=.*/WEB_ADMIN_PASSWORD=\"$admin_password\"/" /etc/pi-signage/config.conf
    else
        # Créer nouvelle config
        mkdir -p /etc/pi-signage
        cat > /etc/pi-signage/config.conf << EOF
# Configuration Pi Signage Web
WEB_ADMIN_USER="$admin_user"
WEB_ADMIN_PASSWORD="$admin_password"
GDRIVE_FOLDER="Signage"
VIDEO_DIR="/opt/videos"
EOF
    fi
    
    chmod 600 /etc/pi-signage/config.conf
    
    print_success "Identifiants configurés"
}

test_installation() {
    print_header "Test de l'installation"
    
    local ip_addr=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    # Test nginx
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost/" | grep -q "200\|302"; then
        print_success "nginx répond correctement"
    else
        print_warning "nginx ne répond pas sur localhost"
    fi
    
    # Test PHP
    echo "<?php phpinfo();" > "$WEB_ROOT/test.php"
    if curl -s "http://localhost/test.php" | grep -q "PHP Version"; then
        print_success "PHP fonctionne correctement"
        rm -f "$WEB_ROOT/test.php"
    else
        print_warning "PHP ne fonctionne pas correctement"
    fi
}

cleanup() {
    print_header "Nettoyage"
    rm -rf "$TEMP_DIR"
    print_success "Fichiers temporaires supprimés"
}

show_summary() {
    local ip_addr=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "IP_ADDRESS")
    
    echo -e "\n${GREEN}=== Installation Terminée ! ===${NC}\n"
    echo "Accès à l'interface web :"
    echo "  URL: http://$ip_addr/"
    echo "  Utilisateur: $admin_user"
    echo "  Mot de passe: [défini]"
    echo
    echo "Prochaines étapes :"
    echo "  1. Ouvrez l'interface dans votre navigateur"
    echo "  2. Connectez-vous avec vos identifiants"
    echo "  3. Téléchargez vos vidéos ou utilisez Google Drive"
    echo
    echo "Documentation : https://github.com/votre-username/pi-signage-web"
}

# =============================================================================
# PROGRAMME PRINCIPAL
# =============================================================================

main() {
    clear
    
    cat << 'EOF'
    ____  _    ____  _                              
   |  _ \(_)  / ___|(_) __ _ _ __   __ _  __ _  ___ 
   | |_) | |  \___ \| |/ _` | '_ \ / _` |/ _` |/ _ \
   |  __/| |   ___) | | (_| | | | | (_| | (_| |  __/
   |_|   |_|  |____/|_|\__, |_| |_|\__,_|\__, |\___|
                       |___/             |___/      
     
           Interface Web - Installation Autonome

EOF
    
    echo "Version: 2.0.0"
    echo "========================================"
    echo
    
    # Vérifications
    check_root
    check_os
    check_prerequisites
    
    # Installation
    install_ytdlp
    download_web_interface
    install_web_files
    configure_nginx
    configure_phpfpm
    configure_sudoers
    setup_credentials
    
    # Tests
    test_installation
    
    # Nettoyage
    cleanup
    
    # Résumé
    show_summary
}

# Gestion des erreurs
trap 'print_error "Une erreur est survenue. Installation interrompue."; exit 1' ERR

# Lancer le programme principal
main "$@"