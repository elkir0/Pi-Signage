<?php
/**
 * Zaforge — API COMPTE (liaison au relais depuis l'admin authentifié).
 *
 *   GET  /api/account.php?action=status -> état de liaison (JSON sanitisé via helper root)
 *   POST /api/account.php?action=link   -> lie/re-lie la box au compte
 *        {mode:'code', code:'ZF-XXXX-XXXX-XXXX'}
 *        {mode:'login', email, password}   (provisionne le code via le relais)
 *
 * Endpoint ADMIN : aucune exception publique dans _guard.php (session + CSRF requis sur POST).
 * Re-lier = rebind (relay-link.sh rebind) pour autoriser le déplacement vers un autre tenant.
 */

require_once __DIR__ . '/_guard.php';
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/relay-lib.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$action = $_GET['action'] ?? '';

if ($method === 'GET' && $action === 'status') {
    jsonResponse(true, relayReadStatus(), 'ok');
}

if ($method === 'POST' && $action === 'link') {
    $input = json_decode((string)file_get_contents('php://input'), true);
    if (!is_array($input)) jsonResponse(false, null, 'Requête invalide', 400);
    $mode = (string)($input['mode'] ?? '');

    // 1) Résoudre le code d'enrôlement selon le mode.
    if ($mode === 'code') {
        $code = strtoupper(trim((string)($input['code'] ?? '')));
        if (!relayValidateCode($code)) {
            jsonResponse(false, null, "Code d'enrôlement invalide (format ZF-XXXX-XXXX-XXXX)", 422);
        }
    } elseif ($mode === 'login') {
        $email    = trim((string)($input['email'] ?? ''));
        $password = (string)($input['password'] ?? '');
        if ($email === '' || $password === '') {
            jsonResponse(false, null, 'E-mail et mot de passe Zaforge requis', 422);
        }
        $code = relayProvisionCode($email, $password);
        if ($code === null) {
            jsonResponse(false, null, 'Identifiants Zaforge refusés ou relais injoignable', 502);
        }
    } else {
        jsonResponse(false, null, 'Mode requis : "code" ou "login"', 400);
    }

    // 2) Lier via le helper root (rebind = autorise le déplacement vers un autre compte).
    //    Le code part sur STDIN (jamais en argv).
    $r = relayRunStdin(['sudo', '-n', RELAY_LINK_SH, 'rebind'], $code);
    if ($r['rc'] !== 0) {
        if (function_exists('logMessage')) logMessage('account: échec relay-link (rc=' . $r['rc'] . ')');
        jsonResponse(false, null, 'Liaison au compte échouée (helper rc=' . $r['rc'] . ')', 500);
    }

    if (function_exists('logMessage')) logMessage('account: box (re)liée à un compte Zaforge (' . $mode . ')');
    // L'agent redémarre et s'enrôle ; l'état « connecté » apparaît sous quelques secondes.
    jsonResponse(true, relayReadStatus(), 'Box liée au compte. Connexion au relais en cours…');
}

jsonResponse(false, null, 'Action non supportée', 400);
