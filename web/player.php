<?php
/**
 * PiSignage Chromium HTML5 Player
 * Page minimaliste pour lecture vidéo fullscreen avec playlist
 *
 * Features:
 * - HTML5 <video> fullscreen autoplay
 * - Gestion playlist JSON (autoLoop, autoplay)
 * - Support MP4 (H.264/AAC) et WebM (VP9/Opus)
 * - Wake Lock API (empêche veille écran)
 * - Masquage curseur
 * - Auto-retry sur erreur
 * - Enchaînement automatique
 */
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage Player</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            background: #000;
            overflow: hidden;
            cursor: none; /* Masquer curseur */
            -webkit-user-select: none;
            user-select: none;
        }

        #player-container {
            position: fixed;
            top: 0;
            left: 0;
            width: 100vw;
            height: 100vh;
            background: #000;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        #video {
            width: 100%;
            height: 100%;
            object-fit: contain; /* Default, sera mis à jour dynamiquement */
        }

        #loading {
            position: absolute;
            color: #fff;
            font-family: monospace;
            font-size: 1.5rem;
            text-align: center;
            z-index: 10;
        }

        #error {
            position: absolute;
            color: #f44;
            font-family: monospace;
            font-size: 1rem;
            text-align: center;
            z-index: 10;
            display: none;
            padding: 20px;
            background: rgba(0,0,0,0.8);
            border-radius: 8px;
        }

        /* Debug overlay - masqué par défaut, visible sur Ctrl+D */
        #debug {
            position: absolute;
            top: 10px;
            left: 10px;
            background: rgba(0,0,0,0.8);
            color: #0f0;
            font-family: monospace;
            font-size: 0.8rem;
            padding: 10px;
            border-radius: 4px;
            z-index: 100;
            display: none;
            max-width: 400px;
            word-wrap: break-word;
        }
    </style>
</head>
<body>

<div id="player-container">
    <div id="loading">Loading playlist...</div>
    <div id="error"></div>
    <video id="video" playsinline></video>
    <div id="debug">
        <div>Status: <span id="debug-status">initializing</span></div>
        <div>FPS: <span id="debug-fps">0</span></div>
        <div>Video: <span id="debug-video-info">-</span></div>
        <div>Playlist items: <span id="debug-playlist-items">0</span></div>
        <div>Current index: <span id="debug-current-index">-</span></div>
        <div>Current URL: <span id="debug-current-url">-</span></div>
        <div>Errors: <span id="debug-errors">0</span></div>
        <div>Wake Lock: <span id="debug-wakelock">-</span></div>
    </div>
</div>

<script>
/**
 * PiSignage Chromium HTML5 Player
 * Gestion complète de la playlist avec auto-retry et Wake Lock
 */

class PiSignagePlayer {
    constructor() {
        this.video = document.getElementById('video');
        this.loading = document.getElementById('loading');
        this.errorDiv = document.getElementById('error');
        this.debug = document.getElementById('debug');
        
        this.playlist = null;
        this.currentIndex = 0;
        this.errorCount = 0;
        this.maxRetries = 3;
        this.wakeLock = null;
        this.pollInterval = null;

        // Debug mode (Ctrl+D pour afficher)
        this.debugMode = false;

        // FPS counter
        this.fps = 0;
        this.frameCount = 0;
        this.lastFpsUpdate = Date.now();
        this.animationFrameId = null;

        this.init();
    }

    async init() {
        console.log('[PiSignage Player] Initializing...');
        this.setupEventListeners();
        this.setupKeyboardShortcuts();
        await this.loadPlaylist();
        await this.requestWakeLock();
        this.startPolling();
        this.startFpsCounter();
    }

    setupEventListeners() {
        // Événements vidéo
        this.video.addEventListener('loadedmetadata', () => {
            console.log('[Video] Metadata loaded:', this.video.duration, 'seconds');
            this.updateDebug('status', 'playing');
        });

        this.video.addEventListener('canplay', () => {
            console.log('[Video] Can play');
            this.hideLoading();
        });

        this.video.addEventListener('playing', () => {
            console.log('[Video] Playing');
            this.hideError();
        });

        this.video.addEventListener('ended', () => {
            console.log('[Video] Ended');
            this.handleVideoEnded();
        });

        this.video.addEventListener('error', (e) => {
            console.error('[Video] Error:', e);
            this.handleVideoError();
        });

        this.video.addEventListener('stalled', () => {
            console.warn('[Video] Stalled');
        });

        this.video.addEventListener('waiting', () => {
            console.log('[Video] Waiting for data...');
        });

        // Visibilité page (réacquérir Wake Lock si nécessaire)
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible') {
                this.requestWakeLock();
            }
        });
    }

    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Ctrl+D: Toggle debug overlay
            if (e.ctrlKey && e.key === 'd') {
                e.preventDefault();
                this.debugMode = !this.debugMode;
                this.debug.style.display = this.debugMode ? 'block' : 'none';
                if (this.debugMode) {
                    // Force immediate update when enabling debug
                    this.updateDebug('fps', this.fps);
                    this.updateVideoInfo();
                }
            }
            // Ctrl+R: Reload playlist
            if (e.ctrlKey && e.key === 'r') {
                e.preventDefault();
                this.reloadPlaylist();
            }
            // Ctrl+N: Next video
            if (e.ctrlKey && e.key === 'n') {
                e.preventDefault();
                this.playNext();
            }
        });
    }

    async loadPlaylist() {
        try {
            console.log('[Playlist] Loading from /api/playlist...');
            this.showLoading('Loading playlist...');

            const response = await fetch('/api/playlist');
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const result = await response.json();
            if (!result.success) {
                throw new Error(result.message || 'Failed to load playlist');
            }

            this.playlist = result.data;
            console.log('[Playlist] Loaded:', this.playlist);

            this.updateDebug('playlist-items', this.playlist.items.length);

            if (!this.playlist.items || this.playlist.items.length === 0) {
                throw new Error('Playlist is empty');
            }

            // Démarrer lecture si autoplay
            if (this.playlist.autoplay) {
                this.playItem(0);
            } else {
                this.hideLoading();
            }

        } catch (error) {
            console.error('[Playlist] Load error:', error);
            this.showError(`Failed to load playlist: ${error.message}`);
        }
    }

    async reloadPlaylist() {
        console.log('[Playlist] Reloading...');
        await this.loadPlaylist();
    }

    playItem(index) {
        if (!this.playlist || !this.playlist.items) {
            console.error('[Player] No playlist loaded');
            return;
        }

        if (index < 0 || index >= this.playlist.items.length) {
            console.error('[Player] Invalid index:', index);
            return;
        }

        this.currentIndex = index;
        const item = this.playlist.items[index];

        console.log(`[Player] Playing item ${index}:`, item);

        this.updateDebug('current-index', index);
        this.updateDebug('current-url', item.url);

        // Appliquer paramètres
        this.video.muted = item.mute !== undefined ? item.mute : false;
        this.video.loop = item.loop !== undefined ? item.loop : false;
        this.video.style.objectFit = item.fit || 'contain';

        // Charger source
        this.video.src = item.url;

        // Jouer
        this.video.play().catch(err => {
            console.error('[Player] Play error:', err);
            // Si autoplay échoue (politique navigateur), retry avec mute
            if (!this.video.muted) {
                console.warn('[Player] Autoplay failed, retrying with mute');
                this.video.muted = true;
                this.video.play().catch(e => {
                    console.error('[Player] Play with mute failed:', e);
                    this.handleVideoError();
                });
            } else {
                this.handleVideoError();
            }
        });

        // Gérer duration custom (pour images statiques ou override)
        if (item.duration && item.duration > 0) {
            setTimeout(() => {
                if (this.currentIndex === index) {
                    console.log(`[Player] Custom duration ${item.duration}s elapsed`);
                    this.handleVideoEnded();
                }
            }, item.duration * 1000);
        }

        this.errorCount = 0; // Reset error count on successful load
    }

    handleVideoEnded() {
        console.log('[Player] Video ended, checking next...');

        // Si loop individuel activé, on ne passe pas au suivant
        if (this.video.loop) {
            console.log('[Player] Loop enabled, video will replay automatically');
            return;
        }

        // Passer au suivant
        this.playNext();
    }

    playNext() {
        if (!this.playlist) return;

        const nextIndex = this.currentIndex + 1;

        if (nextIndex < this.playlist.items.length) {
            // Élément suivant dans la liste
            this.playItem(nextIndex);
        } else if (this.playlist.autoLoop) {
            // Recommencer au début si autoLoop
            console.log('[Player] End of playlist, looping back to start');
            this.playItem(0);
        } else {
            // Fin de playlist sans loop
            console.log('[Player] End of playlist, stopping');
            this.showLoading('Playlist finished');
        }
    }

    handleVideoError() {
        this.errorCount++;
        this.updateDebug('errors', this.errorCount);

        console.error(`[Player] Video error (${this.errorCount}/${this.maxRetries})`);

        if (this.errorCount < this.maxRetries) {
            // Retry même élément
            console.log('[Player] Retrying current item...');
            setTimeout(() => {
                this.video.load();
                this.video.play().catch(e => console.error('[Player] Retry play failed:', e));
            }, 2000);
        } else {
            // Max retries atteint, passer au suivant
            console.error('[Player] Max retries reached, skipping to next item');
            this.showError(`Failed to play: ${this.playlist.items[this.currentIndex].url}`, 3000);
            this.errorCount = 0;
            this.playNext();
        }
    }

    async requestWakeLock() {
        if (!('wakeLock' in navigator)) {
            console.warn('[Wake Lock] Not supported');
            this.updateDebug('wakelock', 'not supported');
            return;
        }

        try {
            this.wakeLock = await navigator.wakeLock.request('screen');
            console.log('[Wake Lock] Acquired');
            this.updateDebug('wakelock', 'active');

            this.wakeLock.addEventListener('release', () => {
                console.log('[Wake Lock] Released');
                this.updateDebug('wakelock', 'released');
            });
        } catch (err) {
            console.error('[Wake Lock] Error:', err);
            this.updateDebug('wakelock', 'error');
        }
    }

    startPolling() {
        // Poll /tmp/pisignage-playlist-refresh pour détecter rechargements
        this.pollInterval = setInterval(async () => {
            try {
                const response = await fetch('/api/playlist');
                if (response.ok) {
                    const result = await response.json();
                    if (result.success && result.data.version !== this.playlist.version) {
                        console.log('[Playlist] Version changed, reloading...');
                        await this.reloadPlaylist();
                    }
                }
            } catch (err) {
                // Silent fail pour polling
            }
        }, 10000); // Poll toutes les 10 secondes
    }

    startFpsCounter() {
        const updateFps = () => {
            this.frameCount++;
            const now = Date.now();
            const delta = now - this.lastFpsUpdate;

            // Update FPS every second
            if (delta >= 1000) {
                this.fps = Math.round((this.frameCount * 1000) / delta);
                this.frameCount = 0;
                this.lastFpsUpdate = now;

                if (this.debugMode) {
                    this.updateDebug('fps', this.fps);
                    this.updateVideoInfo();
                }
            }

            this.animationFrameId = requestAnimationFrame(updateFps);
        };

        updateFps();
    }

    updateVideoInfo() {
        if (!this.video.videoWidth) {
            this.updateDebug('video-info', '-');
            return;
        }

        const width = this.video.videoWidth;
        const height = this.video.videoHeight;
        const duration = Math.round(this.video.duration);
        const currentTime = Math.round(this.video.currentTime);

        const info = `${width}x${height} | ${currentTime}s/${duration}s`;
        this.updateDebug('video-info', info);
    }

    showLoading(message = 'Loading...') {
        this.loading.textContent = message;
        this.loading.style.display = 'block';
    }

    hideLoading() {
        this.loading.style.display = 'none';
    }

    showError(message, timeout = null) {
        this.errorDiv.textContent = message;
        this.errorDiv.style.display = 'block';
        if (timeout) {
            setTimeout(() => this.hideError(), timeout);
        }
    }

    hideError() {
        this.errorDiv.style.display = 'none';
    }

    updateDebug(key, value) {
        const element = document.getElementById(`debug-${key}`);
        if (element) {
            element.textContent = value;
        }
    }
}

// Initialiser le player au chargement de la page
window.addEventListener('DOMContentLoaded', () => {
    console.log('[PiSignage] Initializing player...');
    new PiSignagePlayer();
});
</script>

</body>
</html>
