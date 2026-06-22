<?php
/**
 * PiSignage — DÉPRÉCIÉ. Remplacé par l'API unifiée /api/playlists.php (Phase 1+).
 *
 * Alias de compatibilité en LECTURE SEULE : GET renvoie encore la liste des playlists
 * (ancien contrat : data = tableau) au cas où un appelant n'aurait pas été migré.
 * Toute écriture renvoie 410 et pointe vers /api/playlists.php.
 */

require_once __DIR__ . '/_guard.php';
require_once __DIR__ . '/playlists-core.php'; // playlistListAll() + jsonResponse() (via config.php)

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Contrat historique : tableau de playlists (chacune avec name + slug + items).
    jsonResponse(true, playlistListAll(), 'Endpoint déprécié — utilisez /api/playlists.php');
}

jsonResponse(false, null, 'Endpoint déprécié — utilisez /api/playlists.php (POST pour créer/modifier).', 410);
