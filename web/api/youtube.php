<?php
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $url = $input['url'] ?? '';
    $quality = $input['quality'] ?? 'best';

    if (empty($url)) {
        echo json_encode(['error' => 'URL required']);
        exit;
    }

    // Prepare yt-dlp command
    $output_path = '/opt/pisignage/media/%(title)s.%(ext)s';
    $command = "yt-dlp ";

    // Quality settings
    if ($quality === 'best') {
        $command .= "-f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best' ";
    } else {
        $command .= "-f 'bestvideo[height<={$quality}]+bestaudio/best[height<={$quality}]' ";
    }

    $command .= "-o '$output_path' '$url' 2>&1";

    // Execute download in background
    exec($command, $output, $return);

    if ($return === 0) {
        echo json_encode([
            'success' => true,
            'message' => 'Download started',
            'output' => $output
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'error' => 'Download failed',
            'output' => $output
        ]);
    }
} elseif ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Return download queue status
    echo json_encode([
        'queue' => [],
        'message' => 'Queue functionality not implemented in v0.8.0'
    ]);
} else {
    echo json_encode(['error' => 'Method not allowed']);
}
?>