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

// Upload du logo : multipart/form-data, stocké dans /data/logos/.
// Bypass le _guard CSRF (géré par session via _guard, mais ?action=upload-logo
// est un POST multipart sans header X-CSRF-Token => on intercepte AVANT le switch JSON).
$action = isset($_GET['action']) ? (string)$_GET['action'] : '';
if ($method === 'POST' && $action === 'upload-logo') {
    handleUploadLogo();
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
        'version'    => 2,
        'enabled'    => true,
        'banner'     => [
            'enabled'  => true,
            'name'     => 'Zaforge',
            'subtitle' => 'Affichage dynamique',
            'logo'     => null,
            'size'     => 'md',
            'opacity'  => 0.92,
            'cycle'    => ['enabled' => false, 'on_seconds' => 8, 'off_seconds' => 20],
        ],
        'clock'      => [
            'enabled' => true,
            'size'    => 'md',
            'opacity' => 0.55,
            'cycle'   => ['enabled' => false, 'on_seconds' => 8, 'off_seconds' => 20],
        ],
        'cards_size'     => 'md',
        'cards_geometry' => [
            'preset'     => 'bottom-center',
            'x'          => 50,   // % de la largeur écran (centre horizontal)
            'y'          => 84,   // % de la hauteur écran (centre vertical de la carte)
            'width'      => 62,   // % de la largeur écran
            'height'     => 11,   // vh (viewport height)
        ],
        'cards_opacity' => 0.94,
        'cards_cycle'   => ['enabled' => false, 'on_seconds' => 8, 'off_seconds' => 20],
        'cards'         => [],
        'qr'            => [
            'enabled' => false,
            'label'   => '',
            'data'    => '',
            'size'    => 'md',
            'opacity' => 0.92,
            'cycle'   => ['enabled' => false, 'on_seconds' => 8, 'off_seconds' => 20],
        ],
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
 * Schéma v2 (juin 2026) :
 *   - Plus de champ `lang` global (multi-langue retiré : 1 seul texte par carte).
 *   - Chaque zone (banner, clock, cards, qr) a son propre `opacity` (0..1) et
 *     son propre `cycle` ({enabled, on_seconds, off_seconds}) pour les périodes
 *     de grâce on/off par zone.
 *   - Cartes : `cards_geometry` (preset + x/y/width/height), `cards_opacity`,
 *     `cards_cycle` (le cycle pilote le conteneur entier, pas chaque carte).
 *   - Carte : `text` unique (migration : `text_fr` ou `text_nl`Legacy → `text`).
 *
 * Toutes les chaînes sont length-bounded et stockées en UTF-8 plain text
 * (pas de HTML/markup — l'échappement est du ressort du renderer).
 */
function overlayValidate($in): ?array {
    if (!is_array($in)) {
        return null;
    }

    $out = [];
    $out['version'] = 2;
    $out['enabled'] = overlayBool($in['enabled'] ?? true);

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
        'opacity'  => overlayOpacity($banner['opacity'] ?? 0.92),
        'cycle'    => overlayCycle($banner['cycle'] ?? null),
    ];

    // Clock.
    $clock = is_array($in['clock'] ?? null) ? $in['clock'] : [];
    $out['clock'] = [
        'enabled' => overlayBool($clock['enabled'] ?? true),
        'size'    => overlaySize($clock['size'] ?? 'md'),
        'opacity' => overlayOpacity($clock['opacity'] ?? 0.55),
        'cycle'   => overlayCycle($clock['cycle'] ?? null),
    ];

    // Cartes — taille commune + géométrie (preset + ajustements fins) + opacité + cycle.
    $out['cards_size'] = overlaySize($in['cards_size'] ?? 'md');
    $out['cards_geometry'] = overlayGeometry($in['cards_geometry'] ?? null);
    $out['cards_opacity'] = overlayOpacity($in['cards_opacity'] ?? 0.94);
    $out['cards_cycle']   = overlayCycle($in['cards_cycle'] ?? null);

    // Cartes (rotatives). Hard cap à 20 pour garder le player léger.
    // Migration : `text_fr` (ou `text_nl`) → `text`. Champ `text` prioritaire.
    $out['cards'] = [];
    if (is_array($in['cards'] ?? null)) {
        foreach ($in['cards'] as $card) {
            if (!is_array($card)) {
                continue;
            }
            $text = overlayStr($card['text'] ?? '', 200);
            if ($text === '') {
                // Migration legacy : text_fr (prioritaire) ou text_nl.
                $legacy = overlayStr($card['text_fr'] ?? '', 120);
                if ($legacy === '') {
                    $legacy = overlayStr($card['text_nl'] ?? '', 120);
                }
                $text = $legacy;
            }
            if ($text === '') {
                continue;   // drop carte vide
            }
            $duration = (int)($card['duration'] ?? 8);
            if ($duration < 3)  { $duration = 3; }
            if ($duration > 60) { $duration = 60; }
            $out['cards'][] = [
                'icon'     => overlayIcon($card['icon'] ?? 'info'),
                'text'     => $text,
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
        'opacity' => overlayOpacity($qr['opacity'] ?? 0.92),
        'cycle'   => overlayCycle($qr['cycle'] ?? null),
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

/**
 * Coerce une valeur d'opacité (transparence) en float ∈ [0.10, 1.0].
 * Accepte int (0..100), float (0..1), ou string "0.85"/"85%".
 * 0.10 minimum pour éviter une zone invisible (préférez `enabled:false`).
 */
function overlayOpacity($v): float {
    if (is_string($v)) {
        $s = trim($v);
        if (substr($s, -1) === '%') { $s = substr($s, 0, -1); }
        $v = is_numeric($s) ? (float)$s : 0.92;
    }
    if (is_int($v)) { $v = ($v > 1) ? $v / 100.0 : (float)$v; }
    if (!is_float($v) && !is_int($v)) { $v = 0.92; }
    $v = (float)$v;
    if ($v < 0.10) $v = 0.10;
    if ($v > 1.0)  $v = 1.0;
    return $v;
}

/**
 * Valide un bloc `cycle` {enabled, on_seconds, off_seconds} pour les périodes
 * de grâce on/off par zone. Defaults sains si absent/malformé.
 * - on_seconds  ∈ [1, 3600] (default 8)
 * - off_seconds ∈ [0, 3600] (default 20 ; 0 = pas de pause)
 */
function overlayCycle($v): array {
    $def = ['enabled' => false, 'on_seconds' => 8, 'off_seconds' => 20];
    if (!is_array($v)) { return $def; }
    $on  = (int)($v['on_seconds']  ?? $def['on_seconds']);
    $off = (int)($v['off_seconds'] ?? $def['off_seconds']);
    if ($on  < 1)    { $on  = 1; }
    if ($on  > 3600) { $on  = 3600; }
    if ($off < 0)    { $off = 0; }
    if ($off > 3600) { $off = 3600; }
    return [
        'enabled'     => overlayBool($v['enabled'] ?? false),
        'on_seconds'  => $on,
        'off_seconds' => $off,
    ];
}

/**
 * Valide la géométrie des cartes d'infos : preset + ajustements X/Y/W/H fins.
 * Le preset est purement cosmétique côté UI (le player utilise x/y/w/h).
 * - x      ∈ [0, 100]   % de la largeur écran (centre horizontal de la carte)
 * - y      ∈ [0, 100]   % de la hauteur écran (centre vertical de la carte)
 * - width  ∈ [10, 100]  % de la largeur écran
 * - height ∈ [3, 50]    vh (viewport height units)
 */
function overlayGeometry($v): array {
    $def = ['preset' => 'bottom-center', 'x' => 50, 'y' => 84, 'width' => 62, 'height' => 11];
    if (!is_array($v)) { return $def; }
    $clamp = function($val, $min, $max, $def) {
        $val = is_numeric($val) ? (float)$val : $def;
        if ($val < $min) { $val = $min; }
        if ($val > $max) { $val = $max; }
        return $val;
    };
    $preset = is_string($v['preset'] ?? null) ? strtolower(trim($v['preset'])) : 'bottom-center';
    $allowed = [
        'top-left','top-center','top-right',
        'middle-left','middle-center','middle-right',
        'bottom-left','bottom-center','bottom-right',
    ];
    if (!in_array($preset, $allowed, true)) { $preset = 'bottom-center'; }
    return [
        'preset' => $preset,
        'x'      => $clamp($v['x']      ?? $def['x'],      0, 100, $def['x']),
        'y'      => $clamp($v['y']      ?? $def['y'],      0, 100, $def['y']),
        'width'  => $clamp($v['width']  ?? $def['width'], 10, 100, $def['width']),
        'height' => $clamp($v['height'] ?? $def['height'], 3,  50, $def['height']),
    ];
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

/* ------------------------------------------------------------------ */
/* Upload logo                                                         */
/* ------------------------------------------------------------------ */

/**
 * POST ?action=upload-logo (multipart/form-data, champ "logo")
 *
 * Stocke un logo (PNG/JPG/SVG/WebP) dans /data/logos/<sha1>.<ext> et retourne
 * l'URL publique. Le PNG préserve la transparence (le user demande explicitement
 * le support de la transparence).
 *
 * Validations :
 *   - Code erreur UPLOAD_ERR_OK sinon message explicite
 *   - MIME parmi image/png, image/jpeg, image/svg+xml, image/webp
 *   - Extension cohérente avec le MIME
 *   - Poids ≤ 2 MB (config OVERLAY_LOGO_MAX_BYTES, défault 2 MB)
 *   - Dimensions ≤ 2000x2000 (anti flood pixels)
 *
 * Réponse 201 {url:"/data/logos/abc.png"} ou 422/413/500 sur erreur.
 *
 * Sécurité :
 *   - Extension déterminée par le MIME (pas par le nom de fichier envoyé)
 *   - Nom dispo = sha1(filesize + random_bytes) — pas de collision, pas de chemin
 *     contrôlable par l'utilisateur
 *   - Le fichier ne part JAMAIS en /data/logos/../ etc (basename strict)
 */
function handleUploadLogo(): void {
    $maxBytes = defined('OVERLAY_LOGO_MAX_BYTES') ? OVERLAY_LOGO_MAX_BYTES : 2 * 1024 * 1024;

    if (empty($_FILES['logo']) || !is_array($_FILES['logo'])) {
        jsonResponse(false, null, 'Aucun fichier reçu (champ "logo" manquant)', 422);
        return;
    }
    $up = $_FILES['logo'];

    if (($up['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        jsonResponse(false, null, 'Erreur upload code ' . (int)($up['error'] ?? -1), 422);
        return;
    }
    if (!is_uploaded_file($up['tmp_name'] ?? '')) {
        jsonResponse(false, null, 'Fichier non valide (is_uploaded_file)', 422);
        return;
    }
    if (($up['size'] ?? 0) > $maxBytes) {
        jsonResponse(false, null, 'Logo trop volumineux (max ' . round($maxBytes / 1024 / 1024, 1) . ' MB)', 413);
        return;
    }

    // MIME réel via finfo (pas confiance au type envoyé par le client).
    $finfo = function_exists('finfo_open') ? finfo_open(FILEINFO_MIME_TYPE) : false;
    $mime = $finfo ? finfo_file($finfo, $up['tmp_name']) : ($up['type'] ?? '');
    if ($finfo) { finfo_close($finfo); }

    $allowed = [
        'image/png'  => 'png',
        'image/jpeg' => 'jpg',
        'image/webp' => 'webp',
        'image/svg+xml' => 'svg',
    ];
    if (!is_string($mime) || !isset($allowed[$mime])) {
        jsonResponse(false, null, 'Type de fichier non supporté (PNG, JPG, WebP, SVG autorisés). MIME détecté: ' . $mime, 422);
        return;
    }
    $ext = $allowed[$mime];

    // Dimensions (sauf SVG qui n'a pas de dimensions naturelles décodables).
    if ($mime !== 'image/svg+xml' && function_exists('getimagesize')) {
        $dim = @getimagesize($up['tmp_name']);
        if ($dim === false) {
            jsonResponse(false, null, 'Image illisible (fichier corrompu ?)', 422);
            return;
        }
        $w = (int)$dim[0]; $h = (int)$dim[1];
        if ($w <= 0 || $h <= 0 || $w > 2000 || $h > 2000) {
            jsonResponse(false, null, 'Dimensions invalides (1..2000 px autorisés, reçu ' . $w . 'x' . $h . ')', 422);
            return;
        }
    }

    // Vérifier le contenu SVG (ne pas autoriser du JS ou des entités externes).
    if ($mime === 'image/svg+xml') {
        $raw = @file_get_contents($up['tmp_name']);
        if ($raw === false || stripos($raw, '<script') !== false || stripos($raw, 'javascript:') !== false) {
            jsonResponse(false, null, 'SVG refusé (contient du code actif)', 422);
            return;
        }
    }

    // Stockage atomique dans /data/logos/.
    $dir = dirname(__DIR__) . '/data/logos';
    if (!is_dir($dir) && !@mkdir($dir, 0755, true)) {
        jsonResponse(false, null, 'Impossible de créer /data/logos/', 500);
        return;
    }
    if (!is_writable($dir)) {
        jsonResponse(false, null, '/data/logos/ non inscriptible', 500);
        return;
    }

    // Nom unique déterministe : sha1(filesize + random). Le user ne contrôle
    // QUE le contenu du fichier (pas le nom, pas le chemin) -> pas d'injection.
    $hash = hash('sha1', (string)($up['size'] ?? 0) . '|' . random_bytes(16));
    $basename = $hash . '.' . $ext;
    $dest = $dir . '/' . $basename;

    if (!@move_uploaded_file($up['tmp_name'], $dest)) {
        jsonResponse(false, null, 'Échec du déplacement du fichier uploadé', 500);
        return;
    }
    @chmod($dest, 0644);

    // URL publique (nginx sert /data/* directement).
    $url = '/data/logos/' . $basename;

    jsonResponse(true, ['url' => $url, 'mime' => $mime], 'Logo uploadé', 201);
}
