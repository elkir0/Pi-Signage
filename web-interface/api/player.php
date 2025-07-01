<?php
/**
 * API de contrôle du player Pi Signage
 */

define('PI_SIGNAGE_WEB', true);
require_once __DIR__ . '/../includes/config.php';
require_once __DIR__ . '/../includes/security.php';

// Démarrer la session avant l'auth
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once __DIR__ . '/../includes/auth.php';

// Vérifier l'authentification
if (!isAuthenticated()) {
    http_response_code(401);
    exit(json_encode(['success' => false, 'message' => 'Unauthorized']));
}

// Headers
header('Content-Type: application/json');

// Gérer les requêtes OPTIONS (CORS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(json_encode(['success' => true]));
}

// POST uniquement
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit(json_encode(['success' => false, 'message' => 'Method not allowed']));
}

// Récupérer les données
$input = json_decode(file_get_contents('php://input'), true);

// Valider l'action
$action = $input['action'] ?? '';
$validActions = ['play', 'pause', 'stop', 'next', 'previous', 'reload', 'update_playlist'];

if (!in_array($action, $validActions)) {
    http_response_code(400);
    exit(json_encode(['success' => false, 'message' => 'Invalid action']));
}

// Log l'action
error_log("Player control action: $action");

$response = ['success' => false];

// Traiter l'action selon le mode d'affichage
if (DISPLAY_MODE === 'chromium') {
    // Mode Chromium : utiliser WebSocket ou contrôle direct
    switch ($action) {
        case 'update_playlist':
            // Mettre à jour la playlist
            if (file_exists('/opt/scripts/update-playlist.sh')) {
                exec('sudo /opt/scripts/update-playlist.sh 2>&1', $output, $returnCode);
                $response['success'] = ($returnCode === 0);
                $response['output'] = implode("\n", $output);
                $response['message'] = $response['success'] ? 'Playlist mise à jour' : 'Échec de la mise à jour';
            } else {
                $response['message'] = 'Script de mise à jour non trouvé';
            }
            break;
            
        case 'reload':
            // Recharger le player Chromium
            exec('sudo /usr/bin/systemctl restart chromium-kiosk.service 2>&1', $output, $returnCode);
            $response['success'] = ($returnCode === 0);
            $response['message'] = $response['success'] ? 'Player redémarré' : 'Échec du redémarrage';
            break;
            
        default:
            // Envoyer la commande via WebSocket au player
            $wsCommand = json_encode(['command' => $action]);
            $wsResult = @file_get_contents('http://localhost:8889', false, stream_context_create([
                'http' => [
                    'method' => 'POST',
                    'header' => "Content-Type: application/json\r\n",
                    'content' => $wsCommand,
                    'timeout' => 2
                ]
            ]));
            
            // Si pas de WebSocket, essayer netcat
            if ($wsResult === false) {
                exec("echo '$wsCommand' | nc -w 1 localhost 8889 2>&1", $output, $returnCode);
                $response['success'] = ($returnCode === 0);
            } else {
                $response['success'] = true;
            }
            $response['message'] = $response['success'] ? 'Commande envoyée' : 'Player non accessible';
            break;
    }
} else {
    // Mode VLC
    switch ($action) {
        case 'update_playlist':
            // Pour VLC, redémarrer le service pour prendre en compte les nouvelles vidéos
            exec('sudo /usr/bin/systemctl restart vlc-signage.service 2>&1', $output, $returnCode);
            $response['success'] = ($returnCode === 0);
            $response['message'] = $response['success'] ? 'VLC redémarré avec la nouvelle playlist' : 'Échec du redémarrage';
            break;
            
        case 'play':
        case 'pause':
        case 'stop':
        case 'next':
        case 'previous':
            // Contrôle VLC via HTTP
            $vlcUrl = sprintf('http://%s:%s/requests/status.xml?command=pl_%s', 
                VLC_HTTP_HOST, 
                VLC_HTTP_PORT, 
                $action === 'previous' ? 'previous' : $action
            );
            
            $context = stream_context_create([
                'http' => [
                    'timeout' => 2,
                    'ignore_errors' => true
                ]
            ]);
            
            $result = @file_get_contents($vlcUrl, false, $context);
            $response['success'] = ($result !== false);
            $response['message'] = $response['success'] ? 'Commande VLC envoyée' : 'VLC non accessible';
            break;
            
        default:
            $response['message'] = 'Action non supportée pour VLC';
            break;
    }
}

echo json_encode($response);