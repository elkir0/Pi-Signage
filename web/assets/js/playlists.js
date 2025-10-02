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

    init: function() {
        console.log('🎵 Initializing playlist management...');
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
                console.log(`🎵 Loaded ${this.currentPlaylists.length} playlists`);
            } else {
                console.error('Failed to load playlists:', data.message);
            }
        } catch (error) {
            console.error('Error loading playlists:', error);
            showAlert('Erreur de chargement des playlists', 'error');
        }
    },

    renderPlaylistsList: function() {
        const container = document.getElementById('playlist-container');
        if (!container) return;

        if (this.currentPlaylists.length === 0) {
            container.innerHTML = `
                <div class="empty-state" style="text-align: center; padding: 40px; color: #666;">
                    <h3>🎵 Aucune playlist</h3>
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
                        ▶️ Lire
                    </button>
                    <button class="btn btn-glass btn-sm" onclick="PiSignage.playlists.editPlaylist('${playlist.name}')" title="Modifier cette playlist">
                        ✏️ Modifier
                    </button>
                    <button class="btn btn-danger btn-sm" onclick="PiSignage.playlists.deletePlaylist('${playlist.name}')" title="Supprimer cette playlist">
                        🗑️ Supprimer
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
                showAlert('Playlist créée!', 'success');
                this.loadPlaylists();
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Create playlist error:', error);
            showAlert('Erreur de création', 'error');
        }
    },

    editPlaylist: async function(name) {
        try {
            const data = await PiSignage.api.playlists.getInfo(name);
            if (data.success && data.data) {
                this.showEditModal(data.data);
            } else {
                showAlert('Erreur lors du chargement de la playlist', 'error');
            }
        } catch (error) {
            console.error('Edit playlist error:', error);
            showAlert('Erreur de chargement', 'error');
        }
    },

    showEditModal: function(playlist) {
        const modalHTML = `
            <div id="editPlaylistModal" class="modal" style="
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                bottom: 0;
                background: rgba(0,0,0,0.7);
                display: flex;
                justify-content: center;
                align-items: center;
                z-index: 10000;
            ">
                <div class="modal-content" style="
                    background: #2a2d3a;
                    padding: 30px;
                    border-radius: 15px;
                    width: 600px;
                    max-width: 90%;
                    max-height: 80vh;
                    overflow-y: auto;
                    position: relative;
                ">
                    <span class="close" style="
                        position: absolute;
                        top: 15px;
                        right: 20px;
                        font-size: 24px;
                        cursor: pointer;
                        color: #ccc;
                    " onclick="PiSignage.playlists.closeEditModal()">&times;</span>

                    <h2 style="margin: 0 0 20px; color: #4a9eff;">✏️ Modifier Playlist: ${playlist.name}</h2>

                    <div style="margin-bottom: 20px;">
                        <label style="display: block; margin-bottom: 5px; color: #ccc;">Nom de la playlist:</label>
                        <input type="text" id="edit-playlist-name" value="${playlist.name}" style="
                            width: 100%;
                            padding: 10px;
                            background: #1a1a2e;
                            border: 1px solid #4a9eff;
                            border-radius: 5px;
                            color: white;
                            font-size: 14px;
                        ">
                    </div>

                    <div style="margin-bottom: 20px;">
                        <label style="display: block; margin-bottom: 5px; color: #ccc;">Fichiers dans la playlist:</label>
                        <div id="edit-playlist-items" style="
                            max-height: 200px;
                            overflow-y: auto;
                            border: 1px solid #4a9eff;
                            padding: 15px;
                            border-radius: 5px;
                            background: rgba(26, 26, 46, 0.5);
                        ">
                            ${playlist.items.map(item => `
                                <div style="margin-bottom: 8px; display: flex; align-items: center;">
                                    <input type="checkbox" id="item-${item}" value="${item}" checked style="margin-right: 10px;">
                                    <label for="item-${item}" style="color: white; flex: 1;">${item}</label>
                                </div>
                            `).join('')}
                        </div>
                    </div>

                    <div style="margin-bottom: 20px;">
                        <label style="display: block; margin-bottom: 5px; color: #ccc;">Ajouter des fichiers:</label>
                        <select id="add-files-select" multiple style="
                            width: 100%;
                            height: 120px;
                            background: #1a1a2e;
                            border: 1px solid #4a9eff;
                            color: white;
                            border-radius: 5px;
                            padding: 5px;
                        ">
                            <!-- Will be populated with available files -->
                        </select>
                    </div>

                    <div style="text-align: right;">
                        <button class="btn btn-primary" onclick="PiSignage.playlists.savePlaylistChanges('${playlist.name}')">💾 Sauvegarder</button>
                        <button class="btn btn-secondary" onclick="PiSignage.playlists.closeEditModal()">Annuler</button>
                    </div>
                </div>
            </div>
        `;

        document.body.insertAdjacentHTML('beforeend', modalHTML);

        // Populate available files
        this.populateAvailableFiles(playlist.items);
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
        if (modal) modal.remove();
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
                showAlert('Playlist modifiée!', 'success');
                this.closeEditModal();
                this.loadPlaylists();
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Save playlist error:', error);
            showAlert('Erreur de sauvegarde', 'error');
        }
    },

    deletePlaylist: async function(name) {
        if (!confirm(`Supprimer la playlist "${name}"?`)) return;

        try {
            const data = await PiSignage.api.playlists.delete(name);
            if (data.success) {
                showAlert('Playlist supprimée!', 'success');
                this.loadPlaylists();
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Delete playlist error:', error);
            showAlert('Erreur de suppression', 'error');
        }
    },

    playPlaylist: async function(name) {
        try {
            const currentPlayer = PiSignage.player.getCurrentPlayer();
            const data = await PiSignage.api.player.playPlaylist(name, currentPlayer);
            if (data.success) {
                showAlert(`Playlist ${name} lancée!`, 'success');
                // Update player status
                setTimeout(() => {
                    if (typeof updatePlayerStatus === 'function') {
                        updatePlayerStatus();
                    }
                }, 500);
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Play playlist error:', error);
            showAlert('Erreur de lecture', 'error');
        }
    },

    // Advanced Playlist Editor Functions
    initPlaylistEditor: function() {
        console.log('🎬 Initializing advanced playlist editor...');
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
                        <button class="btn-add" onclick="PiSignage.playlists.addMediaToPlaylist('${file.name}')" title="Ajouter à la playlist">
                            +
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
        const icons = {
            video: '🎬',
            audio: '🎵',
            image: '🖼️',
            file: '📄'
        };
        return icons[type] || icons.file;
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
                    <div class="drag-handle">⋮⋮</div>
                    <div class="playlist-item-icon ${mediaType}">
                        ${icon}
                    </div>
                    <div class="playlist-item-content">
                        <div class="playlist-item-name" title="${item.file}">${item.file}</div>
                        <div class="playlist-item-details">
                            <span>Durée: ${item.duration}s</span>
                            <span>Transition: ${item.transition}</span>
                            <span>Position: ${index + 1}</span>
                        </div>
                    </div>
                    <div class="playlist-item-actions">
                        <button class="btn btn-sm btn-danger" onclick="PiSignage.playlists.removePlaylistItem(${index})" title="Supprimer">
                            🗑️
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
        if (nameDisplay) nameDisplay.textContent = 'Nouvelle Playlist';

        this.renderPlaylistItems();
        this.updatePlaylistStats();
        this.updatePropertiesPanel();
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
            showAlert('La playlist doit contenir au moins un élément', 'warning');
            return;
        }

        try {
            const data = await PiSignage.api.playlists.save(this.currentPlaylist);
            if (data.success) {
                showAlert(`Playlist "${this.currentPlaylist.name}" sauvegardée!`, 'success');
                this.setPlaylistModified(false);
                this.loadPlaylists(); // Refresh main playlist list
            } else {
                showAlert('Erreur: ' + (data.message || 'Échec de la sauvegarde'), 'error');
            }
        } catch (error) {
            console.error('Save error:', error);
            showAlert('Erreur de connexion lors de la sauvegarde', 'error');
        }
    },

    // Function to show playlist selection modal
    loadExistingPlaylist: function() {
        if (this.currentPlaylists.length === 0) {
            showAlert('Aucune playlist disponible', 'info');
            return;
        }

        // Create modal for playlist selection
        const modal = document.createElement('div');
        modal.className = 'modal show';
        modal.style.cssText = 'display: flex; align-items: center; justify-content: center; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 10000;';

        modal.innerHTML = `
            <div class="modal-content" style="background: white; padding: 30px; border-radius: 8px; max-width: 500px; width: 90%;">
                <h3>Charger une Playlist</h3>
                <div class="playlist-list" style="max-height: 400px; overflow-y: auto; margin: 20px 0;">
                    ${this.currentPlaylists.map(playlist => `
                        <div class="playlist-item" style="padding: 10px; margin: 5px 0; border: 1px solid #ddd; border-radius: 4px; cursor: pointer;"
                             onclick="PiSignage.playlists.selectAndLoadPlaylist('${playlist.name}')">
                            <strong>${playlist.name}</strong>
                            <span style="float: right;">${playlist.items ? playlist.items.length : 0} éléments</span>
                        </div>
                    `).join('')}
                </div>
                <button class="btn btn-secondary" onclick="this.closest('.modal').remove()">Annuler</button>
            </div>
        `;

        document.body.appendChild(modal);
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
            document.querySelector('.modal.show')?.remove();
            showAlert(`Playlist "${playlistName}" chargée`, 'success');
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
    PiSignage.playlists.setupGlobalFunctions();
}

// CSS for playlist styling
const playlistStyles = document.createElement('style');
playlistStyles.textContent = `
    .playlist-card {
        transition: transform 0.2s, box-shadow 0.2s;
    }

    .playlist-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(0,0,0,0.2);
    }

    .playlist-header {
        margin-bottom: 15px;
    }

    .playlist-info {
        display: flex;
        gap: 15px;
        font-size: 12px;
        color: #ccc;
        margin-top: 5px;
    }

    .playlist-actions {
        display: flex;
        gap: 10px;
        justify-content: flex-end;
    }

    .media-item {
        cursor: grab;
        transition: transform 0.2s;
    }

    .media-item:hover {
        transform: scale(1.02);
    }

    .media-item.dragging {
        opacity: 0.5;
        cursor: grabbing;
    }

    .playlist-item {
        display: flex;
        align-items: center;
        padding: 10px;
        border: 1px solid #444;
        border-radius: 5px;
        margin-bottom: 5px;
        cursor: pointer;
        transition: background-color 0.2s;
    }

    .playlist-item:hover {
        background-color: rgba(74, 158, 255, 0.1);
    }

    .playlist-item.selected {
        background-color: rgba(74, 158, 255, 0.2);
        border-color: #4a9eff;
    }

    .drag-handle {
        margin-right: 10px;
        color: #666;
        cursor: grab;
    }

    .playlist-item-icon {
        margin-right: 10px;
        font-size: 18px;
    }

    .playlist-item-content {
        flex: 1;
    }

    .playlist-item-name {
        font-weight: bold;
        margin-bottom: 5px;
    }

    .playlist-item-details {
        font-size: 12px;
        color: #ccc;
        display: flex;
        gap: 15px;
    }

    #playlist-drop-zone.drag-over {
        border-color: #4a9eff;
        background-color: rgba(74, 158, 255, 0.1);
    }
`;
document.head.appendChild(playlistStyles);

console.log('✅ PiSignage Playlists module loaded - Playlist management and editor ready');