<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$uploadDir = '/opt/pisignage/media/';
$response = ['success' => false];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_FILES['video'])) {
        $file = $_FILES['video'];
        $fileName = preg_replace('/[^a-zA-Z0-9._-]/', '_', $file['name']);
        $targetPath = $uploadDir . $fileName;
        
        // Vérifier l'extension
        $allowedExt = ['mp4', 'avi', 'mkv', 'webm', 'mov'];
        $ext = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
        
        if (!in_array($ext, $allowedExt)) {
            $response['error'] = 'Format non supporté. Utilisez: ' . implode(', ', $allowedExt);
        } elseif ($file['size'] > 500 * 1024 * 1024) { // 500MB max
            $response['error'] = 'Fichier trop gros (max 500MB)';
        } elseif (move_uploaded_file($file['tmp_name'], $targetPath)) {
            chmod($targetPath, 0644);
            $response['success'] = true;
            $response['file'] = $fileName;
            $response['size'] = filesize($targetPath);
            $response['message'] = 'Upload réussi!';
        } else {
            $response['error'] = 'Erreur lors de l\'upload';
        }
    } else {
        $response['error'] = 'Aucun fichier reçu';
    }
}

echo json_encode($response);
