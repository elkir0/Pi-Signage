<?php
/**
 * API YouTube - Version corrigée avec gestion d'erreur améliorée
 */

// Activer le rapport d'erreurs pour debug
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', '/var/log/pi-signage/php-error.log');

// Définir la constante avant tout include
define('PI_SIGNAGE_WEB', true);

// Headers de base
header('Content-Type: application/json');

try {
    // Vérifier que les fichiers requis existent
    $requiredFiles = [
        __DIR__ . '/../includes/config.php',
        __DIR__ . '/../includes/security.php',
        __DIR__ . '/../includes/auth.php'
    ];
    
    foreach ($requiredFiles as $file) {
        if (!file_exists($file)) {
            throw new Exception("Required file missing: " . basename($file));
        }
    }
    
    // Inclure les fichiers dans le bon ordre
    require_once __DIR__ . '/../includes/config.php';
    require_once __DIR__ . '/../includes/security.php';
    
    // Démarrer la session avant d'inclure auth.php
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    
    require_once __DIR__ . '/../includes/auth.php';
    
    // Vérifier l'authentification
    if (!isAuthenticated()) {
        http_response_code(401);
        exit(json_encode(['success' => false, 'message' => 'Unauthorized']));
    }
    
    // Vérifier la méthode
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        exit(json_encode(['success' => false, 'message' => 'Method not allowed']));
    }
    
    // Récupérer les données
    $input = json_decode(file_get_contents('php://input'), true);
    
    // Valider CSRF
    if (!validateCSRFToken($input['csrf_token'] ?? '')) {
        http_response_code(403);
        exit(json_encode(['success' => false, 'message' => 'CSRF token validation failed']));
    }
    
    // Récupérer l'URL
    $url = $input['url'] ?? '';
    if (empty($url)) {
        exit(json_encode(['success' => false, 'error' => 'URL is required']));
    }
    
    // Vérifier que c'est une URL YouTube
    if (!preg_match('/^https?:\/\/(www\.)?(youtube\.com|youtu\.be)\//', $url)) {
        exit(json_encode(['success' => false, 'error' => 'Only YouTube URLs are allowed']));
    }
    
    // Générer le nom du fichier
    $title = $input['title'] ?? null;
    $filename = $title ? preg_replace('/[^a-zA-Z0-9._-]/', '_', $title) : 'video_' . time();
    $outputPath = VIDEO_DIR . '/' . $filename . '.mp4';
    
    // Vérifier que le répertoire de destination existe et est writable
    if (!is_dir(VIDEO_DIR)) {
        throw new Exception("Video directory does not exist: " . VIDEO_DIR);
    }
    
    if (!is_writable(VIDEO_DIR)) {
        throw new Exception("Video directory is not writable: " . VIDEO_DIR);
    }
    
    // Construire la commande
    $cmd = sprintf(
        'timeout 300 %s -o %s %s 2>&1',
        YTDLP_BIN,
        escapeshellarg($outputPath),
        escapeshellarg($url)
    );
    
    // Log la commande pour debug
    error_log("YouTube download command: $cmd");
    
    // Exécuter la commande
    $output = [];
    $returnCode = 0;
    exec($cmd, $output, $returnCode);
    
    // Préparer la réponse
    $response = [
        'success' => ($returnCode === 0),
        'output' => implode("\n", $output),
        'returnCode' => $returnCode
    ];
    
    // Si succès et mode Chromium, mettre à jour la playlist
    if ($returnCode === 0 && DISPLAY_MODE === 'chromium') {
        if (file_exists('/opt/scripts/update-playlist.sh')) {
            exec('sudo /opt/scripts/update-playlist.sh 2>&1', $updateOutput, $updateStatus);
            if ($updateStatus === 0) {
                $response['playlist_updated'] = true;
            }
        }
    }
    
    // Log le résultat
    error_log("YouTube download result: " . json_encode(['success' => $response['success'], 'returnCode' => $returnCode]));
    
    echo json_encode($response);
    
} catch (Exception $e) {
    // Log l'erreur complète
    $errorDetails = [
        'message' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
        'trace' => $e->getTraceAsString()
    ];
    error_log("YouTube API Fatal Error: " . json_encode($errorDetails));
    
    // Retourner une erreur générique à l'utilisateur
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Server error occurred. Check logs for details.',
        'details' => $e->getMessage() // Pour debug seulement
    ]);
}