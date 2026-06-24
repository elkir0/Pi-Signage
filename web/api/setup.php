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
elseif ($method === 'POST' && $action === 'link')   { jsonResponse(false, null, 'Liaison compte non encore disponible (Phase B2)'); }
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

function setupApply() {
    $input = json_decode(file_get_contents('php://input'), true);
    $ssid = (is_array($input) && isset($input['ssid'])) ? (string)$input['ssid'] : '';
    $psk  = (is_array($input) && isset($input['psk']))  ? (string)$input['psk']  : '';

    // Valider via la lib WiFi partagée (un seul réseau ici).
    $built = wifiValidateAndBuild([['ssid' => $ssid, 'psk' => $psk]], []);
    if (!$built['ok']) jsonResponse(false, null, $built['error']);

    // Radio unique : couper l'AP AVANT de tenter le STA (ne peuvent coexister).
    executeCommand(['sudo', ONBOARD_AP, 'down']);

    // wifi-apply (PSK via stdin uniquement). rc: 0 = connecté ; 3 = appliqué mais non connecté ; autre = échec.
    $payload = implode("\n", $built['lines']) . "\n";
    $desc = [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $proc = @proc_open(['sudo', WIFI_APPLY_B, 'apply'], $desc, $pipes, null, null);
    if (!is_resource($proc)) {
        executeCommand(['sudo', ONBOARD_AP, 'up']);
        jsonResponse(false, null, 'Échec lancement wifi-apply');
    }
    fwrite($pipes[0], $payload); fclose($pipes[0]);
    stream_get_contents($pipes[1]); fclose($pipes[1]);
    $err = stream_get_contents($pipes[2]); fclose($pipes[2]);
    $rc = proc_close($proc);

    if ($rc === 0) {
        logMessage('Onboarding : WiFi du lieu connecté (' . $ssid . ')');
        // NB (Phase B2) : ici on enchaînera la liaison compte puis on écrira .onboarded + reboot.
        // Pour l'instant (B1), on signale juste le succès WiFi ; l'AP reste baissé.
        jsonResponse(true, ['connected_ssid' => connectedSsid()], 'WiFi connecté');
    }

    // Échec / non connecté : relever l'AP pour que le téléphone reprenne l'assistant.
    executeCommand(['sudo', ONBOARD_AP, 'up']);
    $msg = ($rc === 3)
        ? 'Connexion non confirmée — vérifiez le mot de passe ou la portée, puis réessayez.'
        : 'Échec de la configuration WiFi : ' . trim($err);
    jsonResponse(false, null, $msg);
}
