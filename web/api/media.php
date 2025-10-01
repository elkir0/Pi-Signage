<?php
/**
 * PiSignage v0.8.0 - Media Management API
 * Handles media file operations
 */

require_once '../config.php';

// Only execute request handling if this file is called directly (not included)
if (basename($_SERVER['SCRIPT_FILENAME']) === 'media.php') {
    $method = $_SERVER['REQUEST_METHOD'];
    $input = json_decode(file_get_contents('php://input'), true);

    switch ($method) {
        case 'GET':
            handleGetMedia();
            break;

        case 'POST':
            handleMediaAction($input);
            break;

        case 'DELETE':
            handleDeleteMedia($input);
            break;

        default:
            jsonResponse(false, null, 'Method not allowed');
    }
}

function handleGetMedia() {
    $action = $_GET['action'] ?? 'list';

    switch ($action) {
        case 'list':
            $mediaFiles = getMediaFiles();
            jsonResponse(true, $mediaFiles);
            break;

        case 'info':
            if (!isset($_GET['file'])) {
                jsonResponse(false, null, 'File parameter required');
            }

            $filename = basename($_GET['file']);
            $filepath = MEDIA_PATH . '/' . $filename;

            if (!file_exists($filepath)) {
                jsonResponse(false, null, 'File not found');
            }

            $info = getMediaFileInfo($filepath);
            jsonResponse(true, $info);
            break;

        case 'thumbnails':
            $thumbnails = getMediaThumbnails();
            jsonResponse(true, $thumbnails);
            break;

        default:
            jsonResponse(false, null, "Unknown action: $action");
    }
}

function handleMediaAction($input) {
    if (!isset($input['action'])) {
        jsonResponse(false, null, 'Action parameter required');
    }

    $action = $input['action'];

    switch ($action) {
        case 'rename':
            handleRenameMedia($input);
            break;

        case 'move':
            handleMoveMedia($input);
            break;

        case 'duplicate':
            handleDuplicateMedia($input);
            break;

        case 'generate_thumbnail':
            handleGenerateThumbnail($input);
            break;

        default:
            jsonResponse(false, null, "Unknown action: $action");
    }
}

function handleDeleteMedia($input) {
    if (!isset($input['filename'])) {
        jsonResponse(false, null, 'Filename parameter required');
    }

    $filename = basename($input['filename']);
    $filepath = MEDIA_PATH . '/' . $filename;

    if (!file_exists($filepath)) {
        jsonResponse(false, null, 'File not found');
    }

    // Check if file is currently being used in any playlist
    $playlists = glob(PLAYLISTS_PATH . '/*.json');
    $usedInPlaylists = [];

    foreach ($playlists as $playlistFile) {
        $playlist = json_decode(file_get_contents($playlistFile), true);
        if ($playlist && isset($playlist['items']) && in_array($filename, $playlist['items'])) {
            $usedInPlaylists[] = basename($playlistFile, '.json');
        }
    }

    if (!empty($usedInPlaylists)) {
        jsonResponse(false, [
            'playlists' => $usedInPlaylists
        ], 'File is used in playlists: ' . implode(', ', $usedInPlaylists));
    }

    // Delete the file
    if (unlink($filepath)) {
        // Delete thumbnail if exists
        $thumbnailPath = MEDIA_PATH . '/thumbnails/' . $filename . '.jpg';
        if (file_exists($thumbnailPath)) {
            unlink($thumbnailPath);
        }

        // Update database
        try {
            global $db;
            $stmt = $db->prepare("DELETE FROM media_history WHERE filename = ?");
            $stmt->execute([$filename]);
        } catch (Exception $e) {
            logMessage("Failed to remove media from database: " . $e->getMessage(), 'ERROR');
        }

        logMessage("Media file deleted: $filename");
        jsonResponse(true, null, 'File deleted successfully');
    } else {
        jsonResponse(false, null, 'Failed to delete file');
    }
}

function handleRenameMedia($input) {
    if (!isset($input['old_name']) || !isset($input['new_name'])) {
        jsonResponse(false, null, 'Old name and new name parameters required');
    }

    $oldName = basename($input['old_name']);
    $newName = sanitizeFilename($input['new_name']);

    $oldPath = MEDIA_PATH . '/' . $oldName;
    $newPath = MEDIA_PATH . '/' . $newName;

    if (!file_exists($oldPath)) {
        jsonResponse(false, null, 'Source file not found');
    }

    if (file_exists($newPath)) {
        jsonResponse(false, null, 'Destination file already exists');
    }

    if (!isValidMediaFile($newName)) {
        jsonResponse(false, null, 'Invalid file extension');
    }

    if (rename($oldPath, $newPath)) {
        // Update playlists that reference this file
        updatePlaylistReferences($oldName, $newName);

        // Update database
        try {
            global $db;
            $stmt = $db->prepare("UPDATE media_history SET filename = ? WHERE filename = ?");
            $stmt->execute([$newName, $oldName]);
        } catch (Exception $e) {
            logMessage("Failed to update media in database: " . $e->getMessage(), 'ERROR');
        }

        logMessage("Media file renamed: $oldName -> $newName");
        jsonResponse(true, null, 'File renamed successfully');
    } else {
        jsonResponse(false, null, 'Failed to rename file');
    }
}

function handleDuplicateMedia($input) {
    if (!isset($input['filename'])) {
        jsonResponse(false, null, 'Filename parameter required');
    }

    $filename = basename($input['filename']);
    $sourcePath = MEDIA_PATH . '/' . $filename;

    if (!file_exists($sourcePath)) {
        jsonResponse(false, null, 'Source file not found');
    }

    // Generate new filename
    $pathInfo = pathinfo($filename);
    $baseName = $pathInfo['filename'];
    $extension = $pathInfo['extension'];
    $counter = 1;

    do {
        $newFilename = $baseName . '_copy' . $counter . '.' . $extension;
        $newPath = MEDIA_PATH . '/' . $newFilename;
        $counter++;
    } while (file_exists($newPath));

    if (copy($sourcePath, $newPath)) {
        // Add to database
        try {
            global $db;
            $stmt = $db->prepare("
                INSERT INTO media_history (filename, original_name, file_size, mime_type)
                VALUES (?, ?, ?, ?)
            ");
            $stmt->execute([
                $newFilename,
                $newFilename,
                filesize($newPath),
                mime_content_type($newPath)
            ]);
        } catch (Exception $e) {
            logMessage("Failed to log media duplication: " . $e->getMessage(), 'ERROR');
        }

        logMessage("Media file duplicated: $filename -> $newFilename");
        jsonResponse(true, ['new_filename' => $newFilename], 'File duplicated successfully');
    } else {
        jsonResponse(false, null, 'Failed to duplicate file');
    }
}

function handleGenerateThumbnail($input) {
    if (!isset($input['filename'])) {
        jsonResponse(false, null, 'Filename parameter required');
    }

    $filename = basename($input['filename']);
    $filepath = MEDIA_PATH . '/' . $filename;

    if (!file_exists($filepath)) {
        jsonResponse(false, null, 'File not found');
    }

    $thumbnail = generateThumbnail($filepath);

    if ($thumbnail) {
        jsonResponse(true, ['thumbnail' => $thumbnail], 'Thumbnail generated successfully');
    } else {
        jsonResponse(false, null, 'Failed to generate thumbnail');
    }
}

function getMediaFileInfo($filepath) {
    $filename = basename($filepath);
    $pathInfo = pathinfo($filename);

    $info = [
        'name' => $filename,
        'path' => $filepath,
        'size' => filesize($filepath),
        'size_formatted' => formatFileSize(filesize($filepath)),
        'type' => mime_content_type($filepath),
        'extension' => strtolower($pathInfo['extension'] ?? ''),
        'created' => filectime($filepath),
        'modified' => filemtime($filepath),
        'permissions' => substr(sprintf('%o', fileperms($filepath)), -4)
    ];

    // Get additional info for media files
    if (strpos($info['type'], 'video/') === 0) {
        $info['media_type'] = 'video';
        $info['duration'] = getVideoDuration($filepath);
        $info['resolution'] = getVideoResolution($filepath);
    } elseif (strpos($info['type'], 'audio/') === 0) {
        $info['media_type'] = 'audio';
        $info['duration'] = getAudioDuration($filepath);
    } elseif (strpos($info['type'], 'image/') === 0) {
        $info['media_type'] = 'image';
        $imageSize = getimagesize($filepath);
        if ($imageSize) {
            $info['width'] = $imageSize[0];
            $info['height'] = $imageSize[1];
            $info['resolution'] = $imageSize[0] . 'x' . $imageSize[1];
        }
    }

    return $info;
}

function getVideoDuration($filepath) {
    $command = "ffprobe -v quiet -show_entries format=duration -of csv=p=0 " . escapeshellarg($filepath);
    $result = executeCommand($command);

    if ($result['success'] && !empty($result['output'])) {
        $duration = floatval($result['output'][0]);
        return formatDuration($duration);
    }

    return 'Unknown';
}

function getVideoResolution($filepath) {
    $command = "ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 " . escapeshellarg($filepath);
    $result = executeCommand($command);

    if ($result['success'] && !empty($result['output'])) {
        return trim($result['output'][0]);
    }

    return 'Unknown';
}

function getAudioDuration($filepath) {
    return getVideoDuration($filepath); // Same method works for audio
}

function formatDuration($seconds) {
    $hours = floor($seconds / 3600);
    $minutes = floor(($seconds % 3600) / 60);
    $seconds = floor($seconds % 60);

    if ($hours > 0) {
        return sprintf('%02d:%02d:%02d', $hours, $minutes, $seconds);
    } else {
        return sprintf('%02d:%02d', $minutes, $seconds);
    }
}

function formatFileSize($bytes) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $factor = floor((strlen($bytes) - 1) / 3);
    return sprintf("%.2f", $bytes / pow(1024, $factor)) . ' ' . $units[$factor];
}

function generateThumbnail($filepath) {
    $filename = basename($filepath);
    $thumbnailDir = MEDIA_PATH . '/thumbnails';

    if (!file_exists($thumbnailDir)) {
        mkdir($thumbnailDir, 0755, true);
    }

    $thumbnailPath = $thumbnailDir . '/' . $filename . '.jpg';

    // Generate thumbnail based on file type
    $mimeType = mime_content_type($filepath);

    if (strpos($mimeType, 'video/') === 0) {
        // Video thumbnail using ffmpeg
        $command = "ffmpeg -i " . escapeshellarg($filepath) . " -ss 00:00:01.000 -vframes 1 -vf scale=200:150 " . escapeshellarg($thumbnailPath) . " -y";
        $result = executeCommand($command);
        return $result['success'] ? $thumbnailPath : false;
    } elseif (strpos($mimeType, 'image/') === 0) {
        // Image thumbnail using ImageMagick or GD
        if (function_exists('imagecreatefromjpeg')) {
            return createImageThumbnail($filepath, $thumbnailPath);
        }
    }

    return false;
}

function createImageThumbnail($sourcePath, $thumbnailPath) {
    $imageInfo = getimagesize($sourcePath);
    if (!$imageInfo) return false;

    $sourceWidth = $imageInfo[0];
    $sourceHeight = $imageInfo[1];
    $sourceType = $imageInfo[2];

    // Calculate thumbnail dimensions
    $thumbWidth = 200;
    $thumbHeight = 150;

    $ratio = min($thumbWidth / $sourceWidth, $thumbHeight / $sourceHeight);
    $newWidth = round($sourceWidth * $ratio);
    $newHeight = round($sourceHeight * $ratio);

    // Create source image
    switch ($sourceType) {
        case IMAGETYPE_JPEG:
            $sourceImage = imagecreatefromjpeg($sourcePath);
            break;
        case IMAGETYPE_PNG:
            $sourceImage = imagecreatefrompng($sourcePath);
            break;
        case IMAGETYPE_GIF:
            $sourceImage = imagecreatefromgif($sourcePath);
            break;
        default:
            return false;
    }

    if (!$sourceImage) return false;

    // Create thumbnail
    $thumbnail = imagecreatetruecolor($newWidth, $newHeight);
    imagecopyresampled($thumbnail, $sourceImage, 0, 0, 0, 0, $newWidth, $newHeight, $sourceWidth, $sourceHeight);

    // Save thumbnail
    $success = imagejpeg($thumbnail, $thumbnailPath, 85);

    // Clean up
    imagedestroy($sourceImage);
    imagedestroy($thumbnail);

    return $success ? $thumbnailPath : false;
}

function updatePlaylistReferences($oldFilename, $newFilename) {
    $playlists = glob(PLAYLISTS_PATH . '/*.json');

    foreach ($playlists as $playlistFile) {
        $playlist = json_decode(file_get_contents($playlistFile), true);

        if ($playlist && isset($playlist['items'])) {
            $updated = false;

            for ($i = 0; $i < count($playlist['items']); $i++) {
                if ($playlist['items'][$i] === $oldFilename) {
                    $playlist['items'][$i] = $newFilename;
                    $updated = true;
                }
            }

            if ($updated) {
                file_put_contents($playlistFile, json_encode($playlist, JSON_PRETTY_PRINT));
                logMessage("Updated playlist references: " . basename($playlistFile));
            }
        }
    }
}

function getMediaThumbnails() {
    $thumbnailDir = MEDIA_PATH . '/thumbnails';
    $thumbnails = [];

    if (is_dir($thumbnailDir)) {
        $files = glob($thumbnailDir . '/*.jpg');

        foreach ($files as $thumbnailFile) {
            $originalName = str_replace('.jpg', '', basename($thumbnailFile));
            $thumbnails[$originalName] = $thumbnailFile;
        }
    }

    return $thumbnails;
}
?>