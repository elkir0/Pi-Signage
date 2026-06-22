<?php
/**
 * PiSignage — API PLAYLISTS UNIFIÉE (Phase 1 de l'unification diffusion).
 *
 * UNE source de vérité pour les playlists nommées + la notion de "playlist ACTIVE".
 * - Stockage : PLAYLISTS_PATH/<slug>.json, SCHÉMA UNIQUE basé sur `url`
 *   { name, slug, version, autoplay, autoLoop, items:[{url,type,name,duration,fit,mute,loop,transition}] }
 * - Migration tolérante à la lecture : accepte aussi l'ancien format éditeur {file,duration,transition,order}
 *   (playlist-simple.php) et le convertit en {url:/media/<file>}.
 * - "Diffuser" (activate) : écrit le contenu de la playlist dans /opt/pisignage/media/playlist.json
 *   (ce que lit le player kiosk via GET /api/playlist) en bumpant `version` -> l'écran se met à jour
 *   tout seul (le player poll la version). Le slug actif est mémorisé dans config/active-playlist.json.
 *
 *   GET    /api/playlists.php                 -> { playlists:[...], active:"slug"|null }
 *   GET    /api/playlists.php?name=X          -> la playlist X (normalisée) ou exists:false
 *   POST   /api/playlists.php                 -> créer/mettre à jour (body: {name, items, autoplay, autoLoop})
 *   POST   /api/playlists.php?action=activate&name=X  -> diffuser X à l'écran (= playlist active)
 *   DELETE /api/playlists.php?name=X          -> supprimer la playlist X
 */

require_once __DIR__ . '/_guard.php';
require_once __DIR__ . '/playlists-core.php'; // modèle + activation partagés (inclut config.php)

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

switch ($method) {
    case 'GET':
        if (isset($_GET['name'])) {
            $pl = playlistLoad($_GET['name']);
            jsonResponse($pl !== null, $pl !== null ? $pl : ['exists' => false],
                $pl !== null ? 'Playlist' : 'Playlist introuvable');
        } else {
            jsonResponse(true, ['playlists' => playlistListAll(), 'active' => playlistActiveSlug()]);
        }
        break;

    case 'POST':
        if ($action === 'activate') {
            handleActivate($_GET['name'] ?? '');
        } else {
            handleSave(json_decode(file_get_contents('php://input'), true));
        }
        break;

    case 'DELETE':
        handleDelete($_GET['name'] ?? '');
        break;

    default:
        jsonResponse(false, null, 'Méthode non autorisée', 405);
}

/* Modèle (playlistSlug, playlistNormalize*, playlistLoad, playlistListAll,
   playlistActiveSlug, playlistPushLive, playlistSignalReload, playlistActivateByName)
   est défini dans playlists-core.php (partagé avec le scheduler). */

/* ============================ Handlers ============================ */

function handleSave($input) {
    if (!is_array($input) || empty($input['name'])) {
        jsonResponse(false, null, 'Nom de playlist requis', 400);
        return;
    }
    $pl = playlistNormalize($input);
    if ($pl === null) {
        jsonResponse(false, null, 'Playlist invalide', 422);
        return;
    }
    if (!is_dir(PLAYLISTS_PATH)) { @mkdir(PLAYLISTS_PATH, 0775, true); }

    $file = rtrim(PLAYLISTS_PATH, '/') . '/' . $pl['slug'] . '.json';
    $stored = [
        'name'     => $pl['name'],
        'slug'     => $pl['slug'],
        'version'  => $pl['version'],
        'autoplay' => $pl['autoplay'],
        'autoLoop' => $pl['autoLoop'],
        'items'    => $pl['items'],
        'modified' => date('Y-m-d H:i:s'),
    ];
    if (@file_put_contents($file, json_encode($stored, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)) === false) {
        jsonResponse(false, null, 'Échec de l\'écriture de la playlist', 500);
        return;
    }
    @chmod($file, 0664);
    if (function_exists('logMessage')) logMessage('Playlist enregistrée: ' . $pl['slug'] . ' (' . count($pl['items']) . ' items)');

    // Si la playlist enregistrée est celle actuellement diffusée, on rafraîchit l'écran.
    if (playlistActiveSlug() === $pl['slug']) {
        playlistPushLive($pl);
    }
    jsonResponse(true, $stored, 'Playlist enregistrée');
}

function handleDelete($name) {
    if ($name === '') { jsonResponse(false, null, 'Nom requis', 400); return; }
    $slug = playlistSlug($name);
    $file = rtrim(PLAYLISTS_PATH, '/') . '/' . $slug . '.json';
    if (!is_file($file)) { jsonResponse(false, null, 'Playlist introuvable', 404); return; }
    if (!@unlink($file)) { jsonResponse(false, null, 'Échec de la suppression', 500); return; }
    if (playlistActiveSlug() === $slug) { @unlink(ACTIVE_PLAYLIST_FILE); }
    if (function_exists('logMessage')) logMessage('Playlist supprimée: ' . $slug);
    jsonResponse(true, null, 'Playlist supprimée');
}

/** "Diffuser à l'écran" : la playlist devient ACTIVE et son contenu est poussé au player. */
function handleActivate($name) {
    if ($name === '') { jsonResponse(false, null, 'Nom requis', 400); return; }
    $pl = playlistActivateByName($name); // playlists-core.php : pushLive + pointeur actif
    if ($pl === null)  { jsonResponse(false, null, 'Playlist introuvable', 404); return; }
    if ($pl === false) { jsonResponse(false, null, 'Échec de la mise à l\'écran', 500); return; }
    if (function_exists('logMessage')) logMessage('Playlist diffusée à l\'écran: ' . $pl['slug']);
    jsonResponse(true, ['slug' => $pl['slug'], 'items' => count($pl['items'])], 'Playlist diffusée à l\'écran');
}
