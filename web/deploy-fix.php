<?php
// Script de déploiement temporaire
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'GET' || !isset($_GET['confirm'])) {
    die(json_encode(['message' => 'Access /deploy-fix.php?confirm=yes to deploy']));
}

$playerControlContent = file_get_contents('http://192.168.1.105:8000/web/api/player-control.php');

if ($playerControlContent) {
    file_put_contents('/opt/pisignage/web/api/player-control.php', $playerControlContent);
    echo json_encode(['success' => true, 'message' => 'player-control.php deployed']);
} else {
    echo json_encode(['success' => false, 'message' => 'Failed to fetch file']);
}
?>