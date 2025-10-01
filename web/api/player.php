<?php
/**
 * PiSignage v0.8.9 - VLC Player Control API
 * Controls VLC media player via VLCController
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// Use the VLCController from player-control.php
require_once __DIR__ . '/player-control.php';

define('MEDIA_PATH', '/opt/pisignage/media');
define('PLAYLISTS_PATH', '/opt/pisignage/config');

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

// Initialize VLC controller
$vlc = new VLCController();

switch ($method) {
    case 'GET':
        // Get current player status
        if (isset($_GET['action']) && $_GET['action'] === 'current') {
            echo json_encode([
                'success' => true,
                'current_player' => 'vlc',
                'player' => 'vlc'
            ]);
        } else {
            // Get VLC status
            $status = $vlc->getStatus();
            echo json_encode([
                'success' => true,
                'status' => $status,
                'running' => ($status['state'] ?? '') !== 'stopped',
                'player' => 'vlc'
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

        switch ($action) {
            case 'play':
            case 'start':
                $result = $vlc->play();
                $success = $result;
                $message = $result ? 'Player started' : 'Failed to start player';
                break;

            case 'stop':
                $result = $vlc->stop();
                $success = $result;
                $message = $result ? 'Player stopped' : 'Failed to stop player';
                break;

            case 'restart':
                $vlc->stop();
                sleep(1);
                $result = $vlc->play();
                $success = $result;
                $message = $result ? 'Player restarted' : 'Failed to restart player';
                break;

            case 'pause':
                $result = $vlc->pause();
                $success = $result;
                $message = $result ? 'Player paused/resumed' : 'Failed to pause player';
                break;

            case 'next':
                $result = $vlc->next();
                $success = $result;
                $message = $result ? 'Next track' : 'Failed to skip to next';
                break;

            case 'previous':
            case 'prev':
                $result = $vlc->previous();
                $success = $result;
                $message = $result ? 'Previous track' : 'Failed to go to previous';
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
                    echo json_encode(['success' => false, 'message' => 'File not found: ' . $filename]);
                    exit;
                }

                // TODO BUG-013: Single file playback doesn't work reliably
                // VLC service starts with entire /media/ directory and HTTP interface
                // has async behavior that makes switching files unreliable.
                // Current workaround: Use playlists instead of single files.

                // Attempt to play file (may not work due to VLC service config)
                $vlc->stop();
                $vlc->clearPlaylist();
                $vlc->addToPlaylist($filepath);
                $vlc->play();

                $success = true;
                $message = "Playing: $filename (Note: May still play previous file due to VLC limitation)";
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
                    echo json_encode(['success' => false, 'message' => 'Playlist not found: ' . $playlistName]);
                    exit;
                }

                $playlist = json_decode(file_get_contents($playlistFile), true);

                if (!$playlist || !isset($playlist['files'])) {
                    echo json_encode(['success' => false, 'message' => 'Invalid playlist format']);
                    exit;
                }

                // Stop current playback
                $vlc->stop();
                sleep(1);

                // Clear VLC playlist
                $vlc->clearPlaylist();

                // Add files to VLC playlist
                $addedCount = 0;
                foreach ($playlist['files'] as $file) {
                    $filepath = MEDIA_PATH . '/' . basename($file);
                    if (file_exists($filepath)) {
                        if ($vlc->addToPlaylist($filepath)) {
                            $addedCount++;
                        }
                    }
                }

                if ($addedCount === 0) {
                    echo json_encode(['success' => false, 'message' => 'No valid files in playlist']);
                    exit;
                }

                // Start playback
                $vlc->play();

                $success = true;
                $message = "Playing playlist: $playlistName ($addedCount files)";
                break;

            case 'volume':
                if (!isset($input['value'])) {
                    echo json_encode(['success' => false, 'message' => 'Volume value required']);
                    exit;
                }

                $volume = intval($input['value']);
                $volume = max(0, min(100, $volume)); // Clamp 0-100

                $result = $vlc->setVolume($volume);
                $success = $result;
                $message = $result ? "Volume set to $volume%" : "Failed to set volume";
                break;

            default:
                $success = false;
                $message = "Unknown action: $action";
        }

        echo json_encode([
            'success' => $success,
            'message' => $message,
            'action' => $action,
            'player' => 'vlc'
        ]);
        break;

    default:
        echo json_encode(['success' => false, 'message' => 'Method not allowed']);
}
