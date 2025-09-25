<?php
/**
 * PiSignage v0.8.0 - Simplified Playlist API
 * Version simplifiée sans SQLite pour debug
 */

require_once '../config.php';

$method = $_SERVER['REQUEST_METHOD'];
$playlistFile = CONFIG_PATH . '/playlists.json';

// Initialize playlists file if it doesn't exist
if (!file_exists($playlistFile)) {
    file_put_contents($playlistFile, json_encode([]));
}

switch ($method) {
    case 'GET':
        $playlists = json_decode(file_get_contents($playlistFile), true) ?: [];

        // Ensure proper structure for each playlist
        foreach ($playlists as &$playlist) {
            if (!isset($playlist['items'])) {
                $playlist['items'] = [];
            }
            $playlist['item_count'] = count($playlist['items']);
        }

        jsonResponse(true, $playlists);
        break;

    case 'POST':
        $input = json_decode(file_get_contents('php://input'), true);
        $playlists = json_decode(file_get_contents($playlistFile), true) ?: [];

        if (!isset($input['name'])) {
            jsonResponse(false, null, 'Playlist name required');
        }

        // Check if playlist exists
        foreach ($playlists as $existing) {
            if ($existing['name'] === $input['name']) {
                jsonResponse(false, null, 'Playlist already exists');
            }
        }

        // Create new playlist
        $newPlaylist = [
            'name' => $input['name'],
            'items' => $input['items'] ?? [],
            'description' => $input['description'] ?? '',
            'created_at' => date('Y-m-d H:i:s')
        ];

        $playlists[] = $newPlaylist;
        file_put_contents($playlistFile, json_encode($playlists, JSON_PRETTY_PRINT));

        jsonResponse(true, $newPlaylist, 'Playlist created');
        break;

    case 'DELETE':
        $input = json_decode(file_get_contents('php://input'), true);
        $playlists = json_decode(file_get_contents($playlistFile), true) ?: [];

        if (!isset($input['name'])) {
            jsonResponse(false, null, 'Playlist name required');
        }

        $filtered = array_filter($playlists, function($p) use ($input) {
            return $p['name'] !== $input['name'];
        });

        if (count($filtered) === count($playlists)) {
            jsonResponse(false, null, 'Playlist not found');
        }

        file_put_contents($playlistFile, json_encode(array_values($filtered), JSON_PRETTY_PRINT));
        jsonResponse(true, null, 'Playlist deleted');
        break;

    default:
        jsonResponse(false, null, 'Method not allowed');
}
?>