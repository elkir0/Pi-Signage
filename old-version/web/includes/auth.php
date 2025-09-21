<?php
/**
 * PiSignage Desktop v3.0 - Authentification simplifiée
 */

// Protection contre l'accès direct
if (!defined('PISIGNAGE_DESKTOP')) {
    die('Direct access not allowed');
}

/**
 * Démarrer une session sécurisée
 */
function startSecureSession() {
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
}

/**
 * Vérifier l'authentification
 */
function isAuthenticated() {
    startSecureSession();
    return isset($_SESSION['authenticated']) && $_SESSION['authenticated'] === true 
           && isset($_SESSION['user']) && $_SESSION['user'] === ADMIN_USERNAME;
}

/**
 * Authentifier un utilisateur
 */
function authenticate($username, $password) {
    // Vérification basique
    if ($username === ADMIN_USERNAME && $password === ADMIN_PASSWORD) {
        startSecureSession();
        
        // Régénérer l'ID de session pour la sécurité
        session_regenerate_id(true);
        
        $_SESSION['authenticated'] = true;
        $_SESSION['user'] = $username;
        $_SESSION['login_time'] = time();
        
        return true;
    }
    
    return false;
}

/**
 * Déconnecter l'utilisateur
 */
function logout() {
    startSecureSession();
    
    // Détruire toutes les données de session
    $_SESSION = array();
    
    // Détruire le cookie de session
    if (ini_get("session.use_cookies")) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000,
            $params["path"], $params["domain"],
            $params["secure"], $params["httponly"]
        );
    }
    
    // Détruire la session
    session_destroy();
}

/**
 * Exiger une authentification
 */
function requireAuth() {
    if (!isAuthenticated()) {
        header('Location: login.php');
        exit;
    }
    
    // Vérifier l'expiration de la session
    if (isset($_SESSION['login_time']) && (time() - $_SESSION['login_time']) > SESSION_LIFETIME) {
        logout();
        header('Location: login.php?expired=1');
        exit;
    }
}

/**
 * Générer un token CSRF
 */
function generateCSRFToken() {
    startSecureSession();
    
    if (!isset($_SESSION['csrf_token']) || !isset($_SESSION['csrf_token_time']) 
        || (time() - $_SESSION['csrf_token_time']) > CSRF_TOKEN_LIFETIME) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        $_SESSION['csrf_token_time'] = time();
    }
    
    return $_SESSION['csrf_token'];
}

/**
 * Vérifier un token CSRF
 */
function verifyCSRFToken($token) {
    startSecureSession();
    
    if (!isset($_SESSION['csrf_token']) || !isset($_SESSION['csrf_token_time'])) {
        return false;
    }
    
    // Vérifier l'expiration
    if ((time() - $_SESSION['csrf_token_time']) > CSRF_TOKEN_LIFETIME) {
        return false;
    }
    
    // Comparaison sécurisée
    return hash_equals($_SESSION['csrf_token'], $token);
}

/**
 * Définir les headers de sécurité
 */
function setSecurityHeaders() {
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
    header('X-XSS-Protection: 1; mode=block');
    header('Referrer-Policy: strict-origin-when-cross-origin');
}