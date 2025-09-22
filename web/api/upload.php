<?php
/**
 * PiSignage v0.8.0 - File Upload API
 * Handles media file uploads
 */

require_once '../config.php';

// Handle file uploads
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, null, 'Only POST method allowed');
}

// Check if files were uploaded
if (!isset($_FILES['files']) || empty($_FILES['files']['name'][0])) {
    jsonResponse(false, null, 'No files uploaded');
}

$uploadedFiles = [];
$errors = [];

// Process each uploaded file
$fileCount = count($_FILES['files']['name']);

for ($i = 0; $i < $fileCount; $i++) {
    $fileName = $_FILES['files']['name'][$i];
    $fileTmpName = $_FILES['files']['tmp_name'][$i];
    $fileSize = $_FILES['files']['size'][$i];
    $fileError = $_FILES['files']['error'][$i];
    $fileType = $_FILES['files']['type'][$i];

    // Check for upload errors
    if ($fileError !== UPLOAD_ERR_OK) {
        $errors[] = "Error uploading $fileName: " . getUploadErrorMessage($fileError);
        continue;
    }

    // Validate file size
    if ($fileSize > MAX_UPLOAD_SIZE) {
        $errors[] = "$fileName is too large. Maximum size is " . formatBytes(MAX_UPLOAD_SIZE);
        continue;
    }

    // Sanitize filename
    $sanitizedName = sanitizeFilename($fileName);

    // Validate file type
    if (!isValidMediaFile($sanitizedName)) {
        $errors[] = "$fileName is not a supported file type";
        continue;
    }

    // Generate unique filename if file already exists
    $targetPath = MEDIA_PATH . '/' . $sanitizedName;
    $counter = 1;
    $nameWithoutExt = pathinfo($sanitizedName, PATHINFO_FILENAME);
    $extension = pathinfo($sanitizedName, PATHINFO_EXTENSION);

    while (file_exists($targetPath)) {
        $newName = $nameWithoutExt . '_' . $counter . '.' . $extension;
        $targetPath = MEDIA_PATH . '/' . $newName;
        $counter++;
    }

    $finalFileName = basename($targetPath);

    // Move uploaded file
    if (move_uploaded_file($fileTmpName, $targetPath)) {
        $uploadedFiles[] = [
            'original_name' => $fileName,
            'filename' => $finalFileName,
            'size' => $fileSize,
            'type' => $fileType,
            'path' => $targetPath
        ];

        // Log to database
        try {
            $stmt = $db->prepare("
                INSERT INTO media_history (filename, original_name, file_size, mime_type)
                VALUES (?, ?, ?, ?)
            ");
            $stmt->execute([$finalFileName, $fileName, $fileSize, $fileType]);
        } catch (Exception $e) {
            logMessage("Failed to log media upload: " . $e->getMessage(), 'ERROR');
        }

        logMessage("File uploaded successfully: $finalFileName");
    } else {
        $errors[] = "Failed to move uploaded file: $fileName";
    }
}

// Prepare response
$response = [
    'uploaded_files' => $uploadedFiles,
    'uploaded_count' => count($uploadedFiles),
    'errors' => $errors,
    'error_count' => count($errors)
];

if (count($uploadedFiles) > 0) {
    jsonResponse(true, $response, count($uploadedFiles) . ' file(s) uploaded successfully');
} else {
    jsonResponse(false, $response, 'No files were uploaded successfully');
}

function getUploadErrorMessage($error) {
    switch ($error) {
        case UPLOAD_ERR_INI_SIZE:
            return 'File is too large (php.ini limit)';
        case UPLOAD_ERR_FORM_SIZE:
            return 'File is too large (form limit)';
        case UPLOAD_ERR_PARTIAL:
            return 'File was only partially uploaded';
        case UPLOAD_ERR_NO_FILE:
            return 'No file was uploaded';
        case UPLOAD_ERR_NO_TMP_DIR:
            return 'Missing temporary folder';
        case UPLOAD_ERR_CANT_WRITE:
            return 'Failed to write file to disk';
        case UPLOAD_ERR_EXTENSION:
            return 'File upload stopped by extension';
        default:
            return 'Unknown upload error';
    }
}

function formatBytes($bytes, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];

    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }

    return round($bytes, $precision) . ' ' . $units[$i];
}
?>