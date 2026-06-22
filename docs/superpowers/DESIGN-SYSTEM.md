# PiSignage Design System — Contrat d'implémentation (v0.12)

> **Pour les agents :** ce document est LA source de vérité pour reconstruire chaque page.
> Pages de référence déjà faites : `web/login.php`, `web/dashboard.php` (+ `web/assets/js/dashboard.js`). **Imite-les.**
> Thème adaptatif clair/sombre (emerald). **Zéro emoji** — uniquement `icon('name')`.

## 1. Squelette de page admin (OBLIGATOIRE)

```php
<?php
require_once 'includes/auth.php';
requireAuth();
$pageTitle = 'Titre de la page';
include 'includes/header.php';          // <head>, anti-flash thème, CSS, <body data-page="...">
include 'includes/navigation.php';      // sidebar (icônes SVG, item actif auto via getCurrentPage())
require_once 'includes/components.php';  // pageHeader(), statusPill()
?>
<div class="main">
    <?php pageHeader('Titre', 'Sous-titre court', $actionsHtml /* optionnel */); ?>
    <div class="content">
      <div class="content-inner">
        <!-- contenu spécifique de la page -->
      </div>
    </div>
</div>
<?php include 'includes/footer.php'; ?>  <!-- toasts + scripts versionnés -->
```

- `$actionsHtml` (3e arg de `pageHeader`) = HTML brut injecté à gauche de l'horloge (boutons d'action, `statusPill()`).
- Ne **jamais** réécrire `header.php`/`navigation.php`/`footer.php` (partagés). Ne pas remettre `.main-content` (legacy).
- Le `data-page` du `<body>` = nom du fichier sans `.php` → c'est ce que `init.js` dispatche.

## 2. Tokens CSS (déjà définis, ne pas redéfinir)

`--bg --surface --surface-2 --surface-3 --surface-hover --border --border-strong`
`--text --text-dim --text-faint --shadow --shadow-lg --overlay`
`--accent --accent-strong --accent-bright --accent-soft --accent-ring --accent-text --accent-contrast`
Sémantiques : `--info(-soft/-text) --warn(-soft/-text) --danger(-soft/-text) --violet(-soft/-text)`
Rayons : `--radius(14) --radius-sm(10) --radius-lg(18) --radius-pill`. Espacements `--sp-1..--sp-10`.
**Toujours** utiliser ces variables (jamais de couleur en dur). Les deux thèmes les surchargent automatiquement.

## 3. Composants & classes (déjà stylés dans components.css / pages.css)

| Besoin | Markup |
|---|---|
| Carte | `<div class="card">` · entête `<div class="card-head"><h2 class="card-title"><?= icon('x') ?>Titre</h2><a class="card-link">…</a></div>` |
| Bouton | `<button class="btn btn-primary">`, `.btn-secondary`, `.btn-danger`, `.btn-ghost`, tailles `.btn-sm`/`.btn-lg`, `.btn-block` |
| Bouton icône | `<button class="icon-btn"><?= icon('refresh') ?></button>` |
| Stat | `<div class="card stat"><div class="stat-top"><div class="stat-ico"><?= icon('x') ?></div></div><div><div class="stat-val">42</div><div class="stat-label">Libellé</div></div></div>` (variantes ico `.blue .violet .amber .danger`) |
| Champ | `<div class="form-group"><label>…</label><input class="form-control"></div>` ; `<div class="form-row">` pour côte à côte |
| Toggle | `<label class="toggle-switch"><input type="checkbox"><span class="toggle-slider"></span></label>` |
| Badge/pill | `<span class="badge badge-success">`, `<span class="status-pill is-playing"><span class="live-dot"></span>…</span>` |
| Onglets | `.tab-nav` + `.tab-btn(.active)` ; contenus `.tab-content(.active)` |
| Modale | `<div class="modal" id="m"><div class="modal-content"><div class="modal-header"><h3>…</h3><button class="btn-close" onclick="PiSignage.ui.closeModal('m')"><?= icon('close') ?></button></div><div class="modal-body">…</div><div class="modal-footer">…</div></div></div>` ; ouvrir `PiSignage.ui.openModal('m')` |
| Jauge | `<div class="donut g-cpu" id="g-cpu"><span>--</span></div>` puis JS `el.style.setProperty('--val', n)` + `span.textContent` |
| Tableau | `<table class="table">` |
| État vide | `<div class="empty-state"><?= icon('x') ?><h3>…</h3><p>…</p></div>` |
| Chargement | `<span class="spinner"></span>` ou `.skeleton` |
| Grilles | `.grid .grid-2/3/4`, `.grid-auto`, `.cols-main` (2 colonnes 1.55:1) |
| Média (grille) | `.media-grid` > `.media-card` > `.media-card-thumb` + `.media-card-body` |

> Les classes legacy (`.media-item .playlist-item .schedule-item .filter-btn .day-btn .upload-zone .drop-zone .queue-item`…) sont **déjà restylées** dans `pages.css`. Le HTML généré par les gros modules JS s'affichera donc correctement sans tout réécrire — concentre-toi sur : markup statique, suppression des emojis, toasts, bugs.

## 4. Icônes — `icon($name, $class='', $attrs='')`

Disponibles : `dashboard media image folder playlist youtube play play-line pause stop prev next kiosk monitor calendar camera settings logs logout login upload download plus refresh trash edit search volume volume-x sun moon menu chevron chevron-down check check-circle close x alert info cpu storage activity clock power eye wifi lock user link list filter`.
Besoin d'une icône absente ? **Ajoute-la** dans `web/includes/icons.php` (tableau `pisignage_icon_paths()`), tracé style ligne `stroke="currentColor"`. **Jamais d'emoji.**

## 5. Conventions JavaScript

- Namespace `window.PiSignage`. APIs via `PiSignage.api.*` (voir `assets/js/api.js` — ne pas changer les URLs/contrats).
- **Notifications** : `PiSignage.ui.toast(msg, 'success'|'error'|'warning'|'info')`. `showAlert()`/`showNotification()` sont des alias rétro-compatibles (déjà branchés sur les toasts) — OK de les laisser, mais préférer `PiSignage.ui.toast`.
- **Modales** : `PiSignage.ui.openModal(elOrId)` / `closeModal(elOrId)` (gère clic-fond + ÉCHAP + cleanup). Pour une modale créée dynamiquement, mettre `data-remove-on-close="1"` pour qu'elle se retire du DOM à la fermeture.
- **Init de page** : exposer `PiSignage.<module>.init()` ; `init.js` l'appelle selon `data-page`. Pages dispatchées : `dashboard, media, playlists, player-control-ui, schedule, settings`. Pour `youtube/screenshot/logs/kiosk`, les handlers globaux (`window.downloadYoutube`, `window.takeScreenshot`, `window.refreshLogs`…) sont définis dans `init.js` ; tu peux les garder ou migrer la logique dans un module + l'appeler depuis `init.js`.
- Thème géré par `theme.js` (ne pas dupliquer). Horloge `#topbar-clock` auto.
- **Plus de `functions.js`** (retiré). L'upload média doit être réimplémenté proprement via `PiSignage.api.media.upload(files, onProgress)` + une modale design-system (plus de modale violette à emojis).
- Cache-busting : les scripts/CSS sont versionnés par `ASSET_VERSION` dans header/footer — ne pas remettre de `?v=` en dur.

## 6. Règles d'or (revue à la fin de chaque page)

1. **Zéro emoji** dans le HTML, le PHP et les chaînes JS (`grep -nP '[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}]'`).
2. Rendu correct en **clair ET sombre** (jamais de couleur en dur, toujours les tokens).
3. **0 erreur console** sur la page.
4. Chaque action UI → API **testée en direct** sur le Pi (`192.168.1.92`, `admin`/`palmer00`).
5. `php -l` propre sur chaque fichier PHP modifié.
6. Ne pas casser `player.php` (public) ni `GET /api/playlist` (sans session).

## 7. APIs disponibles (rappel — voir api.js)

- `system.getStats()` → `/api/stats.php` : `{cpu:{usage,load_1min}, memory:{total,used,percent}, disk:{total,used,percent}, temperature, uptime}`
- `media.list()` → `/api/media.php` : `data` = tableau `{name,path,size,type,...}` ; `media.upload(files,onProgress)` ; `media.delete(name)`
- `playlists.list()` → `/api/playlist-simple.php` ; `playlists.create/update/delete/getInfo` → `/api/playlist.php`
- `player.getStatus()` → `/api/player-control.php?action=status` : `{state,position,duration,volume,current_file,playlist[]}` ; `player.control(action)` (play/pause/stop/next/previous)
- `youtube.download(url,quality)` / `youtube.getStatus()` → `/api/youtube.php`
- `screenshot.capture()` → `/api/screenshot.php?action=capture`
- `system.systemAction(action)` POST `/api/system.php` (reboot/shutdown/clear-cache/restart-player) ; `system.getStats`, `get_volume`, `set_volume`, `toggle_mute` (volume ALSA)
- Kiosk : `/api/kiosk.php` (GET statut ; PUT url ; POST restart). Settings : `/api/settings.php` (GET ; POST action update_audio/update_password/logout). Logs : `/api/logs.php`. Schedule : `/api/schedule.php`, `/api/scheduler.php`.

> **Bug connu à corriger** (agent settings) : `GET /api/system.php?action=status` → **HTTP 500**.
