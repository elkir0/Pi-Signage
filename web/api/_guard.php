<?php
// Garde d'authentification central des endpoints API PiSignage.
// N'inclut QUE auth.php (PAS config.php : playlist.php a sa propre jsonResponse() -> éviter une redéclaration).
require_once __DIR__ . '/../includes/auth.php';

// Lecture du token de l'agent local (constant-only, mis en cache statique). Lit
// /opt/pisignage/config/agent.json (mode 0640 pi:www-data). Retourne '' si absent/illisible.
function pisignage_agent_token() {
    static $tok = null;
    if ($tok !== null) { return $tok; }
    $tok = '';
    $f = '/opt/pisignage/config/agent.json';
    if (is_readable($f)) {
        $j = json_decode((string)@file_get_contents($f), true);
        if (is_array($j) && !empty($j['token']) && is_string($j['token'])) {
            $tok = $j['token'];
        }
    }
    return $tok;
}

// Exemption CLI : ce garde est re-inclus en CLI par les workers détachés (ex: worker yt-dlp
// via youtube.php -> media.php). En CLI il n'y a ni requête HTTP ni session -> sans cette
// sortie anticipée le garde tuerait le worker en 401. FPM est 'fpm-fcgi' (jamais 'cli'),
// donc aucun affaiblissement de la sécurité HTTP (PHP_SAPI n'est pas spoofable via HTTP).
if (PHP_SAPI === 'cli') {
    return;
}

// Exception de lecture publique : le kiosk public (player.php) lit GET /api/playlist sans session.
if ($_SERVER['REQUEST_METHOD'] === 'GET' && basename($_SERVER['SCRIPT_NAME']) === 'playlist.php') {
    return;
}

// Exception de lecture publique : le kiosk public lit sa configuration de musique d'ambiance.
// L'écriture reste protégée par session + CSRF plus bas.
if ($_SERVER['REQUEST_METHOD'] === 'GET' && basename($_SERVER['SCRIPT_NAME']) === 'background-music.php') {
    return;
}

// Exceptions publiques pour le player kiosk (Chromium, sans session HTTP) — display.php :
//  - GET  ?action=command  : le player interroge le canal de commande (transport).
//  - POST ?action=state    : le player rapporte son état courant.
// Le reste de display.php (POST command, GET state, playmedia) reste protégé par l'auth.
if (basename($_SERVER['SCRIPT_NAME']) === 'display.php') {
    $m = $_SERVER['REQUEST_METHOD'];
    $a = $_GET['action'] ?? '';
    if (($m === 'GET' && $a === 'command') || ($m === 'POST' && $a === 'state')) {
        return;
    }
}

// Onboarding 1er démarrage : api/setup.php est PUBLIC (téléphone du client, sans session)
// UNIQUEMENT pendant l'onboarding actif (marqueur root .onboarding, .onboarded absent). Dès que
// l'onboarding est terminé, l'exception ne s'ouvre plus -> les endpoints redeviennent 401 (auto-
// désactivation ; pas de trou permanent de config wifi/relais non authentifié). CSRF non exigé ici
// (téléphone sans session) : la protection est l'état non-provisionné + la validation des helpers root.
if (basename($_SERVER['SCRIPT_NAME']) === 'setup.php') {
    require_once __DIR__ . '/../includes/onboarding.php';
    // PUBLIC seulement si onboarding actif ET client sur l'AP/loopback (jamais le LAN du lieu).
    if (function_exists('zfOnboardingActive') && zfOnboardingActive()
        && zfOnboardingClientAllowed()) {
        return;
    }
}

// Pont d'authentification machine (agent local). UNIQUEMENT en loopback + token partagé.
// Réussit (return, en sautant session + must_change + CSRF) SEULEMENT si REMOTE_ADDR est loopback
// ET le token correspond (hash_equals, >= 32 chars). REMOTE_ADDR est le SEUL signal de loopback —
// jamais X-Forwarded-For / X-Real-IP (cet nginx ne fait pas confiance à ces en-têtes => REMOTE_ADDR
// = vrai pair TCP, non spoofable). Tout autre cas tombe dans le 401 normal (aucun oracle).
$agentHeader = $_SERVER['HTTP_X_AGENT_TOKEN'] ?? '';
if ($agentHeader !== '') {
    $remote = $_SERVER['REMOTE_ADDR'] ?? '';
    $isLoopback = in_array($remote, ['127.0.0.1', '::1', '::ffff:127.0.0.1'], true);
    $expected = pisignage_agent_token();
    if ($isLoopback && $expected !== '' && strlen($agentHeader) >= 32 && hash_equals($expected, $agentHeader)) {
        // PÉRIMÈTRE du token agent : il ne déverrouille QUE les endpoints dont l'agent
        // a réellement besoin (stats lecture ; état/commande du player ; playlists).
        // Défense en profondeur : un processus www-data compromis qui lit agent.json
        // (0640 pi:www-data) ne pilote alors que ce périmètre — jamais settings/system/
        // media/upload/youtube/etc. Le token n'est PAS une clé d'API générale.
        // Surface de pilotage du player (lecture + contrôle distant via la console) :
        // stats, état/commande player, playlists, médias, téléchargement YouTube.
        // EXCLUT settings.php (mot de passe/réseau) ET system.php (reboot/shutdown,
        // de toute façon deny-all au niveau nginx). Le volume passe par amixer DIRECT
        // dans l'agent (user pi), pas par le pont PHP — donc system.php inutile ici.
        $agentScript = basename($_SERVER['SCRIPT_NAME'] ?? '');
        if (in_array($agentScript, ['stats.php', 'display.php', 'playlists.php', 'media.php', 'youtube.php'], true)) {
            $GLOBALS['__guard_agent'] = true;
            return;
        }
        // Token valide mais endpoint hors périmètre : pas de return -> tombe dans le
        // 401 normal ci-dessous (aucun accès élargi).
        @error_log('[pisignage] agent token hors périmètre: ' . $agentScript);
    } else {
        // En-tête présent mais échec : journaliser sans révéler quelle vérif a échoué (no-oracle).
        @error_log('[pisignage] agent auth refusée depuis ' . $remote);
    }
}

if (!isAuthenticated()) {
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'data' => null,
        'message' => 'Authentication required',
        'timestamp' => date('Y-m-d H:i:s'),
    ]);
    exit;
}

// Forçage du changement de mot de passe par défaut (API). Ne bloque que les méthodes mutables ;
// les GET (lecture des widgets de la page settings) passent. Seuls update_password et logout
// (sur settings.php) sont autorisés tant que must_change_password est posé.
if (!empty($_SESSION['must_change_password'])) {
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if (in_array($method, ['POST', 'PUT', 'DELETE', 'PATCH'], true)) {
        // On met en cache le corps (php://input est à lecture unique) pour que settings.php le réutilise.
        $GLOBALS['__guard_raw']   = file_get_contents('php://input');
        $GLOBALS['__guard_input'] = ($GLOBALS['__guard_raw'] !== '') ? json_decode($GLOBALS['__guard_raw'], true) : null;
        $isSettings = (basename($_SERVER['SCRIPT_NAME']) === 'settings.php');
        $act = $GLOBALS['__guard_input']['action'] ?? null;
        $allowed = $isSettings && in_array($act, ['update_password', 'logout'], true);
        if (!$allowed) {
            http_response_code(403);
            header('Content-Type: application/json');
            echo json_encode(['success' => false, 'data' => null, 'message' => 'Password change required', 'code' => 'must_change_password', 'timestamp' => date('Y-m-d H:i:s')]);
            exit;
        }
    }
}

// CSRF : exiger un token valide sur les méthodes mutables (le chemin agent loopback a déjà return
// plus haut, et reste donc exempt). hash_equals('','') === true -> on rejette explicitement le vide.
$csrfMethod = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if (in_array($csrfMethod, ['POST', 'PUT', 'DELETE', 'PATCH'], true)) {
    $s = $_SESSION['csrf'] ?? '';
    $h = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
    if ($s === '' || $h === '' || !hash_equals($s, $h)) {
        http_response_code(403);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'data' => null, 'message' => 'CSRF token invalid or missing', 'timestamp' => date('Y-m-d H:i:s')]);
        exit;
    }
}
