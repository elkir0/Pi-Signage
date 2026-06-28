<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Overlay';
include 'includes/header.php';
include 'includes/navigation.php';
require_once 'includes/components.php';

$actions = '<button class="btn btn-primary" type="button" id="overlay-save-btn" onclick="PiSignage.overlay.save()">'
         . icon('check') . 'Enregistrer</button>';

// Helpers HTML réutilisables pour les sections "opacity" et "cycle" par zone.
// Déclarés ici (avant leur utilisation dans le HTML ci-dessous).

/** Slider de transparence (10..100 %). $zone = clock|banner|qr|cards. */
function overlay_opacity_html($zone, $label, $default_percent) {
    $default_percent = (int)$default_percent;
    return <<<HTML
<div class="form-group">
    <label for="ov-{$zone}-opacity">{$label} : <span id="ov-{$zone}-opacity-val">{$default_percent}</span>%</label>
    <input type="range" class="form-control" id="ov-{$zone}-opacity"
           min="10" max="100" step="1" value="{$default_percent}"
           oninput="document.getElementById('ov-{$zone}-opacity-val').textContent = this.value">
</div>
HTML;
}

/** Bloc cycle on/off par zone (toggle + 2 inputs num). $zone = clock|banner|qr|cards. */
function overlay_cycle_html($zone) {
    return <<<HTML
<div class="form-group">
    <div class="row" style="justify-content:space-between;align-items:center">
        <label for="ov-{$zone}-cycle-enabled" style="margin:0">Cycle on/off (période de grâce)</label>
        <label class="toggle-switch">
            <input type="checkbox" id="ov-{$zone}-cycle-enabled">
            <span class="toggle-slider"></span>
        </label>
    </div>
    <div class="form-row" style="margin-top:8px">
        <div class="form-group" style="max-width:140px;margin:0">
            <label for="ov-{$zone}-cycle-on">Affiché (s)</label>
            <input type="number" class="form-control" id="ov-{$zone}-cycle-on" min="1" max="3600" value="8">
        </div>
        <div class="form-group" style="max-width:140px;margin:0">
            <label for="ov-{$zone}-cycle-off">Masqué (s)</label>
            <input type="number" class="form-control" id="ov-{$zone}-cycle-off" min="0" max="3600" value="20">
        </div>
    </div>
</div>
HTML;
}
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
                <?= overlay_opacity_html('clock', 'Transparence fond', 55) ?>
                <?= overlay_cycle_html('clock') ?>
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

                <!-- Logo : upload direct + preview (PNG/JPG/WebP/SVG, transparence préservée) -->
                <div class="form-group">
                    <label>Logo</label>
                    <div class="form-row" style="align-items:center;gap:12px">
                        <img id="ov-banner-logo-preview" alt=""
                             style="max-height:60px;max-width:120px;border-radius:6px;background:var(--surface-2);padding:4px;display:none">
                        <input type="file" id="ov-banner-logo-file"
                               accept="image/png,image/jpeg,image/webp,image/svg+xml" style="display:none">
                        <button type="button" class="btn btn-secondary btn-sm" id="ov-banner-logo-pick">
                            <?= icon('upload') ?>Choisir un fichier
                        </button>
                        <button type="button" class="btn btn-danger btn-sm" id="ov-banner-logo-clear" style="display:none">
                            <?= icon('trash') ?>Retirer
                        </button>
                        <input type="hidden" id="ov-banner-logo">
                    </div>
                    <p style="color:var(--text-faint);font-size:12px;margin:4px 0 0">
                        PNG/JPG/WebP/SVG · max 2 MB · transparence PNG préservée.
                    </p>
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
                <?= overlay_opacity_html('banner', 'Transparence fond', 92) ?>
                <?= overlay_cycle_html('banner') ?>
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
                <?= overlay_opacity_html('qr', 'Transparence fond', 92) ?>
                <?= overlay_cycle_html('qr') ?>
            </div>

        </div>

        <!-- CARTES ROTATIVES + géométrie + cycle conteneur -->
        <div class="card" style="margin-top:18px">
            <div class="card-head">
                <h2 class="card-title"><?= icon('list') ?>Cartes d'information</h2>
                <button class="btn btn-secondary btn-sm" type="button" onclick="PiSignage.overlay.addCard()">
                    <?= icon('plus') ?>Ajouter une carte
                </button>
            </div>
            <p style="color:var(--text-faint);font-size:13px;margin:0 0 12px">
                Une carte à la fois, en boucle. Restez court (≤ 12 mots) pour une lecture rapide à distance.
            </p>

            <!-- Géométrie + style du conteneur de cartes -->
            <div class="grid grid-2" style="margin-bottom:14px">
                <div>
                    <div class="form-group">
                        <label for="ov-cards-size">Taille</label>
                        <select class="form-control" id="ov-cards-size">
                            <option value="sm">Petit</option>
                            <option value="md">Moyen</option>
                            <option value="lg">Grand</option>
                            <option value="xl">Très grand</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label for="ov-cards-preset">Position (présélection)</label>
                        <select class="form-control" id="ov-cards-preset">
                            <option value="top-left">Haut gauche</option>
                            <option value="top-center">Haut centre</option>
                            <option value="top-right">Haut droite</option>
                            <option value="middle-left">Milieu gauche</option>
                            <option value="middle-center">Milieu centre</option>
                            <option value="middle-right">Milieu droite</option>
                            <option value="bottom-left">Bas gauche</option>
                            <option value="bottom-center" selected>Bas centre</option>
                            <option value="bottom-right">Bas droite</option>
                        </select>
                    </div>
                </div>
                <div>
                    <div class="form-row">
                        <div class="form-group" style="max-width:120px">
                            <label for="ov-cards-x">X (%)</label>
                            <input type="number" class="form-control" id="ov-cards-x" min="0" max="100" step="1" value="50">
                        </div>
                        <div class="form-group" style="max-width:120px">
                            <label for="ov-cards-y">Y (%)</label>
                            <input type="number" class="form-control" id="ov-cards-y" min="0" max="100" step="1" value="84">
                        </div>
                    </div>
                    <div class="form-row">
                        <div class="form-group" style="max-width:120px">
                            <label for="ov-cards-w">Largeur (%)</label>
                            <input type="number" class="form-control" id="ov-cards-w" min="10" max="100" step="1" value="62">
                        </div>
                        <div class="form-group" style="max-width:120px">
                            <label for="ov-cards-h">Hauteur (vh)</label>
                            <input type="number" class="form-control" id="ov-cards-h" min="3" max="50" step="1" value="11">
                        </div>
                    </div>
                    <p style="color:var(--text-faint);font-size:11px;margin:4px 0 0">
                        Présélection = reflet visuel ; X/Y/W/H = ajustements fins (override).
                    </p>
                </div>
            </div>

            <?= overlay_opacity_html('cards', 'Transparence fond cartes', 94) ?>
            <?= overlay_cycle_html('cards') ?>

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

<!-- Template d'une carte (cloné côté JS). Schéma v2 : 1 seul texte (plus de FR/NL). -->
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
        <div class="form-group">
            <label>Texte affiché</label>
            <input type="text" class="form-control ov-card-text" maxlength="200"
                   placeholder="Texte affiché à l'écran (max 200 caractères)">
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

    // Range slider (transparence) : valeur 10..100 (%).
    function setRange(id, percent) {
        var el = $(id);
        if (!el) return;
        var p = Math.round(parseFloat(percent));
        if (!isFinite(p)) p = 90;
        if (p < 10) p = 10;
        if (p > 100) p = 100;
        el.value = p;
        // Mettre à jour le label live "<value>%" à côté du slider.
        var lab = $(id + '-val');
        if (lab) lab.textContent = p;
    }
    // Convertit une opacity (0..1) en pourcentage entier 10..100.
    function percentOf(opacity, def) {
        if (typeof opacity !== 'number' || !isFinite(opacity)) {
            opacity = (typeof def === 'number') ? def : 0.90;
        }
        return Math.round(opacity * 100);
    }
    // Lit un slider opacity (%) et renvoie un float 0..1.
    function opacityOf(id, def) {
        var el = $(id);
        var p = el ? parseFloat(el.value) : NaN;
        if (!isFinite(p)) return (typeof def === 'number') ? def : 0.90;
        if (p < 10) p = 10;
        if (p > 100) p = 100;
        return p / 100;
    }

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
            this.initLogoUpload();
            this.initPresetSync();
        },

        // Logo upload : lie les boutons "Choisir"/"Retirer" + POST ?action=upload-logo.
        initLogoUpload: function () {
            var self = this;
            var fileInput = $('ov-banner-logo-file');
            var pickBtn = $('ov-banner-logo-pick');
            var clearBtn = $('ov-banner-logo-clear');
            if (pickBtn && fileInput) {
                pickBtn.addEventListener('click', function () { fileInput.click(); });
            }
            if (fileInput) {
                fileInput.addEventListener('change', function () {
                    var f = fileInput.files && fileInput.files[0];
                    if (!f) return;
                    self.uploadLogo(f);
                });
            }
            if (clearBtn) {
                clearBtn.addEventListener('click', function () {
                    setVal('ov-banner-logo', '');
                    self.updateLogoPreview(null);
                    if (fileInput) fileInput.value = '';
                });
            }
        },

        // POST le fichier vers /api/overlay.php?action=upload-logo (multipart/form-data).
        // Retourne l'URL publique /data/logos/<sha>.<ext> et met à jour le hidden input + preview.
        uploadLogo: function (file) {
            var self = this;
            toast('Upload du logo…', 'info');
            var fd = new FormData();
            fd.append('logo', file);
            fetch(API + '?action=upload-logo', { method: 'POST', body: fd })
                .then(function (r) { return r.json(); })
                .then(function (res) {
                    if (res && res.success && res.data && res.data.url) {
                        setVal('ov-banner-logo', res.data.url);
                        self.updateLogoPreview(res.data.url);
                        toast('Logo importé', 'success');
                    } else {
                        toast((res && res.message) || 'Échec de l\'upload du logo', 'error');
                    }
                })
                .catch(function () {
                    toast('Erreur réseau pendant l\'upload du logo', 'error');
                });
        },

        // Présélection → ajuste X/Y/W/H aux valeurs canoniques du preset.
        // Le user peut ensuite affiner manuellement (les X/Y/W/H sont en override).
        initPresetSync: function () {
            var presets = {
                'top-left':       { x: 25, y: 18 },
                'top-center':     { x: 50, y: 18 },
                'top-right':      { x: 75, y: 18 },
                'middle-left':    { x: 25, y: 50 },
                'middle-center':  { x: 50, y: 50 },
                'middle-right':   { x: 75, y: 50 },
                'bottom-left':    { x: 25, y: 84 },
                'bottom-center':  { x: 50, y: 84 },
                'bottom-right':   { x: 75, y: 84 }
            };
            var sel = $('ov-cards-preset');
            if (!sel) return;
            sel.addEventListener('change', function () {
                var p = presets[sel.value];
                if (!p) return;
                setVal('ov-cards-x', p.x);
                setVal('ov-cards-y', p.y);
            });
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
        // Fill the shared form from an overlay document (schéma v2).
        populate: function (d) {
            d = d || {};
            setChk('ov-enabled', d.enabled !== false);

            var clock = d.clock || {};
            setChk('ov-clock-enabled', clock.enabled !== false);
            setSize('ov-clock-size', clock.size);
            this.setZone('clock', clock);
            // Compat: clock.opacity peut être absent sur anciens documents.
            setRange('ov-clock-opacity',  percentOf(clock.opacity, 55));

            var b = d.banner || {};
            setChk('ov-banner-enabled', b.enabled !== false);
            setVal('ov-banner-name', b.name);
            setVal('ov-banner-subtitle', b.subtitle);
            setVal('ov-banner-logo', b.logo);  // URL hidden input
            this.updateLogoPreview(b.logo);
            setSize('ov-banner-size', b.size);
            setRange('ov-banner-opacity', percentOf(b.opacity, 92));
            this.setZone('banner', b);

            var qr = d.qr || {};
            setChk('ov-qr-enabled', qr.enabled);
            setVal('ov-qr-label', qr.label);
            setVal('ov-qr-data', qr.data);
            setSize('ov-qr-size', qr.size);
            setRange('ov-qr-opacity', percentOf(qr.opacity, 92));
            this.setZone('qr', qr);

            setSize('ov-cards-size', d.cards_size);
            var g = d.cards_geometry || {};
            setVal('ov-cards-preset', g.preset || 'bottom-center');
            setVal('ov-cards-x', g.x !== undefined ? g.x : 50);
            setVal('ov-cards-y', g.y !== undefined ? g.y : 84);
            setVal('ov-cards-w', g.width  !== undefined ? g.width  : 62);
            setVal('ov-cards-h', g.height !== undefined ? g.height : 11);
            setRange('ov-cards-opacity', percentOf(d.cards_opacity, 94));
            this.setZone('cards', {
                cycle: d.cards_cycle || { enabled: false, on_seconds: 8, off_seconds: 20 }
            });

            var host = $('ov-cards');
            if (host) host.innerHTML = '';
            var cards = Array.isArray(d.cards) ? d.cards : [];
            for (var i = 0; i < cards.length; i++) {
                this.addCard(cards[i]);
            }
            this.refreshCardsEmpty();
        },

        // Remplit les champs cycle d'une zone (4 zones : clock, banner, qr, cards).
        setZone: function (zone, src) {
            src = src || {};
            var c = src.cycle || { enabled: false, on_seconds: 8, off_seconds: 20 };
            setChk('ov-' + zone + '-cycle-enabled', c.enabled === true);
            setVal('ov-' + zone + '-cycle-on',  c.on_seconds  || 8);
            setVal('ov-' + zone + '-cycle-off', c.off_seconds || 20);
        },

        // Lit les champs cycle d'une zone -> {enabled, on_seconds, off_seconds}.
        readZone: function (zone) {
            return {
                enabled:     checked('ov-' + zone + '-cycle-enabled'),
                on_seconds:  parseInt(val('ov-' + zone + '-cycle-on'),  10) || 8,
                off_seconds: parseInt(val('ov-' + zone + '-cycle-off'), 10) || 20
            };
        },

        // Met à jour la preview du logo (img + bouton "Retirer").
        updateLogoPreview: function (url) {
            var img = $('ov-banner-logo-preview');
            var clearBtn = $('ov-banner-logo-clear');
            if (url) {
                if (img) { img.src = url; img.style.display = ''; }
                if (clearBtn) clearBtn.style.display = '';
            } else {
                if (img) { img.removeAttribute('src'); img.style.display = 'none'; }
                if (clearBtn) clearBtn.style.display = 'none';
            }
        },

        // Reset the shared form to schema defaults (used for files without overlay).
        resetForm: function () {
            this.populate({
                version: 2, enabled: true,
                banner: { enabled: true, name: '', subtitle: '', logo: null, size: 'md',
                          opacity: 0.92, cycle: { enabled: false, on_seconds: 8, off_seconds: 20 } },
                clock:  { enabled: true, size: 'md',
                          opacity: 0.55, cycle: { enabled: false, on_seconds: 8, off_seconds: 20 } },
                cards_size: 'md',
                cards_geometry: { preset: 'bottom-center', x: 50, y: 84, width: 62, height: 11 },
                cards_opacity: 0.94,
                cards_cycle: { enabled: false, on_seconds: 8, off_seconds: 20 },
                cards: [],
                qr: { enabled: false, label: '', data: '', size: 'md',
                      opacity: 0.92, cycle: { enabled: false, on_seconds: 8, off_seconds: 20 } }
            });
        },

        // Read the shared form into a complete overlay document (schéma v2).
        readForm: function () {
            return {
                version: 2,
                enabled: checked('ov-enabled'),
                banner: {
                    enabled:  checked('ov-banner-enabled'),
                    name:     val('ov-banner-name').trim(),
                    subtitle: val('ov-banner-subtitle').trim(),
                    logo:     val('ov-banner-logo').trim() || null,
                    size:     getSize('ov-banner-size'),
                    opacity:  opacityOf('ov-banner-opacity', 0.92),
                    cycle:    this.readZone('banner')
                },
                clock: {
                    enabled: checked('ov-clock-enabled'),
                    size:    getSize('ov-clock-size'),
                    opacity: opacityOf('ov-clock-opacity', 0.55),
                    cycle:   this.readZone('clock')
                },
                cards_size: getSize('ov-cards-size'),
                cards_geometry: {
                    preset: val('ov-cards-preset'),
                    x:      parseFloat(val('ov-cards-x')) || 50,
                    y:      parseFloat(val('ov-cards-y')) || 84,
                    width:  parseFloat(val('ov-cards-w')) || 62,
                    height: parseFloat(val('ov-cards-h')) || 11
                },
                cards_opacity: opacityOf('ov-cards-opacity', 0.94),
                cards_cycle:   this.readZone('cards'),
                cards: this.collectCards(),
                qr: {
                    enabled: checked('ov-qr-enabled'),
                    label:   val('ov-qr-label').trim(),
                    data:    val('ov-qr-data').trim(),
                    size:    getSize('ov-qr-size'),
                    opacity: opacityOf('ov-qr-opacity', 0.92),
                    cycle:   this.readZone('qr')
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
                var textEl  = node.querySelector('.ov-card-text');
                if (iconSel && data.icon) iconSel.value = data.icon;
                if (durEl && data.duration) durEl.value = data.duration;
                // v2 : `text` unique. Migration legacy : text_fr prioritaire sinon text_nl.
                var legacy = data.text_fr || data.text_nl || '';
                if (textEl) textEl.value = data.text || legacy;
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
                var text = ((it.querySelector('.ov-card-text') || {}).value || '').trim();
                var dur  = parseInt((it.querySelector('.ov-card-duration') || {}).value, 10);
                if (isNaN(dur)) dur = 8;
                if (dur < 3) dur = 3;
                if (dur > 60) dur = 60;
                if (!text) continue;
                out.push({ icon: icon, text: text, duration: dur });
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
