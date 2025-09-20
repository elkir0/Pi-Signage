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
    default:
        echo json_encode(["error" => "Invalid action"]);
}
