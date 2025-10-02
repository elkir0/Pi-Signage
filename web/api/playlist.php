<?php
require_once "/opt/pisignage/web/config.php";

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGetPlaylists();
        break;
    case 'POST':
        handleCreatePlaylist($input);
        break;
    case 'PUT':
        handleUpdatePlaylist($input);
        break;
    case 'DELETE':
        handleDeletePlaylist();
        break;
    default:
        jsonResponse(false, null, 'Method not allowed');
}

function handleGetPlaylists() {
    global $db;
    $action = $_GET['action'] ?? 'list';

    switch ($action) {
        case 'list':
            // Mode dégradé sans DB
            $playlists = [];
            if (is_dir(PLAYLISTS_PATH)) {
                $jsonFiles = glob(PLAYLISTS_PATH . '/*.json');
                foreach ($jsonFiles as $file) {
                    $playlist = json_decode(file_get_contents($file), true);
                    if ($playlist) {
                        $playlists[] = $playlist;
                    }
                }
            }
            jsonResponse(true, $playlists);
            break;

        case 'info':
            // Get specific playlist info
            $name = $_GET['name'] ?? null;
            if (!$name) {
                jsonResponse(false, null, 'Playlist name required');
                return;
            }

            $name = sanitizeFilename($name);
            $filename = PLAYLISTS_PATH . '/' . $name . '.json';

            if (!file_exists($filename)) {
                jsonResponse(false, null, 'Playlist not found: ' . $name);
                return;
            }

            $playlist = json_decode(file_get_contents($filename), true);
            if (!$playlist) {
                jsonResponse(false, null, 'Invalid playlist format');
                return;
            }

            jsonResponse(true, $playlist);
            break;

        default:
            jsonResponse(false, null, 'Unknown action');
    }
}

function handleCreatePlaylist($input) {
    if (!$input || !isset($input['name'])) {
        jsonResponse(false, null, 'Playlist name required');
        return;
    }

    $name = sanitizeFilename($input['name']);
    $duration = $input['duration'] ?? 60;
    $items = $input['items'] ?? [];

    $playlist = [
        'name' => $name,
        'duration' => intval($duration),
        'items' => $items,
        'created' => date('Y-m-d H:i:s'),
        'modified' => date('Y-m-d H:i:s')
    ];

    $filename = PLAYLISTS_PATH . '/' . $name . '.json';

    if (file_exists($filename)) {
        jsonResponse(false, null, 'Playlist already exists');
        return;
    }

    if (file_put_contents($filename, json_encode($playlist, JSON_PRETTY_PRINT))) {
        jsonResponse(true, $playlist, 'Playlist created successfully');
    } else {
        jsonResponse(false, null, 'Failed to create playlist');
    }
}

function handleUpdatePlaylist($input) {
    if (!$input || !isset($input['name'])) {
        jsonResponse(false, null, 'Playlist name required');
        return;
    }

    $name = sanitizeFilename($input['name']);
    $filename = PLAYLISTS_PATH . '/' . $name . '.json';

    if (!file_exists($filename)) {
        jsonResponse(false, null, 'Playlist not found');
        return;
    }

    $playlist = json_decode(file_get_contents($filename), true);
    if (!$playlist) {
        jsonResponse(false, null, 'Invalid playlist format');
        return;
    }

    // Update fields
    if (isset($input['duration'])) $playlist['duration'] = intval($input['duration']);
    if (isset($input['items'])) $playlist['items'] = $input['items'];
    $playlist['modified'] = date('Y-m-d H:i:s');

    if (file_put_contents($filename, json_encode($playlist, JSON_PRETTY_PRINT))) {
        jsonResponse(true, $playlist, 'Playlist updated successfully');
    } else {
        jsonResponse(false, null, 'Failed to update playlist');
    }
}

function handleDeletePlaylist() {
    $name = $_GET['name'] ?? null;
    if (!$name) {
        jsonResponse(false, null, 'Playlist name required');
        return;
    }

    $name = sanitizeFilename($name);
    $filename = PLAYLISTS_PATH . '/' . $name . '.json';

    if (!file_exists($filename)) {
        jsonResponse(false, null, 'Playlist not found');
        return;
    }

    if (unlink($filename)) {
        jsonResponse(true, null, 'Playlist deleted successfully');
    } else {
        jsonResponse(false, null, 'Failed to delete playlist');
    }
}

?>
