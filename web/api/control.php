<?php
header("Content-Type: application/json");

$action = $_GET["action"] ?? "status";

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
        $filename = $_GET["file"] ?? "";
        if (empty($filename)) {
            echo json_encode(["error" => "No filename provided"]);
            break;
        }
        
        // Sécurité : s'assurer que le nom de fichier ne contient pas de caractères dangereux
        $filename = basename($filename);
        $filepath = "/opt/pisignage/media/" . $filename;
        
        if (!file_exists($filepath)) {
            echo json_encode(["error" => "File not found"]);
            break;
        }
        
        if (unlink($filepath)) {
            echo json_encode(["status" => "deleted", "file" => $filename]);
        } else {
            echo json_encode(["error" => "Failed to delete file"]);
        }
        break;
    default:
        echo json_encode(["error" => "Invalid action"]);
}
