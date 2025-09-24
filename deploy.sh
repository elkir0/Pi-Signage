#!/bin/bash

echo "=================================================="
echo "DÉPLOIEMENT v0.8.0 SUR RASPBERRY PI"
echo "=================================================="
echo ""
echo "Cible : 192.168.1.103"
echo "Version : 0.8.0 (version stable)"
echo ""

# Créer l'archive
echo "1. Création de l'archive..."
cd /opt/pisignage
tar -czf /tmp/pisignage-v080-deploy.tar.gz \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='*.log' \
    --exclude='deploy*.sh' \
    .

if [ -f /tmp/pisignage-v080-deploy.tar.gz ]; then
    echo "   ✅ Archive créée"
    ls -lh /tmp/pisignage-v080-deploy.tar.gz
else
    echo "   ❌ Erreur création archive"
    exit 1
fi

# Copier sur le Pi
echo ""
echo "2. Copie sur le Raspberry Pi..."
sshpass -p 'raspberry' scp /tmp/pisignage-v080-deploy.tar.gz pi@192.168.1.103:/tmp/

if [ $? -eq 0 ]; then
    echo "   ✅ Archive copiée"
else
    echo "   ❌ Erreur de copie"
    exit 1
fi

# Déployer sur le Pi
echo ""
echo "3. Déploiement sur le Raspberry Pi..."

sshpass -p 'raspberry' ssh pi@192.168.1.103 << 'DEPLOY_SCRIPT'

echo "   Déploiement en cours..."

# 1. Arrêter les services
echo "   - Arrêt des services..."
sudo systemctl stop nginx 2>/dev/null
sudo systemctl stop php8.2-fpm 2>/dev/null
sudo systemctl stop php8.1-fpm 2>/dev/null

# 2. Backup de l'ancienne version
echo "   - Backup de l'ancienne version..."
if [ -d /opt/pisignage ]; then
    sudo mv /opt/pisignage /opt/pisignage-backup-$(date +%Y%m%d-%H%M%S)
fi

# 3. Créer nouveau dossier
echo "   - Création du nouveau dossier..."
sudo mkdir -p /opt/pisignage
sudo mkdir -p /opt/pisignage/media
sudo mkdir -p /opt/pisignage/config
sudo mkdir -p /opt/pisignage/logs

# 4. Extraire v0.8.0
echo "   - Extraction de v0.8.0..."
sudo tar -xzf /tmp/pisignage-v080-deploy.tar.gz -C /opt/pisignage/

# 5. Permissions
echo "   - Configuration des permissions..."
sudo chown -R www-data:www-data /opt/pisignage
sudo chmod -R 755 /opt/pisignage
sudo chmod -R 777 /opt/pisignage/media
sudo chmod -R 777 /opt/pisignage/logs

# 6. Configuration nginx
echo "   - Configuration nginx..."
sudo tee /etc/nginx/sites-available/pisignage > /dev/null << 'NGINX_CONFIG'
server {
    listen 80;
    server_name _;

    root /opt/pisignage/web;
    index index.php index.html;

    # Taille max upload
    client_max_body_size 500M;
    client_body_timeout 300;
    client_body_buffer_size 128k;

    # Cache control - IMPORTANT: NO CACHE
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;

        # Timeout for long operations
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex on;
    }

    location /api {
        try_files $uri $uri/ =404;
    }

    # Security
    location ~ /\.ht {
        deny all;
    }
}
NGINX_CONFIG

# 7. Activer le site
echo "   - Activation du site..."
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 8. Configuration PHP
echo "   - Configuration PHP..."
sudo tee /etc/php/8.2/fpm/conf.d/99-pisignage.ini > /dev/null << 'PHP_CONFIG'
upload_max_filesize = 500M
post_max_size = 500M
max_execution_time = 300
max_input_time = 300
memory_limit = 256M
PHP_CONFIG

# Aussi pour PHP 8.1 si présent
if [ -d /etc/php/8.1 ]; then
    sudo cp /etc/php/8.2/fpm/conf.d/99-pisignage.ini /etc/php/8.1/fpm/conf.d/ 2>/dev/null
fi

# 9. Test configuration nginx
echo "   - Test configuration nginx..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "   ✅ Configuration nginx valide"
else
    echo "   ❌ Erreur configuration nginx"
fi

# 10. Redémarrer les services
echo "   - Redémarrage des services..."
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm 2>/dev/null || sudo systemctl restart php8.1-fpm

# 11. Vider COMPLÈTEMENT le cache
echo "   - Vidage COMPLET du cache..."
sudo rm -rf /var/cache/nginx/*
sudo rm -rf /tmp/nginx-cache/*
sudo systemctl restart nginx

# 12. Vérification finale
echo ""
echo "   === VÉRIFICATION ==="
echo "   Version déployée :"
cat /opt/pisignage/VERSION 2>/dev/null || echo "Pas de fichier VERSION"
echo ""
echo "   Structure :"
ls -la /opt/pisignage/web/ | head -5
echo ""
echo "   Services :"
sudo systemctl status nginx --no-pager | head -3
sudo systemctl status php8.2-fpm --no-pager 2>/dev/null | head -3 || sudo systemctl status php8.1-fpm --no-pager | head -3
echo ""

echo "   ✅ DÉPLOIEMENT TERMINÉ !"

DEPLOY_SCRIPT

# 4. Test de validation
echo ""
echo "4. Test de validation..."
echo "   Test HTTP..."

response=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.1.103)
if [ "$response" = "200" ]; then
    echo "   ✅ Site accessible (HTTP $response)"
else
    echo "   ❌ Site inaccessible (HTTP $response)"
fi

echo ""
echo "=================================================="
echo "✅ DÉPLOIEMENT v0.8.0 COMPLET"
echo "=================================================="
echo ""
echo "Site : http://192.168.1.103"
echo "Version : 0.8.0"
echo ""
echo "Prochaines étapes :"
echo "1. Tester avec Puppeteer (2 tests minimum)"
echo "2. Vérifier les APIs"
echo "3. Confirmer le succès"
echo ""