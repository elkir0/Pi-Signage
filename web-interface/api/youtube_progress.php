<?php
/**
 * Suivi de progression de téléchargement YouTube
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

$token = $_GET['token'] ?? '';
if (!preg_match('/^[a-f0-9]{16}$/i', $token)) {
    http_response_code(400);
    exit(json_encode(['success' => false, 'message' => 'Invalid token']));
}

$progressFile = PROGRESS_DIR . '/' . $token . '.txt';
$progress = 0;
if (file_exists($progressFile)) {
    $progress = floatval(trim(file_get_contents($progressFile)));
}

echo json_encode(['success' => true, 'progress' => $progress]);
