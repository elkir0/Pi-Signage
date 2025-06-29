<?php
/**
 * Pi Signage Digital - Configuration
 * @version 2.0.0
 */

// Empêcher l'accès direct
if (!defined('INCLUDED')) {
    define('INCLUDED', true);
}

// Version
define('VERSION', '2.0.0');

// Chemins
define('VIDEO_DIR', '/opt/videos');
define('LOG_DIR', '/var/log/pi-signage');
define('CONFIG_FILE', '/etc/pi-signage/config.conf');
define('TEMP_DIR', '/var/www/pi-signage/temp');

// Configuration système
define('MAX_UPLOAD_SIZE', 100 * 1024 * 1024); // 100MB
define('ALLOWED_VIDEO_FORMATS', ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v']);
define('SESSION_TIMEOUT', 3600); // 1 heure

// Configuration yt-dlp
define('YTDLP_BIN', '/usr/local/bin/yt-dlp');
define('YTDLP_OPTIONS', [
    'format' => 'best[height<=1080]/best',
    'output' => VIDEO_DIR . '/%(title)s.%(ext)s',
    'restrict-filenames' => true,
    'no-playlist' => true,
    'no-overwrites' => true
]);

// Services à surveiller
define('MONITORED_SERVICES', [
    'vlc' => 'vlc-signage.service',
    'glances' => 'glances.service',
    'lightdm' => 'lightdm.service',
    'watchdog' => 'pi-signage-watchdog.service'
]);

// Configuration de la base de données (si nécessaire dans le futur)
// Pour l'instant, on utilise des fichiers

// Charger la configuration système
function loadSystemConfig() {
    $config = [];
    
    if (file_exists(CONFIG_FILE)) {
        $lines = file(CONFIG_FILE, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            if (strpos($line, '=') !== false && $line[0] !== '#') {
                list($key, $value) = explode('=', $line, 2);
                $config[trim($key)] = trim($value, '"');
            }
        }
    }
    
    return $config;
}

// Configuration utilisateur depuis le fichier système
$systemConfig = loadSystemConfig();

// Authentification
define('ADMIN_USER', $systemConfig['WEB_ADMIN_USER'] ?? 'admin');
define('ADMIN_PASSWORD_HASH', password_hash($systemConfig['WEB_ADMIN_PASSWORD'] ?? 'admin', PASSWORD_DEFAULT));

// Google Drive
define('GDRIVE_FOLDER', $systemConfig['GDRIVE_FOLDER'] ?? 'Signage');

// Timezone
date_default_timezone_set('Europe/Paris');

// Error reporting (désactiver en production)
if (isset($_SERVER['SERVER_NAME']) && $_SERVER['SERVER_NAME'] === 'localhost') {
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
} else {
    error_reporting(0);
    ini_set('display_errors', 0);
}

// Sécurité des sessions
ini_set('session.cookie_httponly', 1);
ini_set('session.use_only_cookies', 1);
ini_set('session.cookie_samesite', 'Strict');

// Créer les répertoires nécessaires s'ils n'existent pas
if (!file_exists(TEMP_DIR)) {
    mkdir(TEMP_DIR, 0775, true);
    chown(TEMP_DIR, 'www-data');
    chgrp(TEMP_DIR, 'www-data');
}