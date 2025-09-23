// PiSignage v0.8.0 - Missing Functions
// Functions to complete the interface functionality

// Create playlist function
function createPlaylist() {
    const name = prompt('Nom de la nouvelle playlist:');
    if (!name) {
        console.log('Création annulée - pas de nom');
        return;
    }

    // Get selected media files (if any)
    const selectedFiles = Array.from(document.querySelectorAll('.media-item input[type="checkbox"]:checked'))
        .map(cb => cb.value);

    console.log('Creating playlist:', name, 'with files:', selectedFiles);

    fetch('/api/playlist.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            name: name,
            items: selectedFiles || [],
            description: 'Playlist créée via interface web'
        })
    })
    .then(response => response.json())
    .then(data => {
        console.log('Create playlist response:', data);
        if (data.success) {
            alert('Playlist "' + name + '" créée avec succès!');
            if (typeof loadPlaylists === 'function') {
                loadPlaylists();
            }
            location.reload(); // Refresh page to show new playlist
        } else {
            alert('Erreur: ' + (data.message || 'Impossible de créer la playlist'));
        }
    })
    .catch(error => {
        console.error('Create playlist error:', error);
        alert('Erreur de création: ' + error.message);
    });
}

// Download YouTube video
function downloadYouTube() {
    const url = document.getElementById('youtube-url').value;
    const quality = document.getElementById('download-quality')?.value || 'best';
    const compression = document.getElementById('enable-compression')?.checked || false;

    if (!url) {
        showNotification('Veuillez entrer une URL YouTube', 'warning');
        return;
    }

    // Show progress
    const progressDiv = document.getElementById('download-progress');
    if (progressDiv) {
        progressDiv.style.display = 'block';
        progressDiv.innerHTML = '<div class="progress-bar">Téléchargement en cours...</div>';
    }

    fetch('/api/youtube.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            url: url,
            quality: quality,
            compression: compression
        })
    })
    .then(response => response.json())
    .then(data => {
        if (progressDiv) {
            progressDiv.style.display = 'none';
        }

        if (data.success) {
            showNotification('Vidéo téléchargée avec succès', 'success');
            document.getElementById('youtube-url').value = '';
            refreshMediaList();
        } else {
            showNotification('Erreur: ' + data.message, 'error');
        }
    })
    .catch(error => {
        if (progressDiv) {
            progressDiv.style.display = 'none';
        }
        showNotification('Erreur de téléchargement: ' + error, 'error');
    });
}

// Manual screenshot capture
function captureManual() {
    const btn = event.target;
    btn.disabled = true;
    btn.textContent = 'Capture en cours...';

    fetch('/api/screenshot.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'capture' })
    })
    .then(response => response.json())
    .then(data => {
        btn.disabled = false;
        btn.textContent = '📸 Capture manuelle';

        if (data.success && data.data) {
            // Update preview if exists
            const preview = document.getElementById('screenshot-preview');
            if (preview) {
                preview.src = data.data + '?t=' + Date.now();
            }
            showNotification('Capture réussie', 'success');
        } else {
            showNotification('Erreur de capture: ' + (data.message || 'Erreur inconnue'), 'error');
        }
    })
    .catch(error => {
        btn.disabled = false;
        btn.textContent = '📸 Capture manuelle';
        showNotification('Erreur: ' + error, 'error');
    });
}

// Show upload modal
function showUploadModal() {
    // Remove existing modal if any
    const existingModal = document.getElementById('uploadModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Create modal HTML
    const modalHTML = `
        <div id="uploadModal" class="modal" style="display: block; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.5);">
            <div class="modal-content" style="background-color: #fefefe; margin: 15% auto; padding: 20px; border: 1px solid #888; width: 80%; max-width: 500px; border-radius: 10px;">
                <div class="modal-header">
                    <h4>📁 Upload Media Files</h4>
                    <span class="close" style="color: #aaa; float: right; font-size: 28px; font-weight: bold; cursor: pointer;">&times;</span>
                </div>
                <div class="modal-body">
                    <p>Sélectionnez les fichiers à uploader:</p>
                    <input type="file" id="fileInput" multiple accept="video/*,image/*,audio/*" style="width: 100%; padding: 10px; margin: 10px 0; border: 2px dashed #ccc; border-radius: 5px;">
                    <div id="uploadProgress" style="display: none;">
                        <p>Upload en cours...</p>
                        <div style="width: 100%; background-color: #f0f0f0; border-radius: 5px;">
                            <div id="progressBar" style="width: 0%; height: 20px; background-color: #4CAF50; border-radius: 5px; transition: width 0.3s;"></div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer" style="text-align: right; margin-top: 20px;">
                    <button id="cancelUpload" class="btn btn-secondary" style="margin-right: 10px; padding: 8px 16px; border: none; border-radius: 4px; background-color: #6c757d; color: white; cursor: pointer;">Annuler</button>
                    <button id="startUpload" class="btn btn-primary" style="padding: 8px 16px; border: none; border-radius: 4px; background-color: #007bff; color: white; cursor: pointer;">Upload</button>
                </div>
            </div>
        </div>
    `;

    // Add modal to page
    document.body.insertAdjacentHTML('beforeend', modalHTML);

    // Add event listeners
    const modal = document.getElementById('uploadModal');
    const closeBtn = modal.querySelector('.close');
    const cancelBtn = document.getElementById('cancelUpload');
    const uploadBtn = document.getElementById('startUpload');
    const fileInput = document.getElementById('fileInput');

    // Close modal function
    function closeModal() {
        modal.remove();
    }

    // Event listeners
    closeBtn.onclick = closeModal;
    cancelBtn.onclick = closeModal;
    modal.onclick = function(event) {
        if (event.target === modal) {
            closeModal();
        }
    };

    // Upload button click
    uploadBtn.onclick = function() {
        const files = fileInput.files;
        if (files.length === 0) {
            alert('Veuillez sélectionner au moins un fichier');
            return;
        }

        // Show progress
        document.getElementById('uploadProgress').style.display = 'block';
        uploadBtn.disabled = true;
        uploadBtn.textContent = 'Upload...';

        // Start upload
        uploadFiles(files).then(() => {
            showNotification('Upload terminé avec succès!', 'success');
            closeModal();
            refreshMediaList();
        }).catch(error => {
            showNotification('Erreur upload: ' + error.message, 'error');
            document.getElementById('uploadProgress').style.display = 'none';
            uploadBtn.disabled = false;
            uploadBtn.textContent = 'Upload';
        });
    };
}

// Upload multiple files with progress
function uploadFiles(files) {
    return new Promise((resolve, reject) => {
        const formData = new FormData();

        for (let file of files) {
            formData.append('files[]', file);
        }

        const xhr = new XMLHttpRequest();

        // Progress handler
        xhr.upload.addEventListener('progress', function(e) {
            if (e.lengthComputable) {
                const percentComplete = (e.loaded / e.total) * 100;
                const progressBar = document.getElementById('progressBar');
                if (progressBar) {
                    progressBar.style.width = percentComplete + '%';
                }
            }
        });

        xhr.onload = function() {
            if (xhr.status === 200) {
                try {
                    const data = JSON.parse(xhr.responseText);
                    if (data.success) {
                        resolve(data);
                    } else {
                        reject(new Error(data.message || 'Upload failed'));
                    }
                } catch (e) {
                    reject(new Error('Invalid response format'));
                }
            } else {
                reject(new Error('HTTP ' + xhr.status));
            }
        };

        xhr.onerror = function() {
            reject(new Error('Network error'));
        };

        xhr.open('POST', '/api/upload.php');
        xhr.send(formData);
    });
}

// Wrapper for uploadFiles to match expected function name
function uploadFile(files) {
    if (typeof uploadFiles === 'function') {
        return uploadFiles(files);
    }

    // Fallback implementation
    const formData = new FormData();

    for (let file of files) {
        formData.append('files[]', file);
    }

    fetch('/api/upload.php', {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showNotification('Upload réussi', 'success');
            refreshMediaList();
        } else {
            showNotification('Erreur: ' + data.message, 'error');
        }
    })
    .catch(error => {
        showNotification('Erreur upload: ' + error, 'error');
    });
}

// Helper function for notifications
function showNotification(message, type = 'info') {
    // Check if a notification system exists
    if (typeof window.showNotification === 'function') {
        return window.showNotification(message, type);
    }

    // Fallback to console
    console.log(`[${type.toUpperCase()}] ${message}`);

    // Try to show in a toast or alert
    if (type === 'error') {
        console.error(message);
    } else if (type === 'success') {
        console.log('✅', message);
    }
}

// Refresh functions
function refreshPlaylists() {
    if (typeof loadPlaylists === 'function') {
        loadPlaylists();
    } else {
        // Reload playlist section
        fetch('/api/playlist.php?action=list')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    console.log('Playlists refreshed:', data.data.length);
                }
            });
    }
}

function refreshMediaList() {
    if (typeof loadMediaList === 'function') {
        loadMediaList();
    } else {
        // Reload media section
        fetch('/api/media.php?action=list')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    console.log('Media refreshed:', data.data.length);
                }
            });
    }
}

// Auto-init when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    console.log('✅ Additional functions loaded for PiSignage v0.8.0');
});