<?php
header("Content-Type: application/json");
header('Access-Control-Allow-Origin: *');

$action = $_GET["action"] ?? $_POST["action"] ?? "status";

switch($action) {
    case "status":
        $status = shell_exec("/opt/pisignage/scripts/vlc-control.sh status");
        echo json_encode(["status" => trim($status)]);
        break;
        
    case "start":
        shell_exec("/opt/pisignage/scripts/vlc-control.sh start");
        echo json_encode(["status" => "started"]);
        break;
        
    case "stop":
        shell_exec("/opt/pisignage/scripts/vlc-control.sh stop");
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
        
        // Sécurité : nettoyer le nom de fichier
        $filename = basename($filename);
        $filepath = "/opt/pisignage/media/" . $filename;
        
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
                "file" => $filename,
                "path" => $filepath
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
        $fileName = basename($uploadedFile["name"]);
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
                "size" => $uploadedFile["size"],
                "path" => $targetPath
            ]);
        } else {
            echo json_encode([
                "status" => "error",
                "message" => "Impossible de déplacer le fichier",
                "details" => [
                    "tmp_name" => $uploadedFile["tmp_name"],
                    "target" => $targetPath,
                    "upload_dir_writable" => is_writable($uploadDir),
                    "upload_dir_exists" => is_dir($uploadDir)
                ]
            ]);
        }
        break;

    default:
        echo json_encode(["error" => "Action invalide: " . $action]);
}