/**
 * PiSignage Player Control Module
 * Handles all player operations, status updates, and controls
 */

// Ensure PiSignage namespace exists
window.PiSignage = window.PiSignage || {};

// Player control functionality
PiSignage.player = {
    // Player state (extended from core.js)
    state: {
        isPlaying: false,
        isPaused: false,
        currentFile: null,
        position: 0,
        duration: 0,
        volume: 50,
        isMuted: false,
        isLooping: false,
        isShuffling: false
    },

    intervals: {
        status: null
    },

    init: function() {
        console.log('🎮 Initializing player controls...');
        this.getCurrentPlayer();
        this.initializePlayer();
        this.startStatusUpdates();
        this.setupGlobalFunctions();
    },

    getCurrentPlayer: async function() {
        try {
            const data = await PiSignage.api.system.getCurrentPlayer();
            if (data.success) {
                const player = data.player || 'vlc';
                this.setCurrentPlayer(player);
                this.updatePlayerInterface();

                // Update radio buttons
                const radioBtn = document.getElementById('player-' + player);
                if (radioBtn) {
                    radioBtn.checked = true;
                }
            }
        } catch (error) {
            console.error('Get player error:', error);
            // Use VLC as default fallback
            this.setCurrentPlayer('vlc');
            this.updatePlayerInterface();
        }
    },

    setCurrentPlayer: function(player) {
        currentPlayer = player;
        selectedPlayer = player;
        PiSignage.config.currentPlayer = player;
        PiSignage.config.selectedPlayer = player;
    },

    getPlayerName: function() {
        return currentPlayer || 'vlc';
    },

    initializePlayer: async function() {
        // Load playlists for player
        try {
            const playlistData = await PiSignage.api.playlists.list();
            if (playlistData.success && playlistData.data) {
                const playlistSelect = document.getElementById('playlist-select');
                if (playlistSelect) {
                    playlistSelect.innerHTML = '<option value="">-- Sélectionner une playlist --</option>';
                    playlistData.data.forEach(playlist => {
                        playlistSelect.innerHTML += `<option value="${playlist.name}">${playlist.name}</option>`;
                    });
                }
            }
        } catch (error) {
            console.error('Error loading playlists for player:', error);
        }

        // Load media files for player
        try {
            const mediaData = await PiSignage.api.media.list();
            if (mediaData.success && mediaData.data) {
                const mediaSelect = document.getElementById('media-select');
                if (mediaSelect) {
                    mediaSelect.innerHTML = '<option value="">-- Sélectionner un fichier --</option>';
                    mediaData.data.forEach(file => {
                        mediaSelect.innerHTML += `<option value="${file.name}">${file.name}</option>`;
                    });
                }
            }
        } catch (error) {
            console.error('Error loading media for player:', error);
        }

        // Start status polling
        this.refreshPlayerStatus();
    },

    startStatusUpdates: function() {
        // Clear existing interval
        if (this.intervals.status) {
            clearInterval(this.intervals.status);
        }

        // Start new interval
        this.intervals.status = setInterval(() => {
            this.refreshPlayerStatus();
        }, 3000);

        console.log('🎮 Player status updates started (3s interval)');
    },

    stopStatusUpdates: function() {
        if (this.intervals.status) {
            clearInterval(this.intervals.status);
            this.intervals.status = null;
            console.log('🎮 Player status updates stopped');
        }
    },

    refreshPlayerStatus: async function() {
        try {
            const data = await PiSignage.api.player.getStatus();
            if (data.success && data.data) {
                this.updatePlayerUI(data.data);
            }
        } catch (error) {
            console.error('Error fetching player status:', error);
        }
    },

    updatePlayerUI: function(status) {
        if (!status) return;

        // Update player state
        this.state.isPlaying = status.state === 'playing';
        this.state.isPaused = status.state === 'paused';
        this.state.currentFile = status.current_file;
        this.state.position = status.position || 0;
        this.state.duration = status.duration || 0;
        this.state.volume = status.volume || 50;

        // Update Now Playing
        const titleEl = document.getElementById('now-playing-title');
        const metaEl = document.getElementById('player-state');
        const statusEl = document.getElementById('status-indicator');
        const statusTextEl = document.getElementById('status-text');

        if (titleEl) {
            if (status.current_file) {
                titleEl.textContent = status.current_file;
            } else {
                titleEl.textContent = 'Aucun média en lecture';
            }
        }

        // Update status indicator and player state display
        if (metaEl) {
            switch (status.state) {
                case 'playing':
                    metaEl.textContent = 'En lecture';
                    metaEl.style.color = '#51cf66';
                    if (statusEl) statusEl.className = 'status-indicator playing';
                    if (statusTextEl) statusTextEl.textContent = 'En ligne';
                    this.updatePlayPauseButton('⏸️');
                    break;
                case 'paused':
                    metaEl.textContent = 'En pause';
                    metaEl.style.color = '#ffd43b';
                    if (statusEl) statusEl.className = 'status-indicator paused';
                    if (statusTextEl) statusTextEl.textContent = 'En pause';
                    this.updatePlayPauseButton('▶️');
                    break;
                default:
                    metaEl.textContent = 'Arrêté';
                    metaEl.style.color = '#ffd43b';
                    if (statusEl) statusEl.className = 'status-indicator';
                    if (statusTextEl) statusTextEl.textContent = 'Hors ligne';
                    this.updatePlayPauseButton('▶️');
            }
        }

        // Update file and position display
        const fileElement = document.getElementById('player-file');
        if (fileElement) {
            fileElement.textContent = status.current_file || 'Aucun';
        }

        const positionElement = document.getElementById('player-position');
        if (positionElement) {
            positionElement.textContent = status.position || '00:00';
        }

        // Update progress bar if available
        if (this.state.duration > 0) {
            const progress = (this.state.position / this.state.duration) * 100;

            const progressFill = document.getElementById('progress-fill');
            if (progressFill) progressFill.style.width = progress + '%';

            const seekBar = document.getElementById('seek-bar');
            if (seekBar) seekBar.value = progress;

            const timeCurrent = document.getElementById('time-current');
            if (timeCurrent) timeCurrent.textContent = PiSignage.utils.formatTime(this.state.position);

            const timeTotal = document.getElementById('time-total');
            if (timeTotal) timeTotal.textContent = PiSignage.utils.formatTime(this.state.duration);
        }

        // Update volume controls
        this.updateVolumeControls();

        // Update system stats if available
        if (status.system) {
            const updateStat = (id, value) => {
                const el = document.getElementById(id);
                if (el) el.textContent = value;
            };

            // Safe access with optional chaining and fallbacks
            updateStat('player-cpu', (status.system?.cpu || 0) + '%');
            updateStat('player-memory', (status.system?.memory?.percent || 0) + '%');
            updateStat('player-temp', (status.system?.temperature || 'N/A') + '°C');
            updateStat('player-uptime', status.system?.uptime || '--');
        }
    },

    updatePlayPauseButton: function(text) {
        const playPauseBtn = document.getElementById('play-pause-btn');
        if (playPauseBtn) {
            playPauseBtn.textContent = text;
        }
    },

    updateVolumeControls: function() {
        const volumeSlider = document.getElementById('volume-slider');
        if (volumeSlider) volumeSlider.value = this.state.volume;

        const volumeFill = document.getElementById('volume-fill');
        if (volumeFill) volumeFill.style.width = this.state.volume + '%';

        const volumeValue = document.getElementById('volume-value');
        if (volumeValue) volumeValue.textContent = Math.round(this.state.volume) + '%';
    },

    updatePlayerInterface: function() {
        const player = this.getPlayerName();
        const playerName = player.toUpperCase();

        // Update main status display
        const currentPlayerEl = document.getElementById('current-player');
        if (currentPlayerEl) {
            currentPlayerEl.textContent = playerName;
            currentPlayerEl.style.color = player === 'vlc' ? '#4a9eff' : '#51cf66';
        }

        // Update controls section if present
        const controlsNameEl = document.getElementById('player-controls-name');
        if (controlsNameEl) {
            controlsNameEl.textContent = `Contrôles ${playerName}`;
        }

        // Update restart button text
        const restartTextEl = document.getElementById('restart-player-text');
        if (restartTextEl) {
            restartTextEl.textContent = `Redémarrer ${playerName}`;
        }

        // Update radio buttons
        document.querySelectorAll('input[name="player"]').forEach(radio => {
            radio.checked = (radio.value === player);
        });

        // Adapt button colors based on player
        const playerButtons = document.querySelectorAll('.player-btn');
        playerButtons.forEach(btn => {
            if (player === 'vlc') {
                btn.style.background = 'linear-gradient(135deg, #4a9eff, #3d7edb)';
            } else {
                btn.style.background = 'linear-gradient(135deg, #51cf66, #3eb854)';
            }
        });
    },

    // Player control functions
    control: async function(action) {
        try {
            const data = await PiSignage.api.player.control(action);
            if (data.success) {
                if (data.status) {
                    this.updatePlayerUI(data.status);
                }
                showAlert(`${action} exécuté`, 'success');
            } else {
                showAlert(data.message || `Erreur: ${action}`, 'error');
            }
        } catch (error) {
            console.error('Player control error:', error);
            showAlert('Erreur de communication', 'error');
        }
    },

    togglePlayPause: function() {
        const action = this.state.isPlaying ? 'pause' : 'play';
        this.control(action);
    },

    seekTo: async function(percentage) {
        const position = (this.state.duration * percentage) / 100;
        try {
            const data = await PiSignage.api.player.control('seek', { position: position });
            if (data.status) {
                this.updatePlayerUI(data.status);
            }
        } catch (error) {
            console.error('Seek error:', error);
        }
    },

    setVolume: async function(volume) {
        this.state.volume = volume;
        this.updateVolumeControls();

        try {
            await PiSignage.api.player.control('volume', { volume: volume });
        } catch (error) {
            console.error('Volume error:', error);
        }
    },

    toggleMute: function() {
        this.state.isMuted = !this.state.isMuted;
        const muteBtn = document.getElementById('mute-btn');

        if (this.state.isMuted) {
            if (muteBtn) muteBtn.textContent = '🔇';
            this.setVolume(0);
        } else {
            if (muteBtn) muteBtn.textContent = '🔊';
            this.setVolume(this.state.volume || 50);
        }
    },

    toggleLoop: async function() {
        this.state.isLooping = !this.state.isLooping;
        const loopBtn = document.getElementById('loop-btn');
        if (loopBtn) loopBtn.classList.toggle('active');

        try {
            await PiSignage.api.player.control('set_loop', { enabled: this.state.isLooping });
        } catch (error) {
            console.error('Loop error:', error);
        }
    },

    toggleShuffle: async function() {
        this.state.isShuffling = !this.state.isShuffling;
        const shuffleBtn = document.getElementById('shuffle-btn');
        if (shuffleBtn) shuffleBtn.classList.toggle('active');

        try {
            await PiSignage.api.player.control('set_random', { enabled: this.state.isShuffling });
        } catch (error) {
            console.error('Shuffle error:', error);
        }
    },

    // Media and playlist playback
    loadPlaylist: async function() {
        const playlistSelect = document.getElementById('playlist-select');
        const playlistName = playlistSelect ? playlistSelect.value : '';

        if (!playlistName) {
            showAlert('Veuillez sélectionner une playlist', 'warning');
            return;
        }

        try {
            const data = await PiSignage.api.player.control('load_playlist', { name: playlistName });
            if (data.success) {
                showAlert(`Playlist "${playlistName}" chargée`, 'success');
                this.refreshPlayerStatus();
            } else {
                showAlert(data.message || 'Erreur lors du chargement', 'error');
            }
        } catch (error) {
            console.error('Load playlist error:', error);
            showAlert('Erreur de chargement', 'error');
        }
    },

    playMediaFile: async function() {
        const mediaSelect = document.getElementById('media-select');
        const file = mediaSelect ? mediaSelect.value : '';

        if (!file) {
            showAlert('Veuillez sélectionner un fichier', 'warning');
            return;
        }

        try {
            const data = await PiSignage.api.player.control('play_file', { file: file });
            if (data.success) {
                showAlert(`Lecture de ${file}`, 'success');
                this.refreshPlayerStatus();
            } else {
                showAlert(data.message || 'Erreur de lecture', 'error');
            }
        } catch (error) {
            console.error('Play file error:', error);
            showAlert('Erreur de lecture', 'error');
        }
    },

    addMediaToQueue: async function() {
        const mediaSelect = document.getElementById('media-select');
        const file = mediaSelect ? mediaSelect.value : '';

        if (!file) {
            showAlert('Veuillez sélectionner un fichier', 'warning');
            return;
        }

        try {
            const data = await PiSignage.api.player.control('add_to_playlist', { file: file });
            if (data.success) {
                showAlert(`${file} ajouté à la file d'attente`, 'success');
                this.refreshPlayerStatus();
            } else {
                showAlert(data.message || 'Erreur', 'error');
            }
        } catch (error) {
            console.error('Add to queue error:', error);
            showAlert('Erreur d\'ajout', 'error');
        }
    },

    // Legacy player functions for single file and playlist
    playSingleFile: async function() {
        const fileSelect = document.getElementById('single-file-select');
        const file = fileSelect ? fileSelect.value : '';

        if (!file) {
            showAlert('Sélectionnez un fichier', 'error');
            return;
        }

        const playerName = this.getPlayerName().toUpperCase();

        try {
            const data = await PiSignage.api.player.playFile(file, this.getPlayerName());
            if (data.success) {
                showAlert(data.message || `${playerName}: Lecture de ${file} démarrée!`, 'success');
                setTimeout(() => this.refreshPlayerStatus(), 500);
            } else {
                showAlert(data.message || `Erreur ${playerName}: Lecture impossible`, 'error');
            }
        } catch (error) {
            console.error('Play single file error:', error);
            showAlert(`Erreur de communication avec ${playerName}`, 'error');
        }
    },

    playPlaylist: async function() {
        const playlistSelect = document.getElementById('playlist-select');
        const playlist = playlistSelect ? playlistSelect.value : '';

        if (!playlist) {
            showAlert('Sélectionnez une playlist', 'error');
            return;
        }

        const playerName = this.getPlayerName().toUpperCase();

        try {
            const data = await PiSignage.api.player.playPlaylist(playlist, this.getPlayerName());
            if (data.success) {
                showAlert(data.message || `${playerName}: Playlist ${playlist} lancée!`, 'success');
                setTimeout(() => this.refreshPlayerStatus(), 500);
            } else {
                showAlert(`Erreur ${playerName}: ` + data.message, 'error');
            }
        } catch (error) {
            console.error('Play playlist error:', error);
            showAlert(`Erreur de communication avec ${playerName}`, 'error');
        }
    },

    // Player management
    restartCurrentPlayer: async function() {
        const player = this.getPlayerName();
        const playerName = player.toUpperCase();

        showAlert(`Redémarrage de ${playerName}...`, 'info');

        try {
            const data = await PiSignage.api.player.restart();
            if (data.success) {
                showAlert(`${playerName} redémarré avec succès`, 'success');
                setTimeout(() => {
                    this.refreshPlayerStatus();
                    this.updatePlayerInterface();
                }, 2000);
            } else {
                showAlert(data.message || 'Erreur lors du redémarrage', 'error');
            }
        } catch (error) {
            console.error('Restart player error:', error);
            showAlert('Erreur de communication', 'error');
        }
    },

    // Queue management
    showPlaylistQueue: async function() {
        const queueSection = document.getElementById('queue-section');
        if (!queueSection) return;

        const isVisible = queueSection.style.display !== 'none';
        queueSection.style.display = isVisible ? 'none' : 'block';

        if (!isVisible) {
            // Load queue items
            try {
                const data = await PiSignage.api.player.getStatus();
                if (data.success && data.data && data.data.playlist) {
                    this.renderQueueItems(data.data.playlist);
                }
            } catch (error) {
                console.error('Load queue error:', error);
            }
        }
    },

    renderQueueItems: function(playlist) {
        const queueList = document.getElementById('queue-list');
        if (!queueList) return;

        if (!playlist || playlist.length === 0) {
            queueList.innerHTML = '<div class="empty-state">File d\'attente vide</div>';
            return;
        }

        queueList.innerHTML = playlist.map((item, index) => `
            <div class="queue-item ${item.current ? 'current' : ''}" data-index="${index}">
                <span class="queue-number">${index + 1}</span>
                <span class="queue-name">${item.name}</span>
                ${item.current ? '<span class="queue-current">▶️</span>' : ''}
            </div>
        `).join('');
    },

    // Global function setup for backward compatibility
    setupGlobalFunctions: function() {
        // Player control functions
        window.playerControl = this.control.bind(this);
        window.updatePlayerStatus = this.refreshPlayerStatus.bind(this);
        window.updatePlayerInterface = this.updatePlayerInterface.bind(this);
        window.getCurrentPlayer = this.getCurrentPlayer.bind(this);
        window.initializePlayer = this.initializePlayer.bind(this);

        // Media playback functions
        window.playSingleFile = this.playSingleFile.bind(this);
        window.playPlaylist = this.playPlaylist.bind(this);
        window.playMediaFile = this.playMediaFile.bind(this);
        window.loadPlaylist = this.loadPlaylist.bind(this);
        window.addMediaToQueue = this.addMediaToQueue.bind(this);
        window.showPlaylistQueue = this.showPlaylistQueue.bind(this);

        // Player management functions
        window.restartCurrentPlayer = this.restartCurrentPlayer.bind(this);
        window.setVolume = this.setVolume.bind(this);

        // Player state functions
        window.togglePlayPause = this.togglePlayPause.bind(this);
        window.seekTo = this.seekTo.bind(this);
        window.toggleMute = this.toggleMute.bind(this);
        window.toggleLoop = this.toggleLoop.bind(this);
        window.toggleShuffle = this.toggleShuffle.bind(this);

        // Update player UI function
        window.updatePlayerUI = this.updatePlayerUI.bind(this);
    }
};

// CSS for player controls
const playerStyles = document.createElement('style');
playerStyles.textContent = `
    .player-btn {
        transition: all 0.2s;
    }

    .player-btn:hover {
        transform: scale(1.05);
        box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    }

    .queue-item {
        display: flex;
        align-items: center;
        padding: 8px;
        border-radius: 5px;
        margin-bottom: 5px;
        transition: background-color 0.2s;
    }

    .queue-item:hover {
        background-color: rgba(74, 158, 255, 0.1);
    }

    .queue-item.current {
        background-color: rgba(74, 158, 255, 0.2);
        border: 1px solid #4a9eff;
    }

    .queue-number {
        margin-right: 10px;
        color: #666;
        min-width: 20px;
    }

    .queue-name {
        flex: 1;
    }

    .queue-current {
        margin-left: 10px;
        color: #51cf66;
    }

    .status-indicator {
        width: 12px;
        height: 12px;
        border-radius: 50%;
        background-color: #666;
        display: inline-block;
        margin-right: 8px;
    }

    .status-indicator.playing {
        background-color: #51cf66;
        animation: pulse 2s infinite;
    }

    .status-indicator.paused {
        background-color: #ffd43b;
    }

    @keyframes pulse {
        0% { opacity: 1; }
        50% { opacity: 0.5; }
        100% { opacity: 1; }
    }
`;
document.head.appendChild(playerStyles);

console.log('✅ PiSignage Player module loaded - All player controls ready');