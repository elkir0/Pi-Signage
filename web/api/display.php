<?php
/**
 * PiSignage — API DISPLAY (Phase 2 de l'unification de la diffusion).
 *
 * Canal de COMMANDE + remontée d'ÉTAT pour le MOTEUR DE LECTURE RÉEL :
 * Chromium HTML5 (player.php servi sur /player). Remplace l'ancien pilotage VLC (retiré).
 *
 *  Transport — config/player-command.json { seq, cmd, ts }
 *   POST /api/display.php?action=command  {cmd:"next|prev|play|pause|reload"}  (auth admin)
 *   GET  /api/display.php?action=command   -> { seq, cmd, ts }                 (public : le player poll)
 *
 *  État du lecteur — config/player-state.json
 *   POST /api/display.php?action=state  {status,name,version,index,count,current}  (public : le player rapporte)
 *   GET  /api/display.php?action=state   -> { state, online, active }              (auth admin)
 *
 *  Lecture directe d'un média (écrit une playlist live à 1 élément + reload immédiat)
 *   POST /api/display.php?action=playmedia {url|file}                          (auth admin)
 *
 * Les exceptions d'auth publiques (GET command / POST state) sont déclarées dans _guard.php.
 */

require_once __DIR__ . '/_guard.php';
require_once '../config.php';

header('Content-Type: application/json');

if (!defined('COMMAND_FILE'))         define('COMMAND_FILE', CONFIG_PATH . '/player-command.json');
if (!defined('STATE_FILE'))           define('STATE_FILE', CONFIG_PATH . '/player-state.json');
if (!defined('ACTIVE_PLAYLIST_FILE')) define('ACTIVE_PLAYLIST_FILE', CONFIG_PATH . '/active-playlist.json');
if (!defined('LIVE_PLAYLIST_FILE'))   define('LIVE_PLAYLIST_FILE', rtrim(MEDIA_PATH, '/') . '/playlist.json');
if (!defined('STATE_STALE_SECONDS'))  define('STATE_STALE_SECONDS', 15);

$ALLOWED_CMDS = ['next', 'prev', 'play', 'pause', 'reload'];

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

switch (true) {
    case $method === 'GET' && $action === 'command':
        jsonResponse(true, displayReadCommand());
        break;

    case $method === 'POST' && $action === 'command':
        $in  = json_decode(file_get_contents('php://input'), true);
        $cmd = is_array($in) ? ($in['cmd'] ?? '') : '';
        if (!in_array($cmd, $ALLOWED_CMDS, true)) {
            jsonResponse(false, null, 'Commande inconnue', 400);
        }
        jsonResponse(true, displayPushCommand($cmd), 'Commande envoyée');
        break;

    case $method === 'POST' && $action === 'state':
        $in = json_decode(file_get_contents('php://input'), true);
        jsonResponse(true, displayWriteState(is_array($in) ? $in : []));
        break;

    case $method === 'GET' && $action === 'state':
        jsonResponse(true, displayReadState());
        break;

    case $method === 'POST' && $action === 'playmedia':
        $in = json_decode(file_get_contents('php://input'), true);
        handlePlayMedia(is_array($in) ? $in : []);
        break;

    default:
        jsonResponse(false, null, 'Action non supportée', 400);
}

/* ============================ Transport ============================ */

function displayReadCommand() {
    if (is_file(COMMAND_FILE)) {
        $d = json_decode((string)file_get_contents(COMMAND_FILE), true);
        if (is_array($d)) {
            return [
                'seq' => (int)($d['seq'] ?? 0),
                'cmd' => (string)($d['cmd'] ?? ''),
                'ts'  => (int)($d['ts'] ?? 0),
            ];
        }
    }
    return ['seq' => 0, 'cmd' => '', 'ts' => 0];
}

function displayPushCommand($cmd) {
    $cur  = displayReadCommand();
    $next = ['seq' => $cur['seq'] + 1, 'cmd' => $cmd, 'ts' => time()];
    displayAtomicWrite(COMMAND_FILE, $next);
    if (function_exists('logMessage')) {
        logMessage('Commande lecteur: ' . $cmd . ' (seq ' . $next['seq'] . ')');
    }
    return $next;
}

/* ============================ État ============================ */

function displayWriteState($in) {
    $validStatus = ['playing', 'paused', 'loading', 'idle', 'error'];
    $state = [
        'engine'  => 'chromium',
        'status'  => in_array(($in['status'] ?? ''), $validStatus, true) ? $in['status'] : 'unknown',
        'name'    => isset($in['name']) ? (string)$in['name'] : '',
        'version' => isset($in['version']) ? (int)$in['version'] : 0,
        'index'   => isset($in['index']) ? (int)$in['index'] : 0,
        'count'   => isset($in['count']) ? (int)$in['count'] : 0,
        'current' => [
            'url'  => isset($in['current']['url'])  ? (string)$in['current']['url']  : '',
            'name' => isset($in['current']['name']) ? (string)$in['current']['name'] : '',
            'type' => isset($in['current']['type']) ? (string)$in['current']['type'] : '',
        ],
        'reported_at' => time(),
    ];
    displayAtomicWrite(STATE_FILE, $state);
    return ['ok' => true];
}

function displayReadState() {
    $state = null;
    if (is_file(STATE_FILE)) {
        $d = json_decode((string)file_get_contents(STATE_FILE), true);
        if (is_array($d)) $state = $d;
    }
    $online = false;
    if ($state && isset($state['reported_at'])) {
        $online = (time() - (int)$state['reported_at']) <= STATE_STALE_SECONDS;
    }
    $active = null;
    if (is_file(ACTIVE_PLAYLIST_FILE)) {
        $a = json_decode((string)file_get_contents(ACTIVE_PLAYLIST_FILE), true);
        if (is_array($a)) {
            $active = ['slug' => $a['slug'] ?? null, 'name' => $a['name'] ?? null];
        }
    }
    return ['state' => $state, 'online' => $online, 'active' => $active];
}

/* ============================ Lecture directe ============================ */

/** Construit une playlist live à 1 élément à partir d'un média et demande un reload immédiat. */
function handlePlayMedia($in) {
    $url = '';
    if (!empty($in['url']))       $url = (string)$in['url'];
    elseif (!empty($in['file']))  $url = '/media/' . ltrim((string)$in['file'], '/');
    if ($url === '') { jsonResponse(false, null, 'Média requis (url ou file)', 400); return; }

    // Sécurité : restreindre à /media et empêcher toute remontée de chemin.
    $url = '/' . ltrim($url, '/');
    if (strpos($url, '/media/') !== 0 || strpos($url, '..') !== false) {
        jsonResponse(false, null, 'Chemin média invalide', 422); return;
    }
    $rel = ltrim(substr($url, strlen('/media/')), '/');
    $abs = rtrim(MEDIA_PATH, '/') . '/' . $rel;
    if (!is_file($abs)) { jsonResponse(false, null, 'Fichier introuvable', 404); return; }

    $base = basename($rel);
    $ext  = strtolower(pathinfo($base, PATHINFO_EXTENSION));
    $type = in_array($ext, ALLOWED_IMAGE_EXTENSIONS, true) ? 'image' : 'video';

    $prevVersion = 0;
    if (is_file(LIVE_PLAYLIST_FILE)) {
        $prev = json_decode((string)file_get_contents(LIVE_PLAYLIST_FILE), true);
        if (is_array($prev) && isset($prev['version']) && is_numeric($prev['version'])) {
            $prevVersion = (int)$prev['version'];
        }
    }
    $live = [
        'version'  => $prevVersion + 1,
        'name'     => 'Lecture directe',
        'autoplay' => true,
        'autoLoop' => true,
        'items'    => [[
            'url'      => $url,
            'type'     => $type,
            'name'     => $base,
            'duration' => $type === 'image' ? 10 : 0,
            'fit'      => 'contain',
            'mute'     => false,
            'loop'     => true,
        ]],
    ];
    if (!displayAtomicWrite(LIVE_PLAYLIST_FILE, $live)) {
        jsonResponse(false, null, 'Échec de l\'écriture de la playlist live', 500); return;
    }
    // Lecture d'un média isolé : il n'y a plus de playlist nommée "active".
    @unlink(ACTIVE_PLAYLIST_FILE);
    // Reload immédiat (sans attendre le poll de version du player).
    displayPushCommand('reload');
    if (function_exists('logMessage')) logMessage('Lecture directe média: ' . $base);

    jsonResponse(true, ['url' => $url, 'type' => $type], 'Lecture lancée');
}

/* ============================ Utilitaire ============================ */

function displayAtomicWrite($path, $data) {
    $dir = dirname($path);
    if (!is_dir($dir)) @mkdir($dir, 0775, true);
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $tmp  = @tempnam($dir, '.disp.');
    if ($tmp === false) {
        return @file_put_contents($path, $json) !== false;
    }
    $ok = @file_put_contents($tmp, $json) !== false;
    if ($ok && @rename($tmp, $path)) { @chmod($path, 0664); return true; }
    @unlink($tmp);
    return false;
}
