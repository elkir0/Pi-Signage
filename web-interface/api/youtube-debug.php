<?php
/**
 * Version debug de l'API YouTube avec affichage des erreurs
 */

// Activer tous les rapports d'erreur
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);

// Définir la constante avant les includes
define('PI_SIGNAGE_WEB', true);

// Try/catch pour capturer toutes les erreurs
try {
    // Vérifier que les fichiers existent avant de les inclure
    $requiredFiles = [
        '../includes/config.php',
        '../includes/auth.php',
        '../includes/functions.php',
        '../includes/security.php'
    ];
    
    foreach ($requiredFiles as $file) {
        if (!file_exists($file)) {
            throw new Exception("Fichier manquant: $file");
        }
    }
    
    // Inclure les fichiers
    require_once '../includes/config.php';
    require_once '../includes/auth.php';
    require_once '../includes/functions.php';
    require_once '../includes/security.php';
    
    // Pour le debug, on skip l'authentification
    // if (!isAuthenticated()) {
    //     http_response_code(401);
    //     exit(json_encode(['success' => false, 'message' => 'Unauthorized']));
    // }
    
    setSecurityHeaders();
    header('Content-Type: application/json');
    
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        exit(json_encode(['success' => false, 'message' => 'Method not allowed']));
    }
    
    $input = json_decode(file_get_contents('php://input'), true);
    
    // Pour le debug, on skip la validation CSRF
    // if (!validateCSRFToken($input['csrf_token'] ?? '')) {
    //     http_response_code(403);
    //     exit(json_encode(['success' => false, 'message' => 'CSRF token validation failed']));
    // }
    
    $url = $input['url'] ?? '';
    $title = $input['title'] ?? null;
    
    // Vérifications de base
    if (empty($url)) {
        exit(json_encode(['success' => false, 'error' => 'URL manquante']));
    }
    
    // Vérifier que les constantes nécessaires sont définies
    if (!defined('PROGRESS_DIR')) {
        exit(json_encode(['success' => false, 'error' => 'PROGRESS_DIR non défini']));
    }
    
    // Créer le token et le fichier de progression
    $token = bin2hex(random_bytes(8));
    $progressFile = PROGRESS_DIR . '/' . $token . '.txt';
    
    // Appeler la fonction de téléchargement
    if (!function_exists('downloadYouTubeVideo')) {
        exit(json_encode(['success' => false, 'error' => 'Fonction downloadYouTubeVideo non trouvée']));
    }
    
    $result = downloadYouTubeVideo($url, $title, $progressFile);
    $result['token'] = $token;
    
    echo json_encode($result);
    
} catch (Exception $e) {
    // Log l'erreur complète
    error_log('YouTube API Error: ' . $e->getMessage() . "\n" . $e->getTraceAsString());
    
    // Retourner l'erreur en JSON avec détails pour le debug
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
        'trace' => $e->getTraceAsString()
    ]);
}