<?php
/**
 * Media Management API - PiSignage v0.8.0
 * Gestion complète des médias avec upload chunked
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

class MediaService {
    private $media_dir;
    private $allowed_types = [
        'video' => ['mp4', 'avi', 'mkv', 'webm', 'mov'],
        'image' => ['jpg', 'jpeg', 'png', 'gif', 'svg', 'webp'],
        'audio' => ['mp3', 'wav', 'ogg', 'flac']
    ];

    private $mime_types = [
        'mp4' => 'video/mp4',
        'avi' => 'video/x-msvideo',
        'mkv' => 'video/x-matroska',
        'webm' => 'video/webm',
        'mov' => 'video/quicktime',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'svg' => 'image/svg+xml',
        'webp' => 'image/webp',
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'ogg' => 'audio/ogg',
        'flac' => 'audio/flac'
    ];

    public function __construct() {
        $this->media_dir = dirname(dirname(__DIR__)) . '/media';
        if (!is_dir($this->media_dir)) {
            mkdir($this->media_dir, 0755, true);
        }
    }

    public function listMedia() {
        $media = [];
        $files = scandir($this->media_dir);

        foreach ($files as $file) {
            if ($file === '.' || $file === '..') continue;

            $path = $this->media_dir . '/' . $file;
            if (is_file($path)) {
                $media[] = $this->getFileInfo($file);
            }
        }

        // Sort by date modified (newest first)
        usort($media, function($a, $b) {
            return $b['modified'] - $a['modified'];
        });

        return $media;
    }

    public function uploadMedia() {
        // Handle chunked upload
        if (isset($_POST['dzuuid'])) {
            return $this->handleChunkedUpload();
        }

        // Handle regular upload
        if (!isset($_FILES['file'])) {
            return ['error' => 'No file uploaded'];
        }

        $file = $_FILES['file'];

        // Validate file
        $validation = $this->validateFile($file);
        if ($validation !== true) {
            return ['error' => $validation];
        }

        // Generate safe filename
        $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        $filename = $this->generateSafeFilename($file['name']);
        $filepath = $this->media_dir . '/' . $filename;

        // Move uploaded file
        if (move_uploaded_file($file['tmp_name'], $filepath)) {
            // Generate thumbnail for videos/images
            $this->generateThumbnail($filepath, $extension);

            return [
                'success' => true,
                'file' => $this->getFileInfo($filename)
            ];
        }

        return ['error' => 'Failed to save file'];
    }

    private function handleChunkedUpload() {
        $uuid = $_POST['dzuuid'];
        $chunk_index = intval($_POST['dzchunkindex']);
        $total_chunks = intval($_POST['dztotalchunkcount']);
        $filename = $_POST['dzfilename'];

        $chunk_dir = $this->media_dir . '/chunks/' . $uuid;
        if (!is_dir($chunk_dir)) {
            mkdir($chunk_dir, 0755, true);
        }

        // Save chunk
        $chunk_file = $chunk_dir . '/' . $chunk_index;
        move_uploaded_file($_FILES['file']['tmp_name'], $chunk_file);

        // Check if all chunks received
        $chunks_received = count(glob($chunk_dir . '/*'));
        if ($chunks_received === $total_chunks) {
            // Combine chunks
            $final_path = $this->media_dir . '/' . $this->generateSafeFilename($filename);
            $final_file = fopen($final_path, 'wb');

            for ($i = 0; $i < $total_chunks; $i++) {
                $chunk_path = $chunk_dir . '/' . $i;
                fwrite($final_file, file_get_contents($chunk_path));
                unlink($chunk_path);
            }

            fclose($final_file);
            rmdir($chunk_dir);

            // Generate thumbnail
            $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
            $this->generateThumbnail($final_path, $extension);

            return [
                'success' => true,
                'file' => $this->getFileInfo(basename($final_path))
            ];
        }

        return ['success' => true, 'chunk' => $chunk_index, 'total' => $total_chunks];
    }

    private function validateFile($file) {
        // Check for upload errors
        if ($file['error'] !== UPLOAD_ERR_OK) {
            return 'Upload failed with error code: ' . $file['error'];
        }

        // Check file size (max 500MB)
        if ($file['size'] > 500 * 1024 * 1024) {
            return 'File too large (max 500MB)';
        }

        // Check file extension
        $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        $allowed = array_merge(...array_values($this->allowed_types));
        if (!in_array($extension, $allowed)) {
            return 'File type not allowed: ' . $extension;
        }

        // Verify MIME type
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mime = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);

        $expected_mime = $this->mime_types[$extension] ?? '';
        if ($expected_mime && strpos($mime, explode('/', $expected_mime)[0]) === false) {
            return 'Invalid file type detected';
        }

        return true;
    }

    private function generateSafeFilename($original) {
        $extension = strtolower(pathinfo($original, PATHINFO_EXTENSION));
        $basename = pathinfo($original, PATHINFO_FILENAME);
        $basename = preg_replace('/[^a-zA-Z0-9_-]/', '_', $basename);
        $basename = substr($basename, 0, 50);

        $filename = $basename . '.' . $extension;
        $counter = 1;

        while (file_exists($this->media_dir . '/' . $filename)) {
            $filename = $basename . '_' . $counter . '.' . $extension;
            $counter++;
        }

        return $filename;
    }

    private function generateThumbnail($filepath, $extension) {
        $thumb_dir = $this->media_dir . '/thumbnails';
        if (!is_dir($thumb_dir)) {
            mkdir($thumb_dir, 0755, true);
        }

        $filename = basename($filepath);
        $thumb_path = $thumb_dir . '/thumb_' . $filename . '.jpg';

        if (in_array($extension, $this->allowed_types['image'])) {
            exec("convert '$filepath' -resize 320x240 '$thumb_path' 2>&1");
        } elseif (in_array($extension, $this->allowed_types['video'])) {
            exec("ffmpeg -i '$filepath' -ss 00:00:01.000 -vframes 1 -vf scale=320:240 '$thumb_path' 2>&1");
        }
    }

    private function getFileInfo($filename) {
        $filepath = $this->media_dir . '/' . $filename;
        $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
        $type = 'unknown';

        foreach ($this->allowed_types as $media_type => $extensions) {
            if (in_array($extension, $extensions)) {
                $type = $media_type;
                break;
            }
        }

        $info = [
            'name' => $filename,
            'path' => '/media/' . $filename,
            'type' => $type,
            'extension' => $extension,
            'size' => filesize($filepath),
            'modified' => filemtime($filepath),
            'readable_size' => $this->formatBytes(filesize($filepath)),
            'readable_date' => date('Y-m-d H:i', filemtime($filepath))
        ];

        // Add thumbnail if exists
        $thumb_path = $this->media_dir . '/thumbnails/thumb_' . $filename . '.jpg';
        if (file_exists($thumb_path)) {
            $info['thumbnail'] = '/media/thumbnails/thumb_' . $filename . '.jpg';
        }

        // Add duration for videos
        if ($type === 'video') {
            $duration = $this->getVideoDuration($filepath);
            if ($duration) {
                $info['duration'] = $duration;
            }
        }

        return $info;
    }

    private function getVideoDuration($filepath) {
        $output = [];
        exec("ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 '$filepath' 2>&1", $output);
        $duration = floatval($output[0] ?? 0);
        if ($duration > 0) {
            return gmdate('H:i:s', $duration);
        }
        return null;
    }

    private function formatBytes($bytes, $precision = 2) {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $bytes = max($bytes, 0);
        $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
        $pow = min($pow, count($units) - 1);
        $bytes /= pow(1024, $pow);
        return round($bytes, $precision) . ' ' . $units[$pow];
    }

    public function deleteMedia($filename) {
        if (!$filename || strpos($filename, '/') !== false || strpos($filename, '..') !== false) {
            return ['error' => 'Invalid filename'];
        }

        $filepath = $this->media_dir . '/' . $filename;
        $thumb_path = $this->media_dir . '/thumbnails/thumb_' . $filename . '.jpg';

        if (!file_exists($filepath)) {
            return ['error' => 'File not found'];
        }

        if (unlink($filepath)) {
            if (file_exists($thumb_path)) {
                unlink($thumb_path);
            }
            return ['success' => true, 'deleted' => $filename];
        }

        return ['error' => 'Failed to delete file'];
    }
}

// Handle requests
$service = new MediaService();

switch ($_SERVER['REQUEST_METHOD']) {
    case 'GET':
        echo json_encode($service->listMedia());
        break;

    case 'POST':
        if (isset($_GET['action']) && $_GET['action'] === 'upload') {
            echo json_encode($service->uploadMedia());
        } else {
            echo json_encode($service->uploadMedia());
        }
        break;

    case 'DELETE':
        $filename = $_GET['filename'] ?? '';
        echo json_encode($service->deleteMedia($filename));
        break;

    default:
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
}