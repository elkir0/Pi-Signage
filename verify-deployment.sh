#!/bin/bash

PI_HOST="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "🔍 Vérification du déploiement sur le Pi"
echo "========================================"

sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" << 'EOF'
echo "1. Vérification de functions.js:"
echo "--------------------------------"
grep -n "window.loadMediaFiles" /opt/pisignage/web/functions.js 2>/dev/null && echo "✅ window.loadMediaFiles trouvé" || echo "❌ window.loadMediaFiles NON trouvé"
grep -n "FIXED: Refresh media list" /opt/pisignage/web/functions.js 2>/dev/null && echo "✅ Fix refresh trouvé" || echo "❌ Fix refresh NON trouvé"

echo ""
echo "2. Vérification de index.php:"
echo "-----------------------------"
grep -n "window.loadMediaFiles" /opt/pisignage/web/index.php 2>/dev/null && echo "✅ window.loadMediaFiles trouvé dans index.php" || echo "❌ window.loadMediaFiles NON trouvé dans index.php"

echo ""
echo "3. Date de modification des fichiers:"
echo "-------------------------------------"
ls -la /opt/pisignage/web/functions.js | awk '{print "functions.js:", $6, $7, $8}'
ls -la /opt/pisignage/web/index.php | awk '{print "index.php:", $6, $7, $8}'

echo ""
echo "4. Test de la fonction loadMediaFiles:"
echo "---------------------------------------"
curl -s http://localhost | grep -c "window.loadMediaFiles" && echo "✅ Fonction globale détectée" || echo "❌ Fonction pas globale"

echo ""
echo "5. Dernière ligne du refresh dans functions.js:"
echo "------------------------------------------------"
grep -A5 "FIXED: Refresh media list" /opt/pisignage/web/functions.js | head -10
EOF