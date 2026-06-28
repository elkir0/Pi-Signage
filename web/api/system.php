<?php
/**
 * PiSignage v0.11.0 - System API
 * Provides system information and controls
 */

require_once __DIR__ . '/_guard.php';
require_once "/opt/pisignage/web/config.php";

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

/**
 * Human-readable byte formatter.
 * Defined here (guarded) because system.php only includes config.php, which does
 * NOT provide formatFileSize() — it lives in api/media.php. getMemoryInfo()/
 * getDiskInfo() below reference it, so its absence caused a fatal error (HTTP 500)
 * on GET /api/system.php?action=status and ?action=stats. See "api_bugs_found".
 */
if (!function_exists('formatFileSize')) {
    function formatFileSize($bytes) {
        $bytes = (float) $bytes;
        if ($bytes <= 0) {
            return '0 B';
        }
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $i = (int) floor(log($bytes, 1024));
        $i = max(0, min($i, count($units) - 1));
        return round($bytes / pow(1024, $i), ($i >= 3) ? 1 : 0) . ' ' . $units[$i];
    }
}

/**
 * Local IP fallback (defined in api/config.php, which is not included here).
 * Guarded to avoid redeclaration if config.php is ever pulled in.
 */
if (!function_exists('getLocalIP')) {
    function getLocalIP() {
        $result = executeCommand("hostname -I | awk '{print $1}'");
        if ($result['success'] && !empty($result['output'])) {
            $ip = trim($result['output'][0]);
            if ($ip !== '') {
                return $ip;
            }
        }
        return $_SERVER['SERVER_ADDR'] ?? '127.0.0.1';
    }
}

// Gestion spécifique pour l'action stats via GET
if ($method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'stats') {
    $systemInfo = getSystemStats();
    jsonResponse(true, $systemInfo);
    exit;
}

// Gestion spécifique pour l'action status via GET (info système complète)
if ($method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'status') {
    handleGetSystemInfo();
    exit;
}

// Gestion spécifique pour get_player
if ($method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'get_player') {
    $playerInfo = [
        'current' => getCurrentPlayer(),
        'status' => getPlayerStatus(),
        'config' => getPlayerConfiguration()
    ];
    jsonResponse(true, $playerInfo);
    exit;
}

// Volume Control (v0.12.5) — PipeWire (wpctl) prioritaire, fallback ALSA (amixer).
// Sur Pi 4 HDMI, la carte IEC958 n'expose PAS de simple control "Master" ALSA
// (mixer hardware absent en digital). PipeWire/WirePlumber gère le volume côté
// userland via wpctl — c'est la seule méthode fiable sur Trixie Desktop.
if ($method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'get_volume') {
    jsonResponse(true, ['volume' => volumeGet(), 'muted' => muteIs()]);
    exit;
}

if ($method === 'POST' && isset($input['action']) && $input['action'] === 'set_volume') {
    $volume = intval($input['volume'] ?? 100);
    $volume = max(0, min(100, $volume)); // Clamp 0-100
    volumeSet($volume);
    jsonResponse(true, ['volume' => $volume, 'muted' => muteIs(), 'message' => "Volume réglé à {$volume}%"]);
    exit;
}

if ($method === 'POST' && isset($input['action']) && $input['action'] === 'toggle_mute') {
    $muted = muteToggle();
    jsonResponse(true, ['muted' => $muted, 'message' => $muted ? 'Son coupé' : 'Son rétabli']);
    exit;
}

// Choix de la sortie audio (HDMI vs jack 3.5mm) via audio-output.sh (sudo-granté).
// Lit la sortie effective depuis l'état sauvegardé dans /run/audio-output
// (audio-output.sh ne fournit pas de getter direct côté raspi-config).
if ($method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'get_output') {
    $cur = @file_get_contents('/run/audio-output');
    $cur = ($cur === false) ? '' : trim($cur);
    if (!in_array($cur, ['hdmi', 'jack'], true)) { $cur = 'jack'; } // défaut bcm2835
    jsonResponse(true, ['output' => $cur]);
    exit;
}

if ($method === 'POST' && isset($input['action']) && $input['action'] === 'set_output') {
    $out = ($input['output'] ?? '') === 'hdmi' ? 'hdmi' : 'jack';
    $r = executeCommand(['sudo', '/opt/pisignage/scripts/audio-output.sh', $out]);
    if (!$r['success']) {
        jsonResponse(false, null, 'Échec bascule sortie audio: ' . implode(' ', $r['output']), 500);
        exit;
    }
    // Persister le choix pour get_output (audio-output.sh ne le fait pas).
    @file_put_contents('/run/audio-output', $out);
    // Forcer WirePlumber à relire la config ALSA (sinon il garde l'ancien routage).
    executeCommand(['sudo', '--user', '#'.getmyuid(), 'systemctl', '--user', 'restart', 'wireplumber']);
    jsonResponse(true, ['output' => $out, 'message' => "Sortie audio : {$out}"]);
    exit;
}

switch ($method) {
    case 'GET':
        handleGetSystemInfo();
        break;

    case 'POST':
        handleSystemAction($input);
        break;

    default:
        jsonResponse(false, null, 'Method not allowed');
}

function handleGetSystemInfo() {
    $systemInfo = getSystemStats();

    // Add additional info
    $systemInfo['hostname'] = gethostname();
    $systemInfo['ip'] = $_SERVER['SERVER_ADDR'] ?? getLocalIP();
    $systemInfo['version'] = PISIGNAGE_VERSION;
    $systemInfo['php_version'] = PHP_VERSION;
    $systemInfo['platform'] = PHP_OS;

    // Player status (unified VLC/MPV)
    $playerStatus = getPlayerStatus();
    $systemInfo['player_status'] = $playerStatus;

    // Current player info
    $currentPlayer = getCurrentPlayer();
    $systemInfo['current_player'] = $currentPlayer;

    // Media files count (compatible avec l'interface)
    $mediaFiles = getMediaFiles();
    $systemInfo['media_files'] = count($mediaFiles);
    $systemInfo['media_count'] = count($mediaFiles); // Alias pour compatibilité front-end

    // Network info
    $networkInfo = getNetworkInfo();
    $systemInfo['network'] = $networkInfo;

    // Playlist count
    $playlists = glob(PLAYLISTS_PATH . '/*.json');
    $systemInfo['playlist_count'] = count($playlists);

    // Last screenshot
    $screenshots = glob(SCREENSHOTS_PATH . '/screenshot-*.png');
    if (!empty($screenshots)) {
        usort($screenshots, function($a, $b) {
            return filemtime($b) - filemtime($a);
        });
        $systemInfo['last_screenshot'] = date('Y-m-d H:i:s', filemtime($screenshots[0]));
    } else {
        $systemInfo['last_screenshot'] = 'Never';
    }

    jsonResponse(true, $systemInfo);
}

function handleSystemAction($input) {
    if (!isset($input['action'])) {
        jsonResponse(false, null, 'Action parameter required');
    }

    $action = $input['action'];

    switch ($action) {
        case 'restart-player':
        case 'restart-vlc': // alias hérité (VLC retiré) — redémarre désormais la session kiosk
            // Le lecteur réel est le kiosk Chromium (labwc). Redémarrer la session
            // (display-manager, alias générique lightdm/greetd) relance labwc + Chromium.
            // Sudoers: www-data ALL=(root) NOPASSWD: /usr/bin/systemctl restart display-manager
            $result = executeCommand(['sudo', '/usr/bin/systemctl', 'restart', 'display-manager']);
            if ($result['success']) {
                logMessage("Kiosk player (display-manager) restarted via system API");
                jsonResponse(true, null, 'Lecteur kiosk redémarré (session relancée)');
            } else {
                jsonResponse(false, $result, 'Échec du redémarrage du lecteur kiosk');
            }
            break;

        case 'clear-cache':
            $commands = [
                'sudo rm -rf /var/cache/nginx/*',
                'sudo rm -rf /tmp/nginx-cache/*',
                'sudo systemctl reload nginx'
            ];

            $allSuccess = true;
            foreach ($commands as $cmd) {
                $result = executeCommand($cmd);
                if (!$result['success']) {
                    $allSuccess = false;
                }
            }

            if ($allSuccess) {
                logMessage("Cache cleared via system API");
                jsonResponse(true, null, 'Cache cleared successfully');
            } else {
                jsonResponse(false, null, 'Failed to clear cache completely');
            }
            break;

        case 'reboot':
            logMessage("System reboot initiated via API");
            executeCommand('sudo shutdown -r +1', true);
            jsonResponse(true, null, 'System will reboot in 1 minute');
            break;

        case 'shutdown':
            logMessage("System shutdown initiated via API");
            executeCommand('sudo shutdown -h +1', true);
            jsonResponse(true, null, 'System will shutdown in 1 minute');
            break;

        case 'restart-nginx':
            $result = executeCommand(['sudo', '/usr/bin/systemctl', 'restart', 'nginx']);
            if ($result['success']) {
                logMessage("Nginx restarted via system API");
                jsonResponse(true, null, 'Nginx restarted successfully');
            } else {
                jsonResponse(false, $result, 'Failed to restart Nginx');
            }
            break;

        case 'config':
            handleConfigUpdate($input);
            break;

        case 'logs':
            handleGetLogs($input);
            break;

        case 'processes':
            handleGetProcesses();
            break;

        default:
            jsonResponse(false, null, "Unknown action: $action");
    }
}

function handleConfigUpdate($input) {
    if (!isset($input['type'])) {
        jsonResponse(false, null, 'Configuration type required');
    }

    $type = $input['type'];

    switch ($type) {
        case 'display':
            updateDisplayConfig($input);
            break;

        case 'audio':
            updateAudioConfig($input);
            break;

        case 'network':
            updateNetworkConfig($input);
            break;

        default:
            jsonResponse(false, null, "Unknown configuration type: $type");
    }
}




function handleGetLogs($input) {
    $lines = max(1, min(2000, (int)($input['lines'] ?? 50)));
    $logFile = LOGS_PATH . '/pisignage.log';

    if (!file_exists($logFile)) {
        jsonResponse(true, [], 'No logs available');
    }

    $result = executeCommand(['/usr/bin/tail', '-n', (string)$lines, $logFile]);

    if ($result['success']) {
        jsonResponse(true, $result['output']);
    } else {
        jsonResponse(false, null, 'Failed to read logs');
    }
}

function handleGetProcesses() {
    $result = executeCommand('ps aux | grep -E "(vlc|mpv|nginx|php)" | grep -v grep');

    if ($result['success']) {
        $processes = [];
        foreach ($result['output'] as $line) {
            if (trim($line)) {
                $processes[] = $line;
            }
        }
        jsonResponse(true, $processes);
    } else {
        jsonResponse(false, null, 'Failed to get process list');
    }
}



function getSystemStats() {
    $stats = [];

    // CPU usage
    $loadAvg = sys_getloadavg();
    $stats['cpu'] = [
        'load_1min' => round($loadAvg[0], 2),
        'load_5min' => round($loadAvg[1], 2),
        'load_15min' => round($loadAvg[2], 2),
        'usage' => getCpuUsage()
    ];

    // Memory usage
    $memInfo = getMemoryInfo();
    $stats['memory'] = $memInfo;

    // Disk usage
    $diskInfo = getDiskInfo();
    $stats['disk'] = $diskInfo;

    // Temperature (for Raspberry Pi)
    $temp = getCpuTemperature();
    if ($temp !== null) {
        $stats['temperature'] = $temp;
    }

    // Uptime
    $uptime = getUptime();
    $stats['uptime'] = $uptime;

    return $stats;
}

function getCpuUsage() {
    $result = executeCommand("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d '%' -f1");
    if ($result['success'] && !empty($result['output'])) {
        return floatval($result['output'][0]);
    }
    return 0;
}

function getMemoryInfo() {
    $memInfo = [];
    $result = executeCommand("free -b");

    if ($result['success'] && count($result['output']) > 1) {
        $lines = $result['output'];
        $memLine = preg_split('/\s+/', $lines[1]);

        if (count($memLine) >= 3) {
            $total = intval($memLine[1]);
            $used = intval($memLine[2]);
            $free = isset($memLine[3]) ? intval($memLine[3]) : ($total - $used);

            $memInfo = [
                'total' => $total,
                'used' => $used,
                'free' => $free,
                'percent' => $total > 0 ? round(($used / $total) * 100, 2) : 0,
                'total_formatted' => formatFileSize($total),
                'used_formatted' => formatFileSize($used),
                'free_formatted' => formatFileSize($free)
            ];
        }
    }

    return $memInfo;
}

function getDiskInfo() {
    $diskInfo = [];
    $result = executeCommand("df -B1 /");

    if ($result['success'] && count($result['output']) > 1) {
        $lines = $result['output'];
        $diskLine = preg_split('/\s+/', $lines[1]);

        if (count($diskLine) >= 4) {
            $total = intval($diskLine[1]);
            $used = intval($diskLine[2]);
            $available = intval($diskLine[3]);

            $diskInfo = [
                'total' => $total,
                'used' => $used,
                'available' => $available,
                'percent' => $total > 0 ? round(($used / $total) * 100, 2) : 0,
                'total_formatted' => formatFileSize($total),
                'used_formatted' => formatFileSize($used),
                'available_formatted' => formatFileSize($available)
            ];
        }
    }

    return $diskInfo;
}

function getCpuTemperature() {
    // Try Raspberry Pi temperature file
    $tempFile = '/sys/class/thermal/thermal_zone0/temp';
    if (file_exists($tempFile)) {
        $temp = intval(file_get_contents($tempFile)) / 1000;
        return round($temp, 1);
    }

    // Try vcgencmd for Raspberry Pi
    $result = executeCommand("vcgencmd measure_temp 2>/dev/null");
    if ($result['success'] && !empty($result['output'])) {
        if (preg_match('/temp=([\d.]+)/', $result['output'][0], $matches)) {
            return floatval($matches[1]);
        }
    }

    return null;
}

function getUptime() {
    $result = executeCommand("uptime -p");
    if ($result['success'] && !empty($result['output'])) {
        return trim($result['output'][0]);
    }

    // Fallback to basic uptime
    $uptimeSeconds = intval(file_get_contents('/proc/uptime'));
    $days = floor($uptimeSeconds / 86400);
    $hours = floor(($uptimeSeconds % 86400) / 3600);
    $minutes = floor(($uptimeSeconds % 3600) / 60);

    return "up {$days} days, {$hours} hours, {$minutes} minutes";
}

// ========== VLC PLAYER FUNCTIONS ==========

function getCurrentPlayer() {
    // Return the active player based on the Chromium kiosk feature flag.
    return isChromiumPlayerEnabled() ? 'chromium' : 'vlc';
}

/**
 * Check if Chromium Player mode is enabled (mirrors kiosk.php logic).
 */
function isChromiumPlayerEnabled() {
    $featureFlagsFile = '/opt/pisignage/config/feature_flags';
    if (!file_exists($featureFlagsFile)) {
        return true; // Default: enabled
    }

    $content = file_get_contents($featureFlagsFile);
    return strpos($content, 'USE_CHROMIUM_PLAYER=0') === false;
}

function getPlayerStatus() {
    // Check if VLC is running
    $vlcRunning = shell_exec('pgrep -f "vlc.*http-host" | wc -l') > 0;

    if ($vlcRunning) {
        return [
            'status' => 'running',
            'running' => true,
            'player' => 'vlc'
        ];
    }

    return [
        'status' => 'stopped',
        'running' => false,
        'player' => 'vlc'
    ];
}

function getPlayerInfo() {
    $currentPlayer = getCurrentPlayer();

    // Report the systemd state of the VLC fallback service.
    $result = executeCommand('systemctl is-active pisignage-vlc.service');
    $vlcState = ($result['success'] && !empty($result['output']))
        ? trim($result['output'][0])
        : 'unknown';

    return [
        'info' => [
            'current_player' => $currentPlayer,
            'chromium_enabled' => isChromiumPlayerEnabled(),
            'vlc_service' => $vlcState
        ],
        'current_player' => $currentPlayer
    ];
}

function getPlayerConfiguration() {
    $configFile = '/opt/pisignage/config/player-config.json';
    if (file_exists($configFile)) {
        $config = json_decode(file_get_contents($configFile), true);
        if ($config) {
            return $config;
        }
    }

    // Return default configuration
    return [
        'player' => [
            'default' => 'vlc',
            'current' => 'vlc',
            'available' => ['vlc', 'chromium']
        ]
    ];
}

function getNetworkInfo() {
    // Récupérer l'IP locale
    $result = executeCommand("hostname -I | awk '{print $1}'");
    if ($result['success'] && !empty($result['output'])) {
        return trim($result['output'][0]);
    }

    // Alternative si hostname -I échoue
    $ip = $_SERVER['SERVER_ADDR'] ?? '127.0.0.1';
    return $ip;
}

/* ------------------------------------------------------------------ */
/* Volume / Mute helpers (PipeWire wpctl prioritaire, ALSA fallback)   */
/* ------------------------------------------------------------------ */
//
// Sur Pi 4 HDMI, la carte IEC958 n'a pas de contrôle "Master" ALSA. WirePlumber
// (PipeWire) gère le volume du sink par défaut via wpctl — méthode fiable sur
// Trixie Desktop. Fallback amixer si wpctl absent (Lite sans PipeWire).
//
// Exécute via wrapper sudo-granté /opt/pisignage/scripts/wpctl-default-sink.sh
// qui SETENV XDG_RUNTIME_DIR + DBUS_SESSION_BUS_ADDRESS (sinon wpctl démarre un
// PipeWire vide et rend des erreurs RKit sans données volume).

define('WPCTL_BIN', '/usr/bin/wpctl');
define('WPCTL_WRAPPER', '/opt/pisignage/scripts/wpctl-default-sink.sh');
define('AMIXER_BIN', '/usr/bin/amixer');

/** true si wpctl + wrapper dispo ET qu'on a une session user pipewire active. */
function wpctlAvailable(): bool {
    if (!file_exists(WPCTL_BIN)) return false;
    if (!file_exists(WPCTL_WRAPPER)) return false;
    $uid = posix_getpwnam('pi')['uid'] ?? 1000;
    return is_dir("/run/user/{$uid}");
}

/** Retourne le volume courant du sink par défaut, en % entier (0..100). */
function volumeGet(): int {
    if (wpctlAvailable()) {
        $r = executeCommand(['sudo', '-n', '-u', 'pi', WPCTL_WRAPPER, 'get-volume', '@DEFAULT_AUDIO_SINK@']);
        $line = implode("\n", $r['output']);
        // Sortie typique : "Volume: 0.40" ou "Volume: 0.40 [MUTED]"
        if (preg_match('/Volume:\s*([0-9]*\.?[0-9]+)/', $line, $m)) {
            $v = (float)$m[1];
            return (int)round($v * 100);
        }
    }
    // Fallback ALSA : Master ou PCM (selon la carte).
    foreach (['Master', 'PCM', 'Speaker', 'Headphone'] as $ctrl) {
        $r = executeCommand([AMIXER_BIN, 'sget', $ctrl]);
        $line = implode("\n", $r['output']);
        if (preg_match('/(\d+)%/', $line, $m)) { return (int)$m[1]; }
    }
    return 0;
}

/** Positionne le volume du sink par défaut. $percent ∈ [0..100]. */
function volumeSet(int $percent): void {
    $percent = max(0, min(100, $percent));
    $linear = round($percent / 100, 3); // 0..1
    if (wpctlAvailable()) {
        executeCommand(['sudo', '-n', '-u', 'pi', WPCTL_WRAPPER, 'set-volume', '@DEFAULT_AUDIO_SINK@', (string)$linear]);
        return;
    }
    foreach (['Master', 'PCM', 'Speaker', 'Headphone'] as $ctrl) {
        $r = executeCommand([AMIXER_BIN, 'sset', $ctrl, $percent . '%']);
        if ($r['success']) return;
    }
}

/** true si le sink par défaut est muté. */
function muteIs(): bool {
    if (wpctlAvailable()) {
        $r = executeCommand(['sudo', '-n', '-u', 'pi', WPCTL_WRAPPER, 'get-volume', '@DEFAULT_AUDIO_SINK@']);
        $line = implode("\n", $r['output']);
        return (stripos($line, 'MUTED') !== false);
    }
    foreach (['Master', 'PCM', 'Speaker', 'Headphone'] as $ctrl) {
        $r = executeCommand([AMIXER_BIN, 'sget', $ctrl]);
        $line = implode("\n", $r['output']);
        if (preg_match('/\[off\]/', $line)) return true;
        if (preg_match('/\[on\]/', $line)) return false;
    }
    return false;
}

/** Bascule mute. Retourne le nouvel état (true = muté). */
function muteToggle(): bool {
    if (wpctlAvailable()) {
        executeCommand(['sudo', '-n', '-u', 'pi', WPCTL_WRAPPER, 'set-mute', '@DEFAULT_AUDIO_SINK@', 'toggle']);
        return muteIs();
    }
    foreach (['Master', 'PCM', 'Speaker', 'Headphone'] as $ctrl) {
        $r = executeCommand([AMIXER_BIN, 'sset', $ctrl, 'toggle']);
        if ($r['success']) {
            $s = executeCommand([AMIXER_BIN, 'sget', $ctrl]);
            return (bool)preg_match('/\[off\]/', implode("\n", $s['output']));
        }
    }
    return false;
}

// Function getMediaFiles() is already defined in config.php
?>
