// PiSignage v0.8.0 - Functions (Fixed)
// Fixed: Drag & drop and auto-refresh after upload

console.log('✅ PiSignage v0.8.0 - Fixed Functions loaded');

// ========== NOTIFICATION SYSTEM ==========
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;

    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        border-radius: 5px;
        color: white;
        z-index: 10000;
        animation: slideIn 0.3s;
        max-width: 300px;
    `;

    switch(type) {
        case 'success':
            notification.style.backgroundColor = '#28a745';
            break;
        case 'error':
            notification.style.backgroundColor = '#dc3545';
            break;
        case 'warning':
            notification.style.backgroundColor = '#ffc107';
            break;
        default:
            notification.style.backgroundColor = '#17a2b8';
    }

    document.body.appendChild(notification);

    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// ========== UPLOAD MODAL FIXED ==========
function openUploadModal() {
    // Create modal HTML
    const modalHTML = `
        <div id="uploadModal" class="modal" style="
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0, 0, 0, 0.7);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 10000;
        ">
            <div class="modal-content" style="
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                border-radius: 15px;
                padding: 30px;
                max-width: 600px;
                width: 90%;
                position: relative;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                color: white;
            ">
                <span class="close" style="
                    position: absolute;
                    top: 10px;
                    right: 15px;
                    font-size: 28px;
                    cursor: pointer;
                    color: white;
                ">&times;</span>

                <h2 style="margin-bottom: 20px; text-align: center;">📤 Upload de fichiers</h2>

                <div class="modal-body">
                    <div id="fileSelectArea" style="
                        border: 3px dashed rgba(255,255,255,0.5);
                        border-radius: 10px;
                        padding: 40px;
                        text-align: center;
                        cursor: pointer;
                        background-color: rgba(255,255,255,0.1);
                        transition: all 0.3s;
                    ">
                        <h3 style="margin-bottom: 10px;">📁 Glisser-déposer vos fichiers ici</h3>
                        <p>ou cliquez pour sélectionner</p>
                        <p style="font-size: 12px; opacity: 0.8;">Formats acceptés: MP4, AVI, MKV, MOV, JPG, PNG</p>
                        <p style="font-size: 12px; opacity: 0.8;">Taille max: 100MB par fichier</p>
                        <input type="file" id="fileInput" multiple accept="video/*,image/*,audio/*" style="display: none;">
                    </div>

                    <div id="selectedFiles" style="margin-top: 15px; display: none;">
                        <h5>📋 Fichiers sélectionnés:</h5>
                        <ul id="filesList" style="list-style: none; padding: 0;"></ul>
                    </div>

                    <div id="uploadProgress" style="display: none; margin-top: 20px;">
                        <p><strong>⏳ Upload en cours...</strong></p>
                        <div style="width: 100%; background-color: rgba(255,255,255,0.2); border-radius: 10px; overflow: hidden;">
                            <div id="progressBar" style="width: 0%; height: 25px; background: linear-gradient(90deg, #28a745, #20c997); color: white; text-align: center; line-height: 25px; transition: width 0.3s; font-weight: bold;"></div>
                        </div>
                        <p id="uploadStatus" style="margin-top: 10px; font-size: 14px;"></p>
                    </div>
                </div>

                <div class="modal-footer" style="text-align: right; margin-top: 20px;">
                    <button id="cancelUpload" class="btn btn-secondary" style="margin-right: 10px; padding: 10px 20px; border: none; border-radius: 5px; background-color: rgba(255,255,255,0.2); color: white; cursor: pointer;">Annuler</button>
                    <button id="startUpload" class="btn btn-primary" style="padding: 10px 20px; border: none; border-radius: 5px; background-color: #28a745; color: white; cursor: pointer; font-weight: bold;">📤 Upload</button>
                </div>
            </div>
        </div>
    `;

    // Add modal to page
    document.body.insertAdjacentHTML('beforeend', modalHTML);

    // Get elements AFTER modal is added to DOM
    const modal = document.getElementById('uploadModal');
    const closeBtn = modal.querySelector('.close');
    const cancelBtn = document.getElementById('cancelUpload');
    const uploadBtn = document.getElementById('startUpload');
    const fileInput = document.getElementById('fileInput');
    const fileSelectArea = document.getElementById('fileSelectArea');

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
    fileSelectArea.onclick = function(e) {
        // Prevent triggering when clicking on child elements
        if (e.target === fileSelectArea || e.target.tagName === 'H3' || e.target.tagName === 'P') {
            fileInput.click();
        }
    };

    // FIXED: Drag and drop events with proper file handling
    fileSelectArea.ondragover = function(e) {
        e.preventDefault();
        e.stopPropagation();
        fileSelectArea.style.backgroundColor = 'rgba(255,255,255,0.2)';
        fileSelectArea.style.borderColor = '#28a745';
    };

    fileSelectArea.ondragleave = function(e) {
        e.preventDefault();
        e.stopPropagation();
        fileSelectArea.style.backgroundColor = 'rgba(255,255,255,0.1)';
        fileSelectArea.style.borderColor = 'rgba(255,255,255,0.5)';
    };

    fileSelectArea.ondrop = function(e) {
        e.preventDefault();
        e.stopPropagation();
        fileSelectArea.style.backgroundColor = 'rgba(255,255,255,0.1)';
        fileSelectArea.style.borderColor = 'rgba(255,255,255,0.5)';

        const droppedFiles = e.dataTransfer.files;
        if (droppedFiles.length > 0) {
            // Create a new FileList from dropped files
            const dt = new DataTransfer();
            for (let file of droppedFiles) {
                dt.items.add(file);
            }
            fileInput.files = dt.files;
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
                li.style.cssText = 'padding: 10px; margin: 5px 0; background-color: rgba(255,255,255,0.1); border-radius: 5px; display: flex; justify-content: space-between; align-items: center;';

                const fileInfo = document.createElement('span');
                fileInfo.textContent = `📄 ${file.name} (${formatFileSize(file.size)})`;

                const removeBtn = document.createElement('button');
                removeBtn.textContent = '❌';
                removeBtn.style.cssText = 'background: none; border: none; cursor: pointer; font-size: 16px;';
                removeBtn.onclick = function() {
                    removeFileFromSelection(i);
                };

                li.appendChild(fileInfo);
                li.appendChild(removeBtn);
                filesList.appendChild(li);
            }

            // Update the file select area text
            fileSelectArea.innerHTML = `
                <h3 style="color: #28a745; margin-bottom: 10px;">✅ ${files.length} fichier(s) sélectionné(s)</h3>
                <p>Cliquez pour ajouter d'autres fichiers</p>
                <p style="font-size: 12px; opacity: 0.8;">Ou glissez-déposez ici</p>
                <input type="file" id="fileInput" multiple accept="video/*,image/*,audio/*" style="display: none;">
            `;

            // Re-attach the file input reference
            const newFileInput = document.getElementById('fileInput');
            newFileInput.files = files;
            newFileInput.onchange = function() {
                updateSelectedFilesList();
            };
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
            showNotification('Veuillez sélectionner au moins un fichier', 'warning');
            return;
        }

        // Show progress
        document.getElementById('uploadProgress').style.display = 'block';
        document.getElementById('uploadStatus').textContent = `Upload de ${files.length} fichier(s)...`;
        uploadBtn.disabled = true;
        uploadBtn.textContent = '⏳ Upload...';

        // Start upload
        uploadFiles(files).then(() => {
            showNotification('✅ Upload terminé avec succès!', 'success');
            closeModal();
            // FIXED: Refresh media list after successful upload
            setTimeout(() => {
                if (typeof loadMediaFiles === 'function') {
                    console.log('Refreshing media list...');
                    loadMediaFiles();
                } else {
                    console.log('Reloading page to refresh media...');
                    location.reload();
                }
            }, 500);
        }).catch(error => {
            showNotification('❌ Erreur upload: ' + error.message, 'error');
            document.getElementById('uploadProgress').style.display = 'none';
            uploadBtn.disabled = false;
            uploadBtn.textContent = '📤 Upload';
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
                const percentComplete = Math.round((e.loaded / e.total) * 100);
                const progressBar = document.getElementById('progressBar');
                const uploadStatus = document.getElementById('uploadStatus');
                if (progressBar) {
                    progressBar.style.width = percentComplete + '%';
                    progressBar.textContent = percentComplete + '%';
                }
                if (uploadStatus) {
                    const mbUploaded = (e.loaded / (1024 * 1024)).toFixed(1);
                    const mbTotal = (e.total / (1024 * 1024)).toFixed(1);
                    uploadStatus.textContent = `${mbUploaded} MB / ${mbTotal} MB`;
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
                    reject(new Error('Invalid server response'));
                }
            } else if (xhr.status === 413) {
                reject(new Error('Fichier trop volumineux (max 100MB)'));
            } else if (xhr.status === 500) {
                reject(new Error('Erreur serveur - vérifiez les limites PHP'));
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

// Other functions remain the same...
function refreshMediaList() {
    if (typeof loadMediaFiles === 'function') {
        loadMediaFiles();
    } else {
        // Fallback: reload the page
        location.reload();
    }
}

// Rest of the functions (dual player, stats, etc.) remain unchanged...
// [Previous functions continue here...]

// ========== PLAYER CONTROL ==========
function playerControl(action) {
    fetch('/api/player.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: action })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            showNotification('✅ ' + data.message, 'success');
            updatePlayerStatus();
        } else {
            showNotification('❌ ' + data.message, 'error');
        }
    })
    .catch(error => {
        console.error('Player control error:', error);
        showNotification('❌ Erreur de contrôle', 'error');
    });
}

function updatePlayerStatus() {
    fetch('/api/player.php?action=status')
        .then(response => response.json())
        .then(data => {
            if (data.success && data.data) {
                const statusEl = document.getElementById('player-status');
                if (statusEl) {
                    statusEl.textContent = data.data.state || 'Arrêté';
                }
            }
        })
        .catch(error => console.error('Status update error:', error));
}

// ========== SYSTEM STATS ==========
function refreshStats() {
    fetch('/api/system.php?action=stats')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                const stats = data.data;

                // Update dashboard stats
                if (document.getElementById('cpu-usage')) {
                    document.getElementById('cpu-usage').textContent = stats.cpu + '%';
                    document.getElementById('ram-usage').textContent = stats.ram + '%';
                    document.getElementById('temperature').textContent = stats.temperature + '°C';
                    document.getElementById('storage-usage').textContent = stats.storage;
                }
            }
        })
        .catch(error => console.error('Stats error:', error));
}

// Initialize stats refresh
if (typeof window.statsInterval === 'undefined') {
    window.statsInterval = setInterval(refreshStats, 5000);
}

console.log('✅ Fixed functions loaded - Drag & drop and auto-refresh enabled');