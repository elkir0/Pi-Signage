<?php
/**
 * PiSignage v0.8.0 - Configuration File
 * Digital Signage Solution for Raspberry Pi
 */

// Version and general settings
define('PISIGNAGE_VERSION', '0.8.0');
define('PISIGNAGE_TITLE', 'PiSignage v0.8.0');

// Error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Paths
define('BASE_PATH', dirname(__DIR__));
define('MEDIA_PATH', BASE_PATH . '/media');
define('CONFIG_PATH', BASE_PATH . '/config');
define('LOGS_PATH', BASE_PATH . '/logs');
define('SCRIPTS_PATH', BASE_PATH . '/scripts');
define('PLAYLISTS_PATH', CONFIG_PATH . '/playlists');
define('SCHEDULES_PATH', CONFIG_PATH . '/schedules');
define('SCREENSHOTS_PATH', BASE_PATH . '/screenshots');

// Create directories if they don't exist
$dirs = [MEDIA_PATH, CONFIG_PATH, LOGS_PATH, SCRIPTS_PATH, PLAYLISTS_PATH, SCHEDULES_PATH, SCREENSHOTS_PATH];
foreach ($dirs as $dir) {
    if (!file_exists($dir)) {
        mkdir($dir, 0755, true);
    }
}

// VLC settings
define('VLC_HTTP_HOST', '127.0.0.1');
define('VLC_HTTP_PORT', '8080');
define('VLC_HTTP_PASSWORD', 'vlcpassword');

// File upload settings
define('MAX_UPLOAD_SIZE', 500 * 1024 * 1024); // 500MB
define('ALLOWED_EXTENSIONS', ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'mp3', 'wav', 'flac', 'ogg']);

// System settings
define('SCREENSHOT_INTERVAL', 30); // seconds
define('SYSTEM_STATS_INTERVAL', 5); // seconds

// Database settings (SQLite)
define('DB_PATH', CONFIG_PATH . '/pisignage.db');

// Initialize database
function initializeDatabase() {
    $db = new PDO('sqlite:' . DB_PATH);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Create tables
    $db->exec("
        CREATE TABLE IF NOT EXISTS playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            items TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ");

    $db->exec("
        CREATE TABLE IF NOT EXISTS schedules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            playlist_name TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            days TEXT NOT NULL,
            enabled INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ");

    $db->exec("
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ");

    $db->exec("
        CREATE TABLE IF NOT EXISTS media_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filename TEXT NOT NULL,
            original_name TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            mime_type TEXT NOT NULL,
            uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ");

    return $db;
}

// Utility functions
function jsonResponse($success, $data = null, $message = null) {
    header('Content-Type: application/json');
    echo json_encode([
        'success' => $success,
        'data' => $data,
        'message' => $message,
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    exit;
}

function logMessage($message, $level = 'INFO') {
    $logFile = LOGS_PATH . '/pisignage.log';
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[$timestamp] [$level] $message" . PHP_EOL;
    file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);
}

function executeCommand($command, $async = false) {
    logMessage("Executing command: $command");

    if ($async) {
        exec($command . ' > /dev/null 2>&1 &');
        return true;
    } else {
        exec($command, $output, $returnCode);
        return [
            'output' => $output,
            'return_code' => $returnCode,
            'success' => $returnCode === 0
        ];
    }
}

function getSystemStats() {
    $stats = [];

    // CPU usage
    $cpuLoad = sys_getloadavg();
    $stats['cpu'] = round($cpuLoad[0] * 100 / 4, 1); // Assuming 4 cores

    // Memory usage
    $memInfo = file_get_contents('/proc/meminfo');
    preg_match('/MemTotal:\s+(\d+)/', $memInfo, $memTotal);
    preg_match('/MemAvailable:\s+(\d+)/', $memInfo, $memAvailable);
    $memUsed = $memTotal[1] - $memAvailable[1];
    $stats['memory'] = round(($memUsed / $memTotal[1]) * 100, 1);

    // Temperature (Raspberry Pi specific)
    if (file_exists('/sys/class/thermal/thermal_zone0/temp')) {
        $temp = file_get_contents('/sys/class/thermal/thermal_zone0/temp');
        $stats['temperature'] = round($temp / 1000, 1);
    } else {
        $stats['temperature'] = 0;
    }

    // Uptime
    $uptime = file_get_contents('/proc/uptime');
    $uptimeSeconds = intval(explode(' ', $uptime)[0]);
    $stats['uptime'] = formatUptime($uptimeSeconds);

    // Storage
    $freeBytes = disk_free_space(BASE_PATH);
    $totalBytes = disk_total_space(BASE_PATH);
    $usedBytes = $totalBytes - $freeBytes;
    $stats['storage'] = round(($usedBytes / $totalBytes) * 100, 1) . '%';

    // Media count
    $mediaFiles = glob(MEDIA_PATH . '/*');
    $stats['media_count'] = count($mediaFiles);

    return $stats;
}

function formatUptime($seconds) {
    $days = floor($seconds / 86400);
    $hours = floor(($seconds % 86400) / 3600);
    $minutes = floor(($seconds % 3600) / 60);

    if ($days > 0) {
        return "{$days}j {$hours}h {$minutes}m";
    } elseif ($hours > 0) {
        return "{$hours}h {$minutes}m";
    } else {
        return "{$minutes}m";
    }
}

function getMediaFiles() {
    $files = [];
    $mediaFiles = glob(MEDIA_PATH . '/*');

    foreach ($mediaFiles as $file) {
        if (is_file($file)) {
            $extension = strtolower(pathinfo($file, PATHINFO_EXTENSION));
            if (in_array($extension, ALLOWED_EXTENSIONS)) {
                $files[] = [
                    'name' => basename($file),
                    'path' => $file,
                    'size' => filesize($file),
                    'type' => mime_content_type($file),
                    'extension' => $extension,
                    'modified' => filemtime($file)
                ];
            }
        }
    }

    // Sort by modification time (newest first)
    usort($files, function($a, $b) {
        return $b['modified'] - $a['modified'];
    });

    return $files;
}

function sanitizeFilename($filename) {
    // Remove any path components
    $filename = basename($filename);

    // Replace dangerous characters
    $filename = preg_replace('/[^a-zA-Z0-9._-]/', '_', $filename);

    // Remove multiple underscores
    $filename = preg_replace('/_+/', '_', $filename);

    return $filename;
}

function isValidMediaFile($filename) {
    $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
    return in_array($extension, ALLOWED_EXTENSIONS);
}

function vlcCommand($action, $params = []) {
    $url = 'http://' . VLC_HTTP_HOST . ':' . VLC_HTTP_PORT . '/requests/status.xml';

    if ($action !== 'status') {
        $url = 'http://' . VLC_HTTP_HOST . ':' . VLC_HTTP_PORT . '/requests/status.xml?command=' . $action;

        foreach ($params as $key => $value) {
            $url .= '&' . $key . '=' . urlencode($value);
        }
    }

    $context = stream_context_create([
        'http' => [
            'header' => 'Authorization: Basic ' . base64_encode(':' . VLC_HTTP_PASSWORD)
        ]
    ]);

    $result = @file_get_contents($url, false, $context);

    if ($result === false) {
        return false;
    }

    // Parse XML response
    $xml = @simplexml_load_string($result);

    if ($xml === false) {
        return false;
    }

    return [
        'state' => (string)$xml->state ?? 'stopped',
        'position' => (string)$xml->position ?? '0',
        'length' => (string)$xml->length ?? '0',
        'volume' => (string)$xml->volume ?? '0',
        'currentplentry' => (string)$xml->currentplentry ?? '0'
    ];
}

// Initialize database on include
try {
    $db = initializeDatabase();
} catch (Exception $e) {
    logMessage("Database initialization failed: " . $e->getMessage(), 'ERROR');
}

// Set timezone
date_default_timezone_set('Europe/Paris');

// Define common headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle OPTIONS requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}
?>