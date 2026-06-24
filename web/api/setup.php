<?php
/**
 * Zaforge — endpoint d'onboarding 1er démarrage. PUBLIC (téléphone du client, sans session)
 * UNIQUEMENT pendant l'onboarding actif (exception _guard.php + double-garde ci-dessous).
 *   GET  ?action=status : état de l'AP + connexion (le stepper poll toutes les 2s).
 *   POST ?action=apply  : {ssid,psk} -> radio unique : AP down, wifi-apply (stdin), vérifie ;
 *                         échec -> AP relevé pour que l'assistant reprenne.
 *   POST ?action=link   : étape compte (Phase B2) — stub pour l'instant.
 */
require_once __DIR__ . '/_guard.php';
require_once '../config.php';                      // jsonResponse, executeCommand, logMessage
require_once __DIR__ . '/wifi-lib.php';
require_once __DIR__ . '/../includes/onboarding.php';

const ONBOARD_AP   = '/opt/pisignage/scripts/onboard-ap.sh';
const WIFI_APPLY_B = '/opt/pisignage/scripts/wifi-apply.sh';
const RELAY_LINK   = '/opt/pisignage/scripts/relay-link.sh';
const RELAY_BASE   = 'https://relay.zaforge.com';

// Défense en profondeur : ces endpoints n'existent que pendant l'onboarding actif ET pour un client
// AP/loopback (jamais le LAN du lieu, même si un marqueur restait posé).
if (!zfOnboardingActive() || !zfOnboardingClientAllowed()) {
    http_response_code(403);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'data' => null, 'message' => 'Onboarding non actif', 'timestamp' => date('Y-m-d H:i:s')]);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

if ($method === 'GET' && $action === 'status')      { setupStatus(); }
elseif ($method === 'POST' && $action === 'apply')  { setupApply(); }
else { jsonResponse(false, null, 'Action inconnue'); }

function apStatus() {
    $out = ['ap_up' => false, 'ap_ssid' => '', 'clients' => 0];
    $r = executeCommand(['sudo', ONBOARD_AP, 'status']);
    if ($r['success'] && !empty($r['output'])) {
        foreach (preg_split('/\s+/', trim($r['output'][0])) as $kv) {
            if (strpos($kv, '=') === false) continue;
            list($k, $v) = explode('=', $kv, 2);
            if ($k === 'ap_up')        $out['ap_up']   = ($v === 'yes');
            elseif ($k === 'ap_ssid')  $out['ap_ssid'] = $v;
            elseif ($k === 'clients')  $out['clients'] = (int)$v;
        }
    }
    return $out;
}

function connectedSsid() {
    $r = executeCommand(['/usr/bin/nmcli', '-t', '-f', 'active,ssid', 'dev', 'wifi']);
    if ($r['success']) {
        foreach ($r['output'] as $line) {
            if (strpos($line, 'yes:') === 0) {
                return str_replace(['\\:', '\\\\'], [':', '\\'], substr($line, 4));
            }
        }
    }
    return '';
}

function setupStatus() {
    $ap = apStatus();
    jsonResponse(true, [
        'onboarding'     => true,
        'ap_ssid'        => $ap['ap_ssid'],
        'ap_up'          => $ap['ap_up'],
        'clients'        => $ap['clients'],
        'connected_ssid' => connectedSsid(),
    ], 'ok');
}

// Lance un helper root (sudo, args fixes) en lui passant un payload sur STDIN ; renvoie le code retour.
function setupRunStdin($argv, $payload) {
    $desc = [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $proc = @proc_open($argv, $desc, $pipes, null, null);
    if (!is_resource($proc)) return 127;
    fwrite($pipes[0], $payload); fclose($pipes[0]);
    stream_get_contents($pipes[1]); fclose($pipes[1]);
    stream_get_contents($pipes[2]); fclose($pipes[2]);
    return proc_close($proc);
}

// Provisionne un code d'enrôlement auprès du relais avec les identifiants console du proprio.
// Appel sortant TLS via cURL (le mot de passe ne passe PAS par argv). Retourne le code ou null.
function provisionCode($email, $password) {
    if (!function_exists('curl_init')) return null;
    $ch = curl_init(RELAY_BASE . '/enroll/provision');
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_POSTFIELDS => json_encode(['email' => $email, 'password' => $password]),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 20,
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

function setupApply() {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!is_array($input)) jsonResponse(false, null, 'Requête invalide');
    $ssid = isset($input['ssid']) ? (string)$input['ssid'] : '';
    $psk  = isset($input['psk'])  ? (string)$input['psk']  : '';
    $acct = (isset($input['account']) && is_array($input['account'])) ? $input['account'] : [];
    $mode = (string)($acct['mode'] ?? '');   // 'login' | 'code' (enrôlement OBLIGATOIRE)

    // Valider le WiFi (un réseau).
    $built = wifiValidateAndBuild([['ssid' => $ssid, 'psk' => $psk]], []);
    if (!$built['ok']) jsonResponse(false, null, $built['error']);

    // Valider l'étape compte AVANT toute action réseau.
    $email = ''; $password = ''; $code = '';
    if ($mode === 'login') {
        $email = (string)($acct['email'] ?? ''); $password = (string)($acct['password'] ?? '');
        if ($email === '' || $password === '') jsonResponse(false, null, 'Identifiants Zaforge requis');
    } elseif ($mode === 'code') {
        $code = strtoupper(trim((string)($acct['code'] ?? '')));
        if (!preg_match('/^ZF-[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$/', $code)) jsonResponse(false, null, "Code d'enrôlement invalide");
    } else {
        jsonResponse(false, null, 'Étape compte requise (connexion ou code)');
    }

    // 1) Radio unique : couper l'AP, puis connecter le WiFi du lieu (wifi-apply, PSK via stdin).
    executeCommand(['sudo', ONBOARD_AP, 'down']);
    $rc = setupRunStdin(['sudo', WIFI_APPLY_B, 'apply'], implode("\n", $built['lines']) . "\n");
    if ($rc !== 0) {
        executeCommand(['sudo', ONBOARD_AP, 'up']);
        jsonResponse(false, null, $rc === 3
            ? 'WiFi : connexion non confirmée — vérifiez le mot de passe ou la portée.'
            : 'WiFi : échec de la configuration.');
    }

    // 2) Box en ligne : résoudre le code d'enrôlement (login -> provision, ou code collé).
    if ($mode === 'login') {
        $code = provisionCode($email, $password);
        if ($code === null) {
            executeCommand(['sudo', ONBOARD_AP, 'up']);
            jsonResponse(false, null, 'Compte Zaforge : identifiants refusés ou relais injoignable.');
        }
    }

    // 3) Lier la box au tenant (relay-link.sh : écrit relay.json + ENABLE_RELAY=1 + redémarre l'agent).
    if (setupRunStdin(['sudo', RELAY_LINK], $code) !== 0) {
        executeCommand(['sudo', ONBOARD_AP, 'up']);
        jsonResponse(false, null, 'Liaison au compte échouée.');
    }

    // 4) Finaliser : marqueur collant .onboarded + démontage de l'AP. La box est en ligne, l'agent
    // s'enrôle ; le gate se referme -> l'écran kiosk repart sur le player.
    executeCommand(['sudo', ONBOARD_AP, 'finalize']);
    logMessage('Onboarding terminé : WiFi + compte liés (' . $ssid . ')');
    jsonResponse(true, ['done' => true, 'connected_ssid' => connectedSsid()], 'Configuration terminée');
}
