/**
 * PiSignage Player module — wires the player-control-ui page to live APIs.
 * Transport (play/pause/stop/next/previous), dual volume (VLC + ALSA),
 * media/playlist playback and detailed status. Design-system / toasts only.
 *
 * NOTE: core.js defines a base PiSignage.player (state, getCurrentPlayer,
 * setCurrentPlayer, updateState). We extend it here without dropping those.
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
            currentFile: null,
            position: 0,
            duration: 0,
            volume: 50,
            isMuted: false
        }, baseState),

        getCurrentPlayer: base.getCurrentPlayer || function () {
            return (typeof currentPlayer !== 'undefined' ? currentPlayer : 'vlc');
        },
        setCurrentPlayer: base.setCurrentPlayer || function (p) {
            if (typeof currentPlayer !== 'undefined') currentPlayer = p;
            if (typeof selectedPlayer !== 'undefined') selectedPlayer = p;
            if (PiSignage.config) { PiSignage.config.currentPlayer = p; PiSignage.config.selectedPlayer = p; }
        },
        updateState: base.updateState || function (s) { Object.assign(this.state, s); },

        intervals: { status: null },
        _vlcMuted: false,
        _vlcPrevVolume: 50,
        _systemMuted: false,
        _draggingVlc: false,
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

        _fmtTime(s) {
            s = Math.max(0, Math.floor(s || 0));
            const m = Math.floor(s / 60), sec = s % 60;
            return String(m).padStart(2, '0') + ':' + String(sec).padStart(2, '0');
        },

        bindControls() {
            const vlc = this._el('vlc-volume-slider');
            if (vlc) {
                vlc.addEventListener('pointerdown', () => { this._draggingVlc = true; });
                vlc.addEventListener('pointerup', () => { this._draggingVlc = false; });
                vlc.addEventListener('input', () => this.setVlcVolume(parseInt(vlc.value, 10)));
            }
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

        /* ---------- status ---------- */
        async refreshPlayerStatus() {
            try {
                const r = await PiSignage.api.player.getStatus();
                if (r && r.success && r.data) this.updatePlayerUI(r.data);
                else this.updatePlayerUI(null);
            } catch (e) { /* transient */ }
        },

        updatePlayerUI(d) {
            const pill = this._el('topbar-status');
            const stateBadge = this._el('player-state');
            const fileTitle = this._el('current-file');
            const sub = this._el('np-sub');
            const badge = this._el('np-badge');
            const fill = this._el('progress-bar');
            const cur = this._el('current-time');
            const dur = this._el('duration');
            const playBtn = this._el('play-pause-btn');
            const playIco = this._el('play-pause-ico');

            const sFile = this._el('status-file');
            const sPos = this._el('status-position');
            const sVol = this._el('status-vlc-vol');
            const sQueue = this._el('status-queue');

            if (!d || !d.state || d.state === 'stopped') {
                this.state.isPlaying = false;
                this.state.isPaused = false;
                if (fileTitle) fileTitle.textContent = 'Aucune lecture';
                if (sub) sub.textContent = '—';
                if (badge) badge.style.display = 'none';
                if (fill) fill.style.width = '0%';
                if (cur) cur.textContent = '00:00';
                if (dur) dur.textContent = '00:00';
                if (playBtn) playBtn.setAttribute('data-action', 'play');
                if (playIco) playIco.innerHTML = ICON.play;
                if (stateBadge) { stateBadge.textContent = 'Arrêté'; stateBadge.className = 'badge badge-danger'; }
                if (sFile) sFile.textContent = '—';
                if (sPos) sPos.textContent = '00:00 / 00:00';
                if (sVol) sVol.textContent = '—';
                if (sQueue) sQueue.textContent = '—';
                if (pill) { pill.className = 'status-pill is-stopped'; const t = pill.querySelector('.pill-text'); if (t) t.textContent = 'Lecteur · arrêté'; }
                this.syncVlcVolume(d);
                return;
            }

            const playing = d.state === 'playing';
            this.state.isPlaying = playing;
            this.state.isPaused = d.state === 'paused';
            this.state.currentFile = d.current_file || null;
            this.state.position = d.position || 0;
            this.state.duration = d.duration || 0;

            const file = d.current_file || 'Média';
            const pos = d.position || 0, len = d.duration || 0;
            const queue = Array.isArray(d.playlist) ? d.playlist.length : 0;

            if (fileTitle) fileTitle.textContent = file;
            if (sub) sub.textContent = (queue ? queue + ' éléments en file' : 'Lecture directe');
            if (badge) badge.style.display = playing ? 'block' : 'none';
            if (fill) fill.style.width = (len ? Math.min(100, (pos / len) * 100) : 0) + '%';
            if (cur) cur.textContent = this._fmtTime(pos);
            if (dur) dur.textContent = this._fmtTime(len);

            if (playBtn) playBtn.setAttribute('data-action', playing ? 'pause' : 'play');
            if (playIco) playIco.innerHTML = playing ? ICON.pause : ICON.play;

            if (stateBadge) {
                stateBadge.textContent = playing ? 'En lecture' : (d.state === 'paused' ? 'En pause' : 'Inconnu');
                stateBadge.className = 'badge ' + (playing ? 'badge-success' : (d.state === 'paused' ? 'badge-warn' : ''));
            }
            if (sFile) sFile.textContent = file;
            if (sPos) sPos.textContent = this._fmtTime(pos) + ' / ' + this._fmtTime(len);
            if (sVol) sVol.textContent = (d.volume != null ? Math.round(d.volume) + '%' : '—');
            if (sQueue) sQueue.textContent = queue + (queue > 1 ? ' éléments' : ' élément');

            if (pill) {
                pill.className = 'status-pill ' + (playing ? 'is-playing' : 'is-paused');
                const t = pill.querySelector('.pill-text');
                if (t) t.textContent = 'Lecteur · ' + (playing ? 'en lecture' : 'pause');
            }

            this.syncVlcVolume(d);
        },

        syncVlcVolume(d) {
            // Don't fight the user while they drag, and don't override during mute.
            if (this._draggingVlc || this._vlcMuted) return;
            const vol = (d && d.volume != null) ? Math.round(d.volume) : null;
            if (vol == null) return;
            this.state.volume = vol;
            const slider = this._el('vlc-volume-slider');
            const disp = this._el('vlc-volume-display');
            if (slider) slider.value = vol;
            if (disp) disp.textContent = vol + '%';
        },

        /* ---------- transport ---------- */
        async control(action) {
            try {
                const r = await PiSignage.api.player.control(action);
                if (r && r.success) {
                    this.log(this._actionLabel(action));
                    setTimeout(() => this.refreshPlayerStatus(), 400);
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
                play: 'Lecture', pause: 'Pause', stop: 'Arrêt',
                next: 'Piste suivante', previous: 'Piste précédente'
            };
            return map[action] || action;
        },

        async toggleFullscreen() {
            try {
                const r = await PiSignage.api.player.control('set_fullscreen', { enabled: true });
                if (r && r.success) { PiSignage.ui.toast('Plein écran basculé', 'success'); this.log('Plein écran'); }
                else PiSignage.ui.toast((r && r.message) || 'Impossible de basculer', 'error');
            } catch (e) { PiSignage.ui.toast('Erreur de communication', 'error'); }
        },

        async clearPlaylist() {
            if (!PiSignage.ui.confirm("Vider la file d'attente VLC ?")) return;
            try {
                const r = await PiSignage.api.player.control('clear_playlist');
                if (r && r.success) {
                    PiSignage.ui.toast("File d'attente vidée", 'success');
                    this.log("File d'attente vidée");
                    setTimeout(() => this.refreshPlayerStatus(), 400);
                } else {
                    PiSignage.ui.toast((r && r.message) || 'Échec', 'error');
                }
            } catch (e) { PiSignage.ui.toast('Erreur de communication', 'error'); }
        },

        /* ---------- VLC volume (0-100) ---------- */
        async setVlcVolume(volume) {
            volume = Math.max(0, Math.min(100, volume || 0));
            this.state.volume = volume;
            const disp = this._el('vlc-volume-display');
            if (disp) disp.textContent = volume + '%';
            try {
                await PiSignage.api.player.setVolume(volume);
            } catch (e) { /* silent — slider stays responsive */ }
        },

        async toggleVlcMute() {
            const ico = this._el('vlc-mute-ico');
            const txt = this._el('vlc-mute-text');
            const slider = this._el('vlc-volume-slider');
            if (this._vlcMuted) {
                this._vlcMuted = false;
                const restore = this._vlcPrevVolume || 50;
                if (slider) slider.value = restore;
                await this.setVlcVolume(restore);
                if (ico) ico.innerHTML = ICON.volume;
                if (txt) txt.textContent = 'Couper';
                this.log('Son VLC rétabli');
            } else {
                this._vlcPrevVolume = this.state.volume || 50;
                this._vlcMuted = true;
                if (slider) slider.value = 0;
                await this.setVlcVolume(0);
                if (ico) ico.innerHTML = ICON.volumeX;
                if (txt) txt.textContent = 'Rétablir';
                this.log('Son VLC coupé');
            }
        },

        /* ---------- system volume (ALSA, 0-100) ---------- */
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

        /* ---------- play media / playlist ---------- */
        async playMediaFile() {
            const sel = this._el('media-select');
            const file = sel ? sel.value : '';
            if (!file) { PiSignage.ui.toast('Sélectionnez un fichier', 'warning'); return; }
            try {
                const r = await PiSignage.api.player.playFile(file);
                if (r && r.success) {
                    PiSignage.ui.toast('Lecture de ' + file, 'success');
                    this.log('Lecture du fichier : ' + file);
                    setTimeout(() => this.refreshPlayerStatus(), 600);
                } else {
                    PiSignage.ui.toast((r && r.message) || 'Lecture impossible', 'error');
                }
            } catch (e) { PiSignage.ui.toast('Erreur de communication', 'error'); }
        },

        async playPlaylist() {
            const sel = this._el('playlist-select');
            const name = sel ? sel.value : '';
            if (!name) { PiSignage.ui.toast('Sélectionnez une playlist', 'warning'); return; }
            try {
                const r = await PiSignage.api.player.playPlaylist(name);
                if (r && r.success) {
                    PiSignage.ui.toast('Playlist « ' + name + ' » lancée', 'success');
                    this.log('Playlist lancée : ' + name);
                    setTimeout(() => this.refreshPlayerStatus(), 600);
                } else {
                    PiSignage.ui.toast((r && r.message) || 'Lancement impossible', 'error');
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
