<?php
/**
 * PiSignage v0.11.0 - YouTube Download API
 *
 * YouTube video downloader using yt-dlp with queue management and progress tracking.
 * Supports quality selection, audio extraction, and background download processing.
 *
 * @package    PiSignage
 * @subpackage API
 * @version    0.11.0
 * @since      0.8.0
 */

// Auth guard for HTTP requests only; the detached CLI download worker re-includes
// this file to call updateDownloadStatus() and must not be blocked by the session check.
if (php_sapi_name() !== 'cli') {
    require_once __DIR__ . '/_guard.php';
}
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
        'suggestion' => 'Install/update yt-dlp: yt-dlp -U'
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

    // Build the yt-dlp invocation as an argument array (no shell interpolation).
    $ytdlpArgs = [$ytdlpCheck['path']];

    if ($audioOnly) {
        $ytdlpArgs[] = '-f';
        $ytdlpArgs[] = 'bestaudio/best';
        $ytdlpArgs[] = '--extract-audio';
        $ytdlpArgs[] = '--audio-format';
        $ytdlpArgs[] = 'mp3';
    } else {
        if ($quality === 'best') {
            // Try best video+audio merge, fallback to best single file with audio
            $ytdlpArgs[] = '-f';
            $ytdlpArgs[] = 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best';
        } else {
            $qualityNum = intval(str_replace('p', '', $quality));
            // Try merge at quality, fallback to single file with audio at quality, then any format at quality
            $ytdlpArgs[] = '-f';
            $ytdlpArgs[] = "bestvideo[height<=$qualityNum][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$qualityNum]+bestaudio/best[height<=$qualityNum]/best";
        }
        // Merge output container
        $ytdlpArgs[] = '--merge-output-format';
        $ytdlpArgs[] = 'mp4';
    }

    // Output template
    $ytdlpArgs[] = '-o';
    $ytdlpArgs[] = $outputPath;

    // Add URL (passed as a discrete argv element, never interpolated into a shell)
    $ytdlpArgs[] = $url;

    // Log file
    $logFile = LOGS_PATH . "/youtube_$downloadId.log";

    // Create a detached PHP worker that runs yt-dlp via proc_open (array form, no shell)
    $started = launchDownloadWorker($downloadId, $ytdlpArgs, $logFile);

    if (!$started) {
        return false;
    }

    // Update status to downloading
    updateDownloadStatus($downloadId, 'downloading', 0);

    logMessage("YouTube download worker launched (ID: $downloadId) for URL: $url");

    return true;
}

/**
 * Launch a detached PHP worker that downloads via yt-dlp without any shell interpolation.
 *
 * The yt-dlp invocation is passed as an argument array; the worker runs it with
 * proc_open() (array form) so the URL/quality can never be interpreted by a shell.
 *
 * @param string $downloadId Download ID
 * @param array  $ytdlpArgs  yt-dlp argv (first element = executable path)
 * @param string $logFile    Log file path
 * @return bool True if the worker was launched
 * @since 0.11.0
 */
function launchDownloadWorker($downloadId, array $ytdlpArgs, $logFile) {
    // Persist the job parameters as JSON (no shell interpolation, no secrets in argv).
    $jobFile = CONFIG_PATH . "/download_job_$downloadId.json";
    $job = [
        'download_id' => $downloadId,
        'ytdlp_args'  => array_values($ytdlpArgs),
        'log_file'    => $logFile,
        'media_path'  => MEDIA_PATH,
    ];
    if (file_put_contents($jobFile, json_encode($job)) === false) {
        return false;
    }
    chmod($jobFile, 0600);

    // Generate the worker script (static PHP, no interpolated user input).
    $workerPath = createDownloadWorker($downloadId);

    // Launch the worker detached from this request via proc_open with an argv array
    // (array form bypasses /bin/sh entirely). setsid detaches it from the FPM process group.
    $cmd = ['setsid', PHP_BINARY, $workerPath, $jobFile];
    $descriptors = [
        0 => ['file', '/dev/null', 'r'],
        1 => ['file', '/dev/null', 'a'],
        2 => ['file', '/dev/null', 'a'],
    ];
    $proc = proc_open($cmd, $descriptors, $pipes);
    if (!is_resource($proc)) {
        return false;
    }
    proc_close($proc); // setsid forks the worker, so this returns immediately

    return true;
}

/**
 * Generate the detached PHP download worker.
 *
 * The worker contains no interpolated user input: it reads the job JSON, runs
 * yt-dlp via proc_open (array form), detects the resulting file, then updates
 * the download status by re-using updateDownloadStatus() from this API.
 *
 * @param string $downloadId Download ID
 * @return string Worker script path
 * @since 0.11.0
 */
function createDownloadWorker($downloadId) {
    $apiFile = __FILE__;

    $worker = <<<'PHPWORKER'
<?php
// PiSignage YouTube download worker (auto-generated, runs detached).
$jobFile = $argv[1] ?? '';
if ($jobFile === '' || !is_file($jobFile)) {
    exit(1);
}
$job = json_decode(file_get_contents($jobFile), true);
if (!is_array($job) || empty($job['ytdlp_args'])) {
    exit(1);
}

$downloadId = $job['download_id'];
$logFile    = $job['log_file'];
$mediaPath  = $job['media_path'];
$ytdlpArgs  = $job['ytdlp_args'];

// Re-use the API's status/queue helpers (CLI-exempt guard, so no auth required here).
// chdir into the api dir first so youtube.php's relative '../config.php' resolves to
// the same realpath as our absolute include -> require_once dedupes (no redeclare).
require_once '__CONFIG_PATH__';
chdir(dirname('__API_FILE__'));
require_once '__API_FILE__';

@mkdir(dirname($logFile), 0755, true);

$ts = function () { return date('Y-m-d H:i:s'); };
file_put_contents($logFile, '[' . $ts() . "] Starting YouTube download: $downloadId\n", FILE_APPEND);
updateDownloadStatus($downloadId, 'downloading', 0);

// Run yt-dlp via proc_open with an argv array -> no shell, no interpolation.
$descriptors = [
    0 => ['file', '/dev/null', 'r'],
    1 => ['file', $logFile, 'a'],
    2 => ['file', $logFile, 'a'],
];
$proc = proc_open($ytdlpArgs, $descriptors, $pipes);
$exitCode = 1;
if (is_resource($proc)) {
    $exitCode = proc_close($proc);
}

// Detect the downloaded filename from the yt-dlp log (PHP, no shell).
$downloadedFile = '';
$log = is_file($logFile) ? file_get_contents($logFile) : '';

if ($log !== '') {
    // 1) Merged output ("[Merger] Merging formats into "...") is most reliable.
    if (preg_match_all('/\[Merger\] Merging formats into "([^"]+)"/', $log, $m) && !empty($m[1])) {
        $merged = end($m[1]);
        if (is_file($merged)) {
            $downloadedFile = basename($merged);
        }
    }
    // 2) Otherwise the [download] Destination: line.
    if ($downloadedFile === '' && preg_match_all('/\[download\] Destination: (.+)/', $log, $m) && !empty($m[1])) {
        $dest = trim(end($m[1]));
        $candidate = basename($dest);
        // Strip per-format suffix (".f696.mp4" -> ".mp4") and prefer the final file.
        $final = preg_replace('/\.f[0-9]+\.mp4$/', '.mp4', $candidate);
        if ($final !== null && is_file($mediaPath . '/' . $final)) {
            $downloadedFile = $final;
        } elseif (is_file($mediaPath . '/' . $candidate)) {
            $downloadedFile = $candidate;
        }
    }
}

// 3) Last resort: newest media file created in the last 2 minutes.
if ($downloadedFile === '') {
    $newest = '';
    $newestMtime = 0;
    $cutoff = time() - 120;
    foreach (glob($mediaPath . '/*.{mp4,webm,mkv}', GLOB_BRACE) ?: [] as $f) {
        $mtime = filemtime($f);
        if ($mtime >= $cutoff && $mtime > $newestMtime) {
            $newestMtime = $mtime;
            $newest = $f;
        }
    }
    if ($newest !== '') {
        $downloadedFile = basename($newest);
    }
}

if ($exitCode === 0 && $downloadedFile !== '' && is_file($mediaPath . '/' . $downloadedFile)) {
    file_put_contents($logFile, '[' . $ts() . "] Download completed: $downloadedFile\n", FILE_APPEND);
    updateDownloadStatus($downloadId, 'completed', 100, $downloadedFile);
} else {
    file_put_contents($logFile, '[' . $ts() . "] Download failed with exit code: $exitCode\n", FILE_APPEND);
    updateDownloadStatus($downloadId, 'error', 0);
}

// Self-cleanup: remove the job file and this worker.
@unlink($jobFile);
@unlink(__FILE__);
PHPWORKER;

    // Inject the (trusted, constant) paths.
    $worker = str_replace('__CONFIG_PATH__', BASE_DIR . '/web/config.php', $worker);
    $worker = str_replace('__API_FILE__', $apiFile, $worker);

    $workerPath = CONFIG_PATH . "/download_worker_$downloadId.php";
    file_put_contents($workerPath, $worker);
    chmod($workerPath, 0600);

    return $workerPath;
}

/**
 * Cancel active download and cleanup.
 *
 * @param string $downloadId Download ID
 * @return bool True on success
 * @since 0.8.0
 */
function cancelDownload($downloadId) {
    // Kill the detached worker (and its yt-dlp child) by matching the worker file name.
    $result = executeCommand('pkill -f ' . escapeshellarg("download_worker_$downloadId.php"));

    // Update status
    updateDownloadStatus($downloadId, 'cancelled');

    // Clean up files
    $progressFile = CONFIG_PATH . "/progress_$downloadId.txt";
    $logFile = LOGS_PATH . "/youtube_$downloadId.log";
    $workerFile = CONFIG_PATH . "/download_worker_$downloadId.php";
    $jobFile = CONFIG_PATH . "/download_job_$downloadId.json";

    if (file_exists($progressFile)) unlink($progressFile);
    if (file_exists($logFile)) unlink($logFile);
    if (file_exists($workerFile)) unlink($workerFile);
    if (file_exists($jobFile)) unlink($jobFile);

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