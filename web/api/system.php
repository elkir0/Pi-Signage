<?php
/**
 * PiSignage v0.8.0 - System API
 * Provides system information and controls
 */

require_once '../config.php';

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

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

    // Media files count
    $mediaFiles = getMediaFiles();
    $systemInfo['media_files'] = count($mediaFiles);

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

function updateDisplayConfig($input) {
    $resolution = $input['resolution'] ?? null;
    $rotation = $input['rotation'] ?? null;

    $commands = [];

    if ($resolution) {
        // Update resolution in config.txt
        $commands[] = "sudo sed -i 's/^hdmi_mode=.*/hdmi_mode=82/' /boot/config.txt";
        $commands[] = "sudo sed -i 's/^hdmi_group=.*/hdmi_group=1/' /boot/config.txt";
    }

    if ($rotation !== null) {
        // Update display rotation
        $commands[] = "sudo sed -i 's/^display_rotate=.*/display_rotate=$rotation/' /boot/config.txt";
    }

    $success = true;
    foreach ($commands as $cmd) {
        $result = executeCommand($cmd);
        if (!$result['success']) {
            $success = false;
        }
    }

    if ($success) {
        logMessage("Display configuration updated");
        jsonResponse(true, null, 'Display configuration updated. Reboot required.');
    } else {
        jsonResponse(false, null, 'Failed to update display configuration');
    }
}

function updateAudioConfig($input) {
    $output = $input['output'] ?? null;
    $volume = $input['volume'] ?? null;

    $commands = [];

    if ($output) {
        switch ($output) {
            case 'hdmi':
                $commands[] = 'sudo amixer cset numid=3 2';
                break;
            case 'jack':
                $commands[] = 'sudo amixer cset numid=3 1';
                break;
            case 'auto':
                $commands[] = 'sudo amixer cset numid=3 0';
                break;
        }
    }

    if ($volume !== null) {
        $commands[] = "sudo amixer set PCM {$volume}%";
    }

    $success = true;
    foreach ($commands as $cmd) {
        $result = executeCommand($cmd);
        if (!$result['success']) {
            $success = false;
        }
    }

    if ($success) {
        logMessage("Audio configuration updated");
        jsonResponse(true, null, 'Audio configuration updated');
    } else {
        jsonResponse(false, null, 'Failed to update audio configuration');
    }
}

function updateNetworkConfig($input) {
    $hostname = $input['hostname'] ?? null;
    $timezone = $input['timezone'] ?? null;

    $commands = [];

    if ($hostname) {
        $sanitizedHostname = preg_replace('/[^a-zA-Z0-9-]/', '', $hostname);
        $commands[] = "sudo hostnamectl set-hostname $sanitizedHostname";
        $commands[] = "sudo systemctl restart avahi-daemon";
    }

    if ($timezone) {
        $commands[] = "sudo timedatectl set-timezone $timezone";
    }

    $success = true;
    foreach ($commands as $cmd) {
        $result = executeCommand($cmd);
        if (!$result['success']) {
            $success = false;
        }
    }

    if ($success) {
        logMessage("Network configuration updated");
        jsonResponse(true, null, 'Network configuration updated');
    } else {
        jsonResponse(false, null, 'Failed to update network configuration');
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

function getLocalIP() {
    $socket = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
    socket_connect($socket, "8.8.8.8", 53);
    socket_getsockname($socket, $localAddr);
    socket_close($socket);
    return $localAddr;
}

// ========== DUAL PLAYER SUPPORT FUNCTIONS ==========

function getCurrentPlayer() {
    $result = executeCommand('/opt/pisignage/scripts/unified-player-control.sh current');
    if ($result['success'] && !empty($result['output'])) {
        return trim($result['output'][0]);
    }
    return 'mpv'; // default
}

function getPlayerStatus() {
    $result = executeCommand('/opt/pisignage/scripts/unified-player-control.sh status');
    if ($result['success'] && !empty($result['output'])) {
        $status = trim($result['output'][0]);
        return [
            'status' => $status,
            'running' => strpos(strtolower($status), 'running') !== false,
            'player' => getCurrentPlayer()
        ];
    }

    return [
        'status' => 'offline',
        'running' => false,
        'player' => getCurrentPlayer()
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
?>