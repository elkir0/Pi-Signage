<?php
/**
 * PiSignage Playlist API
 * Version: 3.1.0
 * Date: 2025-09-19
 * 
 * Description: API pour la gestion des playlists
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type');

// Configuration
define('PLAYLIST_FILE', '/opt/pisignage/config/playlists.json');
define('MEDIA_DIR', '/opt/pisignage/media/');
define('LOG_FILE', '/opt/pisignage/logs/playlist.log');

// Fonction de log
function writeLog($message) {
    $logDir = dirname(LOG_FILE);
    if (!file_exists($logDir)) {
        mkdir($logDir, 0755, true);
    }
    
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents(LOG_FILE, "[$timestamp] $message\n", FILE_APPEND | LOCK_EX);
}

// Fonction pour charger les playlists
function loadPlaylists() {
    if (!file_exists(PLAYLIST_FILE)) {
        return ['playlists' => [], 'active_playlist' => null];
    }
    
    $data = file_get_contents(PLAYLIST_FILE);
    $playlists = json_decode($data, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        writeLog("Erreur JSON lors du chargement: " . json_last_error_msg());
        return ['playlists' => [], 'active_playlist' => null];
    }
    
    return $playlists ?: ['playlists' => [], 'active_playlist' => null];
}

// Fonction pour sauvegarder les playlists
function savePlaylists($data) {
    $configDir = dirname(PLAYLIST_FILE);
    if (!file_exists($configDir)) {
        mkdir($configDir, 0755, true);
    }
    
    $json = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    if (json_last_error() !== JSON_ERROR_NONE) {
        writeLog("Erreur JSON lors de la sauvegarde: " . json_last_error_msg());
        return false;
    }
    
    return file_put_contents(PLAYLIST_FILE, $json, LOCK_EX) !== false;
}

// Fonction pour obtenir la liste des médias disponibles
function getAvailableMedia() {
    $media = [];
    
    if (is_dir(MEDIA_DIR)) {
        $extensions = ['mp4', 'avi', 'mkv', 'mov', 'webm', 'jpg', 'jpeg', 'png', 'gif'];
        $files = glob(MEDIA_DIR . '*.{' . implode(',', $extensions) . '}', GLOB_BRACE);
        
        foreach ($files as $file) {
            $filename = basename($file);
            $media[] = [
                'id' => md5($filename),
                'name' => $filename,
                'path' => $file,
                'type' => strpos(mime_content_type($file), 'video/') === 0 ? 'video' : 'image',
                'size' => filesize($file),
                'size_formatted' => formatBytes(filesize($file)),
                'duration' => getMediaDuration($file),
                'modified' => date('Y-m-d H:i:s', filemtime($file))
            ];
        }
    }
    
    return $media;
}

// Fonction pour formater la taille des fichiers
function formatBytes($bytes, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}

// Fonction pour obtenir la durée d'un média
function getMediaDuration($file) {
    if (!file_exists($file)) {
        return 0;
    }
    
    // Pour les images, durée par défaut de 5 secondes
    $mime = mime_content_type($file);
    if (strpos($mime, 'image/') === 0) {
        return 5;
    }
    
    // Pour les vidéos, utiliser ffprobe si disponible
    if (command_exists('ffprobe')) {
        $cmd = 'ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ' . escapeshellarg($file);
        $output = shell_exec($cmd);
        
        if ($output && is_numeric(trim($output))) {
            return (int)round(floatval(trim($output)));
        }
    }
    
    return 0; // Durée inconnue
}

// Fonction pour vérifier si une commande existe
function command_exists($cmd) {
    return shell_exec("which $cmd") !== null;
}

// Fonction pour valider une playlist
function validatePlaylist($playlist) {
    $errors = [];
    
    if (empty($playlist['name'])) {
        $errors[] = "Le nom de la playlist est requis";
    }
    
    if (!isset($playlist['items']) || !is_array($playlist['items'])) {
        $errors[] = "La playlist doit contenir un tableau d'éléments";
    }
    
    if (empty($playlist['items'])) {
        $errors[] = "La playlist ne peut pas être vide";
    }
    
    foreach ($playlist['items'] as $index => $item) {
        if (empty($item['media_id'])) {
            $errors[] = "L'élément $index doit avoir un media_id";
        }
        
        if (!isset($item['duration']) || !is_numeric($item['duration']) || $item['duration'] <= 0) {
            $errors[] = "L'élément $index doit avoir une durée valide";
        }
    }
    
    return $errors;
}

// Gestion des requêtes
$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true) ?: [];

try {
    switch ($method) {
        case 'GET':
            if (isset($_GET['action'])) {
                switch ($_GET['action']) {
                    case 'list':
                        $data = loadPlaylists();
                        writeLog("Liste des playlists demandée");
                        echo json_encode([
                            'success' => true,
                            'playlists' => $data['playlists'],
                            'active_playlist' => $data['active_playlist'],
                            'count' => count($data['playlists'])
                        ]);
                        break;
                        
                    case 'get':
                        $id = $_GET['id'] ?? '';
                        if (empty($id)) {
                            throw new Exception("ID de playlist requis");
                        }
                        
                        $data = loadPlaylists();
                        $playlist = null;
                        
                        foreach ($data['playlists'] as $p) {
                            if ($p['id'] === $id) {
                                $playlist = $p;
                                break;
                            }
                        }
                        
                        if (!$playlist) {
                            throw new Exception("Playlist introuvable");
                        }
                        
                        writeLog("Playlist récupérée: {$playlist['name']}");
                        echo json_encode([
                            'success' => true,
                            'playlist' => $playlist
                        ]);
                        break;
                        
                    case 'media':
                        $media = getAvailableMedia();
                        writeLog("Liste des médias demandée (" . count($media) . " fichiers)");
                        echo json_encode([
                            'success' => true,
                            'media' => $media,
                            'count' => count($media)
                        ]);
                        break;
                        
                    case 'active':
                        $data = loadPlaylists();
                        $activePlaylist = null;
                        
                        if ($data['active_playlist']) {
                            foreach ($data['playlists'] as $p) {
                                if ($p['id'] === $data['active_playlist']) {
                                    $activePlaylist = $p;
                                    break;
                                }
                            }
                        }
                        
                        echo json_encode([
                            'success' => true,
                            'active_playlist' => $activePlaylist,
                            'active_playlist_id' => $data['active_playlist']
                        ]);
                        break;
                        
                    default:
                        throw new Exception("Action non supportée: " . $_GET['action']);
                }
            } else {
                // Retourner toutes les informations par défaut
                $data = loadPlaylists();
                $media = getAvailableMedia();
                
                echo json_encode([
                    'success' => true,
                    'playlists' => $data['playlists'],
                    'active_playlist' => $data['active_playlist'],
                    'media' => $media,
                    'stats' => [
                        'playlists_count' => count($data['playlists']),
                        'media_count' => count($media),
                        'total_duration' => array_sum(array_column($media, 'duration'))
                    ]
                ]);
            }
            break;
            
        case 'POST':
            // Créer une nouvelle playlist
            if (empty($input['name'])) {
                throw new Exception("Le nom de la playlist est requis");
            }
            
            $playlist = [
                'id' => uniqid('playlist_'),
                'name' => trim($input['name']),
                'description' => trim($input['description'] ?? ''),
                'items' => $input['items'] ?? [],
                'settings' => [
                    'loop' => $input['settings']['loop'] ?? true,
                    'shuffle' => $input['settings']['shuffle'] ?? false,
                    'transition' => $input['settings']['transition'] ?? 'fade',
                    'transition_duration' => $input['settings']['transition_duration'] ?? 1000
                ],
                'schedule' => $input['schedule'] ?? null,
                'created' => date('Y-m-d H:i:s'),
                'modified' => date('Y-m-d H:i:s')
            ];
            
            // Validation
            $errors = validatePlaylist($playlist);
            if (!empty($errors)) {
                throw new Exception("Erreurs de validation: " . implode(', ', $errors));
            }
            
            // Charger les données existantes
            $data = loadPlaylists();
            
            // Vérifier l'unicité du nom
            foreach ($data['playlists'] as $existing) {
                if (strtolower($existing['name']) === strtolower($playlist['name'])) {
                    throw new Exception("Une playlist avec ce nom existe déjà");
                }
            }
            
            // Ajouter la playlist
            $data['playlists'][] = $playlist;
            
            // Sauvegarder
            if (!savePlaylists($data)) {
                throw new Exception("Impossible de sauvegarder la playlist");
            }
            
            writeLog("Playlist créée: {$playlist['name']} (ID: {$playlist['id']})");
            echo json_encode([
                'success' => true,
                'message' => 'Playlist créée avec succès',
                'playlist' => $playlist
            ]);
            break;
            
        case 'PUT':
            // Mettre à jour une playlist existante
            $id = $_GET['id'] ?? $input['id'] ?? '';
            if (empty($id)) {
                throw new Exception("ID de playlist requis");
            }
            
            $data = loadPlaylists();
            $playlistIndex = -1;
            
            foreach ($data['playlists'] as $index => $p) {
                if ($p['id'] === $id) {
                    $playlistIndex = $index;
                    break;
                }
            }
            
            if ($playlistIndex === -1) {
                throw new Exception("Playlist introuvable");
            }
            
            // Actions spéciales
            if (isset($_GET['action'])) {
                switch ($_GET['action']) {
                    case 'activate':
                        $data['active_playlist'] = $id;
                        if (!savePlaylists($data)) {
                            throw new Exception("Impossible d'activer la playlist");
                        }
                        
                        writeLog("Playlist activée: {$data['playlists'][$playlistIndex]['name']}");
                        echo json_encode([
                            'success' => true,
                            'message' => 'Playlist activée avec succès',
                            'active_playlist' => $id
                        ]);
                        break;
                        
                    case 'deactivate':
                        $data['active_playlist'] = null;
                        if (!savePlaylists($data)) {
                            throw new Exception("Impossible de désactiver la playlist");
                        }
                        
                        writeLog("Playlist désactivée");
                        echo json_encode([
                            'success' => true,
                            'message' => 'Playlist désactivée',
                            'active_playlist' => null
                        ]);
                        break;
                        
                    default:
                        throw new Exception("Action non supportée: " . $_GET['action']);
                }
            } else {
                // Mise à jour normale
                $playlist = $data['playlists'][$playlistIndex];
                
                // Mettre à jour les champs modifiables
                if (isset($input['name'])) $playlist['name'] = trim($input['name']);
                if (isset($input['description'])) $playlist['description'] = trim($input['description']);
                if (isset($input['items'])) $playlist['items'] = $input['items'];
                if (isset($input['settings'])) $playlist['settings'] = array_merge($playlist['settings'], $input['settings']);
                if (isset($input['schedule'])) $playlist['schedule'] = $input['schedule'];
                
                $playlist['modified'] = date('Y-m-d H:i:s');
                
                // Validation
                $errors = validatePlaylist($playlist);
                if (!empty($errors)) {
                    throw new Exception("Erreurs de validation: " . implode(', ', $errors));
                }
                
                // Sauvegarder
                $data['playlists'][$playlistIndex] = $playlist;
                
                if (!savePlaylists($data)) {
                    throw new Exception("Impossible de sauvegarder les modifications");
                }
                
                writeLog("Playlist modifiée: {$playlist['name']}");
                echo json_encode([
                    'success' => true,
                    'message' => 'Playlist mise à jour avec succès',
                    'playlist' => $playlist
                ]);
            }
            break;
            
        case 'DELETE':
            $id = $_GET['id'] ?? '';
            if (empty($id)) {
                throw new Exception("ID de playlist requis");
            }
            
            $data = loadPlaylists();
            $playlistIndex = -1;
            $playlistName = '';
            
            foreach ($data['playlists'] as $index => $p) {
                if ($p['id'] === $id) {
                    $playlistIndex = $index;
                    $playlistName = $p['name'];
                    break;
                }
            }
            
            if ($playlistIndex === -1) {
                throw new Exception("Playlist introuvable");
            }
            
            // Si c'est la playlist active, la désactiver
            if ($data['active_playlist'] === $id) {
                $data['active_playlist'] = null;
            }
            
            // Supprimer la playlist
            array_splice($data['playlists'], $playlistIndex, 1);
            
            if (!savePlaylists($data)) {
                throw new Exception("Impossible de supprimer la playlist");
            }
            
            writeLog("Playlist supprimée: $playlistName (ID: $id)");
            echo json_encode([
                'success' => true,
                'message' => 'Playlist supprimée avec succès',
                'deleted_id' => $id
            ]);
            break;
            
        default:
            throw new Exception("Méthode HTTP non supportée: $method");
    }
    
} catch (Exception $e) {
    http_response_code(400);
    writeLog("Erreur API: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}
?>