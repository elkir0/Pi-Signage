/**
 * PiSignage Playlists Module
 * Handles playlist creation, editing, management and advanced playlist editor
 */

// Ensure PiSignage namespace exists
window.PiSignage = window.PiSignage || {};

// Playlist management functionality
PiSignage.playlists = {
    currentPlaylists: [],

    // Advanced playlist editor state
    currentPlaylist: {
        name: '',
        items: [],
        settings: {
            loop: true,
            shuffle: false,
            auto_advance: true,
            fade_duration: 1000
        }
    },

    mediaLibrary: [],
    selectedItem: null,
    draggedElement: null,
    playlistModified: false,

    /* Inline SVG helpers (design-system, no emoji). viewBox 0 0 24 24, stroke=currentColor. */
    _svg: function(inner) {
        return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
             + 'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + inner + '</svg>';
    },

    _icons: {
        video: '<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/>',
        audio: '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.5 8.5a5 5 0 0 1 0 7M19 5a9 9 0 0 1 0 14"/>',
        image: '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="m21 15-5-5L5 21"/>',
        file:  '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/>',
        plus:  '<path d="M12 5v14M5 12h14"/>',
        trash: '<path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M10 11v6M14 11v6"/>',
        play:  '<polygon points="6 4 20 12 6 20 6 4" fill="currentColor" stroke="none"/>',
        edit:  '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4z"/>',
        drag:  '<circle cx="9" cy="6" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="6" r="1.4" fill="currentColor" stroke="none"/><circle cx="9" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="9" cy="18" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="18" r="1.4" fill="currentColor" stroke="none"/>',
        playlist: '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>'
    },

    init: function() {
        this.loadPlaylists();
        this.setupGlobalFunctions();

        // Initialize playlist editor if on playlists.php page
        if (window.location.pathname.includes('playlists.php')) {
            this.initPlaylistEditor();
        }
    },

    loadPlaylists: async function() {
        try {
            const data = await PiSignage.api.playlists.list();
            if (data.success) {
                this.currentPlaylists = data.data || [];
                this.renderPlaylistsList();
                this.updatePlaylistSelects();
            } else {
                console.error('Failed to load playlists:', data.message);
            }
        } catch (error) {
            console.error('Error loading playlists:', error);
            PiSignage.ui.toast('Erreur de chargement des playlists', 'error');
        }
    },

    renderPlaylistsList: function() {
        const container = document.getElementById('playlist-container');
        if (!container) return;

        if (this.currentPlaylists.length === 0) {
            container.innerHTML = `
                <div class="empty-state" style="grid-column:1/-1">
                    ${this._svg(this._icons.playlist)}
                    <h3>Aucune playlist</h3>
                    <p>Créez votre première playlist pour organiser vos médias</p>
                </div>
            `;
            return;
        }

        container.innerHTML = '';

        this.currentPlaylists.forEach(playlist => {
            const card = document.createElement('div');
            card.className = 'card playlist-card';
            card.innerHTML = `
                <div class="playlist-header">
                    <h3 class="card-title">${playlist.name}</h3>
                    <div class="playlist-info">
                        <span class="item-count">${playlist.items ? playlist.items.length : 0} fichiers</span>
                        ${playlist.duration ? `<span class="duration">${this.formatDuration(playlist.duration)}</span>` : ''}
                    </div>
                </div>
                <div class="playlist-actions">
                    <button class="btn btn-primary btn-sm" onclick="PiSignage.playlists.playPlaylist('${playlist.name}')" title="Lire cette playlist">
                        ${this._svg(this._icons.play)}Lire
                    </button>
                    <button class="btn btn-glass btn-sm" onclick="PiSignage.playlists.editPlaylist('${playlist.name}')" title="Modifier cette playlist">
                        ${this._svg(this._icons.edit)}Modifier
                    </button>
                    <button class="btn btn-danger btn-sm" onclick="PiSignage.playlists.deletePlaylist('${playlist.name}')" title="Supprimer cette playlist">
                        ${this._svg(this._icons.trash)}Supprimer
                    </button>
                </div>
            `;
            container.appendChild(card);
        });
    },

    updatePlaylistSelects: function() {
        // Update playlist select in player section
        const playlistSelect = document.getElementById('playlist-select');
        if (playlistSelect) {
            playlistSelect.innerHTML = '<option value="">-- Sélectionner une playlist --</option>';
            this.currentPlaylists.forEach(playlist => {
                const option = document.createElement('option');
                option.value = playlist.name;
                option.textContent = playlist.name;
                playlistSelect.appendChild(option);
            });
        }
    },

    formatDuration: function(seconds) {
        if (!seconds || isNaN(seconds)) return '';
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    },

    createPlaylist: async function() {
        const name = prompt('Nom de la nouvelle playlist:');
        if (!name) return;

        // Get selected files from media section
        const selectedFiles = Array.from(document.querySelectorAll('#media input[type="checkbox"]:checked'))
            .map(cb => cb.value);

        try {
            const data = await PiSignage.api.playlists.create(name, selectedFiles);
            if (data.success) {
                PiSignage.ui.toast('Playlist créée', 'success');
                this.loadPlaylists();
            } else {
                PiSignage.ui.toast('Erreur : ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Create playlist error:', error);
            PiSignage.ui.toast('Erreur de création', 'error');
        }
    },

    editPlaylist: async function(name) {
        try {
            const data = await PiSignage.api.playlists.getInfo(name);
            if (data.success && data.data) {
                this.showEditModal(data.data);
            } else {
                PiSignage.ui.toast('Erreur lors du chargement de la playlist', 'error');
            }
        } catch (error) {
            console.error('Edit playlist error:', error);
            PiSignage.ui.toast('Erreur de chargement', 'error');
        }
    },

    showEditModal: function(playlist) {
        // Clean up any stale instance first
        this.closeEditModal();

        const esc = (s) => String(s).replace(/[&<>"']/g, c => (
            { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
        ));

        const modalHTML = `
            <div id="editPlaylistModal" class="modal" data-remove-on-close="1">
                <div class="modal-content">
                    <div class="modal-header">
                        <h3>Modifier la playlist : ${esc(playlist.name)}</h3>
                        <button class="btn-close" type="button" onclick="PiSignage.playlists.closeEditModal()">
                            ${this._svg('<path d="M18 6 6 18M6 6l12 12"/>')}
                        </button>
                    </div>
                    <div class="modal-body">
                        <div class="form-group">
                            <label>Nom de la playlist</label>
                            <input type="text" id="edit-playlist-name" class="form-control" value="${esc(playlist.name)}">
                        </div>

                        <div class="form-group">
                            <label>Fichiers dans la playlist</label>
                            <div id="edit-playlist-items" style="max-height:200px;overflow-y:auto;border:1px solid var(--border);padding:12px;border-radius:var(--radius-sm);background:var(--surface-2)">
                                ${playlist.items.map(item => `
                                    <label class="checkbox-label">
                                        <input type="checkbox" value="${esc(item)}" checked>
                                        <span style="flex:1">${esc(item)}</span>
                                    </label>
                                `).join('')}
                            </div>
                        </div>

                        <div class="form-group">
                            <label>Ajouter des fichiers</label>
                            <select id="add-files-select" class="form-control" multiple style="height:120px">
                                <!-- Will be populated with available files -->
                            </select>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button class="btn btn-secondary" type="button" onclick="PiSignage.playlists.closeEditModal()">Annuler</button>
                        <button class="btn btn-primary" type="button" onclick="PiSignage.playlists.savePlaylistChanges('${esc(playlist.name)}')">Sauvegarder</button>
                    </div>
                </div>
            </div>
        `;

        document.body.insertAdjacentHTML('beforeend', modalHTML);

        // Populate available files
        this.populateAvailableFiles(playlist.items);

        // Open via the shared UI helper (handles background click + ESC + cleanup).
        PiSignage.ui.openModal('editPlaylistModal');
    },

    populateAvailableFiles: async function(currentItems) {
        try {
            const data = await PiSignage.api.media.list();
            if (data.success && data.data) {
                const select = document.getElementById('add-files-select');
                if (select) {
                    data.data.forEach(file => {
                        if (!currentItems.includes(file.name)) {
                            const option = document.createElement('option');
                            option.value = file.name;
                            option.textContent = file.name;
                            select.appendChild(option);
                        }
                    });
                }
            }
        } catch (error) {
            console.error('Error loading available files:', error);
        }
    },

    closeEditModal: function() {
        const modal = document.getElementById('editPlaylistModal');
        if (modal) {
            // ui.closeModal removes the ESC/background handlers and, because the
            // modal carries data-remove-on-close="1", pulls it out of the DOM.
            PiSignage.ui.closeModal(modal);
        }
    },

    savePlaylistChanges: async function(originalName) {
        const newName = document.getElementById('edit-playlist-name').value;

        // Get selected existing items
        const selectedItems = Array.from(document.querySelectorAll('#edit-playlist-items input:checked'))
            .map(cb => cb.value);

        // Get newly selected files
        const newFiles = Array.from(document.getElementById('add-files-select').selectedOptions)
            .map(option => option.value);

        const allItems = [...selectedItems, ...newFiles];

        try {
            const data = await PiSignage.api.playlists.update(originalName, newName, allItems);
            if (data.success) {
                PiSignage.ui.toast('Playlist modifiée', 'success');
                this.closeEditModal();
                this.loadPlaylists();
            } else {
                PiSignage.ui.toast('Erreur : ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Save playlist error:', error);
            PiSignage.ui.toast('Erreur de sauvegarde', 'error');
        }
    },

    deletePlaylist: async function(name) {
        if (!PiSignage.ui.confirm(`Supprimer la playlist « ${name} » ?`)) return;

        try {
            const data = await PiSignage.api.playlists.delete(name);
            if (data.success) {
                PiSignage.ui.toast('Playlist supprimée', 'success');
                this.loadPlaylists();
            } else {
                PiSignage.ui.toast('Erreur : ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Delete playlist error:', error);
            PiSignage.ui.toast('Erreur de suppression', 'error');
        }
    },

    playPlaylist: async function(name) {
        try {
            const currentPlayer = PiSignage.player.getCurrentPlayer();
            const data = await PiSignage.api.player.playPlaylist(name, currentPlayer);
            if (data.success) {
                PiSignage.ui.toast(`Playlist « ${name} » lancée`, 'success');
                // Update player status
                setTimeout(() => {
                    if (typeof updatePlayerStatus === 'function') {
                        updatePlayerStatus();
                    }
                }, 500);
            } else {
                PiSignage.ui.toast('Erreur : ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Play playlist error:', error);
            PiSignage.ui.toast('Erreur de lecture', 'error');
        }
    },

    // Advanced Playlist Editor Functions
    initPlaylistEditor: function() {
        this.loadMediaLibrary();
        this.resetPlaylistEditor();
        this.setupEventListeners();
    },

    loadMediaLibrary: async function() {
        try {
            const data = await PiSignage.api.media.list();
            if (data.success) {
                this.mediaLibrary = data.data || [];
                this.renderMediaLibrary();
            }
        } catch (error) {
            console.error('Error loading media library:', error);
        }
    },

    renderMediaLibrary: function() {
        const container = document.getElementById('media-library-list');
        if (!container) return;

        const searchTerm = document.getElementById('media-search')?.value.toLowerCase() || '';
        const activeFilter = document.querySelector('.filter-btn.active')?.dataset.type || 'all';

        const filteredMedia = this.mediaLibrary.filter(file => {
            const matchesSearch = !searchTerm || file.name.toLowerCase().includes(searchTerm);
            const matchesFilter = activeFilter === 'all' || this.getMediaType(file.type) === activeFilter;
            return matchesSearch && matchesFilter;
        });

        container.innerHTML = filteredMedia.map(file => {
            const mediaType = this.getMediaType(file.type);
            const icon = this.getMediaIcon(mediaType);
            const duration = file.duration ? PiSignage.utils.formatTime(file.duration) : '';
            const size = file.size_formatted || '';

            return `
                <div class="media-item" draggable="true" data-file="${file.name}" data-type="${mediaType}">
                    <div class="media-item-icon ${mediaType}">
                        ${icon}
                    </div>
                    <div class="media-item-info">
                        <div class="media-item-name" title="${file.name}">${file.name}</div>
                        <div class="media-item-meta">${duration} ${size}</div>
                    </div>
                    <div class="media-item-actions">
                        <button class="icon-btn" onclick="PiSignage.playlists.addMediaToPlaylist('${file.name}')" title="Ajouter à la playlist">
                            ${this._svg(this._icons.plus)}
                        </button>
                    </div>
                </div>
            `;
        }).join('');

        // Add drag listeners
        container.querySelectorAll('.media-item').forEach(item => {
            item.addEventListener('dragstart', this.handleMediaDragStart.bind(this));
            item.addEventListener('dragend', this.handleMediaDragEnd.bind(this));
        });
    },

    getMediaType: function(mimeType) {
        if (mimeType.startsWith('video/')) return 'video';
        if (mimeType.startsWith('audio/')) return 'audio';
        if (mimeType.startsWith('image/')) return 'image';
        return 'file';
    },

    getMediaIcon: function(type) {
        return this._svg(this._icons[type] || this._icons.file);
    },

    setupEventListeners: function() {
        // Drop zone listeners
        const dropZone = document.getElementById('playlist-drop-zone');
        if (dropZone) {
            dropZone.addEventListener('dragover', this.handleDragOver.bind(this));
            dropZone.addEventListener('drop', this.handleDrop.bind(this));
            dropZone.addEventListener('dragleave', this.handleDragLeave.bind(this));
        }

        // Playlist workspace listeners
        const workspace = document.getElementById('playlist-workspace');
        if (workspace) {
            workspace.addEventListener('dragover', this.handleDragOver.bind(this));
            workspace.addEventListener('drop', this.handleDrop.bind(this));
        }
    },

    handleMediaDragStart: function(e) {
        this.draggedElement = e.target;
        e.target.classList.add('dragging');
        e.dataTransfer.setData('text/plain', e.target.dataset.file);
        e.dataTransfer.effectAllowed = 'copy';
    },

    handleMediaDragEnd: function(e) {
        e.target.classList.remove('dragging');
        this.draggedElement = null;
    },

    handleDragOver: function(e) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'copy';

        const dropZone = document.getElementById('playlist-drop-zone');
        if (dropZone && !dropZone.classList.contains('hidden')) {
            dropZone.classList.add('drag-over');
        }
    },

    handleDragLeave: function(e) {
        const dropZone = document.getElementById('playlist-drop-zone');
        if (dropZone) {
            dropZone.classList.remove('drag-over');
        }
    },

    handleDrop: function(e) {
        e.preventDefault();
        const fileName = e.dataTransfer.getData('text/plain');

        const dropZone = document.getElementById('playlist-drop-zone');
        if (dropZone) {
            dropZone.classList.remove('drag-over');
        }

        if (fileName) {
            this.addMediaToPlaylist(fileName);
        }
    },

    addMediaToPlaylist: function(fileName) {
        const mediaFile = this.mediaLibrary.find(file => file.name === fileName);
        if (!mediaFile) return;

        const playlistItem = {
            file: fileName,
            duration: this.getDefaultDuration(mediaFile.type),
            transition: 'none',
            order: this.currentPlaylist.items.length
        };

        this.currentPlaylist.items.push(playlistItem);
        this.renderPlaylistItems();
        this.updatePlaylistStats();
        this.setPlaylistModified(true);
        this.showDropZone(false);
    },

    getDefaultDuration: function(mimeType) {
        if (mimeType.startsWith('image/')) return 10;
        if (mimeType.startsWith('video/')) return 30;
        if (mimeType.startsWith('audio/')) return 60;
        return 10;
    },

    renderPlaylistItems: function() {
        const container = document.getElementById('playlist-items');
        if (!container) return;

        container.innerHTML = this.currentPlaylist.items.map((item, index) => {
            const mediaFile = this.mediaLibrary.find(file => file.name === item.file);
            const mediaType = mediaFile ? this.getMediaType(mediaFile.type) : 'file';
            const icon = this.getMediaIcon(mediaType);

            return `
                <div class="playlist-item" data-index="${index}" onclick="PiSignage.playlists.selectPlaylistItem(${index})">
                    <div class="drag-handle" title="Déplacer">${this._svg(this._icons.drag)}</div>
                    <div class="playlist-item-icon ${mediaType}">
                        ${icon}
                    </div>
                    <div class="playlist-item-content">
                        <div class="playlist-item-name" title="${item.file}">${item.file}</div>
                        <div class="playlist-item-details">
                            <span>Durée : ${item.duration}s</span>
                            <span>Transition : ${item.transition}</span>
                            <span>Position : ${index + 1}</span>
                        </div>
                    </div>
                    <div class="playlist-item-actions">
                        <button class="icon-btn" onclick="event.stopPropagation();PiSignage.playlists.removePlaylistItem(${index})" title="Supprimer">
                            ${this._svg(this._icons.trash)}
                        </button>
                    </div>
                </div>
            `;
        }).join('');

        this.showDropZone(this.currentPlaylist.items.length === 0);
    },

    showDropZone: function(show) {
        const dropZone = document.getElementById('playlist-drop-zone');
        if (dropZone) {
            dropZone.classList.toggle('hidden', !show);
        }
    },

    selectPlaylistItem: function(index) {
        this.selectedItem = index;

        // Update visual selection
        document.querySelectorAll('.playlist-item').forEach((item, i) => {
            item.classList.toggle('selected', i === index);
        });

        this.updatePropertiesPanel();
    },

    updatePropertiesPanel: function() {
        const propertiesSection = document.getElementById('item-properties');
        if (!propertiesSection) return;

        if (this.selectedItem !== null && this.currentPlaylist.items[this.selectedItem]) {
            const item = this.currentPlaylist.items[this.selectedItem];

            const selectedFileNameEl = document.getElementById('selected-file-name');
            if (selectedFileNameEl) selectedFileNameEl.textContent = item.file;

            const itemDurationEl = document.getElementById('item-duration');
            if (itemDurationEl) itemDurationEl.value = item.duration;

            const itemTransitionEl = document.getElementById('item-transition');
            if (itemTransitionEl) itemTransitionEl.value = item.transition;

            propertiesSection.style.display = 'block';
        } else {
            propertiesSection.style.display = 'none';
        }
    },

    /* Per-item property editors (wired to the right-hand "Propriétés" panel). */
    updateItemDuration: function() {
        const item = this.currentPlaylist.items[this.selectedItem];
        const el = document.getElementById('item-duration');
        if (!item || !el) return;
        item.duration = Math.max(1, parseInt(el.value, 10) || 1);
        this.renderPlaylistItems();
        this.updatePlaylistStats();
        this.setPlaylistModified(true);
        this.selectPlaylistItem(this.selectedItem);
    },

    updateItemTransition: function() {
        const item = this.currentPlaylist.items[this.selectedItem];
        const el = document.getElementById('item-transition');
        if (!item || !el) return;
        item.transition = el.value;
        this.renderPlaylistItems();
        this.setPlaylistModified(true);
        this.selectPlaylistItem(this.selectedItem);
    },

    updateTransitionDuration: function() {
        const item = this.currentPlaylist.items[this.selectedItem];
        const el = document.getElementById('transition-duration');
        if (!item || !el) return;
        item.transition_duration = Math.max(0, parseInt(el.value, 10) || 0);
        this.setPlaylistModified(true);
    },

    previewPlaylist: function() {
        if (!this.currentPlaylist.items.length) {
            PiSignage.ui.toast('Aucun élément à prévisualiser', 'warning');
            return;
        }
        if (this.currentPlaylist.name) {
            this.playPlaylist(this.currentPlaylist.name);
        } else {
            PiSignage.ui.toast('Sauvegardez la playlist avant de la prévisualiser', 'info');
        }
    },

    clearPlaylist: function() {
        if (!this.currentPlaylist.items.length) return;
        if (!PiSignage.ui.confirm('Vider la playlist en cours ?')) return;
        this.currentPlaylist.items = [];
        this.selectedItem = null;
        this.renderPlaylistItems();
        this.updatePlaylistStats();
        this.updatePropertiesPanel();
        this.setPlaylistModified(true);
        PiSignage.ui.toast('Playlist vidée', 'success');
    },

    removePlaylistItem: function(index) {
        this.currentPlaylist.items.splice(index, 1);

        // Update order values
        this.currentPlaylist.items.forEach((item, i) => {
            item.order = i;
        });

        this.renderPlaylistItems();
        this.updatePlaylistStats();
        this.setPlaylistModified(true);

        // Clear selection if removed item was selected
        if (this.selectedItem === index) {
            this.selectedItem = null;
            this.updatePropertiesPanel();
        } else if (this.selectedItem > index) {
            this.selectedItem--;
        }
    },

    updatePlaylistStats: function() {
        const itemCount = this.currentPlaylist.items.length;
        const totalDuration = this.currentPlaylist.items.reduce((sum, item) => sum + item.duration, 0);

        const itemCountEl = document.getElementById('item-count');
        if (itemCountEl) itemCountEl.textContent = `${itemCount} élément${itemCount !== 1 ? 's' : ''}`;

        const totalDurationEl = document.getElementById('total-duration');
        if (totalDurationEl) totalDurationEl.textContent = PiSignage.utils.formatTime(totalDuration);

        // Enable/disable buttons
        const hasItems = itemCount > 0;
        const previewBtn = document.getElementById('preview-btn');
        if (previewBtn) previewBtn.disabled = !hasItems;

        const saveBtn = document.getElementById('save-playlist-btn');
        if (saveBtn) saveBtn.disabled = !hasItems || !this.currentPlaylist.name;
    },

    resetPlaylistEditor: function() {
        this.currentPlaylist = {
            name: '',
            items: [],
            settings: {
                loop: true,
                shuffle: false,
                auto_advance: true,
                fade_duration: 1000
            }
        };

        this.selectedItem = null;
        this.setPlaylistModified(false);

        // Update UI elements
        const nameInput = document.getElementById('playlist-name-input');
        if (nameInput) nameInput.value = '';

        const nameDisplay = document.getElementById('playlist-name-display');
        if (nameDisplay) nameDisplay.textContent = 'Nouvelle playlist';

        this.renderPlaylistItems();
        this.updatePlaylistStats();
        this.updatePropertiesPanel();

        // Show visual feedback
        PiSignage.ui.toast('Nouvelle playlist prête à être éditée', 'success');
    },

    updatePlaylistName: function() {
        const nameInput = document.getElementById('playlist-name-input');
        if (nameInput) {
            const newName = nameInput.value.trim();
            this.currentPlaylist.name = newName;

            // Update display
            const nameDisplay = document.getElementById('playlist-name-display');
            if (nameDisplay) {
                nameDisplay.textContent = newName || 'Nouvelle playlist';
            }

            // Update save button state
            this.setPlaylistModified(true);
        }
    },

    setPlaylistModified: function(modified) {
        this.playlistModified = modified;
        const saveBtn = document.getElementById('save-playlist-btn');
        if (saveBtn) {
            saveBtn.disabled = !modified || !this.currentPlaylist.name || this.currentPlaylist.items.length === 0;
        }
    },

    saveCurrentPlaylist: async function() {
        if (!this.currentPlaylist.name) {
            const name = prompt('Nom de la playlist:');
            if (!name) return;
            this.currentPlaylist.name = name;

            const nameInput = document.getElementById('playlist-name-input');
            if (nameInput) nameInput.value = name;

            const nameDisplay = document.getElementById('playlist-name-display');
            if (nameDisplay) nameDisplay.textContent = name;
        }

        if (this.currentPlaylist.items.length === 0) {
            PiSignage.ui.toast('La playlist doit contenir au moins un élément', 'warning');
            return;
        }

        try {
            const data = await PiSignage.api.playlists.save(this.currentPlaylist);
            if (data.success) {
                PiSignage.ui.toast(`Playlist « ${this.currentPlaylist.name} » sauvegardée`, 'success');
                this.setPlaylistModified(false);
                this.loadPlaylists(); // Refresh main playlist list
            } else {
                PiSignage.ui.toast('Erreur : ' + (data.message || 'Échec de la sauvegarde'), 'error');
            }
        } catch (error) {
            console.error('Save error:', error);
            PiSignage.ui.toast('Erreur de connexion lors de la sauvegarde', 'error');
        }
    },

    // Function to show playlist selection modal
    loadExistingPlaylist: function() {
        if (this.currentPlaylists.length === 0) {
            PiSignage.ui.toast('Aucune playlist disponible', 'info');
            return;
        }

        const esc = (s) => String(s).replace(/[&<>"']/g, c => (
            { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
        ));

        // Reuse the static modal shell from playlists.php; only fill its list body.
        const modal = document.getElementById('load-playlist-modal');
        const list = document.getElementById('existing-playlists-list');
        if (!modal || !list) return;

        list.innerHTML = this.currentPlaylists.map(playlist => `
            <div class="existing-playlist-item" onclick="PiSignage.playlists.selectAndLoadPlaylist('${esc(playlist.name)}')">
                <div class="existing-playlist-info">
                    <h4>${esc(playlist.name)}</h4>
                    <span class="existing-playlist-meta">${playlist.items ? playlist.items.length : 0} éléments</span>
                </div>
            </div>
        `).join('');

        PiSignage.ui.openModal(modal);
    },

    selectAndLoadPlaylist: function(playlistName) {
        const playlist = this.currentPlaylists.find(p => p.name === playlistName);
        if (playlist) {
            this.currentPlaylist = {
                name: playlist.name,
                items: playlist.items || [],
                settings: playlist.settings || {
                    loop: true,
                    shuffle: false,
                    auto_advance: true,
                    fade_duration: 1000
                }
            };
            this.renderPlaylistItems();
            this.renderMediaLibrary();
            this.updatePropertiesPanel();
            PiSignage.ui.closeModal('load-playlist-modal');
            PiSignage.ui.toast(`Playlist « ${playlistName} » chargée`, 'success');
        }
    },

    // Setup global functions for backward compatibility
    setupGlobalFunctions: function() {
        window.loadPlaylists = this.loadPlaylists.bind(this);
        window.createPlaylist = this.createPlaylist.bind(this);
        window.editPlaylist = this.editPlaylist.bind(this);
        window.deletePlaylist = this.deletePlaylist.bind(this);
        window.playPlaylist = this.playPlaylist.bind(this);
        window.initPlaylistEditor = this.initPlaylistEditor.bind(this);
        window.saveCurrentPlaylist = this.saveCurrentPlaylist.bind(this);
        window.createNewPlaylist = this.resetPlaylistEditor.bind(this);
        window.loadExistingPlaylist = this.loadExistingPlaylist.bind(this);
        window.selectAndLoadPlaylist = this.selectAndLoadPlaylist.bind(this);
        window.updatePlaylistName = this.updatePlaylistName.bind(this);

        // Item property editors + workspace actions (wired in playlists.php markup)
        window.updateItemDuration = this.updateItemDuration.bind(this);
        window.updateItemTransition = this.updateItemTransition.bind(this);
        window.updateTransitionDuration = this.updateTransitionDuration.bind(this);
        window.previewPlaylist = this.previewPlaylist.bind(this);
        window.clearPlaylist = this.clearPlaylist.bind(this);

        // Media library functions
        window.refreshMediaLibrary = this.loadMediaLibrary.bind(this);
        window.filterMediaLibrary = this.renderMediaLibrary.bind(this);
        window.filterMediaType = function(type) {
            // Update active button
            document.querySelectorAll('.filter-btn').forEach(btn => {
                btn.classList.toggle('active', btn.dataset.type === type);
            });
            // Re-render with new filter
            PiSignage.playlists.renderMediaLibrary();
        };

        // Playlist settings functions
        window.updatePlaylistSettings = this.updatePropertiesPanel.bind(this);
    }
};

// Ensure global functions are available immediately when script loads
// This handles onclick bindings in HTML before DOMContentLoaded
if (typeof window !== 'undefined') {
    if (typeof PiSignage !== 'undefined' && PiSignage.playlists) {
        PiSignage.playlists.setupGlobalFunctions();
    } else {
        console.error('PiSignage.playlists not ready for global function setup');
    }
}

// Layout/structure for the playlist editor lives in pages.css (design tokens,
// light/dark aware). Only the transient drag-over highlight is added here,
// expressed via CSS variables so it tracks both themes.
const playlistStyles = document.createElement('style');
playlistStyles.textContent = `
    .playlist-card { transition: transform .2s, box-shadow .2s; }
    .playlist-card:hover { transform: translateY(-2px); box-shadow: var(--shadow-lg); }
    .playlist-header { margin-bottom: 15px; }
    .playlist-info { display: flex; gap: 15px; font-size: 12px; color: var(--text-dim); margin-top: 5px; }
    .playlist-actions { display: flex; gap: 10px; justify-content: flex-end; flex-wrap: wrap; }
    #playlist-drop-zone.drag-over { border: 2px dashed var(--accent); border-radius: var(--radius-sm); background-color: var(--accent-soft); }
`;
document.head.appendChild(playlistStyles);

console.log('PiSignage Playlists module loaded');