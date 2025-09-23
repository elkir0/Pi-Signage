#!/bin/bash

# PiSignage - Script de réparation automatique des services web
# Corrige nginx et PHP-FPM après redémarrage

echo "🔧 Réparation des services web PiSignage..."

# Créer les dossiers de logs si manquants
if [ ! -d "/var/log/nginx" ]; then
    echo "✓ Création dossier logs nginx..."
    sudo mkdir -p /var/log/nginx
    sudo touch /var/log/nginx/error.log /var/log/nginx/access.log
    sudo chown -R www-data:adm /var/log/nginx
fi

# Créer dossier pisignage si manquant
if [ ! -d "/opt/pisignage/logs" ]; then
    echo "✓ Création dossier logs pisignage..."
    sudo mkdir -p /opt/pisignage/logs
    sudo chown -R www-data:www-data /opt/pisignage/logs
fi

# Créer dossier screenshots si manquant
if [ ! -d "/opt/pisignage/screenshots" ]; then
    echo "✓ Création dossier screenshots..."
    sudo mkdir -p /opt/pisignage/screenshots
    sudo chown -R www-data:www-data /opt/pisignage/screenshots
fi

# Vérifier PHP-FPM
echo "✓ Vérification PHP-FPM..."
sudo systemctl restart php8.2-fpm

# Redémarrer nginx
echo "✓ Redémarrage nginx..."
sudo systemctl restart nginx

# Vérifier les statuts
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx opérationnel"
else
    echo "❌ Nginx échec"
    sudo journalctl -xe -u nginx --no-pager | tail -20
fi

if systemctl is-active --quiet php8.2-fpm; then
    echo "✅ PHP-FPM opérationnel"
else
    echo "❌ PHP-FPM échec"
fi

# Test HTTP
sleep 2
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
    echo "✅ Interface web accessible sur http://localhost"
else
    echo "❌ Interface web inaccessible"
fi

echo "🔧 Réparation terminée"