<?php
/**
 * PiSignage — NOYAU PLAYLISTS (modèle unifié, sans effet HTTP).
 *
 * Fonctions partagées par :
 *   - api/playlists.php  (endpoint CRUD + activate, côté HTTP)
 *   - api/scheduler.php  (exécuteur cron de programmation, côté CLI)
 *
 * Source de vérité unique pour : schéma d'item, normalisation (migration ancien format
 * {file} -> {url}), chargement/listing, pointeur "playlist active", poussée LIVE vers le
 * player (media/playlist.json + bump version + signal reload). AUCUNE sortie HTTP ici :
 * pas de header(), pas de jsonResponse(), pas d'echo — réutilisable en CLI.
 */

require_once __DIR__ . '/../config.php';

if (!defined('ACTIVE_PLAYLIST_FILE')) {
    define('ACTIVE_PLAYLIST_FILE', CONFIG_PATH . '/active-playlist.json');
}
// Fichier réellement lu par le player kiosk (GET /api/playlist le sert).
if (!defined('LIVE_PLAYLIST_FILE')) {
    define('LIVE_PLAYLIST_FILE', rtrim(MEDIA_PATH, '/') . '/playlist.json');
}
// Canal de commande du player (poll 2s) — un "reload" réveille le player immédiatement.
if (!defined('PLAYER_COMMAND_FILE')) {
    define('PLAYER_COMMAND_FILE', CONFIG_PATH . '/player-command.json');
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

/* ============================ Activation / diffusion ============================ */

/**
 * Écrit le contenu de la playlist dans LIVE_PLAYLIST_FILE (media/playlist.json) au schéma attendu
 * par le player kiosk, en BUMPANT version -> le player (poll 10s) recharge automatiquement.
 * Signale aussi un reload immédiat (poll 2s).
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

    // Rafraîchissement IMMÉDIAT de l'écran : signal "reload" sur le canal de commande
    // (config/player-command.json) que le player poll toutes les 2s — sinon l'écran
    // n'actualise qu'au poll de version (10s). Profite à Diffuser ET au scheduler.
    playlistSignalReload();
    return true;
}

/** Incrémente le seq du canal de commande avec cmd=reload (réveille le player sous 2s). */
function playlistSignalReload() {
    $seq = 0;
    if (is_file(PLAYER_COMMAND_FILE)) {
        $d = json_decode((string)file_get_contents(PLAYER_COMMAND_FILE), true);
        if (is_array($d) && isset($d['seq']) && is_numeric($d['seq'])) $seq = (int)$d['seq'];
    }
    $next = json_encode(['seq' => $seq + 1, 'cmd' => 'reload', 'ts' => time()]);
    $dir = dirname(PLAYER_COMMAND_FILE);
    $tmp = @tempnam($dir, '.cmd.');
    if ($tmp === false) { @file_put_contents(PLAYER_COMMAND_FILE, $next); return; }
    if (@file_put_contents($tmp, $next) !== false && @rename($tmp, PLAYER_COMMAND_FILE)) {
        @chmod(PLAYER_COMMAND_FILE, 0664);
    } else {
        @unlink($tmp);
    }
}

/** Mémorise le slug actif (pointeur "playlist diffusée"). */
function playlistWriteActivePointer($pl) {
    @file_put_contents(ACTIVE_PLAYLIST_FILE, json_encode(
        ['slug' => $pl['slug'], 'name' => $pl['name'], 'activated_at' => date('Y-m-d H:i:s')],
        JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    @chmod(ACTIVE_PLAYLIST_FILE, 0664);
}

/**
 * "Diffuser à l'écran" par nom : pousse la playlist LIVE + écrit le pointeur actif.
 * Retourne l'objet playlist normalisé en cas de succès, null si introuvable, false si échec d'écriture.
 */
function playlistActivateByName($name) {
    $pl = playlistLoad($name);
    if ($pl === null) return null;
    if (!playlistPushLive($pl)) return false;
    playlistWriteActivePointer($pl);
    return $pl;
}
