<?php
/**
 * PiSignage — Overlay content API.
 *
 * Manages the editorial overlay content displayed on top of videos
 * (banner, clock, rotating info cards, QR). The content lives in a single
 * JSON file shared with the public player (served by nginx at
 * /data/overlay-content.json).
 *
 *   GET  /api/overlay.php  -> current content (or defaults if absent/corrupt)
 *   POST /api/overlay.php  -> validate schema and persist atomically
 *
 * The player MUST keep working even if this file is absent or corrupt
 * (degraded mode handled player-side); here we just guarantee that we only
 * ever write a well-formed, validated document.
 */

require_once __DIR__ . '/_guard.php';
require_once '../config.php';

header('Content-Type: application/json');

// Robust absolute path (resolves regardless of CWD / symlinks).
define('OVERLAY_FILE', dirname(__DIR__) . '/data/overlay-content.json');

$method = $_SERVER['REQUEST_METHOD'];

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
        'version' => 1,
        'enabled' => true,
        'lang'    => 'fr',
        'banner'  => [
            'enabled'  => true,
            'name'     => 'PiSignage',
            'subtitle' => 'Affichage dynamique',
            'logo'     => null,
        ],
        'clock'   => ['enabled' => true],
        'cards'   => [],
        'qr'      => ['enabled' => false, 'label' => '', 'data' => ''],
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
    ];

    // Clock.
    $clock = is_array($in['clock'] ?? null) ? $in['clock'] : [];
    $out['clock'] = ['enabled' => overlayBool($clock['enabled'] ?? true)];

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
