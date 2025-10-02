<?php
/**
 * PiSignage - Configuration centrale
 */

// Version
define('PISIGNAGE_VERSION', 'v0.8.9');

// Chemins
define('BASE_DIR', '/opt/pisignage');
define('MEDIA_DIR', BASE_DIR . '/media');
define('MEDIA_PATH', BASE_DIR . '/media'); // Alias pour compatibilité
define('PLAYLISTS_PATH', BASE_DIR . '/playlists');
define('CONFIG_PATH', BASE_DIR . '/config'); // Configuration files
define('SCREENSHOTS_DIR', BASE_DIR . '/web/screenshots');
define('SCREENSHOTS_PATH', BASE_DIR . '/web/screenshots'); // Alias
define('LOGS_DIR', BASE_DIR . '/logs');
define('LOGS_PATH', BASE_DIR . '/logs'); // Alias
define('DB_PATH', BASE_DIR . '/data/pisignage.db');

// Limites d'upload (500MB)
define('MAX_UPLOAD_SIZE', 500 * 1024 * 1024); // 500MB en octets

// Types de fichiers autorisés
define('ALLOWED_VIDEO_EXTENSIONS', ['mp4', 'mkv', 'avi', 'webm', 'mov', 'flv', 'wmv']);
define('ALLOWED_IMAGE_EXTENSIONS', ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg']);
define('ALLOWED_AUDIO_EXTENSIONS', ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac']);

// Configuration de capture
define('SCREENSHOT_QUALITY', 85);
define('SCREENSHOT_COOLDOWN', 5); // Secondes entre captures

// Fonctions utilitaires
function jsonResponse($success, $data = null, $message = '', $httpCode = 200) {
    http_response_code($httpCode);
    header('Content-Type: application/json');
    header('Access-Control-Allow-Origin: *');
    echo json_encode([
        'success' => $success,
        'data' => $data,
        'message' => $message,
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    exit;
}

function formatBytes($bytes, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];

    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }

    return round($bytes, $precision) . ' ' . $units[$i];
}

function sanitizeFilename($filename) {
    // Enlever les caractères spéciaux
    $filename = preg_replace('/[^a-zA-Z0-9\-\_\.]/', '_', $filename);
    // Éviter les doubles points
    $filename = preg_replace('/\.+/', '.', $filename);
    // Éviter les noms vides
    if (empty($filename) || $filename === '.') {
        $filename = 'file_' . time();
    }
    return $filename;
}

function isValidMediaFile($filename) {
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
    return in_array($ext, array_merge(
        ALLOWED_VIDEO_EXTENSIONS,
        ALLOWED_IMAGE_EXTENSIONS,
        ALLOWED_AUDIO_EXTENSIONS
    ));
}

function getUploadErrorMessage($errorCode) {
    switch ($errorCode) {
        case UPLOAD_ERR_INI_SIZE:
            return 'File exceeds upload_max_filesize in php.ini';
        case UPLOAD_ERR_FORM_SIZE:
            return 'File exceeds MAX_FILE_SIZE in form';
        case UPLOAD_ERR_PARTIAL:
            return 'File was only partially uploaded';
        case UPLOAD_ERR_NO_FILE:
            return 'No file was uploaded';
        case UPLOAD_ERR_NO_TMP_DIR:
            return 'Missing temporary folder';
        case UPLOAD_ERR_CANT_WRITE:
            return 'Failed to write file to disk';
        case UPLOAD_ERR_EXTENSION:
            return 'Upload stopped by extension';
        default:
            return 'Unknown upload error';
    }
}

// Créer les répertoires s'ils n'existent pas
foreach ([MEDIA_DIR, SCREENSHOTS_DIR, LOGS_DIR, PLAYLISTS_PATH, dirname(DB_PATH)] as $dir) {
    if (!is_dir($dir)) {
        mkdir($dir, 0755, true);
    }
}

// Initialiser la base de données
try {
    $db = new PDO('sqlite:' . DB_PATH);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Créer les tables si nécessaire
    $db->exec("
        CREATE TABLE IF NOT EXISTS media_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filename TEXT NOT NULL,
            original_name TEXT,
            file_size INTEGER,
            mime_type TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ");

    $db->exec("
        CREATE TABLE IF NOT EXISTS playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            items TEXT DEFAULT '[]',
            duration INTEGER DEFAULT 10,
            transition TEXT DEFAULT 'none',
            is_active INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ");

    $db->exec("
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ");
} catch (Exception $e) {
    // Base de données non disponible - mode dégradé
    $db = null;
}

// Fonction de log
function logMessage($message, $level = 'INFO') {
    $logFile = LOGS_DIR . '/system.log';
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[$timestamp] [$level] $message\n";
    @file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);
}

// Fonction pour exécuter des commandes système
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

// Fonction pour obtenir les fichiers média
function getMediaFiles() {
    $files = [];

    if (is_dir(MEDIA_DIR)) {
        $items = scandir(MEDIA_DIR);
        foreach ($items as $item) {
            if ($item === '.' || $item === '..') continue;

            $path = MEDIA_DIR . '/' . $item;
            if (is_file($path) && isValidMediaFile($item)) {
                $ext = strtolower(pathinfo($item, PATHINFO_EXTENSION));
                $type = 'other';

                if (in_array($ext, ALLOWED_VIDEO_EXTENSIONS)) {
                    $type = 'video';
                } elseif (in_array($ext, ALLOWED_IMAGE_EXTENSIONS)) {
                    $type = 'image';
                } elseif (in_array($ext, ALLOWED_AUDIO_EXTENSIONS)) {
                    $type = 'audio';
                }

                $files[] = [
                    'name' => $item,
                    'path' => '/media/' . $item,
                    'size' => filesize($path),
                    'size_formatted' => formatBytes(filesize($path)),
                    'type' => $type,
                    'extension' => $ext,
                    'modified' => filemtime($path),
                    'modified_date' => date('Y-m-d H:i:s', filemtime($path))
                ];
            }
        }
    }

    return $files;
}

// Ajuster les limites PHP dynamiquement si possible
@ini_set('upload_max_filesize', '500M');
@ini_set('post_max_size', '500M');
@ini_set('max_execution_time', '300');
@ini_set('max_input_time', '300');