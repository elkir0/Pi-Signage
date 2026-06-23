# Onboarding 1er démarrage (B) + Image flashable (C) — conception

> Statut : décisions produit validées par le proprio le 2026-06-23 (mode ultracode). Sous-projets B+C
> de l'ensemble A·Multi-WiFi (livré) → **B·Onboarding** → **C·Image**. Couplés → un seul spec, plans par phase.
> Ancré sur une recherche multi-agents (5 dimensions + synthèse, workflow `onboarding-image-research`).

## Vision

Livrer une **image `.img` flashable** : le client écrit la carte SD, allume, et un **onboarding « scan du QR à
l'écran »** configure le WiFi du lieu **et** lie l'écran à son compte Zaforge — sans clavier ni SSH.

## Décisions verrouillées

| # | Décision | Choix |
|---|----------|-------|
| 1 | Liaison compte | **Login dans l'assistant** (primaire) + **coller un code** (repli). Endpoint relais `POST /enroll/provision`, **0 changement agent**. |
| 2 | Enrôlement | **OBLIGATOIRE pour finir l'onboarding** (le proprio force la liaison). Marqueur collant : une fois onboardée, la box ne repasse JAMAIS par le setup. |
| 3 | Point d'accès | **Ouvert** (auto-join via QR ; sécurité = endpoints actifs seulement pendant l'onboarding). |
| 4 | Mot de passe admin | **Aléatoire par-device**, affiché une fois sur l'écran de setup (fin du défaut partagé `signage2025`). |
| 5 | Builder image | **sdm** (réutilise `install.sh` quasi tel quel en chroot arm64). |
| 6 | Hôte de build | **Docker-on-Mac** (dev) + **VM600** (référence/CI) + Pi de réserve (smoke final). |
| 7 | Bootstrap 1er boot | **`firstrun.sh` minimal** qui installe+active `zaforge-firstboot.service` puis s'auto-supprime. |

## Contraintes matérielles (non négociables)

- **Radio unique, séquentiel** : le firmware WiFi du Pi4 (BCM43455/brcmfmac) **plante en AP+STA simultané**
  sur Trixie/kernel 6.12 (raspberrypi/linux#7092). L'onboarding est une **machine à états AP↓/STA-essai/AP↑**,
  jamais d'interface virtuelle `ap0`.
- **Base = Raspberry Pi OS Desktop arm64 (Trixie)** : le kiosk exige Wayland/labwc/Chromium (Lite impossible ;
  `install.sh` rejette déjà Lite).

## Phase 0 — RÉPARER `install.sh` (bloquant, indépendant, livrable seul)

La recherche a trouvé qu'**une install réelle est aujourd'hui incomplète** :
- `main()` **n'appelle jamais** `install_zaforge_agent` (la fonction n'existe même pas) → le binaire agent,
  `relay.json` et le service ne sont **pas** déployés.
- **`relay-proxy-secret` n'est jamais provisionné** alors que `web/includes/auth.php` en dépend (pont mode complet).
- Paquets manquants pour B/C : `network-manager` (présent mais à confirmer dans la liste), `dnsmasq-base`, `qrencode`.
- Dérive de version : `VERSION` (fichier) vs `install.sh` vs `version.php` → réconcilier + tamponner
  `/opt/pisignage/IMAGE_VERSION` (version + SHA) pour la traçabilité flotte.

**Phase 0 = définir+appeler `install_zaforge_agent`, provisionner `relay-proxy-secret`, compléter les paquets,
réconcilier la version.** Prérequis de B et C. Vérifiable sur une install normale (.92).

## Architecture

### C · Image « golden » (sdm)

- **`BUILD_MODE` dans `install.sh`** : en build chroot (pas de systemd vivant), `systemctl` sans `--now`,
  saute `hostname -I`, saute `wifi-apply.sh sync` (pas de wlan0 live), pré-stage/saute les fetchs réseau.
- Build : (1) **vendoriser le dépôt à un SHA épinglé** dans l'image (jamais `git clone` réseau au build) ;
  (2) `install.sh` en chroot arm64 (qemu-user-static + binfmt), `HOME=/home/pi` ; (3) injecter le plugin
  FirstBoot sdm (pose le service `zaforge-firstboot`) ; (4) **bake-strip** de tout état par-device avant
  shrink+xz : `rm agent.json credentials.json relay-proxy-secret config/relay/{wg_private.key,enrollment.json}
  /etc/ssh/ssh_host_*`, `echo uninitialized > /etc/machine-id`.
- Pipeline : wrapper de build (Dockerfile épinglant sdm+qemu pour le Mac, cible `make` équivalente sur VM600),
  `pishrink -s` + `xz`. Stampe `IMAGE_VERSION`.

### C · Identité 1er boot (`zaforge-firstboot.service` + `scripts/firstboot.sh`)

- **Un** oneshot `Type=oneshot RemainAfterExit`, `After=` (régen machine-id + clés SSH de RPi OS) et
  `Before=lightdm.service nginx.service`, gardé par un **sentinelle Zaforge** `/opt/pisignage/config/.provisioned`
  (pas `ConditionFirstBoot` : RPi OS peut consommer machine-id avant nous).
- `firstboot.sh` (POSIX sh, root, **idempotent, best-effort — ne DOIT JAMAIS bloquer `graphical.target`**) :
  laisse RPi OS régénérer machine-id + clés SSH ; dérive `hostname zaforge-<8 premiers de machine-id>` + `/etc/hosts` ;
  régénère le token `agent.json` (`openssl rand -hex 32`, 0640 pi:www-data) ; génère le `relay-proxy-secret`
  (0640 root:www-data) ; **génère un mot de passe admin aléatoire** (hash dans `credentials.json`, clair gardé en
  mémoire pour l'afficher sur le setup) ; pose la box **non enrôlée** (`relay.json` code vide, `ENABLE_RELAY` non posé,
  pas de clé WG → l'agent en génère une unique) ; écrit la sentinelle **atomiquement** (tmp+rename) à la fin.
- Boot normal : sentinelle présente → `firstboot.sh` sort en <1s.

### B · Réseau d'onboarding (machine à états radio-unique)

- **AP ouvert** via un profil NM keyfile **persistant** `zf-onboard-ap` (`mode=ap`, `ipv4.method=shared` → dnsmasq
  interne de NM = DHCP+DNS sur 10.42.0.1/24 ; **pas** `nmcli device wifi hotspot` qui est éphémère), + drop-in
  `/etc/NetworkManager/dnsmasq-shared.d/00-zaforge-captive.conf` : `address=/#/10.42.0.1` (hijack DNS) +
  `dhcp-option=114,http://10.42.0.1/setup` (RFC 8910). SSID `Zaforge-Setup-<serial4>`. Désactiver
  `[connectivity] enabled` pendant l'onboarding (sinon NM fait flapper l'AP partagé). **Country code WiFi posé**
  (sinon l'AP ne démarre pas sur Trixie).
- **États** : (0) détection non-provisionné → (1) AP up + drop-in captif → (2) portail captif (vhost nginx
  catch-all existant + blocs probe-URL `captive.apple.com`/`generate_204`/`connecttest.txt` qui **302 → /setup**) →
  (3) handoff : **AP down d'abord**, puis `wifi-apply.sh apply` (PSK via stdin) → (4) vérif ~30s : succès → étape
  compte ; échec (`wifi-apply` rc=3) → **AP relevé**, l'assistant montre « mauvais mot de passe, réessayez ».

### B · Écran kiosk (gate par redirection `player.php`)

- **Gate ~5 lignes en tête de `web/player.php`** : `needsOnboarding()` → `header('Location: /setup'); exit;`.
  **`needsOnboarding()` = NOT (WiFi configuré ET compte lié)** — mais **collant** : si le marqueur
  `/opt/pisignage/config/.onboarded` existe, retourne toujours `false`. **FAIL-OPEN** : toute erreur de détection →
  montrer `/player` (ne jamais bloquer une box qui marche). Une box momentanément hors-ligne mais déjà onboardée ne
  rebondit jamais sur le setup (marqueur collant).
- **`web/setup.php`** (public) : réutilise le design emerald + splash de `player.php` + le **générateur QR offline
  déjà vendorisé** (`player.php`) → rend le QR de join AP (`WIFI:S:Zaforge-Setup-XXXX;T:nopass;;`), le **mot de passe
  admin par-device**, et un **stepper de progression live** qui poll `GET /api/setup.php?action=status` toutes les 2s
  (mirroir du poll de commande du player). nginx : `location = /setup { rewrite ^ /setup.php last; }`.

### B · Liaison compte (login primaire + code repli)

- Le tenant est **autoritatif côté serveur** (le device ne nomme pas son tenant ; `tenant_id` vient de la ligne
  `enrollment_codes`). « Lier au compte » = « générer un code sous le tenant du proprio ».
- **Relais — nouvel endpoint `POST /enroll/provision`** (sans cookie, ~40 lignes) : `{email,password,label}` →
  réutilise **exactement** le `verifyPassword` scrypt + `emailAllow` + `loginLimiter` par IP de `console.js`, génère
  `ids.newEnrollmentCode` sous le tenant de l'utilisateur (INSERT de `admin.js`), renvoie le code en clair. **Son
  propre rate-limiter** dans `server.js`. **0 changement agent.**
- La box (assistant étape B) : login → `POST /enroll/provision` → reçoit le code → `relay-link.sh` écrit `relay.json`
  + `ENABLE_RELAY=1` + redémarre `zaforge-agent`. Repli : coller un code console. L'agent (lecture fichiers au boot)
  relit + enrôle via le **contrat `POST /enroll` existant inchangé** (nonce idempotent, code à usage unique, /32 +
  MQTT + WG). Spinner « Liaison… » dimensionné pour la montée WG (~30s).

### Surface privilégiée (le point réellement sensible)

`www-data` n'a aujourd'hui **aucun** droit de lever l'AP, écrire `relay.json`/`feature_flags`, ou redémarrer
`zaforge-agent`. On **calque exactement le précédent `wifi-apply.sh`** (helper root:root 0755, ligne sudoers à args
fixes, validation DANS le helper) :
- **`scripts/onboard-ap.sh up|down`** — lève/abaisse `zf-onboard-ap` + pose/retire le drop-in captif.
- **`scripts/relay-link.sh`** — valide le code (regex `^ZF-[0-9A-Z]{4}-...`) + `relay_url` (allowlist) AVANT
  d'écrire `relay.json`/`feature_flags` et de redémarrer l'agent. **Jamais** de PHP écrivant ces fichiers sous sudo blanket.
- **Endpoints d'onboarding non authentifiés** (`api/setup.php` apply/link + status) : exception **étroite** dans
  `_guard.php` **gardée sur l'état non-provisionné**, qui **s'auto-désactive** dès que `.onboarded` est écrit (sinon
  trou permanent de config wifi/relais non authentifié). À côté des exceptions existantes playlist/display.

## Composants

**À construire** : `scripts/firstboot.sh` + `zaforge-firstboot.service` ; `scripts/onboard-ap.sh` ; profil NM
`zf-onboard-ap` + drop-in dnsmasq captif ; `web/setup.php` ; gate `player.php` ; `web/api/setup.php`
(status/apply/link, auto-désactivable) ; `scripts/relay-link.sh` ; relais `POST /enroll/provision` ;
additions nginx (route /setup + blocs probe) ; exception `_guard.php` ; **fixes `install.sh` (Phase 0)** ;
pipeline de build sdm (+ Dockerfile + cible VM600).

**Réutilisé tel quel** : `scripts/wifi-apply.sh` (étape WiFi du lieu + signal « WiFi configuré » via
`wifi-networks.json`) ; `wifi-lib.php` `wifiValidateAndBuild()` ; vhost nginx catch-all ; `player.php` (design +
point de redirection) ; QR offline vendorisé ; pattern de poll JSON public ; contrat `POST /enroll`
(agent + relais) inchangé ; minting de code tenant-borné (`admin.js`) ; auth login console (`console.js`) ;
agent lecture-au-boot ; chaîne kiosk-apply/labwc/lightdm inchangée ; mécanisme d'exception `_guard.php`.

## Phasage (chaque phase laisse le produit livrable)

- **Phase 0** — fixes `install.sh` (agent + relay-proxy-secret + paquets + version). Vérifié sur .92.
- **Phase C1** — `BUILD_MODE` + build sdm sur Docker-Mac → une image golden qui boote sur `/player` (sans
  onboarding) : valide chroot/HOME/strip/shrink de bout en bout.
- **Phase C2** — `zaforge-firstboot.service` + `firstboot.sh` + sentinelle + bake-strip ; vérifié en flashant
  **deux** cartes → machine-id/hostname/token/identité WG **distincts**.
- **Phase B1** — `setup.php` + gate `player.php` + route nginx /setup + `onboard-ap.sh` + profil AP + drop-in
  captif + boucle AP↓/STA-essai/AP↑ câblée sur `wifi-apply.sh` (étape compte sautée) — pièce la plus couplée au
  matériel, **testée sur le vrai Pi .92**.
- **Phase B2** — relais `POST /enroll/provision` + `relay-link.sh` + étape compte de l'assistant (login + repli
  code) + **gate qui exige l'enrôlement** (décision #2) + mot de passe par-device affiché (décision #4).

## Risques / sécurité (synthèse de l'audit de recherche)

- AP+STA simultané = crash firmware → **séquentiel obligatoire**.
- Nouvelle surface privilégiée www-data → helpers root à args fixes + validation interne (jamais sudo blanket).
- Endpoints d'onboarding non-auth → **auto-désactivation stricte** sur `.onboarded` (sinon trou permanent).
- Suppression de la « page de connexion » OS : **302 sur toutes les probes** (+ DNS wildcard + option 114) sinon
  le téléphone croit avoir internet et n'ouvre pas l'assistant.
- Fuite d'identité par-device si baked → **bake-strip (primaire) + régen 1er boot (filet)** ; `gatherFacts()`
  envoie machine-id/hostname à l'enrôlement → régénérer AVANT le 1er enrôlement.
- Pièges chroot : pas de systemd (drop `--now`), `HOME` → `/home/pi`, qemu lent ; réconcilier+tamponner la version.
- **Gate fail-open** : toute erreur de détection → `/player` ; marqueur collant pour ne jamais rebondir une box
  managée momentanément offline ; `firstboot` best-effort.

## Tests

- **Phase 0** : install normale sur .92 → agent présent+actif, `relay-proxy-secret` présent, mode complet OK, version stampée.
- **C1** : l'image boote sur `/player` (smoke en VM/Pi).
- **C2** : 2 cartes flashées → identités distinctes (machine-id, hostname, token, clé WG).
- **B1** (sur .92, harnais sûr) : AP monté (SSID visible), portail captif s'ouvre (probe → 302), saisie WiFi → AP↓ →
  `wifi-apply` → reconnexion ; mauvais mot de passe → AP↑ + message ; **l'écran kiosk ne perd jamais le loopback**.
- **B2** : login → `/enroll/provision` → code → `relay-link.sh` → enrôlement → badge online dans la console ; repli
  code OK ; gate exige l'enrôlement ; endpoints auto-désactivés après `.onboarded` ; mot de passe par-device affiché.
- Revue adversariale (workflow) sur la surface privilégiée + endpoints non-auth avant de clore B2.

## Hors scope

Provisioning d'usine multi-cartes en masse, signature OTA de l'image, mises à jour d'image OTA (l'app se met déjà
à jour via le dépôt ; l'image est un point de départ). Multi-écran. WiFi entreprise (EAP) en onboarding.
