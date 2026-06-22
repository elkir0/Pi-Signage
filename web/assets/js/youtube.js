/**
 * PiSignage — YouTube download module.
 * Live progress bar + collapsible log ("Détails"), yt-dlp version check + 1-click update.
 * Self-initialises on the youtube page (no init.js dependency).
 */
window.PiSignage = window.PiSignage || {};

PiSignage.youtube = {
    api: '/api/youtube.php',
    poll: null,
    logPoll: null,
    currentId: null,
    detailsOpen: false,

    init() {
        this.$ = (id) => document.getElementById(id);
        const btn = this.$('yt-download-btn');
        if (btn) btn.addEventListener('click', () => this.startDownload());
        const det = this.$('yt-details-toggle');
        if (det) det.addEventListener('click', () => this.toggleDetails());
        const upd = this.$('yt-update-btn');
        if (upd) upd.addEventListener('click', () => this.updateYtdlp());
        const refresh = this.$('yt-history-refresh');
        if (refresh) refresh.addEventListener('click', () => this.loadHistory());

        this.checkYtdlp();
        this.loadHistory();
    },

    async _get(params) {
        const r = await fetch(this.api + '?' + params, { headers: { 'Accept': 'application/json' } });
        return r.json();
    },
    async _post(body) {
        const r = await fetch(this.api, {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
        });
        return r.json();
    },

    /* ---------------- yt-dlp version / update ---------------- */
    async checkYtdlp(refresh) {
        const card = this.$('yt-version-info');
        try {
            const r = await this._get('action=check_ytdlp' + (refresh ? '&refresh=1' : ''));
            const d = (r && r.data) || {};
            if (!d.available) {
                if (card) card.innerHTML = '<span class="badge badge-danger">yt-dlp absent</span>';
                this._setUpdateBtn('Installer', true);
                return;
            }
            const up = d.update_available;
            if (card) {
                card.innerHTML =
                    '<div class="row" style="gap:10px">'
                    + '<span class="mono" style="font-weight:600">v' + this._esc(d.version || '?') + '</span>'
                    + (up
                        ? '<span class="badge badge-warn">Mise à jour disponible : v' + this._esc(d.latest) + '</span>'
                        : '<span class="badge badge-success">À jour</span>')
                    + (d.managed ? '' : '<span class="badge">non géré</span>')
                    + '</div>';
            }
            this._setUpdateBtn(up ? 'Mettre à jour' : 'Réinstaller / vérifier', true);
            if (this.$('yt-update-btn')) this.$('yt-update-btn').classList.toggle('btn-primary', !!up);
        } catch (e) {
            if (card) card.innerHTML = '<span class="text-faint">Statut yt-dlp indisponible</span>';
        }
    },

    _setUpdateBtn(label, enabled) {
        const b = this.$('yt-update-btn');
        if (!b) return;
        const span = b.querySelector('.btn-label');
        if (span) span.textContent = label;
        b.disabled = !enabled;
    },

    async updateYtdlp() {
        const b = this.$('yt-update-btn');
        this._setUpdateBtn('Mise à jour…', false);
        if (b) b.querySelector('.spinner') || b.insertAdjacentHTML('afterbegin', '<span class="spinner" style="width:14px;height:14px;margin-right:6px"></span>');
        PiSignage.ui.toast('Mise à jour de yt-dlp…', 'info');
        try {
            const r = await this._post({ action: 'update_ytdlp' });
            const d = (r && r.data) || {};
            if (d.success) PiSignage.ui.toast('yt-dlp à jour (v' + (d.version || '?') + ')', 'success');
            else PiSignage.ui.toast('Échec de la mise à jour yt-dlp', 'error');
        } catch (e) {
            PiSignage.ui.toast('Erreur réseau pendant la mise à jour', 'error');
        }
        const sp = b && b.querySelector('.spinner'); if (sp) sp.remove();
        this.checkYtdlp(true);
    },

    /* ---------------- download + live progress ---------------- */
    async startDownload() {
        const urlEl = this.$('yt-url');
        const url = urlEl ? urlEl.value.trim() : '';
        if (!url) { PiSignage.ui.toast('Entrez une URL YouTube', 'error'); return; }
        const quality = (this.$('yt-quality') || {}).value || 'best';
        const audioOnly = (this.$('yt-audio') || {}).checked || false;

        this._showProgress(true);
        this._renderProgress({ status: 'queued', progress: 0 }, url);
        if (this.$('yt-download-btn')) this.$('yt-download-btn').disabled = true;

        try {
            const r = await this._post({ url, quality, format: 'mp4', audio_only: audioOnly });
            if (!r || !r.success || !r.data || !r.data.download_id) {
                PiSignage.ui.toast((r && r.message) || 'Échec du démarrage du téléchargement', 'error');
                this._finish(false);
                return;
            }
            this.currentId = r.data.download_id;
            PiSignage.ui.toast('Téléchargement démarré', 'info');
            this._startPolling();
        } catch (e) {
            PiSignage.ui.toast('Erreur de connexion', 'error');
            this._finish(false);
        }
    },

    _startPolling() {
        clearInterval(this.poll);
        this.poll = setInterval(async () => {
            if (!this.currentId) return;
            try {
                const r = await this._get('action=status&id=' + encodeURIComponent(this.currentId));
                const d = (r && r.data) || null;
                if (!d) return;
                this._renderProgress(d);
                if (this.detailsOpen) this._refreshLog();
                if (d.status === 'completed') {
                    PiSignage.ui.toast('Vidéo téléchargée' + (d.filename ? ' : ' + d.filename : ''), 'success');
                    this._finish(true);
                    if (PiSignage.media && PiSignage.media.loadMediaFiles) setTimeout(() => PiSignage.media.loadMediaFiles(), 1500);
                } else if (d.status === 'error' || d.status === 'cancelled') {
                    PiSignage.ui.toast('Échec du téléchargement — voir les détails', 'error');
                    if (!this.detailsOpen) this.toggleDetails(true);
                    this._finish(false);
                }
            } catch (e) { /* transient */ }
        }, 1500);
    },

    _finish(ok) {
        clearInterval(this.poll); this.poll = null;
        if (this.$('yt-download-btn')) this.$('yt-download-btn').disabled = false;
        this.loadHistory();
        if (ok && this.$('yt-url')) this.$('yt-url').value = '';
    },

    _renderProgress(d, urlOverride) {
        const pct = Math.max(0, Math.min(100, Math.round(parseFloat(d.progress) || 0)));
        const fill = this.$('yt-progress-fill'); if (fill) fill.style.width = pct + '%';
        const lbl = this.$('yt-progress-pct'); if (lbl) lbl.textContent = pct + '%';
        const meta = this.$('yt-progress-meta');
        if (meta) {
            const bits = [];
            const statusMap = { queued: 'En file', downloading: 'Téléchargement', completed: 'Terminé', error: 'Erreur', cancelled: 'Annulé' };
            bits.push(statusMap[d.status] || d.status || '');
            if (d.speed) bits.push(d.speed);
            if (d.eta && d.status === 'downloading') bits.push('ETA ' + d.eta);
            meta.textContent = bits.filter(Boolean).join(' · ');
        }
        const title = this.$('yt-progress-title');
        if (title && (urlOverride || d.url || d.filename)) title.textContent = d.filename || urlOverride || d.url;
        const bar = this.$('yt-progress-bar');
        if (bar) {
            bar.classList.toggle('is-error', d.status === 'error' || d.status === 'cancelled');
            bar.classList.toggle('is-done', d.status === 'completed');
        }
    },

    _showProgress(show) {
        const c = this.$('yt-progress-card');
        if (c) c.classList.toggle('hidden', !show);
    },

    /* ---------------- details / log ---------------- */
    toggleDetails(forceOpen) {
        this.detailsOpen = (forceOpen === true) ? true : !this.detailsOpen;
        const panel = this.$('yt-log-panel');
        if (panel) panel.classList.toggle('hidden', !this.detailsOpen);
        const tog = this.$('yt-details-toggle');
        if (tog) tog.querySelector('.btn-label').textContent = this.detailsOpen ? 'Masquer les détails' : 'Détails';
        if (this.detailsOpen) this._refreshLog();
    },

    async _refreshLog() {
        if (!this.currentId) return;
        try {
            const r = await this._get('action=log&id=' + encodeURIComponent(this.currentId));
            const panel = this.$('yt-log-panel');
            if (panel && r && r.data) {
                const atBottom = panel.scrollTop + panel.clientHeight >= panel.scrollHeight - 30;
                panel.textContent = r.data.log || '(log vide)';
                if (atBottom) panel.scrollTop = panel.scrollHeight;
            }
        } catch (e) {}
    },

    /* ---------------- history ---------------- */
    async loadHistory() {
        const list = this.$('yt-history');
        if (!list) return;
        try {
            const r = await this._get('action=queue');
            const items = (r && Array.isArray(r.data)) ? r.data.slice().reverse() : [];
            if (!items.length) {
                list.innerHTML = '<div class="empty-state" style="padding:30px">' + this._svg('youtube', 40) + '<p>Aucun téléchargement</p></div>';
                return;
            }
            const badge = { completed: 'badge-success', error: 'badge-danger', downloading: 'badge-info', queued: 'badge', cancelled: 'badge' };
            const label = { completed: 'Terminé', error: 'Erreur', downloading: 'En cours', queued: 'En file', cancelled: 'Annulé' };
            list.innerHTML = items.map((it) =>
                '<div class="row" style="justify-content:space-between;padding:11px 0;border-bottom:1px solid var(--border);gap:12px">'
                + '<div style="min-width:0;flex:1">'
                + '<div style="font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + this._esc(it.filename || it.url || it.id) + '</div>'
                + '<div class="text-faint" style="font-size:12px">' + this._esc(it.started_at || '') + (it.quality ? ' · ' + this._esc(it.quality) : '') + '</div>'
                + '</div>'
                + '<span class="badge ' + (badge[it.status] || 'badge') + '">' + (label[it.status] || it.status) + '</span>'
                + '</div>'
            ).join('');
        } catch (e) {
            list.innerHTML = '<div class="text-faint">Historique indisponible</div>';
        }
    },

    _esc(s) { const d = document.createElement('div'); d.textContent = String(s == null ? '' : s); return d.innerHTML; },
    _svg(name, sz) {
        const p = {
            youtube: '<path d="M22 8.6a3 3 0 0 0-2.1-2.1C18 6 12 6 12 6s-6 0-7.9.5A3 3 0 0 0 2 8.6 31 31 0 0 0 1.5 12 31 31 0 0 0 2 15.4a3 3 0 0 0 2.1 2.1C6 18 12 18 12 18s6 0 7.9-.5a3 3 0 0 0 2.1-2.1A31 31 0 0 0 22.5 12 31 31 0 0 0 22 8.6z"/><path d="m10 15 5-3-5-3z" fill="currentColor" stroke="none"/>'
        }[name] || '';
        return '<svg viewBox="0 0 24 24" width="' + (sz || 18) + '" height="' + (sz || 18) + '" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + p + '</svg>';
    }
};

document.addEventListener('DOMContentLoaded', () => {
    if ((document.body.getAttribute('data-page') || '') === 'youtube') {
        PiSignage.youtube.init();
    }
});
