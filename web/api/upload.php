<?php
require_once "/opt/pisignage/web/config.php";

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(false, null, 'Only POST method allowed');
}

if (!isset($_FILES['files']) || empty($_FILES['files']['name'][0])) {
    jsonResponse(false, null, 'No files uploaded');
}

$uploadedFiles = [];
$errors = [];

$fileCount = count($_FILES['files']['name']);

for ($i = 0; $i < $fileCount; $i++) {
    $fileName = $_FILES['files']['name'][$i];
    $fileTmpName = $_FILES['files']['tmp_name'][$i];
    $fileSize = $_FILES['files']['size'][$i];
    $fileError = $_FILES['files']['error'][$i];
    $fileType = $_FILES['files']['type'][$i];

    if ($fileError !== UPLOAD_ERR_OK) {
        $errors[] = "Error uploading $fileName: Upload error code $fileError";
        continue;
    }

    if ($fileSize > MAX_UPLOAD_SIZE) {
        $errors[] = "$fileName is too large. Maximum size is 500MB";
        continue;
    }

    $sanitizedName = sanitizeFilename($fileName);
    
    if (!isValidMediaFile($sanitizedName)) {
        $errors[] = "$fileName is not a supported file type";
        continue;
    }

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

    if (move_uploaded_file($fileTmpName, $targetPath)) {
        $uploadedFiles[] = [
            'original_name' => $fileName,
            'filename' => $finalFileName,
            'size' => $fileSize,
            'type' => $fileType,
            'path' => $targetPath
        ];
        
        logMessage("File uploaded: $finalFileName");
    } else {
        $errors[] = "Failed to move uploaded file: $fileName";
    }
}

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
?>
