<?php
/**
 * PiSignage v0.8.0 - Configuration API
 * Handles system configuration updates
 */

require_once __DIR__ . '/_guard.php';
require_once '../config.php';
require_once __DIR__ . '/wifi-lib.php';

const WIFI_STATE_JSON = '/opt/pisignage/config/wifi-networks.json';
const WIFI_APPLY = '/opt/pisignage/scripts/wifi-apply.sh';

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGetConfig();
        break;

    case 'POST':
        handleUpdateConfig($input);
        break;

    default:
        jsonResponse(false, null, 'Method not allowed');
}

function handleGetConfig() {
    $action = $_GET['action'] ?? 'all';

    switch ($action) {
        case 'display':
            $config = getDisplayConfig();
            jsonResponse(true, $config, 'Display configuration retrieved');
            break;

        case 'network':
            $config = getNetworkConfig();
            jsonResponse(true, $config, 'Network configuration retrieved');
            break;

        case 'wifi':
            jsonResponse(true, getWifiConfig(), 'WiFi configuration retrieved');
            break;

        case 'audio':
            $config = getAudioConfig();
            jsonResponse(true, $config, 'Audio configuration retrieved');
            break;

        case 'all':
        default:
            $config = [
                'display' => getDisplayConfig(),
                'network' => getNetworkConfig(),
                'audio' => getAudioConfig(),
                'system' => getSystemConfig()
            ];
            jsonResponse(true, $config, 'All configurations retrieved');
            break;
    }
}

function handleUpdateConfig($input) {
    if (!isset($input['type'])) {
        jsonResponse(false, null, 'Configuration type required');
    }

    $type = $input['type'];

    switch ($type) {
        case 'display':
            updateDisplayConfig($input);
            break;

        case 'network':
            updateNetworkConfig($input);
            break;

        case 'wifi':
            updateWifiConfig($input);
            break;

        case 'audio':
            updateAudioConfig($input);
            break;

        case 'system':
            updateSystemConfig($input);
            break;

        default:
            jsonResponse(false, null, "Unknown configuration type: $type");
    }
}

function getDisplayConfig() {
    $config = [
        'resolution' => '1920x1080',
        'rotation' => '0',
        'overscan' => false,
        'hdmi_mode' => 'auto'
    ];

    // Read from system files if available
    if (file_exists('/boot/config.txt')) {
        $bootConfig = file_get_contents('/boot/config.txt');

        if (preg_match('/hdmi_mode=(\d+)/', $bootConfig, $matches)) {
            $config['hdmi_mode'] = $matches[1];
        }

        if (preg_match('/display_rotate=(\d+)/', $bootConfig, $matches)) {
            $config['rotation'] = $matches[1];
        }
    }

    return $config;
}

function getNetworkConfig() {
    $config = [
        'hostname' => gethostname(),
        'ip_address' => $_SERVER['SERVER_ADDR'] ?? getLocalIP(),
        'wifi_status' => 'unknown',
        'ssid' => 'unknown'
    ];

    // Get WiFi info if available
    $wifiInfo = executeCommand('iwgetid -r 2>/dev/null');
    if ($wifiInfo['success'] && !empty($wifiInfo['output'])) {
        $config['ssid'] = trim($wifiInfo['output'][0]);
        $config['wifi_status'] = 'connected';
    }

    return $config;
}

function getAudioConfig() {
    $config = [
        'output' => 'auto',
        'volume' => 50
    ];

    // Get current audio output
    $audioOutput = executeCommand('amixer cget numid=3 2>/dev/null');
    if ($audioOutput['success']) {
        foreach ($audioOutput['output'] as $line) {
            if (preg_match('/values=(\d+)/', $line, $matches)) {
                switch ($matches[1]) {
                    case '0':
                        $config['output'] = 'auto';
                        break;
                    case '1':
                        $config['output'] = 'jack';
                        break;
                    case '2':
                        $config['output'] = 'hdmi';
                        break;
                }
            }
        }
    }

    // Get volume
    $volumeInfo = executeCommand('amixer get PCM 2>/dev/null');
    if ($volumeInfo['success']) {
        foreach ($volumeInfo['output'] as $line) {
            if (preg_match('/\[(\d+)%\]/', $line, $matches)) {
                $config['volume'] = intval($matches[1]);
                break;
            }
        }
    }

    return $config;
}

function getSystemConfig() {
    return [
        'timezone' => date_default_timezone_get(),
        'locale' => 'fr_FR.UTF-8',
        'version' => PISIGNAGE_VERSION,
        'auto_start' => true
    ];
}

function updateDisplayConfig($input) {
    $commands = [];
    $changes = [];

    if (isset($input['resolution'])) {
        $resolution = $input['resolution'];
        $changes[] = "Resolution: $resolution";

        // Map resolutions to HDMI modes
        switch ($resolution) {
            case '1920x1080':
                $commands[] = "sudo sed -i 's/^hdmi_mode=.*/hdmi_mode=82/' /boot/config.txt";
                $commands[] = "sudo sed -i 's/^hdmi_group=.*/hdmi_group=2/' /boot/config.txt";
                break;
            case '1280x720':
                $commands[] = "sudo sed -i 's/^hdmi_mode=.*/hdmi_mode=85/' /boot/config.txt";
                $commands[] = "sudo sed -i 's/^hdmi_group=.*/hdmi_group=2/' /boot/config.txt";
                break;
            case '1024x768':
                $commands[] = "sudo sed -i 's/^hdmi_mode=.*/hdmi_mode=16/' /boot/config.txt";
                $commands[] = "sudo sed -i 's/^hdmi_group=.*/hdmi_group=2/' /boot/config.txt";
                break;
        }
    }

    if (isset($input['rotation'])) {
        $rotation = (int)$input['rotation'];
        if (!in_array($rotation, [0, 90, 180, 270], true)) {
            jsonResponse(false, null, 'Rotation invalide (0, 90, 180, 270)');
        }
        $changes[] = "Rotation: {$rotation}°";
        $commands[] = "sudo sed -i 's/^display_rotate=.*/display_rotate=$rotation/' /boot/config.txt";

        // Add or update the line if it doesn't exist
        $commands[] = "grep -q '^display_rotate=' /boot/config.txt || echo 'display_rotate=$rotation' | sudo tee -a /boot/config.txt";
    }

    if (empty($commands)) {
        jsonResponse(false, null, 'No display configuration changes specified');
    }

    // Execute commands
    $success = true;
    foreach ($commands as $cmd) {
        $result = executeCommand($cmd);
        if (!$result['success']) {
            $success = false;
        }
    }

    if ($success) {
        logMessage("Display configuration updated: " . implode(', ', $changes));
        jsonResponse(true, $changes, 'Display configuration updated successfully. Reboot required to take effect.');
    } else {
        jsonResponse(false, null, 'Failed to update display configuration');
    }
}

function updateNetworkConfig($input) {
    $commands = [];
    $changes = [];

    // NB : la configuration WiFi (multi-réseaux + fallback) passe désormais par
    // updateWifiConfig() (type=wifi) via NetworkManager. L'ancien chemin ssid/password
    // unique (écriture wpa_supplicant.conf) a été retiré : NM gère wlan0, ce fichier était mort.

    if (isset($input['hostname'])) {
        $hostname = (string)$input['hostname'];
        // Allow-list stricte (RFC 1123, pas de tiret en tête -> pas d'injection d'option).
        if (!preg_match('/^[a-z0-9][a-z0-9-]{0,62}$/i', $hostname)) {
            jsonResponse(false, null, "Nom d'hôte invalide");
        }
        $changes[] = "Hostname: $hostname";
        $commands[] = ['sudo', '/usr/bin/hostnamectl', 'set-hostname', $hostname];
        $commands[] = ['sudo', '/usr/bin/systemctl', 'restart', 'avahi-daemon'];
    }

    if (empty($commands)) {
        jsonResponse(false, null, 'No network configuration changes specified');
    }

    // Execute commands
    $success = true;
    foreach ($commands as $cmd) {
        $result = executeCommand($cmd);
        if (!$result['success']) {
            $success = false;
        }
    }

    if ($success) {
        logMessage("Network configuration updated: " . implode(', ', $changes));
        jsonResponse(true, $changes, 'Network configuration updated successfully');
    } else {
        jsonResponse(false, null, 'Failed to update network configuration');
    }
}

function updateAudioConfig($input) {
    $commands = [];
    $changes = [];

    if (isset($input['output'])) {
        $output = $input['output'];
        $changes[] = "Audio output: $output";

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
            default:
                jsonResponse(false, null, 'Invalid audio output: ' . $output);
        }
    }

    if (isset($input['volume'])) {
        $volume = intval($input['volume']);
        if ($volume < 0 || $volume > 100) {
            jsonResponse(false, null, 'Volume must be between 0 and 100');
        }
        $changes[] = "Volume: {$volume}%";
        $commands[] = "sudo amixer set PCM {$volume}%";
    }

    if (empty($commands)) {
        jsonResponse(false, null, 'No audio configuration changes specified');
    }

    // Execute commands
    $success = true;
    foreach ($commands as $cmd) {
        $result = executeCommand($cmd);
        if (!$result['success']) {
            $success = false;
        }
    }

    if ($success) {
        logMessage("Audio configuration updated: " . implode(', ', $changes));
        jsonResponse(true, $changes, 'Audio configuration updated successfully');
    } else {
        jsonResponse(false, null, 'Failed to update audio configuration');
    }
}

function updateSystemConfig($input) {
    $commands = [];
    $changes = [];

    if (isset($input['timezone'])) {
        $timezone = (string)$input['timezone'];
        // Allow-list strict : identifiant de fuseau connu de PHP (sinon injection shell as www-data).
        if (!in_array($timezone, timezone_identifiers_list(), true)) {
            jsonResponse(false, null, 'Fuseau horaire invalide');
        }
        $changes[] = "Timezone: $timezone";
        $commands[] = ['sudo', '/usr/bin/timedatectl', 'set-timezone', $timezone];
    }

    if (empty($commands)) {
        jsonResponse(false, null, 'No system configuration changes specified');
    }

    // Execute commands
    $success = true;
    foreach ($commands as $cmd) {
        $result = executeCommand($cmd);
        if (!$result['success']) {
            $success = false;
        }
    }

    if ($success) {
        logMessage("System configuration updated: " . implode(', ', $changes));
        jsonResponse(true, $changes, 'System configuration updated successfully');
    } else {
        jsonResponse(false, null, 'Failed to update system configuration');
    }
}

function readWifiState() {
    if (!is_readable(WIFI_STATE_JSON)) return [];
    // JSON_INVALID_UTF8_SUBSTITUTE : un octet douteux ne doit pas annuler tout le décodage
    // (sinon un seul SSID exotique viderait la liste — défense en profondeur).
    $j = json_decode((string)@file_get_contents(WIFI_STATE_JSON), true, 512, JSON_INVALID_UTF8_SUBSTITUTE);
    return (is_array($j) && isset($j['networks']) && is_array($j['networks'])) ? $j['networks'] : [];
}

function getWifiConfig() {
    $networks = readWifiState();
    // SSID actuellement connecté (NetworkManager).
    $connected = '';
    $r = executeCommand(['/usr/bin/nmcli', '-t', '-f', 'active,ssid', 'dev', 'wifi']);
    if ($r['success']) {
        foreach ($r['output'] as $line) {
            // nmcli -t échappe ':' (et '\') dans le SSID -> déséchapper pour matcher le SSID stocké.
            if (strpos($line, 'yes:') === 0) { $connected = str_replace(['\\:', '\\\\'], [':', '\\'], substr($line, 4)); break; }
        }
    }
    return ['networks' => $networks, 'connected_ssid' => $connected];
}

function updateWifiConfig($input) {
    $networks = $input['networks'] ?? null;
    if (!is_array($networks)) jsonResponse(false, null, 'networks requis');

    $built = wifiValidateAndBuild($networks, readWifiState());
    if (!$built['ok']) jsonResponse(false, null, $built['error']);

    $payload = implode("\n", $built['lines']) . "\n";

    // Invoquer le helper root via sudo, payload sur STDIN (le PSK ne touche jamais argv/disque).
    $descriptors = [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $proc = @proc_open(['sudo', WIFI_APPLY, 'apply'], $descriptors, $pipes, null, null);
    if (!is_resource($proc)) jsonResponse(false, null, 'Échec lancement wifi-apply');
    fwrite($pipes[0], $payload); fclose($pipes[0]);
    $out = stream_get_contents($pipes[1]); fclose($pipes[1]);
    $err = stream_get_contents($pipes[2]); fclose($pipes[2]);
    $rc = proc_close($proc);

    if ($rc === 3) {
        // Config écrite mais connexion au réseau ciblé non confirmée (mauvais mot de passe / hors
        // portée). Le lien existant n'a pas été coupé -> avertissement, pas échec.
        logMessage("WiFi appliqué mais non connecté (rc=3): " . trim($err));
        jsonResponse(true, getWifiConfig(), "WiFi enregistré, mais la connexion au réseau configuré n'est pas confirmée (vérifiez le SSID, le mot de passe ou la portée).");
    }
    if ($rc !== 0) {
        logMessage("WiFi apply échec rc=$rc: " . trim($err));
        jsonResponse(false, null, 'Échec application WiFi : ' . trim($err));
    }
    logMessage("WiFi mis à jour (" . count($built['lines']) . " réseau(x))");
    jsonResponse(true, getWifiConfig(), 'Configuration WiFi appliquée');
}

function getLocalIP() {
    $socket = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
    if ($socket === false) {
        return '127.0.0.1';
    }

    $result = socket_connect($socket, "8.8.8.8", 53);
    if ($result === false) {
        socket_close($socket);
        return '127.0.0.1';
    }

    socket_getsockname($socket, $localAddr);
    socket_close($socket);

    return $localAddr ?: '127.0.0.1';
}
?>