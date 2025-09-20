#!/bin/bash

# PiSignage Desktop v3.0 - Script de déploiement
# Usage: sudo ./deploy.sh

set -e

echo "🚀 Déploiement PiSignage Desktop v3.0..."

# Variables
WEB_DIR="/var/www/pisignage-desktop"
SOURCE_DIR="/opt/pisignage/pisignage-desktop/web"
NGINX_SITE="/etc/nginx/sites-available/pisignage-desktop"
VIDEOS_DIR="/opt/videos"
PISIGNAGE_DIR="/opt/pisignage"

# Vérifier les droits root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ce script doit être exécuté en tant que root (sudo)"
    exit 1
fi

# Créer les dossiers système
echo "📁 Création des dossiers..."
mkdir -p "$VIDEOS_DIR"
mkdir -p "$PISIGNAGE_DIR"
mkdir -p "$(dirname "$WEB_DIR")"

# Copier les fichiers web
echo "📋 Copie des fichiers web..."
if [ -d "$WEB_DIR" ]; then
    echo "⚠️  Sauvegarde de l'ancienne installation..."
    mv "$WEB_DIR" "${WEB_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
fi

cp -r "$SOURCE_DIR" "$WEB_DIR"

# Définir les permissions
echo "🔒 Configuration des permissions..."
chown -R www-data:www-data "$WEB_DIR"
chown -R www-data:www-data "$VIDEOS_DIR"
chown -R www-data:www-data "$PISIGNAGE_DIR"

chmod -R 755 "$WEB_DIR"
chmod 640 "$WEB_DIR/includes/config.php"

# Configuration nginx
echo "🌐 Configuration nginx..."
cat > "$NGINX_SITE" << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /var/www/pisignage-desktop/public;
    index index.php;
    
    # Logs
    access_log /var/log/nginx/pisignage-access.log;
    error_log /var/log/nginx/pisignage-error.log;
    
    # PHP
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Limites pour upload
        client_max_body_size 200M;
        fastcgi_read_timeout 300;
    }
    
    # API routing
    location /api {
        try_files $uri $uri/ /api/v1/endpoints.php?$query_string;
    }
    
    # Sécurité
    location ~ /includes/ {
        deny all;
    }
    
    location ~ /\.ht {
        deny all;
    }
    
    # Assets statiques avec cache
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1M;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Activer le site nginx
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    echo "🔄 Désactivation du site par défaut..."
    unlink /etc/nginx/sites-enabled/default 2>/dev/null || true
fi

ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/pisignage-desktop

# Test de la configuration nginx
echo "🧪 Test de la configuration nginx..."
nginx -t

# Configuration PHP
echo "🐘 Configuration PHP..."
PHP_INI="/etc/php/8.2/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
    # Backup de la config PHP
    cp "$PHP_INI" "${PHP_INI}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Mise à jour des limites
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 200M/' "$PHP_INI"
    sed -i 's/post_max_size = .*/post_max_size = 200M/' "$PHP_INI"
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
    sed -i 's/max_input_time = .*/max_input_time = 300/' "$PHP_INI"
    sed -i 's/memory_limit = .*/memory_limit = 256M/' "$PHP_INI"
fi

# Permissions sudo pour www-data (pour contrôle des services)
echo "🔐 Configuration sudo pour www-data..."
cat > /etc/sudoers.d/pisignage-desktop << 'EOF'
# PiSignage Desktop - Permissions pour www-data
www-data ALL=(ALL) NOPASSWD: /bin/systemctl start pisignage-desktop.service
www-data ALL=(ALL) NOPASSWD: /bin/systemctl stop pisignage-desktop.service
www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart pisignage-desktop.service
www-data ALL=(ALL) NOPASSWD: /bin/systemctl status pisignage-desktop.service
www-data ALL=(ALL) NOPASSWD: /bin/systemctl is-active pisignage-desktop.service
www-data ALL=(ALL) NOPASSWD: /bin/systemctl start nginx
www-data ALL=(ALL) NOPASSWD: /bin/systemctl stop nginx
www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx
www-data ALL=(ALL) NOPASSWD: /bin/systemctl status nginx
www-data ALL=(ALL) NOPASSWD: /bin/systemctl is-active nginx
www-data ALL=(ALL) NOPASSWD: /usr/bin/yt-dlp *
EOF

# Redémarrer les services
echo "🔄 Redémarrage des services..."
systemctl restart php8.2-fpm
systemctl reload nginx

# Vérifier les services
echo "✅ Vérification des services..."
systemctl is-active --quiet nginx && echo "✅ nginx actif" || echo "❌ nginx inactif"
systemctl is-active --quiet php8.2-fpm && echo "✅ PHP-FPM actif" || echo "❌ PHP-FPM inactif"

# Obtenir l'IP
IP=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)

echo ""
echo "🎉 Déploiement terminé !"
echo ""
echo "📍 Accès web : http://${IP:-localhost}"
echo "🔑 Identifiants par défaut :"
echo "   Utilisateur : admin"
echo "   Mot de passe : pisignage"
echo ""
echo "⚠️  IMPORTANT :"
echo "   1. Changez le mot de passe dans includes/config.php"
echo "   2. Configurez HTTPS en production"
echo "   3. Ajustez les permissions selon vos besoins"
echo ""
echo "📊 API REST : http://${IP:-localhost}/api/v1/endpoints.php"
echo "📖 Documentation : http://${IP:-localhost}/api.php"
echo ""
echo "🔧 Logs :"
echo "   - Web : tail -f /var/log/nginx/pisignage-*.log"
echo "   - App : tail -f /tmp/pisignage-desktop.log"
echo ""

exit 0