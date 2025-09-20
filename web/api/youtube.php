<?php
/**
 * PiSignage YouTube API
 * Version: 3.1.0
 * Date: 2025-09-19
 * 
 * Description: API pour le téléchargement de vidéos YouTube
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST');
header('Access-Control-Allow-Headers: Content-Type');

// Configuration
define('MEDIA_DIR', '/opt/pisignage/media/');
define('LOG_FILE', '/opt/pisignage/logs/youtube.log');
define('PROGRESS_FILE', '/tmp/pisignage_youtube_progress.json');
define('YOUTUBE_SCRIPT', '/opt/pisignage/scripts/youtube-dl.sh');
define('MAX_CONCURRENT_DOWNLOADS', 2);
define('DOWNLOAD_QUEUE_FILE', '/tmp/pisignage_youtube_queue.json');

// Fonction de log
function writeLog($message) {
    $logDir = dirname(LOG_FILE);
    if (!file_exists($logDir)) {
        mkdir($logDir, 0755, true);
    }
    
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents(LOG_FILE, "[$timestamp] $message\n", FILE_APPEND | LOCK_EX);
}

// Fonction pour valider une URL YouTube
function isValidYouTubeUrl($url) {
    $pattern = '/^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be)\/.+/';
    return preg_match($pattern, $url);
}

// Fonction pour extraire l'ID de la vidéo YouTube
function extractYouTubeId($url) {
    $patterns = [
        '/[?&]v=([^&]+)/',  // youtube.com/watch?v=ID
        '/youtu\.be\/([^?]+)/', // youtu.be/ID
        '/embed\/([^?]+)/'   // youtube.com/embed/ID
    ];
    
    foreach ($patterns as $pattern) {
        if (preg_match($pattern, $url, $matches)) {
            return $matches[1];
        }
    }
    
    return null;
}

// Fonction pour obtenir les informations d'une vidéo YouTube
function getYouTubeVideoInfo($url) {
    if (!command_exists('yt-dlp')) {
        throw new Exception('yt-dlp n\'est pas installé');
    }
    
    $cmd = 'yt-dlp --no-download --print-json ' . escapeshellarg($url) . ' 2>/dev/null';
    $output = shell_exec($cmd);
    
    if (!$output) {
        throw new Exception('Impossible d\'obtenir les informations de la vidéo');
    }
    
    $info = json_decode($output, true);
    if (!$info) {
        throw new Exception('Erreur lors du parsing des informations vidéo');
    }
    
    return [
        'id' => $info['id'] ?? '',
        'title' => $info['title'] ?? 'Titre inconnu',
        'uploader' => $info['uploader'] ?? 'Auteur inconnu',
        'duration' => $info['duration'] ?? 0,
        'duration_formatted' => gmdate('H:i:s', $info['duration'] ?? 0),
        'description' => substr($info['description'] ?? '', 0, 200),
        'thumbnail' => $info['thumbnail'] ?? '',
        'upload_date' => $info['upload_date'] ?? '',
        'view_count' => $info['view_count'] ?? 0,
        'like_count' => $info['like_count'] ?? 0,
        'available_formats' => getAvailableFormats($info['formats'] ?? [])
    ];
}

// Fonction pour obtenir les formats disponibles
function getAvailableFormats($formats) {
    $qualityMap = [
        'best' => ['label' => 'Meilleure qualité', 'desc' => 'La plus haute qualité disponible'],
        '720p' => ['label' => 'HD 720p', 'desc' => 'Haute définition (recommandé)'],
        '480p' => ['label' => 'SD 480p', 'desc' => 'Définition standard'],
        '360p' => ['label' => 'SD 360p', 'desc' => 'Économie d\'espace'],
        'worst' => ['label' => 'Plus faible qualité', 'desc' => 'Minimal pour tests']
    ];
    
    $available = [];
    foreach ($qualityMap as $key => $info) {
        $available[] = [
            'value' => $key,
            'label' => $info['label'],
            'description' => $info['desc']
        ];
    }
    
    return $available;
}

// Fonction pour charger la file d'attente
function loadDownloadQueue() {
    if (!file_exists(DOWNLOAD_QUEUE_FILE)) {
        return [];
    }
    
    $data = file_get_contents(DOWNLOAD_QUEUE_FILE);
    $queue = json_decode($data, true);
    
    return $queue ?: [];
}

// Fonction pour sauvegarder la file d'attente
function saveDownloadQueue($queue) {
    $json = json_encode($queue, JSON_PRETTY_PRINT);
    return file_put_contents(DOWNLOAD_QUEUE_FILE, $json, LOCK_EX) !== false;
}

// Fonction pour obtenir le statut des téléchargements
function getDownloadStatus() {
    $queue = loadDownloadQueue();
    $activeDownloads = 0;
    
    foreach ($queue as &$item) {
        if ($item['status'] === 'downloading') {
            // Vérifier si le processus est toujours actif
            if (isset($item['pid'])) {
                $output = shell_exec("ps -p {$item['pid']} 2>/dev/null");
                if (!$output || strpos($output, (string)$item['pid']) === false) {
                    // Processus terminé, vérifier si c'est un succès ou un échec
                    $logFile = "/tmp/youtube_dl_{$item['id']}.log";
                    if (file_exists($logFile)) {
                        $logContent = file_get_contents($logFile);
                        // Chercher un fichier de sortie dans les logs
                        if (preg_match('/\/opt\/pisignage\/media\/[^\s]+\.mp4/', $logContent, $matches)) {
                            $outputFile = $matches[0];
                            if (file_exists($outputFile)) {
                                $item['status'] = 'completed';
                                $item['progress'] = 100;
                                $item['message'] = 'Téléchargement terminé';
                                $item['output_file'] = basename($outputFile);
                            } else {
                                $item['status'] = 'failed';
                                $item['error'] = 'Fichier de sortie introuvable';
                            }
                        } else {
                            $item['status'] = 'failed';
                            $item['error'] = 'Téléchargement échoué';
                        }
                    } else {
                        $item['status'] = 'failed';
                        $item['error'] = 'Processus interrompu sans log';
                    }
                    $item['finished_at'] = date('Y-m-d H:i:s');
                }
            }
        }
        
        if ($item['status'] === 'downloading') {
            $activeDownloads++;
        }
    }
    
    saveDownloadQueue($queue);
    
    return [
        'queue' => $queue,
        'active_downloads' => $activeDownloads,
        'max_concurrent' => MAX_CONCURRENT_DOWNLOADS,
        'can_start_new' => $activeDownloads < MAX_CONCURRENT_DOWNLOADS
    ];
}

// Fonction pour démarrer un téléchargement
function startDownload($url, $quality = '720p', $customName = null) {
    $queue = loadDownloadQueue();
    $status = getDownloadStatus();
    
    if (!$status['can_start_new']) {
        throw new Exception('Limite de téléchargements simultanés atteinte');
    }
    
    // Vérifier si cette vidéo n'est pas déjà en cours de téléchargement
    $videoId = extractYouTubeId($url);
    foreach ($queue as $item) {
        if ($item['video_id'] === $videoId && in_array($item['status'], ['pending', 'downloading'])) {
            throw new Exception('Cette vidéo est déjà en cours de téléchargement');
        }
    }
    
    $downloadId = uniqid('dl_');
    $downloadItem = [
        'id' => $downloadId,
        'url' => $url,
        'video_id' => $videoId,
        'quality' => $quality,
        'custom_name' => $customName,
        'status' => 'pending',
        'progress' => 0,
        'message' => 'En attente...',
        'created_at' => date('Y-m-d H:i:s'),
        'started_at' => null,
        'finished_at' => null,
        'pid' => null,
        'output_file' => null,
        'error' => null
    ];
    
    $queue[] = $downloadItem;
    saveDownloadQueue($queue);
    
    // Démarrer le téléchargement directement en arrière-plan
    $scriptCmd = YOUTUBE_SCRIPT . ' ' . escapeshellarg($url) . ' ' . escapeshellarg($quality);
    if ($customName) {
        $scriptCmd .= ' ' . escapeshellarg($customName);
    }
    
    // Exécuter en arrière-plan avec redirection vers un fichier log spécifique
    $logFile = "/tmp/youtube_dl_{$downloadId}.log";
    $cmd = "nohup $scriptCmd > $logFile 2>&1 & echo $!";
    $pid = trim(shell_exec($cmd));
    
    if (!empty($pid) && is_numeric($pid)) {
        // Mettre à jour le statut
        foreach ($queue as &$item) {
            if ($item['id'] === $downloadId) {
                $item['status'] = 'downloading';
                $item['started_at'] = date('Y-m-d H:i:s');
                $item['pid'] = intval($pid);
                break;
            }
        }
        saveDownloadQueue($queue);
        writeLog("Téléchargement démarré: $url (ID: $downloadId, PID: $pid)");
    } else {
        throw new Exception('Échec du démarrage du téléchargement');
    }
    
    return $downloadId;
}

// Fonction pour obtenir le progrès d'un téléchargement
function getDownloadProgress($downloadId) {
    // Lire le fichier de progression si disponible
    $progressData = null;
    if (file_exists(PROGRESS_FILE)) {
        $data = file_get_contents(PROGRESS_FILE);
        $progressData = json_decode($data, true);
    }
    
    $queue = loadDownloadQueue();
    $downloadItem = null;
    
    foreach ($queue as &$item) {
        if ($item['id'] === $downloadId) {
            $downloadItem = &$item;
            break;
        }
    }
    
    if (!$downloadItem) {
        throw new Exception('Téléchargement introuvable');
    }
    
    // Mettre à jour avec les données de progression si disponibles
    if ($progressData && $downloadItem['status'] === 'downloading') {
        $downloadItem['progress'] = intval($progressData['percent'] ?? 0);
        $downloadItem['message'] = $progressData['message'] ?? 'Téléchargement en cours...';
        $downloadItem['eta'] = $progressData['eta'] ?? '';
    }
    
    // Vérifier si le téléchargement est terminé
    if ($downloadItem['status'] === 'downloading' && $downloadItem['pid']) {
        $output = shell_exec("ps -p {$downloadItem['pid']} 2>/dev/null");
        if (!$output || strpos($output, $downloadItem['pid']) === false) {
            // Le processus est terminé, vérifier le résultat
            $logFile = "/tmp/youtube_dl_{$downloadId}.log";
            if (file_exists($logFile)) {
                $logContent = file_get_contents($logFile);
                
                // Rechercher le fichier de sortie dans les logs
                if (preg_match('/^\/opt\/pisignage\/media\/.+\.mp4$/m', $logContent, $matches)) {
                    $downloadItem['status'] = 'completed';
                    $downloadItem['progress'] = 100;
                    $downloadItem['message'] = 'Téléchargement terminé';
                    $downloadItem['finished_at'] = date('Y-m-d H:i:s');
                    $downloadItem['output_file'] = basename($matches[0]);
                } else {
                    $downloadItem['status'] = 'failed';
                    $downloadItem['error'] = 'Téléchargement échoué';
                    $downloadItem['finished_at'] = date('Y-m-d H:i:s');
                }
            } else {
                $downloadItem['status'] = 'failed';
                $downloadItem['error'] = 'Log de téléchargement introuvable';
                $downloadItem['finished_at'] = date('Y-m-d H:i:s');
            }
        }
    }
    
    saveDownloadQueue($queue);
    
    return $downloadItem;
}

// Fonction pour vérifier si une commande existe
function command_exists($cmd) {
    return shell_exec("which $cmd") !== null;
}

// Gestion des requêtes
$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true) ?: [];

try {
    switch ($method) {
        case 'GET':
            if (isset($_GET['action'])) {
                switch ($_GET['action']) {
                    case 'info':
                        $url = $_GET['url'] ?? '';
                        if (empty($url)) {
                            throw new Exception('URL requise');
                        }
                        
                        if (!isValidYouTubeUrl($url)) {
                            throw new Exception('URL YouTube invalide');
                        }
                        
                        $info = getYouTubeVideoInfo($url);
                        writeLog("Informations récupérées pour: " . $info['title']);
                        
                        echo json_encode([
                            'success' => true,
                            'info' => $info
                        ]);
                        break;
                        
                    case 'status':
                        $status = getDownloadStatus();
                        echo json_encode([
                            'success' => true,
                            'downloads' => $status
                        ]);
                        break;
                        
                    case 'queue':
                        $status = getDownloadStatus();
                        echo json_encode([
                            'success' => true,
                            'queue' => $status['queue'] ?? [],
                            'active' => $status['active_downloads'] ?? 0,
                            'max' => $status['max_concurrent'] ?? MAX_CONCURRENT_DOWNLOADS
                        ]);
                        break;
                        
                    case 'progress':
                        $downloadId = $_GET['id'] ?? '';
                        if (empty($downloadId)) {
                            throw new Exception('ID de téléchargement requis');
                        }
                        
                        $progress = getDownloadProgress($downloadId);
                        echo json_encode([
                            'success' => true,
                            'download' => $progress
                        ]);
                        break;
                        
                    case 'requirements':
                        $requirements = [
                            'yt-dlp' => command_exists('yt-dlp'),
                            'ffmpeg' => command_exists('ffmpeg'),
                            'script_exists' => file_exists(YOUTUBE_SCRIPT),
                            'script_executable' => file_exists(YOUTUBE_SCRIPT) && is_executable(YOUTUBE_SCRIPT),
                            'media_dir_writable' => is_writable(MEDIA_DIR)
                        ];
                        
                        $allOk = array_reduce($requirements, function($carry, $item) {
                            return $carry && $item;
                        }, true);
                        
                        echo json_encode([
                            'success' => true,
                            'requirements' => $requirements,
                            'ready' => $allOk
                        ]);
                        break;
                        
                    default:
                        throw new Exception('Action non supportée: ' . $_GET['action']);
                }
            } else {
                // État global par défaut
                $status = getDownloadStatus();
                echo json_encode([
                    'success' => true,
                    'status' => 'ready',
                    'downloads' => $status
                ]);
            }
            break;
            
        case 'POST':
            if (isset($_GET['action'])) {
                switch ($_GET['action']) {
                    case 'download':
                        $url = $input['url'] ?? '';
                        $quality = $input['quality'] ?? '720p';
                        $customName = $input['name'] ?? null;
                        
                        if (empty($url)) {
                            throw new Exception('URL requise');
                        }
                        
                        if (!isValidYouTubeUrl($url)) {
                            throw new Exception('URL YouTube invalide');
                        }
                        
                        // Vérifier les prérequis
                        if (!command_exists('yt-dlp')) {
                            throw new Exception('yt-dlp n\'est pas installé');
                        }
                        
                        if (!file_exists(YOUTUBE_SCRIPT) || !is_executable(YOUTUBE_SCRIPT)) {
                            throw new Exception('Script de téléchargement indisponible');
                        }
                        
                        $downloadId = startDownload($url, $quality, $customName);
                        
                        echo json_encode([
                            'success' => true,
                            'message' => 'Téléchargement démarré',
                            'download_id' => $downloadId
                        ]);
                        break;
                        
                    case 'cancel':
                        $downloadId = $input['id'] ?? '';
                        if (empty($downloadId)) {
                            throw new Exception('ID de téléchargement requis');
                        }
                        
                        $queue = loadDownloadQueue();
                        $found = false;
                        
                        foreach ($queue as &$item) {
                            if ($item['id'] === $downloadId) {
                                if ($item['status'] === 'downloading' && isset($item['pid'])) {
                                    // Tuer le processus
                                    shell_exec("kill {$item['pid']} 2>/dev/null");
                                    $item['status'] = 'cancelled';
                                    $item['finished_at'] = date('Y-m-d H:i:s');
                                    $item['error'] = 'Annulé par l\'utilisateur';
                                } else if ($item['status'] === 'pending') {
                                    $item['status'] = 'cancelled';
                                    $item['finished_at'] = date('Y-m-d H:i:s');
                                    $item['error'] = 'Annulé avant démarrage';
                                }
                                $found = true;
                                break;
                            }
                        }
                        
                        if (!$found) {
                            throw new Exception('Téléchargement introuvable');
                        }
                        
                        saveDownloadQueue($queue);
                        writeLog("Téléchargement annulé: $downloadId");
                        
                        echo json_encode([
                            'success' => true,
                            'message' => 'Téléchargement annulé'
                        ]);
                        break;
                        
                    case 'clear':
                        $queue = loadDownloadQueue();
                        $queue = array_filter($queue, function($item) {
                            return in_array($item['status'], ['pending', 'downloading']);
                        });
                        
                        saveDownloadQueue(array_values($queue));
                        
                        echo json_encode([
                            'success' => true,
                            'message' => 'Historique nettoyé'
                        ]);
                        break;
                        
                    default:
                        throw new Exception('Action non supportée: ' . $_GET['action']);
                }
            } else {
                throw new Exception('Action requise');
            }
            break;
            
        default:
            throw new Exception('Méthode HTTP non supportée: ' . $method);
    }
    
} catch (Exception $e) {
    http_response_code(400);
    writeLog("Erreur YouTube API: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}
?>