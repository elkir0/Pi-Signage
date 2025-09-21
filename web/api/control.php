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
        
    default:
        echo json_encode(["error" => "Action invalide: " . $action]);
}