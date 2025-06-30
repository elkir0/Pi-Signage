<?php
/**
 * API de téléchargement YouTube
 */

define('PI_SIGNAGE_WEB', true);
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

$token = bin2hex(random_bytes(8));
$progressFile = PROGRESS_DIR . '/' . $token . '.txt';

$result = downloadYouTubeVideo($url, $title, $progressFile);
$result['token'] = $token;

echo json_encode($result);
