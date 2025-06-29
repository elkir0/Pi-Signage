<?php
/**
 * Template de configuration Pi Signage
 * Ce fichier est utilisé pour générer includes/config.php lors de l'installation
 */

// Protection contre l'accès direct
if (!defined('PI_SIGNAGE_WEB')) {
    define('PI_SIGNAGE_WEB', true);
}

// Configuration de session sécurisée
ini_set('session.cookie_httponly', '1');
ini_set('session.use_only_cookies', '1');
ini_set('session.cookie_secure', '0'); // Mettre à 1 si HTTPS
ini_set('session.cookie_samesite', 'Strict');

// Chemins système
define('VIDEO_DIR', '/opt/videos');
define('SCRIPTS_DIR', '/opt/scripts');
define('LOG_DIR', '/var/log/pi-signage');
define('WEB_ROOT', dirname(__DIR__));

// Configuration d'authentification
define('ADMIN_USERNAME', 'admin');
define('ADMIN_PASSWORD_HASH', '{{WEB_ADMIN_PASSWORD_HASH}}');

// Configuration VLC
define('VLC_SERVICE', 'vlc-signage.service');
define('VLC_HTTP_HOST', '127.0.0.1');
define('VLC_HTTP_PORT', '8080');

// Configuration Glances
define('GLANCES_URL', 'http://localhost:61208');

// Limite de taille d'upload (en MB)
define('MAX_UPLOAD_SIZE', 100);

// Extensions autorisées pour l'upload
define('ALLOWED_EXTENSIONS', ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v']);

// Durée de session (en secondes)
define('SESSION_LIFETIME', 3600); // 1 heure

// Mode debug (désactiver en production)
define('DEBUG_MODE', false);

// Timezone
date_default_timezone_set('Europe/Paris');