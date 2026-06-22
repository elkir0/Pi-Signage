# Phase 0 — Durcissement sécurité (v0.12)

Préalable au plan de contrôle distant (relais Zaforge). Conçu + revu de façon adversariale
(13 agents), appliqué et **vérifié sur le Pi de test 192.168.1.92 (24/24)**.

## Changements

| Domaine | Avant | Après |
|---|---|---|
| **Escalade root** | `www-data ALL=(ALL) NOPASSWD: raspi-config` (outil ncurses → root) | raspi-config retiré ; audio via wrapper à args fixes `audio-output.sh hdmi\|jack` (root:root 0755) ; `(ALL)`→`(root)` ; wlr-randr retiré ; sudoers **0440** validé `visudo` |
| **Auth agent** | tout endpoint exige une session PHP | pont loopback `X-Agent-Token` dans `_guard.php` (REMOTE_ADDR loopback **+** `hash_equals`, no-oracle, jamais XFF) → l'agent pilote l'API locale sans session |
| **CSRF** | scaffold désactivé | activé : mint par session (`auth.php`), meta (`header.php`), intercepteur fetch same-origin + header XHR upload (`core.js`/`api.js`), `hash_equals` sur POST/PUT/DELETE/PATCH (`_guard.php`) ; chemin agent + player publics exemptés |
| **Mot de passe** | défaut `signage2025`, pas de contrôle de longueur | forçage du changement (must_change, méthodes mutables ; logout/update_password autorisés), `>=8` + denylist, écriture atomique, `regenerate_id`, fix oracle de timing au login |
| **Session** | cookie `secure=false` figé | `Secure` dérivé du **vrai** HTTPS (jamais `X-Forwarded-Proto`, anti self-DoS), `use_strict_mode`, durée de vie idle 8h / absolue 7j |
| **Injection exec** | `tail -n $lines` (injection), timezone interpolée | `executeCommand` accepte un **argv** (no-shell via `proc_open`) ; tail/amixer/systemctl en argv ; allow-lists rotation `{0,90,180,270}` / hostname RFC1123 / timezone (`timezone_identifiers_list`) |
| **GET à effet de bord** | `screenshot.php?action=capture` déclenchait grim en GET (CSRF cross-site `<img>`) | capture **POST-only** (405 en GET) |
| **Version** | 4 littéraux divergents (v0.11.0 / 0.12.0 / 0.12.8) | source unique `web/version.php` (`PISIGNAGE_VERSION`) ; `player-control.php` (vestige VLC) supprimé |

## Ordre vertical de `_guard.php` (porteur)
exemptions publiques (CLI, playlist GET, display command/state) → **agent loopback** (return) →
gate session → **must_change** (méthodes mutables) → **CSRF**. Tout autre ordre ouvre un contournement.

## Vérification
```bash
PI_HOST=localhost bash scripts/tests/security-phase0.sh        # sur le Pi
# + tests distants (depuis un hôte LAN, car nginx interdit 127.0.0.1 sur system.php/config.php) :
#   remote + token agent → 401 ; remote + XFF spoofé → 401 ; CSRF system.php depuis LAN.
```

## ⚠️ Reste à faire (suivi)
- **Pi de test** : la grant blanket `pi NOPASSWD: ALL` (`/etc/sudoers.d/010-pisignage-nopasswd`)
  est **conservée temporairement** comme canal de déploiement dev. `install.sh` la supprime pour
  toute nouvelle install ; à retirer du Pi de test lors de la revue finale (passage en OTA only).
- **Rate-limiting / lockout login** avant exposition externe (contrôle porteur pour une flotte).
- `nginx deny 127.0.0.1` sur `system.php`/`config.php` : l'agent ne les atteint pas en loopback —
  surface agent = `playlists.php`, `playlist.php`, `display.php` (+ endpoint heartbeat à venir).
