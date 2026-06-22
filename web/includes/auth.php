<?php
/**
 * PiSignage v0.12 - Authentication and Session Management
 * Handles session initialization and configuration management.
 * v0.12: Chromium HTML5 is the sole player engine (VLC removed).
 */

require_once __DIR__ . '/../version.php';

// Start session if not already started
if (session_status() === PHP_SESSION_NONE) {
    // 'secure' dérivé UNIQUEMENT du vrai TLS (jamais X-Forwarded-Proto, spoofable -> self-DoS LAN HTTP).
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
          || (($_SERVER['SERVER_PORT'] ?? '') === '443');
    @ini_set('session.use_strict_mode', '1');
    session_set_cookie_params(['lifetime' => 0, 'path' => '/', 'httponly' => true, 'samesite' => 'Lax', 'secure' => $https]);
    session_start();
}

// Jeton CSRF par session (survit à session_regenerate_id, qui préserve $_SESSION).
if (empty($_SESSION['csrf'])) {
    $_SESSION['csrf'] = bin2hex(random_bytes(32));
}

// === PONT D'AUTH RELAIS — « mode complet » à distance via le tunnel WireGuard ===
// Le proxy UI du relais (conteneur dans le netns WireGuard, source wg0 = 10.70.0.1)
// présente un secret partagé. On établit une session admin SEULEMENT si :
//   (a) REMOTE_ADDR == 10.70.0.1 — la passerelle relais. NON-SPOOFABLE : TCP exige
//       le handshake (un SYN à source usurpée n'aboutit jamais), et l'isolation WG
//       (FORWARD wg0->wg0 DROP côté relais + allowed_ips clampés côté agent)
//       empêche tout autre pair d'être 10.70.0.1 ou d'atteindre ce Pi ;
//   (b) le header X-Zaforge-Proxy correspond au secret (hash_equals, >= 32).
// REMOTE_ADDR est le vrai pair TCP (cet nginx ne fait pas confiance à XFF). Aucune
// interférence avec le login LAN (192.168.1.x) ni le kiosk (127.0.0.1, sans header).
// L'opérateur a déjà passé l'auth console (httpOnly + CSRF + TLS) avant d'arriver ici.
if (empty($_SESSION['authenticated'])) {
    $zfProxyHdr = $_SERVER['HTTP_X_ZAFORGE_PROXY'] ?? '';
    if ($zfProxyHdr !== '') {
        $zfRemote = $_SERVER['REMOTE_ADDR'] ?? '';
        $zfSecretFile = '/opt/pisignage/config/relay-proxy-secret';
        $zfExpected = is_readable($zfSecretFile) ? trim((string)@file_get_contents($zfSecretFile)) : '';
        if ($zfRemote === '10.70.0.1' && $zfExpected !== ''
            && strlen($zfProxyHdr) >= 32 && hash_equals($zfExpected, $zfProxyHdr)) {
            $_SESSION['authenticated']   = true;
            $_SESSION['username']        = 'admin';
            $_SESSION['login_time']      = $_SESSION['login_time'] ?? time();
            $_SESSION['last_activity']   = time();
            $_SESSION['via_relay_proxy'] = true;
            // L'opérateur distant a déjà été authentifié par la console : on ne le
            // bloque pas sur le mur de changement de mot de passe par défaut.
            unset($_SESSION['must_change_password']);
        } else {
            @error_log('[pisignage] relay-proxy auth refusée depuis ' . $zfRemote);
        }
    }
}

// Durée de vie côté serveur des sessions AUTHENTIFIÉES (le kiosk/agent ne portent pas de session).
if (!empty($_SESSION['authenticated'])) {
    $now = time();
    $idleMax = 8 * 3600;   // 8h d'inactivité
    $absMax  = 7 * 86400;  // 7j absolus
    $login = $_SESSION['login_time'] ?? $now;
    $last  = $_SESSION['last_activity'] ?? $now;
    if (($now - $last) > $idleMax || ($now - $login) > $absMax) {
        $_SESSION = [];
        session_destroy();
    } else {
        $_SESSION['last_activity'] = $now;
    }
}

// Configuration
$config = [
    'version' => PISIGNAGE_VERSION_NUM,
    'media_path' => '/opt/pisignage/media/',
    'config_path' => '/opt/pisignage/config/',
    'logs_path' => '/opt/pisignage/logs/',
    'upload_max_size' => 500 * 1024 * 1024, // 500MB
    'credentials_file' => '/opt/pisignage/config/credentials.json',
];

// Ensure directories exist
$dirs = [$config['media_path'], $config['config_path'], $config['logs_path']];
foreach ($dirs as $dir) {
    if (!file_exists($dir)) {
        mkdir($dir, 0755, true);
    }
}

// Initialize default credentials if file doesn't exist
function initializeCredentials() {
    global $config;
    if (!file_exists($config['credentials_file'])) {
        $defaultCredentials = [
            'username' => 'admin',
            'password' => password_hash('signage2025', PASSWORD_BCRYPT, ['cost' => 12])
        ];
        file_put_contents($config['credentials_file'], json_encode($defaultCredentials, JSON_PRETTY_PRINT));
        chmod($config['credentials_file'], 0600); // Secure file permissions
    }
}

// Load credentials
function loadCredentials() {
    global $config;
    initializeCredentials();
    $data = file_get_contents($config['credentials_file']);
    return json_decode($data, true);
}

// Verify login credentials.
// Pas de court-circuit sur le username : on exécute toujours password_verify contre le hash
// stocké (travail constant) et on compare le username en temps constant (hash_equals).
function verifyLogin($username, $password) {
    global $config;
    $credentials = loadCredentials();
    $userOk = hash_equals((string)$credentials['username'], (string)$username);
    $passOk = password_verify($password, $credentials['password']);
    if ($userOk && $passOk) {
        $_SESSION['authenticated'] = true;
        $_SESSION['username'] = $credentials['username'];
        $_SESSION['login_time'] = time();
        $_SESSION['last_activity'] = time();
        session_regenerate_id(true);
        if (password_verify('signage2025', $credentials['password'])) {
            $_SESSION['must_change_password'] = true;
        }
        // Rehash transparent vers cost=12 (écriture atomique).
        if (password_needs_rehash($credentials['password'], PASSWORD_BCRYPT, ['cost' => 12])) {
            $credentials['password'] = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
            $tmp = $config['credentials_file'] . '.tmp';
            file_put_contents($tmp, json_encode($credentials, JSON_PRETTY_PRINT));
            chmod($tmp, 0600);
            rename($tmp, $config['credentials_file']);
        }
        return true;
    }
    return false;
}

// Update password
function updatePassword($oldPassword, $newPassword) {
    global $config;
    $credentials = loadCredentials();

    if (!password_verify($oldPassword, $credentials['password'])) {
        return ['success' => false, 'message' => 'Ancien mot de passe incorrect'];
    }

    if (strlen($newPassword) < 8) {
        return ['success' => false, 'message' => 'Le mot de passe doit faire au moins 8 caractères'];
    }

    // Refuser les mots de passe faibles / par défaut.
    $weak = ['signage2025', 'password', 'admin', 'administrator', '12345678', 'pisignage', 'zaforge', (string)gethostname()];
    $lower = strtolower($newPassword);
    foreach ($weak as $w) {
        if ($w !== '' && $lower === strtolower($w)) {
            return ['success' => false, 'message' => 'Mot de passe trop faible / par défaut interdit'];
        }
    }

    $credentials['password'] = password_hash($newPassword, PASSWORD_BCRYPT, ['cost' => 12]);
    $tmp = $config['credentials_file'] . '.tmp';
    if (file_put_contents($tmp, json_encode($credentials, JSON_PRETTY_PRINT)) !== false) {
        chmod($tmp, 0600);
        rename($tmp, $config['credentials_file']);
        unset($_SESSION['must_change_password']);
        session_regenerate_id(true);
        return ['success' => true, 'message' => 'Mot de passe mis à jour'];
    }

    return ['success' => false, 'message' => 'Erreur lors de la sauvegarde'];
}

// Check if user is authenticated
function isAuthenticated() {
    return isset($_SESSION['authenticated']) && $_SESSION['authenticated'] === true;
}

// Require authentication (redirect to login if not authenticated)
function requireAuth() {
    if (!isAuthenticated()) {
        $currentPage = $_SERVER['REQUEST_URI'];
        $_SESSION['redirect_after_login'] = $currentPage;
        header('Location: /login.php');
        exit;
    }

    // Forcer le changement du mot de passe par défaut (pages WEB uniquement).
    // player.php / GET /api/playlist sont publics et n'appellent jamais requireAuth().
    if (!empty($_SESSION['must_change_password'])) {
        $page = getCurrentPage();
        if (!in_array($page, ['login', 'settings'], true)) {
            header('Location: /settings.php?force_password=1');
            exit;
        }
    }
}

// Logout function
function logout() {
    session_destroy();
    header('Location: /login.php');
    exit;
}

function getCurrentPage() {
    $scriptName = basename($_SERVER['SCRIPT_NAME'], '.php');
    return $scriptName;
}

// Initialize credentials on first load
initializeCredentials();
?>
