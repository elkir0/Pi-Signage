/**
 * Zaforge — Music module. Global background music settings for the Chromium player.
 */
window.PiSignage = window.PiSignage || {};

PiSignage.music = {
    config: null,
    presets: [],
    audioFiles: [],

    init() {
        this.cacheDom();
        this.bindEvents();
        this.load();
    },

    cacheDom() {
        this.$enabled = document.getElementById('music-enabled');
        this.$enabledLabel = document.getElementById('music-enabled-label');
        this.$source = document.getElementById('music-source');
        this.$radio = document.getElementById('music-radio');
        this.$radioMeta = document.getElementById('music-radio-meta');
        this.$radioPanel = document.getElementById('music-radio-panel');
        this.$localPanel = document.getElementById('music-local-panel');
        this.$playback = document.getElementById('music-playback');
        this.$tracks = document.getElementById('music-tracks');
        this.$summary = document.getElementById('music-summary');
    },

    bindEvents() {
        const rerender = () => this.renderSummary();
        if (this.$enabled) this.$enabled.addEventListener('change', rerender);
        if (this.$source) this.$source.addEventListener('change', () => {
            this.togglePanels();
            this.renderSummary();
        });
        if (this.$radio) this.$radio.addEventListener('change', () => {
            this.renderRadioMeta();
            this.renderSummary();
        });
        if (this.$playback) this.$playback.addEventListener('change', rerender);
        if (this.$tracks) this.$tracks.addEventListener('change', (e) => {
            if (e.target && e.target.matches('[data-track]')) this.renderSummary();
        });
    },

    async load() {
        try {
            const res = await PiSignage.api.backgroundMusic.get();
            if (!res || !res.success || !res.data) throw new Error((res && res.message) || 'Réponse invalide');
            this.config = res.data.config || {};
            this.presets = Array.isArray(res.data.presets) ? res.data.presets : [];
            this.audioFiles = Array.isArray(res.data.audio_files) ? res.data.audio_files : [];
            this.render();
        } catch (e) {
            if (this.$summary) this.$summary.textContent = 'Impossible de charger la configuration musique.';
            PiSignage.ui.toast('Erreur de chargement musique', 'error');
        }
    },

    render() {
        const cfg = this.config || {};
        if (this.$enabled) this.$enabled.checked = !!cfg.enabled;
        if (this.$source) this.$source.value = cfg.source === 'local' ? 'local' : 'webradio';
        if (this.$playback) this.$playback.value = cfg.playback === 'random' ? 'random' : 'order';
        this.renderRadios(cfg.radio);
        this.renderTracks(cfg.tracks || []);
        this.togglePanels();
        this.renderRadioMeta();
        this.renderSummary();
    },

    renderRadios(selected) {
        if (!this.$radio) return;
        this.$radio.innerHTML = this.presets.map((p) => {
            const sel = p.id === selected ? ' selected' : '';
            return '<option value="' + this.esc(p.id) + '"' + sel + '>'
                + this.esc(p.name) + ' · ' + this.esc(p.genre || 'Radio') + '</option>';
        }).join('');
    },

    renderTracks(selectedTracks) {
        if (!this.$tracks) return;
        const selected = new Set(selectedTracks || []);
        if (!this.audioFiles.length) {
            this.$tracks.innerHTML = '<div class="empty-state" style="padding:26px 10px">'
                + '<h3>Aucun fichier audio</h3><p>Téléversez des MP3/OGG dans Médias pour les utiliser ici.</p></div>';
            return;
        }
        this.$tracks.innerHTML = this.audioFiles.map((file) => {
            const checked = selected.has(file.path) ? ' checked' : '';
            return '<label class="row" style="justify-content:space-between;gap:12px;margin:0 0 8px;padding:10px 12px;border:1px solid var(--border);border-radius:12px;cursor:pointer;background:var(--surface)">'
                + '<span style="min-width:0"><span style="display:block;font-weight:650;color:var(--text);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + this.esc(file.name) + '</span>'
                + '<span style="display:block;font-size:11.5px;color:var(--text-faint)">' + this.formatSize(file.size || 0) + '</span></span>'
                + '<span class="toggle-switch"><input type="checkbox" data-track="' + this.esc(file.path) + '"' + checked + '><span class="toggle-slider"></span></span>'
                + '</label>';
        }).join('');
    },

    togglePanels() {
        const local = this.$source && this.$source.value === 'local';
        if (this.$radioPanel) this.$radioPanel.style.display = local ? 'none' : '';
        if (this.$localPanel) this.$localPanel.style.display = local ? '' : 'none';
    },

    renderRadioMeta() {
        if (!this.$radioMeta || !this.$radio) return;
        const preset = this.presets.find((p) => p.id === this.$radio.value);
        this.$radioMeta.textContent = preset ? (preset.genre + ' · ' + preset.url) : '';
    },

    renderSummary() {
        if (!this.$summary) return;
        const enabled = !!(this.$enabled && this.$enabled.checked);
        if (this.$enabledLabel) {
            this.$enabledLabel.textContent = enabled ? 'Activé' : 'Désactivé';
            this.$enabledLabel.style.color = enabled ? 'var(--accent-text)' : 'var(--text-dim)';
        }
        if (!enabled) {
            this.$summary.innerHTML = '<strong>Mode désactivé.</strong><br>Les vidéos gardent leur réglage sonore normal.';
            return;
        }
        if (this.$source && this.$source.value === 'local') {
            const count = this.selectedTracks().length;
            const mode = this.$playback && this.$playback.value === 'random' ? 'aléatoire' : 'dans l’ordre choisi';
            this.$summary.innerHTML = '<strong>Mode local activé.</strong><br>'
                + count + ' fichier(s) audio seront joués en boucle, ' + mode + '.<br>'
                + 'Le son des vidéos sera coupé automatiquement.';
            return;
        }
        const preset = this.presets.find((p) => this.$radio && p.id === this.$radio.value);
        this.$summary.innerHTML = '<strong>Webradio activée.</strong><br>'
            + 'Station: ' + this.esc(preset ? preset.name : 'Webradio') + '.<br>'
            + 'Le son des vidéos sera coupé automatiquement.';
    },

    selectedTracks() {
        if (!this.$tracks) return [];
        return Array.from(this.$tracks.querySelectorAll('[data-track]:checked')).map((el) => el.getAttribute('data-track'));
    },

    selectAllTracks(checked) {
        if (!this.$tracks) return;
        this.$tracks.querySelectorAll('[data-track]').forEach((el) => { el.checked = !!checked; });
        this.renderSummary();
    },

    async save() {
        const payload = {
            enabled: !!(this.$enabled && this.$enabled.checked),
            source: (this.$source && this.$source.value === 'local') ? 'local' : 'webradio',
            radio: this.$radio ? this.$radio.value : '',
            playback: (this.$playback && this.$playback.value === 'random') ? 'random' : 'order',
            tracks: this.selectedTracks()
        };
        if (payload.enabled && payload.source === 'local' && payload.tracks.length === 0) {
            PiSignage.ui.toast('Sélectionnez au moins un fichier audio, ou choisissez Webradio', 'warning');
            return;
        }
        try {
            const res = await PiSignage.api.backgroundMusic.save(payload);
            if (res && res.success && res.data) {
                this.config = res.data.config || payload;
                this.presets = Array.isArray(res.data.presets) ? res.data.presets : this.presets;
                this.audioFiles = Array.isArray(res.data.audio_files) ? res.data.audio_files : this.audioFiles;
                this.render();
                PiSignage.ui.toast(res.message || 'Musique enregistrée', 'success');
            } else {
                PiSignage.ui.toast((res && res.message) || 'Sauvegarde impossible', 'error');
            }
        } catch (e) {
            PiSignage.ui.toast('Erreur de sauvegarde musique', 'error');
        }
    },

    formatSize(bytes) {
        if (!bytes) return '0 o';
        const units = ['o', 'Ko', 'Mo', 'Go'];
        const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
        return (bytes / Math.pow(1024, i)).toFixed(i >= 2 ? 1 : 0).replace('.', ',') + ' ' + units[i];
    },

    esc(value) {
        return String(value == null ? '' : value).replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
        }[c]));
    }
};

console.log('PiSignage Music module loaded');
