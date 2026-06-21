/**
 * PiSignage Kiosk Control module — Chromium kiosk (Trixie / Wayland).
 * Exposes window.PiSignage.kiosk with init() + UI wiring to /api/kiosk.php* and /api/playlist.php*.
 * Design-system aware: toasts via PiSignage.ui, modals via PiSignage.ui.{open,close}Modal.
 */
window.PiSignage = window.PiSignage || {};

PiSignage.kiosk = {
    playlistData: null,
    editingItemIndex: null,
    statusInterval: null,

    /* ---------- lifecycle ---------- */
    init() {
        this.loadStatus();
        this.loadPlaylist();
        this.loadUrl();
        this.loadFlags();
        this.loadMode();
        this.loadScreen();
        this.startAutoRefresh();
        this.bindEvents();
    },

    _el(id) { return document.getElementById(id); },

    _toast(msg, type) {
        if (PiSignage.ui && PiSignage.ui.toast) PiSignage.ui.toast(msg, type || 'info');
    },

    _confirm(msg) {
        return (PiSignage.ui && PiSignage.ui.confirm) ? PiSignage.ui.confirm(msg) : window.confirm(msg);
    },

    _escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text == null ? '' : String(text);
        return div.innerHTML;
    },

    bindEvents() {
        const enable = this._el('enable-kiosk');
        if (enable) enable.addEventListener('change', (e) => this.updateMode('enable', e.target.checked));

        const player = this._el('use-chromium-player');
        if (player) player.addEventListener('change', (e) => this.updateMode('player', e.target.checked));

        const uploadArea = this._el('upload-area');
        if (uploadArea) {
            uploadArea.addEventListener('click', () => { const fi = this._el('file-input'); if (fi) fi.click(); });
            uploadArea.addEventListener('dragover', (e) => { e.preventDefault(); uploadArea.classList.add('dragging'); });
            uploadArea.addEventListener('dragleave', (e) => { e.preventDefault(); uploadArea.classList.remove('dragging'); });
            uploadArea.addEventListener('drop', (e) => {
                e.preventDefault();
                uploadArea.classList.remove('dragging');
                if (e.dataTransfer.files.length > 0) this.handleUpload(e.dataTransfer.files[0]);
            });
        }

        const fileInput = this._el('file-input');
        if (fileInput) fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) this.handleUpload(e.target.files[0]);
        });

        document.addEventListener('visibilitychange', () => {
            if (document.hidden) this.stopAutoRefresh(); else this.startAutoRefresh();
        });

        window.addEventListener('beforeunload', () => this.stopAutoRefresh());
    },

    /* ---------- kiosk mode (feature flags) ---------- */
    async loadMode() {
        try {
            const r = await fetch('/api/kiosk.php');
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success && result.data) {
                const en = this._el('enable-kiosk');
                const pl = this._el('use-chromium-player');
                if (en) en.checked = result.data.enabled !== false;
                if (pl) pl.checked = result.data.useChromiumPlayer !== false;
            }
        } catch (e) {
            console.error('[kiosk] loadMode', e);
            this._toast('Erreur de chargement du mode kiosk', 'error');
        }
    },

    async updateMode(type, value) {
        try {
            const endpoint = type === 'enable' ? '/api/kiosk.php/enable' : '/api/kiosk.php/mode';
            const body = type === 'enable' ? { enabled: value } : { useChromiumPlayer: value };
            const r = await fetch(endpoint, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body)
            });
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) {
                this._toast(result.message || 'Mode mis à jour', 'success');
                this.loadStatus();
            } else {
                throw new Error(result.message);
            }
        } catch (e) {
            console.error('[kiosk] updateMode', e);
            this._toast('Erreur de mise à jour du mode : ' + e.message, 'error');
        }
    },

    /* ---------- playlist ---------- */
    async loadPlaylist() {
        try {
            const r = await fetch('/api/playlist.php');
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) {
                this.playlistData = result.data || { items: [] };
                if (!Array.isArray(this.playlistData.items)) this.playlistData.items = [];
                this.renderPlaylist();
                const ap = this._el('playlist-autoplay');
                const al = this._el('playlist-autoloop');
                if (ap) ap.checked = this.playlistData.autoplay !== false;
                if (al) al.checked = this.playlistData.autoLoop !== false;
            } else {
                throw new Error(result.message);
            }
        } catch (e) {
            console.error('[kiosk] loadPlaylist', e);
            const c = this._el('playlist-items');
            if (c) c.innerHTML = '<div class="empty-state" style="padding:24px"><p>Erreur de chargement de la playlist</p></div>';
        }
    },

    renderPlaylist() {
        const c = this._el('playlist-items');
        if (!c) return;
        const items = (this.playlistData && this.playlistData.items) || [];
        if (items.length === 0) {
            c.innerHTML = '<div class="empty-state" style="padding:24px"><p>Aucun média dans la playlist</p></div>';
            return;
        }

        let html = '';
        items.forEach((item, index) => {
            const meta = [];
            if (item.mute) meta.push('Muet');
            if (item.loop) meta.push('Boucle');
            meta.push('Ajustement : ' + (item.fit || 'contain'));
            if (item.duration > 0) meta.push('Durée : ' + item.duration + 's');

            html += '<div class="playlist-item" data-index="' + index + '">';
            html += '<div class="playlist-item-content">';
            html += '<div class="playlist-item-name">' + this._escapeHtml(item.url) + '</div>';
            html += '<div class="playlist-item-details"><span>' + meta.join('</span><span>') + '</span></div>';
            html += '</div>';
            html += '<div class="playlist-item-actions">';
            if (index > 0) html += '<button class="icon-btn" type="button" title="Monter" onclick="PiSignage.kiosk.moveItem(' + index + ', -1)">' + this._icon('chevron-up') + '</button>';
            if (index < items.length - 1) html += '<button class="icon-btn" type="button" title="Descendre" onclick="PiSignage.kiosk.moveItem(' + index + ', 1)">' + this._icon('chevron-down') + '</button>';
            html += '<button class="icon-btn" type="button" title="Modifier" onclick="PiSignage.kiosk.editItem(' + index + ')">' + this._icon('edit') + '</button>';
            html += '<button class="icon-btn" type="button" title="Supprimer" onclick="PiSignage.kiosk.deleteItem(' + index + ')">' + this._icon('trash') + '</button>';
            html += '</div></div>';
        });
        c.innerHTML = html;
    },

    addItem() {
        this.editingItemIndex = null;
        this._setModalField('modal-title', 'Ajouter un média', 'text');
        this._setVal('item-url', '');
        this._setVal('item-fit', 'contain');
        this._setVal('item-duration', '0');
        this._setChecked('item-mute', false);
        this._setChecked('item-loop', false);
        PiSignage.ui.openModal('playlist-item-modal');
    },

    editItem(index) {
        this.editingItemIndex = index;
        const item = this.playlistData.items[index];
        this._setModalField('modal-title', 'Modifier le média', 'text');
        this._setVal('item-url', item.url || '');
        this._setVal('item-fit', item.fit || 'contain');
        this._setVal('item-duration', item.duration || 0);
        this._setChecked('item-mute', !!item.mute);
        this._setChecked('item-loop', !!item.loop);
        PiSignage.ui.openModal('playlist-item-modal');
    },

    saveItem() {
        const item = {
            url: (this._el('item-url').value || '').trim(),
            fit: this._el('item-fit').value,
            duration: parseInt(this._el('item-duration').value, 10) || 0,
            mute: this._el('item-mute').checked,
            loop: this._el('item-loop').checked
        };
        if (!item.url) { this._toast('URL requise', 'error'); return; }

        if (!this.playlistData) this.playlistData = { items: [] };
        if (this.editingItemIndex !== null) this.playlistData.items[this.editingItemIndex] = item;
        else this.playlistData.items.push(item);

        this.renderPlaylist();
        PiSignage.ui.closeModal('playlist-item-modal');
        this._toast('Élément enregistré (pensez à sauvegarder)', 'info');
    },

    deleteItem(index) {
        if (!this._confirm('Supprimer cet élément ?')) return;
        this.playlistData.items.splice(index, 1);
        this.renderPlaylist();
        this._toast('Élément supprimé (pensez à sauvegarder)', 'info');
    },

    moveItem(index, direction) {
        const ni = index + direction;
        if (ni < 0 || ni >= this.playlistData.items.length) return;
        const tmp = this.playlistData.items[index];
        this.playlistData.items[index] = this.playlistData.items[ni];
        this.playlistData.items[ni] = tmp;
        this.renderPlaylist();
        this._toast('Ordre modifié (pensez à sauvegarder)', 'info');
    },

    async save() {
        if (!this.playlistData) return;
        this.playlistData.autoplay = this._el('playlist-autoplay').checked;
        this.playlistData.autoLoop = this._el('playlist-autoloop').checked;
        this.playlistData.version = (this.playlistData.version || 0) + 1;
        try {
            const r = await fetch('/api/playlist.php', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.playlistData)
            });
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) {
                this._toast('Playlist sauvegardée', 'success');
                this.loadPlaylist();
            } else {
                throw new Error(result.message);
            }
        } catch (e) {
            console.error('[kiosk] save', e);
            this._toast('Erreur de sauvegarde : ' + e.message, 'error');
        }
    },

    async validate() {
        if (!this.playlistData) return;
        try {
            const r = await fetch('/api/playlist.php/validate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(this.playlistData)
            });
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) {
                const data = result.data;
                if (data.allAccessible) {
                    this._toast('Playlist valide, tous les médias sont accessibles', 'success');
                } else {
                    const bad = (data.urlChecks || []).filter(c => !c.accessible).map(c => c.url);
                    this._toast('Playlist valide, mais ' + bad.length + ' média(s) inaccessible(s)', 'warning');
                    console.warn('[kiosk] médias inaccessibles', bad);
                }
            } else {
                throw new Error(result.message);
            }
        } catch (e) {
            console.error('[kiosk] validate', e);
            this._toast('Erreur de validation : ' + e.message, 'error');
        }
    },

    async refreshPlaylist() {
        try {
            const r = await fetch('/api/playlist.php/refresh', { method: 'POST' });
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) this._toast('Signal de rechargement envoyé au player', 'success');
            else throw new Error(result.message);
        } catch (e) {
            console.error('[kiosk] refreshPlaylist', e);
            this._toast('Erreur de rechargement : ' + e.message, 'error');
        }
    },

    /* ---------- upload ---------- */
    openUpload() {
        const prog = this._el('upload-progress');
        const area = this._el('upload-area');
        if (prog) prog.style.display = 'none';
        if (area) area.style.display = 'block';
        PiSignage.ui.openModal('upload-modal');
    },

    async handleUpload(file) {
        const area = this._el('upload-area');
        const prog = this._el('upload-progress');
        if (area) area.style.display = 'none';
        if (prog) prog.style.display = 'block';

        const formData = new FormData();
        formData.append('file', file);

        const xhr = new XMLHttpRequest();
        xhr.upload.addEventListener('progress', (e) => {
            if (e.lengthComputable) {
                const pct = (e.loaded / e.total) * 100;
                const fill = this._el('progress-fill');
                const st = this._el('upload-status');
                if (fill) fill.style.width = pct + '%';
                if (st) st.textContent = 'Téléversement : ' + Math.round(pct) + '%';
            }
        });
        xhr.addEventListener('load', () => {
            try {
                if (xhr.status !== 200) throw new Error('HTTP ' + xhr.status);
                const result = JSON.parse(xhr.responseText);
                if (!result.success) throw new Error(result.message);
                this._toast('Fichier téléversé : ' + (result.data.filename || ''), 'success');
                PiSignage.ui.closeModal('upload-modal');
                if (this._confirm('Ajouter ce fichier à la playlist ?')) {
                    if (!this.playlistData) this.playlistData = { items: [] };
                    this.playlistData.items.push({ url: result.data.url, fit: 'contain', duration: 0, mute: false, loop: false });
                    this.renderPlaylist();
                    this._toast('Ajouté à la playlist (pensez à sauvegarder)', 'info');
                }
            } catch (e) {
                console.error('[kiosk] upload', e);
                this._toast('Erreur de téléversement : ' + e.message, 'error');
                PiSignage.ui.closeModal('upload-modal');
            }
        });
        xhr.addEventListener('error', () => {
            this._toast('Erreur réseau pendant le téléversement', 'error');
            PiSignage.ui.closeModal('upload-modal');
        });
        xhr.open('POST', '/api/playlist.php/upload');
        xhr.send(formData);
    },

    /* ---------- kiosk URL ---------- */
    async loadUrl() {
        try {
            const r = await fetch('/api/kiosk.php/url');
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success && result.data) {
                const el = this._el('kiosk-url');
                if (el) el.value = result.data.url || '';
            }
        } catch (e) {
            console.error('[kiosk] loadUrl', e);
        }
    },

    async updateUrl() {
        const url = (this._el('kiosk-url').value || '').trim();
        if (!url) { this._toast('URL requise', 'error'); return; }
        try {
            const r = await fetch('/api/kiosk.php/url', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url })
            });
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) { this._toast('URL kiosk mise à jour', 'success'); this.loadStatus(); }
            else throw new Error(result.message);
        } catch (e) {
            console.error('[kiosk] updateUrl', e);
            this._toast('Erreur de mise à jour de l\'URL : ' + e.message, 'error');
        }
    },

    /* ---------- chromium flags ---------- */
    async loadFlags() {
        try {
            const r = await fetch('/api/kiosk.php/flags');
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success && result.data) {
                const el = this._el('chromium-flags');
                if (el) el.value = result.data.flags || '';
            }
        } catch (e) {
            console.error('[kiosk] loadFlags', e);
        }
    },

    async updateFlags() {
        const flags = (this._el('chromium-flags').value || '').trim();
        try {
            const r = await fetch('/api/kiosk.php/flags', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ flags })
            });
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) this._toast('Flags Chromium mis à jour', 'success');
            else throw new Error(result.message);
        } catch (e) {
            console.error('[kiosk] updateFlags', e);
            this._toast('Erreur de mise à jour des flags : ' + e.message, 'error');
        }
    },

    resetFlags() {
        if (!this._confirm('Réinitialiser aux flags par défaut ?')) return;
        const def = '--ozone-platform=wayland\n--enable-features=UseOzonePlatform\n--ignore-gpu-blocklist\n--autoplay-policy=no-user-gesture-required\n--disable-infobars\n--noerrdialogs\n--disable-translate\n--no-first-run\n--incognito';
        const el = this._el('chromium-flags');
        if (el) el.value = def;
        this._toast('Flags réinitialisés (pensez à sauvegarder)', 'info');
    },

    /* ---------- status ---------- */
    async loadStatus() {
        try {
            const r = await fetch('/api/kiosk.php');
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success && result.data) this.renderStatus(result.data);
            else throw new Error(result.message);
        } catch (e) {
            console.error('[kiosk] loadStatus', e);
            const el = this._el('kiosk-status');
            if (el) el.innerHTML = '<div class="empty-state" style="padding:24px"><p>Erreur de chargement du statut</p></div>';
        }
    },

    renderStatus(data) {
        const row = (label, valueHtml) =>
            '<div style="display:flex;justify-content:space-between;align-items:center;gap:12px;padding:10px 0;border-bottom:1px solid var(--border)">'
            + '<span style="color:var(--text-dim);font-weight:600">' + label + '</span>'
            + '<span style="text-align:right">' + valueHtml + '</span></div>';

        const badge = (ok, okText, koText) =>
            '<span class="badge ' + (ok ? 'badge-success' : 'badge-danger') + '">' + (ok ? okText : koText) + '</span>';

        let html = '';
        html += row('Mode Kiosk', badge(!!data.enabled, 'Activé', 'Désactivé'));
        html += row('Chromium Player', data.useChromiumPlayer
            ? '<span class="badge badge-success">Actif</span>'
            : '<span class="badge badge-warn">Repli VLC</span>');
        html += row('URL Kiosk', '<span style="font-family:var(--font-mono);font-size:12.5px;color:var(--text-dim)">' + this._escapeHtml(data.url || 'Non définie') + '</span>');
        html += row('Statut Chromium', badge(!!data.chromiumRunning, 'En cours', 'Arrêté'));
        if (data.lastUpdate) {
            html += '<div style="display:flex;justify-content:space-between;align-items:center;gap:12px;padding:10px 0">'
                + '<span style="color:var(--text-dim);font-weight:600">Dernière mise à jour</span>'
                + '<span style="font-family:var(--font-mono);font-size:12.5px;color:var(--text-faint)">' + this._escapeHtml(data.lastUpdate) + '</span></div>';
        }

        const el = this._el('kiosk-status');
        if (el) el.innerHTML = html;

        const pill = this._el('kiosk-pill');
        if (pill) {
            const running = !!data.chromiumRunning;
            pill.className = 'status-pill ' + (running ? 'is-playing' : 'is-stopped');
            const txt = pill.querySelector('.pill-text');
            if (txt) txt.textContent = 'Chromium · ' + (running ? 'en cours' : 'arrêté');
        }
    },

    refreshStatus() {
        this.loadStatus();
        this._toast('Statut actualisé', 'info');
    },

    startAutoRefresh() {
        if (this.statusInterval) clearInterval(this.statusInterval);
        this.statusInterval = setInterval(() => this.loadStatus(), 5000);
    },

    stopAutoRefresh() {
        if (this.statusInterval) { clearInterval(this.statusInterval); this.statusInterval = null; }
    },

    /* ---------- actions ---------- */
    async restart() {
        if (!this._confirm('Redémarrer Chromium ?')) return;
        try {
            const r = await fetch('/api/kiosk.php/restart', { method: 'POST' });
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) {
                this._toast('Chromium redémarré', 'success');
                setTimeout(() => this.loadStatus(), 2000);
            } else {
                throw new Error(result.message);
            }
        } catch (e) {
            console.error('[kiosk] restart', e);
            this._toast('Erreur de redémarrage : ' + e.message, 'error');
        }
    },

    async restartSession() {
        if (!this._confirm('Redémarrer toute la session graphique (greetd) ? labwc et Chromium seront relancés.')) return;
        try {
            const r = await fetch('/api/kiosk.php/restart-session', { method: 'POST' });
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) {
                this._toast('Session redémarrée', 'success');
                setTimeout(() => this.loadStatus(), 3000);
            } else {
                throw new Error(result.message);
            }
        } catch (e) {
            console.error('[kiosk] restartSession', e);
            this._toast('Erreur de redémarrage de la session : ' + e.message, 'error');
        }
    },

    previewPlayer() {
        window.open('/player', '_blank', 'width=1280,height=720');
    },

    /* ---------- screen power (extinction programmée) ---------- */
    async loadScreen() {
        try {
            const r = await fetch('/api/kiosk.php/screen');
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success && result.data) {
                this.renderScreen(result.data);
            }
        } catch (e) {
            console.error('[kiosk] loadScreen', e);
        }
    },

    renderScreen(data) {
        const sched = data.schedule || {};
        this._setChecked('screen-schedule-enabled', sched.enabled === true);
        if (sched.on_time) this._setVal('screen-on-time', sched.on_time);
        if (sched.off_time) this._setVal('screen-off-time', sched.off_time);

        const days = Array.isArray(sched.days) ? sched.days.map(Number) : [];
        document.querySelectorAll('.screen-day').forEach((cb) => {
            cb.checked = days.indexOf(parseInt(cb.value, 10)) !== -1;
        });

        const badge = this._el('screen-state-badge');
        if (badge) {
            const state = data.state;
            let cls = 'badge';
            let label = 'Écran';
            if (state === 'on') { cls = 'badge badge-success'; label = 'Écran allumé'; }
            else if (state === 'off') { cls = 'badge badge-warn'; label = 'Écran éteint'; }
            badge.className = cls;
            badge.textContent = label;
        }
    },

    _collectScreenDays() {
        const days = [];
        document.querySelectorAll('.screen-day').forEach((cb) => {
            if (cb.checked) days.push(parseInt(cb.value, 10));
        });
        return days;
    },

    async saveScreenSchedule() {
        const body = {
            enabled: this._el('screen-schedule-enabled').checked,
            on_time: this._el('screen-on-time').value,
            off_time: this._el('screen-off-time').value,
            days: this._collectScreenDays()
        };
        try {
            const r = await fetch('/api/kiosk.php/screen', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body)
            });
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) this._toast('Planning écran enregistré', 'success');
            else throw new Error(result.message);
        } catch (e) {
            console.error('[kiosk] saveScreenSchedule', e);
            this._toast('Erreur d\'enregistrement du planning : ' + e.message, 'error');
        }
    },

    async screenOn() { await this._applyScreenPower('on'); },
    async screenOff() { await this._applyScreenPower('off'); },

    async _applyScreenPower(action) {
        try {
            const r = await fetch('/api/kiosk.php/screen/' + action, { method: 'POST' });
            if (!r.ok) throw new Error('HTTP ' + r.status);
            const result = await r.json();
            if (result.success) {
                this._toast(action === 'on' ? 'Écran allumé' : 'Écran éteint', 'success');
                setTimeout(() => this.loadScreen(), 1000);
            } else {
                throw new Error(result.message);
            }
        } catch (e) {
            console.error('[kiosk] applyScreenPower', e);
            this._toast('Erreur de commande écran : ' + e.message, 'error');
        }
    },

    /* ---------- small DOM helpers ---------- */
    _setVal(id, v) { const el = this._el(id); if (el) el.value = v; },
    _setChecked(id, v) { const el = this._el(id); if (el) el.checked = !!v; },
    _setModalField(id, v) { const el = this._el(id); if (el) el.textContent = v; },

    /* Inline SVG icons (line style, currentColor) for JS-rendered controls. */
    _icon(name) {
        const paths = {
            'edit': '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4z"/>',
            'trash': '<path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M10 11v6M14 11v6"/>',
            'chevron-up': '<path d="m6 15 6-6 6 6"/>',
            'chevron-down': '<path d="m6 9 6 6 6-6"/>'
        };
        const inner = paths[name] || '';
        return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
            + 'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + inner + '</svg>';
    }
};

/* Auto-init: kiosk-control.js is loaded only on kiosk.php (not via init.js dispatch).
 * This file is a deferred script placed before footer.php's core scripts; since all
 * are `defer`, they execute in document order then DOMContentLoaded fires. We init on
 * DOMContentLoaded so core.js/ui.js (PiSignage.ui) are guaranteed available first. */
(function () {
    function boot() {
        try {
            if (window.PiSignage && PiSignage.kiosk && PiSignage.kiosk.init) PiSignage.kiosk.init();
        } catch (e) { console.error('[kiosk] init', e); }
    }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', boot);
    } else {
        // DOM already parsed (e.g. script injected late) — defer to end of task queue.
        setTimeout(boot, 0);
    }
})();

console.log('PiSignage Kiosk module loaded');
