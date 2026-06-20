# Refonte complète de l'interface web PiSignage — Design system adaptatif « Emerald »

- **Date** : 2026-06-20
- **Branche** : `feature/modernization-trixie-wayland` (travail dérivé)
- **Statut** : Spécification validée (direction visuelle + IA approuvées par l'utilisateur)
- **Maquette de référence** : `.superpowers/brainstorm/4704-1781992050/content/dashboard-preview.html`

## 1. Objectif

Recoder **intégralement la couche frontend** de l'interface d'administration PiSignage pour obtenir une UI **résolument moderne et professionnelle** :

- Thème **adaptatif clair/sombre** (bascule manuelle + suivi `prefers-color-scheme`), accent **emerald**.
- **Zéro emoji** — uniquement des **icônes SVG** ligne, cohérentes, dans une bibliothèque maison.
- **Toutes les fonctions existantes opérationnelles** : on refait l'apparence ET on répare ce qui est cassé (objectif « redesign + repair »).

Ce n'est pas un simple reskin : on reconstruit le markup, le design system CSS, les composants partagés et on consolide le JavaScript.

## 2. Décisions validées

| Décision | Choix retenu |
|---|---|
| Direction visuelle | **Adaptatif clair + sombre** (toggle + auto OS) |
| Couleur d'accent | **Emerald** (`#10b981` / dark `#34d399`, light `#059669`) |
| Périmètre technique | **Garder le backend PHP + les ~19 APIs JSON** ; reconstruire tout le front |
| Objectif fonctionnel | **Redesign + réparer ce qui est cassé** |
| Navigation | Réorganisée en 3 sections + **ajout de Kiosk** au menu |

## 3. Contraintes

- **Cible matérielle** : Raspberry Pi 4/5, OS Trixie + Wayland (labwc). Performance et légèreté prioritaires.
- **Pas de framework front ni d'étape de build** (pas de Node/Tailwind/Bootstrap). Vanilla JS + CSS, conforme à l'ADN du projet et à `install.sh` (source de vérité).
- **Police Inter embarquée localement** sur le Pi (le kiosk peut être hors-ligne) — pas de CDN Google Fonts en production.
- **Ne pas casser le kiosk en service** : `player.php` (sortie signage publique) et `GET /api/playlist` (sans session) doivent continuer à répondre pendant et après la refonte.
- **Contrats d'API inchangés** sauf bug avéré : le JS consomme déjà ces endpoints, on ne change pas leur forme de réponse sans raison.

## 4. Environnement de vérification

- **Pi de test** : `192.168.1.92` (hostname `pisignage`), SSH `pi` (clé + sudo NOPASSWD).
- **Web admin** : `admin` / `palmer00` (mot de passe personnalisé, sera changé plus tard par l'utilisateur).
- **Outils** : SSH + curl pour les APIs ; **Playwright MCP** pour captures + console JS par page.
- **Déjà constaté** : `GET /api/system.php?action=status` → **HTTP 500** (à corriger). Sous-alimentation matérielle connue (cf. mémoire projet) — n'affecte pas le front.

## 5. Design system

### 5.1 Tokens
- Variables CSS sous `:root` + surcharges `html[data-theme="dark"]` / `html[data-theme="light"]`.
- Familles : `--bg`, `--surface`, `--surface-2`, `--surface-hover`, `--border`, `--border-strong`, `--text`, `--text-dim`, `--text-faint`, `--accent*`, `--shadow`, `--radius*`.
- Échelle d'espacement, de rayons (cartes 14px, éléments 10px), d'ombres unifiée.
- Typo **Inter** (400→800) servie en `@font-face` local + fallback système.

### 5.2 Bibliothèque d'icônes SVG
- ~30 icônes ligne (`stroke="currentColor"`, `stroke-width:2`, viewBox 24) : dashboard, image, playlist, youtube, play, kiosk/screen, calendar, camera, settings, logs, logout, upload, plus, refresh, trash, edit, search, volume, sun, moon, chevrons, check, alert, cpu, etc.
- **Mécanisme** : sprite SVG unique (`<symbol>` + `<use>`) ou partial PHP `icon($name)`. Décision d'implémentation tranchée dans le plan ; objectif = une seule source, réutilisable, mise en cache.

### 5.3 Composants partagés (réutilisés sur toutes les pages)
- **Layout** : sidebar (3 sections + bloc utilisateur), topbar (titre + fil d'ariane, horloge live, pill de statut lecteur, toggle thème), zone de contenu scrollable.
- **Cartes** : `.card`, `.card-head`, `.card-title`, `.card-link`.
- **Boutons** : primaire (emerald), secondaire, danger, icône-seul, tailles.
- **Formulaires** : inputs, selects, toggles, sliders, fieldsets — stylés pour les deux thèmes.
- **Modales** : pattern de gestion d'événements correct (handlers JS attachés après création, clic fond, touche ÉCHAP, nettoyage) — réutilise la leçon documentée (BUG-019).
- **Toasts** : remplace tous les `alert()`/`showAlert()` ad hoc par un système de notifications cohérent (succès/erreur/info), conteneur déjà présent dans `footer.php`.
- **Tableaux**, **badges/pills**, **jauges donut** (CPU/RAM/temp/disque), **onglets**, **état vide**, **skeleton/spinner de chargement**.

### 5.4 Fichiers CSS (cible)
Restructuration de `web/assets/css/` : `variables.css` (tokens 2 thèmes) → `base.css` (reset, typo, Inter) → `layout.css` (sidebar/topbar/grilles) → `components.css` (tous les composants) → `pages.css` (specificités résiduelles) → `responsive.css`. `main.css` orchestre les imports. Suppression du glassmorphism sombre-only actuel.

## 6. Architecture de l'information / navigation

```
PiSignage v0.12
├── PRINCIPAL
│   ├── Tableau de bord   (dashboard.php)
│   ├── Médias            (media.php)
│   ├── Playlists         (playlists.php)
│   └── YouTube           (youtube.php)
├── DIFFUSION
│   ├── Lecteur           (player-control-ui.php)
│   ├── Kiosk             (kiosk.php)        ← ajouté au menu
│   ├── Programmation     (schedule.php)
│   └── Capture           (screenshot.php)
└── SYSTÈME
    ├── Paramètres        (settings.php)
    ├── Logs              (logs.php)
    └── Déconnexion
```
- `login.php` : hors menu, **entièrement refait** au design system (fini le thème violet + emoji).
- `player.php` : sortie signage publique, hors menu — aligné visuellement mais rôle inchangé.

## 7. Périmètre page par page

Chaque page est **(a)** reconstruite avec le design system et **(b)** vérifiée en direct sur le Pi (chaque action testée ; bugs corrigés).

| Page | Fonctions clés à conserver/vérifier |
|---|---|
| `login.php` | Auth ; refonte visuelle complète ; gestion `must_change_password`. |
| `dashboard.php` | Stats (médias, playlists, stockage, sortie), lecture en cours, jauges système, actions rapides. APIs `stats.php`, `media.php`, `player(-control).php`, `system.php`. |
| `media.php` | Liste/grille des médias, upload (≤500 Mo), suppression, aperçu/vignettes, tri. API `media.php`, `upload.php`. |
| `playlists.php` | CRUD playlists, éditeur (modale BUG-019), réordonnancement, assignation, lecture. API `playlist.php` / `playlist-simple.php`. |
| `youtube.php` | Téléchargement yt-dlp, progression, ajout à la médiathèque. API `youtube.php`. |
| `player-control-ui.php` | Transport (play/pause/stop/next/prev), volume double (VLC + ALSA), statut, sélection média/playlist. API `player.php`, `player-control.php`, `system.php`. |
| `kiosk.php` | URL kiosk, flags Chromium, restart, statut, feature flag. API `kiosk.php`. |
| `schedule.php` | Programmation horaire des playlists, CRUD créneaux. API `schedule.php`, `scheduler.php`. |
| `screenshot.php` | Capture écran, auto-capture, galerie. API `screenshot.php`. |
| `settings.php` | Audio (VLC/ALSA), affichage, réseau, mot de passe, actions système (reboot/shutdown/clear-cache). API `settings.php`, `config.php`, `system.php`. **Réparer `system.php?action=status` (500).** |
| `logs.php` | Multi-sources, filtre, niveaux colorés, auto-refresh, rotation. API `logs.php`. |
| `player.php` | Sortie signage publique (rôle inchangé, alignement visuel léger). |

## 8. JavaScript

- Conserver le namespace `window.PiSignage` et l'architecture modulaire (`core`, `api`, `init` + un module par page).
- **Consolider/nettoyer** : supprimer les doublons, corriger les bugs runtime, remplacer `alert()`/`showAlert()` par les toasts, ajouter la logique de **thème** (persisté `localStorage` + classe sur `<html>`, appliqué avant paint pour éviter le flash) et le **toggle sidebar** mobile.
- **Cache-busting** : remplacer les `?v=871` / `?v=v0.11.0` codés en dur par un numéro de version unique injecté côté PHP (constante `ASSET_VERSION`).
- `functions.js` (legacy à la racine) : auditer, fusionner l'utile dans les modules, supprimer le reste.

## 9. Stratégie de vérification (« réparer ce qui est cassé »)

1. **Audit de l'état courant** (avant/pendant la refonte) : pour chaque page, parcourir chaque action UI → API et noter ce qui échoue (console JS, HTTP 4xx/5xx, comportement).
2. **Réparation** : corriger les bugs trouvés (front et, si nécessaire, l'API responsable — ex. le 500 de `system status`).
3. **Vérification finale par page** sur le Pi via Playwright MCP : 0 erreur console, rendu correct clair **et** sombre, chaque action fonctionnelle. Captures à l'appui.

## 10. Déploiement

- Développer en local, déployer sur le Pi (`scp` + `chown www-data`), tester, itérer.
- Respecter `install.sh` comme source de vérité (ne pas réintroduire de régénération de fichiers neutralisée).
- Bump de version (`0.11.0` → `0.12.0`) cohérent (config, header, footer).
- Commits atomiques par lot (design system, puis pages par groupes).

## 11. Hors périmètre (YAGNI)

- Pas de réécriture du backend ni de changement de contrat d'API (sauf bug).
- Pas de nouvelles fonctionnalités majeures (multi-écrans, drag&drop avancé, etc.) — strictement redesign + réparation.
- Pas de framework JS ni d'étape de build.
- Pas de migration de l'auth/sessions (CSRF « phase 2 » reste hors scope).

## 12. Risques & mitigations

| Risque | Mitigation |
|---|---|
| Casser le kiosk en service pendant le déploiement | Tester `player.php` + `GET /api/playlist` après chaque déploiement ; déployer le design system d'abord, pages ensuite. |
| Régression fonctionnelle silencieuse | Vérification Playwright par page (console + actions) avant de considérer une page « faite ». |
| `install.sh` régénère des fichiers | Vérifier qu'aucune régénération n'écrase le nouveau front (cf. mémoire `install-sh-source-of-truth`). |
| Flash de thème au chargement | Appliquer `data-theme` depuis `localStorage` en `<head>` avant le rendu. |
| Sous-alimentation matérielle du Pi | Hors scope front ; déjà documenté, action utilisateur (alim 5V/3A). |

## 13. Découpage d'implémentation prévu (détaillé dans le plan)

- **Phase 0** — Fondations : tokens 2 thèmes, Inter local, icônes SVG, includes partagés (header/navigation/footer + partials composants), logique de thème JS.
- **Phase 1** — `login.php` + `dashboard.php` (valide le système de bout en bout).
- **Phase 2** — `media.php`, `playlists.php`, `youtube.php`.
- **Phase 3** — `player-control-ui.php`, `kiosk.php`, `schedule.php`, `screenshot.php`.
- **Phase 4** — `settings.php` (+ fix 500), `logs.php`, `player.php`.
- **Phase 5** — Passe de vérification/réparation globale sur le Pi + déploiement + bump de version.
