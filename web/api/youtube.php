<?php
/**
 * PiSignage v0.8.0 - YouTube Download API
 * Téléchargement de vidéos YouTube avec yt-dlp
 * Compatible PHP 7.4 pour Raspberry Pi Bullseye
 */

require_once '../config.php';
require_once 'media.php';

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGetDownloads();
        break;

    case 'POST':
        handleDownloadVideo($input);
        break;

    case 'DELETE':
        handleCancelDownload($input);
        break;

    default:
        jsonResponse(false, null, 'Method not allowed');
}

function handleGetDownloads() {
    $action = $_GET['action'] ?? 'queue';

    switch ($action) {
        case 'queue':
            $queue = getDownloadQueue();
            jsonResponse(true, $queue, 'Download queue retrieved');
            break;

        case 'status':
            if (!isset($_GET['id'])) {
                jsonResponse(false, null, 'Download ID required');
            }
            $status = getDownloadStatus($_GET['id']);
            jsonResponse(true, $status, 'Download status retrieved');
            break;

        case 'info':
            if (!isset($_GET['url'])) {
                jsonResponse(false, null, 'URL required');
            }
            $info = getVideoInfo($_GET['url']);
            if ($info) {
                jsonResponse(true, $info, 'Video info retrieved');
            } else {
                jsonResponse(false, null, 'Failed to get video info');
            }
            break;

        case 'check_ytdlp':
            $ytdlpInfo = checkYtDlpInstallation();
            jsonResponse(true, $ytdlpInfo, 'yt-dlp installation status');
            break;

        default:
            jsonResponse(false, null, 'Unknown action: ' . $action);
    }
}

function handleDownloadVideo($input) {
    if (!isset($input['url']) || empty($input['url'])) {
        jsonResponse(false, null, 'URL is required');
    }

    $url = trim($input['url']);
    $quality = $input['quality'] ?? 'best';
    $format = $input['format'] ?? 'mp4';
    $audioOnly = $input['audio_only'] ?? false;

    // Validate URL
    if (!isValidYouTubeUrl($url)) {
        jsonResponse(false, null, 'Invalid YouTube URL');
    }

    // Check if yt-dlp is available
    $ytdlpCheck = checkYtDlpInstallation();
    if (!$ytdlpCheck['available']) {
        jsonResponse(false, null, 'yt-dlp is not installed or not working properly');
    }

    // Generate download ID
    $downloadId = generateDownloadId();

    // Prepare download parameters
    $downloadParams = [
        'id' => $downloadId,
        'url' => $url,
        'quality' => $quality,
        'format' => $format,
        'audio_only' => $audioOnly,
        'status' => 'queued',
        'started_at' => date('Y-m-d H:i:s'),
        'progress' => 0
    ];

    // Save to queue
    saveDownloadToQueue($downloadParams);

    // Start download in background
    $success = startDownload($downloadId, $url, $quality, $format, $audioOnly);

    if ($success) {
        logMessage("YouTube download started: $url (ID: $downloadId)");
        jsonResponse(true, [
            'download_id' => $downloadId,
            'status' => 'started',
            'estimated_time' => 'Unknown'
        ], 'Download started successfully');
    } else {
        jsonResponse(false, null, 'Failed to start download');
    }
}

function handleCancelDownload($input) {
    if (!isset($input['id'])) {
        jsonResponse(false, null, 'Download ID required');
    }

    $downloadId = $input['id'];
    $success = cancelDownload($downloadId);

    if ($success) {
        logMessage("YouTube download cancelled: $downloadId");
        jsonResponse(true, null, 'Download cancelled successfully');
    } else {
        jsonResponse(false, null, 'Failed to cancel download or download not found');
    }
}

function checkYtDlpInstallation() {
    $ytdlpPath = '/usr/local/bin/yt-dlp';
    $alternative = '/usr/bin/yt-dlp';

    // Check primary location
    if (file_exists($ytdlpPath) && is_executable($ytdlpPath)) {
        $version = getYtDlpVersion($ytdlpPath);
        return [
            'available' => true,
            'path' => $ytdlpPath,
            'version' => $version
        ];
    }

    // Check alternative location
    if (file_exists($alternative) && is_executable($alternative)) {
        $version = getYtDlpVersion($alternative);
        return [
            'available' => true,
            'path' => $alternative,
            'version' => $version
        ];
    }

    // Check if it's in PATH
    $result = executeCommand('which yt-dlp 2>/dev/null');
    if ($result['success'] && !empty($result['output'])) {
        $path = trim($result['output'][0]);
        $version = getYtDlpVersion($path);
        return [
            'available' => true,
            'path' => $path,
            'version' => $version
        ];
    }

    return [
        'available' => false,
        'path' => null,
        'version' => null,
        'suggestion' => 'Install yt-dlp: pip3 install yt-dlp'
    ];
}

function getYtDlpVersion($path) {
    $result = executeCommand("$path --version 2>/dev/null");
    if ($result['success'] && !empty($result['output'])) {
        return trim($result['output'][0]);
    }
    return 'Unknown';
}

function isValidYouTubeUrl($url) {
    $patterns = [
        '/^https?:\/\/(www\.)?(youtube\.com|youtu\.be)/',
        '/^https?:\/\/(www\.)?youtube\.com\/watch\?v=/',
        '/^https?:\/\/youtu\.be\//',
        '/^https?:\/\/(www\.)?youtube\.com\/playlist\?list=/'
    ];

    foreach ($patterns as $pattern) {
        if (preg_match($pattern, $url)) {
            return true;
        }
    }

    return false;
}

function generateDownloadId() {
    return 'dl_' . date('YmdHis') . '_' . substr(md5(uniqid()), 0, 8);
}

function getVideoInfo($url) {
    $ytdlpCheck = checkYtDlpInstallation();
    if (!$ytdlpCheck['available']) {
        return false;
    }

    $command = $ytdlpCheck['path'] . " --dump-json --no-download " . escapeshellarg($url) . " 2>/dev/null";
    $result = executeCommand($command);

    if ($result['success'] && !empty($result['output'])) {
        $jsonOutput = implode("\n", $result['output']);
        $videoInfo = json_decode($jsonOutput, true);

        if ($videoInfo) {
            return [
                'title' => $videoInfo['title'] ?? 'Unknown',
                'duration' => $videoInfo['duration'] ?? 0,
                'duration_formatted' => formatDuration($videoInfo['duration'] ?? 0),
                'thumbnail' => $videoInfo['thumbnail'] ?? null,
                'uploader' => $videoInfo['uploader'] ?? 'Unknown',
                'upload_date' => $videoInfo['upload_date'] ?? null,
                'view_count' => $videoInfo['view_count'] ?? 0,
                'description' => substr($videoInfo['description'] ?? '', 0, 200),
                'formats' => extractAvailableFormats($videoInfo['formats'] ?? [])
            ];
        }
    }

    return false;
}

function extractAvailableFormats($formats) {
    $availableFormats = [];

    foreach ($formats as $format) {
        if (isset($format['height']) && $format['height'] > 0) {
            $quality = $format['height'] . 'p';
            if (!in_array($quality, $availableFormats)) {
                $availableFormats[] = $quality;
            }
        }
    }

    // Sort by quality (highest first)
    rsort($availableFormats, SORT_NUMERIC);

    return $availableFormats;
}

function saveDownloadToQueue($downloadParams) {
    $queueFile = CONFIG_PATH . '/download_queue.json';
    $queue = [];

    if (file_exists($queueFile)) {
        $queue = json_decode(file_get_contents($queueFile), true) ?: [];
    }

    $queue[$downloadParams['id']] = $downloadParams;
    file_put_contents($queueFile, json_encode($queue, JSON_PRETTY_PRINT));
}

function getDownloadQueue() {
    $queueFile = CONFIG_PATH . '/download_queue.json';

    if (file_exists($queueFile)) {
        $queue = json_decode(file_get_contents($queueFile), true) ?: [];

        // Clean up completed downloads older than 24 hours
        $cutoff = time() - 86400;
        foreach ($queue as $id => $download) {
            if (isset($download['completed_at']) &&
                strtotime($download['completed_at']) < $cutoff) {
                unset($queue[$id]);
            }
        }

        // Save cleaned queue
        file_put_contents($queueFile, json_encode($queue, JSON_PRETTY_PRINT));

        return array_values($queue);
    }

    return [];
}

function getDownloadStatus($downloadId) {
    $queueFile = CONFIG_PATH . '/download_queue.json';

    if (file_exists($queueFile)) {
        $queue = json_decode(file_get_contents($queueFile), true) ?: [];

        if (isset($queue[$downloadId])) {
            return $queue[$downloadId];
        }
    }

    return null;
}

function updateDownloadStatus($downloadId, $status, $progress = null, $filename = null) {
    $queueFile = CONFIG_PATH . '/download_queue.json';
    $queue = [];

    if (file_exists($queueFile)) {
        $queue = json_decode(file_get_contents($queueFile), true) ?: [];
    }

    if (isset($queue[$downloadId])) {
        $queue[$downloadId]['status'] = $status;
        $queue[$downloadId]['updated_at'] = date('Y-m-d H:i:s');

        if ($progress !== null) {
            $queue[$downloadId]['progress'] = $progress;
        }

        if ($filename !== null) {
            $queue[$downloadId]['filename'] = $filename;
        }

        if ($status === 'completed') {
            $queue[$downloadId]['completed_at'] = date('Y-m-d H:i:s');
        }

        file_put_contents($queueFile, json_encode($queue, JSON_PRETTY_PRINT));
    }
}

function startDownload($downloadId, $url, $quality, $format, $audioOnly) {
    $ytdlpCheck = checkYtDlpInstallation();
    if (!$ytdlpCheck['available']) {
        return false;
    }

    $outputPath = MEDIA_PATH . '/%(title)s.%(ext)s';
    $command = $ytdlpCheck['path'];

    // Format selection
    if ($audioOnly) {
        $command .= " -f 'bestaudio/best' --extract-audio --audio-format mp3";
    } else {
        if ($quality === 'best') {
            $command .= " -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'";
        } else {
            $qualityNum = intval(str_replace('p', '', $quality));
            $command .= " -f 'bestvideo[height<=$qualityNum][ext=mp4]+bestaudio[ext=m4a]/best[height<=$qualityNum]'";
        }
    }

    // Output template
    $command .= " -o " . escapeshellarg($outputPath);

    // Progress hook
    $progressFile = CONFIG_PATH . "/progress_$downloadId.txt";
    $command .= " --newline --progress-template '%(progress._percent_str)s %(filename)s'";

    // Add URL
    $command .= " " . escapeshellarg($url);

    // Redirect output to log file
    $logFile = LOGS_PATH . "/youtube_$downloadId.log";
    $command .= " > " . escapeshellarg($logFile) . " 2>&1";

    // Create progress monitoring script
    $scriptPath = createProgressScript($downloadId, $progressFile, $logFile);

    // Update status to downloading
    updateDownloadStatus($downloadId, 'downloading', 0);

    // Execute download in background
    $bgCommand = "bash $scriptPath &";
    exec($bgCommand);

    return true;
}

function createProgressScript($downloadId, $progressFile, $logFile) {
    $scriptContent = <<<SCRIPT
#!/bin/bash

DOWNLOAD_ID="$downloadId"
PROGRESS_FILE="$progressFile"
LOG_FILE="$logFile"
CONFIG_PATH="{CONFIG_PATH}"

# Function to update download status via PHP
update_status() {
    local status=\$1
    local progress=\$2
    local filename=\$3

    php -r "
    require_once '/opt/pisignage/web/config.php';

    \\\$queueFile = CONFIG_PATH . '/download_queue.json';
    \\\$queue = [];

    if (file_exists(\\\$queueFile)) {
        \\\$queue = json_decode(file_get_contents(\\\$queueFile), true) ?: [];
    }

    if (isset(\\\$queue['\$DOWNLOAD_ID'])) {
        \\\$queue['\$DOWNLOAD_ID']['status'] = '\$status';
        \\\$queue['\$DOWNLOAD_ID']['updated_at'] = date('Y-m-d H:i:s');

        if ('\$progress' !== '') {
            \\\$queue['\$DOWNLOAD_ID']['progress'] = floatval('\$progress');
        }

        if ('\$filename' !== '') {
            \\\$queue['\$DOWNLOAD_ID']['filename'] = '\$filename';
        }

        if ('\$status' === 'completed') {
            \\\$queue['\$DOWNLOAD_ID']['completed_at'] = date('Y-m-d H:i:s');
        }

        file_put_contents(\\\$queueFile, json_encode(\\\$queue, JSON_PRETTY_PRINT));

        if ('\$status' === 'completed' && '\$filename' !== '') {
            logMessage('YouTube download completed: \$filename (ID: \$DOWNLOAD_ID)');
        }
    }
    "
}

# Monitor progress
tail -f "\$LOG_FILE" | while read line; do
    if [[ \$line =~ ([0-9]+\.[0-9]+)%.*\/(.*) ]]; then
        progress=\${BASH_REMATCH[1]}
        filename=\$(basename "\${BASH_REMATCH[2]}")
        update_status "downloading" "\$progress" "\$filename"
    elif [[ \$line =~ "has already been downloaded" ]]; then
        update_status "completed" "100" ""
        break
    elif [[ \$line =~ "ERROR" ]]; then
        update_status "error" "" ""
        break
    fi
done

# Check final status
if grep -q "has already been downloaded\|100%" "\$LOG_FILE"; then
    update_status "completed" "100" ""
else
    update_status "error" "" ""
fi

# Cleanup
rm -f "\$PROGRESS_FILE"
rm -f "\$0"
SCRIPT;

    $scriptPath = CONFIG_PATH . "/download_script_$downloadId.sh";
    file_put_contents($scriptPath, $scriptContent);
    chmod($scriptPath, 0755);

    return $scriptPath;
}

function cancelDownload($downloadId) {
    // Kill process if running
    $result = executeCommand("pkill -f 'yt-dlp.*$downloadId'");

    // Update status
    updateDownloadStatus($downloadId, 'cancelled');

    // Clean up files
    $progressFile = CONFIG_PATH . "/progress_$downloadId.txt";
    $logFile = LOGS_PATH . "/youtube_$downloadId.log";
    $scriptFile = CONFIG_PATH . "/download_script_$downloadId.sh";

    if (file_exists($progressFile)) unlink($progressFile);
    if (file_exists($logFile)) unlink($logFile);
    if (file_exists($scriptFile)) unlink($scriptFile);

    return true;
}


// Cleanup old downloads on startup
function cleanupOldDownloads() {
    $queueFile = CONFIG_PATH . '/download_queue.json';

    if (file_exists($queueFile)) {
        $queue = json_decode(file_get_contents($queueFile), true) ?: [];
        $cleaned = false;

        foreach ($queue as $id => $download) {
            // Remove downloads older than 7 days
            if (isset($download['started_at']) &&
                strtotime($download['started_at']) < time() - 604800) {
                unset($queue[$id]);
                $cleaned = true;
            }
        }

        if ($cleaned) {
            file_put_contents($queueFile, json_encode($queue, JSON_PRETTY_PRINT));
            logMessage("Cleaned up old YouTube downloads");
        }
    }
}

// Auto-cleanup on API load
if (isset($_GET['cleanup']) && $_GET['cleanup'] === 'true') {
    cleanupOldDownloads();
    jsonResponse(true, null, 'Cleanup completed');
}
?>