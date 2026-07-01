/**
 * PiSignage — Module PLAYLISTS (Phase 1 de l'unification diffusion).
 *
 * Pilote l'API unifiée /api/playlists.php :
 *   - liste + playlist ACTIVE (diffusée à l'écran)
 *   - composition (éditeur) + enregistrement
 *   - "Diffuser à l'écran" (activate)
 *
 * Un item de playlist = { url:<media.path>, type, name, duration, fit, mute, loop }.
 * Réorganisation par boutons monter/descendre (robuste) + glisser depuis la bibliothèque.
 */

window.PiSignage = window.PiSignage || {};

PiSignage.playlists = {

    /* ----------------------------- État ----------------------------- */
    list: [],              // playlists normalisées (depuis l'API)
    activeSlug: null,      // slug diffusé à l'écran
    media: [],             // bibliothèque média {name, path, type, size_formatted}
    mediaFilter: 'all',
    mediaSearch: '',

    // Playlist en cours d'édition
    editing: {
        slug: null,        // null = nouvelle playlist
        name: '',
        autoplay: true,
        autoLoop: true,
        items: []          // [{url, type, name, duration, fit, mute, loop}]
    },
    selectedIndex: null,

    /* ------------------------- Icônes SVG inline ------------------------- */
    _svg: function (inner) {
        return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
             + 'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + inner + '</svg>';
    },
    _icons: {
        video:   '<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/>',
        audio:   '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.5 8.5a5 5 0 0 1 0 7M19 5a9 9 0 0 1 0 14"/>',
        image:   '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="m21 15-5-5L5 21"/>',
        file:    '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/>',
        plus:    '<path d="M12 5v14M5 12h14"/>',
        trash:   '<path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M10 11v6M14 11v6"/>',
        play:    '<polygon points="6 4 20 12 6 20 6 4"/>',
        edit:    '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4z"/>',
        up:      '<path d="m18 15-6-6-6 6"/>',
        down:    '<path d="m6 9 6 6 6-6"/>',
        drag:    '<circle cx="9" cy="6" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="6" r="1.4" fill="currentColor" stroke="none"/><circle cx="9" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="9" cy="18" r="1.4" fill="currentColor" stroke="none"/><circle cx="15" cy="18" r="1.4" fill="currentColor" stroke="none"/>',
        playlist:'<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>'
    },

    /* ----------------------------- Helpers ----------------------------- */
    esc: function (s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    },

    typeIcon: function (type) {
        var t = (type || '').toLowerCase();
        if (t.indexOf('video') !== -1) return this._svg(this._icons.video);
        if (t.indexOf('audio') !== -1) return this._svg(this._icons.audio);
        if (t.indexOf('image') !== -1) return this._svg(this._icons.image);
        return this._svg(this._icons.file);
    },

    // Classe courte (video/image/audio/file) à partir d'un type MIME ou simple.
    typeClass: function (type) {
        var t = (type || '').toLowerCase();
        if (t.indexOf('video') !== -1) return 'video';
        if (t.indexOf('audio') !== -1) return 'audio';
        if (t.indexOf('image') !== -1) return 'image';
        return 'file';
    },

    fmtDate: function (mtime) {
        if (!mtime) return '';
        var d = new Date(mtime * 1000);
        if (isNaN(d.getTime())) return '';
        return d.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
    },

    /* ------------------------------ Init ------------------------------ */
    init: function () {
        this.bindEditorChrome();
        this.load();
    },

    // Recharge la liste + l'état "active" depuis l'API unifiée.
    load: async function () {
        try {
            var res = await PiSignage.api.request('/api/playlists.php');
            if (res && res.success && res.data) {
                this.list = res.data.playlists || [];
                this.activeSlug = res.data.active || null;
            } else {
                this.list = [];
                this.activeSlug = null;
            }
        } catch (e) {
            console.error('Erreur chargement playlists:', e);
            PiSignage.ui.toast('Erreur de chargement des playlists', 'error');
            this.list = [];
            this.activeSlug = null;
        }
        this.renderActiveBanner();
        this.renderCards();
    },

    activePlaylist: function () {
        if (!this.activeSlug) return null;
        for (var i = 0; i < this.list.length; i++) {
            if (this.list[i].slug === this.activeSlug) return this.list[i];
        }
        return null;
    },

    /* ============================ VUE LISTE ============================ */

    renderActiveBanner: function () {
        var banner = document.getElementById('pl-active-banner');
        var pill = document.getElementById('pl-active-pill');
        var active = this.activePlaylist();
        if (!banner) return;

        if (!active) {
            banner.style.display = 'none';
            if (pill) pill.style.display = 'none';
            return;
        }
        banner.style.display = '';
        var nameEl = document.getElementById('pl-active-name');
        var metaEl = document.getElementById('pl-active-meta');
        if (nameEl) nameEl.textContent = active.name;
        if (metaEl) {
            var n = active.item_count != null ? active.item_count : (active.items ? active.items.length : 0);
            metaEl.textContent = n + (n === 1 ? ' élément' : ' éléments') + ' · diffusée à l\'écran';
        }
        var editBtn = document.getElementById('pl-active-edit-btn');
        if (editBtn) {
            var slug = active.slug;
            editBtn.onclick = function () { PiSignage.playlists.edit(slug); };
        }
        // Pastille discrète dans la topbar.
        if (pill) {
            pill.style.display = '';
            var pt = document.getElementById('pl-active-pill-text');
            if (pt) pt.textContent = 'À l\'écran : ' + active.name;
        }
    },

    renderCards: function () {
        var container = document.getElementById('pl-cards');
        if (!container) return;

        if (!this.list.length) {
            container.innerHTML =
                '<div class="empty-state" style="grid-column:1/-1">'
              + this._svg(this._icons.playlist)
              + '<h3>Aucune playlist</h3>'
              + '<p>Créez votre première playlist pour composer et diffuser vos médias.</p>'
              + '<button class="btn btn-primary" type="button" style="margin-top:16px" onclick="PiSignage.playlists.newPlaylist()">'
              + this._svg(this._icons.plus) + 'Nouvelle playlist</button>'
              + '</div>';
            return;
        }

        var self = this;
        container.innerHTML = this.list.map(function (pl) {
            var isActive = pl.slug === self.activeSlug;
            var count = pl.item_count != null ? pl.item_count : (pl.items ? pl.items.length : 0);
            var slug = self.esc(pl.slug);
            var name = self.esc(pl.name);

            return '<div class="card">'
                +   '<div class="card-head" style="margin-bottom:12px">'
                +     '<h3 class="card-title" style="min-width:0">'
                +       '<span style="display:inline-flex;color:var(--text-dim)">' + self._svg(self._icons.playlist) + '</span>'
                +       '<span style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + name + '</span>'
                +     '</h3>'
                +     (isActive ? '<span class="badge badge-success"><span class="live-dot"></span>À l\'écran</span>' : '')
                +   '</div>'
                +   '<div style="font-size:12px;color:var(--text-faint);margin-bottom:14px">'
                +     count + (count === 1 ? ' élément' : ' éléments')
                +     (pl.modified ? ' · ' + self.fmtDate(pl.modified) : '')
                +   '</div>'
                +   '<div class="row" style="gap:8px;flex-wrap:wrap">'
                +     '<button class="btn btn-primary btn-sm" type="button" onclick="PiSignage.playlists.activate(\'' + slug + '\')" title="Mettre cette playlist à l\'écran">'
                +       self._svg(self._icons.play) + (isActive ? 'Rediffuser' : 'Diffuser à l\'écran') + '</button>'
                +     '<button class="btn btn-secondary btn-sm" type="button" onclick="PiSignage.playlists.edit(\'' + slug + '\')">'
                +       self._svg(self._icons.edit) + 'Modifier</button>'
                +     '<button class="btn btn-danger btn-sm" type="button" onclick="PiSignage.playlists.remove(\'' + slug + '\',\'' + name + '\')">'
                +       self._svg(self._icons.trash) + 'Supprimer</button>'
                +   '</div>'
                + '</div>';
        }).join('');
    },

    /* "Diffuser à l'écran" : POST ?action=activate&name=SLUG */
    activate: async function (slug) {
        try {
            var res = await PiSignage.api.request(
                '/api/playlists.php?action=activate&name=' + encodeURIComponent(slug),
                { method: 'POST' }
            );
            if (res && res.success) {
                PiSignage.ui.toast('Playlist diffusée à l\'écran', 'success');
                await this.load();
            } else {
                PiSignage.ui.toast('Erreur : ' + ((res && res.message) || 'diffusion impossible'), 'error');
            }
        } catch (e) {
            console.error('Erreur activation playlist:', e);
            PiSignage.ui.toast('Erreur lors de la diffusion', 'error');
        }
    },

    /* Suppression (avec confirmation) : DELETE ?name=SLUG */
    remove: async function (slug, name) {
        if (!PiSignage.ui.confirm('Supprimer la playlist « ' + name + ' » ?')) return;
        try {
            var res = await PiSignage.api.request(
                '/api/playlists.php?name=' + encodeURIComponent(slug),
                { method: 'DELETE' }
            );
            if (res && res.success) {
                PiSignage.ui.toast('Playlist supprimée', 'success');
                await this.load();
            } else {
                PiSignage.ui.toast('Erreur : ' + ((res && res.message) || 'suppression impossible'), 'error');
            }
        } catch (e) {
            console.error('Erreur suppression playlist:', e);
            PiSignage.ui.toast('Erreur lors de la suppression', 'error');
        }
    },

    /* ============================ VUE ÉDITEUR ============================ */

    showList: function () {
        document.getElementById('pl-editor-view').style.display = 'none';
        document.getElementById('pl-list-view').style.display = '';
        var newBtn = document.getElementById('pl-new-btn');
        if (newBtn) newBtn.style.display = '';
        this.selectedIndex = null;
    },

    showEditor: function () {
        document.getElementById('pl-list-view').style.display = 'none';
        document.getElementById('pl-editor-view').style.display = '';
        var newBtn = document.getElementById('pl-new-btn');
        if (newBtn) newBtn.style.display = 'none';
    },

    newPlaylist: function () {
        this.editing = { slug: null, name: '', autoplay: true, autoLoop: true, items: [] };
        this.selectedIndex = null;
        this.syncEditorForm();
        this.showEditor();
        this.loadMedia();
        this.renderItems();
        this.renderItemOptions();
        var nameInput = document.getElementById('pl-name');
        if (nameInput) nameInput.focus();
    },

    /* Charge une playlist existante et ouvre l'éditeur : GET ?name=SLUG */
    edit: async function (slug) {
        try {
            var res = await PiSignage.api.request('/api/playlists.php?name=' + encodeURIComponent(slug));
            if (!res || !res.success || !res.data || res.data.exists === false) {
                PiSignage.ui.toast('Playlist introuvable', 'error');
                return;
            }
            var pl = res.data;
            this.editing = {
                slug: pl.slug || slug,
                name: pl.name || '',
                autoplay: pl.autoplay !== false,
                autoLoop: pl.autoLoop !== false,
                items: (pl.items || []).map(function (it) {
                    return {
                        url: it.url,
                        type: it.type || '',
                        name: it.name || '',
                        duration: typeof it.duration === 'number' ? it.duration : (parseFloat(it.duration) || 0),
                        fit: (it.fit === 'cover') ? 'cover' : 'contain',
                        mute: !!it.mute,
                        loop: !!it.loop,
                        subtitles: it.subtitles !== false
                    };
                })
            };
            this.selectedIndex = null;
            this.syncEditorForm();
            this.showEditor();
            this.loadMedia();
            this.renderItems();
            this.renderItemOptions();
        } catch (e) {
            console.error('Erreur chargement playlist:', e);
            PiSignage.ui.toast('Erreur de chargement de la playlist', 'error');
        }
    },

    // Branche les contrôles statiques de l'éditeur (nom, toggles, recherche, filtres, drop-zone).
    bindEditorChrome: function () {
        var self = this;

        var nameInput = document.getElementById('pl-name');
        if (nameInput) nameInput.addEventListener('input', function () { self.editing.name = this.value; });

        var autoplay = document.getElementById('pl-autoplay');
        if (autoplay) autoplay.addEventListener('change', function () { self.editing.autoplay = this.checked; });

        var autoloop = document.getElementById('pl-autoloop');
        if (autoloop) autoloop.addEventListener('change', function () { self.editing.autoLoop = this.checked; });

        var search = document.getElementById('pl-media-search');
        if (search) search.addEventListener('input', function () {
            self.mediaSearch = this.value.toLowerCase();
            self.renderMedia();
        });

        var filters = document.getElementById('pl-media-filters');
        if (filters) filters.addEventListener('click', function (e) {
            var btn = e.target.closest('.filter-btn');
            if (!btn) return;
            self.mediaFilter = btn.dataset.type || 'all';
            filters.querySelectorAll('.filter-btn').forEach(function (b) {
                b.classList.toggle('active', b === btn);
            });
            self.renderMedia();
        });

        // Drop-zone : accepte les médias glissés depuis la bibliothèque.
        var dz = document.getElementById('pl-drop-zone');
        var ws = document.getElementById('pl-items');
        [dz, ws].forEach(function (zone) {
            if (!zone) return;
            zone.addEventListener('dragover', function (e) {
                if (self._dragPath) { e.preventDefault(); if (dz) dz.classList.add('drag-over'); }
            });
            zone.addEventListener('dragleave', function () { if (dz) dz.classList.remove('drag-over'); });
            zone.addEventListener('drop', function (e) {
                e.preventDefault();
                if (dz) dz.classList.remove('drag-over');
                var path = e.dataTransfer.getData('text/plain') || self._dragPath;
                if (path) self.addByPath(path);
            });
        });
    },

    syncEditorForm: function () {
        var nameInput = document.getElementById('pl-name');
        if (nameInput) nameInput.value = this.editing.name || '';
        var autoplay = document.getElementById('pl-autoplay');
        if (autoplay) autoplay.checked = this.editing.autoplay !== false;
        var autoloop = document.getElementById('pl-autoloop');
        if (autoloop) autoloop.checked = this.editing.autoLoop !== false;
    },

    /* -------------------------- Bibliothèque média -------------------------- */
    loadMedia: async function () {
        var container = document.getElementById('pl-media-list');
        try {
            var res = await PiSignage.api.request('/api/media.php');
            this.media = (res && res.success && res.data) ? res.data : [];
        } catch (e) {
            console.error('Erreur chargement médias:', e);
            this.media = [];
            if (container) container.innerHTML = '<div class="empty-state"><p>Erreur de chargement des médias</p></div>';
            return;
        }
        this.renderMedia();
    },

    renderMedia: function () {
        var container = document.getElementById('pl-media-list');
        if (!container) return;
        var self = this;

        var items = this.media.filter(function (m) {
            var matchType = self.mediaFilter === 'all' || self.typeClass(m.type) === self.mediaFilter;
            var matchSearch = !self.mediaSearch || (m.name || '').toLowerCase().indexOf(self.mediaSearch) !== -1;
            return matchType && matchSearch;
        });

        if (!items.length) {
            container.innerHTML = '<div class="empty-state" style="padding:24px 8px"><p>Aucun média</p></div>';
            return;
        }

        container.innerHTML = items.map(function (m) {
            var cls = self.typeClass(m.type);
            return '<div class="media-item" draggable="true" data-path="' + self.esc(m.path) + '">'
                +    '<div class="media-item-icon ' + cls + '">' + self.typeIcon(m.type) + '</div>'
                +    '<div class="media-item-info">'
                +      '<div class="media-item-name" title="' + self.esc(m.name) + '">' + self.esc(m.name) + '</div>'
                +      '<div class="media-item-meta">' + self.esc(m.size_formatted || '') + '</div>'
                +    '</div>'
                +    '<div class="media-item-actions">'
                +      '<button class="icon-btn" type="button" title="Ajouter à la playlist" data-add="' + self.esc(m.path) + '">'
                +        self._svg(self._icons.plus) + '</button>'
                +    '</div>'
                +  '</div>';
        }).join('');

        // Clic "+" pour ajouter.
        container.querySelectorAll('[data-add]').forEach(function (btn) {
            btn.addEventListener('click', function () { self.addByPath(this.getAttribute('data-add')); });
        });
        // Glisser depuis la bibliothèque.
        container.querySelectorAll('.media-item').forEach(function (el) {
            el.addEventListener('dragstart', function (e) {
                self._dragPath = el.getAttribute('data-path');
                e.dataTransfer.setData('text/plain', self._dragPath);
                e.dataTransfer.effectAllowed = 'copy';
                el.classList.add('dragging');
            });
            el.addEventListener('dragend', function () {
                self._dragPath = null;
                el.classList.remove('dragging');
            });
        });
    },

    // Durée par défaut : images 10s, vidéo/audio 0 (= durée native gérée par le player).
    defaultDuration: function (type) {
        return this.typeClass(type) === 'image' ? 10 : 0;
    },

    addByPath: function (path) {
        var m = null;
        for (var i = 0; i < this.media.length; i++) {
            if (this.media[i].path === path) { m = this.media[i]; break; }
        }
        var type = m ? m.type : '';
        var name = m ? m.name : (path.split('/').pop() || path);
        this.editing.items.push({
            url: path,
            type: type,
            name: name,
            duration: this.defaultDuration(type),
            fit: 'contain',
            mute: false,
            loop: false,
            subtitles: true
        });
        this.renderItems();
        PiSignage.ui.toast('« ' + name + ' » ajouté', 'success');
    },

    /* ------------------------- Items de la playlist ------------------------- */
    renderItems: function () {
        var container = document.getElementById('pl-items');
        var dropZone = document.getElementById('pl-drop-zone');
        var countEl = document.getElementById('pl-item-count');
        if (!container) return;
        var self = this;
        var items = this.editing.items;

        if (countEl) countEl.textContent = items.length + (items.length === 1 ? ' élément' : ' éléments');
        if (dropZone) dropZone.classList.toggle('hidden', items.length > 0);

        container.innerHTML = items.map(function (it, i) {
            var cls = self.typeClass(it.type);
            var dur = (cls === 'image' || it.duration > 0) ? (it.duration || 0) + 's' : 'durée native';
            var selected = (self.selectedIndex === i) ? ' selected' : '';
            return '<div class="playlist-item' + selected + '" data-index="' + i + '">'
                +    '<div class="drag-handle" title="Position ' + (i + 1) + '">' + self._svg(self._icons.drag) + '</div>'
                +    '<div class="playlist-item-icon ' + cls + '">' + self.typeIcon(it.type) + '</div>'
                +    '<div class="playlist-item-content">'
                +      '<div class="playlist-item-name" title="' + self.esc(it.name) + '">' + self.esc(it.name) + '</div>'
                +      '<div class="playlist-item-details"><span>' + (i + 1) + '</span><span>' + dur + '</span><span>' + self.esc(it.fit) + '</span></div>'
                +    '</div>'
                +    '<div class="playlist-item-actions">'
                +      '<button class="icon-btn" type="button" title="Monter" data-move="up" data-index="' + i + '"' + (i === 0 ? ' disabled' : '') + '>' + self._svg(self._icons.up) + '</button>'
                +      '<button class="icon-btn" type="button" title="Descendre" data-move="down" data-index="' + i + '"' + (i === items.length - 1 ? ' disabled' : '') + '>' + self._svg(self._icons.down) + '</button>'
                +      '<button class="icon-btn" type="button" title="Retirer" data-remove="' + i + '">' + self._svg(self._icons.trash) + '</button>'
                +    '</div>'
                +  '</div>';
        }).join('');

        // Sélection (clic sur la ligne).
        container.querySelectorAll('.playlist-item').forEach(function (row) {
            row.addEventListener('click', function () {
                self.selectItem(parseInt(this.getAttribute('data-index'), 10));
            });
        });
        // Boutons monter/descendre.
        container.querySelectorAll('[data-move]').forEach(function (btn) {
            btn.addEventListener('click', function (e) {
                e.stopPropagation();
                self.move(parseInt(this.getAttribute('data-index'), 10), this.getAttribute('data-move'));
            });
        });
        // Retirer.
        container.querySelectorAll('[data-remove]').forEach(function (btn) {
            btn.addEventListener('click', function (e) {
                e.stopPropagation();
                self.removeItem(parseInt(this.getAttribute('data-remove'), 10));
            });
        });
    },

    move: function (index, dir) {
        var items = this.editing.items;
        var target = dir === 'up' ? index - 1 : index + 1;
        if (target < 0 || target >= items.length) return;
        var tmp = items[index];
        items[index] = items[target];
        items[target] = tmp;
        if (this.selectedIndex === index) this.selectedIndex = target;
        else if (this.selectedIndex === target) this.selectedIndex = index;
        this.renderItems();
        this.renderItemOptions();
    },

    removeItem: function (index) {
        this.editing.items.splice(index, 1);
        if (this.selectedIndex === index) this.selectedIndex = null;
        else if (this.selectedIndex != null && this.selectedIndex > index) this.selectedIndex--;
        this.renderItems();
        this.renderItemOptions();
    },

    selectItem: function (index) {
        this.selectedIndex = index;
        this.renderItems();
        this.renderItemOptions();
    },

    /* ---------------------- Options de l'élément sélectionné ---------------------- */
    renderItemOptions: function () {
        var box = document.getElementById('pl-item-options');
        if (!box) return;
        var self = this;
        var idx = this.selectedIndex;

        if (idx == null || !this.editing.items[idx]) {
            box.innerHTML = '<div class="empty-state" style="padding:24px 8px">'
                + this._svg(this._icons.playlist)
                + '<p>Sélectionnez un élément de la playlist pour ajuster ses options.</p></div>';
            return;
        }

        var it = this.editing.items[idx];
        var isImage = this.typeClass(it.type) === 'image';
        var isAudio = this.typeClass(it.type) === 'audio';

        var html = '<div class="form-group"><label>Élément</label>'
            + '<div style="font-size:13px;font-weight:600;color:var(--text);word-break:break-word">' + this.esc(it.name) + '</div></div>';

        // Durée : pertinente pour les images (les vidéos/audios utilisent leur durée native si 0).
        html += '<div class="form-group"><label>Durée (secondes)</label>'
            + '<input type="number" id="pl-opt-duration" class="form-control" min="0" max="86400" value="' + (it.duration || 0) + '">'
            + '<p style="font-size:11.5px;color:var(--text-faint);margin-top:6px">'
            + (isImage ? 'Temps d\'affichage de l\'image.' : '0 = durée native du fichier.') + '</p></div>';

        // Ajustement (fit) — utile pour images/vidéos.
        if (!isAudio) {
            html += '<div class="form-group"><label>Ajustement</label>'
                + '<select id="pl-opt-fit" class="form-control">'
                + '<option value="contain"' + (it.fit !== 'cover' ? ' selected' : '') + '>Contenir (entier)</option>'
                + '<option value="cover"' + (it.fit === 'cover' ? ' selected' : '') + '>Remplir (recadré)</option>'
                + '</select></div>';
        }

        // Muet (vidéo/audio).
        if (!isImage) {
            html += '<div class="form-group"><label class="row" style="justify-content:space-between;gap:12px;margin:0;cursor:pointer">'
                + '<span>Couper le son</span>'
                + '<span class="toggle-switch"><input type="checkbox" id="pl-opt-mute"' + (it.mute ? ' checked' : '') + '><span class="toggle-slider"></span></span>'
                + '</label></div>';
        }

        // Boucle de l'élément.
        html += '<div class="form-group"><label class="row" style="justify-content:space-between;gap:12px;margin:0;cursor:pointer">'
            + '<span>Boucler cet élément</span>'
            + '<span class="toggle-switch"><input type="checkbox" id="pl-opt-loop"' + (it.loop ? ' checked' : '') + '><span class="toggle-slider"></span></span>'
            + '</label></div>';

        // Sous-titres (vidéo uniquement) — affichés si un .vtt existe pour ce média, sauf désactivation ici.
        if (!isImage && !isAudio) {
            html += '<div class="form-group"><label class="row" style="justify-content:space-between;gap:12px;margin:0;cursor:pointer">'
                + '<span>Afficher les sous-titres</span>'
                + '<span class="toggle-switch"><input type="checkbox" id="pl-opt-subtitles"' + (it.subtitles !== false ? ' checked' : '') + '><span class="toggle-slider"></span></span>'
                + '</label><p style="font-size:11.5px;color:var(--text-faint);margin-top:6px">Si un fichier de sous-titres (.vtt) existe pour ce média.</p></div>';
        }

        html += '<button class="btn btn-danger btn-block btn-sm" type="button" id="pl-opt-remove">'
            + this._svg(this._icons.trash) + 'Retirer de la playlist</button>';

        box.innerHTML = html;

        var dur = document.getElementById('pl-opt-duration');
        if (dur) dur.addEventListener('input', function () {
            var v = parseFloat(this.value);
            it.duration = (isNaN(v) || v < 0) ? 0 : v;
            self.renderItems();
        });
        var fit = document.getElementById('pl-opt-fit');
        if (fit) fit.addEventListener('change', function () {
            it.fit = (this.value === 'cover') ? 'cover' : 'contain';
            self.renderItems();
        });
        var mute = document.getElementById('pl-opt-mute');
        if (mute) mute.addEventListener('change', function () { it.mute = this.checked; });
        var loop = document.getElementById('pl-opt-loop');
        if (loop) loop.addEventListener('change', function () { it.loop = this.checked; });
        var subs = document.getElementById('pl-opt-subtitles');
        if (subs) subs.addEventListener('change', function () { it.subtitles = this.checked; });
        var rem = document.getElementById('pl-opt-remove');
        if (rem) rem.addEventListener('click', function () { self.removeItem(idx); });
    },

    /* ----------------------------- Enregistrement ----------------------------- */
    // save(andBroadcast): POST /api/playlists.php ; si andBroadcast -> activate ensuite.
    save: async function (andBroadcast) {
        var name = (this.editing.name || '').trim();
        if (!name) {
            PiSignage.ui.toast('Donnez un nom à la playlist', 'warning');
            var nameInput = document.getElementById('pl-name');
            if (nameInput) nameInput.focus();
            return;
        }
        if (!this.editing.items.length) {
            PiSignage.ui.toast('Ajoutez au moins un élément', 'warning');
            return;
        }

        var payload = {
            name: name,
            autoplay: this.editing.autoplay !== false,
            autoLoop: this.editing.autoLoop !== false,
            items: this.editing.items.map(function (it) {
                return {
                    url: it.url,
                    duration: it.duration || 0,
                    fit: (it.fit === 'cover') ? 'cover' : 'contain',
                    mute: !!it.mute,
                    loop: !!it.loop,
                    subtitles: it.subtitles !== false
                };
            })
        };

        try {
            var res = await PiSignage.api.request('/api/playlists.php', {
                method: 'POST',
                body: JSON.stringify(payload)
            });
            if (!res || !res.success) {
                PiSignage.ui.toast('Erreur : ' + ((res && res.message) || 'enregistrement impossible'), 'error');
                return;
            }
            // Slug renvoyé par l'API (dérivé du nom).
            var slug = (res.data && res.data.slug) ? res.data.slug : null;
            this.editing.slug = slug;

            if (andBroadcast && slug) {
                var act = await PiSignage.api.request(
                    '/api/playlists.php?action=activate&name=' + encodeURIComponent(slug),
                    { method: 'POST' }
                );
                if (act && act.success) {
                    PiSignage.ui.toast('Playlist enregistrée et diffusée à l\'écran', 'success');
                } else {
                    PiSignage.ui.toast('Enregistrée, mais diffusion impossible', 'warning');
                }
            } else {
                PiSignage.ui.toast('Playlist enregistrée', 'success');
            }

            await this.load();
            this.showList();
        } catch (e) {
            console.error('Erreur enregistrement playlist:', e);
            PiSignage.ui.toast('Erreur lors de l\'enregistrement', 'error');
        }
    }
};

/* Compat : certains appels historiques utilisent window.loadPlaylists(). */
window.loadPlaylists = function () { return PiSignage.playlists.load(); };

console.log('PiSignage Playlists module loaded (API unifiée)');
