#!/bin/bash

# Script de déploiement rapide des fichiers web
echo "=== Déploiement rapide des fichiers web ==="

# Vérifier qu'on est root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté avec sudo"
   exit 1
fi

# Répertoires
WEB_ROOT="/var/www/pi-signage"
SOURCE_DIR="$(pwd)/web-interface"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Erreur: Répertoire web-interface non trouvé"
    echo "Assurez-vous d'être dans le répertoire Pi-Signage"
    exit 1
fi

echo "Copie des fichiers API..."
cp -v "$SOURCE_DIR/api/youtube-test.php" "$WEB_ROOT/api/"
cp -v "$SOURCE_DIR/api/youtube-simple.php" "$WEB_ROOT/api/"
cp -v "$SOURCE_DIR/api/test-youtube.php" "$WEB_ROOT/api/"
cp -v "$SOURCE_DIR/api/youtube-debug.php" "$WEB_ROOT/api/"

echo ""
echo "Copie du JavaScript mis à jour..."
cp -v "$SOURCE_DIR/assets/js/main.js" "$WEB_ROOT/assets/js/"

echo ""
echo "Correction des permissions..."
chown -R www-data:www-data "$WEB_ROOT/api/"
chown -R www-data:www-data "$WEB_ROOT/assets/"
chmod -R 755 "$WEB_ROOT/api/"

echo ""
echo "=== Déploiement terminé ==="
echo ""
echo "Vérification des fichiers:"
ls -la "$WEB_ROOT/api/youtube-test.php" 2>/dev/null && echo "✓ youtube-test.php déployé" || echo "✗ youtube-test.php manquant"
ls -la "$WEB_ROOT/api/youtube-simple.php" 2>/dev/null && echo "✓ youtube-simple.php déployé" || echo "✗ youtube-simple.php manquant"

echo ""
echo "Vous pouvez maintenant tester:"
echo "curl -X POST http://192.168.64.3/api/youtube-test.php -H 'Content-Type: application/json' -d '{\"url\":\"test\"}'"