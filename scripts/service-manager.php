#!/usr/bin/env php
<?php
/**
 * PiSignage Service Manager
 * Monitors system health and manages playlist execution
 */

require_once '/opt/pisignage/web/config.php';

// Service configuration
$config = [
    'check_interval' => 60,  // seconds
    'log_file' => LOGS_DIR . '/service.log',
    'pid_file' => '/var/run/pisignage.pid'
];

// Write PID file
file_put_contents($config['pid_file'], getmypid());

// Signal handlers
pcntl_signal(SIGTERM, 'signalHandler');
pcntl_signal(SIGINT, 'signalHandler');
pcntl_signal(SIGHUP, 'signalHandler');

function signalHandler($signal) {
    global $config;

    switch ($signal) {
        case SIGTERM:
        case SIGINT:
            logService("Service stopping...");
            unlink($config['pid_file']);
            exit(0);
            break;
        case SIGHUP:
            logService("Reloading configuration...");
            break;
    }
}

function logService($message) {
    global $config;
    $timestamp = date('Y-m-d H:i:s');
    $entry = "[$timestamp] $message\n";
    file_put_contents($config['log_file'], $entry, FILE_APPEND | LOCK_EX);
}

function checkSystemHealth() {
    $health = [
        'cpu' => getCpuUsage(),
        'memory' => getMemoryUsage(),
        'disk' => getDiskUsage(),
        'network' => checkNetworkStatus(),
        'media_count' => count(getMediaFiles())
    ];

    return $health;
}

function getCpuUsage() {
    $load = sys_getloadavg();
    return round($load[0] * 100 / 4, 2);  // Assuming 4 cores
}

function getMemoryUsage() {
    $free = shell_exec('free');
    $free = (string)trim($free);
    $free_arr = explode("\n", $free);
    $mem = explode(" ", preg_replace('/\s+/', ' ', $free_arr[1]));

    $total = $mem[1] ?? 0;
    $used = $mem[2] ?? 0;

    if ($total > 0) {
        return round(($used / $total) * 100, 2);
    }
    return 0;
}

function getDiskUsage() {
    $df = disk_free_space('/opt/pisignage');
    $dt = disk_total_space('/opt/pisignage');

    if ($dt > 0) {
        $used = $dt - $df;
        return round(($used / $dt) * 100, 2);
    }
    return 0;
}

function checkNetworkStatus() {
    $result = @fsockopen('8.8.8.8', 53, $errno, $errstr, 1);
    if ($result) {
        fclose($result);
        return true;
    }
    return false;
}

function checkActivePlaylist() {
    $playlistDir = PLAYLISTS_PATH;

    if (is_dir($playlistDir)) {
        $files = glob($playlistDir . '/*.json');

        foreach ($files as $file) {
            $data = json_decode(file_get_contents($file), true);

            if (isset($data['is_active']) && $data['is_active']) {
                return $data;
            }
        }
    }

    return null;
}

function updateHealthStats() {
    $health = checkSystemHealth();
    $statsFile = BASE_DIR . '/data/health.json';

    file_put_contents($statsFile, json_encode($health, JSON_PRETTY_PRINT));

    return $health;
}

// Main service loop
logService("PiSignage Service Started");
logService("Monitoring directory: " . MEDIA_DIR);

while (true) {
    pcntl_signal_dispatch();

    // Update system health
    $health = updateHealthStats();

    // Check for active playlist
    $activePlaylist = checkActivePlaylist();

    if ($activePlaylist) {
        logService("Active playlist: " . $activePlaylist['name']);
    }

    // Log health status
    if ($health['cpu'] > 80) {
        logService("WARNING: High CPU usage: " . $health['cpu'] . "%");
    }

    if ($health['memory'] > 85) {
        logService("WARNING: High memory usage: " . $health['memory'] . "%");
    }

    if ($health['disk'] > 90) {
        logService("WARNING: Low disk space: " . $health['disk'] . "% used");
    }

    if (!$health['network']) {
        logService("WARNING: Network connectivity issue");
    }

    // Sleep until next check
    sleep($config['check_interval']);
}