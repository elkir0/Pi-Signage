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
require_once '../config.php';

header('Content-Type: application/json');

if (!defined('ACTIVE_PLAYLIST_FILE')) {
    define('ACTIVE_PLAYLIST_FILE', CONFIG_PATH . '/active-playlist.json');
}
// Fichier réellement lu par le player kiosk (GET /api/playlist le sert).
if (!defined('LIVE_PLAYLIST_FILE')) {
    define('LIVE_PLAYLIST_FILE', rtrim(MEDIA_PATH, '/') . '/playlist.json');
}

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

/* ============================ Helpers modèle ============================ */

/** Slug de fichier sûr à partir d'un nom de playlist. */
function playlistSlug($name) {
    $s = strtolower(trim((string)$name));
    $s = preg_replace('/[^a-z0-9._-]+/u', '-', $s);
    $s = trim($s, '-._');
    return $s !== '' ? substr($s, 0, 80) : 'playlist';
}

/** Type média d'après l'extension. */
function playlistGuessType($pathOrUrl) {
    $ext = strtolower(pathinfo(parse_url((string)$pathOrUrl, PHP_URL_PATH) ?: (string)$pathOrUrl, PATHINFO_EXTENSION));
    if (in_array($ext, ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'], true)) return 'image';
    if (in_array($ext, ['mp3', 'wav', 'ogg', 'm4a', 'flac', 'aac'], true)) return 'audio';
    return 'video';
}

/**
 * Normalise un item de playlist vers le schéma UNIQUE {url,type,name,duration,fit,mute,loop,transition}.
 * Accepte l'ancien format {file,...} (migration) et le format {url,...}.
 */
function playlistNormalizeItem($item) {
    if (!is_array($item)) return null;

    // url directe, sinon dérivée de `file` (ancien format éditeur), sinon rien.
    $url = '';
    if (!empty($item['url'])) {
        $url = (string)$item['url'];
    } elseif (!empty($item['file'])) {
        $url = '/media/' . rawurlencode(basename((string)$item['file']));
    }
    if ($url === '') return null;

    // Nom lisible.
    $name = $item['name'] ?? basename(parse_url($url, PHP_URL_PATH) ?: $url);
    $name = rawurldecode((string)$name);

    $fit = (isset($item['fit']) && in_array($item['fit'], ['contain', 'cover'], true)) ? $item['fit'] : 'contain';
    $duration = isset($item['duration']) && is_numeric($item['duration']) ? (float)$item['duration'] : 0;
    if ($duration < 0) $duration = 0;

    return [
        'url'        => $url,
        'type'       => (isset($item['type']) && $item['type'] !== '') ? (string)$item['type'] : playlistGuessType($url),
        'name'       => $name,
        'duration'   => $duration,
        'fit'        => $fit,
        'mute'       => !empty($item['mute']),
        'loop'       => !empty($item['loop']),
        'transition' => isset($item['transition']) ? (string)$item['transition'] : 'none',
    ];
}

/** Construit l'objet playlist unifié à partir d'un input/raw (tolérant aux 2 formats). */
function playlistNormalize($raw, $slugHint = null) {
    if (!is_array($raw)) return null;
    $name = isset($raw['name']) && $raw['name'] !== '' ? (string)$raw['name'] : ($slugHint ?: 'Playlist');
    $slug = $slugHint ?: playlistSlug($name);

    $items = [];
    foreach (($raw['items'] ?? []) as $it) {
        $n = playlistNormalizeItem($it);
        if ($n !== null) $items[] = $n;
    }

    // autoplay/autoLoop : depuis le format url, sinon depuis settings{} de l'ancien format.
    $settings = is_array($raw['settings'] ?? null) ? $raw['settings'] : [];
    $autoplay = array_key_exists('autoplay', $raw) ? (bool)$raw['autoplay']
              : (array_key_exists('auto_advance', $settings) ? (bool)$settings['auto_advance'] : true);
    $autoLoop = array_key_exists('autoLoop', $raw) ? (bool)$raw['autoLoop']
              : (array_key_exists('loop', $settings) ? (bool)$settings['loop'] : true);

    return [
        'name'     => $name,
        'slug'     => $slug,
        'version'  => isset($raw['version']) && is_numeric($raw['version']) ? (int)$raw['version'] : 1,
        'autoplay' => $autoplay,
        'autoLoop' => $autoLoop,
        'items'    => $items,
    ];
}

/** Charge + normalise une playlist nommée. null si introuvable. */
function playlistLoad($name) {
    $slug = playlistSlug($name);
    $file = rtrim(PLAYLISTS_PATH, '/') . '/' . $slug . '.json';
    if (!is_file($file)) return null;
    $raw = json_decode((string)file_get_contents($file), true);
    if (!is_array($raw)) return null;
    $pl = playlistNormalize($raw, $slug);
    $pl['modified'] = filemtime($file);
    return $pl;
}

/** Liste toutes les playlists nommées (normalisées, plus récentes d'abord). */
function playlistListAll() {
    $out = [];
    if (is_dir(PLAYLISTS_PATH)) {
        foreach (glob(rtrim(PLAYLISTS_PATH, '/') . '/*.json') as $file) {
            $raw = json_decode((string)file_get_contents($file), true);
            if (!is_array($raw)) continue;
            $pl = playlistNormalize($raw, pathinfo($file, PATHINFO_FILENAME));
            $pl['modified'] = filemtime($file);
            $pl['item_count'] = count($pl['items']);
            $out[] = $pl;
        }
        usort($out, function ($a, $b) { return ($b['modified'] ?? 0) - ($a['modified'] ?? 0); });
    }
    return $out;
}

/** Slug de la playlist actuellement diffusée à l'écran (ou null). */
function playlistActiveSlug() {
    if (is_file(ACTIVE_PLAYLIST_FILE)) {
        $d = json_decode((string)file_get_contents(ACTIVE_PLAYLIST_FILE), true);
        if (is_array($d) && !empty($d['slug'])) return (string)$d['slug'];
    }
    return null;
}

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
    $pl = playlistLoad($name);
    if ($pl === null) { jsonResponse(false, null, 'Playlist introuvable', 404); return; }

    if (!playlistPushLive($pl)) {
        jsonResponse(false, null, 'Échec de la mise à l\'écran', 500);
        return;
    }
    // Mémoriser le slug actif.
    @file_put_contents(ACTIVE_PLAYLIST_FILE, json_encode(
        ['slug' => $pl['slug'], 'name' => $pl['name'], 'activated_at' => date('Y-m-d H:i:s')],
        JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    @chmod(ACTIVE_PLAYLIST_FILE, 0664);
    if (function_exists('logMessage')) logMessage('Playlist diffusée à l\'écran: ' . $pl['slug']);

    jsonResponse(true, ['slug' => $pl['slug'], 'items' => count($pl['items'])], 'Playlist diffusée à l\'écran');
}

/**
 * Écrit le contenu de la playlist dans LIVE_PLAYLIST_FILE (media/playlist.json) au schéma attendu
 * par le player kiosk, en BUMPANT version -> le player (poll 10s) recharge automatiquement.
 */
function playlistPushLive($pl) {
    $prevVersion = 0;
    if (is_file(LIVE_PLAYLIST_FILE)) {
        $prev = json_decode((string)file_get_contents(LIVE_PLAYLIST_FILE), true);
        if (is_array($prev) && isset($prev['version']) && is_numeric($prev['version'])) {
            $prevVersion = (int)$prev['version'];
        }
    }
    $live = [
        'version'  => $prevVersion + 1,
        'name'     => $pl['name'],
        'autoplay' => $pl['autoplay'],
        'autoLoop' => $pl['autoLoop'],
        'items'    => array_map(function ($it) {
            // Schéma exact consommé par player.php (clé url + métadonnées).
            return [
                'url'      => $it['url'],
                'type'     => $it['type'],
                'name'     => $it['name'],
                'duration' => $it['duration'],
                'fit'      => $it['fit'],
                'mute'     => $it['mute'],
                'loop'     => $it['loop'],
            ];
        }, $pl['items']),
    ];
    // Écriture atomique.
    $dir = dirname(LIVE_PLAYLIST_FILE);
    $tmp = @tempnam($dir, '.playlist.');
    if ($tmp === false) return false;
    if (@file_put_contents($tmp, json_encode($live, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)) === false) {
        @unlink($tmp);
        return false;
    }
    @chmod($tmp, 0664);
    if (!@rename($tmp, LIVE_PLAYLIST_FILE)) { @unlink($tmp); return false; }
    return true;
}
