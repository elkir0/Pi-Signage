<?php
/**
 * PiSignage Desktop v3.0 - Configuration
 * Copyright (c) 2024 PiSignage
 */

// Load system configuration
$config_file = PISIGNAGE_ROOT . '/config/default.conf';
$config = [];

if (file_exists($config_file)) {
    $lines = file($config_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line && !str_starts_with($line, '#')) {
            if (strpos($line, '=') !== false) {
                list($key, $value) = explode('=', $line, 2);
                $config[trim($key)] = trim($value);
            }
        }
    }
}

// Define constants from config
define('PISIGNAGE_USER', $config['PISIGNAGE_USER'] ?? 'pisignage');
define('VIDEO_PATH', $config['VIDEO_PATH'] ?? PISIGNAGE_ROOT . '/videos');
define('WEB_PORT', $config['WEB_PORT'] ?? 80);
define('LOG_LEVEL', $config['LOG_LEVEL'] ?? 'INFO');

// Database configuration (if needed in future)
define('DB_HOST', 'localhost');
define('DB_NAME', 'pisignage');
define('DB_USER', 'pisignage');
define('DB_PASS', '');

// Security settings
define('WEB_AUTH_ENABLED', $config['WEB_AUTH_ENABLED'] ?? 'false');
define('DEFAULT_PASSWORD', $config['DEFAULT_PASSWORD'] ?? 'pisignage');
?>