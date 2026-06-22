/**
 * PiSignage Player module — pilote la page « Lecteur » sur le MOTEUR RÉEL.
 *
 * Phase 2 de l'unification : VLC retiré. Le moteur affiché à l'écran est Chromium HTML5
 * (player.php sur /player). On le contrôle via /api/display.php :
 *   - transport (prev/play/pause/next/reload) -> POST ?action=command
 *   - état courant                            -> GET  ?action=state
 *   - lecture directe d'un média              -> POST ?action=playmedia
 * La diffusion d'une playlist nommée passe par /api/playlists.php?action=activate.
 * Le volume est UNIQUEMENT le volume système (ALSA) via system.php.
 *
 * NOTE: core.js définit une base PiSignage.player (state, getCurrentPlayer,
 * setCurrentPlayer, updateState). On l'étend sans casser ces membres.
 */

window.PiSignage = window.PiSignage || {};

(function () {
    // SVG icons mirroring includes/icons.php (line style, stroke=currentColor).
    const SVG = {
        open: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">',
        close: '</svg>'
    };
    const ICON = {
        play: SVG.open + '<polygon points="6 4 20 12 6 20 6 4" fill="currentColor" stroke="none"/>' + SVG.close,
        pause: SVG.open + '<rect x="6" y="4" width="4" height="16" rx="1" fill="currentColor" stroke="none"/><rect x="14" y="4" width="4" height="16" rx="1" fill="currentColor" stroke="none"/>' + SVG.close,
        volume: SVG.open + '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.5 8.5a5 5 0 0 1 0 7M19 5a9 9 0 0 1 0 14"/>' + SVG.close,
        volumeX: SVG.open + '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M23 9l-6 6M17 9l6 6"/>' + SVG.close
    };

    const base = PiSignage.player || {};
    const baseState = base.state || {};

    const player = {
        // Preserve core.js base state + setters (do not break consumers).
        state: Object.assign({
            isPlaying: false,
            isPaused: false,
            online: false,
            currentFile: null,
            index: 0,
            count: 0
        }, baseState),

        getCurrentPlayer: base.getCurrentPlayer || function () { return 'chromium'; },
        setCurrentPlayer: base.setCurrentPlayer || function () {},
        updateState: base.updateState || function (s) { Object.assign(this.state, s); },

        intervals: { status: null },
        _systemMuted: false,
        _draggingSys: false,

        /* ---------- lifecycle ---------- */
        init() {
            this.bindControls();
            this.loadSources();
            this.refreshPlayerStatus();
            this.refreshSystemVolume();
            if (this.intervals.status) clearInterval(this.intervals.status);
            this.intervals.status = setInterval(() => this.refreshPlayerStatus(), 3000);
        },

        _el(id) { return document.getElementById(id); },

        bindControls() {
            const sys = this._el('system-volume-slider');
            if (sys) {
                sys.addEventListener('pointerdown', () => { this._draggingSys = true; });
                sys.addEventListener('pointerup', () => { this._draggingSys = false; });
                sys.addEventListener('input', () => this.setSystemVolume(parseInt(sys.value, 10)));
            }
        },

        /* ---------- sources (media + playlists) ---------- */
        async loadSources() {
            try {
                const r = await PiSignage.api.media.list();
                const sel = this._el('media-select');
                if (sel && r && r.success && Array.isArray(r.data)) {
                    sel.innerHTML = '<option value="">-- Sélectionner un fichier --</option>';
                    r.data.forEach((f) => {
                        const opt = document.createElement('option');
                        opt.value = f.name;
                        opt.textContent = f.name;
                        sel.appendChild(opt);
                    });
                }
            } catch (e) { /* silent */ }

            try {
                const r = await PiSignage.api.playlists.list();
                const sel = this._el('playlist-select');
                if (sel && r && r.success) {
                    const list = Array.isArray(r.data) ? r.data : (r.data && Array.isArray(r.data.playlists) ? r.data.playlists : []);
                    sel.innerHTML = '<option value="">-- Sélectionner une playlist --</option>';
                    list.forEach((p) => {
                        const name = (typeof p === 'string') ? p : p.name;
                        if (!name) return;
                        const opt = document.createElement('option');
                        opt.value = name;
                        opt.textContent = name;
                        sel.appendChild(opt);
                    });
                }
            } catch (e) { /* silent */ }
        },

        /* ---------- status (état réel du moteur) ---------- */
        async refreshPlayerStatus() {
            try {
                const r = await PiSignage.api.request('/api/display.php?action=state');
                if (r && r.success && r.data) this.updatePlayerUI(r.data);
                else this.updatePlayerUI(null);
            } catch (e) { /* transient */ }
        },

        // d = { state:{status,name,version,index,count,current{...}}, online, active{slug,name} }
        updatePlayerUI(d) {
            const pill = this._el('topbar-status');
            const modeBadge = this._el('player-mode-badge');
            const stateBadge = this._el('player-state');
            const fileTitle = this._el('current-file');
            const sub = this._el('np-sub');
            const npBadge = this._el('np-badge');
            const playBtn = this._el('play-pause-btn');
            const playIco = this._el('play-pause-ico');
            const sFile = this._el('status-file');
            const sPos = this._el('status-position');
            const sActive = this._el('status-active');
            const sOnline = this._el('status-online');

            const st = d && d.state ? d.state : null;
            const online = !!(d && d.online);
            const active = d && d.active ? d.active : null;
            this.state.online = online;

            const activeName = (active && active.name) ? active.name : (st && st.name ? st.name : '');
            if (sActive) sActive.textContent = activeName || '—';
            if (sOnline) {
                sOnline.textContent = online ? 'En ligne' : 'Hors ligne';
                sOnline.className = 'badge ' + (online ? 'badge-success' : 'badge-danger');
            }
            if (modeBadge) modeBadge.textContent = online ? 'Écran · en ligne' : 'Écran · hors ligne';

            const status = st ? st.status : null;
            const playing = status === 'playing';
            const paused = status === 'paused';
            this.state.isPlaying = playing;
            this.state.isPaused = paused;

            if (!st || !online || status === 'idle' || !st.current) {
                if (fileTitle) fileTitle.textContent = online ? 'Aucune lecture' : 'Lecteur hors ligne';
                if (sub) sub.textContent = '—';
                if (npBadge) npBadge.style.display = 'none';
                if (playBtn) playBtn.setAttribute('data-action', 'play');
                if (playIco) playIco.innerHTML = ICON.play;
                if (stateBadge) {
                    stateBadge.textContent = online ? 'Arrêté' : 'Hors ligne';
                    stateBadge.className = 'badge badge-danger';
                }
                if (sFile) sFile.textContent = '—';
                if (sPos) sPos.textContent = '—';
                if (pill) { pill.className = 'status-pill is-stopped'; const t = pill.querySelector('.pill-text'); if (t) t.textContent = online ? 'Lecteur · arrêté' : 'Lecteur · hors ligne'; }
                return;
            }

            const cur = st.current || {};
            const file = cur.name || cur.url || 'Média';
            const idx = (st.index | 0) + 1;
            const count = st.count | 0;
            this.state.currentFile = file;
            this.state.index = st.index | 0;
            this.state.count = count;

            if (fileTitle) fileTitle.textContent = file;
            if (sub) sub.textContent = (count ? ('Élément ' + idx + ' / ' + count) : 'Lecture directe') + (activeName ? ' · ' + activeName : '');
            if (npBadge) npBadge.style.display = playing ? 'block' : 'none';

            if (playBtn) playBtn.setAttribute('data-action', playing ? 'pause' : 'play');
            if (playIco) playIco.innerHTML = playing ? ICON.pause : ICON.play;

            if (stateBadge) {
                stateBadge.textContent = playing ? 'En lecture' : (paused ? 'En pause' : 'Inconnu');
                stateBadge.className = 'badge ' + (playing ? 'badge-success' : (paused ? 'badge-warn' : ''));
            }
            if (sFile) sFile.textContent = file;
            if (sPos) sPos.textContent = count ? (idx + ' / ' + count) : '—';

            if (pill) {
                pill.className = 'status-pill ' + (playing ? 'is-playing' : 'is-paused');
                const t = pill.querySelector('.pill-text');
                if (t) t.textContent = 'Lecteur · ' + (playing ? 'en lecture' : 'pause');
            }
        },

        /* ---------- transport (commandes vers le moteur réel) ---------- */
        async _sendCommand(cmd) {
            return PiSignage.api.request('/api/display.php?action=command', {
                method: 'POST',
                body: JSON.stringify({ cmd: cmd })
            });
        },

        async control(action) {
            const map = { previous: 'prev', next: 'next', play: 'play', pause: 'pause', reload: 'reload' };
            const cmd = map[action] || action;
            try {
                const r = await this._sendCommand(cmd);
                if (r && r.success) {
                    this.log(this._actionLabel(action));
                    setTimeout(() => this.refreshPlayerStatus(), 600);
                } else {
                    PiSignage.ui.toast((r && r.message) || 'Action impossible', 'error');
                    this.log(this._actionLabel(action) + ' — échec', 'error');
                }
            } catch (e) {
                PiSignage.ui.toast('Erreur de communication', 'error');
                this.log('Erreur : ' + action, 'error');
            }
        },

        togglePlayPause() {
            this.control(this.state.isPlaying ? 'pause' : 'play');
        },

        _actionLabel(action) {
            const map = {
                play: 'Lecture', pause: 'Pause', reload: 'Rechargement du contenu',
                next: 'Élément suivant', previous: 'Élément précédent'
            };
            return map[action] || action;
        },

        /* ---------- volume système (ALSA, 0-100) ---------- */
        async refreshSystemVolume() {
            try {
                const r = await PiSignage.api.request('/api/system.php?action=get_volume');
                const vol = r && r.data && r.data.volume;
                if (r && r.success && vol != null) {
                    const slider = this._el('system-volume-slider');
                    const disp = this._el('system-volume-display');
                    if (slider && !this._draggingSys) slider.value = vol;
                    if (disp) disp.textContent = vol + '%';
                }
            } catch (e) { /* silent */ }
        },

        async setSystemVolume(volume) {
            volume = Math.max(0, Math.min(100, volume || 0));
            const disp = this._el('system-volume-display');
            if (disp) disp.textContent = volume + '%';
            try {
                // system.php reads $input['volume'] — send 'volume' (contract), keep 'value' too.
                await PiSignage.api.request('/api/system.php', {
                    method: 'POST',
                    body: JSON.stringify({ action: 'set_volume', volume: volume, value: volume })
                });
            } catch (e) { /* silent */ }
        },

        async toggleSystemMute() {
            const ico = this._el('system-mute-ico');
            const txt = this._el('system-mute-text');
            try {
                const r = await PiSignage.api.request('/api/system.php', {
                    method: 'POST',
                    body: JSON.stringify({ action: 'toggle_mute' })
                });
                if (r && r.success) {
                    this._systemMuted = !!(r.data && r.data.muted);
                    if (ico) ico.innerHTML = this._systemMuted ? ICON.volumeX : ICON.volume;
                    if (txt) txt.textContent = this._systemMuted ? 'Rétablir' : 'Couper';
                    this.log(this._systemMuted ? 'Système coupé' : 'Système rétabli');
                } else {
                    PiSignage.ui.toast((r && r.message) || 'Échec du mute', 'error');
                }
            } catch (e) { PiSignage.ui.toast('Erreur de communication', 'error'); }
        },

        /* ---------- lecture directe d'un média ---------- */
        async playMediaFile() {
            const sel = this._el('media-select');
            const file = sel ? sel.value : '';
            if (!file) { PiSignage.ui.toast('Sélectionnez un fichier', 'warning'); return; }
            try {
                const r = await PiSignage.api.request('/api/display.php?action=playmedia', {
                    method: 'POST',
                    body: JSON.stringify({ file: file })
                });
                if (r && r.success) {
                    PiSignage.ui.toast('Lecture de ' + file, 'success');
                    this.log('Lecture directe : ' + file);
                    setTimeout(() => this.refreshPlayerStatus(), 800);
                } else {
                    PiSignage.ui.toast((r && r.message) || 'Lecture impossible', 'error');
                }
            } catch (e) { PiSignage.ui.toast('Erreur de communication', 'error'); }
        },

        /* ---------- diffuser une playlist nommée (= activer) ---------- */
        async playPlaylist() {
            const sel = this._el('playlist-select');
            const name = sel ? sel.value : '';
            if (!name) { PiSignage.ui.toast('Sélectionnez une playlist', 'warning'); return; }
            try {
                const r = await PiSignage.api.request('/api/playlists.php?action=activate&name=' + encodeURIComponent(name), {
                    method: 'POST',
                    body: '{}'
                });
                if (r && r.success) {
                    PiSignage.ui.toast('Playlist « ' + name + ' » diffusée', 'success');
                    this.log('Playlist diffusée : ' + name);
                    setTimeout(() => this.refreshPlayerStatus(), 800);
                } else {
                    PiSignage.ui.toast((r && r.message) || 'Diffusion impossible', 'error');
                }
            } catch (e) { PiSignage.ui.toast('Erreur de communication', 'error'); }
        },

        /* ---------- activity log ---------- */
        log(message, type) {
            const box = this._el('status-log');
            if (!box) return;
            // Drop placeholder on first real entry.
            if (box.dataset.empty !== '0') { box.innerHTML = ''; box.dataset.empty = '0'; }
            const ts = new Date().toLocaleTimeString('fr-FR');
            const row = document.createElement('div');
            row.style.color = (type === 'error') ? 'var(--danger-text)' : 'var(--text-dim)';
            row.style.fontVariantNumeric = 'tabular-nums';
            row.textContent = '[' + ts + '] ' + message;
            box.insertBefore(row, box.firstChild);
            while (box.children.length > 12) box.removeChild(box.lastChild);
        }
    };

    PiSignage.player = player;
})();

console.log('PiSignage Player module loaded');
