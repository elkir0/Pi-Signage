#!/bin/bash

# Déploiement direct des fichiers corrigés
# Ce script copie directement les fichiers sans utiliser SSH interactif

RASPI_IP="192.168.1.103"
RASPI_USER="pi"

echo "======================================"
echo "Déploiement direct vers $RASPI_IP"
echo "======================================"
echo

# Créer un script d'installation distant qui sera exécuté sur le Pi
cat > /tmp/remote-fix.sh << 'ENDSCRIPT'
#!/bin/bash
set -e

echo "Application des corrections..."

# Créer les répertoires nécessaires
sudo mkdir -p /opt/pisignage/data
sudo mkdir -p /opt/pisignage/logs
sudo mkdir -p /opt/pisignage/playlists
sudo mkdir -p /tmp/nginx_upload
sudo mkdir -p /opt/pisignage/web/api

# Appliquer la configuration PHP
if [ -f /etc/php/8.2/fpm/php.ini ]; then
    echo "Configuration PHP..."
    sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' /etc/php/8.2/fpm/php.ini
    sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' /etc/php/8.2/fpm/php.ini
    sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini
    sudo sed -i 's/max_input_time = .*/max_input_time = 300/' /etc/php/8.2/fpm/php.ini
    sudo sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.2/fpm/php.ini
fi

# Configurer nginx si nécessaire
if [ -f /opt/pisignage/config/nginx-pisignage.conf ]; then
    echo "Configuration nginx..."
    sudo cp /opt/pisignage/config/nginx-pisignage.conf /etc/nginx/sites-available/pisignage
    sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# Permissions
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R pi:pi /opt/pisignage/data
sudo chown -R pi:pi /opt/pisignage/logs
sudo chown -R pi:pi /opt/pisignage/playlists
sudo chown www-data:www-data /tmp/nginx_upload

# Installer les extensions PHP nécessaires
echo "Installation des extensions PHP..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    php8.2-sqlite3 \
    php8.2-mbstring \
    php8.2-gd \
    php8.2-xml \
    php8.2-curl \
    sqlite3 2>/dev/null || true

# Redémarrer les services
echo "Redémarrage des services..."
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

echo "Corrections appliquées!"
ENDSCRIPT

echo "Copie des fichiers..."

# Copier les fichiers corrigés un par un
FILES=(
    "web/config.php"
    "web/api/system.php"
    "web/api/media.php"
    "web/api/playlist.php"
    "web/api/upload.php"
    "config/nginx-pisignage.conf"
    "config/php-upload.ini"
)

for file in "${FILES[@]}"; do
    if [ -f "/opt/pisignage/$file" ]; then
        echo "  - $file"
        scp -o BatchMode=yes -o ConnectTimeout=5 \
            "/opt/pisignage/$file" \
            "${RASPI_USER}@${RASPI_IP}:/opt/pisignage/$file" 2>/dev/null || {
            echo "    ERREUR: Impossible de copier $file"
            echo "    Vérifiez que SSH est configuré avec une clé"
        }
    fi
done

# Copier et exécuter le script de fix
echo
echo "Exécution du script de correction..."
scp -o BatchMode=yes /tmp/remote-fix.sh ${RASPI_USER}@${RASPI_IP}:/tmp/ 2>/dev/null && \
ssh -o BatchMode=yes ${RASPI_USER}@${RASPI_IP} "bash /tmp/remote-fix.sh" 2>/dev/null || {
    echo "ERREUR: Impossible d'exécuter le script distant"
    echo
    echo "=== Configuration SSH requise ==="
    echo "Sur votre machine locale, exécutez:"
    echo "  ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa"
    echo "  ssh-copy-id ${RASPI_USER}@${RASPI_IP}"
    echo
    echo "Ou copiez manuellement les fichiers:"
    echo "  scp -r /opt/pisignage/web/api/*.php ${RASPI_USER}@${RASPI_IP}:/opt/pisignage/web/api/"
    echo "  scp /opt/pisignage/web/config.php ${RASPI_USER}@${RASPI_IP}:/opt/pisignage/web/"
}

echo
echo "Test des APIs..."
curl -s "http://${RASPI_IP}/api/system.php?action=stats" | head -1