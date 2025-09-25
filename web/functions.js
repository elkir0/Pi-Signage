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
                    <div id="fileSelectArea" style="border: 3px dashed #007bff; border-radius: 10px; padding: 30px; text-align: center; background-color: #f8f9fa; cursor: pointer; margin: 20px 0;">
                        <h4 style="color: #007bff; margin-bottom: 15px;">📁 Cliquez ici pour sélectionner vos fichiers</h4>
                        <p style="margin-bottom: 10px; color: #6c757d;">Ou glissez-déposez vos fichiers ici</p>
                        <p style="font-size: 12px; color: #6c757d;">Formats supportés: MP4, AVI, JPG, PNG, MP3, etc.</p>
                        <input type="file" id="fileInput" multiple accept="video/*,image/*,audio/*" style="display: none;">
                    </div>
                    <div id="selectedFiles" style="margin-top: 15px; display: none;">
                        <h5>📋 Fichiers sélectionnés:</h5>
                        <ul id="filesList" style="list-style: none; padding: 0;"></ul>
                    </div>
                    <div id="uploadProgress" style="display: none; margin-top: 20px;">
                        <p><strong>⏳ Upload en cours...</strong></p>
                        <div style="width: 100%; background-color: #e9ecef; border-radius: 10px; overflow: hidden;">
                            <div id="progressBar" style="width: 0%; height: 25px; background: linear-gradient(90deg, #007bff, #0056b3); color: white; text-align: center; line-height: 25px; transition: width 0.3s; font-weight: bold;"></div>
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

    // File selection area click
    const fileSelectArea = document.getElementById('fileSelectArea');
    fileSelectArea.onclick = function() {
        fileInput.click();
    };

    // Drag and drop events
    fileSelectArea.ondragover = function(e) {
        e.preventDefault();
        fileSelectArea.style.backgroundColor = '#e3f2fd';
        fileSelectArea.style.borderColor = '#2196f3';
    };

    fileSelectArea.ondragleave = function(e) {
        e.preventDefault();
        fileSelectArea.style.backgroundColor = '#f8f9fa';
        fileSelectArea.style.borderColor = '#007bff';
    };

    fileSelectArea.ondrop = function(e) {
        e.preventDefault();
        fileSelectArea.style.backgroundColor = '#f8f9fa';
        fileSelectArea.style.borderColor = '#007bff';

        const droppedFiles = e.dataTransfer.files;
        if (droppedFiles.length > 0) {
            // Update the file input with dropped files
            fileInput.files = droppedFiles;
            updateSelectedFilesList();
        }
    };

    // File input change event
    fileInput.onchange = function() {
        updateSelectedFilesList();
    };

    function updateSelectedFilesList() {
        const files = fileInput.files;
        const selectedFilesDiv = document.getElementById('selectedFiles');
        const filesList = document.getElementById('filesList');

        if (files.length > 0) {
            selectedFilesDiv.style.display = 'block';
            filesList.innerHTML = '';

            for (let i = 0; i < files.length; i++) {
                const file = files[i];
                const li = document.createElement('li');
                li.style.cssText = 'padding: 8px; margin: 5px 0; background-color: #e9ecef; border-radius: 5px; display: flex; justify-content: space-between; align-items: center;';

                const fileInfo = document.createElement('span');
                fileInfo.textContent = `📄 ${file.name} (${formatFileSize(file.size)})`;

                const removeBtn = document.createElement('button');
                removeBtn.textContent = '❌';
                removeBtn.style.cssText = 'background: none; border: none; cursor: pointer; font-size: 16px; color: #dc3545;';
                removeBtn.onclick = function() {
                    removeFileFromSelection(i);
                };

                li.appendChild(fileInfo);
                li.appendChild(removeBtn);
                filesList.appendChild(li);
            }

            // Update the file select area text
            fileSelectArea.innerHTML = `
                <h4 style="color: #28a745; margin-bottom: 15px;">✅ ${files.length} fichier(s) sélectionné(s)</h4>
                <p style="margin-bottom: 10px; color: #6c757d;">Cliquez pour changer la sélection</p>
                <p style="font-size: 12px; color: #6c757d;">Ou glissez-déposez d'autres fichiers</p>
                <input type="file" id="fileInput" multiple accept="video/*,image/*,audio/*" style="display: none;">
            `;
        } else {
            selectedFilesDiv.style.display = 'none';
        }
    }

    function formatFileSize(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    function removeFileFromSelection(index) {
        const dt = new DataTransfer();
        const files = fileInput.files;

        for (let i = 0; i < files.length; i++) {
            if (i !== index) {
                dt.items.add(files[i]);
            }
        }

        fileInput.files = dt.files;
        updateSelectedFilesList();
    }

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

// ========== DUAL PLAYER CONTROL FUNCTIONS ==========

// Get current player
function getCurrentPlayer() {
    return fetch('/api/player.php?action=current')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                return data.current_player;
            }
            return 'mpv'; // default
        })
        .catch(error => {
            console.error('Error getting current player:', error);
            return 'mpv';
        });
}

// Switch between VLC and MPV
function switchPlayer() {
    fetch('/api/player.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'switch' })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showNotification('Player basculé: ' + data.message, 'success');
            // Update interface
            updatePlayerInterface();
        } else {
            showNotification('Erreur: ' + data.message, 'error');
        }
    })
    .catch(error => {
        showNotification('Erreur de basculement: ' + error, 'error');
    });
}

// Unified player control function
function playerControl(action, value = null) {
    const body = { action: action };
    if (value !== null) {
        body.value = value;
    }

    fetch('/api/player.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    })
    .then(response => response.json())
    .then(data => {
        const statusDiv = document.getElementById('player-status');
        if (statusDiv) {
            statusDiv.textContent = data.message || action + ' completed';
        }

        if (data.success) {
            showNotification('Action réussie: ' + action, 'success');
        } else {
            showNotification('Erreur: ' + data.message, 'error');
        }

        // Update player status
        updatePlayerStatus();
    })
    .catch(error => {
        showNotification('Erreur de contrôle: ' + error, 'error');
    });
}

// Update player interface to reflect current player
function updatePlayerInterface() {
    getCurrentPlayer().then(currentPlayer => {
        // Update radio buttons
        const mpvRadio = document.getElementById('player-mpv');
        const vlcRadio = document.getElementById('player-vlc');

        if (mpvRadio && vlcRadio) {
            mpvRadio.checked = (currentPlayer === 'mpv');
            vlcRadio.checked = (currentPlayer === 'vlc');
        }

        // Update status display
        const statusDiv = document.getElementById('current-player');
        if (statusDiv) {
            statusDiv.textContent = currentPlayer.toUpperCase();
        }
    });
}

// Update player status
function updatePlayerStatus() {
    fetch('/api/player.php')
        .then(response => response.json())
        .then(data => {
            const statusDiv = document.getElementById('player-status');
            if (statusDiv && data.status) {
                statusDiv.textContent = data.status;
                statusDiv.className = data.running ? 'status-running' : 'status-stopped';
            }
        })
        .catch(error => {
            console.error('Error updating player status:', error);
        });
}

// Play specific file
function playFile(filename) {
    fetch('/api/player.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            action: 'play-file',
            file: filename
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showNotification('Lecture de: ' + filename, 'success');
        } else {
            showNotification('Erreur: ' + data.message, 'error');
        }
    });
}

// Volume control
function setVolume(volume) {
    playerControl('volume', parseInt(volume));
}

// ========== LEGACY FUNCTIONS COMPATIBILITY ==========

// Legacy MPV control function (for backward compatibility)
function mpvControl(action, value = null) {
    return playerControl(action, value);
}

// Quick screenshot function
function takeQuickScreenshot(section) {
    const btn = event.target;
    const originalText = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'Capture...';

    fetch('/api/screenshot.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'capture' })
    })
    .then(response => response.json())
    .then(data => {
        btn.disabled = false;
        btn.textContent = originalText;

        if (data.success) {
            showNotification('Capture réussie', 'success');
        } else {
            showNotification('Erreur: ' + data.message, 'error');
        }
    })
    .catch(error => {
        btn.disabled = false;
        btn.textContent = originalText;
        showNotification('Erreur: ' + error, 'error');
    });
}

// ========== NAVIGATION AND UI FUNCTIONS ==========

// Show section navigation
function showSection(sectionName) {
    // Hide all sections
    const sections = document.querySelectorAll('.content-section');
    sections.forEach(section => {
        section.classList.remove('active');
    });

    // Show target section
    const targetSection = document.getElementById(sectionName);
    if (targetSection) {
        targetSection.classList.add('active');
    }

    // Update navigation
    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
        item.classList.remove('active');
    });

    // Find and activate current nav item
    const currentNav = Array.from(navItems).find(item =>
        item.getAttribute('onclick') && item.getAttribute('onclick').includes(sectionName)
    );
    if (currentNav) {
        currentNav.classList.add('active');
    }

    // Load section-specific data
    if (sectionName === 'player') {
        updatePlayerInterface();
        updatePlayerStatus();
    }
}

// Toggle sidebar for mobile
function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    if (sidebar) {
        sidebar.classList.toggle('show');
    }
}

// Refresh system stats
function refreshStats() {
    fetch('/api/system.php?action=stats')
        .then(response => response.json())
        .then(data => {
            if (data.success && data.data) {
                const stats = data.data;
                document.getElementById('cpu-usage').textContent = stats.cpu || '--';
                document.getElementById('ram-usage').textContent = stats.ram || '--';
                document.getElementById('temperature').textContent = stats.temperature || '--';
            }
        })
        .catch(error => {
            console.error('Error refreshing stats:', error);
        });
}

// Auto-init when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    console.log('✅ PiSignage v0.8.0 - Dual Player Functions loaded');

    // Initialize player interface if on player section
    if (document.getElementById('player')) {
        updatePlayerInterface();
        updatePlayerStatus();
    }

    // Auto-refresh player status every 10 seconds
    setInterval(updatePlayerStatus, 10000);

    // Auto-refresh stats every 5 seconds
    setInterval(refreshStats, 5000);
});