<?php
/**
 * PiSignage - Kiosk Mode API
 * Manages Chromium kiosk configuration for Trixie/Wayland
 *
 * Endpoints:
 *   GET  /api/kiosk          -> Returns kiosk status
 *   GET  /api/kiosk/status   -> Returns kiosk status (alias)
 *   GET  /api/kiosk/health   -> Health check endpoint
 *   GET  /api/kiosk/url      -> Returns current kiosk URL
 *   PUT  /api/kiosk/url      -> Updates kiosk URL and reloads
 *   GET  /api/kiosk/flags    -> Returns current Chromium flags
 *   PUT  /api/kiosk/flags    -> Updates Chromium flags and reloads
 *   PUT  /api/kiosk/enable   -> Enable/disable kiosk mode
 *   PUT  /api/kiosk/mode            -> Switch between Chromium player and VLC
 *   POST /api/kiosk/restart         -> Restarts Chromium kiosk
 *   POST /api/kiosk/restart-session -> Restarts the full greetd session (R7)
 *   GET  /api/kiosk/screen          -> Returns screen power state + schedule (D1)
 *   PUT  /api/kiosk/screen          -> Saves the screen power schedule (D1)
 *   POST /api/kiosk/screen/on       -> Turns the screen on now (D1)
 *   POST /api/kiosk/screen/off      -> Turns the screen off now (D1)
 */

require_once __DIR__ . '/_guard.php';
require_once "/opt/pisignage/web/config.php";

// Configuration paths
define('KIOSK_CONFIG_DIR', '/opt/pisignage/config');
define('KIOSK_URL_FILE', KIOSK_CONFIG_DIR . '/kiosk_url');
define('KIOSK_FLAGS_FILE', KIOSK_CONFIG_DIR . '/kiosk_flags');
define('KIOSK_FEATURE_FLAGS_FILE', KIOSK_CONFIG_DIR . '/feature_flags');
define('KIOSK_SCREEN_SCHEDULE_FILE', KIOSK_CONFIG_DIR . '/screen_schedule.json');
define('KIOSK_APPLY_SCRIPT', '/opt/pisignage/scripts/kiosk-apply');
define('KIOSK_SCREEN_POWER_SCRIPT', '/opt/pisignage/scripts/screen-power.sh');

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
} elseif ($pathInfo === '/restart-session') {
    if ($method === 'POST') {
        handleRestartSession();
    } else {
        jsonResponse(false, null, 'Method not allowed for /restart-session (use POST)', 405);
    }
} elseif ($pathInfo === '/screen/on') {
    if ($method === 'POST') {
        handleScreenPower('on');
    } else {
        jsonResponse(false, null, 'Method not allowed for /screen/on (use POST)', 405);
    }
} elseif ($pathInfo === '/screen/off') {
    if ($method === 'POST') {
        handleScreenPower('off');
    } else {
        jsonResponse(false, null, 'Method not allowed for /screen/off (use POST)', 405);
    }
} elseif ($pathInfo === '/screen') {
    if ($method === 'GET') {
        handleGetScreen();
    } elseif ($method === 'PUT') {
        handlePutScreen($input);
    } else {
        jsonResponse(false, null, 'Method not allowed for /screen', 405);
    }
} elseif ($pathInfo === '/status' || $pathInfo === '' || $pathInfo === '/') {
    if ($method === 'GET') {
        handleGetStatus();
    } else {
        jsonResponse(false, null, 'Method not allowed for /status (use GET)', 405);
    }
} elseif ($pathInfo === '/health') {
    if ($method === 'GET') {
        handleGetHealth();
    } else {
        jsonResponse(false, null, 'Method not allowed for /health (use GET)', 405);
    }
} elseif ($pathInfo === '/enable') {
    if ($method === 'PUT') {
        handlePutEnable($input);
    } else {
        jsonResponse(false, null, 'Method not allowed for /enable (use PUT)', 405);
    }
} elseif ($pathInfo === '/mode') {
    if ($method === 'PUT') {
        handlePutMode($input);
    } else {
        jsonResponse(false, null, 'Method not allowed for /mode (use PUT)', 405);
    }
} else {
    jsonResponse(false, null, 'Invalid endpoint', 404);
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

    // Restrict to http/https only (blocks file:/javascript:/data:)
    $scheme = parse_url($url, PHP_URL_SCHEME);
    if (!in_array($scheme, ['http', 'https'], true)) {
        jsonResponse(false, null, 'Schéma URL non autorisé', 400);
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
 * GET /api/kiosk (default) or GET /api/kiosk/status
 * Returns kiosk status and configuration
 */
function handleGetStatus() {
    $useChromiumPlayer = isChromiumPlayerEnabled();

    $status = [
        'enabled' => isKioskEnabled(),
        'useChromiumPlayer' => $useChromiumPlayer,
        'url' => file_exists(KIOSK_URL_FILE) ? trim(file_get_contents(KIOSK_URL_FILE)) : null,
        'flags' => file_exists(KIOSK_FLAGS_FILE) ? trim(file_get_contents(KIOSK_FLAGS_FILE)) : null,
        'chromiumRunning' => isChromiumRunning(),
        'chromiumPlayer' => $useChromiumPlayer ? 'active' : 'vlc-fallback',
        'autostartExists' => file_exists($_SERVER['HOME'] . '/.config/labwc/autostart'),
        'lastUpdate' => date('Y-m-d H:i:s'),
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

/**
 * Check if Chromium Player mode is enabled
 */
function isChromiumPlayerEnabled() {
    if (!file_exists(KIOSK_FEATURE_FLAGS_FILE)) {
        return true; // Default: enabled
    }

    $content = file_get_contents(KIOSK_FEATURE_FLAGS_FILE);
    return strpos($content, 'USE_CHROMIUM_PLAYER=0') === false;
}

/**
 * Update feature flag in feature_flags file
 */
function updateFeatureFlag($flag, $value) {
    // Ensure config directory exists
    if (!is_dir(KIOSK_CONFIG_DIR)) {
        mkdir(KIOSK_CONFIG_DIR, 0755, true);
    }

    // Read existing flags or create default
    if (file_exists(KIOSK_FEATURE_FLAGS_FILE)) {
        $content = file_get_contents(KIOSK_FEATURE_FLAGS_FILE);
        $lines = explode("\n", $content);
    } else {
        $lines = [
            '# PiSignage Feature Flags',
            'ENABLE_KIOSK=1',
            'USE_CHROMIUM_PLAYER=1',
        ];
    }

    // Update or add flag
    $flagPattern = "/^" . preg_quote($flag, '/') . "=/";
    $flagLine = "$flag=$value";
    $found = false;

    foreach ($lines as $i => $line) {
        if (preg_match($flagPattern, $line)) {
            $lines[$i] = $flagLine;
            $found = true;
            break;
        }
    }

    if (!$found) {
        $lines[] = $flagLine;
    }

    // Write back
    $content = implode("\n", $lines);
    if (file_put_contents(KIOSK_FEATURE_FLAGS_FILE, $content) === false) {
        return ['success' => false, 'message' => 'Failed to write feature flags'];
    }

    return ['success' => true, 'message' => 'Feature flag updated'];
}

/**
 * GET /api/kiosk/health
 * Health check endpoint
 */
function handleGetHealth() {
    $kioskEnabled = isKioskEnabled();
    $chromiumRunning = isChromiumRunning();
    $autostartExists = file_exists($_SERVER['HOME'] . '/.config/labwc/autostart');

    $healthy = true;
    $issues = [];

    if ($kioskEnabled && !$chromiumRunning) {
        $healthy = false;
        $issues[] = 'Chromium not running despite kiosk being enabled';
    }

    if ($kioskEnabled && !$autostartExists) {
        $healthy = false;
        $issues[] = 'Autostart file missing';
    }

    jsonResponse(true, [
        'healthy' => $healthy,
        'issues' => $issues,
        'checks' => [
            'kioskEnabled' => $kioskEnabled,
            'chromiumRunning' => $chromiumRunning,
            'autostartExists' => $autostartExists,
        ]
    ], $healthy ? 'Kiosk healthy' : 'Kiosk has issues');
}

/**
 * PUT /api/kiosk/enable
 * Enable or disable kiosk mode
 */
function handlePutEnable($input) {
    if (!isset($input['enabled']) || !is_bool($input['enabled'])) {
        jsonResponse(false, null, 'Missing or invalid field: enabled (must be boolean)', 400);
        return;
    }

    $enabled = $input['enabled'];
    $value = $enabled ? '1' : '0';

    $result = updateFeatureFlag('ENABLE_KIOSK', $value);

    if (!$result['success']) {
        jsonResponse(false, null, $result['message'], 500);
        return;
    }

    logMessage("Kiosk mode " . ($enabled ? 'enabled' : 'disabled') . " via API", 'INFO');

    // Re-apply kiosk configuration
    $applyResult = applyKioskConfig();

    jsonResponse(true, [
        'enabled' => $enabled,
        'applied' => $applyResult['success'],
    ], 'Kiosk mode ' . ($enabled ? 'enabled' : 'disabled'));
}

/**
 * PUT /api/kiosk/mode
 * Switch between Chromium Player and VLC fallback
 */
function handlePutMode($input) {
    if (!isset($input['useChromiumPlayer']) || !is_bool($input['useChromiumPlayer'])) {
        jsonResponse(false, null, 'Missing or invalid field: useChromiumPlayer (must be boolean)', 400);
        return;
    }

    $useChromiumPlayer = $input['useChromiumPlayer'];
    $value = $useChromiumPlayer ? '1' : '0';

    $result = updateFeatureFlag('USE_CHROMIUM_PLAYER', $value);

    if (!$result['success']) {
        jsonResponse(false, null, $result['message'], 500);
        return;
    }

    logMessage("Chromium Player mode " . ($useChromiumPlayer ? 'enabled' : 'disabled') . " via API", 'INFO');

    // Re-apply kiosk configuration
    $applyResult = applyKioskConfig();

    jsonResponse(true, [
        'useChromiumPlayer' => $useChromiumPlayer,
        'mode' => $useChromiumPlayer ? 'chromium-player' : 'vlc-fallback',
        'applied' => $applyResult['success'],
    ], 'Player mode switched to ' . ($useChromiumPlayer ? 'Chromium HTML5' : 'VLC fallback'));
}

/**
 * POST /api/kiosk/restart-session
 * Restarts the full display-manager session (relaunches labwc + Chromium), not just Chromium.
 * 'display-manager' is the generic systemd alias -> works whether the DM is lightdm (this
 * Pi4/Trixie image) or greetd. Requires sudoers:
 *   www-data ALL=(root) NOPASSWD: /usr/bin/systemctl restart display-manager
 */
function handleRestartSession() {
    logMessage("Kiosk session restart (display-manager) requested via API", 'INFO');

    exec('sudo /usr/bin/systemctl restart display-manager 2>&1', $output, $returnCode);

    if ($returnCode !== 0) {
        jsonResponse(false, [
            'return_code' => $returnCode,
            'output' => implode("\n", $output),
        ], 'Failed to restart the session', 500);
        return;
    }

    jsonResponse(true, [
        'return_code' => $returnCode,
        'note' => 'display-manager restarted: the whole session (labwc + Chromium) is reloading',
    ], 'Session redémarrée');
}

/**
 * Read the screen power schedule from JSON, returning defaults if absent/invalid.
 */
function readScreenSchedule() {
    $defaults = [
        'enabled'  => false,
        'on_time'  => '07:00',
        'off_time' => '22:00',
        'days'     => [0, 1, 2, 3, 4, 5, 6],
    ];

    if (!file_exists(KIOSK_SCREEN_SCHEDULE_FILE)) {
        return $defaults;
    }

    $raw = file_get_contents(KIOSK_SCREEN_SCHEDULE_FILE);
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        return $defaults;
    }

    return array_merge($defaults, $data);
}

/**
 * Validate a "HH:MM" 24-hour time string.
 */
function isValidHhMm($value) {
    return is_string($value) && preg_match('/^([01][0-9]|2[0-3]):[0-5][0-9]$/', $value) === 1;
}

/**
 * GET /api/kiosk/screen
 * Returns the live screen power state plus the saved schedule.
 */
function handleGetScreen() {
    $schedule = readScreenSchedule();

    // Probe the live screen state via the helper (runs in pi's Wayland session, sets the
    // Wayland env itself; ignores the virtual NOOP output). The helper path is whitelisted
    // in sudoers (env/wlr-randr directly are not), so we go through it.
    $state = 'unknown';
    if (file_exists(KIOSK_SCREEN_POWER_SCRIPT)) {
        exec('sudo -u pi ' . escapeshellarg(KIOSK_SCREEN_POWER_SCRIPT) . ' state 2>/dev/null', $probe, $probeCode);
        $out = trim(implode("\n", $probe));
        if ($probeCode === 0 && ($out === 'on' || $out === 'off')) {
            $state = $out;
        }
    }

    jsonResponse(true, [
        'state'    => $state,
        'schedule' => $schedule,
    ], 'Screen power state and schedule');
}

/**
 * PUT /api/kiosk/screen
 * Saves the screen power schedule to JSON.
 * Body: {enabled:bool, on_time:"HH:MM", off_time:"HH:MM", days:[0-6]}
 */
function handlePutScreen($input) {
    if (!is_array($input)) {
        jsonResponse(false, null, 'Invalid or missing JSON body', 400);
        return;
    }

    if (!isset($input['enabled']) || !is_bool($input['enabled'])) {
        jsonResponse(false, null, 'Missing or invalid field: enabled (must be boolean)', 400);
        return;
    }

    if (!isset($input['on_time']) || !isValidHhMm($input['on_time'])) {
        jsonResponse(false, null, 'Invalid on_time (expected HH:MM)', 400);
        return;
    }

    if (!isset($input['off_time']) || !isValidHhMm($input['off_time'])) {
        jsonResponse(false, null, 'Invalid off_time (expected HH:MM)', 400);
        return;
    }

    if (!isset($input['days']) || !is_array($input['days'])) {
        jsonResponse(false, null, 'Invalid days (expected array of 0-6)', 400);
        return;
    }

    // Sanitize days: keep unique integers in [0,6], sorted.
    $days = [];
    foreach ($input['days'] as $d) {
        if (is_int($d) && $d >= 0 && $d <= 6) {
            $days[$d] = $d;
        } elseif (is_string($d) && ctype_digit($d) && (int)$d >= 0 && (int)$d <= 6) {
            $days[(int)$d] = (int)$d;
        }
    }
    $days = array_values($days);
    sort($days);

    $schedule = [
        'enabled'  => $input['enabled'],
        'on_time'  => $input['on_time'],
        'off_time' => $input['off_time'],
        'days'     => $days,
    ];

    // Ensure config directory exists
    if (!is_dir(KIOSK_CONFIG_DIR)) {
        mkdir(KIOSK_CONFIG_DIR, 0755, true);
    }

    $json = json_encode($schedule, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    if (file_put_contents(KIOSK_SCREEN_SCHEDULE_FILE, $json) === false) {
        jsonResponse(false, null, 'Failed to write screen schedule', 500);
        return;
    }

    logMessage('Screen power schedule updated via API', 'INFO');

    jsonResponse(true, ['schedule' => $schedule], 'Planning écran enregistré');
}

/**
 * POST /api/kiosk/screen/on  or  /api/kiosk/screen/off
 * Applies the screen power state immediately via screen-power.sh (run as pi).
 * Requires sudoers: www-data ALL=(pi) NOPASSWD: /opt/pisignage/scripts/screen-power.sh
 */
function handleScreenPower($action) {
    if (!in_array($action, ['on', 'off'], true)) {
        jsonResponse(false, null, 'Invalid screen action', 400);
        return;
    }

    if (!file_exists(KIOSK_SCREEN_POWER_SCRIPT)) {
        jsonResponse(false, null, 'screen-power.sh script not found at ' . KIOSK_SCREEN_POWER_SCRIPT, 500);
        return;
    }

    logMessage("Screen power '$action' requested via API", 'INFO');

    $cmd = 'sudo -u pi ' . escapeshellarg(KIOSK_SCREEN_POWER_SCRIPT) . ' ' . escapeshellarg($action) . ' 2>&1';
    exec($cmd, $output, $returnCode);

    if ($returnCode !== 0) {
        jsonResponse(false, [
            'return_code' => $returnCode,
            'output' => implode("\n", $output),
        ], "Failed to turn screen $action", 500);
        return;
    }

    jsonResponse(true, [
        'state' => $action,
        'output' => implode("\n", $output),
    ], $action === 'on' ? 'Écran allumé' : 'Écran éteint');
}
