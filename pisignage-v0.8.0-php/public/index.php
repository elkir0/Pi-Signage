<?php
/**
 * PiSignage v0.8.0 - Digital Signage System
 * Main entry point - Clean PHP architecture
 */

define('VERSION', '0.8.0');
define('ROOT_PATH', dirname(__DIR__));
define('MEDIA_PATH', ROOT_PATH . '/media');
define('LOGS_PATH', ROOT_PATH . '/logs');

// Simple autoloader (no Composer needed for lightweight deployment)
spl_autoload_register(function ($class) {
    $file = ROOT_PATH . '/src/' . str_replace('\\', '/', $class) . '.php';
    if (file_exists($file)) {
        require $file;
    }
});

// Initialize error handling
error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');
ini_set('error_log', LOGS_PATH . '/error.log');

// Simple routing without framework
$request_uri = $_SERVER['REQUEST_URI'];
$request_method = $_SERVER['REQUEST_METHOD'];

// Remove query string
$path = parse_url($request_uri, PHP_URL_PATH);

// API routes
if (strpos($path, '/api/') === 0) {
    header('Content-Type: application/json');

    // Remove query string from path
    $api_path = str_replace('/api/', '', explode('?', $path)[0]);

    switch($api_path) {
        case 'screenshot':
            require __DIR__ . '/api/screenshot.php';
            break;
        case 'media':
        case 'media/upload':
            require __DIR__ . '/api/media.php';
            break;
        case 'youtube':
            require __DIR__ . '/api/youtube.php';
            break;
        case 'system':
            require __DIR__ . '/api/system.php';
            break;
        case 'playlist':
            require __DIR__ . '/api/playlist.php';
            break;
        default:
            http_response_code(404);
            echo json_encode(['error' => 'API endpoint not found: ' . $api_path]);
    }
    exit;
}

// Serve static files
$static_extensions = ['css', 'js', 'png', 'jpg', 'jpeg', 'gif', 'svg', 'ico'];
$extension = pathinfo($path, PATHINFO_EXTENSION);
if (in_array($extension, $static_extensions)) {
    $file_path = ROOT_PATH . '/assets' . $path;
    if (file_exists($file_path)) {
        $mime_types = [
            'css' => 'text/css',
            'js' => 'application/javascript',
            'png' => 'image/png',
            'jpg' => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'gif' => 'image/gif',
            'svg' => 'image/svg+xml',
            'ico' => 'image/x-icon'
        ];
        header('Content-Type: ' . ($mime_types[$extension] ?? 'application/octet-stream'));
        readfile($file_path);
        exit;
    }
}

// Main dashboard
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage v0.8.0</title>
    <link rel="stylesheet" href="/design-system.css">
</head>
<body>
    <div class="ps-container">
        <header class="ps-header">
            <div class="ps-logo">
                <svg class="ps-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect>
                    <line x1="8" y1="21" x2="16" y2="21"></line>
                    <line x1="12" y1="17" x2="12" y2="21"></line>
                </svg>
                <span>PiSignage</span>
                <span class="ps-version">v0.8.0</span>
            </div>
            <div class="ps-status">
                <span class="ps-indicator ps-indicator--success"></span>
                <span>En ligne</span>
            </div>
        </header>

        <nav class="ps-nav">
            <button class="ps-nav-item ps-nav-item--active" data-tab="monitoring">
                <svg class="ps-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
                </svg>
                Monitoring
            </button>
            <button class="ps-nav-item" data-tab="content">
                <svg class="ps-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"/>
                </svg>
                Contenu
            </button>
            <button class="ps-nav-item" data-tab="broadcast">
                <svg class="ps-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polygon points="5 3 19 12 5 21 5 3"></polygon>
                </svg>
                Diffusion
            </button>
            <button class="ps-nav-item" data-tab="system">
                <svg class="ps-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="3"></circle>
                    <path d="M12 1v6m0 6v6m4.22-13.22l4.24 4.24M1.54 9.54l4.24 4.24m12.68 0l4.24 4.24M1.54 14.46l4.24-4.24"/>
                </svg>
                Système
            </button>
        </nav>

        <main class="ps-main" id="main-content">
            <!-- Content will be loaded here via JavaScript -->
            <div class="ps-loading">
                <div class="ps-spinner"></div>
                <p>Chargement...</p>
            </div>
        </main>
    </div>

    <script src="/app.js"></script>
</body>
</html>