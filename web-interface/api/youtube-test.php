<?php
/**
 * Test minimal de l'API YouTube
 */

// Configuration minimale
define('PI_SIGNAGE_WEB', true);
header('Content-Type: application/json');

// Réponse de test
$response = [
    'success' => true,
    'message' => 'API accessible',
    'php_version' => phpversion(),
    'user' => get_current_user(),
    'method' => $_SERVER['REQUEST_METHOD'],
    'time' => date('Y-m-d H:i:s')
];

// Si POST, récupérer les données
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $response['received_data'] = $input;
    
    // Test d'exécution de commande simple
    $output = [];
    $status = -1;
    exec('echo "Test command execution"', $output, $status);
    $response['exec_test'] = [
        'status' => $status,
        'output' => $output
    ];
    
    // Test du wrapper si disponible
    if (file_exists('/opt/scripts/yt-dlp-wrapper.sh')) {
        $response['wrapper_exists'] = true;
        
        // Tester avec timeout court
        exec('timeout 2 sudo /opt/scripts/yt-dlp-wrapper.sh --version 2>&1', $output2, $status2);
        $response['wrapper_test'] = [
            'status' => $status2,
            'output' => array_slice($output2, 0, 5) // Limiter la sortie
        ];
    }
}

echo json_encode($response, JSON_PRETTY_PRINT);