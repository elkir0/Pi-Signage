<?php
/**
 * PiSignage Desktop v3.0 - Déconnexion
 */

define('PISIGNAGE_DESKTOP', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';

// Déconnecter l'utilisateur
logout();

// Rediriger vers la page de connexion
header('Location: login.php');
exit;
?>