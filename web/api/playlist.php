<?php
header('Content-Type: application/json');

$playlists_file = '/opt/pisignage/config/playlists.json';

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Get playlists
    if (file_exists($playlists_file)) {
        echo file_get_contents($playlists_file);
    } else {
        echo json_encode(['playlists' => []]);
    }
} elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Create/update playlist
    $input = json_decode(file_get_contents('php://input'), true);

    // Save playlist
    $playlists = [];
    if (file_exists($playlists_file)) {
        $playlists = json_decode(file_get_contents($playlists_file), true);
    }

    $playlists[] = $input;
    file_put_contents($playlists_file, json_encode($playlists));

    echo json_encode(['success' => true]);
} else {
    echo json_encode(['error' => 'Method not allowed']);
}
?>