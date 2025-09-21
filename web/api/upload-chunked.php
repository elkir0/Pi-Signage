<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$uploadDir = '/opt/pisignage/media/';
$tempDir = '/tmp/pisignage_uploads/';

// Create temp directory if needed
if (!is_dir($tempDir)) {
    mkdir($tempDir, 0777, true);
}

$action = $_POST['action'] ?? 'upload';

if ($action === 'chunk') {
    // Handle chunk upload
    $fileName = preg_replace('/[^a-zA-Z0-9._-]/', '_', $_POST['filename']);
    $chunkIndex = intval($_POST['chunk']);
    $totalChunks = intval($_POST['chunks']);
    
    $tempFile = $tempDir . $fileName . '.part';
    
    // Get the chunk data
    $chunk = $_FILES['file']['tmp_name'] ?? null;
    
    if (!$chunk) {
        echo json_encode(['success' => false, 'error' => 'No chunk data']);
        exit;
    }
    
    // Append chunk to temp file
    $mode = ($chunkIndex === 0) ? 'wb' : 'ab';
    $out = fopen($tempFile, $mode);
    if (!$out) {
        echo json_encode(['success' => false, 'error' => 'Cannot open temp file']);
        exit;
    }
    
    $in = fopen($chunk, 'rb');
    if (!$in) {
        fclose($out);
        echo json_encode(['success' => false, 'error' => 'Cannot read chunk']);
        exit;
    }
    
    while ($buff = fread($in, 4096)) {
        fwrite($out, $buff);
    }
    
    fclose($in);
    fclose($out);
    
    // If last chunk, move to media directory
    if ($chunkIndex === $totalChunks - 1) {
        $finalPath = $uploadDir . $fileName;
        if (rename($tempFile, $finalPath)) {
            chmod($finalPath, 0644);
            echo json_encode([
                'success' => true,
                'complete' => true,
                'file' => $fileName,
                'size' => filesize($finalPath)
            ]);
        } else {
            echo json_encode(['success' => false, 'error' => 'Cannot move file']);
        }
    } else {
        echo json_encode([
            'success' => true,
            'chunk' => $chunkIndex,
            'progress' => round(($chunkIndex + 1) / $totalChunks * 100)
        ]);
    }
} else {
    echo json_encode(['success' => false, 'error' => 'Invalid action']);
}
