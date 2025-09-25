#!/bin/bash

PI_HOST="192.168.1.103"
PI_USER="pi"  
PI_PASS="raspberry"

echo "🧹 NETTOYAGE ET FIX SIMPLE"
echo "=========================="

# 1. Récupérer les fichiers actuels du Pi pour diagnostic
echo "📥 Récupération des fichiers actuels..."
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST:/opt/pisignage/web/index.php" /tmp/index-from-pi.php

# 2. Vérifier ce qui existe dans index.php
echo "🔍 Analyse de index.php..."
echo "Fonctions upload trouvées:"
grep -n "dropHandler\|uploadFiles" /tmp/index-from-pi.php | head -5

# 3. Créer un fix minimal pour l'auto-refresh
cat > /tmp/minimal-refresh-fix.js << 'JSFIX'
// Minimal fix for auto-refresh after upload
// This overrides the upload success handler

// Store original uploadFiles if it exists
window.originalUploadFiles = window.uploadFiles || null;

// Override uploadFiles to add auto-refresh
window.uploadFiles = function(files) {
    console.log('📤 Starting upload with auto-refresh fix...');
    
    const formData = new FormData();
    for (let i = 0; i < files.length; i++) {
        formData.append('files[]', files[i]);
    }

    return fetch('/api/upload.php', {
        method: 'POST',
        body: formData
    })
    .then(response => {
        if (!response.ok) throw new Error('Upload failed');
        return response.json();
    })
    .then(data => {
        console.log('✅ Upload success:', data);
        
        // Show success message
        if (typeof showNotification === 'function') {
            showNotification('✅ Upload terminé!', 'success');
        }
        
        // Close modal if exists
        const modal = document.getElementById('uploadModal');
        if (modal) modal.style.display = 'none';
        
        // AUTO-REFRESH - Simple and direct
        console.log('🔄 Starting auto-refresh...');
        
        // Method 1: Direct reload of media list
        setTimeout(() => {
            if (typeof loadMediaFiles === 'function') {
                console.log('Calling loadMediaFiles...');
                loadMediaFiles();
            }
        }, 500);
        
        // Method 2: Force switch to media tab
        setTimeout(() => {
            const mediaBtn = document.querySelector('[onclick*="showSection(\'media\')"]');
            if (mediaBtn) {
                console.log('Clicking media button...');
                mediaBtn.click();
            }
        }, 1000);
        
        return data;
    })
    .catch(error => {
        console.error('Upload error:', error);
        if (typeof showNotification === 'function') {
            showNotification('❌ Erreur: ' + error.message, 'error');
        }
        throw error;
    });
};

// Fix stats error
const originalRefreshStats = window.refreshStats;
window.refreshStats = function() {
    if (document.getElementById('cpu-usage')) {
        // Only run if stats elements exist
        if (originalRefreshStats) originalRefreshStats();
    }
};

console.log('✅ Auto-refresh fix loaded');
JSFIX

# 4. Déployer le fix
echo "📤 Déploiement du fix minimal..."
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no /tmp/minimal-refresh-fix.js "$PI_USER@$PI_HOST:/tmp/"

sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" << 'EOF'
# Ajouter le fix à la fin de index.php, juste avant </body>
sudo cp /opt/pisignage/web/index.php /opt/pisignage/web/index.php.bak-minimal

# Insérer le script juste avant </body>
sudo sed -i '/<\/body>/i\<script src="/minimal-refresh-fix.js"></script>' /opt/pisignage/web/index.php

# Copier le fichier JS
sudo cp /tmp/minimal-refresh-fix.js /opt/pisignage/web/
sudo chown www-data:www-data /opt/pisignage/web/minimal-refresh-fix.js

# Clear cache
sudo rm -rf /var/cache/nginx/*
sudo systemctl restart nginx

echo "✅ Fix minimal déployé"
EOF

echo ""
echo "============================"
echo "✅ FIX MINIMAL APPLIQUÉ"
echo "============================"
echo ""
echo "Solution simplifiée:"
echo "  - Override de uploadFiles() pour ajouter l'auto-refresh"
echo "  - Appel de loadMediaFiles() après 500ms"
echo "  - Click sur l'onglet Media après 1s"
echo "  - Fix de l'erreur stats"
echo ""
echo "Testez maintenant sur http://$PI_HOST/"
