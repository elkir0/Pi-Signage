<?php
/**
 * Fonctions de sécurité pour Pi Signage
 */

// Protection contre l'accès direct
if (!defined('PI_SIGNAGE_WEB')) {
    die('Direct access not allowed');
}

/**
 * Générer un token CSRF
 */
function generateCSRFToken() {
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

/**
 * Valider un token CSRF
 */
function validateCSRFToken($token) {
    if (empty($_SESSION['csrf_token']) || empty($token)) {
        return false;
    }
    return hash_equals($_SESSION['csrf_token'], $token);
}

/**
 * Définir les headers de sécurité HTTP
 */
function setSecurityHeaders() {
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
    header('X-XSS-Protection: 1; mode=block');
    header('Referrer-Policy: strict-origin-when-cross-origin');
    header('Content-Security-Policy: default-src \'self\'; script-src \'self\' \'unsafe-inline\'; style-src \'self\' \'unsafe-inline\';');
}

/**
 * Sanitiser une entrée utilisateur
 */
function sanitizeInput($input) {
    return htmlspecialchars(strip_tags(trim($input)), ENT_QUOTES, 'UTF-8');
}

/**
 * Valider un nom de fichier
 */
function isValidFilename($filename) {
    // Vérifier les caractères autorisés
    if (!preg_match('/^[a-zA-Z0-9._-]+$/', $filename)) {
        return false;
    }
    
    // Vérifier l'extension
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
    return in_array($ext, ALLOWED_EXTENSIONS);
}

/**
 * Logger une activité
 */
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

/**
 * Vérifier le taux de requêtes (rate limiting)
 */
function checkRateLimit($identifier, $maxAttempts = 5, $timeWindow = 300) {
    $cacheFile = sys_get_temp_dir() . '/pi_signage_rate_' . md5($identifier);
    
    $attempts = [];
    if (file_exists($cacheFile)) {
        $attempts = json_decode(file_get_contents($cacheFile), true) ?: [];
    }
    
    $now = time();
    $attempts = array_filter($attempts, function($timestamp) use ($now, $timeWindow) {
        return ($now - $timestamp) < $timeWindow;
    });
    
    if (count($attempts) >= $maxAttempts) {
        return false;
    }
    
    $attempts[] = $now;
    file_put_contents($cacheFile, json_encode($attempts));
    
    return true;
}

/**
 * Générer un mot de passe aléatoire sécurisé
 */
function generateSecurePassword($length = 16) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,.<>?';
    $password = '';
    $charLength = strlen($chars);
    
    for ($i = 0; $i < $length; $i++) {
        $password .= $chars[random_int(0, $charLength - 1)];
    }
    
    return $password;
}

/**
 * Valider une adresse IP
 */
function isValidIP($ip) {
    return filter_var($ip, FILTER_VALIDATE_IP) !== false;
}

/**
 * Obtenir l'adresse IP réelle du client
 */
function getClientIP() {
    $headers = [
        'HTTP_CLIENT_IP',
        'HTTP_X_FORWARDED_FOR',
        'HTTP_X_FORWARDED',
        'HTTP_X_CLUSTER_CLIENT_IP',
        'HTTP_FORWARDED_FOR',
        'HTTP_FORWARDED',
        'REMOTE_ADDR'
    ];
    
    foreach ($headers as $header) {
        if (isset($_SERVER[$header]) && !empty($_SERVER[$header])) {
            $ips = explode(',', $_SERVER[$header]);
            foreach ($ips as $ip) {
                $ip = trim($ip);
                if (isValidIP($ip)) {
                    return $ip;
                }
            }
        }
    }
    
    return '0.0.0.0';
}