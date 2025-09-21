<?php
header("Content-Type: application/json");
header('Access-Control-Allow-Origin: *');

// Liste blanche des actions autorisées
$allowedActions = ['status', 'start', 'stop', 'delete', 'upload'];
$action = $_GET["action"] ?? $_POST["action"] ?? "status";

// Validation de l'action
if (!in_array($action, $allowedActions)) {
    http_response_code(400);
    echo json_encode(["error" => "Action non autorisée"]);
    exit;
}

switch($action) {
    case "status":
        $status = shell_exec(escapeshellcmd("/opt/pisignage/scripts/vlc-control.sh") . " status");
        echo json_encode(["status" => trim($status)]);
        break;
        
    case "start":
        shell_exec(escapeshellcmd("/opt/pisignage/scripts/vlc-control.sh") . " start");
        echo json_encode(["status" => "started"]);
        break;
        
    case "stop":
        shell_exec(escapeshellcmd("/opt/pisignage/scripts/vlc-control.sh") . " stop");
        echo json_encode(["status" => "stopped"]);
        break;
        
    case "delete":
        // Récupérer le nom du fichier depuis POST (video) ou GET (file)
        $filename = $_POST["video"] ?? $_GET["file"] ?? "";
        
        if (empty($filename)) {
            echo json_encode([
                "success" => false,
                "error" => "Aucun fichier spécifié",
                "debug" => "POST: " . json_encode($_POST) . ", GET: " . json_encode($_GET)
            ]);
            break;
        }
        
        // Sécurité : validation stricte du nom de fichier
        $filename = basename($filename);
        // Validation : caractères autorisés seulement
        if (!preg_match('/^[a-zA-Z0-9._-]+$/', $filename)) {
            echo json_encode([
                "success" => false,
                "error" => "Nom de fichier invalide"
            ]);
            break;
        }
        $filepath = "/opt/pisignage/media/" . $filename;
        
        // Vérification supplémentaire : s'assurer qu'on reste dans le bon dossier
        $realpath = realpath($filepath);
        $mediaDir = realpath("/opt/pisignage/media/");
        if ($realpath === false || strpos($realpath, $mediaDir) !== 0) {
            echo json_encode([
                "success" => false,
                "error" => "Chemin de fichier invalide"
            ]);
            break;
        }
        
        // Vérifier que le fichier existe
        if (!file_exists($filepath)) {
            echo json_encode([
                "success" => false,
                "error" => "Fichier non trouvé: " . $filename
            ]);
            break;
        }
        
        // Supprimer le fichier
        if (unlink($filepath)) {
            // Log pour debug
            error_log("[DELETE] Fichier supprimé: " . $filepath);
            
            echo json_encode([
                "success" => true,
                "status" => "deleted",
                "message" => "Fichier supprimé avec succès",
                "file" => $filename
            ]);
        } else {
            echo json_encode([
                "success" => false,
                "error" => "Impossible de supprimer le fichier",
                "file" => $filename
            ]);
        }
        break;
        
    case "upload":
        header("Access-Control-Allow-Origin: *");
        
        if (!isset($_FILES["video"])) {
            echo json_encode([
                "status" => "error",
                "message" => "Aucun fichier reçu"
            ]);
            exit;
        }
        
        $uploadDir = "/opt/pisignage/media/";
        $uploadedFile = $_FILES["video"];
        
        // Validation du nom de fichier
        $fileName = basename($uploadedFile["name"]);
        // Remplacer les caractères non autorisés
        $fileName = preg_replace('/[^a-zA-Z0-9._-]/', '_', $fileName);
        
        // Vérification de l'extension
        $allowedExtensions = ['mp4', 'avi', 'mkv', 'webm', 'mov', 'jpg', 'jpeg', 'png', 'gif'];
        $fileExtension = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
        if (!in_array($fileExtension, $allowedExtensions)) {
            echo json_encode([
                "status" => "error",
                "message" => "Type de fichier non autorisé"
            ]);
            exit;
        }
        
        // Vérification du type MIME
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $uploadedFile["tmp_name"]);
        finfo_close($finfo);
        
        $allowedMimeTypes = [
            'video/mp4', 'video/x-msvideo', 'video/x-matroska', 'video/webm', 'video/quicktime',
            'image/jpeg', 'image/png', 'image/gif'
        ];
        
        if (!in_array($mimeType, $allowedMimeTypes)) {
            echo json_encode([
                "status" => "error",
                "message" => "Type MIME non autorisé: " . $mimeType
            ]);
            exit;
        }
        
        $targetPath = $uploadDir . $fileName;
        
        // Vérifier les erreurs d'upload
        if ($uploadedFile["error"] !== UPLOAD_ERR_OK) {
            echo json_encode([
                "status" => "error",
                "message" => "Erreur d'upload: " . $uploadedFile["error"],
                "details" => [
                    "error_code" => $uploadedFile["error"],
                    "max_upload_size" => ini_get("upload_max_filesize"),
                    "max_post_size" => ini_get("post_max_size")
                ]
            ]);
            exit;
        }
        
        // Déplacer le fichier uploadé
        if (move_uploaded_file($uploadedFile["tmp_name"], $targetPath)) {
            // Donner les bonnes permissions
            chmod($targetPath, 0666);
            chown($targetPath, "www-data");
            chgrp($targetPath, "www-data");
            
            echo json_encode([
                "status" => "success",
                "message" => "Fichier uploadé avec succès",
                "filename" => $fileName,
                "size" => $uploadedFile["size"]
            ]);
        } else {
            echo json_encode([
                "status" => "error",
                "message" => "Impossible de déplacer le fichier"
            ]);
        }
        break;

    default:
        echo json_encode(["error" => "Action invalide: " . $action]);
}