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