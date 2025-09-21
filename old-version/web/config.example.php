<?php
/**
 * PiSignage Desktop v3.0 - Exemple de configuration
 * Copiez ce fichier vers includes/config.php et modifiez selon vos besoins
 */

// Protection contre l'accès direct
if (!defined('PISIGNAGE_DESKTOP')) {
    die('Direct access not allowed');
}

// Configuration de session sécurisée
ini_set('session.cookie_httponly', '1');
ini_set('session.use_only_cookies', '1');
ini_set('session.cookie_secure', '0'); // Mettre à 1 si HTTPS
ini_set('session.cookie_samesite', 'Strict');

// === CHEMINS SYSTÈME ===
define('VIDEO_DIR', '/opt/videos');
define('SCRIPTS_DIR', '/opt/scripts');
define('PLAYLIST_FILE', '/opt/pisignage/playlist.json');
define('WEB_ROOT', dirname(__DIR__));

// === AUTHENTIFICATION ===
// ⚠️ CHANGEZ CES VALEURS EN PRODUCTION !
define('ADMIN_USERNAME', 'admin');
define('ADMIN_PASSWORD', 'votre_mot_de_passe_fort'); // Changez absolument ceci !

// === CONFIGURATION SYSTÈME ===
// Mode d'affichage (toujours Chromium pour Desktop)
define('DISPLAY_MODE', 'chromium');

// Service principal
define('PISIGNAGE_SERVICE', 'pisignage-desktop.service');

// URL du player
define('PLAYER_URL', 'http://localhost:8080');

// === LIMITES ===
define('MAX_UPLOAD_SIZE', 200); // MB
define('ALLOWED_EXTENSIONS', ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v']);

// Durée de session (1 heure par défaut)
define('SESSION_LIFETIME', 3600);

// === APPLICATION ===
define('APP_NAME', 'PiSignage Desktop');
define('APP_VERSION', '3.0.0');

// Timezone
date_default_timezone_set('Europe/Paris');

// === API ===
define('API_ENABLED', true);
define('API_VERSION', 'v1');

// === SÉCURITÉ ===
define('CSRF_TOKEN_LIFETIME', 3600);
define('MAX_LOGIN_ATTEMPTS', 5);
define('LOCKOUT_TIME', 300); // 5 minutes

// === ENVIRONNEMENT ===
// Mode debug (désactiver en production)
define('DEBUG_MODE', false);

// Logs
define('LOG_LEVEL', 'INFO'); // DEBUG, INFO, WARNING, ERROR

// === FONCTIONNALITÉS OPTIONNELLES ===
// YouTube-dl
define('YTDLP_ENABLED', true);
define('YTDLP_BINARY', '/usr/local/bin/yt-dlp');

// Notifications
define('NOTIFICATIONS_ENABLED', true);

// Auto-update playlist
define('AUTO_UPDATE_PLAYLIST', true);

// === PERSONNALISATION ===
// Logo (chemin relatif depuis public/)
define('LOGO_PATH', 'assets/img/logo.png');

// Couleur principale (CSS)
define('PRIMARY_COLOR', '#3b82f6');

// === INTÉGRATIONS ===
// API externe (optionnel)
define('EXTERNAL_API_URL', '');
define('EXTERNAL_API_KEY', '');

// Webhook pour notifications (optionnel)
define('WEBHOOK_URL', '');

// === SAUVEGARDE ===
// Dossier de sauvegarde automatique
define('BACKUP_DIR', '/opt/pisignage/backups');

// Rétention des sauvegardes (jours)
define('BACKUP_RETENTION', 30);

// === AVANCÉ ===
// Timeout pour les commandes système
define('SYSTEM_COMMAND_TIMEOUT', 30);

// Pool de connexions
define('MAX_CONCURRENT_UPLOADS', 3);

// Cache
define('CACHE_ENABLED', true);
define('CACHE_LIFETIME', 300); // 5 minutes