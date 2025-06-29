<?php
/**
 * Pi Signage Digital - Gestion des sessions
 * @version 2.0.0
 */

// Empêcher l'accès direct
if (!defined('INCLUDED')) {
    define('INCLUDED', true);
}

/**
 * Vérifier l'authentification et rediriger si nécessaire
 */
function checkAuth() {
    if (!isLoggedIn()) {
        header('Location: index.php');
        exit;
    }
    
    // Renouveler le timeout de session
    $_SESSION['login_time'] = time();
}

/**
 * Déconnexion
 */
function logout() {
    session_destroy();
    header('Location: index.php');
    exit;
}

/**
 * Obtenir l'IP du client
 */
function getClientIP() {
    $ipKeys = ['HTTP_X_FORWARDED_FOR', 'HTTP_CLIENT_IP', 'REMOTE_ADDR'];
    
    foreach ($ipKeys as $key) {
        if (array_key_exists($key, $_SERVER) === true) {
            foreach (explode(',', $_SERVER[$key]) as $ip) {
                $ip = trim($ip);
                
                if (filter_var($ip, FILTER_VALIDATE_IP, 
                    FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) !== false) {
                    return $ip;
                }
            }
        }
    }
    
    return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
}

/**
 * Vérifier le token CSRF
 */
function checkCSRF($token) {
    if (!isset($_SESSION['csrf_token']) || $token !== $_SESSION['csrf_token']) {
        die('CSRF token validation failed');
    }
}

/**
 * Générer un token CSRF
 */
function generateCSRF() {
    if (!isset($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

/**
 * Limiter le taux de requêtes
 */
function rateLimit($action, $maxAttempts = 5, $window = 300) {
    $key = 'rate_limit_' . $action . '_' . getClientIP();
    
    if (!isset($_SESSION[$key])) {
        $_SESSION[$key] = [
            'count' => 0,
            'first_attempt' => time()
        ];
    }
    
    $data = &$_SESSION[$key];
    
    // Réinitialiser si la fenêtre est expirée
    if (time() - $data['first_attempt'] > $window) {
        $data['count'] = 0;
        $data['first_attempt'] = time();
    }
    
    $data['count']++;
    
    if ($data['count'] > $maxAttempts) {
        header('HTTP/1.1 429 Too Many Requests');
        die('Too many requests. Please try again later.');
    }
}

/**
 * Nettoyer les sessions expirées (à appeler périodiquement)
 */
function cleanupSessions() {
    $sessionPath = session_save_path();
    if (empty($sessionPath)) {
        $sessionPath = '/var/lib/php/sessions/pi-signage';
    }
    
    if (is_dir($sessionPath)) {
        $files = glob($sessionPath . '/sess_*');
        $now = time();
        
        foreach ($files as $file) {
            if (is_file($file) && ($now - filemtime($file)) > SESSION_TIMEOUT) {
                unlink($file);
            }
        }
    }
}

/**
 * Initialiser la sécurité de session
 */
function initSessionSecurity() {
    // Régénérer l'ID de session périodiquement
    if (!isset($_SESSION['regenerated'])) {
        session_regenerate_id(true);
        $_SESSION['regenerated'] = time();
    } elseif (time() - $_SESSION['regenerated'] > 300) { // 5 minutes
        session_regenerate_id(true);
        $_SESSION['regenerated'] = time();
    }
    
    // Stocker l'empreinte du navigateur
    $fingerprint = md5(
        $_SERVER['HTTP_USER_AGENT'] . 
        $_SERVER['HTTP_ACCEPT_LANGUAGE'] . 
        $_SERVER['HTTP_ACCEPT_ENCODING']
    );
    
    if (!isset($_SESSION['fingerprint'])) {
        $_SESSION['fingerprint'] = $fingerprint;
    } elseif ($_SESSION['fingerprint'] !== $fingerprint) {
        session_destroy();
        header('Location: index.php');
        exit;
    }
}