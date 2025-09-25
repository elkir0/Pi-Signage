#!/bin/bash

PI_HOST="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "==========================================="
echo "🚀 DÉPLOIEMENT SOLUTION BULLETPROOF"
echo "==========================================="

# 1. Copier functions.js modifié
echo "📤 Copie de functions.js..."
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no \
    /opt/pisignage/web/functions.js \
    "$PI_USER@$PI_HOST:/tmp/"

# 2. Vérifier et corriger index.php sur le Pi
echo "🔧 Vérification de index.php..."
sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" << 'EOF'
# Backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
sudo cp /opt/pisignage/web/functions.js "/opt/pisignage/web/functions.js.bak-$TIMESTAMP"

# Déployer functions.js
sudo cp /tmp/functions.js /opt/pisignage/web/functions.js
sudo chown www-data:www-data /opt/pisignage/web/functions.js

# Vérifier que loadMediaFiles est bien globale dans index.php
echo "Vérification de window.loadMediaFiles dans index.php:"
grep -n "window.loadMediaFiles" /opt/pisignage/web/index.php | head -3

# Si pas trouvé, on doit corriger
if ! grep -q "window.loadMediaFiles" /opt/pisignage/web/index.php; then
    echo "⚠️ window.loadMediaFiles n'est pas globale, correction..."
    
    # Chercher function loadMediaFiles et la rendre globale
    sudo sed -i 's/function loadMediaFiles/window.loadMediaFiles = function loadMediaFiles/g' /opt/pisignage/web/index.php
    
    echo "✅ Correction appliquée"
fi

# Vérifier l'ID du conteneur media-list
echo ""
echo "Vérification de l'ID media-list dans index.php:"
grep -n 'id="media-list"' /opt/pisignage/web/index.php | head -1

# Clear cache et restart
echo ""
echo "🔄 Redémarrage des services..."
sudo rm -rf /var/cache/nginx/*
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

echo "✅ Déploiement terminé"

# Test rapide
echo ""
echo "🧪 Test de l'interface..."
curl -s "http://localhost" > /dev/null && echo "✅ Interface accessible" || echo "❌ Erreur interface"
EOF

echo ""
echo "==========================================="
echo "✅ SOLUTION BULLETPROOF DÉPLOYÉE"
echo "==========================================="
echo ""
echo "La solution utilise maintenant:"
echo "  ✅ 3 tentatives avec backoff exponentiel (300ms, 450ms, 675ms)"
echo "  ✅ Méthode A: window.loadMediaFiles() avec vérification"
echo "  ✅ Méthode B: API direct + reconstruction DOM"
echo "  ✅ Méthode C: Rechargement page en dernier recours"
echo "  ✅ Cache busting avec timestamp"
echo "  ✅ Event system pour coordination"
echo ""
echo "🌐 Testez sur http://$PI_HOST/"
echo ""
echo "Pour tester:"
echo "  1. Uploadez un fichier (drag & drop ou click)"
echo "  2. L'auto-refresh devrait fonctionner automatiquement"
echo "  3. Regardez la console pour voir les tentatives"
