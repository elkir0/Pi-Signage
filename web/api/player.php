<?php
/**
 * PiSignage v0.8.0 - Player Control API
 * Controls VLC media player
 */

require_once '../config.php';

// Handle different HTTP methods
$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGetStatus();
        break;

    case 'POST':
        handlePlayerAction($input);
        break;

    default:
        jsonResponse(false, null, 'Method not allowed');
}

function handleGetStatus() {
    $status = vlcCommand('status');

    if ($status === false) {
        jsonResponse(false, null, 'VLC not responding');
    }

    jsonResponse(true, $status);
}

function handlePlayerAction($input) {
    if (!isset($input['action'])) {
        jsonResponse(false, null, 'Action parameter required');
    }

    $action = $input['action'];

    switch ($action) {
        case 'play':
            $result = vlcCommand('pl_play');
            break;

        case 'pause':
            $result = vlcCommand('pl_pause');
            break;

        case 'stop':
            $result = vlcCommand('pl_stop');
            break;

        case 'next':
            $result = vlcCommand('pl_next');
            break;

        case 'previous':
            $result = vlcCommand('pl_previous');
            break;

        case 'volume':
            if (!isset($input['value'])) {
                jsonResponse(false, null, 'Volume value required');
            }
            $volume = intval($input['value']);
            $result = vlcCommand('volume', ['val' => $volume]);
            break;

        case 'seek':
            if (!isset($input['position'])) {
                jsonResponse(false, null, 'Position parameter required');
            }
            $position = floatval($input['position']);
            $result = vlcCommand('seek', ['val' => $position . '%']);
            break;

        case 'play_file':
        case 'play-file':  // Support both formats
            if (!isset($input['file'])) {
                jsonResponse(false, null, 'File parameter required');
            }

            $filename = $input['file'];
            $filepath = MEDIA_PATH . '/' . basename($filename);

            if (!file_exists($filepath)) {
                jsonResponse(false, null, 'File not found');
            }

            // Clear playlist and add file
            vlcCommand('pl_empty');
            $result = vlcCommand('in_play', ['input' => $filepath]);
            break;

        case 'play_playlist':
            if (!isset($input['playlist'])) {
                jsonResponse(false, null, 'Playlist parameter required');
            }

            $playlistName = $input['playlist'];
            $playlistFile = PLAYLISTS_PATH . '/' . $playlistName . '.json';

            if (!file_exists($playlistFile)) {
                jsonResponse(false, null, 'Playlist not found');
            }

            $playlist = json_decode(file_get_contents($playlistFile), true);

            if (!$playlist || !isset($playlist['items'])) {
                jsonResponse(false, null, 'Invalid playlist format');
            }

            // Clear current playlist
            vlcCommand('pl_empty');

            // Add all files to VLC playlist
            foreach ($playlist['items'] as $item) {
                $filepath = MEDIA_PATH . '/' . basename($item);
                if (file_exists($filepath)) {
                    vlcCommand('in_enqueue', ['input' => $filepath]);
                }
            }

            // Start playing
            $result = vlcCommand('pl_play');
            break;

        case 'toggle_loop':
            $result = vlcCommand('pl_loop');
            break;

        case 'toggle_repeat':
            $result = vlcCommand('pl_repeat');
            break;

        case 'fullscreen':
            $result = vlcCommand('fullscreen');
            break;

        case 'set-mode':
            if (!isset($input['mode'])) {
                jsonResponse(false, null, 'Mode parameter required');
            }

            $mode = $input['mode'];
            $startScript = '/opt/pisignage/start-pisignage.sh';

            // Kill current processes
            executeCommand('sudo killall -9 vlc chromium-browser chromium 2>/dev/null');
            sleep(1);

            switch ($mode) {
                case 'fullscreen':
                    // VLC only in fullscreen
                    $cmd = 'DISPLAY=:0 cvlc --fullscreen --loop --no-audio --intf http --http-password pisignage /opt/pisignage/media/playlist.m3u > /dev/null 2>&1 &';
                    executeCommand($cmd);
                    $result = ['mode' => 'fullscreen', 'status' => 'started'];
                    break;

                case 'windowed':
                    // VLC in windowed mode
                    $cmd = 'DISPLAY=:0 cvlc --width=1920 --height=1050 --no-embedded-video --loop --no-audio --intf http --http-password pisignage /opt/pisignage/media/playlist.m3u > /dev/null 2>&1 &';
                    executeCommand($cmd);
                    $result = ['mode' => 'windowed', 'status' => 'started'];
                    break;

                case 'with-rss':
                    // Launch the full startup script with RSS
                    executeCommand("bash $startScript > /dev/null 2>&1 &");
                    $result = ['mode' => 'with-rss', 'status' => 'started'];
                    break;

                default:
                    jsonResponse(false, null, 'Invalid mode: ' . $mode);
            }

            logMessage("Player mode changed to: $mode");
            break;

        default:
            jsonResponse(false, null, 'Unknown action: ' . $action);
    }

    if ($result === false) {
        jsonResponse(false, null, 'VLC command failed');
    }

    logMessage("Player action executed: $action");
    jsonResponse(true, $result, "Action $action executed successfully");
}

// VLC control script fallback for system commands
function executeVLCScript($action, $params = []) {
    $scriptPath = SCRIPTS_PATH . '/vlc-control.sh';

    if (!file_exists($scriptPath)) {
        return false;
    }

    $command = "bash $scriptPath $action";

    foreach ($params as $param) {
        $command .= ' ' . escapeshellarg($param);
    }

    $result = executeCommand($command);
    return $result['success'];
}

// Alternative VLC control using system scripts if HTTP interface fails
function vlcSystemControl($action, $file = null) {
    switch ($action) {
        case 'play':
            if ($file) {
                $filepath = MEDIA_PATH . '/' . basename($file);
                return executeVLCScript('play', [$filepath]);
            } else {
                return executeVLCScript('resume');
            }

        case 'stop':
            return executeVLCScript('stop');

        case 'pause':
            return executeVLCScript('pause');

        case 'kill':
            return executeVLCScript('kill');

        default:
            return false;
    }
}
?>