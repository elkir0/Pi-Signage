<?php
/**
 * Déconnexion Pi Signage
 */

define('PI_SIGNAGE_WEB', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';

// Déconnecter l'utilisateur
logoutUser();

// Rediriger vers la page de connexion
header('Location: index.php');
exit;