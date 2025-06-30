<?php
/**
 * Version simplifiée de l'API YouTube pour test
 */

define('PI_SIGNAGE_WEB', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_once '../includes/security.php';

if (!isAuthenticated()) {
    http_response_code(401);
    exit(json_encode(['success' => false, 'message' => 'Unauthorized']));
}

setSecurityHeaders();
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit(json_encode(['success' => false, 'message' => 'Method not allowed']));
}

$input = json_decode(file_get_contents('php://input'), true);

if (!validateCSRFToken($input['csrf_token'] ?? '')) {
    http_response_code(403);
    exit(json_encode(['success' => false, 'message' => 'CSRF token validation failed']));
}

$url = $input['url'] ?? '';
$title = $input['title'] ?? null;

// Validation simple
if (empty($url)) {
    exit(json_encode(['success' => false, 'error' => 'URL required']));
}

// Générer un nom de fichier
$filename = $title ? preg_replace('/[^a-zA-Z0-9._-]/', '_', $title) : 'video_' . time();
$output_path = VIDEO_DIR . '/' . $filename . '.mp4';

// Commande yt-dlp ultra simple
$cmd = sprintf(
    '%s -o %s %s 2>&1',
    escapeshellcmd(YTDLP_BIN),
    escapeshellarg($output_path),
    escapeshellarg($url)
);

// Exécuter avec un timeout
$cmd = 'timeout 300 ' . $cmd;

// Log la commande pour debug
error_log("Executing: $cmd");

// Exécuter la commande
exec($cmd, $output, $status);

// Préparer la réponse
$response = [
    'success' => ($status === 0),
    'output' => implode("\n", $output),
    'status' => $status,
    'command' => $cmd // Pour debug
];

// Si succès et mode Chromium, mettre à jour la playlist
if ($status === 0 && DISPLAY_MODE === 'chromium' && file_exists('/opt/scripts/update-playlist.sh')) {
    exec('sudo /opt/scripts/update-playlist.sh 2>&1', $updateOutput, $updateStatus);
    if ($updateStatus === 0) {
        $response['playlist_updated'] = true;
    }
}

// Log le résultat
error_log("YouTube download result: " . json_encode($response));

echo json_encode($response);