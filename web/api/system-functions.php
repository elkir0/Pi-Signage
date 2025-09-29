<?php
/**
 * System helper functions for PiSignage
 * Extracted from system.php to be reusable
 */

function getCpuUsage() {
    $load = sys_getloadavg();
    return round($load[0] * 25, 1); // Simple approximation
}

function getMemoryUsage() {
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

function getRaspberryPiTemperature() {
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
?>
