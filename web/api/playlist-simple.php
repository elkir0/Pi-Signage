<?php
/**
 * PiSignage v0.8.3 - Simple Playlist API
 * Simplified playlist management for the playlist editor
 */

require_once '../config.php';

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGetPlaylists();
        break;
    case 'POST':
        handleSavePlaylist($input);
        break;
    case 'DELETE':
        handleDeletePlaylist();
        break;
    default:
        jsonResponse(false, null, 'Method not allowed');
}

function handleGetPlaylists() {
    $playlists = [];

    if (is_dir(PLAYLISTS_PATH)) {
        $jsonFiles = glob(PLAYLISTS_PATH . '/*.json');
        foreach ($jsonFiles as $file) {
            $playlist = json_decode(file_get_contents($file), true);
            if ($playlist) {
                // Add file modification time for sorting
                $playlist['file_modified'] = filemtime($file);
                $playlists[] = $playlist;
            }
        }

        // Sort by modification time (newest first)
        usort($playlists, function($a, $b) {
            return $b['file_modified'] - $a['file_modified'];
        });
    }

    jsonResponse(true, $playlists);
}

function handleSavePlaylist($input) {
    if (!$input || !isset($input['name'])) {
        jsonResponse(false, null, 'Playlist name required');
        return;
    }

    $name = sanitizeFilename($input['name']);
    $items = $input['items'] ?? [];
    $settings = $input['settings'] ?? [];

    // Validate items structure
    $validatedItems = [];
    foreach ($items as $item) {
        $validatedItem = [
            'file' => $item['file'] ?? '',
            'duration' => intval($item['duration'] ?? 10),
            'transition' => $item['transition'] ?? 'none',
            'order' => intval($item['order'] ?? 0)
        ];

        // Validate file exists
        if (!empty($validatedItem['file'])) {
            $filepath = MEDIA_PATH . '/' . basename($validatedItem['file']);
            if (file_exists($filepath)) {
                $validatedItems[] = $validatedItem;
            }
        }
    }

    // Sort items by order
    usort($validatedItems, function($a, $b) {
        return $a['order'] - $b['order'];
    });

    $playlist = [
        'name' => $name,
        'items' => $validatedItems,
        'settings' => [
            'loop' => $settings['loop'] ?? true,
            'shuffle' => $settings['shuffle'] ?? false,
            'auto_advance' => $settings['auto_advance'] ?? true,
            'fade_duration' => intval($settings['fade_duration'] ?? 1000)
        ],
        'created' => $input['created'] ?? date('Y-m-d H:i:s'),
        'modified' => date('Y-m-d H:i:s'),
        'total_duration' => array_sum(array_column($validatedItems, 'duration'))
    ];

    $filename = PLAYLISTS_PATH . '/' . $name . '.json';

    if (file_put_contents($filename, json_encode($playlist, JSON_PRETTY_PRINT))) {
        logMessage("Playlist saved: $name (" . count($validatedItems) . " items)");
        jsonResponse(true, $playlist, 'Playlist saved successfully');
    } else {
        jsonResponse(false, null, 'Failed to save playlist');
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
        logMessage("Playlist deleted: $name");
        jsonResponse(true, null, 'Playlist deleted successfully');
    } else {
        jsonResponse(false, null, 'Failed to delete playlist');
    }
}

?>