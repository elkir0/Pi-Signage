<?php
header('Content-Type: application/json');

// Media directory
$media_dir = '/opt/pisignage/media/';

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // List media files
    $files = [];
    if (is_dir($media_dir)) {
        $items = scandir($media_dir);
        foreach ($items as $item) {
            if ($item != '.' && $item != '..') {
                $path = $media_dir . $item;
                $files[] = [
                    'name' => $item,
                    'size' => filesize($path),
                    'modified' => filemtime($path),
                    'type' => mime_content_type($path)
                ];
            }
        }
    }
    echo json_encode(['files' => $files]);
} else {
    echo json_encode(['error' => 'Method not allowed']);
}
?>