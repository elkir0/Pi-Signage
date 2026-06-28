# Handoff → Codex : finir les chantiers B + C de Zaforge (onboarding + image flashable)

Tu reprends un projet en cours sur la branche `feature/zaforge` du repo `/Users/anthony/pisignage`
(GitHub `elkir0/Pi-Signage`). Lis ce document EN ENTIER avant d'agir. Il contient l'état précis, ce
qui reste, et surtout les **contraintes de sécurité opérationnelle** pour ne RIEN casser en prod.

---

## 0) Contexte produit (1 paragraphe)

Zaforge = solution d'affichage dynamique sur Raspberry Pi 4 (RPi OS **Desktop** Trixie, kiosk
Wayland/labwc + Chromium sur `http://127.0.0.1/player`). Réseau géré par **NetworkManager**. App web
PHP 8.4 + nginx dans `/opt/pisignage/web`. Un **agent Go** (`agent/`) enrôle la box à un **relais**
(`relay.zaforge.com`, code Node dans `relay/fleet-api/`, hébergé en Docker sur la VM600) via WireGuard
+ MQTT. On construit **un onboarding 1er-démarrage « scan du QR »** (B) et **une image .img flashable**
(C). Tout est spécifié + décidé. Spec de référence (À LIRE) :
`docs/superpowers/specs/2026-06-23-onboarding-and-image-design.md`.

Contrainte matérielle DURE : le firmware WiFi du Pi4 **plante en AP+STA simultané** → l'onboarding est
**séquentiel radio-unique** (AP↓ / essai-STA / AP↑). Base image = RPi OS **Desktop** (le kiosk exige
Wayland). Décisions proprio verrouillées : compte = **login dans l'assistant + coller un code en
repli** ; **enrôlement OBLIGATOIRE** pour finir ; **AP ouvert** ; **mot de passe admin aléatoire
par-device** affiché à l'écran ; builder **sdm** ; build sur **Docker / VM600**.

---

## 1) Infrastructure & accès (réels)

- **Pi de test, LIVE et managé** : `192.168.1.92`. SSH `pi` / mot de passe `palmer00` (clé installée).
  Web admin `admin` / `palmer00`. **sudo durci** : pas de blanket ; `echo palmer00 | sudo -S ...`.
  La box est **en WiFi** (`wlan0`, SSID `shathony`), `eth0` DOWN, tunnel `zf0` (WireGuard relais).
- **Relais, PRODUCTION** : VM600 `10.10.10.160`, accès `ssh -J root@37.187.155.234 deploy@10.10.10.160`.
  fleet-api = conteneur Docker `zf-fleet-api` (port `10.10.10.160:3200`), DB `/data/zaforge.db`
  (better-sqlite3). Le proprio = console_user `anthony.dhaene@gmail.com`, tenant `t_a5efsuak3dhl`
  (plan lifetime, managed-on = entitled). `relay.zaforge.com` (HTTPS via le reverse-proxy CT101).

---

## 2) État EXACT du code (vérifie avec `git status` / `git log`)

**Poussé sur `origin/feature/zaforge` (jusqu'à `db6ff6e`)** — fait + vérifié :
- **A · Multi-WiFi fallback** : 3 réseaux + priorité via NM. Helper root `scripts/wifi-apply.sh`
  (apply lit stdin / sync), profils `zf-wifi-<sha1(ssid)[:12]>`, `autoconnect-priority` 30/20/10.
  PHP `web/api/wifi-lib.php` (validation pure, tests) + `web/api/config.php` (GET `?action=wifi`,
  POST `type=wifi`). UI `web/settings.php` + `init.js`/`api.js`. Audité (workflow multi-agents),
  durci (handoff transactionnel anti-lock-out, UTF-8/JSON, WORKDIR `/run`, retry psk, privesc
  scripts/-dir-root-owned). **Vérifié live sur .92.**
- **Phase 0 · install.sh complet** : `install_zaforge_agent` (était ABSENTE → l'agent n'était jamais
  installé) DÉFINIE+appelée ; `provision_relay_proxy_secret` ; paquets `network-manager dnsmasq-base
  qrencode golang-go` ; version unifiée **v0.12.4** + `IMAGE_VERSION`. **Vérifié .92.**
- **B1 · onboarding réseau + écran** : `web/includes/onboarding.php` (gate par marqueurs ROOT
  `.onboarding`/`.onboarded`, FAIL-OPEN, + `zfOnboardingClientAllowed()` = loopback + AP 10.42.0.0/24),
  gate dans `web/player.php`, exception `web/api/_guard.php`, `web/setup.php` (vue kiosk = QR qrencode
  + mdp + stepper / vue téléphone = assistant ; split par REMOTE_ADDR), `web/api/setup.php`
  (status + apply), `scripts/onboard-ap.sh` (root:root 0755, AP ouvert NM mode=ap shared + drop-in
  dnsmasq captif + finalize), nginx `/setup` + 302 sondes captives, sudoers args fixes. Revue
  adversariale → corrigé l'auto-désactivation (les endpoints ne se refermaient jamais). **Vérifié live
  sur .92 (parties sûres).**
- **B2 · liaison compte** : **relais `POST /enroll/provision`** (`routes/enroll.js` `provision()` +
  exports `console.js` `verifyPassword`/`emailAllow`/`emailClear` + route `server.js`) — login console
  scrypt + limiters → génère un code sous le tenant DU COMPTE (autoritatif). **Déployé LIVE sur VM600 +
  vérifié bout-en-bout** (201+code sous bon tenant ; mauvais creds → 401). Box : `scripts/relay-link.sh`
  (root:root 0755, code via STDIN, valide regex+allowlist `relay_url`, écrit relay.json + ENABLE_RELAY=1
  + restart agent) ; `web/api/setup.php` `apply` = flux radio-unique complet (valide wifi+compte → AP
  down → wifi-apply → `provisionCode` cURL/TLS ou code collé → relay-link → finalize) ; `web/setup.php`
  assistant 2 étapes. Vérifié .92 : relay-link rejette les mauvais codes sans toucher le relay.json live.

**Committé mais NON poussé** : `ebc2e8b` — **C2 · identité 1er-boot** : `scripts/firstboot.sh`
(idempotent, BEST-EFFORT, gardé par sentinel `.provisioned` ; régénère hostname/agent.json/
relay-proxy-secret/mdp admin bcrypt ; box NON enrôlée ; décide l'onboarding ; testable via
`ZF_CONF`/`ZF_DRY`), `deploy/systemd/zaforge-firstboot.service`, `scripts/bake-strip.sh` (retire l'état
par-device avant de sceller l'image), wiring `install.sh` (déploie+enable le service ; une install
NORMALE écrit `.provisioned` → firstboot fast-path ; seule l'image bake-strippée le relance).
**Sandbox-vérifié sur .92** (identité live intacte) : bcrypt valide, idempotent, tokens uniques, bake-strip OK.

**Modifs NON committées dans l'arbre de travail (en cours — à reprendre/committer)** :
- `scripts/onboard-ap.sh` : `nmcli -w 20 con up` (borne le 90s par défaut, évite de retarder le kiosk).
- `scripts/firstboot.sh` : `timeout 10 hostnamectl` (durcissement disponibilité — l'invariant est
  « firstboot ne DOIT JAMAIS bloquer le kiosk »).
- `install.sh` : **C1 commencé** — variable `BUILD_MODE` + `SOURCE_DIR` + wrapper `sysd()` ajoutés en
  tête, MAIS **les guards ne sont pas encore câblés** (le code existant appelle toujours `sudo
  systemctl ...` en dur). `install.sh` n'est PAS cassé (`sysd()` inutilisé). `bash -n install.sh` passe.
- `scripts/tests/wifi-apply.test.sh` : modif mineure (vérifie le diff).
- (PNG non suivis à la racine = artefacts de test, ignore.)

---

## 3) Ce qui RESTE à faire

### C1 — pipeline d'image sdm (le gros morceau restant)
1. **Finir `BUILD_MODE` dans `install.sh`** (set -e actif → en chroot, les actions runtime de
   systemctl avortent le build). Le wrapper `sysd()` est déjà écrit (neutralise start/restart/
   daemon-reload/--now en BUILD_MODE, laisse passer `enable`). À FAIRE : router les appels concernés
   via `sysd` (ou guards `[ "$BUILD_MODE" = 1 ] ||`) :
   - les `sudo systemctl daemon-reload` NON gardés (≈ lignes 1151, 1505, 1517) ;
   - `systemctl enable --now ...timer` (le `--now` doit sauter) ;
   - `systemctl start/restart pisignage.service`, `restart zaforge-agent`, nginx/php reload ;
   - **NE PAS écrire le sentinel `.provisioned`** en BUILD_MODE (l'image doit lancer firstboot) ;
   - sauter `wifi-apply.sh sync` (pas de wlan0) et `hostname -I` (banner) en BUILD_MODE ;
   - `clone_from_github` : si `SOURCE_DIR` est défini, copier le dépôt LOCAL (build reproductible)
     au lieu de `git clone` réseau.
2. **`scripts/build-image.sh`** (orchestration sdm) : récupère l'image de base RPi OS **Desktop**
   arm64 (Trixie), lance `install.sh` dans un **chroot arm64** (qemu-user-static + binfmt) avec
   `BUILD_MODE=1 SOURCE_DIR=<repo>` et `HOME=/home/pi`, le service firstboot est posé par install.sh,
   puis `scripts/bake-strip.sh` sur le rootfs, puis `pishrink -s` + `xz`. Tampon `IMAGE_VERSION`.
3. **Env de build** : Dockerfile (epingle sdm + qemu) pour builder sur Mac OU sur la VM600 (Debian 13).
   ⚠️ **Sur VM600, `docker compose build` exige buildx ≥ 0.17 (absent)** → utiliser
   `DOCKER_BUILDKIT=0 docker build -t <tag> <ctx>`.
4. Vérifier ce qui est vérifiable (syntaxe + un snippet `BUILD_MODE=1` prouve que start/restart sont
   sautés) ; **le build complet + le flash sont des opérations sur un hôte de build / physiques**
   (pas faisables depuis le poste Mac actuel — pas de Docker).

### C2 — finaliser
- Committer les 2 durcissements en cours (onboard-ap `-w 20`, firstboot `timeout`).
- **Relancer une revue adversariale propre de C2** (la mienne a été coupée par des limites de session :
  0 finding confirmée, mais incomplète). Dimensions : unicité d'identité par-device, non-blocage du
  kiosk (firstboot best-effort), exhaustivité de bake-strip + logique `.provisioned`.

### Pousser
- Pousser `ebc2e8b` + tes commits C1/C2 sur `origin/feature/zaforge` **après vérification**.

### Tests PHYSIQUES (le proprio, sur place — IMPOSSIBLE à distance)
- **Flux AP end-to-end** : flasher une carte (ou poser le marqueur sur une box de test) → l'écran montre
  le QR → scan au téléphone → portail captif → saisir WiFi + compte → bascule → kiosk managé.
- **`relay-link.sh` avec un VRAI code** (re-lierait la box → à faire sur une box de test, pas .92).
- **Flash de l'image** produite par C1.

---

## 4) CONTRAINTES DE SÉCURITÉ OPÉRATIONNELLE (ne casse RIEN en prod)

- **.92 est une box LIVE managée.** NE LANCE PAS `firstboot.sh` pour de vrai dessus (il régénérerait
  token/mot de passe/identité → casse l'enrôlement). Utilise le **mode sandbox** :
  `ZF_CONF=/tmp/xxx ZF_DRY=1 sh firstboot.sh`. NE relie PAS .92 avec un vrai code via `relay-link.sh`
  (teste seulement le REJET de codes invalides). **NE lève PAS l'AP sur .92 à distance** : `onboard-ap.sh
  up` coupe le STA = **tu perds le SSH** (et tu ne peux pas être le téléphone). L'AP/onboarding réels =
  test physique.
- **Le relais VM600 est en PROD.** Recréer `zf-fleet-api` = reconcile = re-provision dynsec = **KICK
  transitoire des devices** (flap MQTT, ils se reconnectent seuls — normal). Build de l'image fleet-api :
  `DOCKER_BUILDKIT=0 docker build` (pas `compose build`). Ne touche pas aux autres conteneurs.
- **Déploiement web sur .92** : copier via `~/` (PAS `/tmp` qui est CHRONIQUEMENT à 100% à cause de
  Chromium), puis `sudo install ...`. **Reload `php8.4-fpm` après TOUT `.php`** (OPcache). Les helpers
  root vont dans `/opt/pisignage/scripts/` (ce répertoire DOIT rester `root:root` — un fix de privesc
  l'impose : sinon www-data pourrait remplacer un helper root sudo-granté).
- **Travail root sur .92** : `sudo tee` vers un fichier temp possédé par `pi` échoue → fais TOUT le
  travail root dans **un seul `sudo sh -c '...'`** ; cache les creds avec `echo palmer00 | sudo -S -v`.
- **Le WORKDIR des helpers est dans `/run`** (pas `/tmp` qui est plein) — garde ce choix.

## 5) Invariants d'architecture / sécurité à respecter

- Helpers root sudo-grantés : **root:root 0755**, **arguments FIXES** dans sudoers (jamais de wildcard),
  **secrets via STDIN** (jamais argv → pas de fuite `ps`), **validation DANS le helper** (ne jamais
  faire confiance à PHP). Modèles : `wifi-apply.sh`, `onboard-ap.sh`, `relay-link.sh`.
- php-fpm (www-data) **ne peut pas lire `relay.json`** (pi:pi) → le gate d'onboarding s'appuie sur des
  marqueurs ROOT (`.onboarding`/`.onboarded`), jamais sur relay.json.
- Endpoints d'onboarding **publics UNIQUEMENT** pendant l'onboarding actif ET depuis loopback/AP-subnet
  (`zfOnboardingClientAllowed()`), s'auto-désactivent après `.onboarded`. Le gate `player.php` est
  **FAIL-OPEN** (toute erreur → /player, ne jamais bloquer un écran qui marche).
- `firstboot.sh` est **BEST-EFFORT** : il ne DOIT JAMAIS bloquer `graphical.target` / le kiosk
  (`set -u` mais pas `set -e`, tout en `|| true`/`timeout`).
- Liaison tenant **autoritative côté serveur** (le device ne nomme jamais son tenant).

## 6) Méthode attendue

Implémenter → **contrôle fonctionnel** (live sur .92/VM600 quand c'est SÛR, sinon sandbox/raisonnement)
→ **revue de bugs systématique** (workflow multi-agents adversarial, refute-par-défaut, ou inline si
limites) → **boucle de correction** → commit. **Ne JAMAIS annoncer « vérifié » sans preuve** ; distingue
clairement ce qui est vérifié live de ce qui attend un test physique. Lis les specs/plans en repo
(`docs/superpowers/specs/`, `docs/superpowers/plans/`). Le helper `agent/` (Go) se build avec
`GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build ./agent` (go.mod dans `agent/`).

Bonne reprise.
