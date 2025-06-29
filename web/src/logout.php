<?php
/**
 * Pi Signage Digital - Déconnexion
 * @version 2.0.0
 */

session_start();
require_once 'includes/config.php';
require_once 'includes/functions.php';

// Log de la déconnexion
if (isset($_SESSION['user'])) {
    logAction('Logout', 'User: ' . $_SESSION['user']);
}

// Détruire la session
session_unset();
session_destroy();

// Supprimer le cookie de session
if (ini_get("session.use_cookies")) {
    $params = session_get_cookie_params();
    setcookie(session_name(), '', time() - 42000,
        $params["path"], $params["domain"],
        $params["secure"], $params["httponly"]
    );
}

// Redirection vers la page de connexion
header('Location: index.php');
exit;