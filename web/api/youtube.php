<?php
/**
 * PiSignage v0.8.9 - YouTube Download API
 *
 * YouTube video downloader using yt-dlp with queue management and progress tracking.
 * Supports quality selection, audio extraction, and background download processing.
 *
 * @package    PiSignage
 * @subpackage API
 * @version    0.8.9
 * @since      0.8.0
 */

require_once '../config.php';
require_once 'media.php';

// Only execute request handling if this file is called directly (not included)
if (basename($_SERVER['SCRIPT_FILENAME']) === 'youtube.php' ||
    basename($_SERVER['SCRIPT_FILENAME']) === 'youtube-simple.php') {
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
}

/**
 * Handle GET requests for download data.
 *
 * Supports queue, status, info, and check_ytdlp actions.
 *
 * @since 0.8.0
 */
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

/**
 * Start YouTube video download.
 *
 * @param array $input Request data with url, quality, format, audio_only
 * @since 0.8.0
 */
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

/**
 * Cancel active download.
 *
 * @param array $input Request data with download ID
 * @since 0.8.0
 */
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

/**
 * Check yt-dlp installation status.
 *
 * @return array Installation info with available, path, version
 * @since 0.8.0
 */
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

/**
 * Get yt-dlp version.
 *
 * @param string $path Path to yt-dlp executable
 * @return string Version string
 * @since 0.8.0
 */
function getYtDlpVersion($path) {
    $result = executeCommand("$path --version 2>/dev/null");
    if ($result['success'] && !empty($result['output'])) {
        return trim($result['output'][0]);
    }
    return 'Unknown';
}

/**
 * Validate YouTube URL format.
 *
 * @param string $url URL to validate
 * @return bool True if valid YouTube URL
 * @since 0.8.0
 */
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

/**
 * Generate unique download ID.
 *
 * @return string Download ID with timestamp
 * @since 0.8.0
 */
function generateDownloadId() {
    return 'dl_' . date('YmdHis') . '_' . substr(md5(uniqid()), 0, 8);
}

/**
 * Get video metadata from YouTube.
 *
 * @param string $url YouTube video URL
 * @return array|false Video info or false on failure
 * @since 0.8.0
 */
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

/**
 * Extract available quality formats.
 *
 * @param array $formats yt-dlp format list
 * @return array Quality options (e.g., ["1080p", "720p"])
 * @since 0.8.0
 */
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

/**
 * Save download to queue file.
 *
 * @param array $downloadParams Download parameters
 * @since 0.8.0
 */
function saveDownloadToQueue($downloadParams) {
    $queueFile = CONFIG_PATH . '/download_queue.json';
    $queue = [];

    if (file_exists($queueFile)) {
        $queue = json_decode(file_get_contents($queueFile), true) ?: [];
    }

    $queue[$downloadParams['id']] = $downloadParams;
    file_put_contents($queueFile, json_encode($queue, JSON_PRETTY_PRINT));
}

/**
 * Get download queue with auto-cleanup.
 *
 * @return array Download queue items
 * @since 0.8.0
 */
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

/**
 * Get status of specific download.
 *
 * @param string $downloadId Download ID
 * @return array|null Download status or null if not found
 * @since 0.8.0
 */
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

/**
 * Update download status in queue.
 *
 * @param string $downloadId Download ID
 * @param string $status Status (queued, downloading, completed, error)
 * @param int|null $progress Progress percentage
 * @param string|null $filename Downloaded filename
 * @since 0.8.0
 */
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

/**
 * Start background download process.
 *
 * @param string $downloadId Download ID
 * @param string $url YouTube URL
 * @param string $quality Quality (best, 1080p, 720p, etc.)
 * @param string $format Output format (mp4, mp3)
 * @param bool $audioOnly Extract audio only
 * @return bool True if started successfully
 * @since 0.8.0
 */
function startDownload($downloadId, $url, $quality, $format, $audioOnly) {
    $ytdlpCheck = checkYtDlpInstallation();
    if (!$ytdlpCheck['available']) {
        return false;
    }

    $outputPath = MEDIA_PATH . '/%(title)s.%(ext)s';
    $command = $ytdlpCheck['path'];

    // Format selection - Updated to handle modern YouTube formats
    if ($audioOnly) {
        $command .= " -f 'bestaudio/best' --extract-audio --audio-format mp3";
    } else {
        if ($quality === 'best') {
            // Try best video+audio merge, fallback to best single file with audio
            $command .= " -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best'";
        } else {
            $qualityNum = intval(str_replace('p', '', $quality));
            // Try merge at quality, fallback to single file with audio at quality, then any format at quality
            $command .= " -f 'bestvideo[height<=$qualityNum][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$qualityNum]+bestaudio/best[height<=$qualityNum]/best'";
        }
        // Merge output container
        $command .= " --merge-output-format mp4";
    }

    // Output template
    $command .= " -o " . escapeshellarg($outputPath);

    // Add URL
    $command .= " " . escapeshellarg($url);

    // Log file (but don't redirect in command - the script will handle it)
    $logFile = LOGS_PATH . "/youtube_$downloadId.log";

    // Create download script with proper monitoring
    $scriptPath = createDownloadScript($downloadId, $command, $logFile);

    // Update status to downloading
    updateDownloadStatus($downloadId, 'downloading', 0);

    // Execute download in background
    $bgCommand = "bash $scriptPath > /dev/null 2>&1 &";
    exec($bgCommand);

    logMessage("YouTube download script created: $scriptPath for URL: $url");

    return true;
}

/**
 * Create bash script for background download.
 *
 * @param string $downloadId Download ID
 * @param string $ytdlpCommand yt-dlp command to execute
 * @param string $logFile Log file path
 * @return string Script path
 * @since 0.8.0
 */
function createDownloadScript($downloadId, $ytdlpCommand, $logFile) {
    $configPath = CONFIG_PATH;
    $mediaPath = MEDIA_PATH;

    // Create bash script with proper escaping
    $scriptContent = "#!/bin/bash\n\n";
    $scriptContent .= "DOWNLOAD_ID=\"$downloadId\"\n";
    $scriptContent .= "LOG_FILE=\"$logFile\"\n";
    $scriptContent .= "CONFIG_PATH=\"$configPath\"\n";
    $scriptContent .= "MEDIA_PATH=\"$mediaPath\"\n\n";

    $scriptContent .= "# Ensure log directory exists\n";
    $scriptContent .= "mkdir -p \"\$(dirname \"\$LOG_FILE\")\"\n\n";

    $scriptContent .= "# Update download status\n";
    $scriptContent .= "update_status() {\n";
    $scriptContent .= "    local status=\"\$1\"\n";
    $scriptContent .= "    local progress=\"\${2:-0}\"\n";
    $scriptContent .= "    local filename=\"\${3:-}\"\n";
    $scriptContent .= "    php -r \"\n";
    $scriptContent .= "    require_once '/opt/pisignage/web/config.php';\n";
    $scriptContent .= "    require_once '/opt/pisignage/web/api/youtube.php';\n";
    $scriptContent .= "    updateDownloadStatus('\$DOWNLOAD_ID', '\$status', \$progress, '\$filename');\n";
    $scriptContent .= "    \"\n";
    $scriptContent .= "}\n\n";

    $scriptContent .= "# Execute download\n";
    $scriptContent .= "echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Starting YouTube download: \$DOWNLOAD_ID\" >> \"\$LOG_FILE\"\n";
    $scriptContent .= "update_status \"downloading\" 0\n\n";

    $scriptContent .= "# Run yt-dlp and capture output\n";
    $scriptContent .= "$ytdlpCommand >> \"\$LOG_FILE\" 2>&1\n";
    $scriptContent .= "YTDLP_EXIT_CODE=\$?\n\n";

    $scriptContent .= "# Parse log to find downloaded filename\n";
    $scriptContent .= "DOWNLOADED_FILE=\"\"\n";
    $scriptContent .= "if [ -f \"\$LOG_FILE\" ]; then\n";
    $scriptContent .= "    # Try to find merged file from [Merger] line (most reliable)\n";
    $scriptContent .= "    MERGED_PATH=\$(grep -oP '\\[Merger\\] Merging formats into \"\\K[^\"]+' \"\$LOG_FILE\" | tail -1 2>/dev/null)\n";
    $scriptContent .= "    if [ -n \"\$MERGED_PATH\" ] && [ -f \"\$MERGED_PATH\" ]; then\n";
    $scriptContent .= "        DOWNLOADED_FILE=\$(basename \"\$MERGED_PATH\")\n";
    $scriptContent .= "    fi\n\n";
    $scriptContent .= "    # If not found, try destination filename in log\n";
    $scriptContent .= "    if [ -z \"\$DOWNLOADED_FILE\" ]; then\n";
    $scriptContent .= "        DEST_PATH=\$(grep -oP '\\[download\\] Destination: \\K.*' \"\$LOG_FILE\" | tail -1 2>/dev/null)\n";
    $scriptContent .= "        if [ -n \"\$DEST_PATH\" ]; then\n";
    $scriptContent .= "            DOWNLOADED_FILE=\$(basename \"\$DEST_PATH\")\n";
    $scriptContent .= "            # Remove format suffix if present (.f696.mp4 -> check for final .mp4)\n";
    $scriptContent .= "            FINAL_FILE=\"\${DOWNLOADED_FILE%%.f[0-9]*.mp4}.mp4\"\n";
    $scriptContent .= "            if [ -f \"\$MEDIA_PATH/\$FINAL_FILE\" ]; then\n";
    $scriptContent .= "                DOWNLOADED_FILE=\"\$FINAL_FILE\"\n";
    $scriptContent .= "            fi\n";
    $scriptContent .= "        fi\n";
    $scriptContent .= "    fi\n\n";
    $scriptContent .= "    # Last resort: find any .mp4/.webm/.mkv file created in last 2 minutes\n";
    $scriptContent .= "    if [ -z \"\$DOWNLOADED_FILE\" ]; then\n";
    $scriptContent .= "        FOUND_FILE=\$(find \"\$MEDIA_PATH\" -maxdepth 1 -type f \\( -name \"*.mp4\" -o -name \"*.webm\" -o -name \"*.mkv\" \\) -mmin -2 2>/dev/null | head -1)\n";
    $scriptContent .= "        if [ -n \"\$FOUND_FILE\" ]; then\n";
    $scriptContent .= "            DOWNLOADED_FILE=\$(basename \"\$FOUND_FILE\")\n";
    $scriptContent .= "        fi\n";
    $scriptContent .= "    fi\n";
    $scriptContent .= "fi\n\n";

    $scriptContent .= "# Update final status\n";
    $scriptContent .= "if [ \$YTDLP_EXIT_CODE -eq 0 ] && [ -n \"\$DOWNLOADED_FILE\" ] && [ -f \"\$MEDIA_PATH/\$DOWNLOADED_FILE\" ]; then\n";
    $scriptContent .= "    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Download completed: \$DOWNLOADED_FILE\" >> \"\$LOG_FILE\"\n";
    $scriptContent .= "    update_status \"completed\" 100 \"\$DOWNLOADED_FILE\"\n";
    $scriptContent .= "else\n";
    $scriptContent .= "    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] Download failed with exit code: \$YTDLP_EXIT_CODE\" >> \"\$LOG_FILE\"\n";
    $scriptContent .= "    update_status \"error\" 0\n";
    $scriptContent .= "fi\n\n";

    $scriptContent .= "# Self-cleanup after 5 minutes\n";
    $scriptContent .= "sleep 300\n";
    $scriptContent .= "rm -f \"\$0\"\n";

    $scriptPath = CONFIG_PATH . "/download_script_$downloadId.sh";
    file_put_contents($scriptPath, $scriptContent);
    chmod($scriptPath, 0755);

    return $scriptPath;
}

/**
 * Create progress tracking script (DEPRECATED).
 *
 * @deprecated 0.8.9 Use createDownloadScript instead
 * @param string $downloadId Download ID
 * @param string $progressFile Progress file path
 * @param string $logFile Log file path
 * @return string Script path
 * @since 0.8.0
 */
function createProgressScript($downloadId, $progressFile, $logFile) {
    // DEPRECATED - Kept for compatibility
    return createDownloadScript($downloadId, '', $logFile);
}

/**
 * Cancel active download and cleanup.
 *
 * @param string $downloadId Download ID
 * @return bool True on success
 * @since 0.8.0
 */
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


/**
 * Remove old downloads from queue (7+ days).
 *
 * @since 0.8.0
 */
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