<?php
/**
 * PiSignage — Overlay content API.
 *
 * Manages the editorial overlay content displayed on top of videos
 * (banner, clock, rotating info cards, QR). The content lives in a single
 * JSON file shared with the public player (served by nginx at
 * /data/overlay-content.json).
 *
 *   GET    /api/overlay.php                     -> global content (or defaults)
 *   POST   /api/overlay.php                     -> validate + persist the global
 *   GET    /api/overlay.php?target=media        -> map {filename: overlay}
 *   GET    /api/overlay.php?target=media&file=X -> per-video overlay (or {exists:false})
 *   POST   /api/overlay.php?target=media&file=X -> save the per-video overlay
 *   DELETE /api/overlay.php?target=media&file=X -> drop the per-video overlay
 *
 * Per-video overlays use REPLACE semantics (no merge with the global): when
 * present for the current item's basename, the player shows that overlay
 * instead of the global one.
 *
 * The player MUST keep working even if these files are absent or corrupt
 * (degraded mode handled player-side); here we just guarantee that we only
 * ever write well-formed, validated documents.
 */

require_once __DIR__ . '/_guard.php';
require_once '../config.php';

header('Content-Type: application/json');

// Robust absolute paths (resolve regardless of CWD / symlinks).
define('OVERLAY_FILE', dirname(__DIR__) . '/data/overlay-content.json');
define('MEDIA_OVERLAYS_FILE', dirname(__DIR__) . '/data/media-overlays.json');

$method = $_SERVER['REQUEST_METHOD'];
$target = isset($_GET['target']) ? (string)$_GET['target'] : '';

// Per-video overlays (REPLACE semantics, stored in media-overlays.json).
if ($target === 'media') {
    $file = isset($_GET['file']) ? (string)$_GET['file'] : '';
    switch ($method) {
        case 'GET':
            handleGetMediaOverlay($file);
            break;
        case 'POST':
            $input = json_decode(file_get_contents('php://input'), true);
            handleSaveMediaOverlay($file, $input);
            break;
        case 'DELETE':
            handleDeleteMediaOverlay($file);
            break;
        default:
            jsonResponse(false, null, 'Méthode non autorisée', 405);
    }
    return;
}

switch ($method) {
    case 'GET':
        handleGetOverlay();
        break;
    case 'POST':
        $input = json_decode(file_get_contents('php://input'), true);
        handleSaveOverlay($input);
        break;
    default:
        jsonResponse(false, null, 'Méthode non autorisée', 405);
}

/* ------------------------------------------------------------------ */
/* GET                                                                 */
/* ------------------------------------------------------------------ */

function handleGetOverlay() {
    jsonResponse(true, overlayLoad());
}

/**
 * Load current overlay content, falling back to defaults if the file is
 * missing or unreadable/corrupt. Never throws.
 */
function overlayLoad(): array {
    if (is_readable(OVERLAY_FILE)) {
        $raw = @file_get_contents(OVERLAY_FILE);
        if ($raw !== false) {
            $data = json_decode($raw, true);
            if (is_array($data)) {
                return overlayNormalize($data);
            }
        }
    }
    return overlayDefaults();
}

function overlayDefaults(): array {
    return [
        'version'    => 1,
        'enabled'    => true,
        'lang'       => 'fr',
        'banner'     => [
            'enabled'  => true,
            'name'     => 'PiSignage',
            'subtitle' => 'Affichage dynamique',
            'logo'     => null,
            'size'     => 'md',
        ],
        'clock'      => ['enabled' => true, 'size' => 'md'],
        'cards_size' => 'md',
        'cards'      => [],
        'qr'         => ['enabled' => false, 'label' => '', 'data' => '', 'size' => 'md'],
    ];
}

/* ------------------------------------------------------------------ */
/* POST                                                                */
/* ------------------------------------------------------------------ */

function handleSaveOverlay($input) {
    if (!is_array($input)) {
        jsonResponse(false, null, 'Corps de requête JSON invalide', 400);
        return;
    }

    $clean = overlayValidate($input);
    if ($clean === null) {
        jsonResponse(false, null, 'Données overlay invalides', 422);
        return;
    }

    if (!overlayWriteAtomic($clean)) {
        jsonResponse(false, null, 'Échec de l\'écriture du fichier overlay', 500);
        return;
    }

    jsonResponse(true, $clean, 'Overlay enregistré');
}

/* ------------------------------------------------------------------ */
/* Per-video overlays (target=media)                                   */
/* ------------------------------------------------------------------ */

/**
 * GET ?target=media            -> full map {filename: overlayNormalized}.
 * GET ?target=media&file=X     -> normalized overlay for X, or {exists:false}.
 */
function handleGetMediaOverlay(string $file) {
    $map = mediaOverlaysLoad();

    if ($file === '') {
        $out = [];
        foreach ($map as $name => $ov) {
            $out[$name] = overlayNormalize($ov);
        }
        jsonResponse(true, $out);
        return;
    }

    $name = mediaOverlayKey($file);
    if ($name === null) {
        jsonResponse(false, null, 'Nom de fichier invalide', 400);
        return;
    }
    if (!isset($map[$name]) || !is_array($map[$name])) {
        jsonResponse(true, ['exists' => false]);
        return;
    }
    jsonResponse(true, overlayNormalize($map[$name]));
}

/**
 * POST ?target=media&file=X -> validate the body and store it under key X
 * in media-overlays.json (whole file written atomically).
 */
function handleSaveMediaOverlay(string $file, $input) {
    $name = mediaOverlayKey($file);
    if ($name === null) {
        jsonResponse(false, null, 'Nom de fichier invalide', 400);
        return;
    }
    if (!is_array($input)) {
        jsonResponse(false, null, 'Corps de requête JSON invalide', 400);
        return;
    }

    $clean = overlayValidate($input);
    if ($clean === null) {
        jsonResponse(false, null, 'Données overlay invalides', 422);
        return;
    }

    $map = mediaOverlaysLoad();
    $map[$name] = $clean;

    if (!mediaOverlaysWriteAtomic($map)) {
        jsonResponse(false, null, 'Échec de l\'écriture du fichier overlay par-vidéo', 500);
        return;
    }

    jsonResponse(true, $clean, 'Overlay par-vidéo enregistré');
}

/**
 * DELETE ?target=media&file=X -> remove key X (item reverts to the global
 * overlay player-side). Idempotent: deleting an absent key still succeeds.
 */
function handleDeleteMediaOverlay(string $file) {
    $name = mediaOverlayKey($file);
    if ($name === null) {
        jsonResponse(false, null, 'Nom de fichier invalide', 400);
        return;
    }

    $map = mediaOverlaysLoad();
    if (array_key_exists($name, $map)) {
        unset($map[$name]);
        if (!mediaOverlaysWriteAtomic($map)) {
            jsonResponse(false, null, 'Échec de l\'écriture du fichier overlay par-vidéo', 500);
            return;
        }
    }

    jsonResponse(true, ['deleted' => $name], 'Overlay par-vidéo supprimé');
}

/**
 * Load the per-video overlay map. Falls back to an empty map if the file is
 * missing or unreadable/corrupt. Never throws.
 */
function mediaOverlaysLoad(): array {
    if (is_readable(MEDIA_OVERLAYS_FILE)) {
        $raw = @file_get_contents(MEDIA_OVERLAYS_FILE);
        if ($raw !== false) {
            $data = json_decode($raw, true);
            if (is_array($data)) {
                // Keep only string keys mapping to array overlays.
                $out = [];
                foreach ($data as $k => $v) {
                    if (is_string($k) && is_array($v)) {
                        $key = mediaOverlayKey($k);
                        if ($key !== null) {
                            $out[$key] = $v;
                        }
                    }
                }
                return $out;
            }
        }
    }
    return [];
}

/**
 * Sanitize an incoming file reference into a safe map key (basename only).
 * Drops any path/query, rejects traversal, bounds length, allows a
 * conservative character set. Returns null when nothing safe remains.
 */
function mediaOverlayKey($file): ?string {
    if (!is_string($file)) {
        return null;
    }
    // Strip a possible query/fragment, then take the last path segment.
    $file = preg_replace('/[?#].*$/', '', $file);
    $file = str_replace('\\', '/', $file);
    $file = basename($file);
    $file = trim($file);

    if ($file === '' || $file === '.' || $file === '..') {
        return null;
    }
    if (strpos($file, '/') !== false) {
        return null;
    }
    // Conservative safe set for media basenames.
    if (!preg_match('/^[A-Za-z0-9._\- ()]+$/', $file)) {
        return null;
    }
    if (strlen($file) > 200) {
        return null;
    }
    return $file;
}

/** Atomic whole-file write of the per-video overlay map (tmp + rename). */
function mediaOverlaysWriteAtomic(array $map): bool {
    $dir = dirname(MEDIA_OVERLAYS_FILE);
    if (!is_dir($dir)) {
        @mkdir($dir, 0755, true);
    }
    if (!is_writable($dir) && !is_writable(MEDIA_OVERLAYS_FILE)) {
        return false;
    }

    // Encode an empty map as a JSON object, not an array.
    $payload = empty($map) ? new stdClass() : $map;
    $json = json_encode(
        $payload,
        JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
    );
    if ($json === false) {
        return false;
    }

    $tmp = @tempnam($dir, '.media-overlays.');
    if ($tmp === false) {
        return false;
    }

    if (@file_put_contents($tmp, $json . "\n") === false) {
        @unlink($tmp);
        return false;
    }
    @chmod($tmp, 0644);

    if (!@rename($tmp, MEDIA_OVERLAYS_FILE)) {
        @unlink($tmp);
        return false;
    }
    return true;
}

/**
 * Validate + coerce an incoming overlay document into a safe, well-typed
 * structure. Returns null when the input cannot be made valid.
 *
 * All string fields are length-bounded and stored as plain UTF-8 text
 * (no HTML/markup interpretation here — escaping is the renderer's job).
 */
function overlayValidate($in): ?array {
    if (!is_array($in)) {
        return null;
    }

    $out = [];
    $out['version'] = 1;
    $out['enabled'] = overlayBool($in['enabled'] ?? true);

    // Language: only "fr" or "nl".
    $lang = is_string($in['lang'] ?? null) ? strtolower(trim($in['lang'])) : 'fr';
    $out['lang'] = in_array($lang, ['fr', 'nl'], true) ? $lang : 'fr';

    // Banner.
    $banner = is_array($in['banner'] ?? null) ? $in['banner'] : [];
    $logo = $banner['logo'] ?? null;
    $logo = (is_string($logo) && $logo !== '') ? overlayStr($logo, 512) : null;
    $out['banner'] = [
        'enabled'  => overlayBool($banner['enabled'] ?? true),
        'name'     => overlayStr($banner['name'] ?? '', 80),
        'subtitle' => overlayStr($banner['subtitle'] ?? '', 160),
        'logo'     => $logo,
        'size'     => overlaySize($banner['size'] ?? 'md'),
    ];

    // Clock.
    $clock = is_array($in['clock'] ?? null) ? $in['clock'] : [];
    $out['clock'] = [
        'enabled' => overlayBool($clock['enabled'] ?? true),
        'size'    => overlaySize($clock['size'] ?? 'md'),
    ];

    // Common size for info cards.
    $out['cards_size'] = overlaySize($in['cards_size'] ?? 'md');

    // Cards (rotating info). Hard cap to keep the player light.
    $out['cards'] = [];
    if (is_array($in['cards'] ?? null)) {
        foreach ($in['cards'] as $card) {
            if (!is_array($card)) {
                continue;
            }
            $textFr = overlayStr($card['text_fr'] ?? '', 120);
            $textNl = overlayStr($card['text_nl'] ?? '', 120);
            // Drop fully-empty cards.
            if ($textFr === '' && $textNl === '') {
                continue;
            }
            $duration = (int)($card['duration'] ?? 8);
            if ($duration < 3)  { $duration = 3; }
            if ($duration > 60) { $duration = 60; }
            $out['cards'][] = [
                'icon'     => overlayIcon($card['icon'] ?? 'info'),
                'text_fr'  => $textFr,
                'text_nl'  => $textNl,
                'duration' => $duration,
            ];
            if (count($out['cards']) >= 20) {
                break;
            }
        }
    }

    // QR.
    $qr = is_array($in['qr'] ?? null) ? $in['qr'] : [];
    $out['qr'] = [
        'enabled' => overlayBool($qr['enabled'] ?? false),
        'label'   => overlayStr($qr['label'] ?? '', 60),
        'data'    => overlayStr($qr['data'] ?? '', 512),
        'size'    => overlaySize($qr['size'] ?? 'md'),
    ];

    return $out;
}

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */

function overlayBool($v): bool {
    if (is_bool($v))   { return $v; }
    if (is_int($v))    { return $v !== 0; }
    if (is_string($v)) { return in_array(strtolower($v), ['1', 'true', 'on', 'yes'], true); }
    return false;
}

/** Trim + strip control chars + length-bound a string field. */
function overlayStr($v, int $max): string {
    if (!is_string($v)) {
        $v = is_scalar($v) ? (string)$v : '';
    }
    // Strip control characters (keep normal whitespace handled by trim()).
    $v = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $v);
    $v = trim($v);
    if (function_exists('mb_substr')) {
        $v = mb_substr($v, 0, $max, 'UTF-8');
    } else {
        $v = substr($v, 0, $max);
    }
    return $v;
}

/** Allow only a small known-safe set of icon names (line-style design system). */
function overlayIcon($v): string {
    $allowed = ['info', 'alert', 'clock', 'check', 'check-circle', 'calendar', 'wifi', 'volume', 'user'];
    $v = is_string($v) ? strtolower(trim($v)) : 'info';
    return in_array($v, $allowed, true) ? $v : 'info';
}

/**
 * Bound a size token to the shared scale {sm, md, lg, xl} (default "md").
 * Scale factors are applied player-side: sm=0.8, md=1.0, lg=1.25, xl=1.5.
 */
function overlaySize($v): string {
    $v = is_string($v) ? strtolower(trim($v)) : 'md';
    return in_array($v, ['sm', 'md', 'lg', 'xl'], true) ? $v : 'md';
}

/** Re-validate an already-stored document so GET never serves garbage. */
function overlayNormalize(array $data): array {
    $clean = overlayValidate($data);
    return $clean !== null ? $clean : overlayDefaults();
}

/**
 * Write the document atomically: encode -> temp file in the same dir ->
 * fsync-less rename(). rename() is atomic on the same filesystem, so the
 * player never reads a half-written file.
 */
function overlayWriteAtomic(array $data): bool {
    $dir = dirname(OVERLAY_FILE);
    if (!is_dir($dir)) {
        @mkdir($dir, 0755, true);
    }
    if (!is_writable($dir) && !is_writable(OVERLAY_FILE)) {
        return false;
    }

    $json = json_encode(
        $data,
        JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
    );
    if ($json === false) {
        return false;
    }

    $tmp = @tempnam($dir, '.overlay.');
    if ($tmp === false) {
        return false;
    }

    if (@file_put_contents($tmp, $json . "\n") === false) {
        @unlink($tmp);
        return false;
    }
    @chmod($tmp, 0644);

    if (!@rename($tmp, OVERLAY_FILE)) {
        @unlink($tmp);
        return false;
    }
    return true;
}
