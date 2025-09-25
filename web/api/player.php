<?php
/**
 * PiSignage v0.8.0 - Unified Player Control API
 * Controls both VLC and MPV media players via unified script
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

define('MEDIA_PATH', '/opt/pisignage/media');
define('SCRIPTS_PATH', '/opt/pisignage/scripts');
define('PLAYLISTS_PATH', '/opt/pisignage/config');
define('LOGS_PATH', '/opt/pisignage/logs');
define('UNIFIED_SCRIPT', '/opt/pisignage/scripts/unified-player-control.sh');

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        // Get current player status
        if (isset($_GET['action']) && $_GET['action'] === 'current') {
            // Get current player
            $current_player = exec(UNIFIED_SCRIPT . ' current 2>&1');
            echo json_encode([
                'success' => true,
                'current_player' => trim($current_player)
            ]);
        } else {
            // Get player status
            $status = exec(UNIFIED_SCRIPT . ' status 2>&1');
            echo json_encode([
                'success' => true,
                'status' => $status,
                'running' => strpos($status, 'running') !== false
            ]);
        }
        break;

    case 'POST':
        if (!isset($input['action'])) {
            echo json_encode(['success' => false, 'message' => 'Action required']);
            exit;
        }

        $action = $input['action'];
        $success = false;
        $message = '';
        $output = [];
        $retval = 0;

        switch ($action) {
            case 'play':
            case 'start':
                // Start current player with all media files
                $output = [];
                exec(UNIFIED_SCRIPT . ' play 2>&1', $output, $retval);
                $success = ($retval === 0);
                $message = !empty($output) ? implode("\n", $output) : 'Player started';
                break;

            case 'stop':
                // Stop current player
                $output = [];
                exec(UNIFIED_SCRIPT . ' stop 2>&1', $output, $retval);
                $success = ($retval === 0);
                $message = !empty($output) ? implode("\n", $output) : 'Player stopped';
                break;

            case 'restart':
                // Restart current player
                $output = [];
                exec(UNIFIED_SCRIPT . ' restart 2>&1', $output, $retval);
                $success = ($retval === 0);
                $message = !empty($output) ? implode("\n", $output) : 'Player restarted';
                break;

            case 'pause':
                // Pause current player
                $output = [];
                exec(UNIFIED_SCRIPT . ' pause 2>&1', $output, $retval);
                $success = true;
                $message = !empty($output) ? implode("\n", $output) : 'Player paused/resumed';
                break;

            case 'next':
                // Next track
                $output = [];
                exec(UNIFIED_SCRIPT . ' next 2>&1', $output, $retval);
                $success = true;
                $message = !empty($output) ? implode("\n", $output) : 'Next track';
                break;

            case 'previous':
            case 'prev':
                // Previous track
                $output = [];
                exec(UNIFIED_SCRIPT . ' prev 2>&1', $output, $retval);
                $success = true;
                $message = !empty($output) ? implode("\n", $output) : 'Previous track';
                break;

            case 'switch':
            case 'switch_player':
                // Switch between VLC and MPV
                $output = [];
                exec(UNIFIED_SCRIPT . ' switch 2>&1', $output, $retval);
                $success = ($retval === 0);
                $message = !empty($output) ? implode("\n", $output) : 'Player switched';
                break;

            case 'play-file':
            case 'play_file':
                if (!isset($input['file'])) {
                    echo json_encode(['success' => false, 'message' => 'File required']);
                    exit;
                }

                $filename = basename($input['file']);
                $filepath = MEDIA_PATH . '/' . $filename;

                if (!file_exists($filepath)) {
                    echo json_encode(['success' => false, 'message' => 'File not found']);
                    exit;
                }

                // Stop current MPV and play specific file
                exec('pkill -f mpv 2>/dev/null');
                sleep(1);

                $cmd = "mpv --fullscreen --loop-playlist=inf --really-quiet " .
                       escapeshellarg($filepath) . " > " . LOGS_PATH . "/mpv.log 2>&1 &";
                exec($cmd, $output, $retval);

                $success = true;
                $message = "Playing: $filename";
                break;

            case 'play-playlist':
            case 'play_playlist':
                if (!isset($input['playlist'])) {
                    echo json_encode(['success' => false, 'message' => 'Playlist required']);
                    exit;
                }

                $playlistName = $input['playlist'];
                $playlistFile = PLAYLISTS_PATH . '/' . $playlistName . '.json';

                if (!file_exists($playlistFile)) {
                    echo json_encode(['success' => false, 'message' => 'Playlist not found']);
                    exit;
                }

                $playlist = json_decode(file_get_contents($playlistFile), true);

                if (!$playlist || !isset($playlist['files'])) {
                    echo json_encode(['success' => false, 'message' => 'Invalid playlist']);
                    exit;
                }

                // Stop current MPV
                exec('pkill -f mpv 2>/dev/null');
                sleep(1);

                // Build file list
                $files = [];
                foreach ($playlist['files'] as $file) {
                    $filepath = MEDIA_PATH . '/' . basename($file);
                    if (file_exists($filepath)) {
                        $files[] = escapeshellarg($filepath);
                    }
                }

                if (empty($files)) {
                    echo json_encode(['success' => false, 'message' => 'No valid files in playlist']);
                    exit;
                }

                // Play playlist
                $cmd = "mpv --fullscreen --loop-playlist=inf --really-quiet " .
                       implode(' ', $files) . " > " . LOGS_PATH . "/mpv.log 2>&1 &";
                exec($cmd, $output, $retval);

                $success = true;
                $message = "Playing playlist: $playlistName";
                break;

            case 'volume':
                // Volume control via unified script
                if (!isset($input['value'])) {
                    echo json_encode(['success' => false, 'message' => 'Volume value required']);
                    exit;
                }
                $volume = intval($input['value']);
                $output = [];
                exec(UNIFIED_SCRIPT . " volume $volume 2>&1", $output, $retval);
                $success = ($retval === 0);
                $message = !empty($output) ? implode("\n", $output) : "Volume set to $volume%";
                break;

            default:
                $success = false;
                $message = "Unknown action: $action";
        }

        echo json_encode([
            'success' => $success,
            'message' => $message,
            'action' => $action
        ]);
        break;

    default:
        echo json_encode(['success' => false, 'message' => 'Method not allowed']);
}
?>