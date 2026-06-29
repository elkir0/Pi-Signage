<?php
/**
 * Zaforge — configuration globale de musique d'ambiance.
 *
 * Ce fichier ne sort pas de JSON HTTP : il est partageable entre l'API et les tests CLI.
 */

if (!defined('BACKGROUND_MUSIC_FILE')) {
    $configBase = defined('CONFIG_PATH') ? CONFIG_PATH : '/opt/pisignage/config';
    define('BACKGROUND_MUSIC_FILE', rtrim($configBase, '/') . '/background-music.json');
}
if (!defined('BACKGROUND_MUSIC_MEDIA_PATH')) {
    $mediaBase = defined('MEDIA_PATH') ? MEDIA_PATH : '/opt/pisignage/media';
    define('BACKGROUND_MUSIC_MEDIA_PATH', rtrim($mediaBase, '/'));
}
if (!defined('BACKGROUND_MUSIC_MEDIA_URL_PREFIX')) {
    define('BACKGROUND_MUSIC_MEDIA_URL_PREFIX', '/media');
}

function backgroundMusicAudioExtensions(): array {
    if (defined('ALLOWED_AUDIO_EXTENSIONS')) {
        return array_map('strtolower', ALLOWED_AUDIO_EXTENSIONS);
    }
    return ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac'];
}

function backgroundMusicRadioPresets(): array {
    return [
        ['id' => 'fip',               'name' => 'FIP',                    'genre' => 'Eclectique',        'url' => 'https://icecast.radiofrance.fr/fip-hifi.aac'],
        ['id' => 'fip-jazz',          'name' => 'FIP Jazz',               'genre' => 'Jazz',              'url' => 'https://icecast.radiofrance.fr/fipjazz-hifi.aac'],
        ['id' => 'fip-groove',        'name' => 'FIP Groove',             'genre' => 'Groove',            'url' => 'https://icecast.radiofrance.fr/fipgroove-hifi.aac'],
        ['id' => 'radio-swiss-jazz',  'name' => 'Radio Swiss Jazz',       'genre' => 'Jazz',              'url' => 'https://stream.srg-ssr.ch/srgssr/rsj/mp3/128'],
        ['id' => 'radio-swiss-classic','name' => 'Radio Swiss Classic',   'genre' => 'Classique',         'url' => 'https://stream.srg-ssr.ch/srgssr/rsc_de/mp3/128'],
        ['id' => 'radio-swiss-pop',   'name' => 'Radio Swiss Pop',        'genre' => 'Pop soft',          'url' => 'https://stream.srg-ssr.ch/srgssr/rsp/mp3/128'],
        ['id' => 'abc-lounge',        'name' => 'ABC Lounge Radio',       'genre' => 'Lounge jazz',       'url' => 'https://eu1.fastcast4u.com/proxy/kpmxz?mp=/1'],
        ['id' => 'jazz-radio-lounge', 'name' => 'Jazz Radio Lounge',      'genre' => 'Lounge',            'url' => 'https://jazzlounge.ice.infomaniak.ch/jazzlounge-high.mp3'],
        ['id' => 'jazz-radio-classic','name' => 'Jazz Radio Classic Jazz','genre' => 'Jazz classique',    'url' => 'https://jazz-wr01.ice.infomaniak.ch/jazz-wr01-128.mp3'],
        ['id' => 'pd-jazz',           'name' => 'Public Domain Jazz',     'genre' => 'Domaine public',    'url' => 'http://relay.publicdomainradio.org/jazz_swing.mp3'],
        ['id' => 'pd-classical',      'name' => 'Public Domain Classical','genre' => 'Domaine public',    'url' => 'http://relay.publicdomainradio.org/classical.mp3'],
        ['id' => 'soma-groove-salad', 'name' => 'SomaFM Groove Salad',    'genre' => 'Downtempo indé',    'url' => 'https://ice2.somafm.com/groovesalad-128-mp3'],
        ['id' => 'soma-secret-agent', 'name' => 'SomaFM Secret Agent',    'genre' => 'Lounge indé',       'url' => 'https://ice2.somafm.com/secretagent-128-mp3'],
        ['id' => 'soma-drone-zone',   'name' => 'SomaFM Drone Zone',      'genre' => 'Ambient indé',      'url' => 'https://ice2.somafm.com/dronezone-128-mp3'],
        ['id' => 'soma-beat-blender', 'name' => 'SomaFM Beat Blender',    'genre' => 'Deep house indé',   'url' => 'https://ice2.somafm.com/beatblender-128-mp3'],
        ['id' => 'soma-bossa',        'name' => 'SomaFM Bossa Beyond',    'genre' => 'Bossa lounge',      'url' => 'https://ice2.somafm.com/bossa-128-mp3'],
        ['id' => 'soma-sonic',        'name' => 'SomaFM Sonic Universe',  'genre' => 'Jazz indé',         'url' => 'https://ice2.somafm.com/sonicuniverse-128-mp3'],
        ['id' => 'soma-lush',         'name' => 'SomaFM Lush',            'genre' => 'Vocal chill',       'url' => 'https://ice2.somafm.com/lush-128-mp3'],
    ];
}

function backgroundMusicDefaultRadioId(): string {
    $presets = backgroundMusicRadioPresets();
    return (string)$presets[0]['id'];
}

function backgroundMusicDefaultConfig(): array {
    return [
        'enabled'  => false,
        'source'   => 'webradio',
        'radio'    => backgroundMusicDefaultRadioId(),
        'playback' => 'order',
        'tracks'   => [],
    ];
}

function backgroundMusicPresetById(string $id): ?array {
    foreach (backgroundMusicRadioPresets() as $preset) {
        if ($preset['id'] === $id) return $preset;
    }
    return null;
}

function backgroundMusicNormalizeTrackUrl($url): ?string {
    if (!is_string($url)) return null;
    $url = trim($url);
    if ($url === '') return null;

    $prefix = '/' . trim(BACKGROUND_MUSIC_MEDIA_URL_PREFIX, '/');
    $url = '/' . ltrim($url, '/');
    $path = parse_url($url, PHP_URL_PATH) ?: '';
    if (strpos($path, $prefix . '/') !== 0) return null;
    if (strpos(rawurldecode($path), '..') !== false) return null;

    $base = basename($path);
    $decodedBase = rawurldecode($base);
    if ($decodedBase === '' || basename($decodedBase) !== $decodedBase) return null;

    $ext = strtolower(pathinfo($decodedBase, PATHINFO_EXTENSION));
    if (!in_array($ext, backgroundMusicAudioExtensions(), true)) return null;
    if (!is_file(rtrim(BACKGROUND_MUSIC_MEDIA_PATH, '/') . '/' . $decodedBase)) return null;

    return $prefix . '/' . rawurlencode($decodedBase);
}

function backgroundMusicNormalizeConfig($raw): array {
    $defaults = backgroundMusicDefaultConfig();
    if (!is_array($raw)) return $defaults;

    $source = (isset($raw['source']) && in_array($raw['source'], ['webradio', 'local'], true))
        ? $raw['source']
        : $defaults['source'];
    $radio = isset($raw['radio']) ? (string)$raw['radio'] : $defaults['radio'];
    if (backgroundMusicPresetById($radio) === null) $radio = $defaults['radio'];
    $playback = (isset($raw['playback']) && in_array($raw['playback'], ['order', 'random'], true))
        ? $raw['playback']
        : $defaults['playback'];

    $tracks = [];
    foreach (($raw['tracks'] ?? []) as $track) {
        $normalized = backgroundMusicNormalizeTrackUrl($track);
        if ($normalized !== null && !in_array($normalized, $tracks, true)) {
            $tracks[] = $normalized;
        }
    }

    return [
        'enabled'  => !empty($raw['enabled']),
        'source'   => $source,
        'radio'    => $radio,
        'playback' => $playback,
        'tracks'   => $tracks,
    ];
}

function backgroundMusicLoadConfig(): array {
    if (!is_file(BACKGROUND_MUSIC_FILE)) {
        return backgroundMusicDefaultConfig();
    }
    $raw = json_decode((string)@file_get_contents(BACKGROUND_MUSIC_FILE), true);
    return backgroundMusicNormalizeConfig($raw);
}

function backgroundMusicSaveConfig($raw): array {
    $config = backgroundMusicNormalizeConfig($raw);
    $dir = dirname(BACKGROUND_MUSIC_FILE);
    if (!is_dir($dir)) @mkdir($dir, 0775, true);
    $json = json_encode($config, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $tmp = @tempnam($dir, '.bgmusic.');
    if ($tmp === false) {
        @file_put_contents(BACKGROUND_MUSIC_FILE, $json);
        @chmod(BACKGROUND_MUSIC_FILE, 0664);
        return $config;
    }
    if (@file_put_contents($tmp, $json) !== false && @rename($tmp, BACKGROUND_MUSIC_FILE)) {
        @chmod(BACKGROUND_MUSIC_FILE, 0664);
    } else {
        @unlink($tmp);
    }
    return $config;
}

function backgroundMusicListLocalAudio(): array {
    $dir = BACKGROUND_MUSIC_MEDIA_PATH;
    if (!is_dir($dir)) return [];

    $files = [];
    $extensions = backgroundMusicAudioExtensions();
    foreach (glob(rtrim($dir, '/') . '/*') ?: [] as $path) {
        if (!is_file($path)) continue;
        $base = basename($path);
        $ext = strtolower(pathinfo($base, PATHINFO_EXTENSION));
        if (!in_array($ext, $extensions, true)) continue;
        $files[] = [
            'name' => rawurldecode($base),
            'path' => '/' . trim(BACKGROUND_MUSIC_MEDIA_URL_PREFIX, '/') . '/' . rawurlencode(rawurldecode($base)),
            'type' => 'audio',
            'size' => filesize($path) ?: 0,
            'modified' => filemtime($path) ?: 0,
        ];
    }
    usort($files, function ($a, $b) {
        return strcasecmp($a['name'], $b['name']);
    });
    return $files;
}

function backgroundMusicSelectedRadio(array $config): ?array {
    return backgroundMusicPresetById((string)($config['radio'] ?? ''));
}

function backgroundMusicPayload(): array {
    $config = backgroundMusicLoadConfig();
    return [
        'config' => $config,
        'selected_radio' => backgroundMusicSelectedRadio($config),
        'presets' => backgroundMusicRadioPresets(),
        'audio_files' => backgroundMusicListLocalAudio(),
    ];
}
