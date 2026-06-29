/**
 * PiSignage Initialization — per-page module dispatch (multi-page architecture).
 * Each page initializes only its own module. Shared global handlers remain
 * available for inline onclick handlers on pages not yet migrated.
 */

document.addEventListener('DOMContentLoaded', function () {
    const page = (document.body && document.body.getAttribute('data-page')) || '';
    const P = window.PiSignage || (window.PiSignage = {});
    const run = (label, fn) => { try { fn(); } catch (e) { console.error('[init:' + label + ']', e); } };

    const dispatch = {
        'dashboard':          () => P.dashboard && P.dashboard.init && P.dashboard.init(),
        'media':              () => P.media && P.media.init && P.media.init(),
        'playlists':          () => P.playlists && P.playlists.init && P.playlists.init(),
        'player-control-ui':  () => P.player && P.player.init && P.player.init(),
        'music':              () => P.music && P.music.init && P.music.init(),
        'schedule':           () => P.schedule && P.schedule.init && P.schedule.init(),
        'settings':           () => P.settings && P.settings.init && P.settings.init()
    };
    if (dispatch[page]) run(page, dispatch[page]);

    // Shared global handlers (define window.* used by inline onclick on legacy pages)
    setupScreenshotHandlers();
    setupSystemHandlers();
    setupSettingsHandlers();
    setupLogsHandlers();

    if (page === 'settings') run('wifi', () => window.loadWifiConfig && window.loadWifiConfig());

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

/* YouTube download wiring now lives in assets/js/youtube.js (PiSignage.youtube). */

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
    // --- Multi-WiFi (3 emplacements numérotés, ordre = préférence) ---
    function renderWifiSlots(networks, connected) {
        const host = document.getElementById('wifi-slots');
        if (!host) return;
        const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        const bySlot = {};
        (networks || []).forEach(n => { bySlot[n.slot] = n; });
        let html = '';
        for (let i = 1; i <= 3; i++) {
            const n = bySlot[i] || {};
            const ssid = n.ssid || '';
            const has = !!n.has_password;
            const isConn = ssid && connected && ssid === connected;
            html += '<div class="wifi-slot" data-slot="' + i + '" style="display:flex;gap:8px;align-items:center;margin-bottom:10px;flex-wrap:wrap">'
                + '<span class="wifi-badge" style="flex:none;width:24px;height:24px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-weight:600;color:#fff;background:' + (i === 1 ? 'var(--accent,#10b981)' : 'var(--surface-3,#334155)') + '">' + i + '</span>'
                + '<input type="text" class="form-control wifi-ssid" style="flex:2;min-width:140px" placeholder="SSID ' + (i === 1 ? '(prioritaire)' : '(secours)') + '" value="' + esc(ssid) + '">'
                + '<input type="password" class="form-control wifi-psk" autocomplete="new-password" style="flex:1;min-width:120px" placeholder="' + (has ? '••• inchangé' : 'Mot de passe') + '">'
                + '<span class="wifi-conn" style="flex:none;color:var(--accent,#10b981);font-size:12px;font-weight:600;' + (isConn ? '' : 'display:none') + '">● connecté</span>'
                + '<span style="flex:none;display:inline-flex;gap:4px">'
                + '<button type="button" class="btn btn-secondary" style="padding:6px 9px" onclick="moveWifiSlot(' + i + ',-1)" title="Monter">▲</button>'
                + '<button type="button" class="btn btn-secondary" style="padding:6px 9px" onclick="moveWifiSlot(' + i + ',1)" title="Descendre">▼</button>'
                + '</span></div>';
        }
        host.innerHTML = html;
    }

    window.loadWifiConfig = async function () {
        try {
            const data = await PiSignage.api.config.getWifi();
            if (data.success && data.data) renderWifiSlots(data.data.networks, data.data.connected_ssid);
        } catch (e) { console.error(e); }
    };

    // Réordonne en échangeant les valeurs (SSID + clé saisie + état) entre deux lignes.
    window.moveWifiSlot = function (slot, dir) {
        const host = document.getElementById('wifi-slots');
        if (!host) return;
        const rows = Array.from(host.querySelectorAll('.wifi-slot'));
        const i = slot - 1, j = i + dir;
        if (j < 0 || j >= rows.length) return;
        const a = rows[i], b = rows[j];
        const swapVal = sel => { const x = a.querySelector(sel), y = b.querySelector(sel); const t = x.value; x.value = y.value; y.value = t; };
        swapVal('.wifi-ssid'); swapVal('.wifi-psk');
        const pa = a.querySelector('.wifi-psk'), pb = b.querySelector('.wifi-psk');
        const tp = pa.getAttribute('placeholder'); pa.setAttribute('placeholder', pb.getAttribute('placeholder')); pb.setAttribute('placeholder', tp);
        const ca = a.querySelector('.wifi-conn'), cb = b.querySelector('.wifi-conn');
        const td = ca.style.display; ca.style.display = cb.style.display; cb.style.display = td;
    };

    window.saveWifiConfig = async function () {
        const host = document.getElementById('wifi-slots');
        if (!host) return;
        const rows = Array.from(host.querySelectorAll('.wifi-slot'));
        const networks = rows.map(r => ({
            ssid: r.querySelector('.wifi-ssid').value.trim(),
            psk: r.querySelector('.wifi-psk').value
        })).filter(n => n.ssid !== '');
        if (networks.length === 0) { showAlert('Renseignez au moins un réseau', 'error'); return; }
        try {
            const data = await PiSignage.api.config.saveWifi(networks);
            showAlert(data.success ? 'WiFi appliqué' : ('Erreur : ' + data.message), data.success ? 'success' : 'error');
            if (data.success && data.data) renderWifiSlots(data.data.networks, data.data.connected_ssid);
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
    try { if (PiSignage.intervals && PiSignage.intervals.stopAll) PiSignage.intervals.stopAll(); } catch (e) {}
});

console.log('PiSignage Init module loaded');
