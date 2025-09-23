#!/bin/bash

# Script de déploiement rapide PiSignage
# À exécuter sur un Raspberry Pi fraîchement installé

echo "🚀 Déploiement rapide PiSignage v0.8.0"
echo ""

# Vérifier connexion
if ! ping -c 1 github.com > /dev/null 2>&1; then
    echo "❌ Pas de connexion Internet"
    exit 1
fi

# Télécharger et exécuter le script d'installation
echo "📥 Téléchargement du script d'installation..."
wget -q https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install-fresh.sh -O /tmp/install.sh

if [ ! -f /tmp/install.sh ]; then
    echo "❌ Échec du téléchargement"
    exit 1
fi

echo "🔧 Lancement de l'installation..."
chmod +x /tmp/install.sh
/tmp/install.sh

echo "✅ Déploiement terminé!"