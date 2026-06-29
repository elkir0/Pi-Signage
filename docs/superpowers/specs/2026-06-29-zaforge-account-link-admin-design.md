# Spec — Admin « Compte Zaforge » (lier / re-lier depuis l'interface web)

**Date** : 2026-06-29
**Branche** : `feature/zaforge`
**Statut** : validé (proprio), en implémentation

## Problème

La box ne peut être liée à un compte zaforge.com QUE pendant l'onboarding 1er-boot
(`web/setup.php`), gated loopback + AP `10.42.0.0/24` et auto-désactivé une fois
`.onboarded` posé. Aucune surface admin LAN authentifiée pour voir/(re)lier le compte.
Capacité système présente (`scripts/relay-link.sh` écrit `relay.json` + `ENABLE_RELAY=1`
+ restart agent), mais pas d'UI post-onboarding.

## Décisions (proprio)

1. **Méthode de liaison** : les DEUX — login console (email+mdp → relais
   `/enroll/provision` → code) ET repli « coller un code » `ZF-XXXX-XXXX-XXXX`.
2. **État affiché** : complet + live — lié/non-lié, tenant + device, URL relais,
   code masqué, statut « connecté au relais » (agent actif + dernier heartbeat).
3. **Pas de bouton Délier** — lier/re-lier seulement (re-lier écrase).

## Contraintes techniques

- `relay.json` = `pi:pi 0640`, `config/relay/` = `pi:pi 0700`,
  `relay/enrollment.json` = `pi:pi 0600` → **www-data ne lit RIEN de tout ça**.
  Donc le statut passe par un **helper root** en lecture seule.
- Re-lier vers un AUTRE compte = **rebind** (`agent/enroll.go` envoie `Rebind` ;
  `relay-link.sh` écrit aujourd'hui `rebind:false`). L'admin re-link doit pouvoir
  poser `rebind:true`, sinon le relais peut refuser de déplacer un device déjà enrôlé.
- L'admin LAN est en HTTP : le mode **login** fait transiter le mot de passe Zaforge
  en clair sur le LAN jusqu'au Pi (puis TLS vers le relais). Avertissement UI ; le
  mode **code** l'évite.

## Architecture

### Helpers système
- **`scripts/relay-status.sh`** (NOUVEAU, root:root 0755) — lecture seule. Sort un
  JSON **sanitisé** sur stdout : `linked` (relay.json présent + code valide),
  `enabled` (ENABLE_RELAY), `relay_url`, `code_masked` (`ZF-••••-••••-XXXX`),
  `tenant_id`, `device_id`, `fingerprint` (court), `base_topic`, `agent_active`
  (`systemctl is-active zaforge-agent`), `tunnel_up` (interface `zf0` présente),
  `last_heartbeat_age_s` (journald : dernier « heartbeating »/publish, best-effort).
  **JAMAIS** : token agent, mqtt.password, clés WG, code en clair.
- **`scripts/relay-link.sh`** (ÉTENDU) — accepte un arg optionnel `rebind` :
  `printf '%s' "$code" | sudo relay-link.sh rebind` → écrit `"rebind": true`.
  Sans arg = comportement actuel (`rebind:false`). Grant sudoers bare déjà en place
  (tout arg autorisé) → pas de nouvelle règle pour le rebind. Validation du code
  inchangée (regex stricte, STDIN).

### Backend PHP
- **`web/api/relay-lib.php`** (NOUVEAU, partagé) — constantes (`RELAY_BASE`,
  chemins helpers), `relayProvisionCode($email,$pwd)` (cURL TLS `/enroll/provision`,
  factorisé depuis `setup.php`), `relayValidateCode($code)`, `relayMaskCode($code)`,
  `relayRunStdin($argv,$payload)`, `relayReadStatus()` (appelle relay-status.sh via
  sudo, décode le JSON). AUCUNE sortie HTTP (réutilisable CLI/tests).
- **`web/api/account.php`** (NOUVEAU, authentifié admin, PAS d'exception `_guard`) :
  - `GET ?action=status` → `relayReadStatus()` → JSON.
  - `POST ?action=link` `{mode:'code'|'login', code?|email?,password?}` → résout le
    code (login → `relayProvisionCode`), puis `relay-link.sh rebind` via STDIN.
    Réponses honnêtes (creds refusés / relais injoignable / code invalide / échec lien).
  - CSRF requis (méthode mutante, géré par `_guard.php`).
- **`web/api/setup.php`** — refactor pour consommer `relay-lib.php` (supprime la
  duplication `provisionCode`/constantes ; comportement onboarding inchangé).

### UI
- **`web/settings.php`** — nouvelle carte « Compte Zaforge » : zone statut (badge
  Connecté/Déconnecté, lié/non-lié, tenant/device, relais, code masqué, âge heartbeat)
  + formulaire Lier/Re-lier avec bascule Login (email+mdp) / Code (ZF-…), avertissement
  HTTP sur le mode login.
- **`web/assets/js/settings.js`** — `PiSignage.settings` : `loadAccountStatus()`,
  `linkAccount()`, rendu du statut, bascule de mode. Polling léger du statut après
  un lien (l'enrôlement prend quelques secondes).
- **`web/assets/js/api.js`** — `PiSignage.api.account.{status,link}`.

### Déploiement / install
- **`install.sh`** : installer `relay-status.sh` (root:root 0755, ajouté à la boucle
  de durcissement), ajouter le grant sudoers
  `www-data ALL=(root) NOPASSWD: /opt/pisignage/scripts/relay-status.sh`.
- **Bump version** `web/version.php` v0.12.5 → **v0.12.6** (cache-bust JS/CSS).

## Sécurité

- `account.php` = admin authentifié + CSRF (jamais d'exception publique dans `_guard.php`).
- Helpers root à args fixes/validés ; secrets jamais exposés ni journalisés ; code en
  STDIN (pas d'argv → pas de fuite `ps`).
- Allowlist `relay_url` (anti-SSRF) conservée dans `relay-link.sh`.
- Avertissement explicite sur le mode login (mot de passe en clair sur le LAN HTTP).

## Tests

- **`scripts/tests/relay-account.test.sh`** (CLI) : `relayValidateCode` (accepte
  `ZF-AAAA-BBBB-CCCC`, rejette le reste), `relayMaskCode` (masque tout sauf le dernier
  groupe), `relay-status.sh` parse un faux `relay.json`/`enrollment.json` et n'émet
  aucun secret. (`relayProvisionCode` = réseau, non testé hors ligne.)
- **Live** (Pi .62, quand joignable) : GET status rend l'état réel (déjà enrôlé,
  tenant `t_a5efsuak3dhl`), re-link via code de test sans casser le lien courant si
  invalide, vérif Playwright (carte rend, 0 erreur console).

## Hors scope

- Délier/unlink (refusé). Rotation de token agent. Multi-compte. Historique de liens.
