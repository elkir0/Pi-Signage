/**
 * PiSignage Media module — design-system rewrite.
 * Lists media in a .media-grid, drives the upload modal (drag&drop + progress),
 * handles delete, search and type filters. Wires to PiSignage.api.media.*.
 * No emoji, toasts via PiSignage.ui, no functions.js dependency.
 */
window.PiSignage = window.PiSignage || {};

PiSignage.media = {
    files: [],
    filter: 'all',
    query: '',
    uploading: false,

    /* SVG icon markup (line style, stroke=currentColor) — JS-side equivalents of icon(). */
    _svg(inner, w = 18) {
        return '<svg viewBox="0 0 24 24" width="' + w + '" height="' + w + '" fill="none" stroke="currentColor" '
             + 'stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + inner + '</svg>';
    },
    _icons: {
        media: '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="m21 15-5-5L5 21"/>',
        play:  '<polygon points="6 4 20 12 6 20 6 4"/>',
        trash: '<path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M10 11v6M14 11v6"/>',
        audio: '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
        folder:'<path d="M4 20a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2z"/>'
    },

    init() {
        this.cacheDom();
        this.bindEvents();
        this.loadMediaFiles();
    },

    cacheDom() {
        this.$grid = document.getElementById('media-grid');
        this.$search = document.getElementById('media-search');
        this.$filters = document.getElementById('media-filters');
        this.$modal = document.getElementById('upload-modal');
        this.$zone = document.getElementById('upload-zone');
        this.$input = document.getElementById('upload-input');
        this.$progress = document.getElementById('upload-progress');
        this.$progressFill = document.getElementById('upload-progress-fill');
        this.$progressPct = document.getElementById('upload-progress-pct');
        this.$progressLabel = document.getElementById('upload-progress-label');
    },

    bindEvents() {
        if (this.$search) {
            this.$search.addEventListener('input', (e) => {
                this.query = (e.target.value || '').toLowerCase().trim();
                this.renderGrid();
            });
        }
        if (this.$filters) {
            this.$filters.addEventListener('click', (e) => {
                const btn = e.target.closest('.filter-btn');
                if (!btn) return;
                this.$filters.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.filter = btn.dataset.filter || 'all';
                this.renderGrid();
            });
        }
        if (this.$input) {
            this.$input.addEventListener('change', () => {
                if (this.$input.files && this.$input.files.length) {
                    this.upload(Array.from(this.$input.files));
                    this.$input.value = '';
                }
            });
        }
        if (this.$zone) {
            this.$zone.addEventListener('click', () => { if (!this.uploading) this.$input.click(); });
            this.$zone.addEventListener('dragover', (e) => {
                e.preventDefault();
                this.$zone.classList.add('dragging');
            });
            this.$zone.addEventListener('dragleave', (e) => {
                e.preventDefault();
                this.$zone.classList.remove('dragging');
            });
            this.$zone.addEventListener('drop', (e) => {
                e.preventDefault();
                this.$zone.classList.remove('dragging');
                const dropped = e.dataTransfer && e.dataTransfer.files;
                if (dropped && dropped.length) this.upload(Array.from(dropped));
            });
        }
    },

    /* ---------- data ---------- */
    async loadMediaFiles() {
        try {
            const r = await PiSignage.api.media.list();
            if (r && r.success) {
                this.files = Array.isArray(r.data) ? r.data : [];
                this.renderGrid();
            } else {
                this.renderError((r && r.message) || 'Réponse invalide');
            }
        } catch (e) {
            this.renderError('Erreur de chargement des médias');
        }
    },

    /* ---------- helpers ---------- */
    _fmtSize(file) {
        if (file.size_formatted) return file.size_formatted;
        const b = file.size || 0;
        if (!b) return '0 o';
        const u = ['o', 'Ko', 'Mo', 'Go', 'To'];
        const i = Math.floor(Math.log(b) / Math.log(1024));
        return (b / Math.pow(1024, i)).toFixed(i >= 2 ? 1 : 0).replace('.', ',') + ' ' + u[i];
    },

    _typeLabel(type) {
        return ({ video: 'Vidéo', image: 'Image', audio: 'Audio' })[type] || 'Fichier';
    },

    _esc(s) {
        return String(s).replace(/[&<>"']/g, c => (
            { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
        ));
    },

    _visibleFiles() {
        return this.files.filter(f => {
            if (this.filter !== 'all' && f.type !== this.filter) return false;
            if (this.query && !(f.name || '').toLowerCase().includes(this.query)) return false;
            return true;
        });
    },

    /* ---------- render ---------- */
    renderError(msg) {
        if (!this.$grid) return;
        this.$grid.innerHTML =
            '<div class="empty-state">' + this._svg(this._icons.media, 54) +
            '<h3>Impossible de charger les médias</h3><p>' + this._esc(msg) + '</p></div>';
    },

    renderGrid() {
        if (!this.$grid) return;

        if (this.files.length === 0) {
            this.$grid.innerHTML =
                '<div class="empty-state">' + this._svg(this._icons.media, 54) +
                '<h3>Aucun média</h3><p>Téléversez des vidéos, images ou fichiers audio pour commencer.</p></div>';
            return;
        }

        const list = this._visibleFiles();
        if (list.length === 0) {
            this.$grid.innerHTML =
                '<div class="empty-state">' + this._svg(this._icons.media, 54) +
                '<h3>Aucun résultat</h3><p>Aucun média ne correspond à votre recherche.</p></div>';
            return;
        }

        this.$grid.innerHTML = list.map(f => this._cardHtml(f)).join('');
    },

    _cardHtml(f) {
        const name = this._esc(f.name);
        let thumb;
        if (f.type === 'image' && f.path) {
            thumb = '<img src="' + this._esc(f.path) + '" alt="' + name + '" loading="lazy">';
        } else if (f.type === 'audio') {
            thumb = this._svg(this._icons.audio, 34);
        } else {
            thumb = this._svg(this._icons.media, 34);
        }
        return '' +
            '<div class="media-card" data-name="' + name + '">' +
                '<div class="media-card-thumb">' + thumb + '</div>' +
                '<div class="media-card-body">' +
                    '<div class="media-card-name" title="' + name + '">' + name + '</div>' +
                    '<div class="media-card-meta">' + this._typeLabel(f.type) + ' · ' + this._fmtSize(f) + '</div>' +
                    '<div class="row" style="gap:6px;margin-top:10px">' +
                        '<button class="btn btn-ghost btn-sm" type="button" title="Lire" ' +
                            'onclick="PiSignage.media.playFile(\'' + name.replace(/'/g, "\\'") + '\')">' +
                            this._svg(this._icons.play, 14) + 'Lire</button>' +
                        '<button class="btn btn-danger btn-sm" type="button" title="Supprimer" ' +
                            'onclick="PiSignage.media.deleteFile(\'' + name.replace(/'/g, "\\'") + '\')">' +
                            this._svg(this._icons.trash, 14) + '</button>' +
                    '</div>' +
                '</div>' +
            '</div>';
    },

    /* ---------- actions ---------- */
    openUpload() {
        if (this.$progress) this.$progress.style.display = 'none';
        if (this.$progressFill) this.$progressFill.style.width = '0%';
        if (this.$progressPct) this.$progressPct.textContent = '0%';
        PiSignage.ui.openModal('upload-modal');
    },

    async deleteFile(name) {
        if (!PiSignage.ui.confirm('Supprimer le fichier "' + name + '" ?')) return;
        try {
            const r = await PiSignage.api.media.delete(name);
            if (r && r.success) {
                PiSignage.ui.toast('Fichier supprimé', 'success');
                this.loadMediaFiles();
            } else {
                PiSignage.ui.toast((r && r.message) || 'Suppression impossible', 'error');
            }
        } catch (e) {
            PiSignage.ui.toast('Erreur de suppression', 'error');
        }
    },

    async playFile(name) {
        try {
            const r = await PiSignage.api.player.playFile(name);
            if (r && r.success) PiSignage.ui.toast('Lecture de ' + name, 'success');
            else PiSignage.ui.toast((r && r.message) || 'Lecture impossible', 'error');
        } catch (e) {
            PiSignage.ui.toast('Erreur de lecture', 'error');
        }
    },

    /* ---------- upload ---------- */
    async upload(files) {
        if (this.uploading) {
            PiSignage.ui.toast('Téléversement déjà en cours', 'warning');
            return;
        }
        if (!files || !files.length) return;

        this.uploading = true;
        if (this.$progress) this.$progress.style.display = 'block';
        if (this.$progressLabel) {
            const total = files.reduce((s, f) => s + (f.size || 0), 0);
            this.$progressLabel.textContent = files.length + ' fichier(s) · ' + this._fmtSize({ size: total });
        }
        this._setProgress(0);

        try {
            const r = await PiSignage.api.media.upload(files, (p) => this._setProgress(p.percent));
            if (r && r.success) {
                PiSignage.ui.toast('Téléversement terminé', 'success');
                PiSignage.ui.closeModal('upload-modal');
                this.loadMediaFiles();
            } else {
                PiSignage.ui.toast((r && r.message) || 'Échec du téléversement', 'error');
            }
        } catch (e) {
            PiSignage.ui.toast('Erreur de téléversement : ' + e.message, 'error');
        } finally {
            this.uploading = false;
        }
    },

    _setProgress(pct) {
        pct = Math.max(0, Math.min(100, Math.round(pct || 0)));
        if (this.$progressFill) this.$progressFill.style.width = pct + '%';
        if (this.$progressPct) this.$progressPct.textContent = pct + '%';
    }
};

/* Backward-compat global used elsewhere (e.g. init.js youtube auto-refresh). */
window.loadMediaFiles = () => PiSignage.media.loadMediaFiles();

console.log('PiSignage Media module loaded');
