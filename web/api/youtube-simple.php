<?php
/**
 * API YouTube simplifiée et fonctionnelle
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// Paths
define('MEDIA_PATH', '/opt/pisignage/media');
define('LOGS_PATH', '/opt/pisignage/logs');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);

    if (!isset($input['url'])) {
        echo json_encode(['success' => false, 'message' => 'URL requise']);
        exit;
    }

    $url = $input['url'];
    $quality = $input['quality'] ?? '720p';

    // Construire la commande yt-dlp simple et directe
    $outputPath = MEDIA_PATH . '/%(title)s.%(ext)s';
    $logFile = LOGS_PATH . '/youtube_' . time() . '.log';

    // Format selon qualité
    $formatOption = '';
    if ($quality === 'best') {
        $formatOption = '-f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"';
    } else {
        $height = str_replace('p', '', $quality);
        $formatOption = "-f \"bestvideo[height<={$height}][ext=mp4]+bestaudio[ext=m4a]/best[height<={$height}]\"";
    }

    // Commande complète
    $command = "/usr/local/bin/yt-dlp $formatOption -o " . escapeshellarg($outputPath) . " " . escapeshellarg($url) . " > " . escapeshellarg($logFile) . " 2>&1 &";

    // Log la commande
    error_log("YouTube Download Command: " . $command);
    file_put_contents(LOGS_PATH . '/pisignage.log',
        "[" . date('Y-m-d H:i:s') . "] [INFO] YouTube download: $url\n",
        FILE_APPEND);

    // Exécuter la commande
    exec($command, $output, $returnCode);

    echo json_encode([
        'success' => true,
        'message' => 'Téléchargement lancé',
        'log_file' => $logFile
    ]);

} elseif ($method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'status') {
    // Vérifier le statut du téléchargement
    $processes = [];
    exec("ps aux | grep yt-dlp | grep -v grep", $processes);

    $isDownloading = !empty($processes);

    // Récupérer le dernier log
    $lastLog = '';
    $logFiles = glob(LOGS_PATH . '/youtube_*.log');
    if (!empty($logFiles)) {
        $lastLogFile = end($logFiles);
        $lastLog = tail($lastLogFile, 5);
    }

    echo json_encode([
        'success' => true,
        'downloading' => $isDownloading,
        'log' => $lastLog,
        'process_count' => count($processes)
    ]);

} else {
    echo json_encode(['success' => false, 'message' => 'Méthode non supportée']);
}

function tail($file, $lines = 10) {
    if (!file_exists($file)) return '';

    $data = file($file);
    $lines = array_slice($data, -$lines);
    return implode('', $lines);
}
?>