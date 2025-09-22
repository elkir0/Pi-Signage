<?php
/**
 * System API for PiSignage v0.8.0
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST');
header('Access-Control-Allow-Headers: Content-Type');

// Get system information
function getSystemInfo() {
    $info = [];

    // CPU usage
    $load = sys_getloadavg();
    $info['cpu'] = round($load[0] * 100 / 4, 1); // Assuming 4 cores

    // Memory usage
    $free = shell_exec('free -m');
    if ($free) {
        preg_match('/Mem:\s+(\d+)\s+(\d+)/', $free, $matches);
        if (isset($matches[1]) && isset($matches[2])) {
            $total = $matches[1];
            $used = $matches[2];
            $info['ram'] = round(($used / $total) * 100, 1);
            $info['ram_used'] = $used;
            $info['ram_total'] = $total;
        }
    }

    // CPU Temperature (Raspberry Pi specific)
    $temp_file = '/sys/class/thermal/thermal_zone0/temp';
    if (file_exists($temp_file)) {
        $temp = file_get_contents($temp_file);
        $info['temperature'] = round($temp / 1000, 1);
    } else {
        $info['temperature'] = 0;
    }

    // Uptime
    $uptime = shell_exec('uptime -p');
    $info['uptime'] = $uptime ? trim($uptime) : 'N/A';

    // Disk usage
    $df = disk_free_space('/');
    $dt = disk_total_space('/');
    if ($df && $dt) {
        $info['disk_free'] = round($df / 1024 / 1024 / 1024, 2);
        $info['disk_total'] = round($dt / 1024 / 1024 / 1024, 2);
        $info['disk_used'] = round(($dt - $df) / 1024 / 1024 / 1024, 2);
        $info['disk_percent'] = round((($dt - $df) / $dt) * 100, 1);
    }

    // Hostname
    $info['hostname'] = gethostname();

    // IP Address
    $info['ip'] = $_SERVER['SERVER_ADDR'] ?? '127.0.0.1';

    // Version
    $info['version'] = '0.8.0';

    return $info;
}

// Handle request
$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Return system information
    echo json_encode(getSystemInfo());

} elseif ($method === 'POST') {
    // Handle system actions
    $input = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';

    $response = ['success' => false, 'message' => ''];

    switch ($action) {
        case 'restart':
            // Restart VLC player
            exec('sudo systemctl restart vlc 2>&1', $output, $return);
            $response['success'] = ($return === 0);
            $response['message'] = $response['success'] ? 'Player restarted' : 'Failed to restart';
            break;

        case 'clear-cache':
            // Clear cache
            exec('sudo rm -rf /var/cache/nginx/* 2>&1', $output, $return);
            $response['success'] = true;
            $response['message'] = 'Cache cleared';
            break;

        case 'screenshot':
            // Take screenshot
            $screenshot_path = '/opt/pisignage/media/screenshot-' . date('YmdHis') . '.png';
            exec("sudo scrot '$screenshot_path' 2>&1", $output, $return);
            $response['success'] = ($return === 0);
            $response['message'] = $response['success'] ? 'Screenshot saved' : 'Failed to take screenshot';
            $response['path'] = $response['success'] ? $screenshot_path : null;
            break;

        case 'reboot':
            // Reboot system (requires sudo)
            exec('sudo shutdown -r now 2>&1', $output, $return);
            $response['success'] = true;
            $response['message'] = 'System rebooting...';
            break;

        case 'shutdown':
            // Shutdown system (requires sudo)
            exec('sudo shutdown -h now 2>&1', $output, $return);
            $response['success'] = true;
            $response['message'] = 'System shutting down...';
            break;

        case 'update':
            // Update system
            $response['success'] = false;
            $response['message'] = 'Update functionality not implemented in v0.8.0';
            break;

        default:
            $response['message'] = 'Unknown action';
    }

    echo json_encode($response);

} else {
    // Method not allowed
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
}
?>