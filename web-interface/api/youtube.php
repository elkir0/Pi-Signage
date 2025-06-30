<?php
/**
 * API de téléchargement YouTube - Version corrigée
 */

// Éviter la redéfinition de la constante
if (!defined('PI_SIGNAGE_WEB')) {
    define('PI_SIGNAGE_WEB', true);
}

// Gestion d'erreur pour debug
error_reporting(E_ALL);
ini_set('display_errors', 0); // Ne pas afficher les erreurs à l'utilisateur
ini_set('log_errors', 1);

try {
    require_once '../includes/config.php';
    require_once '../includes/auth.php';
    require_once '../includes/functions.php';
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

    // Validation
    if (empty($url)) {
        exit(json_encode(['success' => false, 'error' => 'URL required']));
    }

    // Utiliser une approche simple pour le téléchargement
    $filename = $title ? preg_replace('/[^a-zA-Z0-9._-]/', '_', $title) : 'video_' . time();
    $output_path = VIDEO_DIR . '/' . $filename . '.mp4';

    // Commande simple avec le wrapper
    $cmd = sprintf(
        'timeout 300 %s -o %s %s 2>&1',
        YTDLP_BIN,
        escapeshellarg($output_path),
        escapeshellarg($url)
    );

    // Log pour debug
    error_log("YouTube download command: $cmd");

    // Exécuter la commande
    exec($cmd, $output, $status);

    $response = [
        'success' => ($status === 0),
        'output' => implode("\n", $output)
    ];

    // Si succès et mode Chromium, mettre à jour la playlist
    if ($status === 0 && defined('DISPLAY_MODE') && DISPLAY_MODE === 'chromium' && file_exists('/opt/scripts/update-playlist.sh')) {
        exec('sudo /opt/scripts/update-playlist.sh 2>&1', $updateOutput, $updateStatus);
        if ($updateStatus === 0) {
            $response['playlist_updated'] = true;
            $response['output'] .= "\n[INFO] Playlist mise à jour";
        }
    }

    echo json_encode($response);

} catch (Exception $e) {
    error_log('YouTube API Error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server error occurred',
        'message' => $e->getMessage()
    ]);
}