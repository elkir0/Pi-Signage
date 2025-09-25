#!/bin/bash
#
# PiSignage - Deploy Final Fixes (Auto-refresh + Password warning)
#

set -e

PI_HOST="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "========================================="
echo "🚀 DÉPLOIEMENT FINAL DES CORRECTIONS"
echo "========================================="

# 1. Copier les fichiers
echo "📦 Copie des fichiers corrigés..."
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no \
    web/functions.js \
    web/index.php \
    "$PI_USER@$PI_HOST:/tmp/"

# 2. Déployer sur le Pi
echo "⚙️ Installation sur le Pi..."
sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" << 'EOF'
# Backup avec timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
sudo cp /opt/pisignage/web/functions.js "/opt/pisignage/web/functions.js.bak-$TIMESTAMP"
sudo cp /opt/pisignage/web/index.php "/opt/pisignage/web/index.php.bak-$TIMESTAMP"

# Copier les nouvelles versions
sudo cp /tmp/functions.js /opt/pisignage/web/
sudo cp /tmp/index.php /opt/pisignage/web/

# Permissions
sudo chown www-data:www-data /opt/pisignage/web/functions.js
sudo chown www-data:www-data /opt/pisignage/web/index.php

# Vider TOUT le cache
sudo rm -rf /var/cache/nginx/*
sudo rm -rf /tmp/nginx-cache/*
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

# Nettoyer
rm -f /tmp/functions.js /tmp/index.php

echo "✅ Déploiement terminé"

# Vérifier les changements
echo ""
echo "Vérifications:"
echo "--------------"
grep -c "Force show media section" /opt/pisignage/web/functions.js && echo "✅ Force refresh présent" || echo "❌ Force refresh absent"
grep -c "autocomplete=\"new-password\"" /opt/pisignage/web/index.php && echo "✅ Fix password présent" || echo "❌ Fix password absent"
EOF

# 3. Test rapide
echo ""
echo "🧪 Test rapide des corrections:"
echo "================================"

# Test que l'interface se charge sans erreur
curl -s "http://$PI_HOST" > /dev/null && echo "✅ Interface accessible" || echo "❌ Interface inaccessible"

echo ""
echo "========================================="
echo "✅ CORRECTIONS DÉPLOYÉES"
echo "========================================="
echo ""
echo "Améliorations appliquées:"
echo "  ✅ Auto-refresh force l'affichage de la section média"
echo "  ✅ Champ password dans un formulaire (plus d'avertissement)"
echo "  ✅ Cache vidé et services redémarrés"
echo ""
echo "🌐 Testez maintenant sur http://$PI_HOST/"
echo ""
echo "Pour tester:"
echo "  1. Uploadez un fichier (drag & drop ou click)"
echo "  2. La section média s'affiche automatiquement"
echo "  3. Les fichiers apparaissent sans refresh manuel"
echo "  4. Plus d'avertissement pour le champ password"