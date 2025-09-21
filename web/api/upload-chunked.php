<?php
/**
 * Upload de fichiers par chunks pour gérer les gros fichiers
 * Supporte la reprise après interruption
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-File-Name, X-Chunk-Index, X-Total-Chunks, X-File-Id');

// Gestion des requêtes OPTIONS (CORS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$uploadDir = '/opt/pisignage/media/';
$tempDir = '/opt/pisignage/temp/';
$chunkDir = $tempDir . 'chunks/';

// Créer les dossiers si nécessaire
if (!is_dir($tempDir)) {
    mkdir($tempDir, 0777, true);
}
if (!is_dir($chunkDir)) {
    mkdir($chunkDir, 0777, true);
}

// Configuration
$maxFileSize = 500 * 1024 * 1024; // 500MB
$allowedExtensions = ['mp4', 'avi', 'mkv', 'mov', 'webm', 'jpg', 'jpeg', 'png', 'gif', 'bmp'];
$allowedMimeTypes = [
    'video/mp4', 'video/x-msvideo', 'video/x-matroska', 'video/webm', 'video/quicktime',
    'image/jpeg', 'image/png', 'image/gif', 'image/bmp'
];

/**
 * Nettoyer les vieux chunks (plus de 24h)
 */
function cleanOldChunks($chunkDir) {
    $now = time();
    $maxAge = 24 * 60 * 60; // 24 heures
    
    $dirs = glob($chunkDir . '*', GLOB_ONLYDIR);
    foreach ($dirs as $dir) {
        if (filemtime($dir) < ($now - $maxAge)) {
            array_map('unlink', glob($dir . '/*'));
            rmdir($dir);
        }
    }
}

// Nettoyer les vieux chunks à chaque requête
cleanOldChunks($chunkDir);

$action = $_GET['action'] ?? 'upload';

switch ($action) {
    case 'check':
        // Vérifier l'état d'un upload en cours
        $fileId = $_GET['fileId'] ?? '';
        
        if (!$fileId || !preg_match('/^[a-zA-Z0-9_-]+$/', $fileId)) {
            echo json_encode(['error' => 'ID de fichier invalide']);
            exit;
        }
        
        $fileChunkDir = $chunkDir . $fileId . '/';
        
        if (is_dir($fileChunkDir)) {
            $chunks = glob($fileChunkDir . 'chunk_*');
            $uploadedChunks = array_map(function($chunk) {
                return intval(str_replace('chunk_', '', basename($chunk)));
            }, $chunks);
            
            echo json_encode([
                'success' => true,
                'uploadedChunks' => $uploadedChunks,
                'totalUploaded' => count($uploadedChunks)
            ]);
        } else {
            echo json_encode([
                'success' => true,
                'uploadedChunks' => [],
                'totalUploaded' => 0
            ]);
        }
        break;
        
    case 'upload':
        // Upload d'un chunk
        $fileName = $_SERVER['HTTP_X_FILE_NAME'] ?? '';
        $chunkIndex = intval($_SERVER['HTTP_X_CHUNK_INDEX'] ?? 0);
        $totalChunks = intval($_SERVER['HTTP_X_TOTAL_CHUNKS'] ?? 1);
        $fileId = $_SERVER['HTTP_X_FILE_ID'] ?? '';
        
        // Validation
        if (!$fileName || !$fileId) {
            echo json_encode(['error' => 'Paramètres manquants']);
            exit;
        }
        
        // Nettoyer le nom de fichier
        $fileName = preg_replace('/[^a-zA-Z0-9._-]/', '_', $fileName);
        
        // Vérifier l'extension
        $ext = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
        if (!in_array($ext, $allowedExtensions)) {
            echo json_encode(['error' => 'Type de fichier non autorisé']);
            exit;
        }
        
        // Créer le dossier pour ce fichier
        $fileChunkDir = $chunkDir . $fileId . '/';
        if (!is_dir($fileChunkDir)) {
            mkdir($fileChunkDir, 0777, true);
        }
        
        // Récupérer le chunk
        $chunkData = file_get_contents('php://input');
        if (!$chunkData) {
            echo json_encode(['error' => 'Aucune donnée reçue']);
            exit;
        }
        
        // Sauvegarder le chunk
        $chunkFile = $fileChunkDir . 'chunk_' . $chunkIndex;
        if (file_put_contents($chunkFile, $chunkData) === false) {
            echo json_encode(['error' => 'Impossible d\'écrire le chunk']);
            exit;
        }
        
        // Vérifier si tous les chunks sont présents
        $uploadComplete = true;
        for ($i = 0; $i < $totalChunks; $i++) {
            if (!file_exists($fileChunkDir . 'chunk_' . $i)) {
                $uploadComplete = false;
                break;
            }
        }
        
        if ($uploadComplete) {
            // Assembler le fichier
            $finalPath = $uploadDir . $fileName;
            
            // Si le fichier existe déjà, ajouter un timestamp
            if (file_exists($finalPath)) {
                $info = pathinfo($fileName);
                $fileName = $info['filename'] . '_' . time() . '.' . $info['extension'];
                $finalPath = $uploadDir . $fileName;
            }
            
            // Assembler tous les chunks
            $outputFile = fopen($finalPath, 'wb');
            if (!$outputFile) {
                echo json_encode(['error' => 'Impossible de créer le fichier final']);
                exit;
            }
            
            for ($i = 0; $i < $totalChunks; $i++) {
                $chunkPath = $fileChunkDir . 'chunk_' . $i;
                $chunkContent = file_get_contents($chunkPath);
                fwrite($outputFile, $chunkContent);
                unlink($chunkPath); // Supprimer le chunk après assemblage
            }
            
            fclose($outputFile);
            
            // Supprimer le dossier des chunks
            rmdir($fileChunkDir);
            
            // Vérifier le type MIME du fichier final
            $finfo = finfo_open(FILEINFO_MIME_TYPE);
            $mimeType = finfo_file($finfo, $finalPath);
            finfo_close($finfo);
            
            // Pour certains formats vidéo, le MIME peut être application/octet-stream
            if ($mimeType === 'application/octet-stream' && in_array($ext, ['mp4', 'avi', 'mkv', 'mov', 'webm'])) {
                // Accepter basé sur l'extension pour les vidéos
                $mimeType = 'video/' . $ext;
            }
            
            // Obtenir les infos sur le fichier
            $fileSize = filesize($finalPath);
            
            // Obtenir la liste des médias mise à jour
            $mediaFiles = [];
            $extensions = array_merge(
                ['mp4', 'avi', 'mkv', 'mov', 'webm'],
                ['jpg', 'jpeg', 'png', 'gif', 'bmp']
            );
            
            foreach ($extensions as $ext) {
                $files = glob($uploadDir . '*.' . $ext);
                foreach ($files as $file) {
                    $mediaFiles[] = [
                        'name' => basename($file),
                        'size' => filesize($file),
                        'type' => in_array($ext, ['mp4', 'avi', 'mkv', 'mov', 'webm']) ? 'video' : 'image',
                        'modified' => date('Y-m-d H:i:s', filemtime($file))
                    ];
                }
            }
            
            echo json_encode([
                'success' => true,
                'complete' => true,
                'message' => 'Upload terminé avec succès',
                'filename' => $fileName,
                'size' => $fileSize,
                'mimeType' => $mimeType,
                'files' => $mediaFiles
            ]);
            
        } else {
            // Chunk reçu mais upload pas encore complet
            echo json_encode([
                'success' => true,
                'complete' => false,
                'chunkIndex' => $chunkIndex,
                'totalChunks' => $totalChunks,
                'message' => "Chunk $chunkIndex/$totalChunks reçu"
            ]);
        }
        break;
        
    case 'cancel':
        // Annuler un upload et nettoyer
        $fileId = $_POST['fileId'] ?? '';
        
        if (!$fileId || !preg_match('/^[a-zA-Z0-9_-]+$/', $fileId)) {
            echo json_encode(['error' => 'ID de fichier invalide']);
            exit;
        }
        
        $fileChunkDir = $chunkDir . $fileId . '/';
        
        if (is_dir($fileChunkDir)) {
            // Supprimer tous les chunks
            array_map('unlink', glob($fileChunkDir . '/*'));
            rmdir($fileChunkDir);
            
            echo json_encode([
                'success' => true,
                'message' => 'Upload annulé'
            ]);
        } else {
            echo json_encode([
                'success' => true,
                'message' => 'Aucun upload en cours'
            ]);
        }
        break;
        
    default:
        echo json_encode(['error' => 'Action non reconnue']);
}