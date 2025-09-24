<?php
/**
 * PiSignage v0.8.0 - Player Control API
 * Controls MPV media player via shell scripts
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

define('MEDIA_PATH', '/opt/pisignage/media');
define('SCRIPTS_PATH', '/opt/pisignage/scripts');
define('PLAYLISTS_PATH', '/opt/pisignage/config');
define('LOGS_PATH', '/opt/pisignage/logs');

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        // Get MPV status
        $status = exec('/opt/pisignage/scripts/mpv-control.sh status 2>&1');
        echo json_encode([
            'success' => true,
            'status' => $status,
            'running' => strpos($status, 'running') !== false
        ]);
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
                // Start MPV with all media files
                $output = [];
                exec('/opt/pisignage/scripts/mpv-control.sh start 2>&1', $output, $retval);
                $success = ($retval === 0);
                $message = !empty($output) ? implode("\n", $output) : 'MPV started';
                break;

            case 'stop':
                // Stop MPV
                $output = [];
                exec('/opt/pisignage/scripts/mpv-control.sh stop 2>&1', $output, $retval);
                $success = ($retval === 0);
                $message = !empty($output) ? implode("\n", $output) : 'MPV stopped';
                break;

            case 'restart':
                // Restart MPV
                $output = [];
                exec('/opt/pisignage/scripts/mpv-control.sh restart 2>&1', $output, $retval);
                $success = ($retval === 0);
                $message = !empty($output) ? implode("\n", $output) : 'MPV restarted';
                break;

            case 'pause':
                // MPV pause via dbus (if available) or kill/resume
                exec('dbus-send --print-reply --session --dest=org.mpris.MediaPlayer2.mpv /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause 2>&1', $output, $retval);
                if ($retval !== 0) {
                    // Fallback: stop MPV
                    exec('/opt/pisignage/scripts/mpv-control.sh stop 2>&1', $output, $retval);
                }
                $success = true;
                $message = 'Paused';
                break;

            case 'next':
            case 'previous':
                // Not supported in simple mode - restart playlist
                exec('/opt/pisignage/scripts/mpv-control.sh restart 2>&1', $output, $retval);
                $success = true;
                $message = 'Playlist restarted';
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
                // Volume control via amixer
                if (!isset($input['value'])) {
                    echo json_encode(['success' => false, 'message' => 'Volume value required']);
                    exit;
                }
                $volume = intval($input['value']);
                exec("amixer set Master {$volume}% 2>&1", $output, $retval);
                $success = ($retval === 0);
                $message = "Volume set to $volume%";
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