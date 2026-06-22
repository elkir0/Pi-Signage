<?php
/**
 * PiSignage v0.11.0 - Authentication and Session Management
 * Handles session initialization and configuration management
 * v0.11.0: MPV support removed - VLC exclusive for better reliability
 */

// Start session if not already started
if (session_status() === PHP_SESSION_NONE) {
    // secure=false imposé par LAN HTTP pur (pas de TLS). Passer 'secure'=>true dès qu'on sert en HTTPS.
    session_set_cookie_params(['lifetime' => 0, 'path' => '/', 'httponly' => true, 'samesite' => 'Lax', 'secure' => false]);
    session_start();
}

// Asset cache-busting version (bump when CSS/JS change). Single source of truth.
if (!defined('ASSET_VERSION')) {
    define('ASSET_VERSION', '0.12.6');
}

// Configuration
$config = [
    'version' => '0.12.0',
    'media_path' => '/opt/pisignage/media/',
    'config_path' => '/opt/pisignage/config/',
    'logs_path' => '/opt/pisignage/logs/',
    'upload_max_size' => 500 * 1024 * 1024, // 500MB
    'credentials_file' => '/opt/pisignage/config/credentials.json',
];

// Ensure directories exist
$dirs = [$config['media_path'], $config['config_path'], $config['logs_path']];
foreach ($dirs as $dir) {
    if (!file_exists($dir)) {
        mkdir($dir, 0755, true);
    }
}

// Initialize default credentials if file doesn't exist
function initializeCredentials() {
    global $config;
    if (!file_exists($config['credentials_file'])) {
        $defaultCredentials = [
            'username' => 'admin',
            'password' => password_hash('signage2025', PASSWORD_BCRYPT, ['cost' => 12])
        ];
        file_put_contents($config['credentials_file'], json_encode($defaultCredentials, JSON_PRETTY_PRINT));
        chmod($config['credentials_file'], 0600); // Secure file permissions
    }
}

// Load credentials
function loadCredentials() {
    global $config;
    initializeCredentials();
    $data = file_get_contents($config['credentials_file']);
    return json_decode($data, true);
}

// Verify login credentials
function verifyLogin($username, $password) {
    global $config;
    $credentials = loadCredentials();
    if ($username === $credentials['username'] && password_verify($password, $credentials['password'])) {
        $_SESSION['authenticated'] = true;
        $_SESSION['username'] = $username;
        $_SESSION['login_time'] = time();
        session_regenerate_id(true);
        if (password_verify('signage2025', $credentials['password'])) {
            $_SESSION['must_change_password'] = true;
        }
        // Rehash transparent vers cost=12 (écriture atomique).
        if (password_needs_rehash($credentials['password'], PASSWORD_BCRYPT, ['cost' => 12])) {
            $credentials['password'] = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
            $tmp = $config['credentials_file'] . '.tmp';
            file_put_contents($tmp, json_encode($credentials, JSON_PRETTY_PRINT));
            chmod($tmp, 0600);
            rename($tmp, $config['credentials_file']);
        }
        return true;
    }
    return false;
}

// Update password
function updatePassword($oldPassword, $newPassword) {
    global $config;
    $credentials = loadCredentials();

    if (!password_verify($oldPassword, $credentials['password'])) {
        return ['success' => false, 'message' => 'Ancien mot de passe incorrect'];
    }

    if ($newPassword === 'signage2025') {
        return ['success' => false, 'message' => 'Mot de passe par défaut interdit'];
    }

    $credentials['password'] = password_hash($newPassword, PASSWORD_BCRYPT, ['cost' => 12]);
    if (file_put_contents($config['credentials_file'], json_encode($credentials, JSON_PRETTY_PRINT))) {
        chmod($config['credentials_file'], 0600);
        unset($_SESSION['must_change_password']);
        return ['success' => true, 'message' => 'Mot de passe mis à jour'];
    }

    return ['success' => false, 'message' => 'Erreur lors de la sauvegarde'];
}

// Check if user is authenticated
function isAuthenticated() {
    return isset($_SESSION['authenticated']) && $_SESSION['authenticated'] === true;
}

// Require authentication (redirect to login if not authenticated)
function requireAuth() {
    if (!isAuthenticated()) {
        $currentPage = $_SERVER['REQUEST_URI'];
        $_SESSION['redirect_after_login'] = $currentPage;
        header('Location: /login.php');
        exit;
    }

    // Forcer le changement du mot de passe par défaut (pages WEB uniquement).
    // Ne JAMAIS appliquer au player public ni à GET /api/playlist.
    if (!empty($_SESSION['must_change_password'])) {
        $page = getCurrentPage();
        if (!in_array($page, ['login', 'settings', 'player', 'playlist'], true)) {
            header('Location: /settings.php');
            exit;
        }
    }
}

// Logout function
function logout() {
    session_destroy();
    header('Location: /login.php');
    exit;
}

function getCurrentPage() {
    $scriptName = basename($_SERVER['SCRIPT_NAME'], '.php');
    return $scriptName;
}

// Initialize credentials on first load
initializeCredentials();
?>