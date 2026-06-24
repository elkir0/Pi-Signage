# Reprise Commerciale OTB — Cloud, Onboarding et Image Flashable

> Statut : conception validée en session Codex le 2026-06-24. Cette spec recadre le chantier B+C existant pour produire un parcours commercial réellement utilisable par un client non technique, tout en conservant la version gratuite locale.

## Objectif

Livrer deux images Zaforge distinctes :

- **Image gratuite locale** : démarre sans QR cloud obligatoire. Le client configure la box dans le mini-site web local du Raspberry Pi.
- **Image commerciale cloud** : affiche un QR de configuration au premier boot. Le téléphone rejoint l’assistant local du Pi, configure le WiFi du lieu, lie la box au compte `app.zaforge.com`, puis la suite se fait dans la console cloud.

Le succès commercial OTB signifie : un client qui possède déjà un compte `app.zaforge.com` peut flasher l’image commerciale, brancher l’écran, scanner le QR, saisir WiFi + identifiants Zaforge, puis retrouver une box active et pilotable dans la console sans SSH, sans terminal et sans confirmation manuelle.

## Décisions Produit Verrouillées

| Sujet | Décision |
|---|---|
| Packaging | Deux images séparées : gratuite locale et commerciale cloud. |
| QR onboarding | Uniquement dans l’image commerciale. |
| Premier écran commercial | QR affiché sur l’écran du Raspberry Pi. |
| Premier écran gratuit | Pas de QR cloud obligatoire ; configuration via mini-site local. |
| Assistant commercial | Assistant local Pi via AP ouvert `Zaforge-Setup-XXXX`. |
| Compte client | Le compte `app.zaforge.com` existe avant livraison/allumage. Pas de signup dans cette phase. |
| Liaison compte | Email + mot de passe Zaforge dans l’assistant local, avec code d’enrôlement comme outil support/fallback. |
| Confirmation appareil | Auto-confirmation commerciale : après liaison réussie via le compte, la box devient directement active/pilotable. |
| Fin d’onboarding | Deux états visibles : “liaison lancée” puis “visible dans le cloud” si confirmé. Si la confirmation tarde, afficher une sortie guidée vers `app.zaforge.com`/support. |
| Handoff utilisateur | QR/lien `app.zaforge.com` visibles sur l’écran du Pi et sur le téléphone. |

## Analyse Critique de l’Existant

### Ce qui est solide

- Le relais pose déjà des bases de sécurité correctes : tenant autoritatif côté serveur, WireGuard non routé, ACL MQTT littérales, allocation IP cloisonnée, et BFF console sans clé API dans le navigateur.
- L’agent Go a un contrat clair : `ENABLE_RELAY=1`, lecture de `relay.json`, enrôlement `/enroll`, tunnel WireGuard, MQTT, heartbeat, et commandes via pont loopback limité.
- L’onboarding B1/B2 a les bons invariants de surface privilégiée : helpers root `root:root 0755`, secrets via STDIN, arguments sudoers fixes, marqueurs root `.onboarding`/`.onboarded`, et gate `/player` fail-open.
- Le flux actuel respecte la contrainte radio unique du Pi4 : AP puis STA, jamais AP+STA simultané.
- Le chantier C2 introduit les bonnes briques pour une image golden : `firstboot.sh`, `zaforge-firstboot.service`, `bake-strip.sh`, identité par-device, mot de passe admin aléatoire.

### Ce qui empêche un vrai OTB commercial

- Le code actuel ne distingue pas encore “image gratuite” et “image commerciale”. Sans garde d’édition, le QR/onboarding risque d’apparaître dans des cas où l’utilisateur gratuit attend le mini-site local.
- Le pipeline C1 image n’est pas terminé : `BUILD_MODE` existe dans `install.sh`, mais les appels runtime `systemctl`, `hostname -I`, `wifi-apply sync`, le sentinel `.provisioned`, et `SOURCE_DIR` ne sont pas encore tous câblés.
- `scripts/build-image.sh` et l’environnement Docker/sdm n’existent pas encore.
- Le flux téléphone actuel est trop optimiste : il lance l’opération complète dans une requête HTTP locale, puis coupe l’AP. Comme la radio est unique, le téléphone perd le lien local au moment où la box rejoint le WiFi du lieu ; il ne faut pas dépendre d’une réponse finale locale après cette coupure.
- `web/api/setup.php` finalise actuellement juste après `relay-link.sh`. Cela prouve que les fichiers locaux ont été écrits, pas que la box est visible et pilotable dans le cloud.
- Le relais crée les nouveaux devices en `pending`. Ce comportement est acceptable pour des codes administrateur, mais contredit le parcours commercial OTB validé.
- L’UX actuelle reste trop technique et n’offre pas assez de récupération guidée : attente cloud, erreur WiFi, mauvais mot de passe Zaforge, relais injoignable, agent lent, et redirection vers la console.
- Les tests automatisés autour de `/enroll/provision`, de l’auto-confirmation commerciale, et des états d’onboarding sont insuffisants ou absents.

## Architecture Cible

### 1. Éditions d’Image

Les deux images partagent le même code applicatif, mais divergent par un flag d’édition baked dans `/opt/pisignage/config/feature_flags` :

```ini
ZAFORGE_EDITION=free
```

ou :

```ini
ZAFORGE_EDITION=commercial
ENABLE_COMMERCIAL_ONBOARDING=1
ENABLE_RELAY=0
```

Règles :

- `free` : `firstboot.sh` régénère l’identité locale si nécessaire, mais ne lève pas l’AP commercial et ne force pas la liaison cloud.
- `commercial` : `firstboot.sh` lève l’AP commercial si `.onboarded` est absent.
- `ENABLE_RELAY=1` n’est posé qu’après saisie compte/code dans l’assistant commercial.
- `.onboarded` reste collant : une box commerciale liée ne revient jamais au setup à cause d’une panne temporaire.

### 2. Build Image C1

`install.sh` doit devenir compatible chroot via `BUILD_MODE=1 SOURCE_DIR=<repo>` :

- `sysd` remplace les appels runtime `systemctl` pour neutraliser `daemon-reload`, `start`, `restart`, `reload`, et `enable --now` en build.
- `enable` reste autorisé pour poser les symlinks systemd attendus au premier boot.
- `clone_from_github` utilise `SOURCE_DIR` quand défini, afin que le build image soit reproductible et basé sur le repo local.
- Le sentinel `/opt/pisignage/config/.provisioned` n’est jamais écrit en `BUILD_MODE=1`.
- `wifi-apply.sh sync`, `hostname -I`, les tests runtime de services, et les banners IP sont sautés en `BUILD_MODE=1`.
- Le build supporte `--edition free` et `--edition commercial`.

Un nouveau `scripts/build-image.sh` orchestre :

1. téléchargement ou sélection de l’image Raspberry Pi OS Desktop arm64 Trixie ;
2. montage/chroot arm64 via sdm + qemu/binfmt ;
3. exécution `BUILD_MODE=1 SOURCE_DIR=<repo> HOME=/home/pi bash install.sh --auto --force` ;
4. écriture de l’édition (`free` ou `commercial`) dans `feature_flags` ;
5. activation de `zaforge-firstboot.service` ;
6. exécution `scripts/bake-strip.sh` sur le rootfs ;
7. stamp `IMAGE_VERSION` avec version, SHA, édition, date ;
8. `pishrink -s` puis compression `xz`.

### 3. Flux Commercial Téléphone

L’assistant local conserve le QR WiFi AP et le formulaire WiFi + compte, mais le traitement doit être asynchrone côté utilisateur :

1. Le téléphone charge `/setup` via l’AP.
2. Le client saisit SSID, mot de passe WiFi, email et mot de passe Zaforge.
3. L’assistant valide les champs localement.
4. Avant de couper l’AP, le téléphone reçoit une page “liaison lancée” avec :
   - “L’écran continue la configuration” ;
   - bouton/lien `https://app.zaforge.com` ;
   - conseil clair : “si votre téléphone quitte le WiFi Zaforge-Setup, ouvrez la console avec votre connexion normale”.
5. Après avoir envoyé cette réponse, PHP appelle `fastcgi_finish_request()` puis continue côté serveur. PHP-FPM est une dépendance de l’image commerciale ; si cette fonction est absente, l’endpoint échoue avant de couper l’AP avec un message “runtime de configuration indisponible”.
6. Le travail long passe par un nouveau helper root `scripts/commercial-onboard.sh`, appelé sans argument utilisateur et alimenté via STDIN. Ce helper orchestre AP down, `wifi-apply`, provision du code commercial, `relay-link`, démarrage agent, et écriture d’un état non secret lisible par le kiosk.
7. La box coupe l’AP, applique le WiFi, provisionne un code commercial, lie `relay.json`, démarre l’agent, et écrit un état non secret lisible par le kiosk.

Le téléphone ne doit jamais dépendre d’une réponse HTTP locale finale après coupure AP. La confirmation “visible cloud” est portée par l’écran du Pi et par `app.zaforge.com`.

### 4. État d’Onboarding

Ajouter un état non secret, par exemple `/opt/pisignage/config/setup-state.json`, écrit par les helpers root et lisible par `www-data` :

```json
{
  "edition": "commercial",
  "phase": "wifi_applying|wifi_failed|link_started|agent_enrolling|cloud_visible|cloud_delayed|done|failed",
  "message": "Texte court non technique",
  "connected_ssid": "NomDuWifi",
  "device_id": "d_xxx",
  "updated_at": "2026-06-24T12:00:00Z"
}
```

Contraintes :

- aucun mot de passe WiFi ;
- aucun mot de passe Zaforge ;
- aucun code d’enrôlement ;
- aucun secret MQTT/WireGuard ;
- permissions compatibles lecture web, écriture root.

`/setup` côté kiosk affiche :

- QR AP tant que `phase` précède la coupure AP ;
- “liaison lancée” quand le téléphone a soumis le formulaire ;
- “visible dans le cloud” quand l’agent confirme l’enrôlement et la connexion MQTT ;
- QR/lien `app.zaforge.com` ;
- sortie guidée si `cloud_visible` n’arrive pas dans un délai borné.

### 5. Preuve Cloud Locale

L’agent doit écrire un fichier d’état non secret, par exemple `/opt/pisignage/config/relay/status.json`, après ces étapes :

```json
{
  "enabled": true,
  "enrolled": true,
  "device_id": "d_xxx",
  "mqtt_connected": true,
  "last_cloud_connected_at": "2026-06-24T12:00:00Z",
  "last_error": ""
}
```

Le kiosk considère “visible cloud” quand :

- `enrolled=true` ;
- `device_id` non vide ;
- `mqtt_connected=true` ou `last_cloud_connected_at` récent.

Cette preuve est locale et non secrète. Elle évite de stocker les identifiants Zaforge et évite de dépendre d’un polling cloud depuis PHP.

### 6. Auto-confirmation Commerciale

Le relais doit distinguer les codes commerciaux générés par login dans l’assistant des codes manuels/admin.

Évolution DB :

- ajouter `auto_confirm INTEGER NOT NULL DEFAULT 0` à `enrollment_codes` ;
- ajouter `source TEXT NOT NULL DEFAULT 'manual'`, avec valeur `commercial_onboarding` pour `/enroll/provision`.

Règles :

- `POST /enroll/provision` valide email/mot de passe, entitlement, puis crée un code avec `auto_confirm=1` et `source='commercial_onboarding'`.
- `POST /admin/codes` garde `auto_confirm=0` par défaut.
- `POST /enroll` crée le device en `active` avec `confirmed_at=ts` si le code consommé a `auto_confirm=1`.
- Les codes manuels restent en `pending` dans cette reprise.
- Un événement d’audit `auto_confirmed` ou un payload `auto_confirm=true` est enregistré.

### 7. UX Non Geek

Textes interdits dans l’interface client : `relay.json`, `WireGuard`, `MQTT`, `systemd`, `pending`, `enrollment`, `sudo`.

Textes attendus :

- “Connectez l’écran au WiFi du lieu.”
- “Liez cet écran à votre compte Zaforge.”
- “L’écran continue la configuration.”
- “Votre écran est visible dans Zaforge.”
- “Continuez dans app.zaforge.com.”
- “La connexion prend plus de temps que prévu. Ouvrez la console ou contactez le support avec ce code écran.”

L’écran Pi et le téléphone doivent toujours proposer une prochaine action visible.

### 8. Tests et Vérifications

Tests automatisés attendus :

- `bash -n install.sh`
- `sh -n scripts/firstboot.sh scripts/onboard-ap.sh scripts/bake-strip.sh scripts/relay-link.sh`
- tests PHP existants `web/api/tests/wifi-lib.test.php`
- test shell `scripts/tests/wifi-apply.test.sh`
- nouveaux tests relay :
  - `/enroll/provision` génère un code `auto_confirm=1` sous le tenant du compte ;
  - mauvais login retourne 401 sans créer de code ;
  - tenant non entitled retourne 402 ;
  - `/enroll` avec code auto-confirm crée un device `active` ;
  - `/enroll` avec code admin standard crée un device `pending`.
- tests setup :
  - image `free` ne lève pas l’AP commercial ;
  - image `commercial` lève l’AP si pas `.onboarded` ;
  - `/api/setup.php` ne retourne pas de secret dans `status` ;
  - phase `link_started` est écrite avant coupure AP.

Vérifications physiques obligatoires :

- flash image commerciale ;
- écran affiche QR ;
- scan téléphone ;
- mauvais mot de passe WiFi : AP revient et message clair ;
- bon WiFi + bon compte : téléphone reçoit “liaison lancée”, écran passe à “visible cloud”, console montre la box active/pilotable ;
- reboot après onboarding : pas de retour setup ;
- flash image gratuite : pas de QR commercial obligatoire.

## Plan de Reprise Recommandé

1. Stabiliser le dirty worktree : commit séparé des durcissements C2 (`timeout hostnamectl`, `nmcli -w 20`) après vérification.
2. Finir C1 `BUILD_MODE` dans `install.sh`.
3. Ajouter `scripts/build-image.sh` et l’environnement Docker/sdm.
4. Introduire l’édition d’image `free|commercial`.
5. Adapter `firstboot.sh` pour ne lever l’AP commercial que dans l’image commerciale.
6. Revoir l’API setup pour ne plus dépendre d’une réponse finale après coupure AP.
7. Ajouter `scripts/commercial-onboard.sh` comme orchestrateur root à secrets via STDIN.
8. Ajouter `setup-state.json` et l’écran de succès/handoff.
9. Ajouter `relay/status.json` côté agent.
10. Ajouter auto-confirmation commerciale côté relais.
11. Ajouter les tests relay/setup/image.
12. Vérifier ce qui est possible en local/sandbox.
13. Déployer uniquement les changements sûrs sur `.92` ; garder AP réel, flash et re-link réel pour test physique.

## Hors Scope de Cette Reprise

- Création de compte Zaforge depuis l’assistant.
- Lien magique sans mot de passe.
- WiFi entreprise/EAP.
- Provisioning usine multi-cartes.
- OTA d’image complète.
- Refonte visuelle complète de `app.zaforge.com`.
