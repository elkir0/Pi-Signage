#!/bin/bash

# Script d'initialisation du serveur de production Raspberry Pi
# À exécuter UNE FOIS pour configurer le serveur

set -e

PRODUCTION_IP="192.168.1.103"
PRODUCTION_USER="pi"
PRODUCTION_PASS="raspberry"
GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"

echo "🔧 INITIALISATION DU SERVEUR DE PRODUCTION"
echo "==========================================="
date

# Créer le script d'init à exécuter sur le Raspberry
cat > /tmp/init_raspberry.sh << 'INIT'
#!/bin/bash
set -e

echo "📦 1. Installation des dépendances..."
sudo apt-get update
sudo apt-get install -y git nginx php-fpm php-cli php-json php-curl

echo "🔧 2. Configuration de la structure..."
# Nettoyer le dossier actuel
sudo rm -rf /var/www/html/*
sudo rm -rf /var/www/html/.git

# Cloner le repository
echo "📥 3. Clone du repository GitHub..."
cd /var/www
sudo rm -rf html
sudo git clone https://github.com/elkir0/Pi-Signage.git html
cd html

echo "📂 4. Création des dossiers manquants..."
sudo mkdir -p /var/www/html/media
sudo mkdir -p /var/www/html/config
sudo mkdir -p /var/www/html/logs
sudo mkdir -p /var/www/html/scripts

echo "🔑 5. Configuration des permissions..."
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
sudo chmod -R 777 /var/www/html/media
sudo chmod -R 777 /var/www/html/config
sudo chmod -R 777 /var/www/html/logs
sudo chmod +x /var/www/html/scripts/*.sh

echo "⚙️ 6. Configuration Nginx..."
sudo tee /etc/nginx/sites-available/pisignage << 'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html/web;
    index index.php index.html;
    
    server_name _;
    
    client_max_body_size 500M;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
NGINX

# Activer le site
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

echo "🔄 7. Redémarrage des services..."
sudo systemctl restart nginx
sudo systemctl restart php*-fpm

echo "📊 8. Vérification finale..."
echo "Structure créée:"
ls -la /var/www/html/
echo ""
echo "Dossier web:"
ls -la /var/www/html/web/ | head -10
echo ""
echo "APIs:"
ls -la /var/www/html/web/api/ | head -10

echo "✅ INITIALISATION TERMINÉE!"
echo "Interface disponible sur: http://$(hostname -I | cut -d' ' -f1)"
INIT

echo "🚀 Envoi et exécution du script d'initialisation..."
sshpass -p "$PRODUCTION_PASS" scp /tmp/init_raspberry.sh $PRODUCTION_USER@$PRODUCTION_IP:/tmp/
sshpass -p "$PRODUCTION_PASS" ssh $PRODUCTION_USER@$PRODUCTION_IP "bash /tmp/init_raspberry.sh"

echo ""
echo "✅ SERVEUR DE PRODUCTION INITIALISÉ!"
echo "==========================================="
echo "Interface: http://$PRODUCTION_IP"
echo "Utilisez maintenant deploy-production.sh pour les mises à jour"