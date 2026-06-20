/**
 * PiSignage Initialization — per-page module dispatch (multi-page architecture).
 * Each page initializes only its own module. Shared global handlers remain
 * available for inline onclick handlers on pages not yet migrated.
 */

// YouTube monitor state (used by setupYouTubeHandlers)
let youtubeMonitorInterval = null;
let downloadStartTime = null;
let currentDownloadUrl = '';
let currentDownloadQuality = '';

document.addEventListener('DOMContentLoaded', function () {
    const page = (document.body && document.body.getAttribute('data-page')) || '';
    const P = window.PiSignage || (window.PiSignage = {});
    const run = (label, fn) => { try { fn(); } catch (e) { console.error('[init:' + label + ']', e); } };

    const dispatch = {
        'dashboard':          () => P.dashboard && P.dashboard.init && P.dashboard.init(),
        'media':              () => P.media && P.media.init && P.media.init(),
        'playlists':          () => P.playlists && P.playlists.init && P.playlists.init(),
        'player-control-ui':  () => P.player && P.player.init && P.player.init(),
        'schedule':           () => P.schedule && P.schedule.init && P.schedule.init(),
        'settings':           () => P.settings && P.settings.init && P.settings.init()
    };
    if (dispatch[page]) run(page, dispatch[page]);

    // Shared global handlers (define window.* used by inline onclick on legacy pages)
    setupScreenshotHandlers();
    setupYouTubeHandlers();
    setupSystemHandlers();
    setupSettingsHandlers();
    setupLogsHandlers();

    console.log('PiSignage initialized (page: ' + (page || 'n/a') + ')');
});

/* ===================== Screenshot ===================== */
function setupScreenshotHandlers() {
    window.takeScreenshot = async function () {
        showAlert('Capture en cours…', 'info');
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
                showAlert('Capture réalisée', 'success');
            } else {
                showAlert('Erreur : ' + data.message, 'error');
            }
        } catch (error) {
            console.error('Screenshot error:', error);
            showAlert('Erreur lors de la capture', 'error');
        }
    };

    window.toggleAutoCapture = function () {
        const btn = document.getElementById('auto-capture-btn');
        if (window.autoScreenshotInterval) {
            clearInterval(window.autoScreenshotInterval);
            window.autoScreenshotInterval = null;
            if (btn) btn.textContent = 'Auto-capture (OFF)';
            showAlert('Auto-capture désactivée', 'info');
        } else {
            window.autoScreenshotInterval = setInterval(window.takeScreenshot, 30000);
            if (btn) btn.textContent = 'Auto-capture (ON)';
            showAlert('Auto-capture activée (30s)', 'success');
        }
    };
}

/* ===================== YouTube ===================== */
function setupYouTubeHandlers() {
    window.downloadYoutube = async function () {
        const urlInput = document.getElementById('youtube-url');
        const qualitySelect = document.getElementById('youtube-quality');
        if (!urlInput) return;

        const url = urlInput.value;
        const quality = qualitySelect ? qualitySelect.value : 'best';
        currentDownloadUrl = url;
        currentDownloadQuality = quality;

        if (!url) { showAlert('Entrez une URL YouTube', 'error'); return; }

        showAlert('Lancement du téléchargement…', 'info');
        const progressDiv = document.getElementById('youtube-progress');
        if (progressDiv) progressDiv.style.display = 'block';
        downloadStartTime = Date.now();

        try {
            const data = await PiSignage.api.youtube.download(url, quality);
            if (data.success) {
                startYoutubeMonitoring();
            } else {
                showAlert('Erreur : ' + data.message, 'error');
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
        const maxChecks = 120;
        youtubeMonitorInterval = setInterval(async () => {
            checkCount++;
            try {
                const data = await PiSignage.api.youtube.getStatus();
                const progressBar = document.getElementById('youtube-progress-fill');
                if (data.downloading) {
                    if (data.log) {
                        const lines = data.log.split('\n').filter(l => l.trim());
                        const lastLine = lines[lines.length - 1] || '';
                        const m = lastLine.match(/(\d+\.?\d*)%/);
                        if (m && progressBar) progressBar.style.width = parseFloat(m[1]) + '%';
                    }
                } else {
                    clearInterval(youtubeMonitorInterval);
                    const elapsed = Math.round((Date.now() - downloadStartTime) / 1000);
                    showAlert('Vidéo téléchargée (' + elapsed + 's)', 'success');
                    const pd = document.getElementById('youtube-progress');
                    if (pd) pd.style.display = 'none';
                    if (PiSignage.media && PiSignage.media.loadMediaFiles) {
                        setTimeout(() => PiSignage.media.loadMediaFiles(), 2000);
                    }
                    const urlInput = document.getElementById('youtube-url');
                    if (urlInput) urlInput.value = '';
                }
                if (checkCount >= maxChecks) {
                    clearInterval(youtubeMonitorInterval);
                    const pd = document.getElementById('youtube-progress');
                    if (pd) pd.style.display = 'none';
                    showAlert('Délai dépassé — vérifiez les logs', 'warning');
                }
            } catch (error) {
                console.error('YouTube monitoring error:', error);
            }
        }, 5000);
    }
}

/* ===================== System ===================== */
function setupSystemHandlers() {
    window.restartSystem = async function () {
        if (!confirm('Redémarrer le système ?')) return;
        showAlert('Redémarrage du système…', 'info');
        try {
            const data = await PiSignage.api.system.restart();
            if (data.success) { showAlert('Redémarrage dans 5 secondes…', 'success'); document.body.style.opacity = '0.5'; }
            else showAlert(data.message || 'Erreur lors du redémarrage', 'error');
        } catch (e) { console.error(e); showAlert('Erreur de communication', 'error'); }
    };
    window.shutdownSystem = async function () {
        if (!confirm('Arrêter le système ?')) return;
        showAlert('Arrêt du système…', 'info');
        try {
            const data = await PiSignage.api.system.shutdown();
            if (data.success) { showAlert('Arrêt dans 5 secondes…', 'success'); document.body.style.opacity = '0.5'; }
            else showAlert(data.message || 'Erreur lors de l\'arrêt', 'error');
        } catch (e) { console.error(e); showAlert('Erreur de communication', 'error'); }
    };
}

/* ===================== Settings (legacy globals) ===================== */
function setupSettingsHandlers() {
    window.saveDisplayConfig = async function () {
        const r = document.getElementById('resolution'), rot = document.getElementById('rotation');
        if (!r || !rot) return;
        try {
            const data = await PiSignage.api.config.saveDisplay(r.value, rot.value);
            showAlert(data.success ? 'Configuration sauvegardée' : ('Erreur : ' + data.message), data.success ? 'success' : 'error');
        } catch (e) { console.error(e); showAlert('Erreur de sauvegarde', 'error'); }
    };
    window.saveNetworkConfig = async function () {
        const s = document.getElementById('wifi-ssid'), p = document.getElementById('wifi-password');
        if (!s) return;
        if (!s.value) { showAlert('Entrez un SSID', 'error'); return; }
        try {
            const data = await PiSignage.api.config.saveNetwork(s.value, p ? p.value : '');
            showAlert(data.success ? 'Configuration WiFi sauvegardée' : ('Erreur : ' + data.message), data.success ? 'success' : 'error');
        } catch (e) { console.error(e); showAlert('Erreur de sauvegarde', 'error'); }
    };
}

/* ===================== Logs (legacy global) ===================== */
function setupLogsHandlers() {
    window.refreshLogs = async function () {
        try {
            const data = await PiSignage.api.logs.get();
            if (data.success) {
                const el = document.getElementById('logs-content');
                if (el) el.innerHTML = (data.data.logs || '').replace(/\n/g, '<br>');
            }
        } catch (e) { console.error(e); showAlert('Erreur de chargement des logs', 'error'); }
    };
}

/* ===================== Cleanup ===================== */
window.addEventListener('beforeunload', function () {
    try { if (window.autoScreenshotInterval) clearInterval(window.autoScreenshotInterval); } catch (e) {}
    try { if (youtubeMonitorInterval) clearInterval(youtubeMonitorInterval); } catch (e) {}
    try { if (PiSignage.intervals && PiSignage.intervals.stopAll) PiSignage.intervals.stopAll(); } catch (e) {}
});

console.log('PiSignage Init module loaded');
