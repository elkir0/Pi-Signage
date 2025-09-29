<?php
require_once "/opt/pisignage/web/config.php";

// Force la fonction pour les stats
function getSystemStatsReal() {
    $stats = [];
    
    // CPU
    $loadAvg = sys_getloadavg();
    $stats['cpu'] = [
        'load_1min' => round($loadAvg[0], 2),
        'usage' => round($loadAvg[0] * 25, 1) // Approximation
    ];
    
    // Memory
    $free = shell_exec('free -b');
    $free = (string)trim($free);
    $free_arr = explode("\n", $free);
    $mem = explode(" ", preg_replace('/\s+/', ' ', $free_arr[1]));
    $total = intval($mem[1] ?? 1);
    $used = intval($mem[2] ?? 0);
    
    $stats['memory'] = [
        'total' => $total,
        'used' => $used,
        'percent' => round(($used / $total) * 100, 2)
    ];
    
    // Disk
    $df = shell_exec('df /');
    $df_arr = explode("\n", $df);
    if (count($df_arr) >= 2) {
        $disk_info = preg_split('/\s+/', $df_arr[1]);
        if (count($disk_info) >= 5) {
            $stats['disk'] = [
                'percent' => intval(str_replace('%', '', $disk_info[4]))
            ];
        }
    }
    
    // Temperature
    if (file_exists('/sys/class/thermal/thermal_zone0/temp')) {
        $temp = intval(file_get_contents('/sys/class/thermal/thermal_zone0/temp'));
        $stats['temperature'] = round($temp / 1000, 1);
    }
    
    return $stats;
}

// Test direct
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['action']) && $_GET['action'] === 'stats') {
    header('Content-Type: application/json');
    $stats = getSystemStatsReal();
    echo json_encode(['success' => true, 'data' => $stats]);
}
?>
