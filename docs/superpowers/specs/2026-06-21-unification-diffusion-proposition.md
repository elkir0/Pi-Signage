# Proposition — Unification de la gestion des médias / playlists / lecture / programmation

- **Date** : 2026-06-21
- **Statut** : PROPOSITION (analyse + conception). Aucune implémentation tant que non validé.
- **Base** : analyse multi-agents (médias, playlists, moteurs de lecture, programmation, UX), preuves runtime sur le Pi `192.168.1.92`.

## 1. Diagnostic — pourquoi c'est « le bordel »

Le système a **deux de tout**, sans pont entre eux. Vérifié dans le code ET en runtime.

### 1.1 Deux moteurs de lecture déconnectés 🔴 (cause racine)
| Moteur | Ce qu'il est | Contrôlé par | À l'écran ? |
|---|---|---|---|
| **Chromium HTML5** (`player.php` sur `/player`) | Le lecteur réellement affiché en mode kiosk. Lit `media/playlist.json`. | Page **Kiosk** (`kiosk.php`) | **OUI** |
| **VLC** (service `pisignage-vlc`, port 8080) | Démon qui tourne 24/7, état `stopped`, joue des fichiers fantômes inexistants, **invisible** (Chromium est plein écran). | Page **Lecteur** (`player-control-ui.php`) + dashboard | **NON** |

➡️ **Le piège UX central** : la page « **Lecteur** » (play/pause/volume/lire un média) pilote **VLC = un lecteur invisible et arrêté**. Tout ce que l'utilisateur y fait **n'a aucun effet sur l'écran**. Le « Volume VLC » ne change pas le son (c'est Chromium/ALSA). Le statut peut afficher « Arrêté » pendant qu'une vidéo joue. VLC gaspille ~135 Mo RAM pour rien sur un Pi4.

### 1.2 Deux (trois) modèles de playlist incompatibles 🔴
| Monde | Stockage | Schéma d'item | Édité via | Joué ? |
|---|---|---|---|---|
| **Playlist kiosk** | `media/playlist.json` (fichier unique) | `{url:"/media/x.mp4", type, duration, fit, mute, loop}` | Page **Kiosk** | **OUI** |
| **Playlists nommées** | `/opt/pisignage/playlists/*.json` (vide) | `{file, duration, transition, order}` | Page **Playlists** (éditeur drag&drop) | **NON, jamais** |
| **M3U** | `config/playlists/default.m3u` | M3U | personne | mort |

➡️ La page « **Playlists** » (le bel éditeur) écrit dans un monde **que l'écran ne lit jamais**. Pour changer ce qui passe, il faut la page « **Kiosk** ». De plus l'éditeur est **lui-même cassé** : `Modifier` charge la mauvaise playlist (bug de routage `playlist.php`), `Lire` cible VLC via un chemin+clé erronés (`files` vs `items`, mauvais dossier), et les fichiers manquants sont **silencieusement supprimés** de la playlist.

### 1.3 Deux backends de programmation, **aucun ne s'exécute** 🔴
- `schedule.php` (JSON) — utilisé par l'UI **Programmation**, mais **aucun process ne lit** `schedules.json`. Le badge « En cours » est un **mensonge calculé côté navigateur**.
- `scheduler.php` (SQLite) — contient le seul vrai exécuteur, mais cible une **table `schedules` jamais créée** et **aucun cron ne le lance**.

➡️ Le **dayparting ne fonctionne pas du tout** (jouer playlist A le matin, B l'après-midi = inerte). (NB : l'extinction d'écran programmée, elle, marche — pipeline séparé et propre.)

### 1.4 Pas d'identité stable + dérives de config 🟡
- Aucun **ID média stable** : tout repose sur le nom de fichier, en **3 formats** (`nom nu` / `{file}` / `{url}`). Renommer/supprimer casse les références (les garde-fous sont inopérants).
- `PLAYLISTS_PATH` **défini 3 fois** différemment. Tables SQLite `media_history`/`playlists`/`schedules` = **code mort**. Doublons d'uploaders. 
- ⚠️ Sur le Pi actuel, `kiosk_url = https://time.is` (au lieu de `/player`) → **le player n'est même pas affiché** malgré `USE_CHROMIUM_PLAYER=1`.

---

## 2. Modèle mental cible (ce que l'utilisateur devrait vivre)

```
MÉDIAS  ──►  PLAYLISTS (composer + ordonner)  ──►  DIFFUSION  ──►  ÉCRAN
(bibliothèque)   (1 schéma unique, réutilisable)    │   ▲           (1 moteur)
                                                     │   │
                                          PROGRAMMATION (quelle playlist
                                          est ACTIVE selon heure/jour)
```
Une seule réponse claire à : **« qu'est-ce qui passe, maintenant, et pourquoi »**.

## 3. Architecture unifiée proposée

### Principe 1 — UN moteur de lecture
**Chromium HTML5 (`player.php`) devient le moteur unique.** C'est le seul réellement affiché, et il a déjà overlay, préchargement anti-flash, repli hors-ligne. **VLC est retiré** (service arrêté/désactivé) → libère RAM/CPU, supprime le « lecteur fantôme ».
- *Décodage matériel* : Chromium sur Pi décode en HW (V4L2) avec les bons flags ; pas besoin de VLC pour ça.
- *(Alternative si tu veux garder VLC : il devient un backend OPTIONNEL piloté par le même modèle, jamais en parallèle — plus complexe, non recommandé.)*

### Principe 2 — UN modèle de playlist + la notion de « playlist ACTIVE »
- **Schéma unique** = celui du kiosk (`items:[{url, type, duration, fit, mute, loop, transition?, order?}]` + `autoplay`, `autoLoop`, l'overlay par-vidéo déjà en place s'y rattache).
- **Playlists nommées** stockées dans **un seul dossier**, dans ce schéma.
- **Un pointeur « playlist active » explicite** (ex. `config/active.json` → `{playlist:"matin"}`). Le player lit **la playlist active**. Bouton **« Diffuser à l'écran »** sur chaque playlist.
- L'éditeur drag&drop (réparé) écrit dans ce modèle unique → **ce que j'édite = ce qui peut passer à l'écran**.

### Principe 3 — UN scheduler qui s'exécute vraiment
- Réutiliser le **pattern fiable déjà éprouvé** (cron minute + script idempotent, comme l'extinction d'écran) : un exécuteur lit les plannings et **désigne la playlist active** (réécrit le pointeur) selon heure/jour/priorité.
- Supprimer le backend SQLite mort ; garder UN store (JSON) + son exécuteur. L'UI **reflète l'état réel** (quelle playlist active, déclenchée par quel planning) — fin du badge mensonger.

### Principe 4 — UNE API + nettoyage
- **Fusionner** `playlist.php` + `playlist-simple.php` en **une API playlists** cohérente (CRUD + activer). Un seul uploader. 
- **Identité média stable** (id + index `media.json` ou table SQLite réellement alimentée) pour fiabiliser rename/suppression — *phase ultérieure, optionnel*.
- Supprimer : `scheduler.php` SQLite, `default.m3u`, tables fantômes, double `PLAYLISTS_PATH`, 2ᵉ uploader.

### Principe 5 — UI consolidée
Aujourd'hui **5 endroits** semblent contrôler la diffusion (dashboard, Lecteur, Kiosk, Playlists, Programmation) et se contredisent. Cible :
- **Médias** : la bibliothèque (inchangé).
- **Playlists** : composer/ordonner + **« Diffuser »** (devient active) + aperçu. Absorbe l'édition de la playlist kiosk (plus de double éditeur Kiosk/Playlists).
- **Diffusion** (ex-Lecteur, recâblée) : contrôle le **moteur réel** (play/pause/skip/volume **du Chromium affiché**, pas de VLC) + montre la playlist active + aperçu live (capture grim déjà dispo).
- **Programmation** : quand quelle playlist est active (dayparting réel) — distinct et clairement séparé de l'extinction d'écran.
- **Kiosk** : devient purement « réglages d'affichage » (URL/flags/écran/redémarrage), sans éditeur de playlist en double.

---

## 4. Plan d'implémentation par phases (incrémental, sans casser l'écran)

- **Phase 1 — Source de vérité unique + activer** : un modèle/dossier playlist unique + pointeur « active » ; le player lit l'active ; bouton « Diffuser ». Migration des données existantes. *(Le plus structurant.)*
- **Phase 2 — Retirer VLC + recâbler « Lecteur »** : arrêter/désactiver VLC ; la page Lecteur pilote le Chromium réel (refresh/skip via le signal de playlist déjà existant) ; corriger l'audio (ALSA only). 
- **Phase 3 — Scheduler réel** : exécuteur cron-minute qui pose la playlist active selon le planning ; UI reflète l'état réel ; suppression du backend mort.
- **Phase 4 — Fusion API + nettoyage + UI consolidée** : une API playlists, suppression du code mort/vestiges, réorganisation des pages.
- **Phase 5 (option) — Identité média stable** : index média + ids, fiabilise rename/suppression/usage.

Chaque phase est déployable et vérifiable seule (Pi + GitHub), sans interrompre la diffusion.

## 5. Décisions à valider avant le plan détaillé
1. **VLC** : on le **retire** (recommandé) ou on le garde en backend optionnel ?
2. **UI** : on **consolide** les pages (Playlists absorbe l'édition kiosk ; Lecteur recâblé sur le moteur réel ; Kiosk = réglages d'affichage) — OK ?
3. **Ordre** : commencer par la **Phase 1** (source de vérité + « Diffuser ») ?
