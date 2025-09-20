<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$playlistFile = '/opt/pisignage/config/playlists.json';
$mediaDir = '/opt/pisignage/media/';

// Créer le fichier s'il n'existe pas
if (!file_exists($playlistFile)) {
    file_put_contents($playlistFile, json_encode(['playlists' => []]));
}

$action = $_GET['action'] ?? $_POST['action'] ?? 'list';
$data = json_decode(file_get_contents($playlistFile), true);

switch ($action) {
    case 'list':
        // Lister les playlists
        echo json_encode($data);
        break;
        
    case 'create':
        // Créer une playlist
        $name = $_POST['name'] ?? 'Nouvelle Playlist';
        $videos = json_decode($_POST['videos'] ?? '[]', true);
        $playlist = [
            'id' => uniqid(),
            'name' => $name,
            'videos' => $videos,
            'created' => date('Y-m-d H:i:s')
        ];
        $data['playlists'][] = $playlist;
        file_put_contents($playlistFile, json_encode($data, JSON_PRETTY_PRINT));
        echo json_encode(['success' => true, 'playlist' => $playlist]);
        break;
        
    case 'play':
        // Jouer une playlist
        $id = $_GET['id'] ?? '';
        foreach ($data['playlists'] as $playlist) {
            if ($playlist['id'] === $id) {
                $videos = array_map(function($v) use ($mediaDir) {
                    return $mediaDir . $v;
                }, $playlist['videos']);
                $videoList = implode(' ', $videos);
                exec("/opt/pisignage/scripts/vlc-control.sh stop");
                sleep(1);
                exec("/opt/pisignage/scripts/vlc-control.sh start \"$videoList\"");
                echo json_encode(['success' => true, 'playing' => $playlist['name']]);
                exit;
            }
        }
        echo json_encode(['success' => false, 'error' => 'Playlist non trouvée']);
        break;
        
    case 'delete':
        // Supprimer une playlist
        $id = $_POST['id'] ?? '';
        $data['playlists'] = array_filter($data['playlists'], function($p) use ($id) {
            return $p['id'] !== $id;
        });
        file_put_contents($playlistFile, json_encode($data, JSON_PRETTY_PRINT));
        echo json_encode(['success' => true]);
        break;
        
    case 'videos':
        // Lister les vidéos disponibles
        $videos = [];
        foreach (glob($mediaDir . '*.{mp4,avi,mkv,webm,mov}', GLOB_BRACE) as $file) {
            $videos[] = [
                'name' => basename($file),
                'size' => filesize($file),
                'duration' => exec("ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 \"$file\" 2>/dev/null")
            ];
        }
        echo json_encode(['videos' => $videos]);
        break;
}
