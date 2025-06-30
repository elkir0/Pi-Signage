#!/bin/bash

# Script de correction rapide pour config.php
echo "=== Correction du chemin yt-dlp dans config.php ==="

# Vérifier qu'on est root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté avec sudo"
   exit 1
fi

CONFIG_FILE="/var/www/pi-signage/includes/config.php"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Erreur: $CONFIG_FILE n'existe pas"
    exit 1
fi

echo "Sauvegarde du fichier original..."
cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d_%H%M%S)"

echo "Mise à jour du chemin yt-dlp..."
# Remplacer l'ancienne définition par la nouvelle
sed -i "s|define('YTDLP_BIN', '/usr/local/bin/yt-dlp');|define('YTDLP_BIN', 'sudo /opt/scripts/yt-dlp-wrapper.sh');|" "$CONFIG_FILE"

# Vérifier le changement
if grep -q "sudo /opt/scripts/yt-dlp-wrapper.sh" "$CONFIG_FILE"; then
    echo "✓ Configuration mise à jour avec succès"
    echo ""
    echo "Nouvelle configuration:"
    grep "YTDLP_BIN" "$CONFIG_FILE"
else
    echo "✗ Erreur lors de la mise à jour"
    echo ""
    echo "Configuration actuelle:"
    grep "YTDLP_BIN" "$CONFIG_FILE"
    exit 1
fi

echo ""
echo "=== Test du wrapper ==="

# Tester que le wrapper fonctionne
echo "Test 1: Version yt-dlp via wrapper..."
if sudo -u www-data sudo /opt/scripts/yt-dlp-wrapper.sh --version; then
    echo "✓ Le wrapper fonctionne correctement"
else
    echo "✗ Problème avec le wrapper"
fi

echo ""
echo "=== Correction terminée ==="
echo "Vous pouvez maintenant tester le téléchargement YouTube"