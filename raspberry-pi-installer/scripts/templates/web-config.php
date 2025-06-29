<?php
/**
 * Configuration de base pour l'interface web Pi Signage
 * Ce fichier sera copié dans /var/www/pi-signage/includes/config.php
 */

// Protection contre l'accès direct
if (!defined('PI_SIGNAGE_WEB')) {
    define('PI_SIGNAGE_WEB', true);
}

// Configuration de session sécurisée
ini_set('session.cookie_httponly', '1');
ini_set('session.use_only_cookies', '1');
ini_set('session.cookie_secure', '0'); // Mettre à 1 si HTTPS
ini_set('session.cookie_samesite', 'Strict');

// Chemins système
define('VIDEO_DIR', '/opt/videos');
define('SCRIPTS_DIR', '/opt/scripts');
define('LOG_DIR', '/var/log/pi-signage');

// Configuration d'authentification
// Le hash du mot de passe sera injecté lors de l'installation
define('ADMIN_USERNAME', 'admin');
define('ADMIN_PASSWORD_HASH', '{{WEB_ADMIN_PASSWORD_HASH}}');

// Configuration VLC
define('VLC_SERVICE', 'vlc-signage.service');
define('VLC_HTTP_HOST', '127.0.0.1');
define('VLC_HTTP_PORT', '8080');

// Configuration Glances
define('GLANCES_URL', 'http://localhost:61208');

// Limite de taille d'upload (en MB)
define('MAX_UPLOAD_SIZE', 100);

// Extensions autorisées pour l'upload
define('ALLOWED_EXTENSIONS', ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v']);

// Durée de session (en secondes)
define('SESSION_LIFETIME', 3600); // 1 heure

// Protection CSRF
function generateCSRFToken() {
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function validateCSRFToken($token) {
    if (empty($_SESSION['csrf_token']) || empty($token)) {
        return false;
    }
    return hash_equals($_SESSION['csrf_token'], $token);
}

// Fonction de validation du mot de passe
function validatePassword($password) {
    return password_verify($password, ADMIN_PASSWORD_HASH);
}

// Fonction de vérification d'authentification
function checkAuth() {
    session_start();
    
    // Vérifier la durée de vie de la session
    if (isset($_SESSION['last_activity']) && (time() - $_SESSION['last_activity'] > SESSION_LIFETIME)) {
        session_unset();
        session_destroy();
        return false;
    }
    
    $_SESSION['last_activity'] = time();
    
    return isset($_SESSION['authenticated']) && $_SESSION['authenticated'] === true;
}

// Headers de sécurité
function setSecurityHeaders() {
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
    header('X-XSS-Protection: 1; mode=block');
    header('Referrer-Policy: strict-origin-when-cross-origin');
    header('Content-Security-Policy: default-src \'self\'; script-src \'self\' \'unsafe-inline\'; style-src \'self\' \'unsafe-inline\';');
}

// Fonction de logging sécurisé
function logActivity($action, $details = '') {
    $logFile = LOG_DIR . '/web-activity.log';
    $timestamp = date('Y-m-d H:i:s');
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $user = $_SESSION['username'] ?? 'anonymous';
    
    $logEntry = sprintf(
        "[%s] IP:%s User:%s Action:%s %s\n",
        $timestamp,
        $ip,
        $user,
        $action,
        $details
    );
    
    error_log($logEntry, 3, $logFile);
}

// Fonction de sanitisation des entrées
function sanitizeInput($input) {
    return htmlspecialchars(strip_tags(trim($input)), ENT_QUOTES, 'UTF-8');
}

// Fonction de validation des noms de fichiers
function isValidFilename($filename) {
    // Vérifier les caractères autorisés
    if (!preg_match('/^[a-zA-Z0-9._-]+$/', $filename)) {
        return false;
    }
    
    // Vérifier l'extension
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
    return in_array($ext, ALLOWED_EXTENSIONS);
}