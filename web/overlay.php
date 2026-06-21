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
 * Loads the current content via GET /api/overlay.php, lets the operator edit
 * banner / clock / cards / QR, and persists via POST. Auto-inits when
 * data-page === 'overlay'. Uses PiSignage.ui.toast for feedback.
 */
(function () {
    window.PiSignage = window.PiSignage || {};

    var API = '/api/overlay.php';

    function $(id) { return document.getElementById(id); }
    function val(id) { var el = $(id); return el ? el.value : ''; }
    function checked(id) { var el = $(id); return !!(el && el.checked); }
    function setVal(id, v) { var el = $(id); if (el) el.value = (v == null ? '' : v); }
    function setChk(id, v) { var el = $(id); if (el) el.checked = !!v; }

    function toast(msg, type) {
        if (window.PiSignage && PiSignage.ui && PiSignage.ui.toast) {
            PiSignage.ui.toast(msg, type || 'info');
        }
    }

    PiSignage.overlay = {
        init: function () {
            this.load();
        },

        /* ---------- load ---------- */
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

        populate: function (d) {
            d = d || {};
            setChk('ov-enabled', d.enabled);
            setVal('ov-lang', (d.lang === 'nl') ? 'nl' : 'fr');

            var clock = d.clock || {};
            setChk('ov-clock-enabled', clock.enabled);

            var b = d.banner || {};
            setChk('ov-banner-enabled', b.enabled);
            setVal('ov-banner-name', b.name);
            setVal('ov-banner-subtitle', b.subtitle);
            setVal('ov-banner-logo', b.logo);

            var qr = d.qr || {};
            setChk('ov-qr-enabled', qr.enabled);
            setVal('ov-qr-label', qr.label);
            setVal('ov-qr-data', qr.data);

            // Cards
            var host = $('ov-cards');
            if (host) host.innerHTML = '';
            var cards = Array.isArray(d.cards) ? d.cards : [];
            for (var i = 0; i < cards.length; i++) {
                this.addCard(cards[i]);
            }
            this.refreshCardsEmpty();
        },

        /* ---------- cards ---------- */
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

        /* ---------- save ---------- */
        save: function () {
            var btn = $('overlay-save-btn');
            var payload = {
                version: 1,
                enabled: checked('ov-enabled'),
                lang: (val('ov-lang') === 'nl') ? 'nl' : 'fr',
                banner: {
                    enabled: checked('ov-banner-enabled'),
                    name: val('ov-banner-name').trim(),
                    subtitle: val('ov-banner-subtitle').trim(),
                    logo: val('ov-banner-logo').trim() || null
                },
                clock: { enabled: checked('ov-clock-enabled') },
                cards: this.collectCards(),
                qr: {
                    enabled: checked('ov-qr-enabled'),
                    label: val('ov-qr-label').trim(),
                    data: val('ov-qr-data').trim()
                }
            };

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
                        toast((res && res.message) || 'Overlay enregistré', 'success');
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
        }
    };

    document.addEventListener('DOMContentLoaded', function () {
        if (document.body && document.body.getAttribute('data-page') === 'overlay') {
            PiSignage.overlay.init();
        }
    });
})();
</script>
