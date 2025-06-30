#!/bin/bash

# Script de correction pour autoriser exec() dans PHP
echo "=== Correction de la fonction exec() PHP ==="

# Vérifier qu'on est root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté avec sudo"
   exit 1
fi

# Fichier de configuration PHP-FPM
PHP_POOL_CONFIG="/etc/php/8.2/fpm/pool.d/pi-signage.conf"

if [ ! -f "$PHP_POOL_CONFIG" ]; then
    echo "Erreur: $PHP_POOL_CONFIG n'existe pas"
    exit 1
fi

echo "Sauvegarde de la configuration..."
cp "$PHP_POOL_CONFIG" "$PHP_POOL_CONFIG.bak.$(date +%Y%m%d_%H%M%S)"

echo "Mise à jour de la configuration PHP..."
# Retirer exec de la liste des fonctions désactivées
sed -i 's/disable_functions = exec,passthru/disable_functions = passthru/' "$PHP_POOL_CONFIG"

echo "Vérification de la modification..."
if grep -q "disable_functions = passthru,system" "$PHP_POOL_CONFIG"; then
    echo "✓ Configuration mise à jour avec succès"
else
    echo "⚠ Vérification manuelle nécessaire"
fi

echo ""
echo "Redémarrage de PHP-FPM..."
systemctl restart php8.2-fpm

if systemctl is-active --quiet php8.2-fpm; then
    echo "✓ PHP-FPM redémarré avec succès"
else
    echo "✗ Erreur lors du redémarrage de PHP-FPM"
    exit 1
fi

echo ""
echo "=== Test de la fonction exec() ==="

# Test simple
php -r 'if(function_exists("exec")) { echo "✓ exec() est disponible\n"; exec("echo Test OK", $out); echo "✓ Résultat: " . $out[0] . "\n"; } else { echo "✗ exec() n'\''est PAS disponible\n"; }'

echo ""
echo "=== Correction terminée ==="
echo ""
echo "Testez maintenant le téléchargement YouTube dans l'interface web."