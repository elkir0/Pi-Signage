/**
 * PiSignage Media Management Module
 * Handles media file operations, upload, delete, and display
 */

// Ensure PiSignage namespace exists
window.PiSignage = window.PiSignage || {};

// Media management functionality
PiSignage.media = {
    currentFiles: [],
    uploadInProgress: false,

    init: function() {
        console.log('📁 Initializing media management...');
        this.loadMediaFiles();
        this.setupUploadHandlers();
        this.setupEventListeners();
    },

    loadMediaFiles: async function() {
        try {
            const data = await PiSignage.api.media.list();
            if (data.success) {
                this.currentFiles = data.data || [];
                this.renderMediaList();
                this.updateFileSelects();
                console.log(`📁 Loaded ${this.currentFiles.length} media files`);
            } else {
                console.error('Failed to load media files:', data.message);
            }
        } catch (error) {
            console.error('Error loading media files:', error);
            showAlert('Erreur de chargement des fichiers', 'error');
        }
    },

    renderMediaList: function() {
        const container = document.getElementById('media-list');
        if (!container) return;

        if (this.currentFiles.length === 0) {
            container.innerHTML = `
                <div class="empty-state" style="text-align: center; padding: 40px; color: #666;">
                    <h3>📂 Aucun fichier média</h3>
                    <p>Commencez par uploader des fichiers vidéo, audio ou image</p>
                </div>
            `;
            return;
        }

        container.innerHTML = '';

        this.currentFiles.forEach(file => {
            const card = document.createElement('div');
            card.className = 'card media-file-card';
            card.innerHTML = `
                <div style="display: flex; align-items: center; margin-bottom: 10px;">
                    <input type="checkbox" id="media-${file.name}" value="${file.name}" style="margin-right: 10px;">
                    <h4 style="margin: 0; flex: 1;" title="${file.name}">${this.truncateFilename(file.name)}</h4>
                </div>
                <div class="file-info">
                    <p><strong>Taille:</strong> ${(file.size / 1024 / 1024).toFixed(2)} MB</p>
                    <p><strong>Type:</strong> ${file.type}</p>
                    ${file.duration ? `<p><strong>Durée:</strong> ${this.formatDuration(file.duration)}</p>` : ''}
                </div>
                <div class="file-actions" style="margin-top: 15px;">
                    <button class="btn btn-primary btn-sm" onclick="PiSignage.media.playFile('${file.name}')" title="Lire ce fichier">
                        ▶️ Lire
                    </button>
                    <button class="btn btn-danger btn-sm" onclick="PiSignage.media.deleteFile('${file.name}')" title="Supprimer ce fichier">
                        🗑️ Supprimer
                    </button>
                </div>
            `;
            container.appendChild(card);
        });
    },

    updateFileSelects: function() {
        // Update single file select dropdown
        const fileSelect = document.getElementById('single-file-select');
        if (fileSelect) {
            fileSelect.innerHTML = '<option value="">-- Choisir --</option>';
            this.currentFiles.forEach(file => {
                const option = document.createElement('option');
                option.value = file.name;
                option.textContent = file.name;
                fileSelect.appendChild(option);
            });
        }

        // Update media select in player section
        const mediaSelect = document.getElementById('media-select');
        if (mediaSelect) {
            mediaSelect.innerHTML = '<option value="">-- Sélectionner un fichier --</option>';
            this.currentFiles.forEach(file => {
                const option = document.createElement('option');
                option.value = file.name;
                option.textContent = file.name;
                mediaSelect.appendChild(option);
            });
        }
    },

    truncateFilename: function(filename, maxLength = 30) {
        if (filename.length <= maxLength) return filename;
        const extension = filename.split('.').pop();
        const nameWithoutExt = filename.substring(0, filename.lastIndexOf('.'));
        const truncated = nameWithoutExt.substring(0, maxLength - extension.length - 4) + '...';
        return truncated + '.' + extension;
    },

    formatDuration: function(seconds) {
        if (!seconds || isNaN(seconds)) return '';
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    },

    deleteFile: async function(filename) {
        if (!confirm(`Supprimer le fichier "${filename}" ?`)) return;

        try {
            const data = await PiSignage.api.media.delete(filename);
            if (data.success) {
                showAlert('Fichier supprimé!', 'success');
                this.loadMediaFiles(); // Refresh the list
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Delete file error:', error);
            showAlert('Erreur de suppression', 'error');
        }
    },

    playFile: async function(filename) {
        try {
            const currentPlayer = PiSignage.player.getCurrentPlayer();
            const data = await PiSignage.api.player.playFile(filename, currentPlayer);
            if (data.success) {
                showAlert(`Lecture de ${filename} démarrée`, 'success');
                // Refresh player status
                setTimeout(() => {
                    if (typeof updatePlayerStatus === 'function') {
                        updatePlayerStatus();
                    }
                }, 500);
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Play file error:', error);
            showAlert('Erreur de lecture', 'error');
        }
    },

    setupUploadHandlers: function() {
        // Make upload functions globally available
        window.showUploadModal = this.showUploadModal.bind(this);
        window.openUploadModal = this.showUploadModal.bind(this); // Alternative name for compatibility
    },

    setupEventListeners: function() {
        // Global drag and drop for the entire media section
        const mediaSection = document.getElementById('media');
        if (mediaSection) {
            mediaSection.addEventListener('dragover', this.handleDragOver.bind(this));
            mediaSection.addEventListener('drop', this.handleDrop.bind(this));
            mediaSection.addEventListener('dragleave', this.handleDragLeave.bind(this));
        }
    },

    handleDragOver: function(e) {
        e.preventDefault();
        e.stopPropagation();
        e.dataTransfer.dropEffect = 'copy';

        const mediaSection = document.getElementById('media');
        if (mediaSection) {
            mediaSection.classList.add('drag-over');
        }
    },

    handleDragLeave: function(e) {
        e.preventDefault();
        e.stopPropagation();

        const mediaSection = document.getElementById('media');
        if (mediaSection) {
            mediaSection.classList.remove('drag-over');
        }
    },

    handleDrop: function(e) {
        e.preventDefault();
        e.stopPropagation();

        const mediaSection = document.getElementById('media');
        if (mediaSection) {
            mediaSection.classList.remove('drag-over');
        }

        const files = e.dataTransfer.files;
        if (files.length > 0) {
            this.uploadFiles(Array.from(files));
        }
    },

    showUploadModal: function() {
        if (this.uploadInProgress) {
            showAlert('Upload en cours, veuillez attendre', 'warning');
            return;
        }

        // Use the enhanced upload modal from functions.js if available
        if (typeof openUploadModal === 'function') {
            openUploadModal();
            return;
        }

        // Fallback to basic modal
        this.showBasicUploadModal();
    },

    showBasicUploadModal: function() {
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
                    max-width: 500px;
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
                    " onclick="PiSignage.media.closeUploadModal()">&times;</span>

                    <h2 style="margin-bottom: 20px; text-align: center;">📤 Upload de fichiers</h2>

                    <div class="upload-area" style="
                        border: 3px dashed rgba(255,255,255,0.5);
                        border-radius: 10px;
                        padding: 40px;
                        text-align: center;
                        cursor: pointer;
                        background-color: rgba(255,255,255,0.1);
                        transition: all 0.3s;
                    " onclick="document.getElementById('fileInput').click()">
                        <h3 style="margin-bottom: 10px;">📁 Sélectionner des fichiers</h3>
                        <p>ou glisser-déposer ici</p>
                        <p style="font-size: 12px; opacity: 0.8;">Formats: MP4, AVI, MKV, MOV, JPG, PNG</p>
                        <input type="file" id="fileInput" multiple accept="video/*,image/*,audio/*" style="display: none;" onchange="PiSignage.media.handleFileSelection(this.files)">
                    </div>

                    <div class="modal-footer" style="text-align: right; margin-top: 20px;">
                        <button class="btn btn-secondary" onclick="PiSignage.media.closeUploadModal()">Annuler</button>
                    </div>
                </div>
            </div>
        `;

        document.body.insertAdjacentHTML('beforeend', modalHTML);

        // Add drag and drop to upload area
        const uploadArea = document.querySelector('#uploadModal .upload-area');
        if (uploadArea) {
            uploadArea.addEventListener('dragover', (e) => {
                e.preventDefault();
                uploadArea.style.backgroundColor = 'rgba(255,255,255,0.2)';
            });

            uploadArea.addEventListener('dragleave', (e) => {
                e.preventDefault();
                uploadArea.style.backgroundColor = 'rgba(255,255,255,0.1)';
            });

            uploadArea.addEventListener('drop', (e) => {
                e.preventDefault();
                uploadArea.style.backgroundColor = 'rgba(255,255,255,0.1)';
                const files = e.dataTransfer.files;
                if (files.length > 0) {
                    this.closeUploadModal();
                    this.uploadFiles(Array.from(files));
                }
            });
        }
    },

    closeUploadModal: function() {
        const modal = document.getElementById('uploadModal');
        if (modal) {
            modal.remove();
        }
    },

    handleFileSelection: function(files) {
        if (files && files.length > 0) {
            this.closeUploadModal();
            this.uploadFiles(Array.from(files));
        }
    },

    uploadFiles: async function(files) {
        if (this.uploadInProgress) {
            showAlert('Upload déjà en cours', 'warning');
            return;
        }

        this.uploadInProgress = true;
        const totalSize = files.reduce((sum, file) => sum + file.size, 0);

        showAlert(`📤 Upload de ${files.length} fichier(s) - ${(totalSize/1024/1024).toFixed(1)}MB`, 'info');

        // Show progress indicator
        const progressDiv = this.createProgressIndicator();
        document.body.appendChild(progressDiv);

        try {
            const data = await PiSignage.api.media.upload(files, (progress) => {
                this.updateProgress(progressDiv, progress);
            });

            if (data.success) {
                showAlert('✅ Upload terminé avec succès!', 'success');

                // Auto-refresh media list with multiple strategies
                setTimeout(() => {
                    this.refreshMediaAfterUpload();
                }, 1000);
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Upload error:', error);
            showAlert('❌ Erreur upload: ' + error.message, 'error');
        } finally {
            this.uploadInProgress = false;
            setTimeout(() => {
                if (progressDiv.parentNode) {
                    progressDiv.remove();
                }
            }, 2000);
        }
    },

    createProgressIndicator: function() {
        const progressDiv = document.createElement('div');
        progressDiv.id = 'upload-progress-indicator';
        progressDiv.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: #2a2d3a;
            padding: 20px;
            border-radius: 10px;
            z-index: 10001;
            box-shadow: 0 6px 20px rgba(0,0,0,0.3);
            min-width: 250px;
        `;

        progressDiv.innerHTML = `
            <div style="color: #4a9eff; margin-bottom: 10px; font-weight: bold;">📤 Upload en cours...</div>
            <div style="width: 200px; height: 12px; background: rgba(255,255,255,0.1); border-radius: 6px; overflow: hidden;">
                <div id="upload-progress-bar" style="width: 0%; height: 100%; background: linear-gradient(90deg, #4a9eff, #51cf66); transition: width 0.3s; border-radius: 6px;"></div>
            </div>
            <div id="upload-status" style="margin-top: 8px; font-size: 12px; color: #ccc;">Initialisation...</div>
        `;

        return progressDiv;
    },

    updateProgress: function(progressDiv, progress) {
        const progressBar = progressDiv.querySelector('#upload-progress-bar');
        const statusDiv = progressDiv.querySelector('#upload-status');

        if (progressBar) {
            progressBar.style.width = progress.percent + '%';
        }

        if (statusDiv) {
            const mbLoaded = (progress.loaded / (1024 * 1024)).toFixed(1);
            const mbTotal = (progress.total / (1024 * 1024)).toFixed(1);
            statusDiv.textContent = `${mbLoaded} MB / ${mbTotal} MB (${progress.percent}%)`;
        }
    },

    refreshMediaAfterUpload: function() {
        console.log('🔄 Refreshing media after upload...');

        // Strategy 1: Direct refresh
        this.loadMediaFiles();

        // Strategy 2: Dispatch custom event
        const refreshEvent = new CustomEvent('mediaListUpdated', {
            detail: { source: 'upload', timestamp: Date.now() }
        });
        document.dispatchEvent(refreshEvent);

        // Strategy 3: Switch to media section if not already there
        setTimeout(() => {
            const currentSection = document.querySelector('.content-section.active');
            if (currentSection && currentSection.id !== 'media') {
                console.log('📂 Auto-switching to media section');
                if (typeof showSection === 'function') {
                    showSection('media');
                }
            }
        }, 500);
    },

    // Utility functions for media type detection
    getMediaType: function(mimeType) {
        if (mimeType.startsWith('video/')) return 'video';
        if (mimeType.startsWith('audio/')) return 'audio';
        if (mimeType.startsWith('image/')) return 'image';
        return 'file';
    },

    getMediaIcon: function(type) {
        const icons = {
            video: '🎬',
            audio: '🎵',
            image: '🖼️',
            file: '📄'
        };
        return icons[type] || icons.file;
    }
};

// Global functions for backward compatibility
window.loadMediaFiles = function() {
    PiSignage.media.loadMediaFiles();
};

window.deleteFile = function(filename) {
    PiSignage.media.deleteFile(filename);
};

window.uploadFiles = function(files) {
    PiSignage.media.uploadFiles(Array.from(files));
};

// CSS for drag and drop styling
const mediaStyles = document.createElement('style');
mediaStyles.textContent = `
    #media.drag-over {
        background-color: rgba(74, 158, 255, 0.1);
        border: 2px dashed #4a9eff;
        border-radius: 10px;
    }

    .media-file-card {
        transition: transform 0.2s, box-shadow 0.2s;
    }

    .media-file-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(0,0,0,0.2);
    }

    .file-info p {
        margin: 5px 0;
        font-size: 14px;
        color: #ccc;
    }

    .file-actions {
        display: flex;
        gap: 10px;
    }

    .btn-sm {
        padding: 6px 12px;
        font-size: 12px;
    }
`;
document.head.appendChild(mediaStyles);

console.log('✅ PiSignage Media module loaded - File management ready');