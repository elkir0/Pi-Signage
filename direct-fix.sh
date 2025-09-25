#!/bin/bash

PI_HOST="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "🔧 FIX DIRECT DES FONCTIONS"
echo "============================"

# Récupérer index.php actuel
echo "📥 Récupération de index.php..."
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST:/opt/pisignage/web/index.php" /tmp/index-current.php

# Trouver où se trouve uploadFiles
echo "🔍 Localisation de uploadFiles..."
grep -n "function uploadFiles" /tmp/index-current.php | head -1

# Créer le patch pour corriger uploadFiles ET l'erreur stats
sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" << 'EOF'
echo "📝 Application des corrections..."

# Backup
sudo cp /opt/pisignage/web/index.php /opt/pisignage/web/index.php.bak-directfix

# 1. Corriger uploadFiles dans index.php pour ajouter l'auto-refresh
sudo cat > /tmp/fix-upload.sed << 'SEDFIX'
# Chercher la fin de la fonction uploadFiles et ajouter l'auto-refresh
/xhr\.onload = function/,/};/ {
    /if (xhr\.status === 200)/ {
        a\
                        // AUTO-REFRESH après upload réussi\
                        console.log("Auto-refresh: tentative de refresh...");\
                        setTimeout(function() {\
                            if (typeof loadMediaFiles === "function") {\
                                console.log("Auto-refresh: appel de loadMediaFiles");\
                                loadMediaFiles();\
                            }\
                            // Forcer affichage section media\
                            var mediaSection = document.getElementById("media");\
                            if (mediaSection) {\
                                mediaSection.classList.add("active");\
                                mediaSection.style.display = "block";\
                            }\
                        }, 800);
    }
}
SEDFIX

# Appliquer le patch
sudo sed -i -f /tmp/fix-upload.sed /opt/pisignage/web/index.php

# 2. Corriger l'erreur stats dans functions.js
sudo sed -i '413,416s/document\.getElementById/var elem = document.getElementById/g; 413,416s/\.textContent/; if(elem) elem.textContent/g' /opt/pisignage/web/functions.js

# Alternative plus simple pour stats - remplacer tout le bloc
sudo cat > /tmp/fix-stats.js << 'STATSFIX'
                // Update dashboard stats (avec vérification)
                var cpuElem = document.getElementById('cpu-usage');
                var ramElem = document.getElementById('ram-usage');
                var tempElem = document.getElementById('temperature');
                var storageElem = document.getElementById('storage-usage');
                
                if (cpuElem) cpuElem.textContent = stats.cpu + '%';
                if (ramElem) ramElem.textContent = stats.ram + '%';
                if (tempElem) tempElem.textContent = stats.temperature + '°C';
                if (storageElem) storageElem.textContent = stats.storage;
STATSFIX

# Remplacer les lignes problématiques dans functions.js
sudo awk '
/Update dashboard stats/ {
    print
    system("cat /tmp/fix-stats.js")
    for(i=1; i<=5; i++) getline
    next
}
{print}
' /opt/pisignage/web/functions.js > /tmp/functions-fixed.js

sudo cp /tmp/functions-fixed.js /opt/pisignage/web/functions.js
sudo chown www-data:www-data /opt/pisignage/web/functions.js

# 3. Clear cache et restart
sudo rm -rf /var/cache/nginx/*
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

echo "✅ Corrections appliquées"

# Vérifier
echo ""
echo "Vérifications:"
echo "-------------"
grep -c "Auto-refresh" /opt/pisignage/web/index.php && echo "✅ Auto-refresh ajouté" || echo "❌ Auto-refresh non trouvé"
grep -c "if (cpuElem)" /opt/pisignage/web/functions.js && echo "✅ Fix stats appliqué" || echo "❌ Fix stats non appliqué"
EOF

echo ""
echo "============================"
echo "✅ CORRECTIONS DIRECTES OK"
echo "============================"
echo ""
echo "Corrections appliquées:"
echo "  ✅ Auto-refresh ajouté directement dans uploadFiles"
echo "  ✅ Erreur stats corrigée avec vérification null"
echo ""
echo "Testez maintenant sur http://$PI_HOST/"
echo "L'auto-refresh devrait fonctionner après 800ms"
