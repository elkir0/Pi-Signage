<?php
/**
 * PiSignage/Zaforge — Multi-WiFi : fonctions PURES (aucun effet de bord).
 * Validation des réseaux + construction du payload stdin pour wifi-apply.sh.
 * Inclus par api/config.php ; testé par api/tests/wifi-lib.test.php.
 */

/** SSID : 1-32 octets, aucun caractère de contrôle, ni " ni \, et UTF-8 valide
 *  (un octet non-UTF-8 corromprait wifi-networks.json -> json_decode null -> liste vidée). */
function wifiValidSsid($s) {
    return is_string($s) && strlen($s) >= 1 && strlen($s) <= 32
        && !preg_match('/[\x00-\x1f\x7f"\\\\]/', $s)
        && mb_check_encoding($s, 'UTF-8');
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
