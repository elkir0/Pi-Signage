<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// CPU Usage
$cpuUsage = sys_getloadavg()[0] * 100 / 4; // 4 cores

// Memory
$memInfo = file_get_contents('/proc/meminfo');
preg_match('/MemTotal:\s+(\d+)/', $memInfo, $totalMem);
preg_match('/MemAvailable:\s+(\d+)/', $memInfo, $availMem);
$memUsage = round((1 - $availMem[1] / $totalMem[1]) * 100, 1);

// Temperature
$temp = exec('vcgencmd measure_temp');
preg_match('/temp=([\d.]+)/', $temp, $tempMatch);

// Disk
$diskTotal = disk_total_space('/');
$diskFree = disk_free_space('/');
$diskUsage = round((1 - $diskFree / $diskTotal) * 100, 1);

// VLC Status
$vlcStatus = trim(exec('/opt/pisignage/scripts/vlc-control.sh status'));

echo json_encode([
    'cpu' => round($cpuUsage, 1),
    'memory' => $memUsage,
    'temperature' => floatval($tempMatch[1] ?? 0),
    'disk' => $diskUsage,
    'vlc_status' => $vlcStatus,
    'uptime' => trim(file_get_contents('/proc/uptime'))
]);
