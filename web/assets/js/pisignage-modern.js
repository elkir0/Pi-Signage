/**
 * PiSignage v0.8.0 - Modern JavaScript Application
 * Advanced UX/UI Interface with all functionalities
 */

class PiSignageApp {
    constructor() {
        this.currentTheme = 'dark';
        this.autoScreenshotInterval = null;
        this.systemStatsInterval = null;
        this.isFullscreen = false;
        this.draggedElement = null;
        this.mediaFiles = [];
        this.playlists = [];
        this.isLoading = false;

        // Configuration
        this.config = {
            statsUpdateInterval: 5000,
            toastDuration: 5000,
            animationDuration: 300,
            maxFileSize: 100 * 1024 * 1024, // 100MB
            supportedFileTypes: ['video/*', 'image/*', 'audio/*'],
            apiEndpoints: {
                system: '/api/system.php',
                media: '/api/media.php',
                playlist: '/api/playlist.php',
                player: '/api/player.php',
                youtube: '/api/youtube.php',
                screenshot: '/api/screenshot.php',
                upload: '/api/upload.php'
            }
        };

        this.init();
    }

    /**
     * Initialize the application
     */
    init() {
        this.setupEventListeners();
        this.loadSavedSettings();
        this.startSystemMonitoring();
        this.loadInitialData();
        this.setupKeyboardShortcuts();
        this.setupPerformanceOptimizations();
    }

    /**
     * Setup all event listeners
     */
    setupEventListeners() {
        // DOM Content Loaded
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.onDOMReady());
        } else {
            this.onDOMReady();
        }

        // Window events
        window.addEventListener('resize', this.debounce(this.handleWindowResize.bind(this), 250));
        window.addEventListener('beforeunload', this.handleBeforeUnload.bind(this));

        // Fullscreen events
        document.addEventListener('fullscreenchange', this.handleFullscreenChange.bind(this));
        document.addEventListener('webkitfullscreenchange', this.handleFullscreenChange.bind(this));
        document.addEventListener('mozfullscreenchange', this.handleFullscreenChange.bind(this));

        // Keyboard events
        document.addEventListener('keydown', this.handleKeyboardShortcuts.bind(this));

        // Network status
        window.addEventListener('online', () => this.showToast('Connexion rétablie', 'success'));
        window.addEventListener('offline', () => this.showToast('Connexion perdue', 'warning'));
    }

    /**
     * DOM Ready handler
     */
    onDOMReady() {
        this.setupFileUpload();
        this.setupDragAndDrop();
        this.setupFormValidation();
        this.setupTooltips();
        this.setupLazyLoading();
    }

    /**
     * Setup file upload functionality
     */
    setupFileUpload() {
        const fileInput = document.getElementById('fileInput');
        const dropZone = document.getElementById('dropZone');

        if (fileInput) {
            fileInput.addEventListener('change', this.handleFileSelection.bind(this));
        }

        if (dropZone) {
            dropZone.addEventListener('dragover', this.handleDragOver.bind(this));
            dropZone.addEventListener('drop', this.handleFileDrop.bind(this));
            dropZone.addEventListener('dragenter', this.handleDragEnter.bind(this));
            dropZone.addEventListener('dragleave', this.handleDragLeave.bind(this));
            dropZone.addEventListener('click', () => fileInput?.click());
        }
    }

    /**
     * Setup drag and drop for playlist builder
     */
    setupDragAndDrop() {
        const playlistItemsList = document.getElementById('playlist-items-list');
        if (!playlistItemsList) return;

        // Enable drop zone
        playlistItemsList.addEventListener('dragover', (e) => {
            e.preventDefault();
            playlistItemsList.classList.add('drag-over');
        });

        playlistItemsList.addEventListener('dragleave', (e) => {
            if (!playlistItemsList.contains(e.relatedTarget)) {
                playlistItemsList.classList.remove('drag-over');
            }
        });

        playlistItemsList.addEventListener('drop', (e) => {
            e.preventDefault();
            playlistItemsList.classList.remove('drag-over');

            const filename = e.dataTransfer.getData('text/plain');
            if (filename) {
                this.addToPlaylist(filename);
            }
        });

        // Setup sortable functionality
        this.setupSortable(playlistItemsList);
    }

    /**
     * Setup sortable functionality for playlist items
     */
    setupSortable(container) {
        let draggedElement = null;

        container.addEventListener('dragstart', (e) => {
            if (e.target.classList.contains('draggable-item')) {
                draggedElement = e.target;
                e.target.classList.add('dragging');
                e.dataTransfer.effectAllowed = 'move';
            }
        });

        container.addEventListener('dragend', (e) => {
            if (e.target.classList.contains('draggable-item')) {
                e.target.classList.remove('dragging');
                draggedElement = null;
            }
        });

        container.addEventListener('dragover', (e) => {
            e.preventDefault();
            if (draggedElement) {
                const afterElement = this.getDragAfterElement(container, e.clientY);
                if (afterElement == null) {
                    container.appendChild(draggedElement);
                } else {
                    container.insertBefore(draggedElement, afterElement);
                }
            }
        });
    }

    /**
     * Get element to insert dragged item after
     */
    getDragAfterElement(container, y) {
        const draggableElements = [...container.querySelectorAll('.draggable-item:not(.dragging)')];

        return draggableElements.reduce((closest, child) => {
            const box = child.getBoundingClientRect();
            const offset = y - box.top - box.height / 2;

            if (offset < 0 && offset > closest.offset) {
                return { offset: offset, element: child };
            } else {
                return closest;
            }
        }, { offset: Number.NEGATIVE_INFINITY }).element;
    }

    /**
     * Theme Management
     */
    toggleTheme() {
        this.currentTheme = this.currentTheme === 'dark' ? 'light' : 'dark';
        document.body.setAttribute('data-theme', this.currentTheme);
        this.updateThemeIcon();
        localStorage.setItem('pisignage-theme', this.currentTheme);

        // Animate theme transition
        document.body.style.transition = 'all 0.3s ease';
        setTimeout(() => {
            document.body.style.transition = '';
        }, 300);
    }

    updateThemeIcon() {
        const icon = document.getElementById('theme-icon');
        if (icon) {
            icon.className = this.currentTheme === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
        }
    }

    /**
     * Fullscreen Management
     */
    toggleFullscreen() {
        if (!this.isFullscreen) {
            const element = document.documentElement;
            if (element.requestFullscreen) {
                element.requestFullscreen();
            } else if (element.webkitRequestFullscreen) {
                element.webkitRequestFullscreen();
            } else if (element.mozRequestFullScreen) {
                element.mozRequestFullScreen();
            }
        } else {
            if (document.exitFullscreen) {
                document.exitFullscreen();
            } else if (document.webkitExitFullscreen) {
                document.webkitExitFullscreen();
            } else if (document.mozCancelFullScreen) {
                document.mozCancelFullScreen();
            }
        }
    }

    handleFullscreenChange() {
        this.isFullscreen = !!(document.fullscreenElement ||
                              document.webkitFullscreenElement ||
                              document.mozFullScreenElement);

        const icon = document.querySelector('.fullscreen-btn i');
        if (icon) {
            icon.className = this.isFullscreen ? 'fas fa-compress' : 'fas fa-expand';
        }
    }

    /**
     * Tab Management
     */
    showTab(tabName) {
        // Hide all tabs with animation
        const allTabs = document.querySelectorAll('.tab-content');
        allTabs.forEach(tab => {
            if (tab.classList.contains('active')) {
                tab.style.opacity = '0';
                tab.style.transform = 'translateY(20px)';
                setTimeout(() => {
                    tab.classList.remove('active');
                }, 150);
            }
        });

        // Remove active from nav tabs
        document.querySelectorAll('.nav-tab').forEach(tab => {
            tab.classList.remove('active');
        });

        // Show selected tab with animation
        setTimeout(() => {
            const targetTab = document.getElementById(tabName + '-tab');
            const navTab = document.querySelector(`[data-tab="${tabName}"]`);

            if (targetTab && navTab) {
                targetTab.classList.add('active');
                navTab.classList.add('active');

                // Animate in
                setTimeout(() => {
                    targetTab.style.opacity = '1';
                    targetTab.style.transform = 'translateY(0)';
                }, 50);
            }
        }, 150);

        // Load tab-specific data
        this.loadTabData(tabName);

        // Update URL hash without triggering scroll
        if (history.replaceState) {
            history.replaceState(null, null, '#' + tabName);
        }
    }

    loadTabData(tabName) {
        switch(tabName) {
            case 'dashboard':
                this.loadSystemStats();
                break;
            case 'media':
                this.refreshMediaList();
                break;
            case 'playlist':
                this.refreshPlaylists();
                this.updateAvailableMediaList();
                break;
            case 'player':
                this.loadPlaylistsForSelects();
                this.loadMediaForSelects();
                this.updateVLCStatus();
                break;
            case 'youtube':
                this.loadYouTubeHistory();
                break;
            case 'screenshot':
                this.loadScreenshotHistory();
                break;
            case 'scheduler':
                this.refreshSchedules();
                break;
            case 'settings':
                this.loadSystemInfo();
                break;
        }
    }

    /**
     * Toast Notification System
     */
    showToast(message, type = 'info', duration = null) {
        const toastContainer = document.getElementById('toast-container');
        if (!toastContainer) return;

        const toast = document.createElement('div');
        toast.className = `toast ${type}`;

        const icons = {
            success: 'fas fa-check',
            warning: 'fas fa-exclamation-triangle',
            error: 'fas fa-times',
            info: 'fas fa-info'
        };

        const colors = {
            success: 'var(--success-color)',
            warning: 'var(--warning-color)',
            error: 'var(--error-color)',
            info: 'var(--info-color)'
        };

        toast.innerHTML = `
            <div class="toast-header">
                <div class="toast-icon" style="background: ${colors[type]};">
                    <i class="${icons[type]}"></i>
                </div>
                <div class="toast-title">${this.capitalizeFirst(type)}</div>
                <button class="toast-close" onclick="this.closest('.toast').remove()">
                    <i class="fas fa-times"></i>
                </button>
            </div>
            <div class="toast-body">${message}</div>
        `;

        toastContainer.appendChild(toast);

        // Auto remove
        const timeoutDuration = duration || this.config.toastDuration;
        setTimeout(() => {
            if (toast.parentNode) {
                toast.classList.add('removing');
                setTimeout(() => toast.remove(), 300);
            }
        }, timeoutDuration);

        // Add click to dismiss
        toast.addEventListener('click', (e) => {
            if (!e.target.closest('.toast-close')) {
                toast.classList.add('removing');
                setTimeout(() => toast.remove(), 300);
            }
        });
    }

    /**
     * System Monitoring
     */
    startSystemMonitoring() {
        this.loadSystemStats();
        this.systemStatsInterval = setInterval(() => {
            this.loadSystemStats();
        }, this.config.statsUpdateInterval);
    }

    stopSystemMonitoring() {
        if (this.systemStatsInterval) {
            clearInterval(this.systemStatsInterval);
            this.systemStatsInterval = null;
        }
    }

    async loadSystemStats() {
        try {
            const response = await this.apiCall('system');
            if (response.success) {
                this.updateSystemStats(response.data);
                this.updateConnectionStatus(true);
            }
        } catch (error) {
            console.error('Error loading system stats:', error);
            this.updateConnectionStatus(false);
        }
    }

    updateSystemStats(stats) {
        // Update CPU with trend
        this.updateStatWithTrend('cpu-usage', stats.cpu + '%', stats.cpu);

        // Update Memory with trend
        this.updateStatWithTrend('memory-usage', stats.memory + '%', stats.memory);

        // Update Temperature
        this.updateElement('temperature', stats.temperature + '°C');

        // Update Uptime
        this.updateElement('uptime', stats.uptime);

        // Update other stats
        this.updateElement('media-count', stats.media_count || '0');
        this.updateElement('storage-usage', stats.storage || '0%');
        this.updateElement('playlist-count', stats.playlist_count || '0');
    }

    updateStatWithTrend(elementId, value, numericValue) {
        const element = document.getElementById(elementId);
        if (!element) return;

        const previousValue = parseInt(element.dataset.previous || '0');
        element.textContent = value;
        element.dataset.previous = numericValue;

        // Update trend indicator
        const trendElement = document.getElementById(elementId.replace('-usage', '-trend'));
        if (trendElement) {
            const diff = numericValue - previousValue;
            if (diff > 0) {
                trendElement.className = 'stat-trend trend-up';
                trendElement.innerHTML = `<i class="fas fa-arrow-up"></i> +${diff}%`;
            } else if (diff < 0) {
                trendElement.className = 'stat-trend trend-down';
                trendElement.innerHTML = `<i class="fas fa-arrow-down"></i> ${diff}%`;
            } else {
                trendElement.className = 'stat-trend trend-neutral';
                trendElement.innerHTML = `<i class="fas fa-minus"></i> 0%`;
            }
        }
    }

    updateConnectionStatus(isOnline) {
        const statusDot = document.querySelector('.status-dot');
        const statusText = document.querySelector('.status-indicator span');

        if (statusDot && statusText) {
            if (isOnline) {
                statusDot.style.background = 'var(--success-color)';
                statusText.textContent = 'En ligne';
            } else {
                statusDot.style.background = 'var(--error-color)';
                statusText.textContent = 'Hors ligne';
            }
        }
    }

    /**
     * File Management
     */
    handleFileSelection(event) {
        const files = Array.from(event.target.files);
        this.validateAndDisplayFiles(files);
    }

    handleFileDrop(e) {
        e.preventDefault();
        e.target.classList.remove('dragover');

        const files = Array.from(e.dataTransfer.files);
        this.validateAndDisplayFiles(files);

        // Update file input
        const fileInput = document.getElementById('fileInput');
        if (fileInput) {
            fileInput.files = e.dataTransfer.files;
        }
    }

    handleDragOver(e) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'copy';
    }

    handleDragEnter(e) {
        e.preventDefault();
        e.target.classList.add('dragover');
    }

    handleDragLeave(e) {
        e.preventDefault();
        if (!e.target.contains(e.relatedTarget)) {
            e.target.classList.remove('dragover');
        }
    }

    validateAndDisplayFiles(files) {
        const validFiles = [];
        const errors = [];

        files.forEach(file => {
            // Check file size
            if (file.size > this.config.maxFileSize) {
                errors.push(`${file.name}: Fichier trop volumineux (max ${this.formatFileSize(this.config.maxFileSize)})`);
                return;
            }

            // Check file type
            const isValidType = this.config.supportedFileTypes.some(type => {
                if (type.endsWith('/*')) {
                    return file.type.startsWith(type.slice(0, -1));
                }
                return file.type === type;
            });

            if (!isValidType) {
                errors.push(`${file.name}: Type de fichier non supporté`);
                return;
            }

            validFiles.push(file);
        });

        // Show errors
        if (errors.length > 0) {
            this.showToast(`Erreurs de validation:\n${errors.join('\n')}`, 'warning');
        }

        // Display valid files
        if (validFiles.length > 0) {
            this.displaySelectedFiles(validFiles);
        }
    }

    displaySelectedFiles(files) {
        const dropZone = document.getElementById('dropZone');
        if (!dropZone) return;

        // Remove previous file list
        const existing = dropZone.querySelector('.selected-files');
        if (existing) existing.remove();

        const fileList = document.createElement('div');
        fileList.className = 'selected-files mt-4';

        fileList.innerHTML = `
            <h5><i class="fas fa-check-circle text-success"></i> Fichiers sélectionnés (${files.length}):</h5>
        `;

        files.forEach(file => {
            const fileItem = document.createElement('div');
            fileItem.className = 'flex items-center gap-2 p-2 bg-glass rounded mt-2';

            const icon = this.getFileIconClass(file.type);
            const size = this.formatFileSize(file.size);

            fileItem.innerHTML = `
                <i class="${icon} text-primary"></i>
                <span class="flex-1">${file.name}</span>
                <span class="text-muted text-sm">${size}</span>
                <button class="btn btn-sm btn-danger" onclick="this.parentElement.remove()">
                    <i class="fas fa-times"></i>
                </button>
            `;
            fileList.appendChild(fileItem);
        });

        dropZone.appendChild(fileList);
    }

    clearFileSelection() {
        const fileInput = document.getElementById('fileInput');
        const dropZone = document.getElementById('dropZone');

        if (fileInput) fileInput.value = '';
        if (dropZone) {
            const fileList = dropZone.querySelector('.selected-files');
            if (fileList) fileList.remove();
        }
    }

    async uploadFiles() {
        const fileInput = document.getElementById('fileInput');
        if (!fileInput || !fileInput.files.length) {
            this.showToast('Veuillez sélectionner au moins un fichier', 'warning');
            return;
        }

        const formData = new FormData();
        Array.from(fileInput.files).forEach(file => {
            formData.append('files[]', file);
        });

        try {
            this.showUploadProgress(true);

            const response = await fetch(this.config.apiEndpoints.upload, {
                method: 'POST',
                body: formData
            });

            const data = await response.json();
            this.showUploadProgress(false);

            if (data.success) {
                this.showToast('Fichiers uploadés avec succès!', 'success');
                this.clearFileSelection();
                this.refreshMediaList();
            } else {
                this.showToast('Erreur lors de l\'upload: ' + data.message, 'error');
            }
        } catch (error) {
            this.showUploadProgress(false);
            this.showToast('Erreur lors de l\'upload', 'error');
            console.error('Upload error:', error);
        }
    }

    showUploadProgress(show, percent = 0) {
        const progressContainer = document.getElementById('upload-progress');
        const progressBar = document.getElementById('upload-progress-bar');
        const progressPercent = document.getElementById('upload-percent');
        const uploadStatus = document.getElementById('upload-status');

        if (!progressContainer) return;

        if (show) {
            progressContainer.classList.remove('hidden');
            if (progressBar) progressBar.style.width = percent + '%';
            if (progressPercent) progressPercent.textContent = percent + '%';
            if (uploadStatus) uploadStatus.textContent = 'Upload en cours...';
        } else {
            progressContainer.classList.add('hidden');
        }
    }

    /**
     * Media Management
     */
    async refreshMediaList() {
        try {
            this.showLoadingState('media-list');

            const response = await this.apiCall('media', { action: 'list' });

            if (response.success) {
                this.mediaFiles = response.data;
                this.displayMediaList(response.data);
                this.updateAvailableMediaList(response.data);
            } else {
                this.showToast('Erreur lors du chargement des médias', 'error');
            }
        } catch (error) {
            console.error('Error loading media:', error);
            this.showToast('Erreur de connexion', 'error');
        } finally {
            this.hideLoadingState('media-list');
        }
    }

    displayMediaList(mediaFiles) {
        const mediaList = document.getElementById('media-list');
        if (!mediaList) return;

        if (mediaFiles.length === 0) {
            mediaList.innerHTML = `
                <div class="text-center text-muted p-8" style="grid-column: 1 / -1;">
                    <div class="mb-4">
                        <i class="fas fa-folder-open" style="font-size: 64px; opacity: 0.5;"></i>
                    </div>
                    <h3>Aucun fichier média</h3>
                    <p>Uploadez vos premiers fichiers pour commencer</p>
                    <button class="btn btn-primary mt-4" onclick="app.showTab('media')">
                        <i class="fas fa-upload"></i>
                        Uploader des fichiers
                    </button>
                </div>
            `;
            return;
        }

        mediaList.innerHTML = '';

        mediaFiles.forEach(file => {
            const mediaItem = document.createElement('div');
            mediaItem.className = 'media-item';

            const iconClass = this.getFileIconClass(file.type);
            const fileSize = this.formatFileSize(file.size);

            mediaItem.innerHTML = `
                <div class="media-thumbnail">
                    ${file.thumbnail ?
                        `<img src="${file.thumbnail}" alt="${file.name}" loading="lazy">` :
                        `<i class="${iconClass}"></i>`
                    }
                    <div class="media-overlay">
                        <button class="btn btn-sm btn-primary" onclick="app.previewMedia('${file.name}')">
                            <i class="fas fa-eye"></i>
                        </button>
                    </div>
                </div>
                <div class="media-info">
                    <div class="media-name" title="${file.name}">${file.name}</div>
                    <div class="media-meta">${file.type} • ${fileSize}</div>
                    <div class="flex gap-1 justify-center mt-2">
                        <button class="btn btn-sm btn-secondary" onclick="app.previewMedia('${file.name}')" title="Aperçu">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button class="btn btn-sm btn-secondary" onclick="app.downloadMedia('${file.name}')" title="Télécharger">
                            <i class="fas fa-download"></i>
                        </button>
                        <button class="btn btn-sm btn-danger" onclick="app.deleteMedia('${file.name}')" title="Supprimer">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </div>
            `;

            mediaList.appendChild(mediaItem);
        });
    }

    async deleteMedia(filename) {
        if (!confirm(`Êtes-vous sûr de vouloir supprimer "${filename}" ?`)) {
            return;
        }

        try {
            const response = await this.apiCall('media', {
                action: 'delete',
                filename: filename
            }, 'DELETE');

            if (response.success) {
                this.showToast('Fichier supprimé avec succès', 'success');
                this.refreshMediaList();
            } else {
                this.showToast('Erreur lors de la suppression: ' + response.message, 'error');
            }
        } catch (error) {
            this.showToast('Erreur lors de la suppression', 'error');
            console.error('Delete error:', error);
        }
    }

    previewMedia(filename) {
        const file = this.mediaFiles.find(f => f.name === filename);
        if (!file) return;

        const modal = this.createModal('Aperçu du fichier', this.generatePreviewContent(file));
        this.showModal(modal);
    }

    generatePreviewContent(file) {
        const isImage = file.type.startsWith('image/');
        const isVideo = file.type.startsWith('video/');
        const isAudio = file.type.startsWith('audio/');

        if (isImage) {
            return `
                <div class="text-center">
                    <img src="/media/${file.name}" alt="${file.name}" style="max-width: 100%; max-height: 400px; border-radius: 8px;">
                    <div class="mt-4 text-muted">
                        <strong>${file.name}</strong><br>
                        ${file.type} • ${this.formatFileSize(file.size)}
                    </div>
                </div>
            `;
        } else if (isVideo) {
            return `
                <div class="text-center">
                    <video controls style="max-width: 100%; max-height: 400px; border-radius: 8px;">
                        <source src="/media/${file.name}" type="${file.type}">
                        Votre navigateur ne supporte pas la lecture vidéo.
                    </video>
                    <div class="mt-4 text-muted">
                        <strong>${file.name}</strong><br>
                        ${file.type} • ${this.formatFileSize(file.size)}
                    </div>
                </div>
            `;
        } else if (isAudio) {
            return `
                <div class="text-center">
                    <div class="mb-4">
                        <i class="fas fa-music" style="font-size: 64px; color: var(--primary-color);"></i>
                    </div>
                    <audio controls style="width: 100%;">
                        <source src="/media/${file.name}" type="${file.type}">
                        Votre navigateur ne supporte pas la lecture audio.
                    </audio>
                    <div class="mt-4 text-muted">
                        <strong>${file.name}</strong><br>
                        ${file.type} • ${this.formatFileSize(file.size)}
                    </div>
                </div>
            `;
        } else {
            return `
                <div class="text-center">
                    <div class="mb-4">
                        <i class="fas fa-file" style="font-size: 64px; color: var(--primary-color);"></i>
                    </div>
                    <div class="text-muted">
                        <strong>${file.name}</strong><br>
                        ${file.type} • ${this.formatFileSize(file.size)}<br>
                        <em>Aperçu non disponible pour ce type de fichier</em>
                    </div>
                </div>
            `;
        }
    }

    /**
     * Player Controls
     */
    async vlcControl(action, options = {}) {
        try {
            const response = await this.apiCall('player', {
                action: action,
                ...options
            }, 'POST');

            if (response.success) {
                this.showToast(`Action ${action} exécutée`, 'success');
                this.updateVLCStatus();
            } else {
                this.showToast(`Erreur: ${response.message}`, 'error');
            }
        } catch (error) {
            this.showToast('Erreur de communication avec VLC', 'error');
            console.error('VLC control error:', error);
        }
    }

    async updateVLCStatus() {
        try {
            const response = await this.apiCall('player', { action: 'status' });

            if (response.success) {
                const status = response.data;
                this.updateElement('vlc-state', status.state || 'Arrêté');
                this.updateElement('vlc-file', status.file || 'Aucun');
                this.updateElement('vlc-position', status.position || '00:00');
                this.updateElement('now-playing', status.file || 'Aucun média en lecture');

                if (status.progress !== undefined) {
                    const progressBar = document.getElementById('player-progress');
                    if (progressBar) {
                        progressBar.style.width = status.progress + '%';
                    }
                }
            }
        } catch (error) {
            console.error('Error updating VLC status:', error);
        }
    }

    setVolume(volume) {
        this.vlcControl('volume', { value: volume });
        this.updateElement('volume-display', volume + '%');
    }

    /**
     * Screenshot Management
     */
    async takeScreenshot() {
        this.showToast('Capture en cours...', 'info');

        try {
            const response = await this.apiCall('screenshot', { action: 'capture' });

            if (response.success) {
                this.displayScreenshot(response.data.url);
                this.showToast('Capture réalisée avec succès!', 'success');
                this.updateLastScreenshotTime();
            } else {
                this.showToast('Erreur lors de la capture: ' + response.message, 'error');
            }
        } catch (error) {
            this.showToast('Erreur lors de la capture', 'error');
            console.error('Screenshot error:', error);
        }
    }

    displayScreenshot(url) {
        const img = document.getElementById('screenshot-display');
        const placeholder = document.getElementById('screenshot-placeholder');

        if (img && placeholder) {
            img.src = url + '?t=' + Date.now();
            img.classList.remove('hidden');
            placeholder.style.display = 'none';
        }
    }

    toggleAutoScreenshot() {
        const button = document.getElementById('auto-screenshot-btn');

        if (this.autoScreenshotInterval) {
            clearInterval(this.autoScreenshotInterval);
            this.autoScreenshotInterval = null;
            if (button) {
                button.innerHTML = '<i class="fas fa-clock"></i> Auto-capture (OFF)';
            }
            this.showToast('Auto-capture désactivée', 'info');
        } else {
            const intervalInput = document.getElementById('auto-interval');
            const interval = parseInt(intervalInput?.value || '30') * 1000;

            this.autoScreenshotInterval = setInterval(() => {
                this.takeScreenshot();
            }, interval);

            if (button) {
                button.innerHTML = '<i class="fas fa-clock"></i> Auto-capture (ON)';
            }
            this.showToast('Auto-capture activée', 'success');
        }
    }

    updateLastScreenshotTime() {
        const element = document.getElementById('last-screenshot');
        if (element) {
            element.textContent = new Date().toLocaleTimeString();
        }
    }

    /**
     * YouTube Download
     */
    async downloadYoutube() {
        const urlInput = document.getElementById('youtube-url');
        const qualitySelect = document.getElementById('download-quality');
        const formatSelect = document.getElementById('download-format');

        if (!urlInput || !urlInput.value.trim()) {
            this.showToast('Veuillez entrer une URL YouTube', 'warning');
            return;
        }

        const url = urlInput.value.trim();
        const quality = qualitySelect?.value || 'best';
        const format = formatSelect?.value || 'mp4';

        if (!this.isValidYouTubeUrl(url)) {
            this.showToast('URL YouTube invalide', 'error');
            return;
        }

        try {
            this.showDownloadProgress(true);

            const response = await this.apiCall('youtube', {
                url: url,
                quality: quality,
                format: format
            }, 'POST');

            this.showDownloadProgress(false);

            if (response.success) {
                this.showToast('Vidéo téléchargée avec succès!', 'success');
                urlInput.value = '';
                this.refreshMediaList();
                this.addToYouTubeHistory(url, response.data);
            } else {
                this.showToast('Erreur lors du téléchargement: ' + response.message, 'error');
            }
        } catch (error) {
            this.showDownloadProgress(false);
            this.showToast('Erreur lors du téléchargement', 'error');
            console.error('YouTube download error:', error);
        }
    }

    isValidYouTubeUrl(url) {
        const youtubeRegex = /^(https?\:\/\/)?(www\.)?(youtube\.com|youtu\.be)\/.+/;
        return youtubeRegex.test(url);
    }

    showDownloadProgress(show, percent = 0) {
        const progressContainer = document.getElementById('download-progress');
        const progressBar = document.getElementById('youtube-progress-bar');
        const progressPercent = document.getElementById('download-percent');
        const downloadStatus = document.getElementById('download-status');

        if (!progressContainer) return;

        if (show) {
            progressContainer.classList.remove('hidden');
            if (progressBar) progressBar.style.width = percent + '%';
            if (progressPercent) progressPercent.textContent = percent + '%';
            if (downloadStatus) downloadStatus.textContent = 'Téléchargement en cours...';
        } else {
            progressContainer.classList.add('hidden');
        }
    }

    /**
     * Keyboard Shortcuts
     */
    handleKeyboardShortcuts(e) {
        // Only handle when not in input fields
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
            return;
        }

        switch(e.key) {
            case 'F11':
                e.preventDefault();
                this.toggleFullscreen();
                break;
            case ' ':
                if (e.ctrlKey) {
                    e.preventDefault();
                    this.vlcControl('pause');
                }
                break;
            case 't':
                if (e.ctrlKey) {
                    e.preventDefault();
                    this.takeScreenshot();
                }
                break;
            case 'd':
                if (e.ctrlKey) {
                    e.preventDefault();
                    this.toggleTheme();
                }
                break;
            case 'Escape':
                this.closeAllModals();
                break;
        }

        // Number keys for tab switching
        if (e.key >= '1' && e.key <= '8' && e.altKey) {
            e.preventDefault();
            const tabs = ['dashboard', 'media', 'playlist', 'player', 'youtube', 'screenshot', 'scheduler', 'settings'];
            const tabIndex = parseInt(e.key) - 1;
            if (tabs[tabIndex]) {
                this.showTab(tabs[tabIndex]);
            }
        }
    }

    setupKeyboardShortcuts() {
        // Show shortcuts help
        const shortcutsInfo = `
            <div class="keyboard-shortcuts" style="position: fixed; bottom: 20px; right: 20px; background: var(--bg-card); padding: 10px; border-radius: 8px; font-size: 12px; opacity: 0.7; max-width: 300px;">
                <strong>Raccourcis clavier:</strong><br>
                F11: Plein écran<br>
                Ctrl+Space: Play/Pause<br>
                Ctrl+T: Capture d'écran<br>
                Ctrl+D: Changer thème<br>
                Alt+1-8: Changer d'onglet
            </div>
        `;

        // Add to body after a delay
        setTimeout(() => {
            document.body.insertAdjacentHTML('beforeend', shortcutsInfo);

            // Auto-hide after 10 seconds
            setTimeout(() => {
                const element = document.querySelector('.keyboard-shortcuts');
                if (element) element.remove();
            }, 10000);
        }, 2000);
    }

    /**
     * Performance Optimizations
     */
    setupPerformanceOptimizations() {
        // Intersection Observer for lazy loading
        this.setupIntersectionObserver();

        // Service Worker for caching (if supported)
        this.setupServiceWorker();

        // Image optimization
        this.setupImageOptimization();
    }

    setupIntersectionObserver() {
        if ('IntersectionObserver' in window) {
            this.observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        this.loadLazyContent(entry.target);
                        this.observer.unobserve(entry.target);
                    }
                });
            }, { threshold: 0.1 });
        }
    }

    setupLazyLoading() {
        // Add lazy loading for images and heavy content
        const lazyElements = document.querySelectorAll('[data-lazy]');
        lazyElements.forEach(element => {
            if (this.observer) {
                this.observer.observe(element);
            } else {
                // Fallback for browsers without IntersectionObserver
                this.loadLazyContent(element);
            }
        });
    }

    loadLazyContent(element) {
        const src = element.dataset.lazy;
        if (src && element.tagName === 'IMG') {
            element.src = src;
            element.removeAttribute('data-lazy');
        }
    }

    setupServiceWorker() {
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.register('/sw.js')
                .then(registration => {
                    console.log('Service Worker registered:', registration);
                })
                .catch(error => {
                    console.log('Service Worker registration failed:', error);
                });
        }
    }

    setupImageOptimization() {
        // Setup responsive images and WebP support
        if (this.supportsWebP()) {
            document.documentElement.classList.add('webp');
        }
    }

    supportsWebP() {
        const canvas = document.createElement('canvas');
        canvas.width = 1;
        canvas.height = 1;
        return canvas.toDataURL('image/webp').indexOf('data:image/webp') === 0;
    }

    /**
     * Utility Functions
     */
    async apiCall(endpoint, data = {}, method = 'GET') {
        const url = this.config.apiEndpoints[endpoint];
        if (!url) {
            throw new Error(`Unknown API endpoint: ${endpoint}`);
        }

        const options = {
            method: method,
            headers: {
                'Content-Type': 'application/json',
            }
        };

        if (method === 'GET' && Object.keys(data).length > 0) {
            const params = new URLSearchParams(data);
            return fetch(`${url}?${params}`, options).then(r => r.json());
        }

        if (method !== 'GET') {
            options.body = JSON.stringify(data);
        }

        const response = await fetch(url, options);
        return response.json();
    }

    updateElement(id, value) {
        const element = document.getElementById(id);
        if (element) {
            element.textContent = value;
        }
    }

    getFileIconClass(mimeType) {
        if (mimeType.startsWith('video/')) return 'fas fa-film';
        if (mimeType.startsWith('image/')) return 'fas fa-image';
        if (mimeType.startsWith('audio/')) return 'fas fa-music';
        return 'fas fa-file';
    }

    formatFileSize(bytes) {
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        if (bytes === 0) return '0 B';
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        const size = (bytes / Math.pow(1024, i)).toFixed(1);
        return `${size} ${sizes[i]}`;
    }

    capitalizeFirst(str) {
        return str.charAt(0).toUpperCase() + str.slice(1);
    }

    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    throttle(func, limit) {
        let inThrottle;
        return function executedFunction(...args) {
            if (!inThrottle) {
                func.apply(this, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    }

    showLoadingState(containerId) {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = `
                <div class="text-center p-8">
                    <div class="loading loading-lg mb-4"></div>
                    <div class="text-muted">Chargement...</div>
                </div>
            `;
        }
    }

    hideLoadingState(containerId) {
        // This will be called after data is loaded and displayed
    }

    createModal(title, content, actions = '') {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3 class="modal-title">${title}</h3>
                    <button class="modal-close" onclick="this.closest('.modal').remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    ${content}
                </div>
                ${actions ? `<div class="modal-footer">${actions}</div>` : ''}
            </div>
        `;
        return modal;
    }

    showModal(modal) {
        document.body.appendChild(modal);
        setTimeout(() => modal.classList.add('show'), 10);

        // Close on backdrop click
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                this.closeModal(modal);
            }
        });
    }

    closeModal(modal) {
        modal.classList.remove('show');
        setTimeout(() => modal.remove(), 300);
    }

    closeAllModals() {
        document.querySelectorAll('.modal').forEach(modal => {
            this.closeModal(modal);
        });
    }

    handleWindowResize() {
        // Handle responsive adjustments
        this.updateLayout();
    }

    updateLayout() {
        // Responsive layout updates
        const width = window.innerWidth;

        if (width < 768) {
            document.body.classList.add('mobile');
        } else {
            document.body.classList.remove('mobile');
        }
    }

    handleBeforeUnload(e) {
        // Clean up intervals and save state
        this.stopSystemMonitoring();

        if (this.autoScreenshotInterval) {
            clearInterval(this.autoScreenshotInterval);
        }

        // Save current state
        this.saveCurrentState();
    }

    loadSavedSettings() {
        // Load theme
        const savedTheme = localStorage.getItem('pisignage-theme');
        if (savedTheme) {
            this.currentTheme = savedTheme;
            document.body.setAttribute('data-theme', this.currentTheme);
            this.updateThemeIcon();
        }

        // Load last active tab
        const savedTab = localStorage.getItem('pisignage-active-tab') ||
                        window.location.hash.slice(1) || 'dashboard';
        this.showTab(savedTab);
    }

    saveCurrentState() {
        // Save current tab
        const activeTab = document.querySelector('.nav-tab.active');
        if (activeTab) {
            localStorage.setItem('pisignage-active-tab', activeTab.dataset.tab);
        }
    }

    loadInitialData() {
        // Load all initial data
        this.loadSystemStats();
        this.refreshMediaList();
    }

    // Placeholder methods for incomplete functionality
    async refreshPlaylists() {
        console.log('Loading playlists...');
        // Implementation here
    }

    async loadPlaylistsForSelects() {
        console.log('Loading playlists for selects...');
        // Implementation here
    }

    updateAvailableMediaList(mediaFiles = []) {
        const container = document.getElementById('available-media-list');
        if (!container) return;

        container.innerHTML = '';

        mediaFiles.forEach(file => {
            const item = document.createElement('div');
            item.className = 'draggable-item';
            item.draggable = true;
            item.dataset.filename = file.name;

            const icon = this.getFileIconClass(file.type);
            item.innerHTML = `
                <i class="drag-handle fas fa-grip-vertical"></i>
                <i class="${icon}"></i>
                <span>${file.name}</span>
            `;

            item.addEventListener('dragstart', (e) => {
                e.dataTransfer.setData('text/plain', file.name);
                item.classList.add('dragging');
            });

            item.addEventListener('dragend', () => {
                item.classList.remove('dragging');
            });

            container.appendChild(item);
        });
    }

    addToPlaylist(filename) {
        const container = document.getElementById('playlist-items-list');
        if (!container) return;

        // Remove placeholder if exists
        const placeholder = container.querySelector('.text-center');
        if (placeholder) placeholder.remove();

        const item = document.createElement('div');
        item.className = 'draggable-item';
        item.draggable = true;
        item.dataset.filename = filename;

        const file = this.mediaFiles.find(f => f.name === filename);
        const icon = file ? this.getFileIconClass(file.type) : 'fas fa-file';

        item.innerHTML = `
            <i class="drag-handle fas fa-grip-vertical"></i>
            <i class="${icon}"></i>
            <span>${filename}</span>
            <button class="btn btn-sm btn-danger ml-auto" onclick="this.parentElement.remove()">
                <i class="fas fa-times"></i>
            </button>
        `;

        container.appendChild(item);
    }

    async loadMediaForSelects() {
        console.log('Loading media for selects...');
        // Implementation here
    }

    async loadScreenshotHistory() {
        console.log('Loading screenshot history...');
        // Implementation here
    }

    async refreshSchedules() {
        console.log('Loading schedules...');
        // Implementation here
    }

    async loadSystemInfo() {
        console.log('Loading system info...');
        // Implementation here
    }

    async loadYouTubeHistory() {
        console.log('Loading YouTube history...');
        // Implementation here
    }

    addToYouTubeHistory(url, data) {
        console.log('Adding to YouTube history:', url, data);
        // Implementation here
    }

    downloadMedia(filename) {
        const link = document.createElement('a');
        link.href = `/media/${filename}`;
        link.download = filename;
        link.click();
    }
}

// Initialize application when DOM is ready
window.app = new PiSignageApp();

// Export for global access
window.PiSignageApp = PiSignageApp;