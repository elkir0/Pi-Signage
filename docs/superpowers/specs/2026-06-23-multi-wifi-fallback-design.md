# Multi-WiFi fallback — conception (sous-projet A)

> Statut : validé par le proprio le 2026-06-23 (« je valide le plan »). Implémentation autorisée en autonomie.
> Partie A d'un ensemble de 3 : **A · Multi-WiFi** (ce doc) → B · Onboarding 1er démarrage → C · Image flashable.

## Objectif

Permettre de configurer **jusqu'à 3 réseaux WiFi avec un ordre de préférence** sur la box. La box se
connecte automatiquement au réseau disponible le **plus prioritaire** et **rebascule** vers un réseau
plus prioritaire dès qu'il redevient disponible (ex. retour du WiFi principal après coupure).

Comportement validé : **« revenir au plus prioritaire »** (vraie priorité, pas « rester collé »). La
courte reconnexion au retour du principal est absorbée par le cache hors-ligne du player.

## Contexte technique vérifié sur la box (192.168.1.92, 2026-06-23)

- La box est connectée **en WiFi** (`wlan0` = 192.168.1.92). `eth0` est DOWN (pas de câble). Le tunnel
  `zf0` (WireGuard relais) roule **par-dessus** le WiFi → si le WiFi tombe, le relais tombe aussi.
- **NetworkManager gère wlan0** (`systemctl is-active NetworkManager` = active ; nmcli présent). Le
  fichier `/etc/wpa_supplicant/wpa_supplicant.conf` est **absent**.
- Conséquence majeure : **le code WiFi actuel** (`web/api/config.php` → écrit `wpa_supplicant.conf` +
  `wpa_cli reconfigure`) **n'a aucun effet** sur cette box. Il est mort. De plus, les grants sudo
  correspondants n'existent plus (blanket retiré). Ce sous-projet **corrige ce bug latent**.
- Réseau actuel : SSID `shathony`, profil NM `netplan-wlan0-shathony`, `autoconnect-priority=0`.
  Profils NM stockés en `/etc/NetworkManager/system-connections/*.nmconnection` (root 0600) + intégration
  netplan (`/etc/netplan/90-NM-<uuid>.yaml`) → **les profils créés via nmcli persistent au reboot**.

## Décision d'architecture : NetworkManager / nmcli (et non wpa_supplicant)

Le mécanisme de fallback = le champ **`connection.autoconnect-priority`** de NetworkManager (plus haut =
préféré). NM choisit nativement le réseau autoconnect disponible de plus haute priorité, et rebascule
quand un meilleur réapparaît. C'est exactement le comportement demandé, sans daemon custom.

Avantages vs wpa_supplicant : rebascule native, **secrets (PSK) jamais exposés à www-data** (gérés par
NM en fichiers root 0600), persistance reboot via l'intégration netplan-NM.

## Composants

### 1. `scripts/wifi-apply.sh` (nouveau helper root)

Invariant de sécurité : **root:root 0755** (comme `audio-output.sh`) — sinon la grant sudo deviendrait
une escalade vers root. Généré/déployé par `install.sh` *après* le déploiement web.

Deux invocations (sudoers à arguments fixes) :

- **`wifi-apply.sh apply`** — lit sur **stdin** une ligne par slot rempli, dans l'ordre de priorité :
  ```
  <priority>\t<ssid>\t<mode>\t<secret>
  ```
  - `priority` : entier (30 pour slot 1, 20 pour slot 2, 10 pour slot 3).
  - `ssid` : 1–32 caractères, sans caractères de contrôle ni `"` `\` (revalidé indépendamment de PHP).
  - `mode` : `new` (un mot de passe est fourni dans `secret`) ou `keep` (psk inchangé).
  - `secret` : la passphrase (8–63) si `new`, vide si `keep`.

  Le passage par **stdin** évite toute fuite du PSK via `argv`/`ps`.

  Logique (**reconstruction depuis un snapshot** — robuste au réordonnancement) :
  1. Lire + **valider chaque champ** (rejet → exit ≠ 0, **rien n'est modifié**).
  2. **Snapshot psk par SSID** : scanner tous les profils `802-11-wireless` existants (les `zf-wifi-*`
     **et** les étrangers comme `netplan-wlan0-shathony`) ; pour chacun, relever
     `802-11-wireless.ssid` + `nmcli -s -g 802-11-wireless-security.psk` (root) → map `psk[ssid]`.
  3. Résoudre le psk de chaque slot rempli : `mode=new` → la passphrase fournie ; `mode=keep` →
     `psk[ssid]` du snapshot (si absent → erreur « pas de mot de passe mémorisé pour &lt;ssid&gt; »,
     rien n'est modifié). La résolution se fait **par SSID**, pas par numéro de slot → un
     réordonnancement (ex. déplacer `shathony` du slot 1 au slot 2) conserve son psk correctement.
  4. (Re)construire les profils NM `zf-wifi-<n>` (n = numéro de slot dans le nouvel ordre) :
     `nmcli con add/modify` type wifi, `interface-name=wlan0`, `802-11-wireless.ssid`,
     `wifi-sec.key-mgmt=wpa-psk`, `wifi-sec.psk` (← psk résolu), `connection.autoconnect=yes`,
     `connection.autoconnect-priority=<priority>` (30/20/10). **Supprimer** les `zf-wifi-<n>` des slots
     devenus vides.
  5. **Désactiver l'autoconnect** des profils WiFi *étrangers* (802-11-wireless dont le nom ≠
     `zf-wifi-[123]`) pour qu'ils ne concurrencent pas nos profils (de toute façon nos priorités 30/20/10
     dominent le `0` du profil netplan). **Ne jamais** toucher `zf0` (wireguard), `eth0`, `lo`, ni les
     profils non-WiFi (`Wired connection 1`).
  6. Connecter **immédiatement** au meilleur réseau **actuellement visible** : scanner
     (`nmcli -f ssid dev wifi list`), prendre le `zf-wifi-<n>` de plus haute priorité dont le SSID est
     visible, `nmcli con up` celui-là. **Sans jamais forcer la déconnexion** d'un lien qui fonctionne
     (si le réseau connecté est déjà le meilleur visible, no-op). Si aucun n'est visible, laisser NM
     autoconnecter.
  7. Écrire le JSON assaini (voir plus bas).
  - **Atomicité / rollback** : si une étape critique échoue, **ré-activer l'autoconnect du profil
    d'origine** (snapshot pris en 2) pour ne jamais rester déconnecté.

- **`wifi-apply.sh sync`** — pas de stdin. Régénère **uniquement** `config/wifi-networks.json` à partir
  des profils NM WiFi connus (les `zf-wifi-*` + le profil actif s'il est étranger, pour pré-remplir le
  slot 1 à la première ouverture). Idempotent. Appelé par `install.sh` (migration) et au besoin.

### 2. `config/wifi-networks.json` (état assaini, source de vérité de l'UI)

`root:root 0644` (aucun secret → lisible par www-data). Forme :
```json
{ "networks": [ {"slot":1,"ssid":"shathony","has_password":true}, ... ] }
```
`has_password` = le profil a une sécurité WPA (déduit, non secret). Pas de réseaux ouverts en v1.

### 3. `web/api/config.php` (étendu)

- **`GET ?action=wifi`** → `{ networks:[{slot,ssid,has_password}], connected_ssid }`.
  Lit `wifi-networks.json` + SSID actif via `nmcli -t -f active,ssid dev wifi` (ou `GENERAL.CONNECTION`).
- **`POST {type:'wifi', networks:[{slot,ssid,psk?}]}`** :
  - Valider chaque slot : `ssid` 1–32 sans contrôle/`"`/`\` ; `psk` si présent 8–63 sans contrôle/`"`/`\`.
  - Déterminer le mode par slot : `psk` non vide → `new` ; sinon si `ssid` vide → slot omis ; sinon si
    `ssid` correspond à **un** réseau déjà configuré **avec** `has_password` (recherche par SSID sur tout
    `wifi-networks.json`, **pas** par numéro de slot — robuste au réordonnancement) → `keep` ; sinon
    (SSID nouveau/changé sans psk) → erreur « mot de passe requis pour &lt;ssid&gt; ».
  - Refuser les **doublons de SSID** entre slots.
  - Construire le payload stdin (priority = 30/20/10 selon l'ordre) et invoquer
    `sudo /opt/pisignage/scripts/wifi-apply.sh apply` via `proc_open` avec un **pipe stdin** (le PSK n'est
    jamais écrit sur disque ni passé en argv). Lire le code retour ; répondre succès/échec.
- L'ancien chemin `type=network` (ssid/password unique → wpa_supplicant) est **retiré** (mort). Le reste
  de `network` (hostname) est conservé tel quel.

### 4. `web/settings.php` + JS (`assets/js/init.js`, `assets/js/api.js`)

Remplacer la carte « Réseau Wi-Fi » mono-SSID par la carte **3 emplacements numérotés** :
- 3 lignes : badge ①/②/③, champ SSID, champ mot de passe (placeholder « ••• inchangé » si `has_password`,
  laisser vide = conserver), boutons ▲▼ pour réordonner (échange de slots).
- Badge **● connecté** sur le slot dont le SSID == `connected_ssid`.
- Bouton « Enregistrer & appliquer ».
- `api.js` : `config.getWifi()` (GET action=wifi) + `config.saveWifi(networks)` (POST type=wifi).
- `init.js` : `loadWifiConfig()` (au chargement de la page settings) + `saveWifiConfig()` (collecte les 3
  slots dans l'ordre, envoie, toast, recharge le badge). Supprimer `saveNetworkConfig` (ancien).

### 5. Sudoers (`install.sh` → `/etc/sudoers.d/pisignage`)

Ajouter (grants à arguments fixes, comme le reste) :
```
www-data ALL=(root) NOPASSWD: /opt/pisignage/scripts/wifi-apply.sh apply, /opt/pisignage/scripts/wifi-apply.sh sync
```
Aucune grant générique `nmcli`/`cp wpa_supplicant.conf`/`wpa_cli` (l'ancien code mort n'en avait pas non
plus). Bump `ASSET_VERSION` (cache-bust CSS/JS).

### 6. `install.sh`

- Déployer `scripts/wifi-apply.sh` (root:root 0755) + la grant sudoers.
- **Migration** : appeler `wifi-apply.sh sync` en fin d'install pour générer `wifi-networks.json` à partir
  du profil WiFi actif → le réseau courant apparaît en slot 1 dans l'UI.

## Flux

- **Charger** : settings → `GET action=wifi` → `wifi-networks.json` + SSID actif → 3 slots + badge.
- **Enregistrer** : formulaire → `POST type=wifi` → validation PHP → `wifi-apply.sh apply` (stdin) →
  profils NM `zf-wifi-*` + priorités → `nmcli con up` → `wifi-networks.json` mis à jour → refresh UI.

## Gestion d'erreurs & sûreté

- Validation **client + serveur (PHP) + helper (root)** — défense en profondeur ; le helper ne fait jamais
  confiance à PHP.
- **Pas d'auto-lock-out** : tant qu'au moins un des réseaux configurés est joignable, NM reste/devient
  connecté. Les SSID inexistants ne « volent » pas la connexion (NM ne peut pas s'y associer).
- **Rollback** du helper si une étape critique échoue (ré-activer l'autoconnect du profil d'origine).
- Limite assumée v1 : un mot de passe **syntaxiquement valide mais erroné** n'est pas détecté à
  l'enregistrement (NM tentera puis ce slot échouera ; les autres slots prennent le relais).
- Ne jamais toucher `zf0`/`eth0`/`lo`. Le helper ne gère que les profils `802-11-wireless` sur `wlan0`.

## Tests

1. **Helper (live sur la box, harnais sûr)** : slot1=`shathony` (réel, keep), slot2/slot3 = SSID bidons
   hors de portée. Vérifier : 2–3 profils `zf-wifi-*` créés, `autoconnect-priority` = 30/20/10,
   `shathony` toujours connecté (SSH non coupé), profils étrangers en autoconnect=no, `wifi-networks.json`
   correct, idempotence (re-apply = pas de doublon), entrées invalides rejetées (ssid avec `"`/newline,
   psk trop court) sans modifier la conf, réordonnancement (échange slot1/slot2) appliqué.
2. **API PHP** : `GET action=wifi` renvoie les bons slots + `connected_ssid` ; `POST` valide rejette
   doublons/psk court ; « keep » conserve le psk (réseau reste joignable).
3. **UI (Playwright)** : page Paramètres rend 3 slots, 0 erreur console, toast au save, badge ● sur le
   bon slot, deux thèmes OK.
4. **Persistance** : (optionnel, risqué) après reboot, les profils `zf-wifi-*` et priorités survivent.

## Hors scope de A (pour B/C ou plus tard)

Mode point d'accès / onboarding (sous-projet B), sélecteur de pays (`country`), réseaux ouverts (sans
psk), WiFi entreprise (EAP), ajout du WiFi au panneau de contrôle distant de la console (déjà couvert par
le « mode complet » qui proxifie toute l'UI LAN du Pi).
