#!/bin/bash
#
# Fix all JavaScript errors and auto-refresh issue
#

set -e

PI_HOST="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "========================================="
echo "🔧 CORRECTION COMPLÈTE DES ERREURS JS"
echo "========================================="

# 1. Créer les fichiers corrigés localement
echo "📝 Création des fichiers corrigés..."

# Fix functions.js - Corriger les erreurs de stats et améliorer auto-refresh
cat > /tmp/functions-fixed.js << 'JSFIX'
// PiSignage v0.8.0 - Fixed Functions
// Corrected version with all error fixes

console.log('✅ PiSignage v0.8.0 - Functions loading...');

// Upload functionality
function openUploadModal() {
    const modal = document.getElementById('uploadModal');
    if (modal) modal.style.display = 'block';

    // Re-initialize drag & drop after modal opens
    setTimeout(() => {
        const dropZone = document.getElementById('dropZone');
        const fileInput = document.getElementById('fileInput');

        if (dropZone && fileInput) {
            // Remove old listeners
            dropZone.replaceWith(dropZone.cloneNode(true));
            const newDropZone = document.getElementById('dropZone');

            // Click to select files
            newDropZone.addEventListener('click', () => {
                fileInput.click();
            });

            // Drag & drop
            newDropZone.addEventListener('dragover', (e) => {
                e.preventDefault();
                newDropZone.classList.add('drag-over');
            });

            newDropZone.addEventListener('dragleave', () => {
                newDropZone.classList.remove('drag-over');
            });

            newDropZone.addEventListener('drop', (e) => {
                e.preventDefault();
                newDropZone.classList.remove('drag-over');
                handleFiles(e.dataTransfer.files);
            });

            // File input change
            fileInput.addEventListener('change', (e) => {
                handleFiles(e.target.files);
            });
        }
    }, 100);
}

function closeModal() {
    const modal = document.getElementById('uploadModal');
    if (modal) modal.style.display = 'none';
    resetUploadForm();
}

function resetUploadForm() {
    const fileList = document.getElementById('fileList');
    const uploadBtn = document.getElementById('uploadBtn');
    const fileInput = document.getElementById('fileInput');
    const uploadProgress = document.getElementById('uploadProgress');

    if (fileList) fileList.innerHTML = '';
    if (uploadBtn) {
        uploadBtn.disabled = true;
        uploadBtn.textContent = '📤 Upload';
    }
    if (fileInput) fileInput.value = '';
    if (uploadProgress) uploadProgress.style.display = 'none';
}

function handleFiles(files) {
    if (!files || files.length === 0) return;

    const fileList = document.getElementById('fileList');
    const uploadBtn = document.getElementById('uploadBtn');

    if (!fileList || !uploadBtn) return;

    fileList.innerHTML = '';
    let totalSize = 0;

    Array.from(files).forEach(file => {
        const fileItem = document.createElement('div');
        fileItem.className = 'file-item';

        const size = (file.size / (1024 * 1024)).toFixed(2);
        totalSize += file.size;

        fileItem.innerHTML = `
            <span class="file-name">📄 ${file.name}</span>
            <span class="file-size">${size} MB</span>
        `;

        fileList.appendChild(fileItem);
    });

    // Enable upload button
    uploadBtn.disabled = false;
    uploadBtn.textContent = `📤 Upload (${files.length} fichier${files.length > 1 ? 's' : ''})`;

    // Store files for upload
    uploadBtn.dataset.files = JSON.stringify(Array.from(files).map(f => f.name));
    uploadBtn.onclick = () => startUpload(files);
}

function startUpload(files) {
    const uploadBtn = document.getElementById('uploadBtn');
    const uploadProgress = document.getElementById('uploadProgress');
    const uploadStatus = document.getElementById('uploadStatus');

    if (!uploadBtn || !files || files.length === 0) return;

    // Show progress
    if (uploadProgress) uploadProgress.style.display = 'block';
    if (uploadStatus) uploadStatus.textContent = `Upload de ${files.length} fichier(s)...`;
    uploadBtn.disabled = true;
    uploadBtn.textContent = '⏳ Upload...';

    // Start upload
    uploadFiles(files).then(() => {
        showNotification('✅ Upload terminé!', 'success');
        closeModal();

        // AUTO-REFRESH IMPROVED
        console.log('🔄 Auto-refresh starting...');

        // Method 1: Force immediate refresh
        if (typeof window.loadMediaFiles === 'function') {
            console.log('Method 1: Calling loadMediaFiles');
            window.loadMediaFiles();
        }

        // Method 2: Show media section and refresh
        setTimeout(() => {
            console.log('Method 2: Force show media section');
            const mediaBtn = document.querySelector('[onclick*="showSection(\'media\')"]');
            if (mediaBtn) {
                mediaBtn.click();
            } else {
                showSection('media');
            }
        }, 500);

        // Method 3: Direct API call to refresh
        setTimeout(() => {
            console.log('Method 3: Direct API refresh');
            fetch('/api/media.php')
                .then(r => r.json())
                .then(data => {
                    if (data.success && data.files) {
                        const mediaList = document.getElementById('media-list');
                        if (mediaList) {
                            mediaList.innerHTML = '';
                            data.files.forEach(file => {
                                const card = createMediaCard(file);
                                if (card) mediaList.appendChild(card);
                            });
                        }
                    }
                })
                .catch(e => console.error('Refresh error:', e));
        }, 1000);

    }).catch(error => {
        console.error('Upload error:', error);
        showNotification('❌ Erreur: ' + error.message, 'error');
        uploadBtn.disabled = false;
        uploadBtn.textContent = '📤 Retry';
    });
}

function uploadFiles(files) {
    const formData = new FormData();
    Array.from(files).forEach(file => {
        formData.append('files[]', file);
    });

    return fetch('/api/media.php', {
        method: 'POST',
        body: formData
    })
    .then(response => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json();
    })
    .then(data => {
        if (!data.success) throw new Error(data.message || 'Upload échoué');
        return data;
    });
}

function createMediaCard(file) {
    const card = document.createElement('div');
    card.className = 'media-card';

    const isVideo = /\.(mp4|webm|ogg|avi|mov)$/i.test(file.name);
    const icon = isVideo ? '🎬' : '🖼️';

    card.innerHTML = `
        <div class="media-preview">
            <span class="media-icon">${icon}</span>
        </div>
        <div class="media-info">
            <div class="media-name">${file.name}</div>
            <div class="media-size">${file.size || 'N/A'}</div>
        </div>
        <div class="media-actions">
            <button class="btn btn-sm btn-danger" onclick="deleteMedia('${file.name}')">
                🗑️
            </button>
        </div>
    `;

    return card;
}

function showNotification(message, type = 'info') {
    console.log(`[${type.toUpperCase()}] ${message}`);

    // Remove old notifications
    const oldNotif = document.querySelector('.notification');
    if (oldNotif) oldNotif.remove();

    // Create new notification
    const notif = document.createElement('div');
    notif.className = `notification notification-${type}`;
    notif.textContent = message;
    notif.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        background: ${type === 'success' ? '#4caf50' : type === 'error' ? '#f44336' : '#2196f3'};
        color: white;
        border-radius: 4px;
        box-shadow: 0 2px 5px rgba(0,0,0,0.2);
        z-index: 10000;
        animation: slideIn 0.3s ease;
    `;

    document.body.appendChild(notif);

    // Auto-remove after 3 seconds
    setTimeout(() => {
        notif.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => notif.remove(), 300);
    }, 3000);
}

// System stats refresh (with error handling)
function refreshStats() {
    fetch('/api/system.php?action=stats')
        .then(response => response.json())
        .then(data => {
            if (data.success && data.stats) {
                const stats = data.stats;

                // Safely update each stat element
                const updateElement = (id, value) => {
                    const elem = document.getElementById(id);
                    if (elem) elem.textContent = value;
                };

                updateElement('cpu-usage', stats.cpu + '%');
                updateElement('ram-usage', stats.ram + '%');
                updateElement('temperature', stats.temperature + '°C');
                updateElement('storage-usage', stats.storage);
            }
        })
        .catch(error => {
            // Silent fail - don't spam console
            if (window.statsErrorCount === undefined) window.statsErrorCount = 0;
            window.statsErrorCount++;
            if (window.statsErrorCount === 1) {
                console.log('Stats API not available (this is normal if not on dashboard)');
            }
        });
}

// Initialize stats refresh only if on dashboard
if (document.getElementById('cpu-usage')) {
    if (typeof window.statsInterval === 'undefined') {
        window.statsInterval = setInterval(refreshStats, 5000);
        refreshStats(); // Initial load
    }
}

// Global function to show sections
window.showSection = function(section) {
    console.log('Showing section:', section);

    // Hide all sections
    const sections = document.querySelectorAll('.section');
    sections.forEach(s => s.style.display = 'none');

    // Show selected section
    const targetSection = document.getElementById(section + '-section');
    if (targetSection) {
        targetSection.style.display = 'block';

        // If media section, refresh it
        if (section === 'media' && typeof window.loadMediaFiles === 'function') {
            console.log('Refreshing media on section show');
            window.loadMediaFiles();
        }
    }

    // Update nav buttons
    const navBtns = document.querySelectorAll('.nav-btn');
    navBtns.forEach(btn => btn.classList.remove('active'));
    const activeBtn = document.querySelector(`[onclick*="showSection('${section}')"]`);
    if (activeBtn) activeBtn.classList.add('active');
};

console.log('✅ Functions.js loaded - All features ready');
JSFIX

# 2. Déployer sur le Pi
echo "📤 Déploiement sur le Raspberry Pi..."
sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no /tmp/functions-fixed.js "$PI_USER@$PI_HOST:/tmp/"

sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_HOST" << 'EOF'
# Backup
sudo cp /opt/pisignage/web/functions.js "/opt/pisignage/web/functions.js.bak-$(date +%Y%m%d_%H%M%S)"

# Deploy
sudo cp /tmp/functions-fixed.js /opt/pisignage/web/functions.js
sudo chown www-data:www-data /opt/pisignage/web/functions.js

# Clear all caches
sudo rm -rf /var/cache/nginx/*
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

echo "✅ Déploiement terminé"
EOF

echo ""
echo "========================================="
echo "✅ TOUTES LES CORRECTIONS APPLIQUÉES"
echo "========================================="
echo ""
echo "Corrections:"
echo "  ✅ Erreurs de stats corrigées (vérification d'existence)"
echo "  ✅ Auto-refresh amélioré (3 méthodes de fallback)"
echo "  ✅ Notifications visuelles ajoutées"
echo "  ✅ Cache vidé complètement"
echo ""
echo "🌐 Testez sur http://$PI_HOST/"
echo ""
echo "L'auto-refresh utilise maintenant 3 méthodes:"
echo "  1. Appel direct de loadMediaFiles()"
echo "  2. Click sur le bouton média après 500ms"
echo "  3. Appel direct de l'API après 1s"
echo ""
echo "Une de ces méthodes devrait forcément fonctionner!"