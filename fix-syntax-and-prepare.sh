#!/bin/bash

PI_HOST="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "🔧 FIX SYNTAXE ET PRÉPARATION GITHUB"
echo "====================================="

# 1. Récupérer les fichiers corrigés du Pi
echo "📥 Récupération des fichiers du Pi..."
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no \
    "$PI_USER@$PI_HOST:/opt/pisignage/web/functions.js" \
    "$PI_USER@$PI_HOST:/opt/pisignage/web/index.php" \
    /opt/pisignage/web/

# 2. Vérifier et corriger l'erreur de syntaxe ligne 421
echo "🔍 Vérification ligne 421..."
sed -n '418,424p' /opt/pisignage/web/functions.js

# Corriger l'erreur de syntaxe (parenthèse manquante)
echo "✏️ Correction de l'erreur de syntaxe..."
sed -i '421s/;$/);/' /opt/pisignage/web/functions.js

# Vérifier la correction
echo "Après correction:"
sed -n '418,424p' /opt/pisignage/web/functions.js

# 3. Déployer la correction sur le Pi
echo "📤 Déploiement de la correction..."
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no \
    /opt/pisignage/web/functions.js \
    "$PI_USER@$PI_HOST:/tmp/"

sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" << 'EOF'
sudo cp /tmp/functions.js /opt/pisignage/web/
sudo chown www-data:www-data /opt/pisignage/web/functions.js
sudo systemctl restart nginx
echo "✅ Correction déployée"
EOF

echo ""
echo "====================================="
echo "✅ FICHIERS PRÊTS POUR GITHUB"
echo "====================================="
