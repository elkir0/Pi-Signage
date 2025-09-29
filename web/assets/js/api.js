/**
 * PiSignage API Communication Layer
 * Handles all AJAX/API calls with error handling and retries
 */

// Ensure PiSignage namespace exists
window.PiSignage = window.PiSignage || {};

// API configuration and utilities
PiSignage.api = {
    baseUrl: '',
    timeout: 30000,
    retryAttempts: 3,
    retryDelay: 1000,

    // Generic fetch wrapper with error handling
    request: async function(url, options = {}) {
        const defaultOptions = {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
            },
            timeout: this.timeout,
            ...options
        };

        let attempt = 0;
        while (attempt < this.retryAttempts) {
            try {
                const response = await fetch(url, defaultOptions);

                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }

                const data = await response.json();
                return data;
            } catch (error) {
                attempt++;
                console.error(`API request failed (attempt ${attempt}/${this.retryAttempts}):`, error);

                if (attempt < this.retryAttempts) {
                    await this.delay(this.retryDelay * attempt);
                } else {
                    throw error;
                }
            }
        }
    },

    delay: function(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    },

    // System API calls
    system: {
        getStats: function() {
            return PiSignage.api.request('/api/stats.php');
        },

        switchPlayer: function(newPlayer, currentPlayer) {
            return PiSignage.api.request('/api/system.php', {
                method: 'POST',
                body: JSON.stringify({
                    action: 'switch_player',
                    player: newPlayer,
                    current_player: currentPlayer
                })
            });
        },

        getCurrentPlayer: function() {
            return PiSignage.api.request('/api/system.php?action=get_player');
        },

        restart: function() {
            return PiSignage.api.request('/api/system.php?action=restart');
        },

        shutdown: function() {
            return PiSignage.api.request('/api/system.php?action=shutdown');
        },

        systemAction: function(action) {
            return PiSignage.api.request('/api/system.php', {
                method: 'POST',
                body: JSON.stringify({ action })
            });
        }
    },

    // Media API calls
    media: {
        list: function() {
            return PiSignage.api.request('/api/media.php');
        },

        delete: function(filename) {
            return PiSignage.api.request('/api/media.php', {
                method: 'DELETE',
                body: JSON.stringify({
                    filename: filename,
                    action: 'delete'
                })
            });
        },

        upload: function(files, onProgress = null) {
            return new Promise((resolve, reject) => {
                const formData = new FormData();

                for (let file of files) {
                    formData.append('files[]', file);
                }

                const xhr = new XMLHttpRequest();

                // Progress handler
                if (onProgress) {
                    xhr.upload.addEventListener('progress', function(e) {
                        if (e.lengthComputable) {
                            const percentComplete = Math.round((e.loaded / e.total) * 100);
                            onProgress({
                                loaded: e.loaded,
                                total: e.total,
                                percent: percentComplete
                            });
                        }
                    });
                }

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
                        reject(new Error('File too large (max 100MB)'));
                    } else if (xhr.status === 500) {
                        reject(new Error('Server error - check PHP limits'));
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
    },

    // Player API calls
    player: {
        control: function(action, params = {}) {
            return PiSignage.api.request('/api/player-control.php', {
                method: 'POST',
                body: JSON.stringify({
                    action: action,
                    params: params
                })
            });
        },

        getStatus: function() {
            return PiSignage.api.request('/api/player-control.php?action=status');
        },

        playFile: function(file, player = null) {
            return PiSignage.api.request('/api/player.php', {
                method: 'POST',
                body: JSON.stringify({
                    action: 'play-file',
                    file: file,
                    player: player || currentPlayer
                })
            });
        },

        playPlaylist: function(playlist, player = null) {
            return PiSignage.api.request('/api/player.php', {
                method: 'POST',
                body: JSON.stringify({
                    action: 'play-playlist',
                    playlist: playlist,
                    player: player || currentPlayer
                })
            });
        },

        setVolume: function(value, player = null) {
            return PiSignage.api.request('/api/player.php', {
                method: 'POST',
                body: JSON.stringify({
                    action: 'volume',
                    value: value,
                    player: player || currentPlayer
                })
            });
        },

        restart: function() {
            return PiSignage.api.request('/api/player.php?action=restart');
        },

        // Legacy player control
        legacyControl: function(action) {
            return PiSignage.api.request('/api/player.php', {
                method: 'POST',
                body: JSON.stringify({ action: action })
            });
        }
    },

    // Playlist API calls
    playlists: {
        list: function() {
            return PiSignage.api.request('/api/playlist-simple.php');
        },

        create: function(name, items = [], settings = {}) {
            return PiSignage.api.request('/api/playlist.php', {
                method: 'POST',
                body: JSON.stringify({
                    action: 'create',
                    name: name,
                    items: items
                })
            });
        },

        update: function(oldName, newName, items, settings = {}) {
            return PiSignage.api.request('/api/playlist.php', {
                method: 'PUT',
                body: JSON.stringify({
                    action: 'update',
                    oldName: oldName,
                    name: newName,
                    items: items
                })
            });
        },

        delete: function(name) {
            return PiSignage.api.request('/api/playlist.php', {
                method: 'DELETE',
                body: JSON.stringify({
                    action: 'delete',
                    name: name
                })
            });
        },

        getInfo: function(name) {
            return PiSignage.api.request(`/api/playlist.php?action=info&name=${encodeURIComponent(name)}`);
        },

        // Advanced playlist API
        save: function(playlistData) {
            return PiSignage.api.request('/api/playlist-simple.php', {
                method: 'POST',
                body: JSON.stringify(playlistData)
            });
        }
    },

    // YouTube API calls
    youtube: {
        download: function(url, quality = 'best') {
            return PiSignage.api.request('/api/youtube-simple.php', {
                method: 'POST',
                body: JSON.stringify({
                    url: url,
                    quality: quality
                })
            });
        },

        getStatus: function() {
            return PiSignage.api.request('/api/youtube-simple.php?action=status');
        }
    },

    // Screenshot API calls
    screenshot: {
        capture: function() {
            return PiSignage.api.request('/api/screenshot.php?action=capture');
        }
    },

    // Configuration API calls
    config: {
        saveDisplay: function(resolution, rotation) {
            return PiSignage.api.request('/api/config.php', {
                method: 'POST',
                body: JSON.stringify({
                    type: 'display',
                    resolution: resolution,
                    rotation: rotation
                })
            });
        },

        saveNetwork: function(ssid, password) {
            return PiSignage.api.request('/api/config.php', {
                method: 'POST',
                body: JSON.stringify({
                    type: 'network',
                    ssid: ssid,
                    password: password
                })
            });
        }
    },

    // Logs API calls
    logs: {
        get: function() {
            return PiSignage.api.request('/api/logs.php');
        }
    }
};

// Global API functions for backward compatibility
window.refreshStats = async function() {
    try {
        const data = await PiSignage.api.system.getStats();
        if (data.success && data.data) {
            // Update all stats directly
            const stats = data.data;

            const updateElement = (id, value) => {
                const el = document.getElementById(id);
                if (el) el.textContent = value;
            };

            updateElement('cpu-usage', ((stats.cpu && stats.cpu.usage) || 0) + '%');
            updateElement('ram-usage', ((stats.memory && stats.memory.percent) || 0) + '%');
            updateElement('temperature', (stats.temperature || 0) + '°C');
            updateElement('uptime', stats.uptime || '--');
            updateElement('network', stats.network || '--');
            updateElement('media-count', (stats.media_count || 0) + ' fichiers');

            // Storage info
            const storageEl = document.getElementById('storage');
            if (storageEl && stats.disk) {
                storageEl.textContent = `${stats.disk.used_formatted} / ${stats.disk.total_formatted} (${stats.disk.percent}%)`;
            }
        }
    } catch (error) {
        console.error('Error loading stats:', error);
    }
};

window.playerControl = async function(action) {
    try {
        const data = await PiSignage.api.player.control(action);
        if (data.success) {
            if (data.status && typeof updatePlayerUI === 'function') {
                updatePlayerUI(data.status);
            }
            showAlert(`${action} exécuté`, 'success');
        } else {
            showAlert(data.message || `Erreur: ${action}`, 'error');
        }
    } catch (error) {
        console.error('Player control error:', error);
        showAlert('Erreur de communication', 'error');
    }
};

window.systemAction = async function(action) {
    if (action === 'reboot' || action === 'shutdown') {
        if (!confirm(`Êtes-vous sûr de vouloir ${action}?`)) return;
    }

    try {
        const data = await PiSignage.api.system.systemAction(action);
        if (data.success) {
            showAlert(`Action ${action} exécutée!`, 'success');
        } else {
            showAlert('Erreur: ' + data.message, 'error');
        }
    } catch (error) {
        console.error('System action error:', error);
        showAlert('Erreur système', 'error');
    }
};

console.log('✅ PiSignage API module loaded - All communication functions ready');