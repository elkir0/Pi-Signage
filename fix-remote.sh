#!/bin/bash

# Script à exécuter directement sur le Raspberry Pi
# Usage: curl -sL https://raw.githubusercontent.com/elkir0/Pi-Signage/main/fix-remote.sh | bash

set -e

echo "======================================"
echo "Fix PiSignage v0.8.0 - Erreurs 500"
echo "======================================"
echo

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# 1. Mise à jour depuis GitHub
log_info "Téléchargement des corrections depuis GitHub..."

cd /opt/pisignage

# Sauvegarder les configs existantes
if [ -f web/config.php ]; then
    cp web/config.php web/config.php.backup
fi

# Télécharger les fichiers corrigés
git pull origin main || {
    log_warn "Git pull échoué, téléchargement manuel..."

    # Télécharger les fichiers critiques directement
    GITHUB_RAW="https://raw.githubusercontent.com/elkir0/Pi-Signage/main"

    wget -q -O web/config.php "$GITHUB_RAW/web/config.php"
    wget -q -O web/api/system.php "$GITHUB_RAW/web/api/system.php"
    wget -q -O web/api/media.php "$GITHUB_RAW/web/api/media.php"
    wget -q -O web/api/playlist.php "$GITHUB_RAW/web/api/playlist.php"
    wget -q -O web/api/upload.php "$GITHUB_RAW/web/api/upload.php"

    mkdir -p config
    wget -q -O config/nginx-pisignage.conf "$GITHUB_RAW/config/nginx-pisignage.conf"
    wget -q -O config/php-upload.ini "$GITHUB_RAW/config/php-upload.ini"
}

# 2. Créer les répertoires nécessaires
log_info "Création des répertoires..."

sudo mkdir -p /opt/pisignage/data
sudo mkdir -p /opt/pisignage/logs
sudo mkdir -p /opt/pisignage/playlists
sudo mkdir -p /opt/pisignage/media
sudo mkdir -p /opt/pisignage/media/thumbnails
sudo mkdir -p /opt/pisignage/web/screenshots
sudo mkdir -p /tmp/nginx_upload

# 3. Installer les extensions PHP manquantes
log_info "Installation des extensions PHP..."

# Détecter la version de PHP
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-curl \
    sqlite3 2>/dev/null || {
    log_warn "Certaines extensions n'ont pas pu être installées"
}

# 4. Configurer PHP
log_info "Configuration PHP..."

PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
    sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' "$PHP_INI"
    sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' "$PHP_INI"
    sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
    sudo sed -i 's/max_input_time = .*/max_input_time = 300/' "$PHP_INI"
    sudo sed -i 's/memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
    log_info "PHP configuré pour uploads 500MB"
else
    log_warn "php.ini non trouvé pour PHP $PHP_VERSION"
fi

# 5. Configurer nginx
log_info "Configuration nginx..."

if [ -f /opt/pisignage/config/nginx-pisignage.conf ]; then
    sudo cp /opt/pisignage/config/nginx-pisignage.conf /etc/nginx/sites-available/pisignage
    sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    log_info "Configuration nginx appliquée"
else
    log_warn "Configuration nginx non trouvée"
fi

# 6. Permissions
log_info "Configuration des permissions..."

sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R $USER:$USER /opt/pisignage/data
sudo chown -R $USER:$USER /opt/pisignage/logs
sudo chown -R $USER:$USER /opt/pisignage/playlists
sudo chown -R www-data:www-data /opt/pisignage/media
sudo chown www-data:www-data /tmp/nginx_upload

# Permissions spéciales pour l'écriture
sudo chmod 775 /opt/pisignage/data
sudo chmod 775 /opt/pisignage/logs
sudo chmod 775 /opt/pisignage/media
sudo chmod 775 /tmp/nginx_upload

# 7. Créer la base de données
log_info "Initialisation de la base de données..."

if [ ! -f /opt/pisignage/data/pisignage.db ]; then
    sqlite3 /opt/pisignage/data/pisignage.db << EOF
CREATE TABLE IF NOT EXISTS media_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL,
    original_name TEXT,
    file_size INTEGER,
    mime_type TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS playlists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    items TEXT DEFAULT '[]',
    duration INTEGER DEFAULT 10,
    transition TEXT DEFAULT 'none',
    is_active INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
    sudo chown www-data:www-data /opt/pisignage/data/pisignage.db
    log_info "Base de données créée"
fi

# 8. Redémarrer les services
log_info "Redémarrage des services..."

sudo systemctl restart nginx
sudo systemctl restart php${PHP_VERSION}-fpm

# 9. Test rapide
log_info "Test des APIs..."

sleep 2

# Test system API
if curl -s "http://localhost/api/system.php?action=stats" | grep -q "success"; then
    log_info "API système: OK"
else
    log_error "API système: Erreur"

    # Afficher les erreurs PHP
    echo
    log_warn "Vérification des erreurs..."

    # Tester avec le script de diagnostic
    if [ ! -f /opt/pisignage/web/diagnose.php ]; then
        cat > /opt/pisignage/web/diagnose.php << 'DIAGEOF'
<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: text/plain');
echo "=== TEST CONFIG ===\n";
echo "PHP Version: " . PHP_VERSION . "\n";
echo "Extensions: \n";
foreach (['pdo_sqlite', 'mbstring', 'gd', 'json'] as $ext) {
    echo "  - $ext: " . (extension_loaded($ext) ? "OK" : "MANQUANT") . "\n";
}
echo "\nInclusion config.php...\n";
try {
    require_once '/opt/pisignage/web/config.php';
    echo "Config OK\n";
} catch (Exception $e) {
    echo "ERREUR: " . $e->getMessage() . "\n";
}
DIAGEOF
    fi

    echo
    curl -s "http://localhost/diagnose.php" | head -20
fi

# Test media API
if curl -s "http://localhost/api/media.php" | grep -q "success\|data"; then
    log_info "API média: OK"
else
    log_error "API média: Erreur"
fi

echo
echo "======================================"
echo "Correction terminée!"
echo "======================================"
echo
echo "Interface disponible sur:"
echo "  http://$(hostname -I | awk '{print $1}')/"
echo
echo "Si des erreurs persistent, vérifiez:"
echo "  sudo tail -f /var/log/nginx/error.log"
echo "  sudo tail -f /var/log/php*.log"
echo "  tail -f /opt/pisignage/logs/system.log"
echo