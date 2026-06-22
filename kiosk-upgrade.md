# Rapport d'amélioration — Mode Kiosk PiSignage

> **Projet :** PiSignage v0.11.0 · **Cible :** Raspberry Pi 4/5, Raspberry Pi OS Trixie (Debian 13) + Wayland
> **Branche :** `feature/modernization-trixie-wayland`
> **Portée :** robustesse du kiosk + **informations complémentaires** (overlay d'ambiance par-dessus les vidéos)
> **Statut :** rapport d'analyse — aucune ligne de code modifiée. Sert de base à un futur plan d'implémentation.

---

## 0. Résumé exécutif

Le mode kiosk de PiSignage est **fonctionnel mais incomplet**. Le socle (Chromium plein écran sous labwc, relance automatique, API de pilotage, lecteur HTML5 avec playlist, sélection des sorties HDMI via kanshi) est solide. Il reste cependant des **angles morts opérationnels** qui peuvent faire échouer un déploiement réel en clientèle :

1. **Fiabilité de boot** — la config `greetd` n'est pas générée par `install.sh` (dépend des défauts système) ; permissions `www-data → home pi` fragiles ; tolérance réseau qui « passe quand même ».
2. **Gestion de l'écran** — aucune extinction programmée ni DPMS : l'écran reste allumé 24/7 (burn-in, surchauffe d'un Pi sous-alimenté, surconsommation).
3. **Informations complémentaires (overlay)** — la fonctionnalité demandée : une couche HTML/CSS sobre par-dessus les vidéos (bandeau cabinet, horloge, cartes conseils, etc.). **Techniquement validée** en mode lecteur Chromium (l'overlay s'injecte dans `player.php`).
4. **Observabilité & pilotage** — `GET system.php?action=status` renvoie **HTTP 500** ; pas de heartbeat central ; pas d'« aperçu de ce qui est à l'écran ».
5. **Performance & résilience** — pas de préchargement vidéo (flash noir entre items), décodage matériel non garanti, pas de cache hors-ligne.

Ce rapport classe ces améliorations par axe, avec **sévérité** (🔴 critique / 🟡 moyen / 🟢 confort) et **effort** (S < ½ j · M ½–2 j · L > 2 j), puis propose une feuille de route en phases.

---

## Table des matières

- [1. État des lieux du mode kiosk](#1-état-des-lieux-du-mode-kiosk)
- [2. Axes d'amélioration](#2-axes-damélioration)
  - [2.1 Fiabilité & robustesse du démarrage](#21-fiabilité--robustesse-du-démarrage)
  - [2.2 Gestion de l'écran & du matériel](#22-gestion-de-lécran--du-matériel)
  - [2.3 Informations complémentaires (overlay)](#23-informations-complémentaires-overlay) ⭐
  - [2.4 Gestion à distance & observabilité](#24-gestion-à-distance--observabilité)
  - [2.5 Lecteur, contenu & programmation](#25-lecteur-contenu--programmation)
  - [2.6 Performance sur Pi4](#26-performance-sur-pi4)
  - [2.7 Sécurité & verrouillage](#27-sécurité--verrouillage)
- [3. Feuille de route priorisée](#3-feuille-de-route-priorisée)
- [4. Quick wins (< 1 jour chacun)](#4-quick-wins--1-jour-chacun)
- [5. Annexes — références fichiers & valeurs](#5-annexes--références-fichiers--valeurs)

---

## 1. État des lieux du mode kiosk

### 1.1 Flux de démarrage actuel

```
Mise sous tension
  └─ systemd
     └─ greetd                    (auto-login user "pi" — config NON générée par install.sh ⚠️)
        └─ labwc                  (compositeur Wayland, lit ~/.config/labwc/rc.xml)
           ├─ kanshi              (sélection sortie : HDMI-A-1 prioritaire, voir 2 micro-HDMI Pi4)
           └─ autostart           (~/.config/labwc/autostart — GÉNÉRÉ par scripts/kiosk-apply)
              └─ boucle: chromium --kiosk "<URL>" <FLAGS> ; sleep 3   (respawn auto)
                 └─ URL =
                      • USE_CHROMIUM_PLAYER=1 → http://127.0.0.1/player  (player.php, lecteur HTML5)
                      • USE_CHROMIUM_PLAYER=0 → config/kiosk_url (défaut https://time.is)
```

### 1.2 Composants réels

| Composant | Chemin | Rôle |
|---|---|---|
| Générateur autostart | `scripts/kiosk-apply` (POSIX sh, ~123 l.) | Construit `~/.config/labwc/autostart` + boucle de relance Chromium |
| Compositeur | `templates/.config/labwc/rc.xml` | Règles fenêtre Chromium (Maximize + Fullscreen), raccourcis secours |
| Sorties d'affichage | `~/.config/kanshi/config` (généré par install.sh) | Profils `both` / `port0` / `port1` pour les 2 micro-HDMI |
| Lecteur HTML5 | `web/player.php` (~569 l.) | `<video>`/`<img>` plein écran, **poll `/api/playlist` toutes les 10 s** |
| API playlist | `web/api/playlist.php` | GET public (200 même vide), PUT/POST authentifiés |
| API kiosk | `web/api/kiosk.php` (~443 l.) | status, health, url, flags, enable, mode, restart |
| UI de gestion | `web/kiosk.php` + `assets/js/kiosk-control.js` | Toggles mode, URL, flags, playlist, actions |
| Flags fonctionnels | `config/feature_flags` | `ENABLE_KIOSK=1`, `USE_CHROMIUM_PLAYER=1` |
| Capture d'écran | `scripts/screenshot-wayland.sh` + `grim-capture.sh` | `grim` (natif Wayland) avec chaîne de repli |

### 1.3 Ce qui fonctionne bien ✅

- Relance automatique de Chromium (boucle `while true … sleep 3`).
- Double mode : **lecteur HTML5 local** vs **URL dashboard distante**.
- API REST complète pour piloter le kiosk à distance.
- `player.php` possède déjà des **calques superposés** (`#loading`, `#error`, `#debug` togglable via Ctrl+D) en `position:absolute` / `z-index:10/100` dans `#player-container` → **l'infrastructure d'overlay existe déjà**.
- Sélection robuste des sorties Pi4 (kanshi, commit `b2c06ec`).
- Capture d'écran 100 % Wayland (`grim`), exploitable pour l'aperçu distant.
- Design system propre et **hors-ligne** : tokens emerald (`--accent:#10b981`), thèmes `data-theme="dark|light"`, police **Inter en WOFF2 local** (`web/assets/fonts/`).

### 1.4 Faiblesses identifiées

| # | Faiblesse | Sévérité | Source |
|---|---|---|---|
| F1 | **Config greetd absente** d'`install.sh` — dépend des défauts système ; si mal configuré, le kiosk ne démarre pas | 🔴 | `scripts/`, `install.sh` |
| F2 | **Permissions `www-data`** : `kiosk-apply` est lancé par PHP-FPM (`www-data`) mais doit écrire dans `~pi/.config/labwc/autostart` | 🔴 | `kiosk.php:260` |
| F3 | **Aucune extinction d'écran / DPMS** : `rc.xml` désactive volontairement l'idle daemon → écran allumé 24/7 | 🔴 | `rc.xml` (commentaire idle) |
| F4 | **`GET system.php?action=status` → HTTP 500** (fonction `formatFileSize()` manquante, gardée en inline) | 🟡 | `system.php` |
| F5 | **Tolérance réseau permissive** : `kiosk-apply` attend 20 s puis continue → page blanche possible si réseau pas prêt | 🟡 | `kiosk-apply` |
| F6 | **Flash noir entre vidéos** : pas de préchargement de l'item suivant | 🟡 | `player.php` |
| F7 | **Curseur visible** si `player.php` ne charge pas (masqué seulement en CSS de la page) | 🟡 | `rc.xml` / `player.php` |
| F8 | **`restart` ne relance que Chromium**, pas la session greetd/labwc ; pas de watchdog d'auto-récupération | 🟡 | `kiosk.php` |
| F9 | **Validation flags partielle** : l'API rejette `[;&\|` mais `kiosk-apply` ne revalide pas | 🟡 | `kiosk.php` / `kiosk-apply` |
| F10 | **`dashboard_default_url`** référencé dans `kiosk-apply` mais jamais créé/documenté | 🟢 | `kiosk-apply` |
| F11 | **Ambiguïté app-id** Chromium (`chromium` vs `chromium-browser`) à confirmer côté Pi | 🟢 | `rc.xml` |

---

## 2. Axes d'amélioration

### 2.1 Fiabilité & robustesse du démarrage

**Objectif : qu'un Pi qui boote affiche TOUJOURS quelque chose de correct, même réseau coupé ou après coupure de courant.**

| Id | Amélioration | Détail | Sév. | Effort |
|---|---|---|---|---|
| R1 | **Générer `/etc/greetd/config.toml`** dans `install.sh` | Auto-login explicite `pi` + `command = labwc`, ne plus dépendre des défauts (corrige F1) | 🔴 | M |
| R2 | **Règle sudo dédiée `www-data → pi`** pour `kiosk-apply` | `sudo -u pi` (comme `grim-capture.sh` le fait déjà) ou écriture de l'autostart par un service root ; corrige F2 | 🔴 | M |
| R3 | **Watchdog kiosk** (systemd timer ou service) | Vérifie périodiquement que Chromium tourne et que la page répond (`curl 127.0.0.1/player`), sinon `kiosk-apply` + relance ; auto-récupération sans intervention | 🟡 | M |
| R4 | **Page d'attente / splash de marque** | Au lieu de page blanche ou `time.is` pendant l'attente réseau : page locale `boot.html` (logo cabinet + « démarrage… ») chargée d'emblée, bascule vers le contenu quand prêt (corrige F5) | 🟡 | S |
| R5 | **Repli hors-ligne du lecteur** | Si `/api/playlist` injoignable, rejouer le dernier contenu connu en cache plutôt qu'écran vide | 🟡 | M |
| R6 | **Validation `feature_flags` + `flags`** au boot | `kiosk-apply` vérifie la syntaxe avant d'appliquer ; revalide les flags Chromium (corrige F9) ; mode dégradé si fichier corrompu | 🟡 | S |
| R7 | **Bouton « Redémarrer la session »** dans l'UI | Action API qui fait `systemctl restart greetd` (pas seulement `pkill chromium`) ; corrige F8 | 🟢 | S |

### 2.2 Gestion de l'écran & du matériel

**Objectif : préserver la dalle, réduire la conso et la chauffe, et exploiter le matériel.**

| Id | Amélioration | Détail | Sév. | Effort |
|---|---|---|---|---|
| D1 | **Extinction programmée de l'écran** | Allumer/éteindre la sortie selon des horaires (`wlr-randr --output … --off/--on`, ou DPMS). Pilotée par un planning configurable dans l'UI. Corrige F3 — **prioritaire** (burn-in + surchauffe Pi sous-alimenté) | 🔴 | M |
| D2 | **Pilotage TV par HDMI-CEC** | `cec-utils` : éteindre/allumer le téléviseur lui-même (pas que la sortie vidéo) aux horaires du cabinet → vraie économie d'énergie | 🟢 | M |
| D3 | **Rotation & résolution depuis l'UI** | Exposer `wlr-randr` (transform 90/180/270, mode, scale) dans `kiosk.php` pour écrans portrait — fréquent en signage vertical | 🟡 | M |
| D4 | **Anti burn-in** | Si écran maintenu la nuit : pixel-shift des éléments fixes (overlay/horloge), variation d'opacité, masquage cyclique du logo. Le « permanent » est l'ennemi de la dalle | 🟡 | S |
| D5 | **Masquage curseur au niveau compositeur** | `seat`/`hideCursor` côté labwc plutôt que CSS uniquement → curseur jamais visible même hors `player.php` (corrige F7) | 🟢 | S |
| D6 | **Gestion multi-écran** | Aujourd'hui kanshi force HDMI-A-1. Prévoir un mode « clone » ou « contenu différent par sortie » pour installations multi-écrans | 🟢 | L |

### 2.3 Informations complémentaires (overlay) ⭐

> **C'est la fonctionnalité au cœur de la demande.** Une couche HTML/CSS sobre superposée aux vidéos affichant des infos d'ambiance et de valorisation. Analyse détaillée (cas : cabinet ostéo/chiro) menée séparément ; voici l'intégration technique dans PiSignage.

#### 2.3.1 Faisabilité — confirmée ✅

En mode `USE_CHROMIUM_PLAYER=1`, Chromium charge **`http://127.0.0.1/player`** → `web/player.php`. L'overlay s'injecte donc **directement dans `player.php`**, au-dessus de la vidéo, exactement comme les calques `#loading`/`#error`/`#debug` déjà présents.

> ⚠️ **Limite à acter :** en **mode dashboard** (`USE_CHROMIUM_PLAYER=0`, URL distante), on ne peut pas injecter dans une page tierce. L'overlay ne sera disponible qu'en **mode lecteur Chromium** (ou via une future page « wrapper » locale qui embarque l'URL distante dans une iframe + overlay).

#### 2.3.2 Architecture recommandée (imposée par le Pi4)

L'overlay JS **ne fait aucun appel API externe**. Tout passe par des fichiers locaux servis par nginx :

```
[cron PHP] fetch éventuel ──► écrit web/data/*.json ──► nginx sert /data/*.json
                                                          ▼
   overlay JS dans player.php lit UNIQUEMENT les fichiers locaux (relit toutes les 5–10 min)
```

- **Réutiliser le poll existant** de `player.php` (`/api/playlist` toutes les 10 s) pour transporter une clé `overlay`, plutôt qu'un nouveau timer réseau.
- **Réutiliser le design system** : `variables.css` (tokens emerald), `data-theme="dark"`, Inter local. Cohérence garantie avec la refonte UI en cours.
- **Contenu éditorial** dans `web/data/overlay-content.json`, éditable via une future page admin `web/overlay.php` (même pattern CRUD que `playlists.php`).
- **Jamais d'iframe/widget tiers** (trackers, pubs) → tout flux externe en `fetch` côté serveur PHP.

#### 2.3.3 Zones d'overlay (proposition)

```
+-----------------------------------------------------------------------+
|  [safe-area ~4%]                                  +-----------------+  |
|                                                   |     14:32       |  |  A. Horloge + date
|              VIDEO PLEIN ECRAN                     |  Sam. 21 juin   |  |     (100% local)
|     +-----------------------------------------+   +-----------------+  |
|     |  CARTE ROTATIVE (fond opaque >=92%)     |                       |  C. Carte vedette
|     |  [picto]  conseil / valorisation        |                       |     (1 info, <=12 mots,
|     +-----------------------------------------+                       |     crossfade lent)
|═══════════════════════════════════════════════════════════════════════|  filet emerald
| [LOGO]  Cabinet — Ostéo & Chiro · Lun–Ven 8h–19h            [QR RDV]   |  D. Bandeau bas
+-----------------------------------------------------------------------+
```

| Id | Brique overlay | Source | Sév. | Effort |
|---|---|---|---|---|
| O1 | **Conteneur `#overlay-root`** (`fixed; inset:0; pointer-events:none`) dans `player.php` | — | 🟢 | S |
| O2 | **Bandeau bas** (logo, nom, spécialités, horaires) + filet emerald | `overlay-content.json` (local) | 🟢 | S |
| O3 | **Horloge + date** (coin haut-droit, `tabular-nums`, maj 30 s) | 100 % local (Date JS) | 🟢 | S |
| O4 | **Carrousel de cartes** (conseils, valorisation) state-machine + crossfade | `overlay-content.json` | 🟡 | M |
| O5 | **Rotation bilingue** (clé `lang`, FR/NL) | `overlay-content.json` | 🟢 | S |
| O6 | **QR code** (RDV / avis) généré **localement** (`endroid/qr-code` ou PNG pré-généré, jamais en ligne) | local | 🟢 | S |
| O7 | **Page admin `web/overlay.php`** : CRUD JSON + **validateur de schéma** + upload photo redimensionné (WebP ≤ 200 Ko) + message épinglé / congés | — | 🟡 | M |
| O8 | **Météo** (Open-Meteo, sans clé, `fetch` serveur, cron 30–60 min, repli hors-ligne) — **optionnel, faible priorité** | `web/data/weather.json` | 🟢 | M |

#### 2.3.4 Garde-fous (overlay)

- **Performance Pi4** : n'animer que `opacity`/`transform` ; `blur`/`backdrop-filter` **interdits par défaut** (fond uni semi-opaque) ; DOM minuscule ; pas de `setInterval` rapide.
- **`pointer-events:none`** sur tout l'overlay → ne capte aucun clic (ne casse pas l'autoplay/wakelock ; le QR se scanne, ne se clique pas).
- **Lisibilité 2–4 m** : 1 info à la fois, ≤ 12 mots, contraste fort, taille mini ≈ 2 % de la hauteur d'écran, fond de carte **opaque ≥ 92 %** (la semi-transparence ne tient pas le contraste sur vidéo claire).
- **Mode dégradé** : si `overlay-content.json` absent/corrompu → carrousel masqué, bandeau + horloge maintenus. L'overlay ne casse jamais le lecteur.
- **Sobriété médicale** : transitions en fondu, jamais de clignotement ; pas de contenu anxiogène (actu/faits divers).
- **RGPD / déontologie** : zéro donnée patient ; aucun tracker tiers ; contenu santé sans diagnostic ni promesse de guérison (pack de cartes pré-rédigées + avertissement dans l'admin).

### 2.4 Gestion à distance & observabilité

**Objectif : savoir, sans se déplacer, que l'écran tourne et afficher le bon contenu.**

| Id | Amélioration | Détail | Sév. | Effort |
|---|---|---|---|---|
| M1 | **Corriger `system.php?action=status`** | Rétablir un endpoint status propre (corrige F4) — pré-requis de toute supervision | 🟡 | S |
| M2 | **Heartbeat / « dernière mise à jour »** | Indicateur visible (admin) de dernière activité du Pi + alerte si silence → le proprio sait que l'écran fonctionne | 🟡 | M |
| M3 | **Aperçu « ce qui est à l'écran »** | Exploiter `grim-capture.sh` existant : vignette de l'écran réel dans `kiosk.php` (rafraîchie à la demande) | 🟢 | S |
| M4 | **Health enrichi** | `kiosk.php/health` : ajouter température, RAM, réseau, dernier item joué, état overlay | 🟢 | S |
| M5 | **Parc multi-Pi (futur)** | Tableau de bord central listant plusieurs écrans (héritage `192.168.1.x`) — vision long terme | 🟢 | L |

### 2.5 Lecteur, contenu & programmation

| Id | Amélioration | Détail | Sév. | Effort |
|---|---|---|---|---|
| C1 | **Préchargement de l'item suivant** | Double `<video>` + bascule à la fin → supprime le flash noir (corrige F6) | 🟡 | M |
| C2 | **Transitions douces** | Crossfade entre items (opacity), Ken Burns léger sur images | 🟢 | M |
| C3 | **Dayparting / programmation horaire** | `schedule.php` existe : jouer playlist A le matin, B l'après-midi, contenus selon jour/heure | 🟡 | M |
| C4 | **Cache média hors-ligne** | Pré-télécharger les médias distants en local pour résister aux coupures | 🟡 | M |
| C5 | **Zones / templates de mise en page** | Modèles « vidéo plein écran », « vidéo + bandeau », « grille d'images » sélectionnables | 🟢 | L |

### 2.6 Performance sur Pi4

| Id | Amélioration | Détail | Sév. | Effort |
|---|---|---|---|---|
| P1 | **Décodage matériel vidéo** | Vérifier/forcer V4L2 + flags Chromium (`--enable-features=VaapiVideoDecoder`, `--use-gl=egl`) ; éviter le décodage logiciel qui sature le CPU | 🟡 | M |
| P2 | **Budget mémoire** | Limiter le cache Chromium, surveiller la RAM (Pi 2 Go) ; éviter playlists d'images non redimensionnées | 🟡 | S |
| P3 | **Alimentation/throttling** | Détecter le sous-voltage (`vcgencmd get_throttled`) et alerter — note mémoire projet : Pi4 sous-alimenté à corriger | 🟡 | S |
| P4 | **Overlay GPU-friendly** | (voir 2.3.4) — `opacity`/`transform` only, pas de `blur` | 🟢 | S |

### 2.7 Sécurité & verrouillage

| Id | Amélioration | Détail | Sév. | Effort |
|---|---|---|---|---|
| S1 | **Durcissement validation flags** | Revalider côté `kiosk-apply` (pas seulement API) ; liste blanche de flags autorisés (corrige F9) | 🟡 | S |
| S2 | **Verrouillage Chromium kiosk** | Désactiver devtools, navigation, téléchargements, menus contextuels via flags/policy | 🟢 | M |
| S3 | **Authentification de l'admin** | Confirmer que `kiosk.php`/`overlay.php` exigent `includes/auth.php` ; `player.php` reste public (nécessaire au kiosk local) | 🟡 | S |
| S4 | **Surface réseau** | `/api/playlist` GET est public par design (garde-fou kiosk) ; vérifier que les écritures (PUT/POST) sont bien protégées | 🟡 | S |

---

## 3. Feuille de route priorisée

Découpage en phases livrables incrémentalement. Chaque phase apporte une valeur visible.

### Phase 0 — Fondations fiabilité (🔴 d'abord)
- R1 (greetd config) · R2 (permissions www-data) · D1 (extinction programmée) · M1 (fix status 500).
- **Pourquoi en premier :** ce sont les éléments qui font *échouer un déploiement réel* ou *abîment le matériel*. Rien ne sert d'enrichir le contenu si le Pi ne boote pas de façon fiable ou si la dalle marque.

### Phase 1 — Overlay MVP (la fonctionnalité demandée)
- O1 (`#overlay-root`) · O2 (bandeau bas) · O3 (horloge). Tout en local, ~½ journée, **visible immédiatement**.
- D4 (anti burn-in) acté dès la conception de l'overlay.

### Phase 2 — Overlay valeur + résilience
- O4 (carrousel) · O5 (bilingue) · O6 (QR) · R4 (splash) · R5 (repli hors-ligne) · C1 (préchargement, fin du flash noir).

### Phase 3 — Autonomie & supervision
- O7 (admin `overlay.php` + validateur) · M2 (heartbeat) · M3 (aperçu écran) · R3 (watchdog) · C3 (dayparting).

### Phase 4 — Raffinements
- O8 (météo) · D2 (CEC) · D3 (rotation UI) · C2 (transitions) · P1 (décodage matériel) · S2 (verrouillage) · M5 (parc multi-Pi).

---

## 4. Quick wins (< 1 jour chacun)

À piocher pour un impact rapide sans gros chantier :

1. **M1** — corriger `system.php?action=status` (débloque la supervision). 🟡 S
2. **O1 + O2 + O3** — overlay bandeau + horloge dans `player.php` : du concret à l'écran tout de suite. 🟢 S
3. **R4** — page splash de marque au lieu de la page blanche/`time.is`. 🟡 S
4. **D5** — masquer le curseur au niveau labwc. 🟢 S
5. **P3** — alerte sous-voltage (`vcgencmd get_throttled`). 🟡 S
6. **R7** — bouton « redémarrer la session » dans l'UI. 🟢 S

---

## 5. Annexes — références fichiers & valeurs

### 5.1 Fichiers clés (chemins réels)

| Rôle | Chemin repo | Chemin déployé (Pi) |
|---|---|---|
| Générateur autostart | `scripts/kiosk-apply` | `/opt/pisignage/scripts/kiosk-apply` |
| Compositeur | `templates/.config/labwc/rc.xml` | `~/.config/labwc/rc.xml` |
| Autostart (généré) | — | `~/.config/labwc/autostart` |
| Sorties HDMI | (généré par `install.sh`) | `~/.config/kanshi/config` |
| Flags fonctionnels | `templates/feature_flags` | `/opt/pisignage/config/feature_flags` |
| URL dashboard | — | `/opt/pisignage/config/kiosk_url` (défaut `https://time.is`) |
| Flags Chromium | — | `/opt/pisignage/config/kiosk_flags` |
| Lecteur HTML5 | `web/player.php` | `/opt/pisignage/web/player.php` |
| API kiosk | `web/api/kiosk.php` | `/opt/pisignage/web/api/kiosk.php` |
| API playlist | `web/api/playlist.php` | `/opt/pisignage/web/api/playlist.php` |
| UI kiosk | `web/kiosk.php` | `/opt/pisignage/web/kiosk.php` |
| Capture écran | `scripts/screenshot-wayland.sh`, `scripts/grim-capture.sh` | idem `/opt/pisignage/scripts/` |
| (à créer) overlay | `web/overlay.php`, `web/data/overlay-content.json` | `/opt/pisignage/web/…` |

### 5.2 Valeurs de référence (vérifiées dans le code)

- **Lancement Chromium :** `/usr/bin/chromium --kiosk "<URL>" <FLAGS>` puis `sleep 3` (boucle de relance).
- **URL mode lecteur :** `http://127.0.0.1/player` (→ `player.php`) quand `USE_CHROMIUM_PLAYER=1`.
- **Poll playlist :** **10 000 ms** (`player.php`, détection via `version`).
- **Format playlist :** `{ version, items:[{url, type?, mute?, loop?, fit?, duration?}], autoLoop, autoplay }`.
- **API kiosk :** `GET /` (status), `/status`, `/health`, `GET|PUT /url`, `GET|PUT /flags`, `PUT /enable`, `PUT /mode`, `POST /restart`.
- **Calques existants `player.php` :** `#loading`, `#error`, `#debug` (Ctrl+D), `z-index:10/100` dans `#player-container`.
- **Tokens design :** `--accent:#10b981` · `--accent-strong:#059669` · `--accent-bright:#34d399` · thème sombre `--bg:#0a0f1a` · `--surface:#111827`.
- **Thème :** `html[data-theme="dark|light"]` (anti-flash inline dans `header.php`, persistance `localStorage`).
- **Police :** Inter WOFF2 local (`web/assets/fonts/inter-400…800.woff2`), `font-display:swap`.
- **Kanshi (Pi4 2× micro-HDMI) :** profils `both` (HDMI-A-1 actif, A-2 off), `port0`, `port1`.

### 5.3 Confirmé / à vérifier sur le Pi

- ✅ **Confirmé :** en mode lecteur, Chromium charge `player.php` → l'overlay y est injectable.
- ⚠️ **À vérifier sur le Pi** avant Phase 0 :
  - `cat /opt/pisignage/config/feature_flags` (mode réellement actif).
  - `cat /opt/pisignage/config/kiosk_url`.
  - Présence/contenu de `/etc/greetd/config.toml` (F1).
  - Droits d'écriture `www-data` sur `~pi/.config/labwc/autostart` (F2).
  - Quel app-id Chromium est réellement utilisé (`chromium` vs `chromium-browser`, F11) via les logs labwc.

---

*Rapport généré le 2026-06-21 — base d'analyse pour un plan d'implémentation ultérieur. Aucune modification de code n'a été effectuée.*
