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
        // Créer une playlist avec tous les paramètres
        $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        
        $name = $input['name'] ?? 'Nouvelle Playlist';
        $videos = $input['videos'] ?? $input['items'] ?? [];
        $settings = $input['settings'] ?? [];
        
        $playlist = [
            'id' => uniqid('playlist_'),
            'name' => $name,
            'items' => is_array($videos) ? $videos : json_decode($videos, true) ?? [],
            'settings' => [
                'loop' => $settings['loop'] ?? true,
                'shuffle' => $settings['shuffle'] ?? false,
                'image_duration' => $settings['image_duration'] ?? 10,
                'transition' => $settings['transition'] ?? 'none',
                'transition_duration' => $settings['transition_duration'] ?? 1000
            ],
            'created' => date('Y-m-d H:i:s'),
            'modified' => date('Y-m-d H:i:s')
        ];
        
        // Ajouter au fichier JSON
        if (!isset($data['playlists'])) {
            $data['playlists'] = [];
        }
        $data['playlists'][] = $playlist;
        
        file_put_contents($playlistFile, json_encode($data, JSON_PRETTY_PRINT));
        echo json_encode(['success' => true, 'playlist' => $playlist]);
        break;
        
    case 'play':
        // Jouer une playlist avec le nouveau moteur
        $id = $_GET['id'] ?? '';
        
        if ($id === 'default') {
            // Utiliser la playlist par défaut (tous les médias)
            $output = shell_exec("/opt/pisignage/scripts/playlist-engine.sh start default 2>&1");
            echo json_encode([
                'success' => true,
                'playing' => 'Playlist par défaut',
                'output' => $output
            ]);
        } else {
            // Vérifier que la playlist existe
            $found = false;
            foreach ($data['playlists'] as $playlist) {
                if ($playlist['id'] === $id) {
                    $found = true;
                    $name = $playlist['name'];
                    break;
                }
            }
            
            if ($found) {
                $output = shell_exec("/opt/pisignage/scripts/playlist-engine.sh start " . escapeshellarg($id) . " 2>&1");
                echo json_encode([
                    'success' => true,
                    'playing' => $name,
                    'output' => $output
                ]);
            } else {
                echo json_encode(['success' => false, 'error' => 'Playlist non trouvée']);
            }
        }
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
    case 'media':
        // Lister tous les médias disponibles (vidéos ET images)
        $media = [];
        
        // Vidéos
        foreach (glob($mediaDir . '*.{mp4,avi,mkv,webm,mov}', GLOB_BRACE) as $file) {
            $duration = trim(shell_exec("ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 " . escapeshellarg($file) . " 2>/dev/null"));
            $media[] = [
                'name' => basename($file),
                'type' => 'video',
                'size' => filesize($file),
                'duration' => $duration ? round($duration) : 0
            ];
        }
        
        // Images
        foreach (glob($mediaDir . '*.{jpg,jpeg,png,gif,bmp}', GLOB_BRACE) as $file) {
            $media[] = [
                'name' => basename($file),
                'type' => 'image',
                'size' => filesize($file),
                'duration' => 10 // Durée par défaut pour les images
            ];
        }
        
        echo json_encode(['media' => $media, 'videos' => $media]);
        break;
}
