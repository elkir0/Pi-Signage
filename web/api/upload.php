<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

function log_upload($message) {
    error_log('[' . date('Y-m-d H:i:s') . '] UPLOAD: ' . $message);
}

function getFileType($file) {
    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    $videoExts = ['mp4', 'avi', 'mkv', 'mov', 'webm'];
    return in_array($ext, $videoExts) ? 'video' : 'image';
}

function formatBytes($size) {
    if ($size >= 1073741824) return number_format($size / 1073741824, 2) . ' GB';
    if ($size >= 1048576) return number_format($size / 1048576, 2) . ' MB';
    if ($size >= 1024) return number_format($size / 1024, 2) . ' KB';
    return $size . ' B';
}

function getMediaDuration($file) {
    if (getFileType($file) !== 'video') return 0;
    $cmd = 'ffprobe -v quiet -select_streams v:0 -show_entries stream=duration -of csv=p=0 "' . $file . '" 2>/dev/null';
    $duration = trim(shell_exec($cmd));
    return $duration ? round((float)$duration) : 0;
}

function getMediaFiles() {
    $files = [];
    $mediaDir = '/opt/pisignage/media/';
    if (is_dir($mediaDir)) {
        $extensions = ['mp4', 'avi', 'mkv', 'mov', 'webm', 'jpg', 'jpeg', 'png', 'gif'];
        $videos = glob($mediaDir . '*.{' . implode(',', $extensions) . '}', GLOB_BRACE);
        foreach ($videos as $file) {
            $files[] = [
                'name' => basename($file),
                'path' => $file,
                'type' => getFileType($file),
                'size' => filesize($file),
                'size_formatted' => formatBytes(filesize($file)),
                'duration' => getMediaDuration($file),
                'modified' => date('Y-m-d H:i', filemtime($file))
            ];
        }
    }
    return $files;
}

$uploadDir = '/opt/pisignage/media/';
$response = ['success' => false];

log_upload('Upload request received');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_FILES['video'])) {
        $file = $_FILES['video'];
        $fileName = preg_replace('/[^a-zA-Z0-9._-]/', '_', $file['name']);
        $targetPath = $uploadDir . $fileName;
        
        log_upload('Processing file: ' . $fileName . ' (size: ' . $file['size'] . ')');
        
        // Vérifier l'extension
        $allowedExt = ['mp4', 'avi', 'mkv', 'webm', 'mov', 'jpg', 'jpeg', 'png', 'gif'];
        $ext = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
        
        if (!in_array($ext, $allowedExt)) {
            $response['error'] = 'Format non supporté. Utilisez: ' . implode(', ', $allowedExt);
            log_upload('ERROR: Unsupported format: ' . $ext);
        } elseif ($file['size'] > 500 * 1024 * 1024) { // 500MB max
            $response['error'] = 'Fichier trop gros (max 500MB)';
            log_upload('ERROR: File too large: ' . $file['size']);
        } elseif (move_uploaded_file($file['tmp_name'], $targetPath)) {
            chmod($targetPath, 0644);
            log_upload('SUCCESS: File uploaded to ' . $targetPath);
            
            // Return updated file list
            $mediaFiles = getMediaFiles();
            $response['success'] = true;
            $response['file'] = $fileName;
            $response['size'] = filesize($targetPath);
            $response['message'] = 'Upload réussi!';
            $response['files'] = $mediaFiles;  // Include updated file list
            
            log_upload('Updated media list with ' . count($mediaFiles) . ' files');
        } else {
            $response['error'] = 'Erreur lors de l\'upload';
            log_upload('ERROR: move_uploaded_file failed');
        }
    } else {
        $response['error'] = 'Aucun fichier reçu';
        log_upload('ERROR: No file in request');
    }
} else {
    $response['error'] = 'Méthode non autorisée';
    log_upload('ERROR: Wrong request method: ' . $_SERVER['REQUEST_METHOD']);
}

echo json_encode($response);
