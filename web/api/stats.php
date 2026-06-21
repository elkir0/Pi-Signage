<?php
/**
 * PiSignage Stats API - Direct stats endpoint
 */

require_once __DIR__ . '/_guard.php';

header('Content-Type: application/json');

function getCpuUsage() {
    $load = sys_getloadavg();
    return round($load[0] * 25, 1);
}

function getMemoryInfo() {
    $free = shell_exec('free -b');
    $free = (string)trim($free);
    $free_arr = explode("\n", $free);
    $mem = explode(" ", preg_replace('/\s+/', ' ', $free_arr[1]));

    $total = intval($mem[1] ?? 1);
    $used = intval($mem[2] ?? 0);

    return [
        'total' => $total,
        'used' => $used,
        'percent' => round(($used / $total) * 100, 2)
    ];
}

function getDiskInfo() {
    $df = shell_exec('df -B1 /');
    $df = explode("\n", $df);
    if (isset($df[1])) {
        $parts = preg_split('/\s+/', $df[1]);
        $total = intval($parts[1] ?? 0);
        $used = intval($parts[2] ?? 0);
        $percent = intval(str_replace('%', '', $parts[4] ?? '0'));

        return [
            'total' => $total,
            'used' => $used,
            'percent' => $percent
        ];
    }
    return ['percent' => 0];
}

function getCpuTemperature() {
    if (file_exists('/sys/class/thermal/thermal_zone0/temp')) {
        $temp = intval(file_get_contents('/sys/class/thermal/thermal_zone0/temp'));
        return round($temp / 1000, 1);
    }
    return null;
}

function getUptime() {
    $uptime = shell_exec('uptime -p');
    return trim($uptime);
}

/**
 * Read Raspberry Pi under-voltage / throttling state via vcgencmd.
 *
 * Parses the hex bitfield returned by `vcgencmd get_throttled`:
 *   bit 0  (0x1)     -> under-voltage currently detected
 *   bit 16 (0x10000) -> under-voltage has occurred since boot
 *
 * @return array|null Null when vcgencmd is unavailable (non-Pi hardware) or
 *                    the output cannot be parsed; otherwise an associative
 *                    array {raw, under_voltage_now, under_voltage_occurred}.
 */
function getThrottledState() {
    $out = @shell_exec('vcgencmd get_throttled 2>/dev/null');
    if ($out === null || trim($out) === '') {
        return null;
    }
    // Expected format: "throttled=0x50005"
    if (!preg_match('/throttled=0x([0-9a-fA-F]+)/', $out, $m)) {
        return null;
    }
    $value = hexdec($m[1]);

    return [
        'raw' => '0x' . $m[1],
        'under_voltage_now' => (bool)($value & 0x1),
        'under_voltage_occurred' => (bool)($value & 0x10000),
    ];
}

// Get stats
$stats = [
    'cpu' => [
        'usage' => getCpuUsage(),
        'load_1min' => round(sys_getloadavg()[0], 2)
    ],
    'memory' => getMemoryInfo(),
    'disk' => getDiskInfo(),
    'temperature' => getCpuTemperature(),
    'uptime' => getUptime(),
    'throttled' => getThrottledState()
];

// Return JSON response
echo json_encode([
    'success' => true,
    'data' => $stats,
    'timestamp' => date('Y-m-d H:i:s')
]);
?>