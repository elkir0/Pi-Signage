<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$response = ['success' => false];

// Chemins
$screenshot_dir = '/opt/pisignage/web/assets/screenshots/';
$screenshot_file = $screenshot_dir . 'current.png';
$screenshot_url = '/assets/screenshots/current.png';

// Créer le répertoire si nécessaire
if (!is_dir($screenshot_dir)) {
    mkdir($screenshot_dir, 0755, true);
}

// Utiliser le script intelligent qui extrait une frame
$output = [];
$return_code = 0;

exec('sudo /opt/pisignage/scripts/screenshot-smart.sh ' . escapeshellarg($screenshot_file) . ' 2>&1', $output, $return_code);

if ($return_code === 0 && file_exists($screenshot_file)) {
    $size = filesize($screenshot_file);
    
    // Accepter toutes les tailles car on génère une image info même sans vidéo
    $response['success'] = true;
    $response['screenshot'] = $screenshot_url . '?t=' . time();
    $response['method'] = 'frame-extraction';
    $response['size'] = $size;
    
    // Ajouter des infos sur la vidéo si disponible
    foreach ($output as $line) {
        if (strpos($line, 'Extracting frame from:') !== false) {
            preg_match('/from: (.+)$/', $line, $matches);
            if (isset($matches[1])) {
                $response['video'] = basename($matches[1]);
            }
        }
        if (strpos($line, 'Frame extracted at') !== false) {
            preg_match('/at (\d+:\d+:\d+)/', $line, $matches);
            if (isset($matches[1])) {
                $response['position'] = $matches[1];
            }
        }
    }
} else {
    $response['error'] = 'Extraction échouée';
    $response['return_code'] = $return_code;
    $response['debug'] = $output;
}

echo json_encode($response, JSON_PRETTY_PRINT);
