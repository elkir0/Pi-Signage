#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/pisignage-bg-music.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

php <<PHP
<?php
define('BACKGROUND_MUSIC_FILE', '$TMP_ROOT/config/background-music.json');
define('BACKGROUND_MUSIC_MEDIA_PATH', '$TMP_ROOT/media');
define('BACKGROUND_MUSIC_MEDIA_URL_PREFIX', '/media');

require '$ROOT_DIR/web/api/background-music-lib.php';

function assert_true(
    bool \$condition,
    string \$message
): void {
    if (!\$condition) {
        fwrite(STDERR, "FAIL: " . \$message . PHP_EOL);
        exit(1);
    }
}

@mkdir(BACKGROUND_MUSIC_MEDIA_PATH, 0775, true);
file_put_contents(BACKGROUND_MUSIC_MEDIA_PATH . '/lounge.mp3', 'x');
file_put_contents(BACKGROUND_MUSIC_MEDIA_PATH . '/ambient.ogg', 'x');
file_put_contents(BACKGROUND_MUSIC_MEDIA_PATH . '/clip.mp4', 'x');

\$presets = backgroundMusicRadioPresets();
assert_true(count(\$presets) >= 15, 'at least 15 radio presets are available');
assert_true(isset(\$presets[0]['id'], \$presets[0]['url']), 'radio presets expose id and url');

\$default = backgroundMusicDefaultConfig();
assert_true(\$default['enabled'] === false, 'default config is disabled');
assert_true(\$default['source'] === 'webradio', 'default source is webradio');

\$audioFiles = backgroundMusicListLocalAudio();
\$paths = array_column(\$audioFiles, 'path');
sort(\$paths);
assert_true(\$paths === ['/media/ambient.ogg', '/media/lounge.mp3'], 'local audio listing filters non-audio files');

\$saved = backgroundMusicSaveConfig([
    'enabled' => true,
    'source' => 'local',
    'radio' => 'unknown-station',
    'playback' => 'random',
    'tracks' => ['/media/lounge.mp3', '/media/../bad.mp3', 'https://example.test/bad.mp3', '/media/ambient.ogg', '/media/missing.mp3', '/media/clip.mp4'],
]);

assert_true(\$saved['enabled'] === true, 'enabled value is persisted');
assert_true(\$saved['source'] === 'local', 'local source is persisted');
assert_true(\$saved['playback'] === 'random', 'random playback is persisted');
assert_true(\$saved['radio'] === \$default['radio'], 'unknown radio falls back to default preset');
assert_true(\$saved['tracks'] === ['/media/lounge.mp3', '/media/ambient.ogg'], 'tracks are sanitized to local audio urls');

\$loaded = backgroundMusicLoadConfig();
assert_true(\$loaded === \$saved, 'saved config loads back unchanged');

echo "background-music-config ok" . PHP_EOL;
PHP
