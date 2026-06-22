<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Overlay';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

$actions = '<button class="btn btn-primary" type="button" id="overlay-save-btn" onclick="PiSignage.overlay.save()">'
         . icon('check') . 'Enregistrer</button>';
?>
<div class="main">
    <?php pageHeader('Overlay', 'Informations affichées sur les vidéos', $actions); ?>

    <div class="content">
      <div class="content-inner">

        <!-- MODE: Global / Par vidéo -->
        <div class="card" style="margin-bottom:18px">
            <div class="tab-nav">
                <button class="tab-btn active" type="button" id="ov-mode-global"
                        onclick="PiSignage.overlay.setMode('global')">
                    <?= icon('monitor') ?>Overlay global
                </button>
                <button class="tab-btn" type="button" id="ov-mode-media"
                        onclick="PiSignage.overlay.setMode('media')">
                    <?= icon('media') ?>Overlay par vidéo
                </button>
            </div>

            <!-- Bandeau d'explication mode global -->
            <p id="ov-mode-hint-global" style="color:var(--text-faint);font-size:13px;margin:12px 0 0">
                L'overlay global s'applique à toutes les vidéos qui n'ont pas d'overlay dédié.
            </p>

            <!-- Sélecteur de fichier (mode par vidéo) -->
            <div id="ov-media-picker" style="display:none;margin-top:12px">
                <div class="form-row" style="align-items:flex-end">
                    <div class="form-group" style="flex:1">
                        <label for="ov-media-file">Vidéo / image concernée</label>
                        <select class="form-control" id="ov-media-file"
                                onchange="PiSignage.overlay.onMediaChange()">
                            <option value="">— Choisir un fichier —</option>
                        </select>
                    </div>
                    <div class="form-group" style="flex:0 0 auto">
                        <button class="btn btn-danger" type="button" id="ov-media-delete-btn"
                                onclick="PiSignage.overlay.deleteForMedia()" disabled>
                            <?= icon('trash') ?>Supprimer (revenir au global)
                        </button>
                    </div>
                </div>
                <p style="color:var(--text-faint);font-size:13px;margin:6px 0 0">
                    L'overlay d'une vidéo <strong>remplace entièrement</strong> l'overlay global pour cette vidéo
                    (aucune fusion). Les vidéos marquées d'un badge ont déjà un overlay dédié.
                </p>
                <div id="ov-media-list" class="row" style="flex-wrap:wrap;gap:8px;margin-top:10px"></div>
            </div>
        </div>

        <div class="grid grid-2">

            <!-- GENERAL -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('settings') ?>Général</h2>
                </div>
                <div class="form-group row" style="justify-content:space-between;align-items:center">
                    <label for="ov-enabled" style="margin:0">Activer l'overlay</label>
                    <label class="toggle-switch">
                        <input type="checkbox" id="ov-enabled">
                        <span class="toggle-slider"></span>
                    </label>
                </div>
                <div class="form-group">
                    <label for="ov-lang">Langue par défaut</label>
                    <select class="form-control" id="ov-lang">
                        <option value="fr">Français</option>
                        <option value="nl">Nederlands</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="ov-cards-size">Taille des cartes</label>
                    <select class="form-control" id="ov-cards-size">
                        <option value="sm">Petit</option>
                        <option value="md">Moyen</option>
                        <option value="lg">Grand</option>
                        <option value="xl">Très grand</option>
                    </select>
                </div>
                <p style="color:var(--text-faint);font-size:13px;margin:6px 0 0">
                    L'overlay s'affiche par-dessus les vidéos sans jamais bloquer le lecteur.
                </p>
            </div>

            <!-- HORLOGE -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('clock') ?>Horloge</h2>
                </div>
                <div class="form-group row" style="justify-content:space-between;align-items:center">
                    <label for="ov-clock-enabled" style="margin:0">Afficher l'horloge (haut-droite)</label>
                    <label class="toggle-switch">
                        <input type="checkbox" id="ov-clock-enabled">
                        <span class="toggle-slider"></span>
                    </label>
                </div>
                <div class="form-group">
                    <label for="ov-clock-size">Taille</label>
                    <select class="form-control" id="ov-clock-size">
                        <option value="sm">Petit</option>
                        <option value="md">Moyen</option>
                        <option value="lg">Grand</option>
                        <option value="xl">Très grand</option>
                    </select>
                </div>
            </div>

            <!-- BANDEAU -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('monitor') ?>Bandeau (bas)</h2>
                </div>
                <div class="form-group row" style="justify-content:space-between;align-items:center">
                    <label for="ov-banner-enabled" style="margin:0">Afficher le bandeau</label>
                    <label class="toggle-switch">
                        <input type="checkbox" id="ov-banner-enabled">
                        <span class="toggle-slider"></span>
                    </label>
                </div>
                <div class="form-group">
                    <label for="ov-banner-name">Nom de l'établissement</label>
                    <input type="text" class="form-control" id="ov-banner-name"
                           maxlength="80" placeholder="Mon établissement">
                </div>
                <div class="form-group">
                    <label for="ov-banner-subtitle">Sous-titre</label>
                    <input type="text" class="form-control" id="ov-banner-subtitle"
                           maxlength="160" placeholder="Spécialité · Lun–Ven 8h–18h">
                </div>
                <div class="form-group">
                    <label for="ov-banner-logo">Logo (URL, optionnel)</label>
                    <input type="text" class="form-control" id="ov-banner-logo"
                           maxlength="512" placeholder="/data/logo.png">
                </div>
                <div class="form-group">
                    <label for="ov-banner-size">Taille</label>
                    <select class="form-control" id="ov-banner-size">
                        <option value="sm">Petit</option>
                        <option value="md">Moyen</option>
                        <option value="lg">Grand</option>
                        <option value="xl">Très grand</option>
                    </select>
                </div>
            </div>

            <!-- QR -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('link') ?>Code QR (bas-droite)</h2>
                </div>
                <div class="form-group row" style="justify-content:space-between;align-items:center">
                    <label for="ov-qr-enabled" style="margin:0">Afficher le QR</label>
                    <label class="toggle-switch">
                        <input type="checkbox" id="ov-qr-enabled">
                        <span class="toggle-slider"></span>
                    </label>
                </div>
                <div class="form-group">
                    <label for="ov-qr-label">Libellé</label>
                    <input type="text" class="form-control" id="ov-qr-label"
                           maxlength="60" placeholder="Prendre RDV">
                </div>
                <div class="form-group">
                    <label for="ov-qr-data">Contenu (URL ou texte)</label>
                    <input type="text" class="form-control" id="ov-qr-data"
                           maxlength="512" placeholder="https://example.com">
                </div>
                <div class="form-group">
                    <label for="ov-qr-size">Taille</label>
                    <select class="form-control" id="ov-qr-size">
                        <option value="sm">Petit</option>
                        <option value="md">Moyen</option>
                        <option value="lg">Grand</option>
                        <option value="xl">Très grand</option>
                    </select>
                </div>
            </div>

        </div>

        <!-- CARTES ROTATIVES -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('list') ?>Cartes d'information (centre-bas)</h2>
                <button class="btn btn-secondary btn-sm" type="button" onclick="PiSignage.overlay.addCard()">
                    <?= icon('plus') ?>Ajouter une carte
                </button>
            </div>
            <p style="color:var(--text-faint);font-size:13px;margin:0 0 12px">
                Une carte à la fois, en boucle. Restez court (≤ 12 mots) pour une lecture rapide à distance.
            </p>
            <div id="ov-cards"></div>
            <div id="ov-cards-empty" class="empty-state" style="display:none">
                <?= icon('list') ?>
                <h3>Aucune carte</h3>
                <p>Ajoutez une carte d'information à afficher en rotation sur les vidéos.</p>
            </div>
        </div>

      </div>
    </div>
</div>

<!-- Template d'une carte (cloné côté JS) -->
<template id="ov-card-template">
    <div class="card ov-card-item" style="margin-bottom:12px;background:var(--surface-2)">
        <div class="form-row">
            <div class="form-group" style="max-width:160px">
                <label>Icône</label>
                <select class="form-control ov-card-icon">
                    <option value="info">Info</option>
                    <option value="alert">Alerte</option>
                    <option value="clock">Horloge</option>
                    <option value="check">Validé</option>
                    <option value="check-circle">Confirmé</option>
                    <option value="calendar">Agenda</option>
                    <option value="wifi">Wi-Fi</option>
                    <option value="volume">Son</option>
                    <option value="user">Personne</option>
                </select>
            </div>
            <div class="form-group" style="max-width:140px">
                <label>Durée (s)</label>
                <input type="number" class="form-control ov-card-duration" min="3" max="60" value="8">
            </div>
        </div>
        <div class="form-row">
            <div class="form-group">
                <label>Texte (FR)</label>
                <input type="text" class="form-control ov-card-fr" maxlength="120"
                       placeholder="Texte affiché en français">
            </div>
            <div class="form-group">
                <label>Texte (NL)</label>
                <input type="text" class="form-control ov-card-nl" maxlength="120"
                       placeholder="Tekst in het Nederlands">
            </div>
        </div>
        <div class="row" style="justify-content:flex-end">
            <button class="btn btn-danger btn-sm" type="button" onclick="PiSignage.overlay.removeCard(this)">
                <?= icon('trash') ?>Supprimer
            </button>
        </div>
    </div>
</template>

<?php include 'includes/footer.php'; ?>

<script>
/*
 * Overlay admin module — self-contained (no separate JS file).
 *
 * Two modes share ONE form (factored build/read):
 *   - "global"  : GET/POST /api/overlay.php
 *   - "media"   : per-video overlay, REPLACE semantics (no merge), stored in
 *                 media-overlays.json keyed by filename.
 *       GET    /api/overlay.php?target=media            -> {filename: overlay}
 *       GET    /api/overlay.php?target=media&file=X      -> overlay or {exists:false}
 *       POST   /api/overlay.php?target=media&file=X      -> save overlay for X
 *       DELETE /api/overlay.php?target=media&file=X      -> remove overlay for X
 *
 * Size factors (sm/md/lg/xl) are applied player-side; here we only persist the
 * chosen size string per element (banner/clock/qr) and a top-level cards_size.
 * Auto-inits when data-page === 'overlay'. Uses PiSignage.ui.toast for feedback.
 */
(function () {
    window.PiSignage = window.PiSignage || {};

    var API = '/api/overlay.php';
    var MEDIA_API = '/api/media.php';
    var SIZES = ['sm', 'md', 'lg', 'xl'];

    function $(id) { return document.getElementById(id); }
    function val(id) { var el = $(id); return el ? el.value : ''; }
    function checked(id) { var el = $(id); return !!(el && el.checked); }
    function setVal(id, v) { var el = $(id); if (el) el.value = (v == null ? '' : v); }
    function setChk(id, v) { var el = $(id); if (el) el.checked = !!v; }

    function normSize(v) {
        v = (typeof v === 'string') ? v.toLowerCase() : '';
        return SIZES.indexOf(v) === -1 ? 'md' : v;
    }
    function setSize(id, v) { setVal(id, normSize(v)); }
    function getSize(id) { return normSize(val(id)); }

    function toast(msg, type) {
        if (window.PiSignage && PiSignage.ui && PiSignage.ui.toast) {
            PiSignage.ui.toast(msg, type || 'info');
        }
    }

    PiSignage.overlay = {
        mode: 'global',          // 'global' | 'media'
        currentFile: '',         // selected media filename (media mode)
        overlayedFiles: [],      // filenames that already have a dedicated overlay

        init: function () {
            this.load();
            this.loadMediaList();
            this.refreshOverlayedFiles();
        },

        /* ================= mode switching ================= */
        setMode: function (mode) {
            mode = (mode === 'media') ? 'media' : 'global';
            this.mode = mode;

            var tGlobal = $('ov-mode-global');
            var tMedia  = $('ov-mode-media');
            if (tGlobal) tGlobal.classList.toggle('active', mode === 'global');
            if (tMedia)  tMedia.classList.toggle('active', mode === 'media');

            var picker = $('ov-media-picker');
            if (picker) picker.style.display = (mode === 'media') ? '' : 'none';
            var hint = $('ov-mode-hint-global');
            if (hint) hint.style.display = (mode === 'global') ? '' : 'none';

            if (mode === 'global') {
                this.currentFile = '';
                this.load();
            } else {
                // Re-evaluate selected file (may be empty).
                this.onMediaChange();
            }
        },

        /* ================= form helpers (shared) ================= */
        // Fill the shared form from an overlay document.
        populate: function (d) {
            d = d || {};
            setChk('ov-enabled', d.enabled !== false);
            setVal('ov-lang', (d.lang === 'nl') ? 'nl' : 'fr');
            setSize('ov-cards-size', d.cards_size);

            var clock = d.clock || {};
            setChk('ov-clock-enabled', clock.enabled);
            setSize('ov-clock-size', clock.size);

            var b = d.banner || {};
            setChk('ov-banner-enabled', b.enabled);
            setVal('ov-banner-name', b.name);
            setVal('ov-banner-subtitle', b.subtitle);
            setVal('ov-banner-logo', b.logo);
            setSize('ov-banner-size', b.size);

            var qr = d.qr || {};
            setChk('ov-qr-enabled', qr.enabled);
            setVal('ov-qr-label', qr.label);
            setVal('ov-qr-data', qr.data);
            setSize('ov-qr-size', qr.size);

            var host = $('ov-cards');
            if (host) host.innerHTML = '';
            var cards = Array.isArray(d.cards) ? d.cards : [];
            for (var i = 0; i < cards.length; i++) {
                this.addCard(cards[i]);
            }
            this.refreshCardsEmpty();
        },

        // Reset the shared form to schema defaults (used for files without overlay).
        resetForm: function () {
            this.populate({
                version: 1, enabled: true, lang: 'fr',
                banner: { enabled: true, name: '', subtitle: '', logo: null, size: 'md' },
                clock:  { enabled: true, size: 'md' },
                cards_size: 'md',
                cards: [],
                qr: { enabled: false, label: '', data: '', size: 'md' }
            });
        },

        // Read the shared form into a complete overlay document.
        readForm: function () {
            return {
                version: 1,
                enabled: checked('ov-enabled'),
                lang: (val('ov-lang') === 'nl') ? 'nl' : 'fr',
                banner: {
                    enabled: checked('ov-banner-enabled'),
                    name: val('ov-banner-name').trim(),
                    subtitle: val('ov-banner-subtitle').trim(),
                    logo: val('ov-banner-logo').trim() || null,
                    size: getSize('ov-banner-size')
                },
                clock: {
                    enabled: checked('ov-clock-enabled'),
                    size: getSize('ov-clock-size')
                },
                cards_size: getSize('ov-cards-size'),
                cards: this.collectCards(),
                qr: {
                    enabled: checked('ov-qr-enabled'),
                    label: val('ov-qr-label').trim(),
                    data: val('ov-qr-data').trim(),
                    size: getSize('ov-qr-size')
                }
            };
        },

        /* ================= cards ================= */
        addCard: function (data) {
            var tpl = $('ov-card-template');
            var host = $('ov-cards');
            if (!tpl || !host) return;
            var node = tpl.content.firstElementChild.cloneNode(true);

            if (data && typeof data === 'object') {
                var iconSel = node.querySelector('.ov-card-icon');
                var durEl   = node.querySelector('.ov-card-duration');
                var frEl    = node.querySelector('.ov-card-fr');
                var nlEl    = node.querySelector('.ov-card-nl');
                if (iconSel && data.icon) iconSel.value = data.icon;
                if (durEl && data.duration) durEl.value = data.duration;
                if (frEl) frEl.value = data.text_fr || '';
                if (nlEl) nlEl.value = data.text_nl || '';
            }
            host.appendChild(node);
            this.refreshCardsEmpty();
        },

        removeCard: function (btn) {
            var item = btn.closest('.ov-card-item');
            if (item) item.remove();
            this.refreshCardsEmpty();
        },

        refreshCardsEmpty: function () {
            var host = $('ov-cards');
            var empty = $('ov-cards-empty');
            if (!host || !empty) return;
            empty.style.display = host.children.length === 0 ? '' : 'none';
        },

        collectCards: function () {
            var out = [];
            var items = document.querySelectorAll('#ov-cards .ov-card-item');
            for (var i = 0; i < items.length; i++) {
                var it = items[i];
                var icon = (it.querySelector('.ov-card-icon') || {}).value || 'info';
                var fr   = ((it.querySelector('.ov-card-fr') || {}).value || '').trim();
                var nl   = ((it.querySelector('.ov-card-nl') || {}).value || '').trim();
                var dur  = parseInt((it.querySelector('.ov-card-duration') || {}).value, 10);
                if (isNaN(dur)) dur = 8;
                if (dur < 3) dur = 3;
                if (dur > 60) dur = 60;
                if (!fr && !nl) continue;
                out.push({ icon: icon, text_fr: fr, text_nl: nl, duration: dur });
            }
            return out;
        },

        /* ================= global load / save ================= */
        load: function () {
            var self = this;
            fetch(API, { headers: { 'Accept': 'application/json' } })
                .then(function (r) { return r.json(); })
                .then(function (res) {
                    if (res && res.success && res.data) {
                        self.populate(res.data);
                    } else {
                        toast((res && res.message) || 'Impossible de charger l\'overlay', 'error');
                    }
                })
                .catch(function (e) {
                    console.error('Overlay load error', e);
                    toast('Erreur de communication avec le serveur', 'error');
                });
        },

        // Entry point for the header "Enregistrer" button — dispatches by mode.
        save: function () {
            if (this.mode === 'media') {
                this.saveForMedia();
            } else {
                this.saveGlobal();
            }
        },

        saveGlobal: function () {
            var btn = $('overlay-save-btn');
            var payload = this.readForm();
            if (btn) btn.disabled = true;
            var self = this;
            fetch(API, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            })
                .then(function (r) { return r.json(); })
                .then(function (res) {
                    if (res && res.success) {
                        toast((res && res.message) || 'Overlay global enregistré', 'success');
                        if (res.data) self.populate(res.data);
                    } else {
                        toast((res && res.message) || 'Erreur lors de l\'enregistrement', 'error');
                    }
                })
                .catch(function (e) {
                    console.error('Overlay save error', e);
                    toast('Erreur de communication avec le serveur', 'error');
                })
                .finally(function () {
                    if (btn) btn.disabled = false;
                });
        },

        /* ================= per-video (media) ================= */
        loadMediaList: function () {
            var self = this;
            fetch(MEDIA_API + '?action=list', { headers: { 'Accept': 'application/json' } })
                .then(function (r) { return r.json(); })
                .then(function (res) {
                    var list = (res && res.success && Array.isArray(res.data)) ? res.data : [];
                    self.populateMediaSelect(list);
                })
                .catch(function (e) {
                    console.error('Media list error', e);
                });
        },

        populateMediaSelect: function (list) {
            var sel = $('ov-media-file');
            if (!sel) return;
            // Keep only relevant types (videos + images).
            var keep = [];
            for (var i = 0; i < list.length; i++) {
                var t = (list[i] && list[i].type) || '';
                if (t === 'video' || t === 'image') keep.push(list[i]);
            }
            keep.sort(function (a, b) {
                return String(a.name).localeCompare(String(b.name));
            });
            var prev = sel.value;
            sel.innerHTML = '<option value="">— Choisir un fichier —</option>';
            for (var j = 0; j < keep.length; j++) {
                var opt = document.createElement('option');
                opt.value = keep[j].name;
                opt.textContent = keep[j].name;
                sel.appendChild(opt);
            }
            if (prev) sel.value = prev;
        },

        // Fetch the set of filenames that already carry a dedicated overlay.
        refreshOverlayedFiles: function () {
            var self = this;
            fetch(API + '?target=media', { headers: { 'Accept': 'application/json' } })
                .then(function (r) { return r.json(); })
                .then(function (res) {
                    var map = (res && res.success && res.data) ? res.data : {};
                    self.overlayedFiles = (map && typeof map === 'object') ? Object.keys(map) : [];
                    self.renderOverlayedBadges();
                })
                .catch(function (e) {
                    console.error('Overlay media map error', e);
                });
        },

        renderOverlayedBadges: function () {
            var host = $('ov-media-list');
            if (!host) return;
            host.innerHTML = '';
            if (!this.overlayedFiles.length) {
                var empty = document.createElement('span');
                empty.style.color = 'var(--text-faint)';
                empty.style.fontSize = '13px';
                empty.textContent = 'Aucune vidéo n\'a encore d\'overlay dédié.';
                host.appendChild(empty);
                return;
            }
            var self = this;
            this.overlayedFiles.slice().sort().forEach(function (name) {
                var badge = document.createElement('button');
                badge.type = 'button';
                badge.className = 'badge badge-success';
                badge.style.cursor = 'pointer';
                badge.style.border = 'none';
                badge.textContent = name;
                badge.title = 'Modifier l\'overlay de ' + name;
                badge.addEventListener('click', function () {
                    var sel = $('ov-media-file');
                    if (sel) { sel.value = name; }
                    self.onMediaChange();
                });
                host.appendChild(badge);
            });
        },

        onMediaChange: function () {
            var file = val('ov-media-file');
            this.currentFile = file;
            var delBtn = $('ov-media-delete-btn');

            if (!file) {
                if (delBtn) delBtn.disabled = true;
                this.resetForm();
                return;
            }

            var self = this;
            fetch(API + '?target=media&file=' + encodeURIComponent(file), {
                headers: { 'Accept': 'application/json' }
            })
                .then(function (r) { return r.json(); })
                .then(function (res) {
                    var data = (res && res.success) ? res.data : null;
                    if (data && data.exists === false) {
                        self.resetForm();
                        if (delBtn) delBtn.disabled = true;
                    } else if (data && typeof data === 'object') {
                        self.populate(data);
                        if (delBtn) delBtn.disabled = false;
                    } else {
                        self.resetForm();
                        if (delBtn) delBtn.disabled = true;
                    }
                })
                .catch(function (e) {
                    console.error('Overlay media load error', e);
                    toast('Erreur de chargement de l\'overlay vidéo', 'error');
                    self.resetForm();
                });
        },

        saveForMedia: function () {
            var file = this.currentFile;
            if (!file) {
                toast('Sélectionnez d\'abord une vidéo', 'warning');
                return;
            }
            var btn = $('overlay-save-btn');
            var payload = this.readForm();
            if (btn) btn.disabled = true;
            var self = this;
            fetch(API + '?target=media&file=' + encodeURIComponent(file), {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            })
                .then(function (r) { return r.json(); })
                .then(function (res) {
                    if (res && res.success) {
                        toast((res && res.message) || 'Overlay enregistré pour cette vidéo', 'success');
                        if (res.data && res.data.exists !== false) self.populate(res.data);
                        var delBtn = $('ov-media-delete-btn');
                        if (delBtn) delBtn.disabled = false;
                        self.refreshOverlayedFiles();
                    } else {
                        toast((res && res.message) || 'Erreur lors de l\'enregistrement', 'error');
                    }
                })
                .catch(function (e) {
                    console.error('Overlay media save error', e);
                    toast('Erreur de communication avec le serveur', 'error');
                })
                .finally(function () {
                    if (btn) btn.disabled = false;
                });
        },

        deleteForMedia: function () {
            var file = this.currentFile;
            if (!file) {
                toast('Sélectionnez d\'abord une vidéo', 'warning');
                return;
            }
            var btn = $('ov-media-delete-btn');
            if (btn) btn.disabled = true;
            var self = this;
            fetch(API + '?target=media&file=' + encodeURIComponent(file), {
                method: 'DELETE',
                headers: { 'Accept': 'application/json' }
            })
                .then(function (r) { return r.json(); })
                .then(function (res) {
                    if (res && res.success) {
                        toast((res && res.message) || 'Overlay supprimé — retour au global', 'success');
                        self.resetForm();
                        self.refreshOverlayedFiles();
                    } else {
                        toast((res && res.message) || 'Erreur lors de la suppression', 'error');
                        if (btn) btn.disabled = false;
                    }
                })
                .catch(function (e) {
                    console.error('Overlay media delete error', e);
                    toast('Erreur de communication avec le serveur', 'error');
                    if (btn) btn.disabled = false;
                });
        }
    };

    document.addEventListener('DOMContentLoaded', function () {
        if (document.body && document.body.getAttribute('data-page') === 'overlay') {
            PiSignage.overlay.init();
        }
    });
})();
</script>
