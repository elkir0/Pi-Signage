<?php
/**
 * PiSignage - Kiosk Mode API
 * Manages Chromium kiosk configuration for Trixie/Wayland
 *
 * Endpoints:
 *   GET  /api/kiosk/url      -> Returns current kiosk URL
 *   PUT  /api/kiosk/url      -> Updates kiosk URL and reloads
 *   GET  /api/kiosk/flags    -> Returns current Chromium flags
 *   PUT  /api/kiosk/flags    -> Updates Chromium flags and reloads
 *   POST /api/kiosk/restart  -> Restarts Chromium kiosk
 */

require_once "/opt/pisignage/web/config.php";

// Configuration paths
define('KIOSK_CONFIG_DIR', '/opt/pisignage/config');
define('KIOSK_URL_FILE', KIOSK_CONFIG_DIR . '/kiosk_url');
define('KIOSK_FLAGS_FILE', KIOSK_CONFIG_DIR . '/kiosk_flags');
define('KIOSK_FEATURE_FLAGS_FILE', KIOSK_CONFIG_DIR . '/feature_flags');
define('KIOSK_APPLY_SCRIPT', '/opt/pisignage/scripts/kiosk-apply');

// Get HTTP method and path
$method = $_SERVER['REQUEST_METHOD'];
$pathInfo = $_SERVER['PATH_INFO'] ?? '';
$input = json_decode(file_get_contents('php://input'), true);

// Route based on PATH_INFO and method
if ($pathInfo === '/url') {
    if ($method === 'GET') {
        handleGetUrl();
    } elseif ($method === 'PUT') {
        handlePutUrl($input);
    } else {
        jsonResponse(false, null, 'Method not allowed for /url', 405);
    }
} elseif ($pathInfo === '/flags') {
    if ($method === 'GET') {
        handleGetFlags();
    } elseif ($method === 'PUT') {
        handlePutFlags($input);
    } else {
        jsonResponse(false, null, 'Method not allowed for /flags', 405);
    }
} elseif ($pathInfo === '/restart') {
    if ($method === 'POST') {
        handleRestart();
    } else {
        jsonResponse(false, null, 'Method not allowed for /restart (use POST)', 405);
    }
} else {
    // Default: return kiosk status
    if ($method === 'GET') {
        handleGetStatus();
    } else {
        jsonResponse(false, null, 'Invalid endpoint. Use /url, /flags, or /restart', 404);
    }
}

/**
 * GET /api/kiosk/url
 * Returns the current kiosk URL
 */
function handleGetUrl() {
    if (!file_exists(KIOSK_URL_FILE)) {
        jsonResponse(false, null, 'Kiosk URL not configured', 404);
        return;
    }

    $url = trim(file_get_contents(KIOSK_URL_FILE));
    jsonResponse(true, ['url' => $url], 'Current kiosk URL');
}

/**
 * PUT /api/kiosk/url
 * Updates the kiosk URL and triggers reload
 */
function handlePutUrl($input) {
    if (!isset($input['url']) || empty($input['url'])) {
        jsonResponse(false, null, 'Missing required field: url', 400);
        return;
    }

    $url = trim($input['url']);

    // Validate URL
    if (!filter_var($url, FILTER_VALIDATE_URL)) {
        jsonResponse(false, null, 'Invalid URL format', 400);
        return;
    }

    // Ensure config directory exists
    if (!is_dir(KIOSK_CONFIG_DIR)) {
        mkdir(KIOSK_CONFIG_DIR, 0755, true);
    }

    // Write URL to config file
    if (file_put_contents(KIOSK_URL_FILE, $url) === false) {
        jsonResponse(false, null, 'Failed to write kiosk URL', 500);
        return;
    }

    logMessage("Kiosk URL updated to: $url", 'INFO');

    // Trigger kiosk-apply to regenerate autostart
    $applyResult = applyKioskConfig();

    jsonResponse(true, [
        'url' => $url,
        'applied' => $applyResult['success'],
        'message' => $applyResult['message']
    ], 'Kiosk URL updated successfully');
}

/**
 * GET /api/kiosk/flags
 * Returns the current Chromium flags
 */
function handleGetFlags() {
    if (!file_exists(KIOSK_FLAGS_FILE)) {
        jsonResponse(false, null, 'Kiosk flags not configured', 404);
        return;
    }

    $flags = trim(file_get_contents(KIOSK_FLAGS_FILE));
    jsonResponse(true, ['flags' => $flags], 'Current Chromium flags');
}

/**
 * PUT /api/kiosk/flags
 * Updates the Chromium flags and triggers reload
 */
function handlePutFlags($input) {
    if (!isset($input['flags'])) {
        jsonResponse(false, null, 'Missing required field: flags', 400);
        return;
    }

    $flags = trim($input['flags']);

    // Basic validation: ensure no shell injection
    if (preg_match('/[;&|`$]/', $flags)) {
        jsonResponse(false, null, 'Invalid characters in flags', 400);
        return;
    }

    // Ensure config directory exists
    if (!is_dir(KIOSK_CONFIG_DIR)) {
        mkdir(KIOSK_CONFIG_DIR, 0755, true);
    }

    // Write flags to config file
    if (file_put_contents(KIOSK_FLAGS_FILE, $flags) === false) {
        jsonResponse(false, null, 'Failed to write kiosk flags', 500);
        return;
    }

    logMessage("Kiosk flags updated to: $flags", 'INFO');

    // Trigger kiosk-apply to regenerate autostart
    $applyResult = applyKioskConfig();

    jsonResponse(true, [
        'flags' => $flags,
        'applied' => $applyResult['success'],
        'message' => $applyResult['message']
    ], 'Kiosk flags updated successfully');
}

/**
 * POST /api/kiosk/restart
 * Restarts the Chromium kiosk browser
 */
function handleRestart() {
    logMessage("Kiosk restart requested via API", 'INFO');

    // Kill existing Chromium processes
    exec('pkill -f "/usr/bin/chromium" 2>&1', $killOutput, $killCode);

    sleep(1);

    // Re-apply kiosk configuration (will restart Chromium via autostart on next login)
    $applyResult = applyKioskConfig();

    // Note: Chromium will restart on next labwc session start or user login
    // For immediate restart, would need to restart labwc session (complex)

    jsonResponse(true, [
        'killed' => $killCode === 0 || $killCode === 1, // 1 = no process found (ok)
        'applied' => $applyResult['success'],
        'message' => 'Chromium killed. Will restart on next labwc session.',
        'note' => 'For immediate effect, logout/login or restart labwc session'
    ], 'Kiosk restart triggered');
}

/**
 * GET /api/kiosk (default)
 * Returns kiosk status and configuration
 */
function handleGetStatus() {
    $status = [
        'enabled' => isKioskEnabled(),
        'url' => file_exists(KIOSK_URL_FILE) ? trim(file_get_contents(KIOSK_URL_FILE)) : null,
        'flags' => file_exists(KIOSK_FLAGS_FILE) ? trim(file_get_contents(KIOSK_FLAGS_FILE)) : null,
        'chromium_running' => isChromiumRunning(),
        'autostart_exists' => file_exists($_SERVER['HOME'] . '/.config/labwc/autostart'),
    ];

    jsonResponse(true, $status, 'Kiosk status');
}

/**
 * Apply kiosk configuration by running kiosk-apply script
 */
function applyKioskConfig() {
    if (!file_exists(KIOSK_APPLY_SCRIPT)) {
        return [
            'success' => false,
            'message' => 'kiosk-apply script not found at ' . KIOSK_APPLY_SCRIPT
        ];
    }

    exec("bash " . KIOSK_APPLY_SCRIPT . " 2>&1", $output, $returnCode);

    return [
        'success' => $returnCode === 0,
        'message' => implode("\n", $output),
        'return_code' => $returnCode
    ];
}

/**
 * Check if kiosk mode is enabled
 */
function isKioskEnabled() {
    if (!file_exists(KIOSK_FEATURE_FLAGS_FILE)) {
        return true; // Default: enabled
    }

    $content = file_get_contents(KIOSK_FEATURE_FLAGS_FILE);
    return strpos($content, 'ENABLE_KIOSK=0') === false;
}

/**
 * Check if Chromium is currently running
 */
function isChromiumRunning() {
    exec('pgrep -f "/usr/bin/chromium"', $output, $returnCode);
    return $returnCode === 0;
}
