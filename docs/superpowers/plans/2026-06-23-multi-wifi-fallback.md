# Multi-WiFi Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline) — implemented in this session under ultracode autonomy. Steps use checkbox (`- [ ]`).

**Goal:** Configurer jusqu'à 3 réseaux WiFi avec ordre de préférence sur la box, via NetworkManager (`autoconnect-priority`), avec rebascule native vers le plus prioritaire.

**Architecture:** Un helper root `wifi-apply.sh` possède 3 profils NM `zf-wifi-1/2/3` (priorités 30/20/10). PHP (`config.php` + `wifi-lib.php` pur/testable) valide et lui passe le payload par **stdin** (psk jamais en argv). Le helper écrit les **keyfiles** NM directement (psk jamais en argv non plus), désactive l'autoconnect des profils WiFi étrangers, connecte le meilleur réseau visible sans couper un lien qui marche, et publie un JSON assaini (sans secret) pour l'UI. UI = carte « 3 emplacements numérotés » dans Paramètres.

**Tech Stack:** sh (POSIX) + nmcli + NetworkManager keyfiles ; PHP 8.4 ; JS vanilla (PiSignage namespace) ; sudoers à arguments fixes.

---

## File Structure

- **Create** `web/api/wifi-lib.php` — fonctions PURES (validation + construction du payload stdin). Aucun effet de bord → testable en CLI.
- **Create** `web/api/tests/wifi-lib.test.php` — test unitaire PHP CLI de `wifi-lib.php`.
- **Create** `scripts/wifi-apply.sh` — helper root (`apply` lit stdin / `sync` régénère le JSON).
- **Create** `scripts/tests/wifi-apply.test.sh` — test d'intégration LIVE sur la box (harnais sûr).
- **Modify** `web/api/config.php` — inclut `wifi-lib.php` ; ajoute `GET ?action=wifi` + `POST type=wifi` ; retire l'écriture wpa_supplicant morte.
- **Modify** `web/settings.php` — remplace la carte WiFi mono-SSID par la carte 3 emplacements.
- **Modify** `web/assets/js/api.js` — `config.getWifi()` / `config.saveWifi()`.
- **Modify** `web/assets/js/init.js` — `loadWifiConfig()` / `saveWifiConfig()` ; retire `saveNetworkConfig`.
- **Modify** `web/includes/auth.php` — bump `ASSET_VERSION` (cache-bust).
- **Modify** `install.sh` — déploie `wifi-apply.sh` (root:root 0755), grant sudoers, appel `sync` (migration).

State files (runtime, sur la box) : `/opt/pisignage/config/wifi-networks.json` (root:root 0644, sans secret) ; profils NM `zf-wifi-1/2/3` + keyfiles `/etc/NetworkManager/system-connections/zf-wifi-*.nmconnection` (0600).

**Contrat payload stdin (`apply`)** : 1 ligne par slot rempli, ordre = priorité décroissante, champs TAB-séparés :
`<priority>\t<ssid>\t<mode>\t<secret>` — `priority`∈{30,20,10}, `mode`∈{new,keep}, `secret`=passphrase si new sinon vide.

---

## Task 1 : `wifi-lib.php` (validation + payload, PUR) + test PHP

**Files:** Create `web/api/wifi-lib.php`, `web/api/tests/wifi-lib.test.php`

- [ ] **Step 1 — Écrire le test (rouge)** `web/api/tests/wifi-lib.test.php`

```php
<?php
require __DIR__ . '/../wifi-lib.php';

$fail = 0;
function check($label, $cond) { global $fail; if ($cond) { echo "ok   - $label\n"; } else { echo "FAIL - $label\n"; $fail++; } }

// Helpers existants assainis (slot, ssid, has_password)
$existing = [['slot'=>1,'ssid'=>'shathony','has_password'=>true]];

// 1) Nouveau réseau valide → mode new, priorité 30
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>'motdepasse1']], []);
check('new valide ok', $r['ok'] === true);
check('new ligne', ($r['lines'][0] ?? '') === "30\tCafe\tnew\tmotdepasse1");

// 2) keep : ssid existant avec mot de passe, psk vide → mode keep
$r = wifiValidateAndBuild([['ssid'=>'shathony','psk'=>'']], $existing);
check('keep ok', $r['ok'] === true && ($r['lines'][0] ?? '') === "30\tshathony\tkeep\t");

// 3) keep robuste au réordonnancement : shathony en 2e position
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>'motdepasse1'],['ssid'=>'shathony','psk'=>'']], $existing);
check('keep reorder', $r['ok'] && $r['lines'][1] === "20\tshathony\tkeep\t");

// 4) SSID nouveau sans mot de passe → erreur
$r = wifiValidateAndBuild([['ssid'=>'Inconnu','psk'=>'']], $existing);
check('new sans psk -> erreur', $r['ok'] === false);

// 5) psk trop court → erreur
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>'court']], []);
check('psk court -> erreur', $r['ok'] === false);

// 6) ssid avec guillemet (injection) → erreur
$r = wifiValidateAndBuild([['ssid'=>'a"b','psk'=>'motdepasse1']], []);
check('ssid guillemet -> erreur', $r['ok'] === false);

// 7) ssid avec saut de ligne (injection payload) → erreur
$r = wifiValidateAndBuild([['ssid'=>"a\nb",'psk'=>'motdepasse1']], []);
check('ssid newline -> erreur', $r['ok'] === false);

// 8) psk avec espace en tête → erreur (casse le keyfile NM)
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>' leadingspace']], []);
check('psk espace en tete -> erreur', $r['ok'] === false);

// 9) doublon de ssid → erreur
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>'motdepasse1'],['ssid'=>'Cafe','psk'=>'motdepasse2']], []);
check('doublon ssid -> erreur', $r['ok'] === false);

// 10) slot vide ignoré
$r = wifiValidateAndBuild([['ssid'=>'Cafe','psk'=>'motdepasse1'],['ssid'=>'','psk'=>'']], []);
check('slot vide ignore', $r['ok'] && count($r['lines']) === 1);

// 11) plus de 3 → erreur
$r = wifiValidateAndBuild([
  ['ssid'=>'A','psk'=>'motdepasse1'],['ssid'=>'B','psk'=>'motdepasse2'],
  ['ssid'=>'C','psk'=>'motdepasse3'],['ssid'=>'D','psk'=>'motdepasse4']], []);
check('max 3 -> erreur', $r['ok'] === false);

// 12) aucun réseau → erreur
$r = wifiValidateAndBuild([], []);
check('aucun -> erreur', $r['ok'] === false);

echo $fail === 0 ? "\nTOUS OK\n" : "\n$fail ECHEC(S)\n";
exit($fail === 0 ? 0 : 1);
```

- [ ] **Step 2 — Lancer (échec attendu)** : `php web/api/tests/wifi-lib.test.php` → FAIL (`wifiValidateAndBuild` indéfinie).

- [ ] **Step 3 — Implémenter** `web/api/wifi-lib.php`

```php
<?php
/**
 * PiSignage/Zaforge — Multi-WiFi : fonctions PURES (aucun effet de bord).
 * Validation des réseaux + construction du payload stdin pour wifi-apply.sh.
 * Inclus par api/config.php ; testé par api/tests/wifi-lib.test.php.
 */

/** SSID : 1-32 octets, aucun caractère de contrôle, ni " ni \ */
function wifiValidSsid($s) {
    return is_string($s) && strlen($s) >= 1 && strlen($s) <= 32
        && !preg_match('/[\x00-\x1f\x7f"\\\\]/', $s);
}

/** PSK : 8-63 caractères, aucun contrôle, ni " ni \, ni espace en tête/fin (casse le keyfile NM). */
function wifiValidPsk($s) {
    return is_string($s) && strlen($s) >= 8 && strlen($s) <= 63
        && !preg_match('/[\x00-\x1f\x7f"\\\\]/', $s)
        && $s === trim($s);
}

/**
 * Valide la liste ordonnée de réseaux et construit les lignes stdin.
 * @param array $networks  [{ssid, psk}], index 0 = plus prioritaire.
 * @param array $existing  [{slot,ssid,has_password}] (wifi-networks.json assaini).
 * @return array ['ok'=>bool, 'error'=>?string, 'lines'=>string[]]
 */
function wifiValidateAndBuild($networks, $existing) {
    if (!is_array($networks)) return ['ok'=>false, 'error'=>'networks invalide', 'lines'=>[]];

    // Ensemble des SSID déjà configurés AVEC mot de passe (pour le mode keep, par SSID).
    $known = [];
    foreach ((is_array($existing) ? $existing : []) as $e) {
        if (!empty($e['ssid']) && !empty($e['has_password'])) $known[$e['ssid']] = true;
    }

    $priorities = [30, 20, 10];
    $lines = [];
    $seen = [];
    $idx = 0;
    foreach ($networks as $n) {
        $ssid = isset($n['ssid']) ? (string)$n['ssid'] : '';
        $psk  = isset($n['psk'])  ? (string)$n['psk']  : '';
        if ($ssid === '') continue;                       // slot vide → ignoré
        if (!wifiValidSsid($ssid)) return ['ok'=>false, 'error'=>"SSID invalide : ".$ssid, 'lines'=>[]];
        if (isset($seen[$ssid])) return ['ok'=>false, 'error'=>"SSID en doublon : ".$ssid, 'lines'=>[]];
        $seen[$ssid] = true;

        if ($idx >= 3) return ['ok'=>false, 'error'=>'Maximum 3 réseaux', 'lines'=>[]];
        $priority = $priorities[$idx];
        $idx++;

        if ($psk !== '') {
            if (!wifiValidPsk($psk)) return ['ok'=>false, 'error'=>"Mot de passe invalide pour ".$ssid, 'lines'=>[]];
            $lines[] = $priority . "\t" . $ssid . "\tnew\t" . $psk;
        } elseif (isset($known[$ssid])) {
            $lines[] = $priority . "\t" . $ssid . "\tkeep\t";
        } else {
            return ['ok'=>false, 'error'=>"Mot de passe requis pour ".$ssid, 'lines'=>[]];
        }
    }

    if (count($lines) === 0) return ['ok'=>false, 'error'=>'Au moins un réseau requis', 'lines'=>[]];
    return ['ok'=>true, 'error'=>null, 'lines'=>$lines];
}
```

- [ ] **Step 4 — Lancer (vert)** : `php web/api/tests/wifi-lib.test.php` → `TOUS OK`.

- [ ] **Step 5 — Commit** : `git add web/api/wifi-lib.php web/api/tests/wifi-lib.test.php && git commit -m "feat(wifi): pure validation/payload lib + tests (sous-projet A)"`

---

## Task 2 : Câbler `config.php` (GET action=wifi, POST type=wifi)

**Files:** Modify `web/api/config.php`

- [ ] **Step 1 — Inclure la lib** (après `require_once '../config.php';`)

```php
require_once __DIR__ . '/wifi-lib.php';

const WIFI_STATE_JSON = '/opt/pisignage/config/wifi-networks.json';
const WIFI_APPLY = '/opt/pisignage/scripts/wifi-apply.sh';
```

- [ ] **Step 2 — GET : ajouter le case `wifi`** dans `handleGetConfig()` (à côté de `network`)

```php
        case 'wifi':
            jsonResponse(true, getWifiConfig(), 'WiFi configuration retrieved');
            break;
```

- [ ] **Step 3 — POST : ajouter le case `wifi`** dans `handleUpdateConfig()` (à côté de `network`)

```php
        case 'wifi':
            updateWifiConfig($input);
            break;
```

- [ ] **Step 4 — Implémenter les deux fonctions** (ajouter en fin de fichier, avant `getLocalIP()`)

```php
function readWifiState() {
    if (!is_readable(WIFI_STATE_JSON)) return [];
    $j = json_decode((string)@file_get_contents(WIFI_STATE_JSON), true);
    return (is_array($j) && isset($j['networks']) && is_array($j['networks'])) ? $j['networks'] : [];
}

function getWifiConfig() {
    $networks = readWifiState();
    // SSID actuellement connecté (NetworkManager).
    $connected = '';
    $r = executeCommand(['/usr/bin/nmcli', '-t', '-f', 'active,ssid', 'dev', 'wifi']);
    if ($r['success']) {
        foreach ($r['output'] as $line) {
            if (strpos($line, 'yes:') === 0) { $connected = substr($line, 4); break; }
        }
    }
    return ['networks' => $networks, 'connected_ssid' => $connected];
}

function updateWifiConfig($input) {
    $networks = $input['networks'] ?? null;
    if (!is_array($networks)) jsonResponse(false, null, 'networks requis');

    $built = wifiValidateAndBuild($networks, readWifiState());
    if (!$built['ok']) jsonResponse(false, null, $built['error']);

    $payload = implode("\n", $built['lines']) . "\n";

    // Invoquer le helper root via sudo, payload sur STDIN (le PSK ne touche jamais argv/disque).
    $descriptors = [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $proc = @proc_open(['sudo', WIFI_APPLY, 'apply'], $descriptors, $pipes, null, null);
    if (!is_resource($proc)) jsonResponse(false, null, 'Échec lancement wifi-apply');
    fwrite($pipes[0], $payload); fclose($pipes[0]);
    $out = stream_get_contents($pipes[1]); fclose($pipes[1]);
    $err = stream_get_contents($pipes[2]); fclose($pipes[2]);
    $rc = proc_close($proc);

    if ($rc !== 0) {
        logMessage("WiFi apply échec rc=$rc: " . trim($err));
        jsonResponse(false, null, 'Échec application WiFi : ' . trim($err));
    }
    logMessage("WiFi mis à jour (" . count($built['lines']) . " réseau(x))");
    jsonResponse(true, getWifiConfig(), 'Configuration WiFi appliquée');
}
```

- [ ] **Step 5 — Retirer le code mort** : dans `updateNetworkConfig()`, supprimer tout le bloc `if (isset($input['ssid']) && isset($input['password'])) { ... }` (écriture wpa_supplicant + `wpa_cli reconfigure`). Garder le bloc `hostname`. (L'UI ne l'appelle plus.)

- [ ] **Step 6 — Vérifier la syntaxe** : `php -l web/api/config.php` → `No syntax errors`.

- [ ] **Step 7 — Commit** : `git add web/api/config.php && git commit -m "feat(wifi): config.php GET action=wifi + POST type=wifi (stdin->helper), drop dead wpa_supplicant"`

---

## Task 3 : Helper root `scripts/wifi-apply.sh`

**Files:** Create `scripts/wifi-apply.sh`

- [ ] **Step 1 — Écrire le helper** (contenu complet ci-dessous)

```sh
#!/bin/sh
# PiSignage/Zaforge — Multi-WiFi fallback via NetworkManager.
# INVARIANT SÉCURITÉ : ce script DOIT rester root:root 0755 (sinon la grant sudo www-data
# deviendrait une escalade vers root). Appelé par www-data via sudo (sudoers à args fixes) :
#   printf '%s' "<payload>" | sudo /opt/pisignage/scripts/wifi-apply.sh apply
#   sudo /opt/pisignage/scripts/wifi-apply.sh sync
#
# 'apply' : lit STDIN, 1 ligne/slot (ordre = priorité), TAB-séparée :
#   <priority>\t<ssid>\t<mode>\t<secret>   (priority 30|20|10 ; mode new|keep)
# Le PSK ne transite QUE par stdin et n'est écrit QUE dans les keyfiles NM root 0600
# (jamais en argv → pas de fuite via ps/proc).
set -eu

IFACE="wlan0"
NMCLI="/usr/bin/nmcli"
NMDIR="/etc/NetworkManager/system-connections"
STATE_JSON="/opt/pisignage/config/wifi-networks.json"
TMPS=""

cleanup() { for f in $TMPS; do rm -f "$f" 2>/dev/null || true; done; }
trap cleanup EXIT INT TERM
mktmp() { f="$(mktemp /tmp/wifi.XXXXXX)"; TMPS="$TMPS $f"; echo "$f"; }

log() { echo "wifi-apply: $*" >&2; }
die() { log "ERREUR: $*"; exit 1; }

b64()   { printf '%s' "$1" | base64 | tr -d '\n'; }
unb64() { printf '%s' "$1" | base64 -d 2>/dev/null || true; }

valid_ssid()     { printf '%s' "$1" | LC_ALL=C grep -Eq '^[^"\\]{1,32}$' && ! printf '%s' "$1" | LC_ALL=C grep -q '[[:cntrl:]]'; }
valid_psk()      { printf '%s' "$1" | LC_ALL=C grep -Eq '^[^"\\]{8,63}$' && ! printf '%s' "$1" | LC_ALL=C grep -q '[[:cntrl:]]'; }
valid_priority() { case "$1" in 10|20|30) return 0 ;; *) return 1 ;; esac; }

# UUIDs des profils de type wifi (UUID = 1er champ, sans ':' → terse sûr).
wifi_uuids() { "$NMCLI" -t -f UUID,TYPE con show 2>/dev/null | awk -F: '$2=="802-11-wireless"{print $1}'; }
con_get()   { "$NMCLI" -s -g "$1" con show "$2" 2>/dev/null || true; }

# Snapshot ssid(b64)->psk(b64) de TOUS les profils wifi ; + UUIDs étrangers.
SNAP=""; FOREIGN=""
build_snapshot() {
    SNAP="$(mktmp)"; FOREIGN="$(mktmp)"; : > "$SNAP"; : > "$FOREIGN"
    for u in $(wifi_uuids); do
        id="$(con_get connection.id "$u")"
        ssid="$(con_get 802-11-wireless.ssid "$u")"
        [ -n "$ssid" ] || continue
        psk="$(con_get 802-11-wireless-security.psk "$u")"
        printf '%s %s\n' "$(b64 "$ssid")" "$(b64 "$psk")" >> "$SNAP"
        case "$id" in zf-wifi-1|zf-wifi-2|zf-wifi-3) : ;; *) printf '%s\n' "$u" >> "$FOREIGN" ;; esac
    done
}
lookup_psk() { line="$(awk -v w="$(b64 "$1")" '$1==w{print $2; exit}' "$SNAP")"; [ -n "$line" ] && unb64 "$line" || true; }

# ssid -> "104;101;...;" (forme tableau d'octets : aucun échappement GKeyFile à gérer).
ssid_bytes() { printf '%s' "$1" | od -An -tu1 | tr -s ' \n' '\n\n' | sed '/^$/d' | while read -r b; do printf '%s;' "$b"; done; }

json_str() { printf '"%s"' "$1"; }  # ssid déjà validé sans "/\/ctrl → sûr en JSON

write_keyfile() { # slot priority ssid psk
    slot="$1"; priority="$2"; ssid="$3"; psk="$4"
    name="zf-wifi-$slot"; file="$NMDIR/$name.nmconnection"
    uuid=""; [ -f "$file" ] && uuid="$(awk -F= '/^uuid=/{print $2; exit}' "$file" 2>/dev/null || true)"
    [ -n "$uuid" ] || uuid="$(cat /proc/sys/kernel/random/uuid)"
    tmp="$(mktmp)"
    {
        printf '[connection]\nid=%s\nuuid=%s\ntype=wifi\ninterface-name=%s\nautoconnect=true\nautoconnect-priority=%s\n' "$name" "$uuid" "$IFACE" "$priority"
        printf '\n[wifi]\nmode=infrastructure\nssid=%s\n' "$(ssid_bytes "$ssid")"
        printf '\n[wifi-security]\nkey-mgmt=wpa-psk\npsk=%s\n' "$psk"
        printf '\n[ipv4]\nmethod=auto\n\n[ipv6]\nmethod=auto\n'
    } > "$tmp"
    chmod 0600 "$tmp"; chown root:root "$tmp"; mv -f "$tmp" "$file"
}

cmd_apply() {
    build_snapshot
    PLAN="$(mktmp)"; : > "$PLAN"
    slot=0; seen=""
    # Lire + valider TOUT avant de modifier (rejet => rien n'est touché).
    while IFS="$(printf '\t')" read -r priority ssid mode secret || [ -n "${priority:-}" ]; do
        [ -n "${priority:-}" ] || continue
        slot=$((slot+1)); [ "$slot" -le 3 ] || die "trop de slots"
        valid_priority "$priority" || die "priorite invalide"
        valid_ssid "$ssid" || die "ssid invalide"
        key="$(b64 "$ssid")"; case " $seen " in *" $key "*) die "ssid doublon" ;; esac; seen="$seen $key"
        case "$mode" in
            new)  valid_psk "$secret" || die "mot de passe invalide"; psk="$secret" ;;
            keep) psk="$(lookup_psk "$ssid")"; [ -n "$psk" ] || die "pas de mot de passe memorise pour ce reseau" ;;
            *)    die "mode invalide" ;;
        esac
        printf '%s\t%s\t%s\t%s\n' "$slot" "$priority" "$(b64 "$ssid")" "$(b64 "$psk")" >> "$PLAN"
    done
    [ -s "$PLAN" ] || die "aucun reseau"

    # (Re)construire nos profils + supprimer les slots devenus vides.
    used=""
    while IFS="$(printf '\t')" read -r slot priority ssidb pskb; do
        write_keyfile "$slot" "$priority" "$(unb64 "$ssidb")" "$(unb64 "$pskb")"
        used="$used $slot"
    done < "$PLAN"
    for s in 1 2 3; do
        case " $used " in *" $s "*) : ;; *) rm -f "$NMDIR/zf-wifi-$s.nmconnection" 2>/dev/null || true ;; esac
    done

    "$NMCLI" con reload >/dev/null 2>&1 || true

    # Désactiver l'autoconnect des profils WiFi étrangers (ne JAMAIS toucher zf0/eth0/lo).
    while read -r u; do [ -n "$u" ] && "$NMCLI" con modify "$u" connection.autoconnect no >/dev/null 2>&1 || true; done < "$FOREIGN"

    # Connecter le meilleur réseau VISIBLE, sans couper un lien déjà optimal.
    "$NMCLI" -t -f ssid dev wifi list --rescan yes >/dev/null 2>&1 || true
    visible="$("$NMCLI" -t -f SSID dev wifi list 2>/dev/null || true)"
    active="$("$NMCLI" -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print substr($0,5); exit}')"
    best=""; best_ssid=""
    while IFS="$(printf '\t')" read -r slot priority ssidb pskb; do
        s="$(unb64 "$ssidb")"
        if printf '%s\n' "$visible" | grep -Fxq "$s"; then best="zf-wifi-$slot"; best_ssid="$s"; break; fi
    done < "$PLAN"
    if [ -n "$best" ] && [ "$best_ssid" != "$active" ]; then
        "$NMCLI" con up "$best" >/dev/null 2>&1 || true
    fi

    write_state_from_plan "$PLAN"
    log "applique ($(wc -l < "$PLAN") reseau(x))"
}

write_state_from_plan() { # PLAN
    tmp="$(mktmp)"
    {
        printf '{"networks":['
        first=1
        while IFS="$(printf '\t')" read -r slot priority ssidb pskb; do
            [ "$first" = 1 ] || printf ','; first=0
            printf '{"slot":%s,"ssid":%s,"has_password":true}' "$slot" "$(json_str "$(unb64 "$ssidb")")"
        done < "$1"
        printf ']}'
    } > "$tmp"
    chmod 0644 "$tmp"; chown root:root "$tmp"
    mkdir -p "$(dirname "$STATE_JSON")"; mv -f "$tmp" "$STATE_JSON"
}

cmd_sync() {
    build_snapshot
    PLAN="$(mktmp)"; : > "$PLAN"
    # Nos profils, triés par priorité décroissante.
    list="$(mktmp)"; : > "$list"
    for u in $(wifi_uuids); do
        id="$(con_get connection.id "$u")"
        case "$id" in zf-wifi-1|zf-wifi-2|zf-wifi-3)
            pr="$(con_get connection.autoconnect-priority "$u")"; [ -n "$pr" ] || pr=0
            ssid="$(con_get 802-11-wireless.ssid "$u")"
            printf '%s\t%s\n' "$pr" "$(b64 "$ssid")" >> "$list" ;;
        esac
    done
    if [ -s "$list" ]; then
        slot=0
        sort -t"$(printf '\t')" -k1,1 -rn "$list" | while IFS="$(printf '\t')" read -r pr ssidb; do
            slot=$((slot+1)); printf '%s\t30\t%s\t\n' "$slot" "$ssidb" >> "$PLAN"
        done
    else
        # Aucun profil zf-wifi-* : pré-remplir le slot 1 depuis le WiFi actif (migration).
        au="$("$NMCLI" -t -f UUID,TYPE,ACTIVE con show 2>/dev/null | awk -F: '$2=="802-11-wireless" && $3=="yes"{print $1; exit}')"
        if [ -n "${au:-}" ]; then
            ssid="$(con_get 802-11-wireless.ssid "$au")"
            [ -n "$ssid" ] && printf '1\t30\t%s\t\n' "$(b64 "$ssid")" >> "$PLAN"
        fi
    fi
    if [ -s "$PLAN" ]; then write_state_from_plan "$PLAN"; else printf '{"networks":[]}' > "$STATE_JSON"; chmod 0644 "$STATE_JSON"; fi
    log "sync ok"
}

case "${1:-}" in
    apply) cmd_apply ;;
    sync)  cmd_sync ;;
    *)     echo "usage: $0 apply|sync" >&2; exit 2 ;;
esac
```

- [ ] **Step 2 — Vérifier la syntaxe sh** : `sh -n scripts/wifi-apply.sh` → aucune erreur.

- [ ] **Step 3 — Commit** : `git add scripts/wifi-apply.sh && git commit -m "feat(wifi): root helper wifi-apply.sh (NM keyfiles, apply/sync)"`

---

## Task 4 : Frontend (carte 3 emplacements + JS)

**Files:** Modify `web/settings.php`, `web/assets/js/api.js`, `web/assets/js/init.js`, `web/includes/auth.php`

- [ ] **Step 1 — Remplacer la carte « Réseau Wi-Fi »** dans `web/settings.php` (le bloc `<!-- RESEAU -->`) par :

```php
            <!-- RESEAU -->
            <div class="card">
                <div class="card-head">
                    <h2 class="card-title"><?= icon('wifi') ?>Réseau Wi-Fi</h2>
                </div>
                <p style="color:var(--text-faint);font-size:13px;margin:0 0 12px">
                    Jusqu'à 3 réseaux par ordre de préférence. La box se connecte au plus prioritaire disponible.
                </p>
                <div id="wifi-slots"><!-- rempli par loadWifiConfig() --></div>
                <button class="btn btn-primary" type="button" onclick="saveWifiConfig()">
                    <?= icon('check') ?>Enregistrer &amp; appliquer
                </button>
            </div>
```

- [ ] **Step 2 — Ajouter les appels API** dans `web/assets/js/api.js` (dans `config: { ... }`, remplacer `saveNetwork`) :

```javascript
        getWifi: function() {
            return PiSignage.api.request('/api/config.php?action=wifi');
        },

        saveWifi: function(networks) {
            return PiSignage.api.request('/api/config.php', {
                method: 'POST',
                body: JSON.stringify({ type: 'wifi', networks: networks })
            });
        }
```

- [ ] **Step 3 — Réécrire le handler WiFi** dans `web/assets/js/init.js` : remplacer `window.saveNetworkConfig` par le rendu 3-slots + save :

```javascript
    function renderWifiSlots(networks, connected) {
        const host = document.getElementById('wifi-slots');
        if (!host) return;
        const bySlot = {};
        (networks || []).forEach(n => { bySlot[n.slot] = n; });
        let html = '';
        for (let i = 1; i <= 3; i++) {
            const n = bySlot[i] || {};
            const ssid = n.ssid || '';
            const has = !!n.has_password;
            const isConn = ssid && connected && ssid === connected;
            html += `
            <div class="wifi-slot" data-slot="${i}" style="display:flex;gap:8px;align-items:center;margin-bottom:10px;flex-wrap:wrap">
              <span class="wifi-badge" style="flex:none;width:24px;height:24px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-weight:600;background:${i===1?'var(--accent)':'var(--surface-2,#334155)'};color:#fff">${i}</span>
              <input type="text" class="form-control wifi-ssid" style="flex:2;min-width:140px" placeholder="SSID ${i===1?'(prioritaire)':'(secours)'}" value="${ssid.replace(/"/g,'&quot;')}">
              <input type="password" class="form-control wifi-psk" autocomplete="new-password" style="flex:1;min-width:120px" placeholder="${has?'••• inchangé':'Mot de passe'}">
              <span class="wifi-conn" style="flex:none;color:var(--accent);font-size:12px;font-weight:600;${isConn?'':'display:none'}">● connecté</span>
              <span style="flex:none;display:inline-flex;gap:4px">
                <button type="button" class="btn btn-secondary btn-sm" onclick="moveWifiSlot(${i},-1)" title="Monter">▲</button>
                <button type="button" class="btn btn-secondary btn-sm" onclick="moveWifiSlot(${i},1)" title="Descendre">▼</button>
              </span>
            </div>`;
        }
        host.innerHTML = html;
    }

    window.loadWifiConfig = async function () {
        try {
            const data = await PiSignage.api.config.getWifi();
            if (data.success && data.data) renderWifiSlots(data.data.networks, data.data.connected_ssid);
        } catch (e) { console.error(e); }
    };

    // Lit l'UI dans l'ordre 1..3 ; déplace une ligne ↑/↓ en réordonnant le DOM.
    window.moveWifiSlot = function (slot, dir) {
        const host = document.getElementById('wifi-slots');
        if (!host) return;
        const rows = Array.from(host.querySelectorAll('.wifi-slot'));
        const i = slot - 1, j = i + dir;
        if (j < 0 || j >= rows.length) return;
        // échange les valeurs (SSID + psk saisi) entre les deux lignes
        const a = rows[i], b = rows[j];
        const swap = sel => { const x = a.querySelector(sel), y = b.querySelector(sel); const t = x.value; x.value = y.value; y.value = t; };
        swap('.wifi-ssid'); swap('.wifi-psk');
        // échange aussi les placeholders psk (état "inchangé") et badge connecté
        const swapAttr = (sel, attr) => { const x = a.querySelector(sel), y = b.querySelector(sel); const t = x.getAttribute(attr); x.setAttribute(attr, y.getAttribute(attr)); y.setAttribute(attr, t); };
        swapAttr('.wifi-psk', 'placeholder');
        const ca = a.querySelector('.wifi-conn'), cb = b.querySelector('.wifi-conn');
        const td = ca.style.display; ca.style.display = cb.style.display; cb.style.display = td;
    };

    window.saveWifiConfig = async function () {
        const host = document.getElementById('wifi-slots');
        if (!host) return;
        const rows = Array.from(host.querySelectorAll('.wifi-slot'));
        const networks = rows.map(r => ({
            ssid: r.querySelector('.wifi-ssid').value.trim(),
            psk: r.querySelector('.wifi-psk').value
        })).filter(n => n.ssid !== '');
        if (networks.length === 0) { showAlert('Renseignez au moins un réseau', 'error'); return; }
        try {
            const data = await PiSignage.api.config.saveWifi(networks);
            showAlert(data.success ? 'WiFi appliqué' : ('Erreur : ' + data.message), data.success ? 'success' : 'error');
            if (data.success && data.data) renderWifiSlots(data.data.networks, data.data.connected_ssid);
        } catch (e) { console.error(e); showAlert('Erreur de sauvegarde', 'error'); }
    };
```

- [ ] **Step 4 — Charger au bon moment** : dans `init.js`, dans le dispatch par page (là où `setupSettingsHandlers()` est appelé pour `data-page="settings"`), appeler aussi `loadWifiConfig()`. Et **retirer** l'ancien `window.saveNetworkConfig`.

- [ ] **Step 5 — Bump cache** : dans `web/includes/auth.php`, incrémenter `ASSET_VERSION` (ex. `0.12.2` → `0.12.3`).

- [ ] **Step 6 — Commit** : `git add web/settings.php web/assets/js/api.js web/assets/js/init.js web/includes/auth.php && git commit -m "feat(wifi): UI 3 emplacements numérotés + reorder (settings)"`

---

## Task 5 : `install.sh` (déploiement helper + sudoers + migration)

**Files:** Modify `install.sh`

- [ ] **Step 1 — Grant sudoers** : dans le heredoc `SUDOERS` de `configure_sudo()`, ajouter avant la ligne `SUDOERS` :

```
# Multi-WiFi : helper root (écrit les keyfiles NM + nmcli). Arguments FIXES.
www-data ALL=(root) NOPASSWD: /opt/pisignage/scripts/wifi-apply.sh apply, /opt/pisignage/scripts/wifi-apply.sh sync
```

- [ ] **Step 2 — Forcer root:root 0755 sur le helper** : dans `configure_sudo()` (à côté de la génération de `audio-output.sh`/`grim-capture.sh`), garantir les droits du helper déployé depuis le dépôt :

```bash
    # Multi-WiFi : le helper est déployé depuis le dépôt (scripts/) ; on (re)pose l'invariant.
    if [ -f "$INSTALL_DIR/scripts/wifi-apply.sh" ]; then
        sudo chown root:root "$INSTALL_DIR/scripts/wifi-apply.sh"
        sudo chmod 0755 "$INSTALL_DIR/scripts/wifi-apply.sh"
    fi
```

- [ ] **Step 3 — Migration** : à la fin de `configure_sudo()` (après l'install des sudoers), générer l'état initial :

```bash
    # Migration multi-WiFi : publier l'état initial (réseau actif -> slot 1) pour l'UI.
    sudo "$INSTALL_DIR/scripts/wifi-apply.sh" sync 2>/dev/null || true
```

- [ ] **Step 4 — Commit** : `git add install.sh && git commit -m "feat(wifi): install.sh deploy helper + sudoers grant + sync migration"`

---

## Task 6 : Déploiement + vérification LIVE sur la box (.92) + revue adversariale

**Files:** Create `scripts/tests/wifi-apply.test.sh` (test d'intégration sûr)

- [ ] **Step 1 — Écrire le test d'intégration** `scripts/tests/wifi-apply.test.sh` (à exécuter SUR la box ; harnais sûr : garde le réseau réel en slot 1, 2 SSID bidons hors de portée) :

```sh
#!/bin/sh
# Test d'intégration LIVE de wifi-apply.sh — À LANCER SUR LA BOX, en root (sudo).
# SÛRETÉ : slot 1 = le SSID réel courant (keep) ; slots 2/3 = SSID inexistants
# (hors de portée → NM ne s'y associe jamais → aucune coupure SSH).
set -eu
H=/opt/pisignage/scripts/wifi-apply.sh
NM=/usr/bin/nmcli
fail=0
t() { if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; fail=$((fail+1)); fi; }

REAL_SSID="$("$NM" -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print substr($0,5);exit}')"
[ -n "$REAL_SSID" ] || { echo "pas de WiFi actif — abort"; exit 1; }
echo "SSID réel courant: $REAL_SSID"

# 1) apply avec slot1=keep(réel) + 2 bidons
printf '30\t%s\tkeep\t\n20\tZZ-bidon-A\tnew\tmotdepasse1\n10\tZZ-bidon-B\tnew\tmotdepasse2\n' "$REAL_SSID" | "$H" apply
t "3 profils zf-wifi crees" '[ "$($NM -t -f NAME con show | grep -c "^zf-wifi-")" -eq 3 ]'
t "slot1 priority 30" '[ "$($NM -g connection.autoconnect-priority con show zf-wifi-1)" = "30" ]'
t "slot2 priority 20" '[ "$($NM -g connection.autoconnect-priority con show zf-wifi-2)" = "20" ]'
t "toujours connecte au reel" '[ "$($NM -t -f active,ssid dev wifi | awk -F: "/^yes:/{print substr(\$0,5);exit}")" = "$REAL_SSID" ]'
t "json sans secret" '! grep -qi "psk\|password\|motdepasse" /opt/pisignage/config/wifi-networks.json'
t "json contient le reel" 'grep -q "$REAL_SSID" /opt/pisignage/config/wifi-networks.json'
t "keyfile slot2 0600" '[ "$(stat -c %a $NMDIR/zf-wifi-2.nmconnection 2>/dev/null || stat -c %a /etc/NetworkManager/system-connections/zf-wifi-2.nmconnection)" = "600" ]'

# 2) idempotence (re-apply identique) — pas de 4e profil, toujours connecté
printf '30\t%s\tkeep\t\n20\tZZ-bidon-A\tnew\tmotdepasse1\n10\tZZ-bidon-B\tnew\tmotdepasse2\n' "$REAL_SSID" | "$H" apply
t "idempotent: 3 profils" '[ "$($NM -t -f NAME con show | grep -c "^zf-wifi-")" -eq 3 ]'

# 3) réordonnancement : réel passe slot2, bidon slot1 — réel toujours joignable (bidon hors portée)
printf '30\tZZ-bidon-A\tnew\tmotdepasse1\n20\t%s\tkeep\t\n' "$REAL_SSID" | "$H" apply
t "reorder: reel toujours connecte" '[ "$($NM -t -f active,ssid dev wifi | awk -F: "/^yes:/{print substr(\$0,5);exit}")" = "$REAL_SSID" ]'
t "reorder: 2 profils" '[ "$($NM -t -f NAME con show | grep -c "^zf-wifi-")" -eq 2 ]'

# 4) injection rejetée (ssid avec guillemet) — rien ne doit changer
before="$($NM -t -f NAME con show | grep -c "^zf-wifi-")"
printf '30\ta"b\tnew\tmotdepasse1\n' | "$H" apply 2>/dev/null && echo "FAIL - injection acceptee" && fail=$((fail+1)) || echo "ok   - injection rejetee"
t "injection: profils inchanges" '[ "$($NM -t -f NAME con show | grep -c "^zf-wifi-")" -eq "$before" ]'

# 5) restaurer l'état nominal : réel en slot1 seul
printf '30\t%s\tkeep\t\n' "$REAL_SSID" | "$H" apply
t "restauration: connecte au reel" '[ "$($NM -t -f active,ssid dev wifi | awk -F: "/^yes:/{print substr(\$0,5);exit}")" = "$REAL_SSID" ]'

echo; [ "$fail" -eq 0 ] && echo "INTEGRATION OK" || echo "$fail ECHEC(S)"
exit "$fail"
```

- [ ] **Step 2 — Déployer sur la box** (via `~/`, jamais `/tmp` ; `sudo -S` avec mot de passe `palmer00`) :
  - `scripts/wifi-apply.sh` → `/opt/pisignage/scripts/` (root:root 0755)
  - `web/api/wifi-lib.php`, `web/api/config.php` → `/opt/pisignage/web/api/` (www-data)
  - `web/settings.php`, `web/assets/js/api.js`, `web/assets/js/init.js`, `web/includes/auth.php` → `/opt/pisignage/web/...`
  - Poser la grant sudoers `wifi-apply.sh apply|sync`.
  - `sudo systemctl reload php8.4-fpm` (flush OPcache).

- [ ] **Step 3 — Lancer le test d'intégration** sur la box : `sudo sh /opt/pisignage/scripts/tests/wifi-apply.test.sh` → `INTEGRATION OK`. **Vérifier que SSH ne tombe jamais.**

- [ ] **Step 4 — Test API** : `GET /api/config.php?action=wifi` (avec session) renvoie les slots + `connected_ssid` ; `php web/api/tests/wifi-lib.test.php` → TOUS OK.

- [ ] **Step 5 — Test UI Playwright** : page `settings.php` rend 3 slots, 0 erreur console, save montre un toast, badge ● sur le bon slot, thèmes clair/sombre OK.

- [ ] **Step 6 — Revue adversariale (workflow)** : multi-agents sur le helper root + PHP (injection SSID/PSK dans keyfile & payload, fuite PSK via argv/ps, lock-out/rollback, manipulation de priorité, profils étrangers/zf0, atomicité). Corriger les findings confirmées (refute par défaut, majorité).

- [ ] **Step 7 — Commit final + état** : commit du test d'intégration ; résumé au proprio.

---

## Self-Review

**Couverture spec :** moteur NM/nmcli ✓ (T3) · autoconnect-priority 30/20/10 ✓ (T3) · keep par SSID ✓ (T1/T3) · adoption profil étranger ✓ (T3 snapshot) · psk hors argv/disque ✓ (stdin + keyfiles, T2/T3) · JSON assaini ✓ (T3) · GET/POST ✓ (T2) · UI 3 slots + badge + reorder ✓ (T4) · sudoers fixe + invariant 0755 ✓ (T5) · migration sync ✓ (T5) · pas de lock-out / rollback ✓ (T3) · ne pas toucher zf0/eth0 ✓ (T3) · tests helper/API/UI ✓ (T1/T6) · retrait code mort ✓ (T2).

**Placeholders :** aucun — code complet dans chaque tâche.

**Cohérence des types :** `wifiValidateAndBuild($networks,$existing)→{ok,error,lines}` (T1) consommé tel quel en T2 ; contrat stdin `priority\tssid\tmode\tsecret` identique T2↔T3 ; `wifi-networks.json` = `{networks:[{slot,ssid,has_password}]}` écrit T3, lu T2, rendu T4 ; profils `zf-wifi-1/2/3` cohérents T3/T5/T6.
