/**
 * PiSignage v0.8.0 - Frontend JavaScript
 * Simple, efficient, no framework needed
 */

const PiSignage = {
    version: '0.8.0',
    currentTab: 'monitoring',
    refreshInterval: null,

    init() {
        console.log(`PiSignage v${this.version} initialized`);
        this.bindNavigation();
        this.loadTab('monitoring');
        this.startMonitoring();
    },

    bindNavigation() {
        document.querySelectorAll('.ps-nav-item').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const tab = e.currentTarget.dataset.tab;
                this.loadTab(tab);
            });
        });
    },

    loadTab(tab) {
        // Update nav active state
        document.querySelectorAll('.ps-nav-item').forEach(btn => {
            btn.classList.remove('ps-nav-item--active');
        });
        document.querySelector(`[data-tab="${tab}"]`).classList.add('ps-nav-item--active');

        // Stop previous intervals
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }

        // Load content
        this.currentTab = tab;
        const content = document.getElementById('main-content');

        switch(tab) {
            case 'monitoring':
                this.loadMonitoring(content);
                break;
            case 'content':
                this.loadContent(content);
                break;
            case 'broadcast':
                this.loadBroadcast(content);
                break;
            case 'system':
                this.loadSystem(content);
                break;
        }
    },

    loadMonitoring(container) {
        container.innerHTML = `
            <div class="ps-panel">
                <h2>Monitoring Système</h2>
                <div class="ps-grid ps-grid--2">
                    <div class="ps-card">
                        <div class="ps-card__header">
                            <h3>État Actuel</h3>
                        </div>
                        <div class="ps-card__body">
                            <div id="current-screen" class="ps-screenshot">
                                <div class="ps-loading"><div class="ps-spinner"></div></div>
                            </div>
                            <button class="ps-btn ps-btn--primary ps-btn--block" onclick="PiSignage.captureScreen()">
                                Capture d'écran
                            </button>
                        </div>
                    </div>

                    <div class="ps-card">
                        <div class="ps-card__header">
                            <h3>Contrôles</h3>
                        </div>
                        <div class="ps-card__body">
                            <div class="ps-btn-group">
                                <button class="ps-btn ps-btn--success">▶ Play</button>
                                <button class="ps-btn ps-btn--warning">⏸ Pause</button>
                                <button class="ps-btn ps-btn--danger">■ Stop</button>
                            </div>
                            <div class="ps-form-group">
                                <label>Volume</label>
                                <input type="range" min="0" max="100" value="50" class="ps-slider">
                            </div>
                        </div>
                    </div>
                </div>

                <div class="ps-card">
                    <div class="ps-card__header">
                        <h3>Performances</h3>
                    </div>
                    <div class="ps-card__body" id="system-stats">
                        <div class="ps-loading"><div class="ps-spinner"></div></div>
                    </div>
                </div>
            </div>
        `;

        this.loadSystemStats();
        this.startMonitoring();
    },

    loadContent(container) {
        container.innerHTML = `
            <div class="ps-panel">
                <h2>Gestion des Médias</h2>

                <div class="ps-card">
                    <div class="ps-card__header">
                        <h3>Upload</h3>
                    </div>
                    <div class="ps-card__body">
                        <div class="ps-upload-zone" id="upload-zone">
                            <p>Glissez vos fichiers ici ou cliquez pour parcourir</p>
                            <input type="file" id="file-input" multiple accept="video/*,image/*,audio/*" style="display:none">
                        </div>
                        <div id="upload-progress"></div>
                    </div>
                </div>

                <div class="ps-card">
                    <div class="ps-card__header">
                        <h3>Bibliothèque</h3>
                        <button class="ps-btn ps-btn--sm" onclick="PiSignage.refreshMedia()">Actualiser</button>
                    </div>
                    <div class="ps-card__body">
                        <div id="media-list" class="ps-media-grid">
                            <div class="ps-loading"><div class="ps-spinner"></div></div>
                        </div>
                    </div>
                </div>

                <div class="ps-card">
                    <div class="ps-card__header">
                        <h3>YouTube Download</h3>
                    </div>
                    <div class="ps-card__body">
                        <div class="ps-form-group">
                            <input type="text" id="youtube-url" class="ps-input" placeholder="https://youtube.com/watch?v=...">
                            <button class="ps-btn ps-btn--primary" onclick="PiSignage.downloadYouTube()">
                                Télécharger
                            </button>
                        </div>
                        <div id="youtube-queue"></div>
                    </div>
                </div>
            </div>
        `;

        this.setupUploadZone();
        this.loadMediaList();
        this.loadYouTubeQueue();
    },

    loadBroadcast(container) {
        container.innerHTML = `
            <div class="ps-panel">
                <h2>Programmation</h2>

                <div class="ps-grid ps-grid--2">
                    <div class="ps-card">
                        <div class="ps-card__header">
                            <h3>Playlists</h3>
                        </div>
                        <div class="ps-card__body">
                            <div id="playlist-list">
                                <p>Aucune playlist</p>
                            </div>
                            <button class="ps-btn ps-btn--primary ps-btn--block">
                                Nouvelle Playlist
                            </button>
                        </div>
                    </div>

                    <div class="ps-card">
                        <div class="ps-card__header">
                            <h3>Calendrier</h3>
                        </div>
                        <div class="ps-card__body">
                            <div id="schedule-calendar">
                                <p>Aucune programmation</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;
    },

    loadSystem(container) {
        container.innerHTML = `
            <div class="ps-panel">
                <h2>Configuration Système</h2>

                <div class="ps-card">
                    <div class="ps-card__header">
                        <h3>Informations</h3>
                    </div>
                    <div class="ps-card__body">
                        <table class="ps-table">
                            <tr><td>Version</td><td><strong>${this.version}</strong></td></tr>
                            <tr><td>Architecture</td><td>PHP 8.1</td></tr>
                            <tr><td>Serveur</td><td>Raspberry Pi</td></tr>
                            <tr><td>IP</td><td>192.168.1.103</td></tr>
                        </table>
                    </div>
                </div>

                <div class="ps-card">
                    <div class="ps-card__header">
                        <h3>Maintenance</h3>
                    </div>
                    <div class="ps-card__body">
                        <button class="ps-btn ps-btn--warning">Redémarrer Service</button>
                        <button class="ps-btn ps-btn--danger">Nettoyer Cache</button>
                        <button class="ps-btn">Exporter Configuration</button>
                    </div>
                </div>
            </div>
        `;
    },

    // API Methods
    async captureScreen() {
        try {
            const response = await fetch('/api/screenshot');
            const data = await response.json();

            if (data.success) {
                const container = document.getElementById('current-screen');
                container.innerHTML = `<img src="${data.path}" alt="Screenshot">`;
                this.showNotification('Screenshot capturé', 'success');
            } else {
                this.showNotification(data.error, 'error');
            }
        } catch (error) {
            this.showNotification('Erreur de capture', 'error');
        }
    },

    async loadSystemStats() {
        try {
            // Simulate system stats for now
            const stats = {
                cpu: Math.floor(Math.random() * 30) + 10,
                ram: Math.floor(Math.random() * 40) + 30,
                disk: Math.floor(Math.random() * 30) + 40,
                temp: Math.floor(Math.random() * 20) + 35
            };

            document.getElementById('system-stats').innerHTML = `
                <div class="ps-stats-grid">
                    <div class="ps-stat">
                        <label>CPU</label>
                        <div class="ps-progress">
                            <div class="ps-progress__bar" style="width: ${stats.cpu}%">${stats.cpu}%</div>
                        </div>
                    </div>
                    <div class="ps-stat">
                        <label>RAM</label>
                        <div class="ps-progress">
                            <div class="ps-progress__bar" style="width: ${stats.ram}%">${stats.ram}%</div>
                        </div>
                    </div>
                    <div class="ps-stat">
                        <label>Stockage</label>
                        <div class="ps-progress">
                            <div class="ps-progress__bar" style="width: ${stats.disk}%">${stats.disk}%</div>
                        </div>
                    </div>
                    <div class="ps-stat">
                        <label>Température</label>
                        <div class="ps-temp">${stats.temp}°C</div>
                    </div>
                </div>
            `;
        } catch (error) {
            console.error('Error loading stats:', error);
        }
    },

    startMonitoring() {
        this.refreshInterval = setInterval(() => {
            if (this.currentTab === 'monitoring') {
                this.loadSystemStats();
            }
        }, 5000);
    },

    setupUploadZone() {
        const zone = document.getElementById('upload-zone');
        const input = document.getElementById('file-input');

        zone.addEventListener('click', () => input.click());
        zone.addEventListener('dragover', (e) => {
            e.preventDefault();
            zone.classList.add('ps-upload-zone--active');
        });
        zone.addEventListener('dragleave', () => {
            zone.classList.remove('ps-upload-zone--active');
        });
        zone.addEventListener('drop', (e) => {
            e.preventDefault();
            zone.classList.remove('ps-upload-zone--active');
            this.uploadFiles(e.dataTransfer.files);
        });

        input.addEventListener('change', (e) => {
            this.uploadFiles(e.target.files);
        });
    },

    async uploadFiles(files) {
        const progress = document.getElementById('upload-progress');

        for (const file of files) {
            const formData = new FormData();
            formData.append('file', file);

            try {
                const response = await fetch('/api/media', {
                    method: 'POST',
                    body: formData
                });

                const data = await response.json();
                if (data.success) {
                    this.showNotification(`${file.name} uploadé`, 'success');
                    this.loadMediaList();
                } else {
                    this.showNotification(data.error, 'error');
                }
            } catch (error) {
                this.showNotification(`Erreur upload ${file.name}`, 'error');
            }
        }
    },

    async loadMediaList() {
        try {
            const response = await fetch('/api/media');
            const media = await response.json();

            const container = document.getElementById('media-list');
            if (media.length === 0) {
                container.innerHTML = '<p>Aucun média</p>';
                return;
            }

            container.innerHTML = media.map(item => `
                <div class="ps-media-item">
                    <div class="ps-media-thumb">
                        ${item.thumbnail ? `<img src="${item.thumbnail}">` : '📁'}
                    </div>
                    <div class="ps-media-info">
                        <div class="ps-media-name">${item.name}</div>
                        <div class="ps-media-meta">${item.readable_size} - ${item.readable_date}</div>
                    </div>
                    <button class="ps-btn ps-btn--sm ps-btn--danger" onclick="PiSignage.deleteMedia('${item.name}')">
                        🗑
                    </button>
                </div>
            `).join('');
        } catch (error) {
            console.error('Error loading media:', error);
        }
    },

    async deleteMedia(filename) {
        if (!confirm(`Supprimer ${filename} ?`)) return;

        try {
            const response = await fetch(`/api/media?filename=${filename}`, {
                method: 'DELETE'
            });

            const data = await response.json();
            if (data.success) {
                this.showNotification('Média supprimé', 'success');
                this.loadMediaList();
            }
        } catch (error) {
            this.showNotification('Erreur suppression', 'error');
        }
    },

    async downloadYouTube() {
        const url = document.getElementById('youtube-url').value;
        if (!url) return;

        try {
            const response = await fetch('/api/youtube', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({url})
            });

            const data = await response.json();
            if (data.success) {
                this.showNotification('Téléchargement démarré', 'success');
                document.getElementById('youtube-url').value = '';
                this.loadYouTubeQueue();
            } else {
                this.showNotification(data.error, 'error');
            }
        } catch (error) {
            this.showNotification('Erreur téléchargement', 'error');
        }
    },

    async loadYouTubeQueue() {
        try {
            const response = await fetch('/api/youtube?action=queue');
            const queue = await response.json();

            const container = document.getElementById('youtube-queue');
            if (!queue || queue.length === 0) {
                container.innerHTML = '';
                return;
            }

            container.innerHTML = queue.map(item => `
                <div class="ps-youtube-item ps-youtube-item--${item.status}">
                    <div class="ps-youtube-title">${item.title}</div>
                    <div class="ps-progress">
                        <div class="ps-progress__bar" style="width: ${item.progress}%">${item.progress}%</div>
                    </div>
                </div>
            `).join('');
        } catch (error) {
            console.error('Error loading queue:', error);
        }
    },

    refreshMedia() {
        this.loadMediaList();
        this.showNotification('Liste actualisée', 'success');
    },

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `ps-notification ps-notification--${type}`;
        notification.textContent = message;

        document.body.appendChild(notification);

        setTimeout(() => {
            notification.classList.add('ps-notification--show');
        }, 100);

        setTimeout(() => {
            notification.classList.remove('ps-notification--show');
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    PiSignage.init();
});