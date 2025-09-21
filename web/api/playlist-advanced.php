<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Gestion CORS
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Configuration
$playlistFile = '/opt/pisignage/config/playlists.json';
$mediaDir = '/opt/pisignage/media/';
$logsDir = '/opt/pisignage/logs/';

// Sécurité - Liste blanche des actions
$allowedActions = [
    'list', 'create', 'update', 'delete', 'duplicate', 
    'get', 'reorder', 'add-media', 'remove-media', 
    'update-media', 'preview', 'export', 'import',
    'get-media-library', 'get-media-info', 'templates',
    'statistics', 'backup', 'restore'
];

// Initialisation
if (!file_exists($playlistFile)) {
    $defaultData = [
        'playlists' => [],
        'active_playlist' => 'default',
        'global_settings' => [
            'default_image_duration' => 10,
            'default_transition' => 'fade',
            'auto_loop' => true,
            'volume' => 80
        ],
        'metadata' => [
            'version' => '1.0.0',
            'created' => date('c'),
            'last_modified' => date('c')
        ]
    ];
    file_put_contents($playlistFile, json_encode($defaultData, JSON_PRETTY_PRINT));
}

// Fonctions utilitaires
function loadPlaylists() {
    global $playlistFile;
    $data = json_decode(file_get_contents($playlistFile), true);
    if (!$data) {
        throw new Exception('Impossible de lire le fichier de playlists');
    }
    return $data;
}

function savePlaylists($data) {
    global $playlistFile;
    $data['metadata']['last_modified'] = date('c');
    $result = file_put_contents($playlistFile, json_encode($data, JSON_PRETTY_PRINT));
    if ($result === false) {
        throw new Exception('Impossible de sauvegarder les playlists');
    }
    return true;
}

function validatePlaylistName($name) {
    return !empty($name) && strlen($name) <= 100 && preg_match('/^[a-zA-Z0-9\s\-_àáâäèéêëìíîïòóôöùúûüç]+$/u', $name);
}

function validateMediaPath($path) {
    global $mediaDir;
    $realPath = realpath($mediaDir . '/' . basename($path));
    return $realPath && strpos($realPath, realpath($mediaDir)) === 0;
}

function getMediaInfo($filename) {
    global $mediaDir;
    $filepath = $mediaDir . '/' . $filename;
    
    if (!file_exists($filepath)) {
        return null;
    }
    
    $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
    $size = filesize($filepath);
    $type = in_array($extension, ['mp4', 'avi', 'mkv', 'mov', 'webm']) ? 'video' : 'image';
    
    $info = [
        'name' => $filename,
        'type' => $type,
        'size' => $size,
        'size_human' => formatBytes($size),
        'extension' => $extension,
        'modified' => filemtime($filepath)
    ];
    
    if ($type === 'video') {
        // Obtenir durée, résolution, codec
        $duration = shell_exec("ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 " . escapeshellarg($filepath) . " 2>/dev/null");
        $width = shell_exec("ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 " . escapeshellarg($filepath) . " 2>/dev/null");
        $height = shell_exec("ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 " . escapeshellarg($filepath) . " 2>/dev/null");
        $codec = shell_exec("ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 " . escapeshellarg($filepath) . " 2>/dev/null");
        
        $info['duration'] = $duration ? round(floatval(trim($duration))) : 0;
        $info['resolution'] = trim($width) && trim($height) ? trim($width) . 'x' . trim($height) : 'Unknown';
        $info['codec'] = trim($codec) ?: 'Unknown';
    } else {
        // Pour les images, obtenir dimensions
        $imageInfo = getimagesize($filepath);
        if ($imageInfo) {
            $info['resolution'] = $imageInfo[0] . 'x' . $imageInfo[1];
        }
        $info['default_duration'] = 10;
    }
    
    return $info;
}

function formatBytes($size, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB'];
    for ($i = 0; $size >= 1024 && $i < count($units) - 1; $i++) {
        $size /= 1024;
    }
    return round($size, $precision) . ' ' . $units[$i];
}

function generateThumbnail($filename) {
    global $mediaDir;
    $filepath = $mediaDir . '/' . $filename;
    $thumbsDir = $mediaDir . '/.thumbnails/';
    
    if (!is_dir($thumbsDir)) {
        mkdir($thumbsDir, 0755, true);
    }
    
    $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
    $thumbPath = $thumbsDir . pathinfo($filename, PATHINFO_FILENAME) . '.jpg';
    
    if (file_exists($thumbPath)) {
        return '/media/.thumbnails/' . pathinfo($filename, PATHINFO_FILENAME) . '.jpg';
    }
    
    if (in_array($extension, ['mp4', 'avi', 'mkv', 'mov', 'webm'])) {
        // Générer thumbnail vidéo
        $cmd = "ffmpeg -i " . escapeshellarg($filepath) . " -ss 00:00:01 -vframes 1 -q:v 2 -s 200x150 " . escapeshellarg($thumbPath) . " 2>/dev/null";
        shell_exec($cmd);
    } elseif (in_array($extension, ['jpg', 'jpeg', 'png', 'gif'])) {
        // Redimensionner image
        $cmd = "convert " . escapeshellarg($filepath) . " -resize 200x150^ -gravity center -extent 200x150 " . escapeshellarg($thumbPath) . " 2>/dev/null";
        shell_exec($cmd);
    }
    
    return file_exists($thumbPath) ? '/media/.thumbnails/' . pathinfo($filename, PATHINFO_FILENAME) . '.jpg' : null;
}

// Traitement des requêtes
try {
    $action = $_GET['action'] ?? $_POST['action'] ?? 'list';
    
    if (!in_array($action, $allowedActions)) {
        throw new Exception('Action non autorisée');
    }
    
    $data = loadPlaylists();
    
    switch ($action) {
        case 'list':
            // Lister toutes les playlists avec statistiques
            $playlists = [];
            foreach ($data['playlists'] as $playlist) {
                $stats = [
                    'total_items' => count($playlist['items'] ?? []),
                    'total_duration' => 0,
                    'videos_count' => 0,
                    'images_count' => 0
                ];
                
                foreach ($playlist['items'] ?? [] as $item) {
                    $info = getMediaInfo($item['path']);
                    if ($info) {
                        if ($info['type'] === 'video') {
                            $stats['videos_count']++;
                            $stats['total_duration'] += $info['duration'] ?? 0;
                        } else {
                            $stats['images_count']++;
                            $stats['total_duration'] += $item['duration'] ?? 10;
                        }
                    }
                }
                
                $playlist['statistics'] = $stats;
                $playlists[] = $playlist;
            }
            
            echo json_encode([
                'success' => true,
                'playlists' => $playlists,
                'active_playlist' => $data['active_playlist'] ?? 'default',
                'global_settings' => $data['global_settings'] ?? []
            ]);
            break;
            
        case 'get':
            // Obtenir une playlist spécifique
            $id = $_GET['id'] ?? '';
            $found = null;
            
            foreach ($data['playlists'] as $playlist) {
                if ($playlist['id'] === $id) {
                    $found = $playlist;
                    break;
                }
            }
            
            if (!$found) {
                throw new Exception('Playlist non trouvée');
            }
            
            // Enrichir avec les infos des médias
            foreach ($found['items'] as &$item) {
                $item['media_info'] = getMediaInfo($item['path']);
                $item['thumbnail'] = generateThumbnail($item['path']);
            }
            
            echo json_encode(['success' => true, 'playlist' => $found]);
            break;
            
        case 'create':
            // Créer une nouvelle playlist
            $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
            
            $name = trim($input['name'] ?? '');
            if (!validatePlaylistName($name)) {
                throw new Exception('Nom de playlist invalide');
            }
            
            $playlist = [
                'id' => uniqid('playlist_'),
                'name' => $name,
                'description' => trim($input['description'] ?? ''),
                'items' => [],
                'settings' => [
                    'loop' => $input['settings']['loop'] ?? true,
                    'shuffle' => $input['settings']['shuffle'] ?? false,
                    'default_image_duration' => intval($input['settings']['default_image_duration'] ?? 10),
                    'transition' => $input['settings']['transition'] ?? 'fade',
                    'transition_duration' => intval($input['settings']['transition_duration'] ?? 1000)
                ],
                'schedule' => null,
                'created' => date('c'),
                'modified' => date('c')
            ];
            
            $data['playlists'][] = $playlist;
            savePlaylists($data);
            
            echo json_encode(['success' => true, 'playlist' => $playlist]);
            break;
            
        case 'update':
            // Mettre à jour une playlist
            $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
            $id = $input['id'] ?? $_GET['id'] ?? '';
            
            $found = false;
            foreach ($data['playlists'] as &$playlist) {
                if ($playlist['id'] === $id) {
                    if (isset($input['name']) && !validatePlaylistName($input['name'])) {
                        throw new Exception('Nom de playlist invalide');
                    }
                    
                    // Mettre à jour les champs autorisés
                    if (isset($input['name'])) $playlist['name'] = trim($input['name']);
                    if (isset($input['description'])) $playlist['description'] = trim($input['description']);
                    if (isset($input['settings'])) $playlist['settings'] = array_merge($playlist['settings'], $input['settings']);
                    if (isset($input['items'])) $playlist['items'] = $input['items'];
                    
                    $playlist['modified'] = date('c');
                    $found = true;
                    break;
                }
            }
            
            if (!$found) {
                throw new Exception('Playlist non trouvée');
            }
            
            savePlaylists($data);
            echo json_encode(['success' => true]);
            break;
            
        case 'delete':
            // Supprimer une playlist
            $id = $_POST['id'] ?? $_GET['id'] ?? '';
            
            $initialCount = count($data['playlists']);
            $data['playlists'] = array_filter($data['playlists'], function($p) use ($id) {
                return $p['id'] !== $id;
            });
            $data['playlists'] = array_values($data['playlists']); // Réindexer
            
            if (count($data['playlists']) === $initialCount) {
                throw new Exception('Playlist non trouvée');
            }
            
            // Si c'était la playlist active, basculer sur default
            if (($data['active_playlist'] ?? '') === $id) {
                $data['active_playlist'] = 'default';
            }
            
            savePlaylists($data);
            echo json_encode(['success' => true]);
            break;
            
        case 'duplicate':
            // Dupliquer une playlist
            $id = $_POST['id'] ?? $_GET['id'] ?? '';
            $found = null;
            
            foreach ($data['playlists'] as $playlist) {
                if ($playlist['id'] === $id) {
                    $found = $playlist;
                    break;
                }
            }
            
            if (!$found) {
                throw new Exception('Playlist non trouvée');
            }
            
            $newPlaylist = $found;
            $newPlaylist['id'] = uniqid('playlist_');
            $newPlaylist['name'] = $found['name'] . ' (Copie)';
            $newPlaylist['created'] = date('c');
            $newPlaylist['modified'] = date('c');
            
            $data['playlists'][] = $newPlaylist;
            savePlaylists($data);
            
            echo json_encode(['success' => true, 'playlist' => $newPlaylist]);
            break;
            
        case 'reorder':
            // Réorganiser les éléments d'une playlist
            $input = json_decode(file_get_contents('php://input'), true);
            $id = $input['playlist_id'] ?? '';
            $fromIndex = intval($input['from_index'] ?? -1);
            $toIndex = intval($input['to_index'] ?? -1);
            
            if ($fromIndex < 0 || $toIndex < 0) {
                throw new Exception('Indices invalides');
            }
            
            foreach ($data['playlists'] as &$playlist) {
                if ($playlist['id'] === $id) {
                    if (!isset($playlist['items'][$fromIndex])) {
                        throw new Exception('Index source invalide');
                    }
                    
                    $item = array_splice($playlist['items'], $fromIndex, 1)[0];
                    array_splice($playlist['items'], $toIndex, 0, [$item]);
                    
                    $playlist['modified'] = date('c');
                    savePlaylists($data);
                    
                    echo json_encode(['success' => true]);
                    return;
                }
            }
            
            throw new Exception('Playlist non trouvée');
            break;
            
        case 'add-media':
            // Ajouter un média à une playlist
            $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
            $playlistId = $input['playlist_id'] ?? '';
            $mediaPath = basename($input['media_path'] ?? '');
            $duration = isset($input['duration']) ? intval($input['duration']) : null;
            $position = isset($input['position']) ? intval($input['position']) : null;
            
            if (!validateMediaPath($mediaPath)) {
                throw new Exception('Chemin média invalide');
            }
            
            $mediaInfo = getMediaInfo($mediaPath);
            if (!$mediaInfo) {
                throw new Exception('Média non trouvé');
            }
            
            $item = [
                'path' => $mediaPath,
                'type' => $mediaInfo['type'],
                'added' => date('c')
            ];
            
            // Gérer la durée pour les images
            if ($mediaInfo['type'] === 'image') {
                $item['duration'] = $duration ?? 10;
            }
            
            foreach ($data['playlists'] as &$playlist) {
                if ($playlist['id'] === $playlistId) {
                    if ($position !== null && $position >= 0 && $position <= count($playlist['items'])) {
                        array_splice($playlist['items'], $position, 0, [$item]);
                    } else {
                        $playlist['items'][] = $item;
                    }
                    
                    $playlist['modified'] = date('c');
                    savePlaylists($data);
                    
                    echo json_encode(['success' => true, 'item' => $item]);
                    return;
                }
            }
            
            throw new Exception('Playlist non trouvée');
            break;
            
        case 'remove-media':
            // Retirer un média d'une playlist
            $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
            $playlistId = $input['playlist_id'] ?? '';
            $index = intval($input['index'] ?? -1);
            
            if ($index < 0) {
                throw new Exception('Index invalide');
            }
            
            foreach ($data['playlists'] as &$playlist) {
                if ($playlist['id'] === $playlistId) {
                    if (!isset($playlist['items'][$index])) {
                        throw new Exception('Élément non trouvé');
                    }
                    
                    array_splice($playlist['items'], $index, 1);
                    $playlist['modified'] = date('c');
                    savePlaylists($data);
                    
                    echo json_encode(['success' => true]);
                    return;
                }
            }
            
            throw new Exception('Playlist non trouvée');
            break;
            
        case 'update-media':
            // Mettre à jour les propriétés d'un média dans une playlist
            $input = json_decode(file_get_contents('php://input'), true);
            $playlistId = $input['playlist_id'] ?? '';
            $index = intval($input['index'] ?? -1);
            $duration = isset($input['duration']) ? intval($input['duration']) : null;
            
            foreach ($data['playlists'] as &$playlist) {
                if ($playlist['id'] === $playlistId) {
                    if (!isset($playlist['items'][$index])) {
                        throw new Exception('Élément non trouvé');
                    }
                    
                    if ($duration !== null && $duration > 0 && $duration <= 300) {
                        $playlist['items'][$index]['duration'] = $duration;
                    }
                    
                    $playlist['modified'] = date('c');
                    savePlaylists($data);
                    
                    echo json_encode(['success' => true]);
                    return;
                }
            }
            
            throw new Exception('Playlist non trouvée');
            break;
            
        case 'get-media-library':
            // Obtenir la bibliothèque de médias avec infos détaillées
            $media = [];
            $extensions = ['mp4', 'avi', 'mkv', 'mov', 'webm', 'jpg', 'jpeg', 'png', 'gif', 'bmp'];
            
            foreach ($extensions as $ext) {
                foreach (glob($mediaDir . '*.' . $ext) as $file) {
                    $info = getMediaInfo(basename($file));
                    if ($info) {
                        $info['thumbnail'] = generateThumbnail(basename($file));
                        $media[] = $info;
                    }
                }
            }
            
            // Trier par nom
            usort($media, function($a, $b) {
                return strcasecmp($a['name'], $b['name']);
            });
            
            echo json_encode(['success' => true, 'media' => $media]);
            break;
            
        case 'export':
            // Exporter une playlist au format JSON
            $id = $_GET['id'] ?? '';
            $found = null;
            
            foreach ($data['playlists'] as $playlist) {
                if ($playlist['id'] === $id) {
                    $found = $playlist;
                    break;
                }
            }
            
            if (!$found) {
                throw new Exception('Playlist non trouvée');
            }
            
            header('Content-Disposition: attachment; filename="playlist_' . $found['name'] . '.json"');
            echo json_encode($found, JSON_PRETTY_PRINT);
            break;
            
        case 'import':
            // Importer une playlist depuis JSON
            if (!isset($_FILES['playlist_file'])) {
                throw new Exception('Fichier manquant');
            }
            
            $content = file_get_contents($_FILES['playlist_file']['tmp_name']);
            $playlist = json_decode($content, true);
            
            if (!$playlist || !isset($playlist['name'])) {
                throw new Exception('Format de fichier invalide');
            }
            
            // Assigner un nouvel ID
            $playlist['id'] = uniqid('playlist_');
            $playlist['name'] .= ' (Importé)';
            $playlist['created'] = date('c');
            $playlist['modified'] = date('c');
            
            $data['playlists'][] = $playlist;
            savePlaylists($data);
            
            echo json_encode(['success' => true, 'playlist' => $playlist]);
            break;
            
        case 'templates':
            // Obtenir les templates de playlist prédéfinis
            $templates = [
                [
                    'name' => 'Présentation d\'entreprise',
                    'description' => 'Images de l\'entreprise avec durée longue',
                    'settings' => [
                        'default_image_duration' => 30,
                        'loop' => true,
                        'shuffle' => false,
                        'transition' => 'fade'
                    ]
                ],
                [
                    'name' => 'Diaporama rapide',
                    'description' => 'Images avec transitions rapides',
                    'settings' => [
                        'default_image_duration' => 5,
                        'loop' => true,
                        'shuffle' => false,
                        'transition' => 'slide_left'
                    ]
                ],
                [
                    'name' => 'Contenu mixte',
                    'description' => 'Mélange vidéos et images',
                    'settings' => [
                        'default_image_duration' => 15,
                        'loop' => true,
                        'shuffle' => true,
                        'transition' => 'fade'
                    ]
                ]
            ];
            
            echo json_encode(['success' => true, 'templates' => $templates]);
            break;
            
        case 'statistics':
            // Obtenir des statistiques globales
            $totalPlaylists = count($data['playlists']);
            $totalMedia = count(glob($mediaDir . '*.{mp4,avi,mkv,mov,webm,jpg,jpeg,png,gif}', GLOB_BRACE));
            $totalSize = 0;
            
            foreach (glob($mediaDir . '*.*') as $file) {
                $totalSize += filesize($file);
            }
            
            $stats = [
                'total_playlists' => $totalPlaylists,
                'total_media_files' => $totalMedia,
                'total_storage_used' => formatBytes($totalSize),
                'active_playlist' => $data['active_playlist'] ?? 'default',
                'last_modified' => $data['metadata']['last_modified'] ?? 'N/A'
            ];
            
            echo json_encode(['success' => true, 'statistics' => $stats]);
            break;
            
        default:
            throw new Exception('Action non supportée');
    }
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>