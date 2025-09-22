#!/bin/bash

# PiSignage v0.8.0 - Configuration Web (Nginx + PHP-FPM)
# Permissions, sécurité et optimisations
# Auteur: Claude Code
# Date: 22/09/2025

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
PISIGNAGE_DIR="/opt/pisignage"
WEB_DIR="$PISIGNAGE_DIR/web"
NGINX_SITE="pisignage"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
PHP_VERSION="8.2"
UPLOAD_MAX_SIZE="2048M"

log() {
    echo -e "${GREEN}[WEB] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WEB] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[WEB] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[WEB] INFO: $1${NC}"
}

# Configuration Nginx
configure_nginx() {
    log "Configuration Nginx..."

    # Backup de la configuration par défaut
    if [ -f "$NGINX_SITES_ENABLED/default" ]; then
        sudo mv "$NGINX_SITES_ENABLED/default" "$NGINX_SITES_ENABLED/default.backup"
        log "✅ Configuration par défaut sauvegardée"
    fi

    # Configuration spécifique PiSignage
    cat << EOF | sudo tee "$NGINX_SITES_AVAILABLE/$NGINX_SITE" > /dev/null
# PiSignage v0.8.0 - Configuration Nginx
# Optimisée pour Raspberry Pi

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root $WEB_DIR;
    index index.php index.html index.htm;

    server_name _ localhost;

    # Logs
    access_log /var/log/nginx/pisignage.access.log;
    error_log /var/log/nginx/pisignage.error.log;

    # Sécurité de base
    server_tokens off;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Upload files de grande taille
    client_max_body_size $UPLOAD_MAX_SIZE;
    client_body_timeout 300s;
    client_header_timeout 300s;

    # Gestion des médias statiques
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary Accept-Encoding;
        access_log off;
    }

    # Médias uploadés
    location /media/ {
        alias $PISIGNAGE_DIR/media/;
        expires 1d;
        add_header Cache-Control "public";

        # Sécurité: empêcher exécution de scripts
        location ~ \.(php|pl|py|jsp|asp|sh|cgi)$ {
            deny all;
        }
    }

    # API endpoints
    location /api/ {
        try_files \$uri \$uri/ =404;

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;

            # Timeouts pour upload
            fastcgi_read_timeout 300;
            fastcgi_send_timeout 300;
            fastcgi_connect_timeout 300;
        }
    }

    # Page principale et PHP
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;

        # Paramètres pour upload
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_connect_timeout 300;
    }

    # Sécurité: bloquer fichiers sensibles
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~ /(README|INSTALL|LICENSE|CHANGELOG|UPGRADING)$ {
        deny all;
    }

    location ~ /\.(htaccess|htpasswd|ini|log|sh|sql|conf)$ {
        deny all;
    }

    # Status nginx pour monitoring
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow ::1;
        deny all;
    }

    # Healthcheck
    location /health {
        access_log off;
        return 200 "PiSignage v0.8.0 OK";
        add_header Content-Type text/plain;
    }
}
EOF

    # Activation du site
    sudo ln -sf "$NGINX_SITES_AVAILABLE/$NGINX_SITE" "$NGINX_SITES_ENABLED/"

    log "✅ Configuration Nginx créée"
}

# Configuration PHP-FPM
configure_php_fpm() {
    log "Configuration PHP-FPM..."

    local php_ini="/etc/php/$PHP_VERSION/fpm/php.ini"
    local fpm_conf="/etc/php/$PHP_VERSION/fpm/pool.d/www.conf"

    # Backup des configurations
    sudo cp "$php_ini" "${php_ini}.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp "$fpm_conf" "${fpm_conf}.backup.$(date +%Y%m%d_%H%M%S)"

    # Configuration PHP.ini pour upload
    sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = $UPLOAD_MAX_SIZE/" "$php_ini"
    sudo sed -i "s/post_max_size = .*/post_max_size = $UPLOAD_MAX_SIZE/" "$php_ini"
    sudo sed -i "s/max_execution_time = .*/max_execution_time = 300/" "$php_ini"
    sudo sed -i "s/max_input_time = .*/max_input_time = 300/" "$php_ini"
    sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" "$php_ini"

    # Optimisations OPcache
    sudo sed -i "s/;opcache.enable=.*/opcache.enable=1/" "$php_ini"
    sudo sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=128/" "$php_ini"
    sudo sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=4000/" "$php_ini"
    sudo sed -i "s/;opcache.revalidate_freq=.*/opcache.revalidate_freq=60/" "$php_ini"

    # Configuration FPM pour performance
    sudo sed -i "s/pm.max_children = .*/pm.max_children = 10/" "$fpm_conf"
    sudo sed -i "s/pm.start_servers = .*/pm.start_servers = 2/" "$fpm_conf"
    sudo sed -i "s/pm.min_spare_servers = .*/pm.min_spare_servers = 1/" "$fpm_conf"
    sudo sed -i "s/pm.max_spare_servers = .*/pm.max_spare_servers = 3/" "$fpm_conf"

    # Ajout des variables d'environnement si elles n'existent pas
    if ! grep -q "env\[PISIGNAGE_DIR\]" "$fpm_conf"; then
        echo "env[PISIGNAGE_DIR] = $PISIGNAGE_DIR" | sudo tee -a "$fpm_conf"
    fi

    log "✅ Configuration PHP-FPM mise à jour"
}

# Configuration des permissions
configure_permissions() {
    log "Configuration des permissions..."

    # Propriétaire des fichiers web
    sudo chown -R www-data:www-data "$WEB_DIR"
    sudo chmod -R 755 "$WEB_DIR"

    # Permissions spéciales pour upload
    sudo mkdir -p "$PISIGNAGE_DIR/media/uploads"
    sudo chown -R www-data:www-data "$PISIGNAGE_DIR/media"
    sudo chmod -R 777 "$PISIGNAGE_DIR/media"

    # Logs accessibles
    sudo mkdir -p "$PISIGNAGE_DIR/logs"
    sudo chown -R www-data:www-data "$PISIGNAGE_DIR/logs"
    sudo chmod -R 775 "$PISIGNAGE_DIR/logs"

    # Configuration des permissions pour les scripts
    if [ -d "$PISIGNAGE_DIR/scripts" ]; then
        sudo chmod +x "$PISIGNAGE_DIR/scripts"/*.sh 2>/dev/null || true
    fi

    log "✅ Permissions configurées"
}

# Optimisation Nginx
optimize_nginx() {
    log "Optimisation Nginx..."

    local nginx_conf="/etc/nginx/nginx.conf"

    # Backup de la configuration
    sudo cp "$nginx_conf" "${nginx_conf}.backup.$(date +%Y%m%d_%H%M%S)"

    # Optimisations pour Raspberry Pi
    sudo tee "/etc/nginx/conf.d/pisignage-optimization.conf" > /dev/null << 'EOF'
# PiSignage v0.8.0 - Optimisations Nginx pour Raspberry Pi

# Performance générale
worker_rlimit_nofile 1024;
worker_connections 512;

# Gzip compression
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_comp_level 6;
gzip_types
    text/plain
    text/css
    text/xml
    text/javascript
    application/json
    application/javascript
    application/xml+rss
    application/atom+xml
    image/svg+xml;

# Cache des fichiers statiques
open_file_cache max=1000 inactive=20s;
open_file_cache_valid 30s;
open_file_cache_min_uses 2;
open_file_cache_errors on;

# Buffers optimisés pour Pi
client_body_buffer_size 128k;
client_header_buffer_size 1k;
large_client_header_buffers 4 4k;
output_buffers 1 32k;
postpone_output 1460;

# Timeouts
client_body_timeout 12;
client_header_timeout 12;
keepalive_timeout 15;
send_timeout 10;

# Rate limiting basique
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=upload:10m rate=1r/s;
EOF

    log "✅ Optimisations Nginx appliquées"
}

# Création des scripts utilitaires
create_utility_scripts() {
    log "Création des scripts utilitaires..."

    # Script de redémarrage des services
    cat << 'EOF' | sudo tee "$PISIGNAGE_DIR/scripts/restart-web.sh" > /dev/null
#!/bin/bash

# PiSignage v0.8.0 - Redémarrage services web

echo "Redémarrage des services web..."

# Arrêt propre
sudo systemctl stop nginx
sudo systemctl stop php8.2-fpm

# Nettoyage cache
sudo rm -rf /var/cache/nginx/*
sudo rm -rf /tmp/nginx-cache/* 2>/dev/null || true

# Redémarrage
sudo systemctl start php8.2-fpm
sleep 2
sudo systemctl start nginx

# Vérification
if systemctl is-active --quiet nginx && systemctl is-active --quiet php8.2-fpm; then
    echo "✅ Services web redémarrés avec succès"
else
    echo "❌ Erreur lors du redémarrage"
    systemctl status nginx
    systemctl status php8.2-fpm
fi
EOF

    sudo chmod +x "$PISIGNAGE_DIR/scripts/restart-web.sh"

    # Script de test de l'upload
    cat << 'EOF' | sudo tee "$PISIGNAGE_DIR/scripts/test-upload.sh" > /dev/null
#!/bin/bash

# PiSignage v0.8.0 - Test upload

UPLOAD_URL="http://localhost/api/upload.php"
TEST_FILE="/tmp/test-upload.txt"

# Création d'un fichier de test
echo "Test upload PiSignage v0.8.0 - $(date)" > "$TEST_FILE"

echo "Test d'upload vers: $UPLOAD_URL"

# Test avec curl
response=$(curl -s -F "file=@$TEST_FILE" "$UPLOAD_URL")

echo "Réponse serveur: $response"

# Nettoyage
rm -f "$TEST_FILE"

if [[ "$response" == *"success"* ]] || [[ "$response" == *"uploaded"* ]]; then
    echo "✅ Test d'upload réussi"
else
    echo "❌ Test d'upload échoué"
fi
EOF

    sudo chmod +x "$PISIGNAGE_DIR/scripts/test-upload.sh"

    log "✅ Scripts utilitaires créés"
}

# Test de la configuration
test_configuration() {
    log "Test de la configuration web..."

    # Test Nginx
    if sudo nginx -t 2>/dev/null; then
        log "✅ Configuration Nginx valide"
    else
        error "❌ Configuration Nginx invalide"
    fi

    # Test PHP-FPM
    if sudo php-fpm$PHP_VERSION -t 2>/dev/null; then
        log "✅ Configuration PHP-FPM valide"
    else
        error "❌ Configuration PHP-FPM invalide"
    fi

    # Vérification des permissions
    if [ -w "$PISIGNAGE_DIR/media" ]; then
        log "✅ Permissions média OK"
    else
        warn "❌ Permissions média insuffisantes"
    fi

    # Test de répertoire web
    if [ -d "$WEB_DIR" ]; then
        log "✅ Répertoire web existe"
    else
        warn "❌ Répertoire web manquant: $WEB_DIR"
    fi

    log "✅ Tests de configuration terminés"
}

# Redémarrage des services
restart_services() {
    log "Redémarrage des services..."

    sudo systemctl restart php$PHP_VERSION-fpm
    sleep 2
    sudo systemctl restart nginx

    # Vérification
    if systemctl is-active --quiet nginx; then
        log "✅ Nginx redémarré"
    else
        error "❌ Échec redémarrage Nginx"
    fi

    if systemctl is-active --quiet php$PHP_VERSION-fpm; then
        log "✅ PHP-FPM redémarré"
    else
        error "❌ Échec redémarrage PHP-FPM"
    fi
}

# Fonction principale
main() {
    log "🌐 Configuration Web pour PiSignage v0.8.0"

    configure_nginx
    configure_php_fpm
    optimize_nginx
    configure_permissions
    create_utility_scripts
    test_configuration
    restart_services

    echo ""
    log "✅ Configuration Web terminée!"
    echo ""
    info "Configuration créée:"
    info "  - Site Nginx: $NGINX_SITES_AVAILABLE/$NGINX_SITE"
    info "  - Upload max: $UPLOAD_MAX_SIZE"
    info "  - Répertoire web: $WEB_DIR"
    info "  - Répertoire média: $PISIGNAGE_DIR/media"
    echo ""
    info "Scripts utilitaires:"
    info "  - $PISIGNAGE_DIR/scripts/restart-web.sh"
    info "  - $PISIGNAGE_DIR/scripts/test-upload.sh"
    echo ""
    info "URLs disponibles:"
    info "  - Interface: http://localhost/"
    info "  - Health check: http://localhost/health"
    info "  - Status Nginx: http://localhost/nginx_status"
    echo ""
    info "Commandes utiles:"
    info "  sudo systemctl restart nginx"
    info "  sudo systemctl restart php$PHP_VERSION-fpm"
    info "  $PISIGNAGE_DIR/scripts/restart-web.sh"
    echo ""
}

# Exécution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi