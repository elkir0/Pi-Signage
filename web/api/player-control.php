<?php
/**
 * PiSignage v0.8.9 - Player Control API
 *
 * Real-time VLC player control via HTTP interface (localhost:8080, password: pisignage).
 * Supports playback control, playlist management, volume, and system monitoring.
 *
 * @package    PiSignage
 * @subpackage API
 * @version    0.8.9
 * @since      0.8.0
 */

require_once '../config.php';

/**
 * Get CPU usage percentage.
 *
 * @return float CPU load percentage
 * @since 0.8.0
 */
function getCpuUsage() {
    $load = sys_getloadavg();
    return round($load[0] * 25, 1); // Simple approximation
}

/**
 * Get system memory usage.
 *
 * @return array Memory stats with total, used, and percent
 * @since 0.8.0
 */
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

/**
 * Get Raspberry Pi CPU temperature.
 *
 * @return float|null Temperature in Celsius or null if unavailable
 * @since 0.8.0
 */
function getRaspberryPiTemperature() {
    if (file_exists('/sys/class/thermal/thermal_zone0/temp')) {
        $temp = intval(file_get_contents('/sys/class/thermal/thermal_zone0/temp'));
        return round($temp / 1000, 1);
    }
    return null;
}

/**
 * Get system uptime.
 *
 * @return string Human-readable uptime
 * @since 0.8.0
 */
function getUptime() {
    $uptime = shell_exec('uptime -p');
    return trim($uptime);
}

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// VLC Configuration
define('VLC_HOST', 'localhost');
define('VLC_PORT', '8080');
define('VLC_PASSWORD', 'pisignage');

/**
 * VLC HTTP interface controller.
 *
 * @since 0.8.0
 */
class VLCController {
    private $baseUrl;
    private $auth;

    public function __construct() {
        $this->baseUrl = 'http://' . VLC_HOST . ':' . VLC_PORT;
        $this->auth = base64_encode(':' . VLC_PASSWORD);
    }

    /**
     * Send command to VLC HTTP interface.
     *
     * @param string $command VLC command name
     * @param array $params Command parameters
     * @return array Response with success status
     * @since 0.8.0
     */
    private function sendCommand($command, $params = []) {
        $url = $this->baseUrl . '/requests/status.json?command=' . $command;

        foreach ($params as $key => $value) {
            // Use rawurlencode to encode spaces as %20 (not +) for VLC compatibility
            $url .= '&' . $key . '=' . rawurlencode($value);
        }

        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'header' => [
                    'Authorization: Basic ' . $this->auth,
                    'Content-Type: application/json'
                ],
                'timeout' => 5,
                'ignore_errors' => true
            ]
        ]);

        $response = @file_get_contents($url, false, $context);

        if ($response === false) {
            // Fallback to shell command if HTTP interface is not available
            return $this->fallbackToShell($command, $params);
        }

        $vlcResponse = json_decode($response, true);
        // VLC doesn't return success field, so we add it if we got a response
        if ($vlcResponse !== null) {
            return ['success' => true, 'data' => $vlcResponse];
        }
        return ['success' => false, 'message' => 'Invalid VLC response'];
    }

    /**
     * Fallback to shell commands via netcat.
     *
     * @param string $command VLC command
     * @param array $params Command parameters
     * @return array Response with success status
     * @since 0.8.0
     */
    private function fallbackToShell($command, $params) {
        $result = ['success' => false, 'message' => 'Command not implemented'];

        switch ($command) {
            case 'pl_play':
                exec('echo "play" | nc localhost 4212 2>&1', $output, $returnVar);
                $result = ['success' => $returnVar === 0];
                break;

            case 'pl_pause':
                exec('echo "pause" | nc localhost 4212 2>&1', $output, $returnVar);
                $result = ['success' => $returnVar === 0];
                break;

            case 'pl_stop':
                exec('echo "stop" | nc localhost 4212 2>&1', $output, $returnVar);
                $result = ['success' => $returnVar === 0];
                break;

            case 'volume':
                $vol = intval($params['val'] ?? 100);
                exec("echo 'volume $vol' | nc localhost 4212 2>&1", $output, $returnVar);
                $result = ['success' => $returnVar === 0, 'volume' => $vol];
                break;
        }

        return $result;
    }

    /**
     * Get detailed player status.
     *
     * @return array Player state, position, volume, and playlist
     * @since 0.8.0
     */
    public function getStatus() {
        $url = $this->baseUrl . '/requests/status.json';

        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'header' => 'Authorization: Basic ' . $this->auth,
                'timeout' => 5,
                'ignore_errors' => true
            ]
        ]);

        $response = @file_get_contents($url, false, $context);

        if ($response === false) {
            // Try to get status from process
            return $this->getProcessStatus();
        }

        $status = json_decode($response, true);

        // Format status for frontend
        return [
            'state' => $status['state'] ?? 'stopped',
            'position' => floatval($status['time'] ?? 0),
            'duration' => floatval($status['length'] ?? 0),
            'volume' => intval($status['volume'] ?? 0) / 2.56, // Convert to 0-100
            'fullscreen' => $status['fullscreen'] ?? false,
            'current_file' => $this->extractCurrentFile($status),
            'playlist' => $this->extractPlaylistInfo($status)
        ];
    }

    /**
     * Get status from VLC process when HTTP unavailable.
     *
     * @return array Basic player status
     * @since 0.8.0
     */
    private function getProcessStatus() {
        $isRunning = false;
        $currentFile = null;

        // Check if VLC is running
        exec('pgrep vlc', $output, $returnVar);
        $isRunning = $returnVar === 0;

        // Try to get current file from process info
        if ($isRunning) {
            exec('ps aux | grep vlc | grep -v grep', $psOutput);
            foreach ($psOutput as $line) {
                if (preg_match('/\/opt\/pisignage\/media\/(.+?)[\s$]/', $line, $matches)) {
                    $currentFile = $matches[1];
                    break;
                }
            }
        }

        return [
            'state' => $isRunning ? 'playing' : 'stopped',
            'position' => 0,
            'duration' => 0,
            'volume' => 50,
            'fullscreen' => false,
            'current_file' => $currentFile,
            'playlist' => []
        ];
    }

    /**
     * Extract current file from VLC status.
     *
     * @param array $status VLC status response
     * @return string|null Current filename
     * @since 0.8.0
     */
    private function extractCurrentFile($status) {
        if (isset($status['information']['category']['meta']['filename'])) {
            return $status['information']['category']['meta']['filename'];
        }

        if (isset($status['information']['category']['meta']['title'])) {
            return $status['information']['category']['meta']['title'];
        }

        return null;
    }

    /**
     * Extract playlist from VLC status.
     *
     * @param array $status VLC status response
     * @return array Playlist items
     * @since 0.8.0
     */
    private function extractPlaylistInfo($status) {
        $playlist = [];

        if (isset($status['playlist']['children'])) {
            foreach ($status['playlist']['children'] as $node) {
                if (isset($node['children'])) {
                    foreach ($node['children'] as $item) {
                        $playlist[] = [
                            'id' => $item['id'] ?? null,
                            'name' => $item['name'] ?? 'Unknown',
                            'uri' => $item['uri'] ?? '',
                            'current' => isset($item['current']) ? true : false
                        ];
                    }
                }
            }
        }

        return $playlist;
    }

    /**
     * Play current media.
     *
     * @return array Response with success status
     * @since 0.8.0
     */
    public function play() {
        return $this->sendCommand('pl_play');
    }

    /**
     * Pause playback.
     *
     * @return array Response with success status
     * @since 0.8.0
     */
    public function pause() {
        return $this->sendCommand('pl_pause');
    }

    /**
     * Stop playback.
     *
     * @return array Response with success status
     * @since 0.8.0
     */
    public function stop() {
        return $this->sendCommand('pl_stop');
    }

    /**
     * Play next item in playlist.
     *
     * @return array Response with success status
     * @since 0.8.0
     */
    public function next() {
        return $this->sendCommand('pl_next');
    }

    /**
     * Play previous item in playlist.
     *
     * @return array Response with success status
     * @since 0.8.0
     */
    public function previous() {
        return $this->sendCommand('pl_previous');
    }

    /**
     * Seek to position in seconds.
     *
     * @param int $position Position in seconds
     * @return array Response with success status
     * @since 0.8.0
     */
    public function seek($position) {
        return $this->sendCommand('seek', ['val' => $position]);
    }

    /**
     * Set volume level.
     *
     * @param int $volume Volume 0-100
     * @return array Response with success status
     * @since 0.8.9
     */
    public function setVolume($volume) {
        // Convert 0-100 to VLC's 0-256 scale
        $vlcVolume = intval($volume * 2.56);
        return $this->sendCommand('volume', ['val' => $vlcVolume]);
    }

    /**
     * Play specific media file.
     *
     * @param string $file Filename in media directory
     * @return array Response with success status
     * @since 0.8.0
     */
    public function playFile($file) {
        $fullPath = MEDIA_DIR . '/' . basename($file);
        if (!file_exists($fullPath)) {
            return ['success' => false, 'message' => 'File not found'];
        }

        return $this->sendCommand('in_play', ['input' => $fullPath]);
    }

    /**
     * Add file to playlist.
     *
     * @param string $file Filename in media directory
     * @return array Response with success status
     * @since 0.8.0
     */
    public function addToPlaylist($file) {
        $fullPath = MEDIA_DIR . '/' . basename($file);
        if (!file_exists($fullPath)) {
            return ['success' => false, 'message' => 'File not found'];
        }

        return $this->sendCommand('in_enqueue', ['input' => $fullPath]);
    }

    /**
     * Clear VLC playlist.
     *
     * @return array Response with success status
     * @since 0.8.0
     */
    public function clearPlaylist() {
        return $this->sendCommand('pl_empty');
    }

    /**
     * Enable or disable loop mode.
     *
     * @param bool $enabled Loop enabled
     * @return array Response with success status
     * @since 0.8.0
     */
    public function setLoop($enabled) {
        $mode = $enabled ? 'on' : 'off';
        return $this->sendCommand('pl_loop', ['val' => $mode]);
    }

    /**
     * Enable or disable random mode.
     *
     * @param bool $enabled Random enabled
     * @return array Response with success status
     * @since 0.8.0
     */
    public function setRandom($enabled) {
        $mode = $enabled ? 'on' : 'off';
        return $this->sendCommand('pl_random', ['val' => $mode]);
    }

    /**
     * Enable or disable fullscreen mode.
     *
     * @param bool $enabled Fullscreen enabled
     * @return array Response with success status
     * @since 0.8.0
     */
    public function setFullscreen($enabled) {
        return $this->sendCommand('fullscreen', ['val' => $enabled ? '1' : '0']);
    }
}

// Handle requests
$vlc = new VLCController();
$method = $_SERVER['REQUEST_METHOD'];

// Handle preflight requests
if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Get action from request
$action = $_GET['action'] ?? $_POST['action'] ?? null;

if ($method === 'GET' && $action === 'status') {
    // Return current status
    $status = $vlc->getStatus();

    // Add system information
    $status['system'] = [
        'cpu' => getCpuUsage(),
        'memory' => getMemoryUsage(),
        'temperature' => getRaspberryPiTemperature(),
        'uptime' => getUptime()
    ];

    jsonResponse(true, $status);
} elseif ($method === 'POST') {
    // Handle player commands
    $input = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? $action;
    $params = $input['params'] ?? [];

    $result = ['success' => false, 'message' => 'Unknown action'];

    switch ($action) {
        case 'play':
            $result = $vlc->play();
            break;

        case 'pause':
            $result = $vlc->pause();
            break;

        case 'stop':
            $result = $vlc->stop();
            break;

        case 'next':
            $result = $vlc->next();
            break;

        case 'previous':
            $result = $vlc->previous();
            break;

        case 'seek':
            $position = $params['position'] ?? 0;
            $result = $vlc->seek($position);
            break;

        case 'volume':
            $volume = $params['volume'] ?? 50;
            $result = $vlc->setVolume($volume);
            break;

        case 'play_file':
            $file = $params['file'] ?? '';
            $result = $vlc->playFile($file);
            break;

        case 'add_to_playlist':
            $file = $params['file'] ?? '';
            $result = $vlc->addToPlaylist($file);
            break;

        case 'clear_playlist':
            $result = $vlc->clearPlaylist();
            break;

        case 'set_loop':
            $enabled = $params['enabled'] ?? false;
            $result = $vlc->setLoop($enabled);
            break;

        case 'set_random':
            $enabled = $params['enabled'] ?? false;
            $result = $vlc->setRandom($enabled);
            break;

        case 'set_fullscreen':
            $enabled = $params['enabled'] ?? false;
            $result = $vlc->setFullscreen($enabled);
            break;

        case 'load_playlist':
            $playlistName = $params['name'] ?? '';
            $result = loadPlaylistToVLC($playlistName);
            break;
    }

    // Add current status to response
    $result['status'] = $vlc->getStatus();

    // Set proper success status and message
    $success = $result['success'] ?? false;

    // If we have a result with data, consider it successful
    if (!$success && isset($result['data'])) {
        $success = true;
    }

    // Create proper response message
    if ($success) {
        $message = ucfirst($action) . ' command executed';
    } else {
        $message = $result['message'] ?? 'Command failed';
    }

    jsonResponse($success, $result, $message);
} else {
    jsonResponse(false, null, 'Invalid request method');
}

/**
 * Load PiSignage playlist into VLC.
 *
 * @param string $playlistName Playlist name without extension
 * @return array Response with success status and loaded playlist
 * @since 0.8.0
 */
function loadPlaylistToVLC($playlistName) {
    $playlistFile = PLAYLISTS_PATH . '/' . $playlistName . '.json';

    if (!file_exists($playlistFile)) {
        return ['success' => false, 'message' => 'Playlist not found'];
    }

    $playlist = json_decode(file_get_contents($playlistFile), true);

    if (!$playlist || !isset($playlist['items'])) {
        return ['success' => false, 'message' => 'Invalid playlist format'];
    }

    // Clear current playlist
    $vlc = new VLCController();
    $vlc->clearPlaylist();

    // Add items to VLC playlist
    foreach ($playlist['items'] as $item) {
        if (isset($item['file'])) {
            $vlc->addToPlaylist($item['file']);
        }
    }

    // Apply settings
    if (isset($playlist['settings'])) {
        $vlc->setLoop($playlist['settings']['loop'] ?? false);
        $vlc->setRandom($playlist['settings']['shuffle'] ?? false);
    }

    // Start playing
    $vlc->play();

    return ['success' => true, 'message' => 'Playlist loaded', 'playlist' => $playlistName];
}
?>