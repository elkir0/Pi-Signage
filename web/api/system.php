<?php
/**
 * PiSignage v0.8.0 - System API
 * Provides system information and controls
 */

require_once "/opt/pisignage/web/config.php";
require_once "config.php";

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

// Gestion spécifique pour l'action stats via GET
if ($method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'stats') {
    $systemInfo = getSystemStats();
    jsonResponse(true, $systemInfo);
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
            $result = executeCommand('sudo systemctl restart pisignage-player');
            if ($result['success']) {
                logMessage("Player restarted via system API");
                jsonResponse(true, null, 'Player restarted successfully');
            } else {
                jsonResponse(false, $result, 'Failed to restart player');
            }
            break;

        case 'restart-vlc':
            // Legacy support - redirect to restart-player
            $result = executeCommand('sudo systemctl restart pisignage-player');
            if ($result['success']) {
                logMessage("Player (legacy VLC command) restarted via system API");
                jsonResponse(true, null, 'Player restarted successfully');
            } else {
                jsonResponse(false, $result, 'Failed to restart player');
            }
            break;

        case 'switch-player':
            $result = executeCommand('/opt/pisignage/scripts/player-manager.sh switch');
            if ($result['success']) {
                logMessage("Player switched via system API");
                jsonResponse(true, ['output' => $result['output']], 'Player switched successfully');
            } else {
                jsonResponse(false, $result, 'Failed to switch player');
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
            $result = executeCommand('sudo systemctl restart nginx');
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
    $lines = $input['lines'] ?? 50;
    $logFile = LOGS_PATH . '/pisignage.log';

    if (!file_exists($logFile)) {
        jsonResponse(true, [], 'No logs available');
    }

    $result = executeCommand("tail -n $lines $logFile");

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
    // PiSignage v0.8.9+ uses VLC exclusively
    return 'vlc';
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
    $result = executeCommand('/opt/pisignage/scripts/player-manager.sh info');
    if ($result['success']) {
        return [
            'info' => $result['output'],
            'current_player' => getCurrentPlayer()
        ];
    }

    return [
        'info' => ['No player information available'],
        'current_player' => getCurrentPlayer()
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
            'default' => 'mpv',
            'current' => 'mpv',
            'available' => ['mpv', 'vlc']
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

// Function getMediaFiles() is already defined in config.php
?>