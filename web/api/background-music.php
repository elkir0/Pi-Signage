<?php
/**
 * Zaforge — API musique d'ambiance.
 *
 * GET  /api/background-music.php  -> config + presets + fichiers audio locaux
 * POST /api/background-music.php  -> sauvegarde config globale (admin)
 */

require_once __DIR__ . '/_guard.php';
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/background-music-lib.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $payload = backgroundMusicPayload();
    // Le player kiosk lit cette config sans session. Il n'a pas besoin de la bibliothèque
    // audio complète, donc on ne l'expose qu'à l'interface admin authentifiée.
    if (!function_exists('isAuthenticated') || !isAuthenticated()) {
        $payload['audio_files'] = [];
    }
    jsonResponse(true, $payload, 'Configuration musique récupérée');
}

if ($method === 'POST') {
    $input = json_decode((string)file_get_contents('php://input'), true);
    if (!is_array($input)) {
        jsonResponse(false, null, 'JSON invalide', 400);
    }
    $config = backgroundMusicSaveConfig($input);
    jsonResponse(true, backgroundMusicPayload(), $config['enabled'] ? 'Musique d’ambiance activée' : 'Musique d’ambiance désactivée');
}

jsonResponse(false, null, 'Method not allowed', 405);
