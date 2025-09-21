<?php
/**
 * PiSignage YouTube API Enhanced
 * Version: 4.0.0
 * Date: 2025-09-21
 * 
 * Description: API améliorée pour le téléchargement de vidéos YouTube
 * Avec monitoring temps réel et système de queue robuste
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Configuration
define('MEDIA_DIR', '/opt/pisignage/media/');
define('LOG_FILE', '/opt/pisignage/logs/youtube-enhanced.log');
define('QUEUE_FILE', '/tmp/pisignage_youtube_enhanced_queue.json');
define('PROGRESS_DIR', '/tmp/pisignage_youtube_progress/');
define('YOUTUBE_SCRIPT', '/opt/pisignage/scripts/youtube-dl.sh');
define('MAX_CONCURRENT_DOWNLOADS', 3);
define('DOWNLOAD_TIMEOUT', 1800); // 30 minutes

// Créer les dossiers nécessaires
if (!file_exists(PROGRESS_DIR)) {
    mkdir(PROGRESS_DIR, 0755, true);
}
if (!file_exists(dirname(LOG_FILE))) {
    mkdir(dirname(LOG_FILE), 0755, true);
}

// Fonction de log
function writeLog($message) {
    $timestamp = date('Y-m-d H:i:s');
    $logMessage = "[$timestamp] $message\n";
    file_put_contents(LOG_FILE, $logMessage, FILE_APPEND | LOCK_EX);
    
    // Log debug aussi dans un fichier séparé pour le développement
    error_log($logMessage, 3, '/tmp/youtube-debug.log');
}

// Fonction pour générer un ID unique
function generateDownloadId() {
    return 'dl_' . date('Ymd_His') . '_' . uniqid();
}

// Fonction pour valider une URL YouTube
function isValidYouTubeUrl($url) {
    $patterns = [
        '/^(https?:\/\/)?(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/).+/',
        '/^(https?:\/\/)?(m\.)?youtube\.com\/watch\?v=.+/',
        '/^(https?:\/\/)?youtube\.com\/v\/.+/',
    ];
    
    foreach ($patterns as $pattern) {
        if (preg_match($pattern, $url)) {
            return true;
        }
    }
    return false;
}

// Fonction pour extraire l'ID de la vidéo YouTube
function extractYouTubeId($url) {
    $patterns = [
        '/[?&]v=([^&]+)/',      // youtube.com/watch?v=ID
        '/youtu\.be\/([^?]+)/', // youtu.be/ID
        '/embed\/([^?]+)/',     // youtube.com/embed/ID
        '/\/v\/([^?]+)/'        // youtube.com/v/ID
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
    
    // Formatage sécurisé des données
    return [
        'id' => $info['id'] ?? '',
        'title' => htmlspecialchars($info['title'] ?? 'Titre inconnu', ENT_QUOTES, 'UTF-8'),
        'uploader' => htmlspecialchars($info['uploader'] ?? 'Auteur inconnu', ENT_QUOTES, 'UTF-8'),
        'duration' => intval($info['duration'] ?? 0),
        'duration_formatted' => gmdate('H:i:s', intval($info['duration'] ?? 0)),
        'description' => htmlspecialchars(substr($info['description'] ?? '', 0, 300), ENT_QUOTES, 'UTF-8'),
        'thumbnail' => $info['thumbnail'] ?? '',
        'upload_date' => $info['upload_date'] ?? '',
        'view_count' => intval($info['view_count'] ?? 0),
        'like_count' => intval($info['like_count'] ?? 0),
        'webpage_url' => $info['webpage_url'] ?? $url,
        'available_qualities' => getAvailableQualities()
    ];
}

// Fonction pour obtenir les qualités disponibles
function getAvailableQualities() {
    return [
        ['value' => 'best', 'label' => 'Meilleure qualité', 'description' => 'La plus haute qualité disponible'],
        ['value' => '1080p', 'label' => 'Full HD 1080p', 'description' => 'Très haute définition'],
        ['value' => '720p', 'label' => 'HD 720p', 'description' => 'Haute définition (recommandé)'],
        ['value' => '480p', 'label' => 'SD 480p', 'description' => 'Définition standard'],
        ['value' => '360p', 'label' => 'SD 360p', 'description' => 'Économie d\'espace'],
        ['value' => 'worst', 'label' => 'Plus faible qualité', 'description' => 'Minimal pour tests']
    ];
}

// Fonction pour charger la file d'attente
function loadDownloadQueue() {
    if (!file_exists(QUEUE_FILE)) {
        return [];
    }
    
    $data = file_get_contents(QUEUE_FILE);
    $queue = json_decode($data, true);
    
    return is_array($queue) ? $queue : [];
}

// Fonction pour sauvegarder la file d'attente
function saveDownloadQueue($queue) {
    $json = json_encode($queue, JSON_PRETTY_PRINT);
    return file_put_contents(QUEUE_FILE, $json, LOCK_EX) !== false;
}

// Fonction pour lire le fichier de progression d'un téléchargement
function getDownloadProgress($downloadId) {
    $progressFile = PROGRESS_DIR . $downloadId . '.json';
    
    if (!file_exists($progressFile)) {
        return [
            'percent' => 0,
            'status' => 'unknown',
            'message' => 'Aucune progression disponible',
            'eta' => '',
            'speed' => '',
            'timestamp' => date('Y-m-d H:i:s')
        ];
    }
    
    $data = file_get_contents($progressFile);
    $progress = json_decode($data, true);
    
    return $progress ?: [
        'percent' => 0,
        'status' => 'error',
        'message' => 'Erreur de lecture de progression',
        'eta' => '',
        'speed' => '',
        'timestamp' => date('Y-m-d H:i:s')
    ];
}

// Fonction pour mettre à jour le statut des téléchargements
function updateDownloadStatuses() {
    $queue = loadDownloadQueue();
    $updated = false;
    
    foreach ($queue as &$item) {
        if ($item['status'] === 'downloading') {
            $now = time();
            $startTime = strtotime($item['started_at']);
            
            // Vérifier timeout
            if ($now - $startTime > DOWNLOAD_TIMEOUT) {
                $item['status'] = 'timeout';
                $item['error'] = 'Timeout après ' . DOWNLOAD_TIMEOUT . ' secondes';
                $item['finished_at'] = date('Y-m-d H:i:s');
                $updated = true;
                continue;
            }
            
            // Vérifier si le processus est toujours actif
            if (isset($item['pid'])) {
                $pidCheck = shell_exec("ps -p {$item['pid']} >/dev/null 2>&1 && echo 'running' || echo 'stopped'");
                
                if (trim($pidCheck) === 'stopped') {
                    // Processus terminé, vérifier le résultat
                    $logFile = "/tmp/youtube_download_{$item['id']}.log";
                    $outputFile = null;
                    
                    // Chercher le fichier de sortie dans les logs
                    if (file_exists($logFile)) {
                        $logContent = file_get_contents($logFile);
                        if (preg_match('/✅ Vidéo prête: ([^\s]+)/', $logContent, $matches)) {
                            $outputFile = $matches[1];
                        }
                    }
                    
                    if ($outputFile && file_exists($outputFile)) {
                        $item['status'] = 'completed';
                        $item['progress'] = 100;
                        $item['message'] = 'Téléchargement terminé avec succès';
                        $item['output_file'] = basename($outputFile);
                        $item['file_size'] = formatFileSize(filesize($outputFile));
                    } else {
                        $item['status'] = 'failed';
                        $item['error'] = 'Téléchargement échoué ou fichier introuvable';
                    }
                    
                    $item['finished_at'] = date('Y-m-d H:i:s');
                    $updated = true;
                }
            }
            
            // Mettre à jour la progression en temps réel
            $progress = getDownloadProgress($item['id']);
            if ($progress['percent'] > $item['progress']) {
                $item['progress'] = $progress['percent'];
                $item['message'] = $progress['message'];
                $item['eta'] = $progress['eta'] ?? '';
                $item['speed'] = $progress['speed'] ?? '';
                $updated = true;
            }
        }
    }
    
    if ($updated) {
        saveDownloadQueue($queue);
    }
    
    return $queue;
}

// Fonction pour démarrer un téléchargement
function startDownload($url, $quality = '720p', $customName = null) {
    $queue = updateDownloadStatuses();
    
    // Compter les téléchargements actifs
    $activeDownloads = array_filter($queue, function($item) {
        return $item['status'] === 'downloading';
    });
    
    if (count($activeDownloads) >= MAX_CONCURRENT_DOWNLOADS) {
        throw new Exception('Limite de téléchargements simultanés atteinte (' . MAX_CONCURRENT_DOWNLOADS . ')');
    }
    
    // Vérifier si cette vidéo n'est pas déjà en cours
    $videoId = extractYouTubeId($url);
    foreach ($queue as $item) {
        if ($item['video_id'] === $videoId && in_array($item['status'], ['pending', 'downloading'])) {
            throw new Exception('Cette vidéo est déjà en cours de téléchargement');
        }
    }
    
    // Obtenir les infos de la vidéo
    try {
        $videoInfo = getYouTubeVideoInfo($url);
    } catch (Exception $e) {
        throw new Exception('Impossible d\'analyser la vidéo: ' . $e->getMessage());
    }
    
    $downloadId = generateDownloadId();
    
    // Créer l'entrée dans la queue
    $downloadItem = [
        'id' => $downloadId,
        'url' => $url,
        'video_id' => $videoId,
        'video_title' => $videoInfo['title'],
        'video_duration' => $videoInfo['duration'],
        'quality' => $quality,
        'custom_name' => $customName,
        'status' => 'pending',
        'progress' => 0,
        'message' => 'Initialisation...',
        'eta' => '',
        'speed' => '',
        'created_at' => date('Y-m-d H:i:s'),
        'started_at' => null,
        'finished_at' => null,
        'pid' => null,
        'output_file' => null,
        'file_size' => null,
        'error' => null
    ];
    
    $queue[] = $downloadItem;
    saveDownloadQueue($queue);
    
    // Préparer la commande de téléchargement avec le script corrigé
    $scriptCmd = '/opt/pisignage/scripts/youtube-dl-fixed.sh ' . escapeshellarg($url) . ' ' . escapeshellarg($quality);
    if ($customName) {
        $scriptCmd .= ' ' . escapeshellarg($customName);
    }
    
    // Créer un fichier de log spécifique
    $logFile = "/tmp/youtube_download_{$downloadId}.log";
    $progressFile = PROGRESS_DIR . $downloadId . '.json';
    
    // Exporter les variables d'environnement pour le script
    $envCmd = "export PROGRESS_FILE='$progressFile'; ";
    $envCmd .= "export DOWNLOAD_ID='$downloadId'; ";
    
    // Commande complète avec redirection des logs
    $fullCmd = $envCmd . $scriptCmd . " > $logFile 2>&1 & echo \$!";
    
    writeLog("Commande de téléchargement: $fullCmd");
    
    // Démarrer le processus en arrière-plan
    $pid = trim(shell_exec($fullCmd));
    
    if (!empty($pid) && is_numeric($pid)) {
        // Mettre à jour le statut
        foreach ($queue as &$item) {
            if ($item['id'] === $downloadId) {
                $item['status'] = 'downloading';
                $item['started_at'] = date('Y-m-d H:i:s');
                $item['pid'] = intval($pid);
                $item['message'] = 'Téléchargement démarré...';
                break;
            }
        }
        saveDownloadQueue($queue);
        
        writeLog("Téléchargement démarré: $url (ID: $downloadId, PID: $pid)");
        
        return $downloadId;
    } else {
        throw new Exception('Échec du démarrage du téléchargement (PID: ' . var_export($pid, true) . ')');
    }
}

// Fonction pour annuler un téléchargement
function cancelDownload($downloadId) {
    $queue = loadDownloadQueue();
    $found = false;
    
    foreach ($queue as &$item) {
        if ($item['id'] === $downloadId) {
            if ($item['status'] === 'downloading' && isset($item['pid'])) {
                // Tuer le processus et tous ses enfants
                shell_exec("pkill -P {$item['pid']} 2>/dev/null");
                shell_exec("kill {$item['pid']} 2>/dev/null");
                
                $item['status'] = 'cancelled';
                $item['finished_at'] = date('Y-m-d H:i:s');
                $item['error'] = 'Annulé par l\'utilisateur';
                
                writeLog("Téléchargement annulé: $downloadId (PID: {$item['pid']})");
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
    return true;
}

// Fonction pour nettoyer l'historique
function cleanupHistory() {
    $queue = loadDownloadQueue();
    $activeStatuses = ['pending', 'downloading'];
    
    // Garder seulement les téléchargements actifs et les 10 derniers terminés
    $activeDownloads = array_filter($queue, function($item) use ($activeStatuses) {
        return in_array($item['status'], $activeStatuses);
    });
    
    $completedDownloads = array_filter($queue, function($item) use ($activeStatuses) {
        return !in_array($item['status'], $activeStatuses);
    });
    
    // Trier les terminés par date et garder les 10 derniers
    usort($completedDownloads, function($a, $b) {
        return strtotime($b['finished_at'] ?? $b['created_at']) - strtotime($a['finished_at'] ?? $a['created_at']);
    });
    
    $recentCompleted = array_slice($completedDownloads, 0, 10);
    
    $newQueue = array_merge($activeDownloads, $recentCompleted);
    saveDownloadQueue(array_values($newQueue));
    
    return count($queue) - count($newQueue);
}

// Fonction utilitaire pour formater la taille de fichier
function formatFileSize($bytes) {
    $units = ['B', 'KB', 'MB', 'GB'];
    $bytes = max($bytes, 0);
    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);
    
    $bytes /= (1 << (10 * $pow));
    
    return round($bytes, 1) . ' ' . $units[$pow];
}

// Fonction pour vérifier si une commande existe
function command_exists($cmd) {
    return !empty(shell_exec("which $cmd 2>/dev/null"));
}

// Gestion des requêtes
$method = $_SERVER['REQUEST_METHOD'];

// Gestion CORS
if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true) ?: [];

try {
    switch ($method) {
        case 'GET':
            $action = $_GET['action'] ?? 'status';
            
            switch ($action) {
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
                    
                case 'queue':
                    $queue = updateDownloadStatuses();
                    
                    // Statistiques
                    $stats = [
                        'total' => count($queue),
                        'downloading' => 0,
                        'pending' => 0,
                        'completed' => 0,
                        'failed' => 0
                    ];
                    
                    foreach ($queue as $item) {
                        $stats[$item['status']] = ($stats[$item['status']] ?? 0) + 1;
                    }
                    
                    echo json_encode([
                        'success' => true,
                        'queue' => $queue,
                        'stats' => $stats,
                        'max_concurrent' => MAX_CONCURRENT_DOWNLOADS
                    ]);
                    break;
                    
                case 'progress':
                    $downloadId = $_GET['id'] ?? '';
                    if (empty($downloadId)) {
                        throw new Exception('ID de téléchargement requis');
                    }
                    
                    $queue = updateDownloadStatuses();
                    $download = null;
                    
                    foreach ($queue as $item) {
                        if ($item['id'] === $downloadId) {
                            $download = $item;
                            break;
                        }
                    }
                    
                    if (!$download) {
                        throw new Exception('Téléchargement introuvable');
                    }
                    
                    // Ajouter la progression en temps réel
                    if ($download['status'] === 'downloading') {
                        $realtimeProgress = getDownloadProgress($downloadId);
                        $download['realtime_progress'] = $realtimeProgress;
                    }
                    
                    echo json_encode([
                        'success' => true,
                        'download' => $download
                    ]);
                    break;
                    
                case 'requirements':
                    $requirements = [
                        'yt-dlp' => command_exists('yt-dlp'),
                        'ffmpeg' => command_exists('ffmpeg'),
                        'script_exists' => file_exists(YOUTUBE_SCRIPT),
                        'script_executable' => file_exists(YOUTUBE_SCRIPT) && is_executable(YOUTUBE_SCRIPT),
                        'media_dir_writable' => is_writable(MEDIA_DIR),
                        'progress_dir_writable' => is_writable(PROGRESS_DIR),
                        'log_dir_writable' => is_writable(dirname(LOG_FILE))
                    ];
                    
                    $allOk = array_reduce($requirements, function($carry, $item) {
                        return $carry && $item;
                    }, true);
                    
                    echo json_encode([
                        'success' => true,
                        'requirements' => $requirements,
                        'ready' => $allOk,
                        'version' => '4.0.0'
                    ]);
                    break;
                    
                case 'status':
                default:
                    $queue = updateDownloadStatuses();
                    $activeDownloads = array_filter($queue, function($item) {
                        return $item['status'] === 'downloading';
                    });
                    
                    echo json_encode([
                        'success' => true,
                        'status' => 'ready',
                        'active_downloads' => count($activeDownloads),
                        'max_concurrent' => MAX_CONCURRENT_DOWNLOADS,
                        'can_start_new' => count($activeDownloads) < MAX_CONCURRENT_DOWNLOADS,
                        'version' => '4.0.0'
                    ]);
                    break;
            }
            break;
            
        case 'POST':
            $action = $_GET['action'] ?? $input['action'] ?? '';
            
            switch ($action) {
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
                        'message' => 'Téléchargement démarré avec succès',
                        'download_id' => $downloadId
                    ]);
                    break;
                    
                case 'cancel':
                    $downloadId = $input['id'] ?? '';
                    if (empty($downloadId)) {
                        throw new Exception('ID de téléchargement requis');
                    }
                    
                    cancelDownload($downloadId);
                    
                    echo json_encode([
                        'success' => true,
                        'message' => 'Téléchargement annulé'
                    ]);
                    break;
                    
                case 'cleanup':
                    $removed = cleanupHistory();
                    
                    echo json_encode([
                        'success' => true,
                        'message' => "Historique nettoyé ($removed éléments supprimés)"
                    ]);
                    break;
                    
                default:
                    throw new Exception('Action non supportée: ' . $action);
            }
            break;
            
        default:
            throw new Exception('Méthode HTTP non supportée: ' . $method);
    }
    
} catch (Exception $e) {
    http_response_code(400);
    writeLog("Erreur YouTube API Enhanced: " . $e->getMessage());
    
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s'),
        'version' => '4.0.0'
    ]);
}
?>