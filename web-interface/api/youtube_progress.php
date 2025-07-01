<?php
/**
 * Suivi de progression de téléchargement YouTube (stub)
 * 
 * Cette API n'est pas implémentée actuellement mais est conservée
 * pour éviter les erreurs 404/400 dans la console.
 */

// Headers de base
header('Content-Type: application/json');
header('Cache-Control: no-cache, no-store, must-revalidate');

// Toujours retourner succès avec progression à 100%
// Cela évite toute erreur dans la console
echo json_encode([
    'success' => true,
    'progress' => 100,
    'message' => 'Progress tracking not implemented'
]);

// Fin du script
exit;