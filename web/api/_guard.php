<?php
// Garde d'authentification central des endpoints API PiSignage.
// N'inclut QUE auth.php (PAS config.php : playlist.php a sa propre jsonResponse() -> éviter une redéclaration).
require_once __DIR__ . '/../includes/auth.php';

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
// NOTE phase 2 (NE PAS activer maintenant): pour POST/PUT/DELETE/PATCH, exiger
// hash_equals($_SESSION['csrf'] ?? '', $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '') une fois api.js adapté.
