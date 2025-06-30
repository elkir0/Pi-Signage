<?php
/**
 * API de streaming pour le téléchargement YouTube avec progression
 */

define('PI_SIGNAGE_WEB', true);
require_once dirname(__DIR__) . '/includes/config.php';
require_once dirname(__DIR__) . '/includes/auth.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/security.php';

// Vérifier l'authentification
requireAuth();

// Désactiver la mise en tampon
ob_implicit_flush(true);
ob_end_flush();

// Headers pour le streaming
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('X-Accel-Buffering: no');

// Fonction pour envoyer des données JSON
function sendData($data) {
    echo json_encode($data) . "\n";
    flush();
}

// Fonction pour parser la sortie yt-dlp
function parseYtDlpOutput($line) {
    // Détection de la progression du téléchargement
    if (preg_match('/\[download\]\s+(\d+\.\d+)%\s+of\s+~?\s*(\d+\.\d+\w+)\s+at\s+(\d+\.\d+\w+\/s)\s+ETA\s+(\d+:\d+)/', $line, $matches)) {
        return [
            'type' => 'progress',
            'percent' => floatval($matches[1]),
            'size' => $matches[2],
            'speed' => $matches[3],
            'eta' => $matches[4]
        ];
    }
    
    // Détection de la progression sans ETA
    if (preg_match('/\[download\]\s+(\d+\.\d+)%/', $line, $matches)) {
        return [
            'type' => 'progress',
            'percent' => floatval($matches[1])
        ];
    }
    
    // Détection des informations de la vidéo
    if (preg_match('/\[info\]\s+(.+):\s+Downloading\s+webpage/', $line, $matches)) {
        return [
            'type' => 'info',
            'message' => 'Récupération des informations de la vidéo...'
        ];
    }
    
    // Détection du titre
    if (preg_match('/\[download\]\s+Destination:\s+(.+)/', $line, $matches)) {
        return [
            'type' => 'info',
            'message' => 'Téléchargement vers: ' . basename($matches[1])
        ];
    }
    
    // Détection de la fin du téléchargement
    if (strpos($line, '[download] 100%') !== false || strpos($line, 'has already been downloaded') !== false) {
        return [
            'type' => 'progress',
            'percent' => 100
        ];
    }
    
    // Détection d'erreurs
    if (strpos($line, 'ERROR:') !== false) {
        return [
            'type' => 'error',
            'message' => trim(str_replace('ERROR:', '', $line))
        ];
    }
    
    // Ligne de console générale
    return [
        'type' => 'console',
        'message' => trim($line)
    ];
}

// Validation de la requête
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendData(['type' => 'error', 'message' => 'Méthode non autorisée']);
    exit;
}

// Validation CSRF
if (!validateCSRFToken($_POST['csrf_token'] ?? '')) {
    sendData(['type' => 'error', 'message' => 'Token CSRF invalide']);
    exit;
}

// Récupération des paramètres
$url = $_POST['url'] ?? '';
$customTitle = $_POST['title'] ?? '';
$verbose = !empty($_POST['verbose']);

// Validation de l'URL
if (!filter_var($url, FILTER_VALIDATE_URL)) {
    sendData(['type' => 'error', 'message' => 'URL invalide']);
    exit;
}

// Vérifier que c'est une URL YouTube
if (!preg_match('/^https?:\/\/(www\.)?(youtube\.com|youtu\.be)\//', $url)) {
    sendData(['type' => 'error', 'message' => 'Seules les URLs YouTube sont autorisées']);
    exit;
}

// Commencer le téléchargement
sendData(['type' => 'info', 'message' => 'Initialisation du téléchargement...']);

// D'abord, obtenir les informations de la vidéo
$info_cmd = sprintf(
    'yt-dlp -j --no-playlist %s 2>&1',
    escapeshellarg($url)
);

$info_output = shell_exec($info_cmd);
$video_info = json_decode($info_output, true);

if ($video_info && !isset($video_info['error'])) {
    // Envoyer les infos de la vidéo
    sendData([
        'type' => 'info',
        'message' => 'Vidéo trouvée: ' . $video_info['title'],
        'video_info' => [
            'title' => $video_info['title'] ?? 'Sans titre',
            'duration' => isset($video_info['duration']) ? gmdate("H:i:s", $video_info['duration']) : 'N/A',
            'resolution' => $video_info['resolution'] ?? $video_info['format_note'] ?? 'N/A',
            'filesize' => isset($video_info['filesize']) ? formatFileSize($video_info['filesize']) : null
        ]
    ]);
}

// Générer un nom de fichier sécurisé
if ($customTitle) {
    $filename = preg_replace('/[^a-zA-Z0-9._-]/', '_', $customTitle);
} else {
    $filename = preg_replace('/[^a-zA-Z0-9._-]/', '_', $video_info['title'] ?? 'video_' . time());
}

// S'assurer que le nom est unique
$output_path = VIDEO_DIR . '/' . $filename . '.%(ext)s';
$final_path = VIDEO_DIR . '/' . $filename . '.mp4';

// Vérifier l'espace disponible
$free_space = disk_free_space(VIDEO_DIR);
$estimated_size = $video_info['filesize'] ?? 0;

if ($estimated_size > 0 && $free_space < $estimated_size * 1.1) {
    sendData(['type' => 'error', 'message' => 'Espace disque insuffisant']);
    exit;
}

// Construire la commande yt-dlp
$cmd = sprintf(
    'yt-dlp -f "best[ext=mp4]/best" -o %s --no-playlist --newline --restrict-filenames %s 2>&1',
    escapeshellarg($output_path),
    escapeshellarg($url)
);

// Log l'activité
logActivity("VIDEO_DOWNLOAD_START", $url);

// Exécuter la commande et streamer la sortie
$descriptorspec = [
    0 => ["pipe", "r"],  // stdin
    1 => ["pipe", "w"],  // stdout
    2 => ["pipe", "w"]   // stderr
];

$process = proc_open($cmd, $descriptorspec, $pipes);

if (is_resource($process)) {
    // Rendre les pipes non-bloquants
    stream_set_blocking($pipes[1], false);
    stream_set_blocking($pipes[2], false);
    
    $last_progress = -1;
    
    while (!feof($pipes[1]) || !feof($pipes[2])) {
        // Lire stdout
        $line = fgets($pipes[1]);
        if ($line !== false) {
            $data = parseYtDlpOutput($line);
            
            // Éviter d'envoyer trop de mises à jour de progression
            if ($data['type'] === 'progress') {
                $current_progress = intval($data['percent']);
                if ($current_progress > $last_progress) {
                    sendData($data);
                    $last_progress = $current_progress;
                }
            } else if ($verbose || $data['type'] !== 'console') {
                sendData($data);
            }
        }
        
        // Lire stderr
        $error = fgets($pipes[2]);
        if ($error !== false && $verbose) {
            sendData(['type' => 'console', 'message' => '[stderr] ' . trim($error)]);
        }
        
        // Petit délai pour éviter de surcharger le CPU
        usleep(50000); // 50ms
    }
    
    // Fermer les pipes
    fclose($pipes[0]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    
    // Obtenir le code de retour
    $return_value = proc_close($process);
    
    if ($return_value === 0) {
        // Vérifier que le fichier existe
        $downloaded_file = glob(VIDEO_DIR . '/' . $filename . '.*');
        if (!empty($downloaded_file)) {
            $final_file = $downloaded_file[0];
            $file_size = filesize($final_file);
            
            logActivity("VIDEO_DOWNLOAD_SUCCESS", basename($final_file));
            
            sendData([
                'type' => 'success',
                'message' => sprintf(
                    'Vidéo téléchargée avec succès: %s (%s)',
                    basename($final_file),
                    formatFileSize($file_size)
                )
            ]);
        } else {
            sendData(['type' => 'error', 'message' => 'Fichier téléchargé introuvable']);
        }
    } else {
        logActivity("VIDEO_DOWNLOAD_FAILED", $url);
        sendData(['type' => 'error', 'message' => 'Échec du téléchargement (code: ' . $return_value . ')']);
    }
} else {
    sendData(['type' => 'error', 'message' => 'Impossible de lancer yt-dlp']);
}

// La fonction formatFileSize est déjà définie dans functions.php