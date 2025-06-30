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

// Token de progression (non utilisé actuellement)
$token = $_GET['token'] ?? '';

// Si pas de token ou token 'undefined', retourner simplement 100%
// Cela évite l'erreur 400 dans la console
if (empty($token) || $token === 'undefined') {
    echo json_encode(['success' => true, 'progress' => 100, 'message' => 'Progress tracking not active']);
    exit;
}

// Validation du token pour les futures implémentations
if (!preg_match('/^[a-f0-9]{16}$/i', $token)) {
    http_response_code(400);
    exit(json_encode(['success' => false, 'message' => 'Invalid token']));
}

// Pour l'instant, retourner toujours 100% car le suivi n'est pas implémenté
echo json_encode(['success' => true, 'progress' => 100]);
