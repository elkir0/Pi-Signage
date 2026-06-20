# Refonte interface web PiSignage — Plan d'implémentation

> **For agentic workers:** Ce plan est exécuté en mode ultracode (orchestration multi-agents via Workflow). Les étapes utilisent la syntaxe checkbox (`- [ ]`). Domaine **frontend** : la vérification (lint, HTTP, console JS, rendu 2 thèmes, actions live sur le Pi) remplace les tests unitaires.

**Goal :** Reconstruire intégralement la couche frontend de l'admin PiSignage en un design system moderne, adaptatif clair/sombre, accent emerald, 100% icônes SVG, toutes fonctions vérifiées et réparées.

**Architecture :** On garde le backend PHP + les ~19 APIs JSON. On reconstruit : un design system CSS (tokens 2 thèmes), une bibliothèque d'icônes SVG, des includes/partials PHP partagés, le markup des 12 pages, et on consolide les modules JS. La cohérence inter-pages est garantie par un contrat unique `docs/superpowers/DESIGN-SYSTEM.md` produit en Phase 0 et consommé par tous les agents constructeurs de pages.

**Tech Stack :** PHP 8.4 (FPM), Nginx, Vanilla JS (namespace `window.PiSignage`), CSS custom properties, police Inter locale, Playwright MCP pour la vérification. Aucun framework ni build.

**Cible de test :** Pi `192.168.1.92` (`pisignage`), SSH `pi` (clé+sudo), web `admin`/`palmer00`.

---

## Stratégie d'orchestration

1. **Phase 0 + 1 (inline, agent principal)** : design system + contrat `DESIGN-SYSTEM.md` + reconstruction de `login.php` et `dashboard.php` comme implémentations de référence. Déploiement + vérification de bout en bout (2 thèmes, console propre). Prouve le système avant tout fan-out.
2. **Phase 2-4 (Workflow fan-out)** : 1 agent par page restante (10 pages), chacun lit le contrat + les pages de référence + l'état actuel, reconstruit markup + JS, lint local, renvoie un rapport structuré (changements + bugs d'API détectés).
3. **Déploiement global (inline)** : pousser tout le nouveau front sur le Pi.
4. **Phase 5 (Workflow vérification + réparation)** : audit live page par page (Playwright console + rendu 2 thèmes + actions clés) → findings → réparation. Boucle jusqu'à propre. Inclut le fix `system.php?action=status` (500).
5. **Finalisation** : bump version 0.11→0.12, commits atomiques, rapport.

---

## File Structure

**Créés :**
- `docs/superpowers/DESIGN-SYSTEM.md` — contrat de design (tokens, classes, snippets de composants, noms d'icônes, squelette de page).
- `web/includes/icons.php` — fonction `icon($name, $attrs)` + sprite/symbols SVG.
- `web/includes/components.php` — helpers de rendu (cartes, boutons, toasts container, modales, page header).
- `web/assets/css/base.css` — reset, typo, `@font-face` Inter.
- `web/assets/css/pages.css` — spécificités résiduelles par page.
- `web/assets/js/theme.js` — gestion thème (localStorage, anti-flash, toggle).
- `web/assets/js/ui.js` — toasts, modales, helpers UI partagés.
- `web/assets/fonts/inter-*.woff2` — police embarquée.

**Modifiés (réécriture markup/style) :**
- `web/includes/header.php`, `web/includes/navigation.php`, `web/includes/footer.php`
- `web/assets/css/variables.css`, `main.css`, `layout.css`, `components.css`, `responsive.css`, `core.css`
- `web/login.php`, `dashboard.php`, `media.php`, `playlists.php`, `youtube.php`, `player-control-ui.php`, `kiosk.php`, `schedule.php`, `screenshot.php`, `settings.php`, `logs.php`, `player.php`
- `web/assets/js/*.js` (consolidation, toasts, suppression emojis, fix bugs)
- `web/config.php` ou `includes/auth.php` — constante `ASSET_VERSION` pour le cache-busting.

**Backend (réparation ciblée uniquement) :**
- `web/api/system.php` — corriger `action=status` (500).
- Autres APIs : seulement si un bug est avéré pendant la vérification.

---

## Design System — contrat (résumé ; détail complet en `DESIGN-SYSTEM.md`)

**Tokens** (`:root` + `html[data-theme="dark|light"]`) : `--bg --surface --surface-2 --surface-hover --border --border-strong --text --text-dim --text-faint --accent --accent-strong --accent-bright --accent-soft --accent-ring --shadow --radius(14) --radius-sm(10)`.
- Dark : bg `#0a0f1a`, surface `#111827`, text `#e6ebf2`, accent-bright `#34d399`.
- Light : bg `#eef2f7`, surface `#ffffff`, text `#0f1b2d`, accent `#059669`.

**Classes clés** (identiques partout) : `.sidebar .brand .nav-group .nav-label .nav-item(.active)`, `.topbar .status-pill .icon-btn .clock`, `.content .card .card-head .card-title .card-link`, `.btn .btn-primary .btn-secondary .btn-danger .btn-icon`, `.stat .stat-ico .stat-val .stat-label`, `.toast`, `.modal`, `.gauge .donut`, `.empty-state`, `.spinner`.

**Icônes** : `icon('dashboard')`, `'media'`, `'playlist'`, `'youtube'`, `'play'`, `'kiosk'`, `'calendar'`, `'camera'`, `'settings'`, `'logs'`, `'logout'`, `'upload'`, `'plus'`, `'refresh'`, `'trash'`, `'edit'`, `'search'`, `'volume'`, `'sun'`, `'moon'`, `'menu'`, `'chevron'`, `'check'`, `'alert'`, `'cpu'`, `'storage'`, `'monitor'`, `'close'`, `'pause'`, `'prev'`, `'next'`, `'stop'`. (Réutilise les tracés de la maquette `dashboard-preview.html`.)

**Squelette de page** (chaque page admin suit ce gabarit) :
```php
<?php require_once 'includes/auth.php'; requireAuth(); ?>
<?php include 'includes/header.php'; ?>      <!-- <head>, thème anti-flash, CSS -->
<?php include 'includes/navigation.php'; ?>  <!-- sidebar -->
<div class="main">
  <?php pageHeader('Titre', 'Sous-titre'); ?> <!-- topbar : titre, horloge, statut, toggle thème -->
  <div class="content"> … contenu spécifique … </div>
</div>
<?php include 'includes/footer.php'; ?>      <!-- scripts -->
```

---

## Phase 0 — Fondations du design system

### Task 0.1 — Tokens & base CSS
**Files:** Modify `web/assets/css/variables.css`, `main.css`, `core.css`→`base.css` ; Create `base.css`.
- [ ] Écrire `variables.css` avec les tokens 2 thèmes (cf. contrat).
- [ ] Écrire `base.css` : reset, `box-sizing`, `@font-face` Inter (woff2 local), styles typographiques de base, scrollbars.
- [ ] Mettre à jour `main.css` (ordre d'import : variables → base → layout → components → pages → responsive).
- [ ] **Vérif :** `php -S` local, charger `main.css` → 200, aucune erreur de syntaxe CSS (visuellement cohérent).

### Task 0.2 — Police Inter locale
**Files:** Create `web/assets/fonts/inter-{400,500,600,700,800}.woff2`.
- [ ] Récupérer les woff2 Inter et les déposer ; référencer en `@font-face` dans `base.css`.
- [ ] **Vérif :** la police charge sans CDN (DevTools Network, file local).

### Task 0.3 — Bibliothèque d'icônes
**Files:** Create `web/includes/icons.php`.
- [ ] Définir `function icon(string $name, string $class=''): string` retournant le `<svg>` correspondant (tracés repris de la maquette), `stroke="currentColor"`.
- [ ] **Vérif :** `php -r "require 'web/includes/icons.php'; echo icon('dashboard');"` → SVG valide.

### Task 0.4 — Includes partagés (header/navigation/footer) + helpers composants
**Files:** Modify `header.php`, `navigation.php`, `footer.php` ; Create `components.php`.
- [ ] `header.php` : `<head>` complet, **snippet anti-flash** (`<script>` qui applique `data-theme` depuis localStorage avant paint), lien CSS versionné par `ASSET_VERSION`, ouverture `<body>` + bouton menu mobile (icône SVG).
- [ ] `navigation.php` : sidebar 3 sections (Principal/Diffusion/Système) avec `icon()` + état actif via `getCurrentPage()`, bloc utilisateur en bas, **Kiosk ajouté**.
- [ ] `components.php` : `pageHeader($title,$sub)` (topbar : titre, horloge, status-pill lecteur, toggle thème), helpers `card()`, `btn()`.
- [ ] `footer.php` : conteneur toasts, scripts versionnés (theme.js, ui.js, core.js, api.js, init.js + module de page).
- [ ] **Vérif :** rendu d'une page coquille sans erreur PHP (`php -l` sur chaque include).

### Task 0.5 — Layout & composants CSS
**Files:** Modify `layout.css`, `components.css`, `responsive.css` ; Create `pages.css`.
- [ ] `layout.css` : sidebar, topbar, `.main`, `.content`, grilles.
- [ ] `components.css` : cartes, boutons, formulaires/inputs/selects/toggles/sliders, modales, toasts, tableaux, badges, jauges donut, onglets, empty-state, spinner — **stylés pour les 2 thèmes**.
- [ ] `responsive.css` : sidebar repliable < 900px, grilles fluides.
- [ ] **Vérif :** page coquille rendue proprement en clair ET sombre.

### Task 0.6 — JS thème + UI
**Files:** Create `theme.js`, `ui.js` ; Modify `init.js`, `core.js`.
- [ ] `theme.js` : init thème (localStorage `pisignage-theme`, fallback `prefers-color-scheme`), `toggleTheme()`, swap icône sun/moon, horloge live.
- [ ] `ui.js` : `PiSignage.toast(msg,type)`, helpers modale (handlers attachés post-création, clic fond, ÉCHAP, cleanup — pattern BUG-019), `toggleSidebar()`.
- [ ] Brancher dans `init.js` ; retirer les globals legacy obsolètes.
- [ ] **Vérif :** toggle thème OK, toast OK, aucune erreur console (Playwright sur la coquille).

### Task 0.7 — Cache-busting & version
**Files:** Modify `config.php`/`auth.php` (constante), `header.php`, `footer.php`.
- [ ] Définir `ASSET_VERSION` (= version app, ex `0.12.0`) ; remplacer tous les `?v=...` codés en dur.
- [ ] **Vérif :** `grep -rn "?v=871\|?v=v0.11.0" web/` → vide.

### Task 0.8 — Écrire `DESIGN-SYSTEM.md`
**Files:** Create `docs/superpowers/DESIGN-SYSTEM.md`.
- [ ] Documenter : tous les tokens, toutes les classes avec snippet HTML, tous les noms d'icônes, le squelette de page, les conventions JS (toast/modale/API), les règles « à faire / à ne pas faire ». **C'est le contrat des agents de Phase 2-4.**

---

## Phase 1 — Pages de référence (login + dashboard)

### Task 1.1 — `login.php`
**Files:** Modify `web/login.php`.
- [ ] Refondre au design system (carte centrée, logo SVG emerald, champs stylés, message d'erreur, toggle thème). Supprimer le thème violet + emoji 🎬. Conserver la logique POST + `must_change_password`.
- [ ] **Vérif :** déploiement Pi → login `admin/palmer00` fonctionne, rendu 2 thèmes, console propre.

### Task 1.2 — `dashboard.php` + `dashboard.js`
**Files:** Modify `web/dashboard.php`, `web/assets/js/dashboard.js`.
- [ ] Markup = maquette validée (stats, lecture en cours, jauges système, actions rapides), données réelles via `stats.php`/`media.php`/`player*`/`system.php`.
- [ ] `dashboard.js` : chargement données, toasts, suppression emojis ; jauges alimentées par `stats.php`.
- [ ] **Vérif :** déploiement Pi → toutes les valeurs se chargent, jauges OK, actions rapides fonctionnelles, console propre, 2 thèmes.

---

## Phase 2-4 — Pages restantes (fan-out, 1 agent/page)

Chaque agent reçoit : `DESIGN-SYSTEM.md`, `login.php`+`dashboard.php` (référence), la page actuelle + son module JS + l'API associée. **Livrable par agent :** page reconstruite, module JS consolidé (toasts, zéro emoji, bugs corrigés), `php -l` propre, rapport structuré `{page, fichiers, fonctions_vérifiées, bugs_api_détectés}`.

- **Phase 2 :** `media.php` (+media.js, upload), `playlists.php` (+playlists.js, modale éditeur), `youtube.php` (+api.js yt).
- **Phase 3 :** `player-control-ui.php` (+player.js, double volume), `kiosk.php` (+kiosk-control.js), `schedule.php` (+schedule.js), `screenshot.php`.
- **Phase 4 :** `settings.php` (+settings.js, **fix system status 500**), `logs.php`, `player.php` (public, alignement visuel, rôle inchangé).

**Acceptance commune par page :** markup au design system, 0 emoji, 0 erreur console, rendu correct 2 thèmes, chaque action UI → API testée live sur le Pi.

---

## Phase 5 — Vérification & réparation globale

### Task 5.1 — Audit live par page (Workflow)
- [ ] Pour chaque page (12) : Playwright navigate + login, capturer console errors + screenshot **clair et sombre**, exécuter les actions clés, vérifier les réponses API. Produire la liste des findings.

### Task 5.2 — Réparation
- [ ] Corriger chaque finding (front et/ou API responsable). Re-vérifier. **Boucle jusqu'à 0 finding** sur 2 passes consécutives.
- [ ] Confirmer non-régression : `player.php` (public) + `GET /api/playlist` (sans session) toujours 200.

### Task 5.3 — Finalisation
- [ ] Bump version 0.11.0 → 0.12.0 (auth.php config, footer, login footer, ASSET_VERSION).
- [ ] Commits atomiques (fondations, puis pages par lots). Rapport final à l'utilisateur (captures, bugs corrigés).

---

## Self-Review (couverture spec)

- §5 design system → Phase 0 (0.1-0.8). ✓
- §6 IA/nav → Task 0.4. ✓
- §7 pages → Phases 1-4 (12 pages couvertes). ✓
- §8 JS → Tasks 0.6, 0.7 + modules par page. ✓
- §9 vérification/réparation → Phase 5. ✓ (fix 500 = Task 4/settings + 5.2).
- §10 déploiement → étapes inline + Task 5.3. ✓
- §11 hors-scope respecté (pas de réécriture backend/contrats, pas de framework). ✓
- §12 risques (anti-flash thème = 0.4 ; non-régression kiosk = 5.2 ; install.sh = à vérifier au déploiement). ✓

Pas de placeholder bloquant : le détail exhaustif des snippets de composants vit dans `DESIGN-SYSTEM.md` (Task 0.8), produit avant le fan-out qui en dépend.
