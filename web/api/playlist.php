<?php
require_once "/opt/pisignage/web/config.php";

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGetPlaylists();
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
            
        default:
            jsonResponse(false, null, 'Unknown action');
    }
}
?>
