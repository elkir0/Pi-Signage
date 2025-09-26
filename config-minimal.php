<?php
/**
 * PiSignage - Configuration minimale pour debug
 */

// Afficher les erreurs pour debug
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Version
define('PISIGNAGE_VERSION', 'v0.8.0');

// Chemins
define('BASE_DIR', '/opt/pisignage');
define('MEDIA_DIR', BASE_DIR . '/media');
define('MEDIA_PATH', BASE_DIR . '/media');
define('PLAYLISTS_PATH', BASE_DIR . '/playlists');
define('SCREENSHOTS_DIR', BASE_DIR . '/web/screenshots');
define('SCREENSHOTS_PATH', BASE_DIR . '/web/screenshots');
define('LOGS_DIR', BASE_DIR . '/logs');
define('LOGS_PATH', BASE_DIR . '/logs');
define('DB_PATH', BASE_DIR . '/data/pisignage.db');

// Limites d'upload (500MB)
define('MAX_UPLOAD_SIZE', 500 * 1024 * 1024);

// Types de fichiers autorisés
define('ALLOWED_VIDEO_EXTENSIONS', ['mp4', 'mkv', 'avi', 'webm', 'mov', 'flv', 'wmv']);
define('ALLOWED_IMAGE_EXTENSIONS', ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg']);
define('ALLOWED_AUDIO_EXTENSIONS', ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac']);

// Créer les répertoires s'ils n'existent pas
$dirs = [MEDIA_DIR, SCREENSHOTS_DIR, LOGS_DIR, PLAYLISTS_PATH, dirname(DB_PATH)];
foreach ($dirs as $dir) {
    if (!is_dir($dir)) {
        @mkdir($dir, 0755, true);
    }
}

// Pas de base de données pour l'instant (mode dégradé)
$db = null;

// Fonctions utilitaires de base
function jsonResponse($success, $data = null, $message = '', $httpCode = 200) {
    http_response_code($httpCode);
    header('Content-Type: application/json');
    header('Access-Control-Allow-Origin: *');

    $response = [
        'success' => $success,
        'data' => $data,
        'message' => $message,
        'timestamp' => date('Y-m-d H:i:s')
    ];

    echo json_encode($response);
    exit;
}

function sanitizeFilename($filename) {
    $filename = preg_replace('/[^a-zA-Z0-9\-\_\.]/', '_', $filename);
    $filename = preg_replace('/\.+/', '.', $filename);
    if (empty($filename) || $filename === '.') {
        $filename = 'file_' . time();
    }
    return $filename;
}

function isValidMediaFile($filename) {
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
    $allowed = array_merge(
        ALLOWED_VIDEO_EXTENSIONS,
        ALLOWED_IMAGE_EXTENSIONS,
        ALLOWED_AUDIO_EXTENSIONS
    );
    return in_array($ext, $allowed);
}

function logMessage($message, $level = 'INFO') {
    $logFile = LOGS_DIR . '/system.log';
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[$timestamp] [$level] $message\n";
    @file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);
}

function executeCommand($command) {
    $output = [];
    $returnVar = 0;
    exec($command . ' 2>&1', $output, $returnVar);
    return [
        'success' => $returnVar === 0,
        'output' => $output,
        'return_code' => $returnVar
    ];
}

function getMediaFiles() {
    $mediaFiles = [];
    if (is_dir(MEDIA_PATH)) {
        $files = scandir(MEDIA_PATH);
        foreach ($files as $file) {
            if ($file === '.' || $file === '..' || $file === 'thumbnails') continue;
            $filepath = MEDIA_PATH . '/' . $file;
            if (is_file($filepath) && isValidMediaFile($file)) {
                $mediaFiles[] = [
                    'name' => $file,
                    'size' => filesize($filepath),
                    'type' => mime_content_type($filepath),
                    'modified' => filemtime($filepath)
                ];
            }
        }
    }
    return $mediaFiles;
}

function formatFileSize($bytes) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $factor = floor((strlen($bytes) - 1) / 3);
    return sprintf("%.2f", $bytes / pow(1024, $factor)) . ' ' . $units[$factor];
}
?>