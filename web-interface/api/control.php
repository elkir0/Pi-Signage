<?php
/**
 * API de contrôle des services Pi Signage
 */

define('PI_SIGNAGE_WEB', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_once '../includes/functions.php';
require_once '../includes/security.php';

// Vérifier l'authentification
if (!isAuthenticated()) {
    http_response_code(401);
    exit(json_encode(['error' => 'Unauthorized']));
}

// Headers de sécurité et JSON
setSecurityHeaders();
header('Content-Type: application/json');

// Traiter uniquement les requêtes POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit(json_encode(['error' => 'Method not allowed']));
}

// Récupérer et valider les données
$input = json_decode(file_get_contents('php://input'), true);

// Valider le token CSRF
if (!validateCSRFToken($input['csrf_token'] ?? '')) {
    http_response_code(403);
    exit(json_encode(['error' => 'CSRF token validation failed']));
}

// Valider l'action et le service
$action = $input['action'] ?? '';
$service = $input['service'] ?? '';

// Actions autorisées
$allowedActions = ['start', 'stop', 'restart', 'status'];
$allowedServices = ['vlc-signage.service'];

if (!in_array($action, $allowedActions)) {
    http_response_code(400);
    exit(json_encode(['error' => 'Invalid action']));
}

if (!in_array($service, $allowedServices)) {
    http_response_code(400);
    exit(json_encode(['error' => 'Invalid service']));
}

// Exécuter l'action
$result = controlService($service, $action);

// Retourner le résultat
echo json_encode($result);