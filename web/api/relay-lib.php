<?php
/**
 * Zaforge — NOYAU LIAISON COMPTE (relais). Partagé par api/account.php (admin) et
 * api/setup.php (onboarding). AUCUNE sortie HTTP ici (réutilisable CLI/tests) :
 * pas de header(), pas de jsonResponse(), pas d'echo.
 *
 * Secrets : le code d'enrôlement passe TOUJOURS par STDIN (jamais argv → pas de
 * fuite ps) ; le mot de passe console part en TLS via cURL (jamais argv/log).
 */

if (!defined('RELAY_BASE'))      define('RELAY_BASE', 'https://relay.zaforge.com');
if (!defined('RELAY_LINK_SH'))   define('RELAY_LINK_SH', '/opt/pisignage/scripts/relay-link.sh');
if (!defined('RELAY_STATUS_SH')) define('RELAY_STATUS_SH', '/opt/pisignage/scripts/relay-status.sh');

/** Valide le format strict d'un code d'enrôlement : ZF-XXXX-XXXX-XXXX (alphanum MAJ). */
function relayValidateCode($code): bool {
    return is_string($code) && (bool)preg_match('/^ZF-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$/', $code);
}

/** Masque un code en ne gardant que le dernier groupe : ZF-••••-••••-EF56. '' si invalide. */
function relayMaskCode($code): string {
    if (!relayValidateCode($code)) return '';
    $parts = explode('-', $code);            // [ZF, G1, G2, G3]
    return 'ZF-••••-••••-' . $parts[3];
}

/**
 * Lance un helper (sudo, argv fixe) avec un payload sur STDIN. Retourne
 * ['rc'=>int,'out'=>string,'err'=>string]. N'écrit jamais le payload ailleurs.
 */
function relayRunStdin(array $argv, string $payload): array {
    $desc = [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $proc = @proc_open($argv, $desc, $pipes, null, null);
    if (!is_resource($proc)) return ['rc' => 127, 'out' => '', 'err' => 'spawn failed'];
    fwrite($pipes[0], $payload); fclose($pipes[0]);
    $out = stream_get_contents($pipes[1]); fclose($pipes[1]);
    $err = stream_get_contents($pipes[2]); fclose($pipes[2]);
    $rc  = proc_close($proc);
    return ['rc' => $rc, 'out' => (string)$out, 'err' => (string)$err];
}

/**
 * Échange des identifiants console contre un code d'enrôlement (POST /enroll/provision).
 * cURL TLS ; le mot de passe ne passe PAS par argv. Retourne le code, ou null si refusé/injoignable.
 */
function relayProvisionCode(string $email, string $password): ?string {
    if (!function_exists('curl_init')) return null;
    $ch = curl_init(RELAY_BASE . '/enroll/provision');
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
        CURLOPT_POSTFIELDS     => json_encode(['email' => $email, 'password' => $password]),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 20,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
    ]);
    $resp = curl_exec($ch);
    $http = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($http !== 201) return null;
    $j = json_decode((string)$resp, true);
    return (is_array($j) && !empty($j['code'])) ? (string)$j['code'] : null;
}

/**
 * Lit l'état de liaison via le helper root relay-status.sh (lecture seule, JSON sanitisé).
 * www-data ne peut pas lire relay.json/relay/* (pi:pi 0600/0640) → on passe par sudo.
 * Retourne un tableau ; en cas d'échec, un état minimal cohérent (linked=false).
 */
function relayReadStatus(): array {
    $fallback = [
        'linked' => false, 'enabled' => false, 'relay_url' => '', 'code_masked' => '',
        'rebind' => false, 'device_id' => '', 'tenant_id' => '', 'fingerprint' => '',
        'base_topic' => '', 'heartbeat_interval_s' => 0, 'agent_active' => 'unknown',
        'tunnel_up' => false, 'last_handshake_age_s' => null, 'connected' => false,
        'error' => 'status indisponible',
    ];
    $r = relayRunStdin(['sudo', '-n', RELAY_STATUS_SH], '');
    if ($r['rc'] !== 0 || $r['out'] === '') return $fallback;
    $d = json_decode($r['out'], true);
    if (!is_array($d)) return $fallback;
    unset($d['error']);
    return array_merge($fallback, $d, ['error' => null]);
}
