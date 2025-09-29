<?php
// Screenshot simple pour VLC
header('Content-Type: application/json');

$outputDir = '/opt/pisignage/screenshots';
if (!is_dir($outputDir)) {
    mkdir($outputDir, 0755, true);
}

// Méthode 1: Si VLC tourne, capturer depuis le fichier vidéo
$vlcPid = trim(shell_exec('pgrep -x vlc'));
if ($vlcPid) {
    // Obtenir le fichier depuis VLC HTTP
    $vlcStatus = @file_get_contents('http://:pisignage@localhost:8080/requests/status.json');
    if ($vlcStatus) {
        $status = json_decode($vlcStatus, true);
        $filename = $status['information']['category']['meta']['filename'] ?? '';
        
        if ($filename && file_exists("/opt/pisignage/media/$filename")) {
            // Obtenir la position actuelle
            $position = intval($status['time'] ?? 0);
            
            // Capturer une frame avec ffmpeg
            $outputFile = $outputDir . '/screenshot_' . time() . '.jpg';
            $cmd = sprintf(
                'ffmpeg -ss %d -i %s -vframes 1 -q:v 2 %s -y 2>/dev/null',
                $position,
                escapeshellarg("/opt/pisignage/media/$filename"),
                escapeshellarg($outputFile)
            );
            
            exec($cmd, $output, $returnVar);
            
            if ($returnVar === 0 && file_exists($outputFile)) {
                echo json_encode([
                    'success' => true,
                    'file' => basename($outputFile),
                    'url' => '/screenshots/' . basename($outputFile),
                    'method' => 'ffmpeg-vlc'
                ]);
                exit;
            }
        }
    }
}

// Méthode 2: Framebuffer
$outputFile = $outputDir . '/screenshot_' . time() . '.png';
exec("sudo fbgrab -d /dev/fb0 $outputFile 2>/dev/null", $output, $returnVar);

if ($returnVar === 0 && file_exists($outputFile)) {
    echo json_encode([
        'success' => true,
        'file' => basename($outputFile),
        'url' => '/screenshots/' . basename($outputFile),
        'method' => 'fbgrab'
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to capture screenshot'
    ]);
}
