/**
 * PiSignage Dashboard module — wires the dashboard UI to live APIs.
 * Stats donuts, media/playlist counts, now-playing, transport, quick actions.
 */
window.PiSignage = window.PiSignage || {};

PiSignage.dashboard = {
    timers: { stats: null, player: null },

    init() {
        this.refreshAll();
        this.timers.stats = setInterval(() => this.refreshStats(), 5000);
        this.timers.player = setInterval(() => this.refreshPlayer(), 3000);
    },

    refreshAll() {
        this.refreshStats();
        this.refreshCounts();
        this.refreshPlayer();
    },

    /* ---------- helpers ---------- */
    _el(id) { return document.getElementById(id); },

    _fmtBytes(b) {
        if (!b || isNaN(b)) return '0';
        const u = ['o', 'Ko', 'Mo', 'Go', 'To'];
        const i = Math.floor(Math.log(b) / Math.log(1024));
        return (b / Math.pow(1024, i)).toFixed(i >= 3 ? 1 : 0).replace('.', ',') + ' ' + u[i];
    },

    _fmtTime(s) {
        s = Math.max(0, Math.floor(s || 0));
        const m = Math.floor(s / 60), sec = s % 60;
        return String(m).padStart(2, '0') + ':' + String(sec).padStart(2, '0');
    },

    _donut(id, pct, text) {
        const el = this._el(id);
        if (!el) return;
        pct = Math.max(0, Math.min(100, pct || 0));
        el.style.setProperty('--val', pct);
        const span = el.querySelector('span');
        if (span) span.textContent = text;
    },

    /* ---------- system stats ---------- */
    async refreshStats() {
        try {
            const r = await PiSignage.api.system.getStats();
            if (!r || !r.success || !r.data) return;
            const s = r.data;
            const cpu = (s.cpu && s.cpu.usage) || 0;
            const ram = (s.memory && s.memory.percent) || 0;
            const temp = s.temperature || 0;
            const disk = s.disk || {};
            this._donut('g-cpu', cpu, Math.round(cpu) + '%');
            this._donut('g-ram', ram, Math.round(ram) + '%');
            this._donut('g-tmp', Math.min(100, temp), Math.round(temp) + '°');
            this._donut('g-dsk', disk.percent || 0, Math.round(disk.percent || 0) + '%');

            const stor = this._el('stat-storage');
            if (stor && disk.total) stor.innerHTML = this._fmtBytes(disk.used) + ' <small>/ ' + this._fmtBytes(disk.total) + '</small>';
            const bar = this._el('stat-storage-bar');
            if (bar) bar.style.width = (disk.percent || 0) + '%';

            const up = this._el('stat-uptime');
            if (up && s.uptime) up.textContent = String(s.uptime).replace(/^up\s+/, '');

            this._setUndervoltage(s.throttled);
        } catch (e) { /* silent — transient */ }
    },

    /* ---------- under-voltage alert ---------- */
    _setUndervoltage(t) {
        const badge = this._el('undervoltage-badge');
        if (!badge) return;
        // t is null on non-Pi hardware or when vcgencmd is unavailable.
        const alert = !!(t && (t.under_voltage_now || t.under_voltage_occurred));
        badge.style.display = alert ? 'inline-flex' : 'none';
        if (alert) {
            badge.title = t.under_voltage_now
                ? "Sous-alimentation en cours — vérifiez l'alimentation du Raspberry Pi"
                : "Une sous-alimentation s'est produite depuis le démarrage";
        }
    },

    /* ---------- counts ---------- */
    async refreshCounts() {
        try {
            const m = await PiSignage.api.media.list();
            const el = this._el('stat-media');
            if (el && m && m.success) el.textContent = Array.isArray(m.data) ? m.data.length : 0;
        } catch (e) {}
        try {
            const p = await PiSignage.api.playlists.list();
            const el = this._el('stat-playlists');
            if (el && p && p.success) {
                const d = p.data;
                el.textContent = Array.isArray(d) ? d.length : (d && Array.isArray(d.playlists) ? d.playlists.length : 0);
            }
        } catch (e) {}
    },

    /* ---------- now playing ---------- */
    async refreshPlayer() {
        try {
            const r = await PiSignage.api.player.getStatus();
            if (!r || !r.success || !r.data) { this._setPlayer(null); return; }
            this._setPlayer(r.data);
        } catch (e) { this._setPlayer(null); }
    },

    _setPlayer(d) {
        const pill = this._el('topbar-status');
        const title = this._el('np-title'), sub = this._el('np-sub'),
              fill = this._el('np-fill'), cur = this._el('np-cur'),
              dur = this._el('np-dur'), badge = this._el('np-badge');

        if (!d || !d.state || d.state === 'stopped' || (!d.current_file && d.state !== 'playing')) {
            if (title) title.textContent = 'Aucune lecture';
            if (sub) sub.textContent = '—';
            if (fill) fill.style.width = '0%';
            if (cur) cur.textContent = '00:00';
            if (dur) dur.textContent = '00:00';
            if (badge) badge.style.display = 'none';
            if (pill) { pill.className = 'status-pill is-stopped'; pill.querySelector('.pill-text').textContent = 'Lecteur · arrêté'; }
            return;
        }
        const playing = d.state === 'playing';
        if (title) title.textContent = d.current_file || 'Média';
        if (sub) {
            const pl = Array.isArray(d.playlist) && d.playlist.length ? d.playlist.length + ' éléments' : 'Lecture directe';
            sub.textContent = 'Volume ' + (d.volume != null ? d.volume + '%' : '—') + ' · ' + pl;
        }
        const pos = d.position || 0, len = d.duration || 0;
        if (fill) fill.style.width = (len ? Math.min(100, pos / len * 100) : 0) + '%';
        if (cur) cur.textContent = this._fmtTime(pos);
        if (dur) dur.textContent = this._fmtTime(len);
        if (badge) badge.style.display = playing ? 'block' : 'none';
        if (pill) {
            pill.className = 'status-pill ' + (playing ? 'is-playing' : 'is-paused');
            pill.querySelector('.pill-text').textContent = 'Lecteur · ' + (playing ? 'en lecture' : 'pause');
        }
    },

    /* ---------- actions ---------- */
    async control(action) {
        try {
            const r = await PiSignage.api.player.control(action);
            if (r && r.success === false) PiSignage.ui.toast(r.message || 'Erreur', 'error');
            this.refreshPlayer();
        } catch (e) { PiSignage.ui.toast('Erreur de communication', 'error'); }
    },

    async screenshot() {
        PiSignage.ui.toast('Capture en cours…', 'info');
        try {
            const r = await PiSignage.api.screenshot.capture();
            if (r && r.success) PiSignage.ui.toast('Capture réalisée', 'success');
            else PiSignage.ui.toast((r && r.message) || 'Échec de la capture', 'error');
        } catch (e) { PiSignage.ui.toast('Erreur lors de la capture', 'error'); }
    },

    async restartPlayer() {
        if (!PiSignage.ui.confirm('Redémarrer le lecteur ?')) return;
        try {
            const r = await PiSignage.api.system.systemAction('restart-player');
            PiSignage.ui.toast((r && r.success) ? 'Lecteur redémarré' : ((r && r.message) || 'Erreur'), (r && r.success) ? 'success' : 'error');
        } catch (e) { PiSignage.ui.toast('Erreur système', 'error'); }
    }
};

console.log('PiSignage Dashboard module loaded');
