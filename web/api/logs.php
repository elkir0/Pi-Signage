<?php
/**
 * PiSignage v0.8.0 - Logs API
 * Provides access to system logs
 */

require_once '../config.php';

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGetLogs();
        break;

    case 'POST':
        handleLogAction($input);
        break;

    default:
        jsonResponse(false, null, 'Method not allowed');
}

function handleGetLogs() {
    $action = $_GET['action'] ?? 'recent';
    $source = $_GET['source'] ?? 'pisignage';
    $lines = intval($_GET['lines'] ?? 100);

    switch ($action) {
        case 'recent':
            $logs = getRecentLogs($source, $lines);
            jsonResponse(true, ['logs' => $logs], 'Recent logs retrieved');
            break;

        case 'search':
            if (!isset($_GET['query'])) {
                jsonResponse(false, null, 'Search query required');
            }
            $query = $_GET['query'];
            $logs = searchLogs($source, $query, $lines);
            jsonResponse(true, ['logs' => $logs, 'query' => $query], 'Search results');
            break;

        case 'sources':
            $sources = getLogSources();
            jsonResponse(true, $sources, 'Available log sources');
            break;

        case 'stats':
            $stats = getLogStats();
            jsonResponse(true, $stats, 'Log statistics');
            break;

        default:
            jsonResponse(false, null, 'Unknown action: ' . $action);
    }
}

function handleLogAction($input) {
    if (!isset($input['action'])) {
        jsonResponse(false, null, 'Action parameter required');
    }

    $action = $input['action'];

    switch ($action) {
        case 'clear':
            $source = $input['source'] ?? 'pisignage';
            $result = clearLogs($source);
            if ($result) {
                logMessage("Logs cleared for source: $source");
                jsonResponse(true, null, "Logs cleared for $source");
            } else {
                jsonResponse(false, null, "Failed to clear logs for $source");
            }
            break;

        case 'download':
            $source = $input['source'] ?? 'pisignage';
            downloadLogs($source);
            break;

        case 'rotate':
            $result = rotateLogs();
            if ($result) {
                logMessage("Log rotation completed");
                jsonResponse(true, null, 'Log rotation completed');
            } else {
                jsonResponse(false, null, 'Log rotation failed');
            }
            break;

        default:
            jsonResponse(false, null, 'Unknown action: ' . $action);
    }
}

function getRecentLogs($source, $lines) {
    $logFile = getLogFile($source);

    if (!file_exists($logFile)) {
        return [];
    }

    // Use tail to get recent lines efficiently
    $result = executeCommand("tail -n $lines " . escapeshellarg($logFile));

    if (!$result['success']) {
        return [];
    }

    $logs = [];
    foreach ($result['output'] as $line) {
        $parsed = parseLogLine($line);
        if ($parsed) {
            $logs[] = $parsed;
        }
    }

    return array_reverse($logs); // Show newest first
}

function searchLogs($source, $query, $lines) {
    $logFile = getLogFile($source);

    if (!file_exists($logFile)) {
        return [];
    }

    // Use grep to search
    $escapedQuery = escapeshellarg($query);
    $result = executeCommand("grep -i $escapedQuery " . escapeshellarg($logFile) . " | tail -n $lines");

    if (!$result['success']) {
        return [];
    }

    $logs = [];
    foreach ($result['output'] as $line) {
        $parsed = parseLogLine($line);
        if ($parsed) {
            $logs[] = $parsed;
        }
    }

    return array_reverse($logs);
}

function getLogSources() {
    $sources = [];

    // PiSignage log
    if (file_exists(LOGS_PATH . '/pisignage.log')) {
        $sources['pisignage'] = [
            'name' => 'PiSignage Application',
            'file' => 'pisignage.log',
            'size' => filesize(LOGS_PATH . '/pisignage.log'),
            'modified' => filemtime(LOGS_PATH . '/pisignage.log')
        ];
    }

    // System logs
    $systemLogs = [
        'syslog' => '/var/log/syslog',
        'nginx_error' => '/var/log/nginx/error.log',
        'nginx_access' => '/var/log/nginx/access.log',
        'php_error' => '/var/log/php8.2-fpm.log',
        'kern' => '/var/log/kern.log'
    ];

    foreach ($systemLogs as $key => $path) {
        if (file_exists($path) && is_readable($path)) {
            $sources[$key] = [
                'name' => ucfirst(str_replace('_', ' ', $key)),
                'file' => basename($path),
                'size' => filesize($path),
                'modified' => filemtime($path)
            ];
        }
    }

    // YouTube download logs
    $youtubeLogsDir = LOGS_PATH;
    $youtubeLogs = glob($youtubeLogsDir . '/youtube_*.log');
    foreach ($youtubeLogs as $logFile) {
        $key = basename($logFile, '.log');
        $sources[$key] = [
            'name' => 'YouTube Download - ' . substr($key, 8),
            'file' => basename($logFile),
            'size' => filesize($logFile),
            'modified' => filemtime($logFile)
        ];
    }

    return $sources;
}

function getLogStats() {
    $stats = [
        'total_size' => 0,
        'file_count' => 0,
        'oldest_entry' => null,
        'newest_entry' => null,
        'error_count' => 0,
        'warning_count' => 0
    ];

    $sources = getLogSources();

    foreach ($sources as $source => $info) {
        $stats['total_size'] += $info['size'];
        $stats['file_count']++;

        // Get first and last entries for main logs
        if (in_array($source, ['pisignage', 'syslog'])) {
            $logFile = getLogFile($source);

            // First line
            $firstLine = executeCommand("head -n 1 " . escapeshellarg($logFile));
            if ($firstLine['success'] && !empty($firstLine['output'])) {
                $parsed = parseLogLine($firstLine['output'][0]);
                if ($parsed && ($stats['oldest_entry'] === null || $parsed['timestamp'] < $stats['oldest_entry'])) {
                    $stats['oldest_entry'] = $parsed['timestamp'];
                }
            }

            // Last line
            $lastLine = executeCommand("tail -n 1 " . escapeshellarg($logFile));
            if ($lastLine['success'] && !empty($lastLine['output'])) {
                $parsed = parseLogLine($lastLine['output'][0]);
                if ($parsed && ($stats['newest_entry'] === null || $parsed['timestamp'] > $stats['newest_entry'])) {
                    $stats['newest_entry'] = $parsed['timestamp'];
                }
            }

            // Count errors and warnings
            $errorCount = executeCommand("grep -c -i 'error' " . escapeshellarg($logFile) . " 2>/dev/null");
            if ($errorCount['success'] && !empty($errorCount['output'])) {
                $stats['error_count'] += intval($errorCount['output'][0]);
            }

            $warningCount = executeCommand("grep -c -i 'warning\\|warn' " . escapeshellarg($logFile) . " 2>/dev/null");
            if ($warningCount['success'] && !empty($warningCount['output'])) {
                $stats['warning_count'] += intval($warningCount['output'][0]);
            }
        }
    }

    $stats['total_size_formatted'] = formatBytes($stats['total_size']);

    return $stats;
}

function getLogFile($source) {
    switch ($source) {
        case 'pisignage':
            return LOGS_PATH . '/pisignage.log';
        case 'syslog':
            return '/var/log/syslog';
        case 'nginx_error':
            return '/var/log/nginx/error.log';
        case 'nginx_access':
            return '/var/log/nginx/access.log';
        case 'php_error':
            return '/var/log/php8.2-fpm.log';
        case 'kern':
            return '/var/log/kern.log';
        default:
            // Check if it's a YouTube log
            if (strpos($source, 'youtube_') === 0) {
                return LOGS_PATH . '/' . $source . '.log';
            }
            return LOGS_PATH . '/pisignage.log';
    }
}

function parseLogLine($line) {
    $line = trim($line);
    if (empty($line)) {
        return null;
    }

    // Try to parse PiSignage format: [2024-09-23 12:34:56] [LEVEL] Message
    if (preg_match('/^\[([^\]]+)\]\s*\[([^\]]+)\]\s*(.+)$/', $line, $matches)) {
        return [
            'timestamp' => $matches[1],
            'level' => $matches[2],
            'message' => $matches[3],
            'raw' => $line
        ];
    }

    // Try to parse syslog format: Sep 23 12:34:56 hostname process[pid]: message
    if (preg_match('/^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+([^:]+):\s*(.+)$/', $line, $matches)) {
        return [
            'timestamp' => $matches[1],
            'level' => 'INFO',
            'process' => $matches[3],
            'message' => $matches[4],
            'raw' => $line
        ];
    }

    // Fallback: treat as generic message
    return [
        'timestamp' => date('Y-m-d H:i:s'),
        'level' => 'INFO',
        'message' => $line,
        'raw' => $line
    ];
}

function clearLogs($source) {
    $logFile = getLogFile($source);

    if ($source === 'pisignage') {
        // For our own log, just truncate it
        return file_put_contents($logFile, '') !== false;
    } else {
        // For system logs, we need sudo
        $result = executeCommand("sudo truncate -s 0 " . escapeshellarg($logFile));
        return $result['success'];
    }
}

function downloadLogs($source) {
    $logFile = getLogFile($source);

    if (!file_exists($logFile)) {
        jsonResponse(false, null, 'Log file not found');
    }

    $filename = basename($logFile);
    $timestamp = date('Y-m-d_H-i-s');
    $downloadName = "{$source}_{$timestamp}.log";

    header('Content-Type: text/plain');
    header('Content-Disposition: attachment; filename="' . $downloadName . '"');
    header('Content-Length: ' . filesize($logFile));

    readfile($logFile);
    exit;
}

function rotateLogs() {
    $success = true;

    // Rotate PiSignage log
    $logFile = LOGS_PATH . '/pisignage.log';
    if (file_exists($logFile) && filesize($logFile) > 10 * 1024 * 1024) { // 10MB
        $rotatedFile = $logFile . '.' . date('Y-m-d');
        if (rename($logFile, $rotatedFile)) {
            file_put_contents($logFile, '');
            logMessage("Log rotated: $rotatedFile");
        } else {
            $success = false;
        }
    }

    // Clean old YouTube logs (older than 7 days)
    $youtubeLogsDir = LOGS_PATH;
    $oldLogs = glob($youtubeLogsDir . '/youtube_*.log');
    $cutoff = time() - (7 * 24 * 60 * 60);

    foreach ($oldLogs as $logFile) {
        if (filemtime($logFile) < $cutoff) {
            if (unlink($logFile)) {
                logMessage("Old YouTube log cleaned: " . basename($logFile));
            }
        }
    }

    return $success;
}

?>