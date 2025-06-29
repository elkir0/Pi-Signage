<?php
/**
 * Gestion de l'authentification pour Pi Signage
 */

// Protection contre l'accès direct
if (!defined('PI_SIGNAGE_WEB')) {
    die('Direct access not allowed');
}

require_once __DIR__ . '/security.php';

/**
 * Démarrer une session sécurisée
 */
function startSecureSession() {
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
}

/**
 * Valider les identifiants de connexion
 */
function validateCredentials($username, $password) {
    return $username === ADMIN_USERNAME && password_verify($password, ADMIN_PASSWORD_HASH);
}

/**
 * Connecter un utilisateur
 */
function loginUser($username) {
    startSecureSession();
    
    $_SESSION['authenticated'] = true;
    $_SESSION['username'] = $username;
    $_SESSION['last_activity'] = time();
    $_SESSION['login_time'] = time();
    $_SESSION['ip_address'] = getClientIP();
    
    // Regénérer l'ID de session pour prévenir le session fixation
    session_regenerate_id(true);
    
    logActivity('LOGIN_SUCCESS');
    
    return true;
}

/**
 * Déconnecter l'utilisateur actuel
 */
function logoutUser() {
    startSecureSession();
    
    logActivity('LOGOUT');
    
    // Détruire toutes les données de session
    $_SESSION = [];
    
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
 * Vérifier si l'utilisateur est authentifié
 */
function isAuthenticated() {
    startSecureSession();
    
    // Vérifier l'existence de la session
    if (!isset($_SESSION['authenticated']) || $_SESSION['authenticated'] !== true) {
        return false;
    }
    
    // Vérifier le timeout de session
    if (isset($_SESSION['last_activity']) && (time() - $_SESSION['last_activity'] > SESSION_LIFETIME)) {
        logoutUser();
        return false;
    }
    
    // Vérifier l'IP (optionnel, peut causer des problèmes avec les proxies)
    if (isset($_SESSION['ip_address']) && $_SESSION['ip_address'] !== getClientIP()) {
        logActivity('SESSION_IP_MISMATCH', 'Expected: ' . $_SESSION['ip_address'] . ', Got: ' . getClientIP());
        logoutUser();
        return false;
    }
    
    // Mettre à jour l'activité
    $_SESSION['last_activity'] = time();
    
    return true;
}

/**
 * Forcer l'authentification
 */
function requireAuth() {
    if (!isAuthenticated()) {
        header('Location: /index.php?redirect=' . urlencode($_SERVER['REQUEST_URI']));
        exit;
    }
}

/**
 * Obtenir les informations de l'utilisateur connecté
 */
function getCurrentUser() {
    if (!isAuthenticated()) {
        return null;
    }
    
    return [
        'username' => $_SESSION['username'] ?? 'unknown',
        'login_time' => $_SESSION['login_time'] ?? null,
        'last_activity' => $_SESSION['last_activity'] ?? null
    ];
}

/**
 * Vérifier si la session est sur le point d'expirer
 */
function isSessionExpiringSoon($threshold = 300) {
    if (!isAuthenticated()) {
        return false;
    }
    
    $timeLeft = SESSION_LIFETIME - (time() - $_SESSION['last_activity']);
    return $timeLeft <= $threshold;
}

/**
 * Renouveler la session
 */
function renewSession() {
    if (isAuthenticated()) {
        $_SESSION['last_activity'] = time();
        session_regenerate_id(true);
        return true;
    }
    return false;
}