/**
 * PiSignage Initialization Module
 * Initializes all modules, sets up event bindings, and starts application
 */

// YouTube functionality
let youtubeMonitorInterval = null;
let downloadStartTime = null;
let currentDownloadUrl = '';
let currentDownloadQuality = '';

// Screenshot auto-capture functionality
// Using existing autoScreenshotInterval from core.js

// Global event listeners and initialization
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 PiSignage Application Starting...');

    // Initialize all modules in correct order
    initializeApplication();

    // Setup global event bindings
    setupGlobalEventBindings();

    // Setup additional functionality
    setupScreenshotHandlers();
    setupYouTubeHandlers();
    setupSystemHandlers();
    setupSettingsHandlers();
    setupLogsHandlers();

    console.log('✅ PiSignage Application Initialized Successfully');
});

async function initializeApplication() {
    try {
        // Initialize core modules
        console.log('📊 Initializing Dashboard...');
        PiSignage.dashboard.init();

        console.log('📁 Initializing Media Management...');
        PiSignage.media.init();

        console.log('🎵 Initializing Playlists...');
        PiSignage.playlists.init();

        console.log('🎮 Initializing Player Controls...');
        PiSignage.player.init();

        // Load initial data with delay to ensure API is ready
        setTimeout(async () => {
            console.log('📥 Loading initial application data...');

            // Get current player and update interface
            await PiSignage.dashboard.getCurrentPlayer();

            // Load media files
            await PiSignage.media.loadMediaFiles();

            // Load playlists
            await PiSignage.playlists.loadPlaylists();

            // Initialize player with current data
            await PiSignage.player.initializePlayer();

            console.log('✅ Initial data loaded successfully');
        }, 100);

        // Start auto-refresh intervals
        setTimeout(() => {
            PiSignage.intervals.startStatsRefresh(5000);
            PiSignage.intervals.startPlayerStatusRefresh(3000);
        }, 500);

        // Page Visibility API: pause polling loops while the tab is hidden,
        // resume them (with the same intervals) when it becomes visible again.
        setupVisibilityPolling();

    } catch (error) {
        console.error('❌ Error during application initialization:', error);
        showAlert('Erreur d\'initialisation de l\'application', 'error');
    }
}

// Suspend/resume the stats (5s) and player (3s) polling loops based on
// the Page Visibility API to avoid useless polling on a hidden tab.
function setupVisibilityPolling() {
    document.addEventListener('visibilitychange', function() {
        if (document.hidden) {
            // Tab hidden: stop both polling intervals to save CPU/network.
            PiSignage.intervals.stopAll();
        } else {
            // Tab visible again: restart both polling intervals.
            PiSignage.intervals.startStatsRefresh(5000);
            PiSignage.intervals.startPlayerStatusRefresh(3000);
        }
    });
}

function setupGlobalEventBindings() {
    // Section navigation event listener
    document.addEventListener('click', function(event) {
        if (event.target.closest('.nav-item')) {
            const navItem = event.target.closest('.nav-item');
            const onclick = navItem.getAttribute('onclick');

            // Extract section name from onclick attribute
            if (onclick && onclick.includes('showSection')) {
                const match = onclick.match(/showSection\('([^']+)'\)/);
                if (match) {
                    const section = match[1];

                    // Initialize section-specific functionality
                    setTimeout(() => {
                        initializeSectionSpecific(section);
                    }, 100);
                }
            }
        }
    });

    // Global escape key handler
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            // Close any open modals (HIDE them, don't remove from DOM)
            const modals = document.querySelectorAll('.modal.show');
            modals.forEach(modal => {
                modal.classList.remove('show');
            });

            // Legacy modals with style.display
            const legacyModals = document.querySelectorAll('#uploadModal, #editPlaylistModal');
            legacyModals.forEach(modal => {
                if (modal.style.display !== 'none') {
                    modal.style.display = 'none';
                }
            });
        }
    });

    // Global media list update event listener
    document.addEventListener('mediaListUpdated', function(event) {
        console.log('📡 Media list updated event received:', event.detail);

        // Refresh all media-dependent components
        setTimeout(() => {
            PiSignage.media.loadMediaFiles();
            PiSignage.player.initializePlayer();
        }, 200);
    });
}

function initializeSectionSpecific(section) {
    switch (section) {
        case 'playlists':
            // Initialize playlist editor if available
            if (typeof PiSignage.playlists.initPlaylistEditor === 'function') {
                PiSignage.playlists.initPlaylistEditor();
            }
            break;

        case 'media':
            // Refresh media list when switching to media section
            PiSignage.media.loadMediaFiles();
            break;

        case 'player':
            // Refresh player status when switching to player section
            PiSignage.player.refreshPlayerStatus();
            break;

        case 'logs':
            // Refresh logs when switching to logs section
            refreshLogs();
            break;
    }
}

// Screenshot functionality
function setupScreenshotHandlers() {
    // Global screenshot functions
    window.takeScreenshot = async function() {
        showAlert('Capture en cours...', 'info');

        try {
            const data = await PiSignage.api.screenshot.capture();
            if (data.success) {
                const img = document.getElementById('screenshot-img');
                const empty = document.getElementById('screenshot-empty');

                if (img && empty) {
                    img.src = data.data.url + '?' + Date.now();
                    img.style.display = 'block';
                    empty.style.display = 'none';
                }

                showAlert('Capture réalisée!', 'success');
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Screenshot error:', error);
            showAlert('Erreur lors de la capture', 'error');
        }
    };

    window.toggleAutoCapture = function() {
        const btn = document.getElementById('auto-capture-btn');

        if (autoScreenshotInterval) {
            clearInterval(autoScreenshotInterval);
            autoScreenshotInterval = null;
            if (btn) btn.textContent = '🔄 Auto-capture (OFF)';
            showAlert('Auto-capture désactivée', 'info');
        } else {
            autoScreenshotInterval = setInterval(takeScreenshot, 30000);
            if (btn) btn.textContent = '🔄 Auto-capture (ON)';
            showAlert('Auto-capture activée (30s)', 'success');
        }
    };
}

// YouTube functionality
function setupYouTubeHandlers() {
    window.downloadYoutube = async function() {
        const urlInput = document.getElementById('youtube-url');
        const qualitySelect = document.getElementById('youtube-quality');

        if (!urlInput) return;

        const url = urlInput.value;
        const quality = qualitySelect ? qualitySelect.value : 'best';

        // Save for history
        currentDownloadUrl = url;
        currentDownloadQuality = quality;

        if (!url) {
            showAlert('Entrez une URL YouTube', 'error');
            return;
        }

        // Show detailed feedback
        showAlert('🚀 Lancement du téléchargement...', 'info');
        const progressDiv = document.getElementById('youtube-progress');
        if (progressDiv) progressDiv.style.display = 'block';

        // Create feedback area if not exists
        let feedbackDiv = document.getElementById('youtube-feedback');
        if (!feedbackDiv) {
            feedbackDiv = document.createElement('div');
            feedbackDiv.id = 'youtube-feedback';
            feedbackDiv.style.cssText = 'margin-top: 20px; padding: 15px; background: rgba(0,0,0,0.3); border-radius: 8px; font-family: monospace; font-size: 12px; max-height: 200px; overflow-y: auto;';
            const youtubeSection = document.getElementById('youtube');
            if (youtubeSection) youtubeSection.appendChild(feedbackDiv);
        }
        feedbackDiv.innerHTML = '<div style="color: #4a9eff;">📥 Connexion à YouTube...</div>';

        downloadStartTime = Date.now();

        try {
            const data = await PiSignage.api.youtube.download(url, quality);
            if (data.success) {
                feedbackDiv.innerHTML += '<div style="color: #4f4;">✅ Téléchargement lancé</div>';
                feedbackDiv.innerHTML += '<div style="color: #999;">⏳ Récupération des informations vidéo...</div>';

                // Start monitoring
                startYoutubeMonitoring();
            } else {
                showAlert('Erreur: ' + data.message, 'error');
                if (progressDiv) progressDiv.style.display = 'none';
            }
        } catch (error) {
            console.error('YouTube download error:', error);
            showAlert('Erreur de connexion', 'error');
            if (progressDiv) progressDiv.style.display = 'none';
        }
    };

    function startYoutubeMonitoring() {
        let checkCount = 0;
        const maxChecks = 120; // 10 minutes max

        youtubeMonitorInterval = setInterval(async () => {
            checkCount++;

            try {
                const data = await PiSignage.api.youtube.getStatus();
                const feedbackDiv = document.getElementById('youtube-feedback');
                const progressBar = document.getElementById('youtube-progress-fill');

                if (data.downloading) {
                    // Show logs
                    if (data.log) {
                        const lines = data.log.split('\n').filter(l => l.trim());
                        const lastLine = lines[lines.length - 1] || '';

                        // Extract percentage if present
                        const percentMatch = lastLine.match(/(\d+\.?\d*)%/);
                        if (percentMatch) {
                            const percent = parseFloat(percentMatch[1]);
                            if (progressBar) {
                                progressBar.style.width = percent + '%';
                            }
                            if (feedbackDiv) {
                                feedbackDiv.innerHTML = '<div style="color: #4a9eff;">⏬ Téléchargement: ' + percent.toFixed(1) + '%</div>';
                            }
                        }

                        // Show video info
                        if (lastLine.includes('Destination:')) {
                            const filename = lastLine.split('/').pop();
                            if (feedbackDiv) {
                                feedbackDiv.innerHTML += '<div style="color: #fff;">📁 ' + filename + '</div>';
                            }
                        }
                    }
                } else {
                    // Download finished
                    clearInterval(youtubeMonitorInterval);
                    const elapsed = Math.round((Date.now() - downloadStartTime) / 1000);

                    if (feedbackDiv) {
                        feedbackDiv.innerHTML += '<div style="color: #4f4;">✅ Téléchargement terminé (' + elapsed + 's)</div>';
                    }
                    showAlert('✅ Vidéo téléchargée avec succès!', 'success');

                    const progressDiv = document.getElementById('youtube-progress');
                    if (progressDiv) progressDiv.style.display = 'none';

                    // Add to history
                    addToYouTubeHistory(elapsed);

                    // Auto-refresh MEDIA
                    setTimeout(() => {
                        PiSignage.media.loadMediaFiles();
                        if (feedbackDiv) {
                            feedbackDiv.innerHTML += '<div style="color: #999;">📂 Section MEDIA mise à jour</div>';
                        }
                    }, 2000);

                    // Clear form
                    const urlInput = document.getElementById('youtube-url');
                    if (urlInput) urlInput.value = '';
                }

                // Timeout after 10 minutes
                if (checkCount >= maxChecks) {
                    clearInterval(youtubeMonitorInterval);
                    if (feedbackDiv) {
                        feedbackDiv.innerHTML += '<div style="color: #f44;">⚠️ Timeout - Vérifiez les logs</div>';
                    }
                    const progressDiv = document.getElementById('youtube-progress');
                    if (progressDiv) progressDiv.style.display = 'none';
                }
            } catch (error) {
                console.error('YouTube monitoring error:', error);
            }
        }, 5000); // Check every 5 seconds
    }

    function addToYouTubeHistory(elapsed) {
        const historyDiv = document.getElementById('youtube-history');
        if (historyDiv) {
            const now = new Date().toLocaleString('fr-FR');
            const historyItem = `
                <div style="padding: 10px; margin-bottom: 10px; background: rgba(74,158,255,0.1); border-radius: 5px; border-left: 3px solid #4a9eff;">
                    <div style="color: #4a9eff; font-size: 12px;">${now}</div>
                    <div style="color: #fff; margin: 5px 0;">✅ ${currentDownloadUrl}</div>
                    <div style="color: #999; font-size: 11px;">Qualité: ${currentDownloadQuality} - Durée: ${elapsed}s</div>
                </div>
            `;
            historyDiv.innerHTML = historyItem + historyDiv.innerHTML;

            // Limit history to 10 entries
            const items = historyDiv.children;
            while (items.length > 10) {
                historyDiv.removeChild(items[items.length - 1]);
            }
        }
    }
}

// System functionality
function setupSystemHandlers() {
    window.restartSystem = async function() {
        if (confirm('Êtes-vous sûr de vouloir redémarrer le système ?')) {
            showAlert('Redémarrage du système...', 'info');

            try {
                const data = await PiSignage.api.system.restart();
                if (data.success) {
                    showAlert('Le système va redémarrer dans 5 secondes...', 'success');
                    document.body.style.opacity = '0.5';
                    document.body.style.pointerEvents = 'none';
                } else {
                    showAlert(data.message || 'Erreur lors du redémarrage', 'error');
                }
            } catch (error) {
                console.error('Restart system error:', error);
                showAlert('Erreur de communication', 'error');
            }
        }
    };

    window.shutdownSystem = async function() {
        if (confirm('Êtes-vous sûr de vouloir arrêter le système ?')) {
            showAlert('Arrêt du système...', 'info');

            try {
                const data = await PiSignage.api.system.shutdown();
                if (data.success) {
                    showAlert('Le système va s\'arrêter dans 5 secondes...', 'success');
                    document.body.style.opacity = '0.5';
                    document.body.style.pointerEvents = 'none';
                } else {
                    showAlert(data.message || 'Erreur lors de l\'arrêt', 'error');
                }
            } catch (error) {
                console.error('Shutdown system error:', error);
                showAlert('Erreur de communication', 'error');
            }
        }
    };
}

// Settings functionality
function setupSettingsHandlers() {
    window.saveDisplayConfig = async function() {
        const resolutionSelect = document.getElementById('resolution');
        const rotationSelect = document.getElementById('rotation');

        if (!resolutionSelect || !rotationSelect) return;

        const resolution = resolutionSelect.value;
        const rotation = rotationSelect.value;

        try {
            const data = await PiSignage.api.config.saveDisplay(resolution, rotation);
            if (data.success) {
                showAlert('Configuration sauvegardée!', 'success');
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Save display config error:', error);
            showAlert('Erreur de sauvegarde', 'error');
        }
    };

    window.saveNetworkConfig = async function() {
        const ssidInput = document.getElementById('wifi-ssid');
        const passwordInput = document.getElementById('wifi-password');

        if (!ssidInput) return;

        const ssid = ssidInput.value;
        const password = passwordInput ? passwordInput.value : '';

        if (!ssid) {
            showAlert('Entrez un SSID', 'error');
            return;
        }

        try {
            const data = await PiSignage.api.config.saveNetwork(ssid, password);
            if (data.success) {
                showAlert('Configuration WiFi sauvegardée!', 'success');
            } else {
                showAlert('Erreur: ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Save network config error:', error);
            showAlert('Erreur de sauvegarde', 'error');
        }
    };
}

// Logs functionality
function setupLogsHandlers() {
    window.refreshLogs = async function() {
        try {
            const data = await PiSignage.api.logs.get();
            if (data.success) {
                const logsContent = document.getElementById('logs-content');
                if (logsContent) {
                    logsContent.innerHTML = data.data.logs.replace(/\n/g, '<br>');
                }
            }
        } catch (error) {
            console.error('Error loading logs:', error);
            showAlert('Erreur de chargement des logs', 'error');
        }
    };
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    console.log('🧹 Cleaning up intervals...');

    // Clear all intervals
    if (autoScreenshotInterval) {
        clearInterval(autoScreenshotInterval);
    }

    if (youtubeMonitorInterval) {
        clearInterval(youtubeMonitorInterval);
    }

    // Stop PiSignage intervals
    PiSignage.intervals.stopAll();
    PiSignage.dashboard.stopStatsRefresh();
    PiSignage.player.stopStatusUpdates();
});

console.log('✅ PiSignage Init module loaded - Application initialization ready');