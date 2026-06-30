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
require_once __DIR__ . '/relay-lib.php';           // relayProvisionCode, relayRunStdin, RELAY_LINK_SH
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

    // Mot de passe admin (FACULTATIF) : si le client en fournit un, il définit SON mot de passe ->
    // on (re)génère credentials.json (bcrypt) et on retire le mot de passe aléatoire affiché à
    // l'écran. Opération LOCALE -> faite AVANT toute action réseau (pas de teardown si elle échoue).
    $adminPw = isset($input['admin_password']) ? (string)$input['admin_password'] : '';
    if ($adminPw !== '') {
        if (strlen($adminPw) < 8) jsonResponse(false, null, 'Mot de passe admin : 8 caractères minimum.');
        if (!setupSetAdminPassword($adminPw)) jsonResponse(false, null, "Impossible d'enregistrer le mot de passe admin.");
    }

    // 1) Radio unique : couper l'AP, puis connecter le WiFi du lieu (wifi-apply, PSK via stdin).
    executeCommand(['sudo', ONBOARD_AP, 'down']);
    $rc = relayRunStdin(['sudo', '-n', WIFI_APPLY_B, 'apply'], implode("\n", $built['lines']) . "\n")['rc'];
    if ($rc !== 0) {
        executeCommand(['sudo', ONBOARD_AP, 'up']);
        jsonResponse(false, null, $rc === 3
            ? 'WiFi : connexion non confirmée — vérifiez le mot de passe ou la portée.'
            : 'WiFi : échec de la configuration.');
    }

    // 2) Box en ligne : résoudre le code d'enrôlement (login -> provision, ou code collé).
    if ($mode === 'login') {
        $code = relayProvisionCode($email, $password);
        if ($code === null) {
            executeCommand(['sudo', ONBOARD_AP, 'up']);
            jsonResponse(false, null, 'Compte Zaforge : identifiants refusés ou relais injoignable.');
        }
    }

    // 3) Lier la box au tenant (relay-link.sh : écrit relay.json + ENABLE_RELAY=1 + redémarre l'agent).
    //    Onboarding = 1er lien -> rebind:false (pas d'arg 'rebind').
    if (relayRunStdin(['sudo', '-n', RELAY_LINK_SH], $code)['rc'] !== 0) {
        executeCommand(['sudo', ONBOARD_AP, 'up']);
        jsonResponse(false, null, 'Liaison au compte échouée.');
    }

    // 4) Finaliser : marqueur collant .onboarded + démontage de l'AP. La box est en ligne, l'agent
    // s'enrôle ; le gate se referme -> l'écran kiosk repart sur le player.
    executeCommand(['sudo', ONBOARD_AP, 'finalize']);
    logMessage('Onboarding terminé : WiFi + compte liés (' . $ssid . ')');
    jsonResponse(true, ['done' => true, 'connected_ssid' => connectedSsid()], 'Configuration terminée');
}

// Écrit credentials.json (bcrypt) au MÊME format que firstboot.sh {username:"admin",password:hash},
// de façon ATOMIQUE (tmp + rename), puis retire le mot de passe aléatoire .setup-admin-password
// (il ne s'applique plus). PHP tourne en www-data, propriétaire du dossier config -> écriture OK.
function setupSetAdminPassword(string $pw): bool {
    $dir  = '/opt/pisignage/config';
    $hash = password_hash($pw, PASSWORD_BCRYPT, ['cost' => 12]);
    if (!is_string($hash) || $hash === '') return false;
    $json = json_encode(['username' => 'admin', 'password' => $hash], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
    $tmp  = $dir . '/credentials.json.tmp';
    if (@file_put_contents($tmp, $json) === false) return false;
    @chmod($tmp, 0640);
    if (!@rename($tmp, $dir . '/credentials.json')) { @unlink($tmp); return false; }
    @unlink($dir . '/.setup-admin-password');
    logMessage('Onboarding : mot de passe admin défini par le client');
    return true;
}
