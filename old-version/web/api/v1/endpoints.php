<?php
/**
 * PiSignage Desktop v3.0 - API REST Endpoints
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Gérer les requêtes OPTIONS (CORS preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

define('PISIGNAGE_DESKTOP', true);
require_once '../../includes/config.php';
require_once '../../includes/functions.php';

/**
 * Retourner une réponse JSON
 */
function jsonResponse($success, $data = null, $message = '', $code = 200) {
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'data' => $data,
        'message' => $message,
        'timestamp' => date('c')
    ]);
    exit;
}

/**
 * Authentification basique pour l'API
 */
function apiAuth() {
    // Pour simplicité, on accepte un token basic ou pas d'auth du tout
    // En production, implémenter un système de tokens JWT
    return true;
}

// Obtenir l'action depuis la query string ou le body
$action = $_GET['action'] ?? $_POST['action'] ?? '';
$method = $_SERVER['REQUEST_METHOD'];

try {
    switch ($action) {
        
        // Informations système
        case 'system_info':
            if ($method !== 'GET') {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            
            $systemInfo = getSystemInfo();
            
            // Ajouter des infos supplémentaires
            $systemInfo['uptime'] = trim(shell_exec('uptime -p 2>/dev/null') ?: 'Inconnu');
            $systemInfo['ip'] = trim(shell_exec("ip route get 1 2>/dev/null | awk '{print $7}' | head -1") ?: 'Inconnu');
            $systemInfo['version'] = APP_VERSION;
            $systemInfo['mode'] = DISPLAY_MODE;
            
            jsonResponse(true, $systemInfo);
            break;
            
        // Statut des services
        case 'service_status':
            if ($method !== 'GET') {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            
            $services = [
                'pisignage' => checkServiceStatus(PISIGNAGE_SERVICE),
                'nginx' => checkServiceStatus('nginx')
            ];
            
            jsonResponse(true, $services);
            break;
            
        // Contrôle des services
        case 'service_control':
            if ($method !== 'POST') {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            
            $input = json_decode(file_get_contents('php://input'), true);
            $service = $input['service'] ?? '';
            $service_action = $input['action'] ?? '';
            
            if (empty($service) || empty($service_action)) {
                jsonResponse(false, null, 'Service et action requis', 400);
            }
            
            $result = controlService($service, $service_action);
            jsonResponse($result['success'], $result, $result['message']);
            break;
            
        // Liste des vidéos
        case 'videos':
            if ($method !== 'GET') {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            
            $videos = listVideos();
            jsonResponse(true, $videos);
            break;
            
        // Playlist
        case 'playlist':
            if ($method === 'GET') {
                $playlist = loadPlaylist();
                jsonResponse(true, $playlist);
            } elseif ($method === 'POST') {
                $input = json_decode(file_get_contents('php://input'), true);
                if (!is_array($input)) {
                    jsonResponse(false, null, 'Données playlist invalides', 400);
                }
                
                $success = savePlaylist($input);
                jsonResponse($success, null, $success ? 'Playlist sauvegardée' : 'Erreur de sauvegarde');
            } else {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            break;
            
        // Contrôle du player
        case 'player_control':
            if ($method !== 'POST') {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            
            $input = json_decode(file_get_contents('php://input'), true);
            $player_action = $input['action'] ?? '';
            
            if (empty($player_action)) {
                jsonResponse(false, null, 'Action requise', 400);
            }
            
            $result = controlPlayer($player_action);
            jsonResponse($result['success'], null, $result['message']);
            break;
            
        // Téléchargement YouTube
        case 'youtube_download':
            if ($method !== 'POST') {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            
            $input = json_decode(file_get_contents('php://input'), true);
            $url = $input['url'] ?? '';
            
            if (empty($url)) {
                jsonResponse(false, null, 'URL requise', 400);
            }
            
            $result = downloadYouTubeVideo($url);
            jsonResponse($result['success'], null, $result['message']);
            break;
            
        // Suppression de vidéo
        case 'delete_video':
            if ($method !== 'DELETE' && $method !== 'POST') {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            
            $input = json_decode(file_get_contents('php://input'), true);
            $filename = $input['filename'] ?? $_POST['filename'] ?? '';
            
            if (empty($filename)) {
                jsonResponse(false, null, 'Nom de fichier requis', 400);
            }
            
            $result = deleteVideo($filename);
            jsonResponse($result['success'], null, $result['message']);
            break;
            
        // Upload de vidéo (pour les apps mobiles)
        case 'upload_video':
            if ($method !== 'POST') {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            
            if (!isset($_FILES['video'])) {
                jsonResponse(false, null, 'Fichier vidéo requis', 400);
            }
            
            $result = handleVideoUpload($_FILES['video']);
            jsonResponse($result['success'], $result, $result['message']);
            break;
            
        // Reboot système (dangereux - à sécuriser)
        case 'system_reboot':
            if ($method !== 'POST') {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            
            // Vérification d'auth plus stricte pour cette action
            if (!apiAuth()) {
                jsonResponse(false, null, 'Non autorisé', 401);
            }
            
            // Programmer un reboot dans 5 secondes
            shell_exec('sudo shutdown -r +1 "Reboot via API" 2>/dev/null &');
            jsonResponse(true, null, 'Reboot programmé dans 1 minute');
            break;
            
        // Stats rapides pour mobile
        case 'stats':
            if ($method !== 'GET') {
                jsonResponse(false, null, 'Méthode non autorisée', 405);
            }
            
            $systemInfo = getSystemInfo();
            $videos = listVideos();
            $playlist = loadPlaylist();
            $serviceStatus = checkServiceStatus(PISIGNAGE_SERVICE);
            
            $stats = [
                'cpu_percent' => $systemInfo['cpu_percent'] ?? 0,
                'memory_percent' => $systemInfo['memory']['percent'] ?? 0,
                'disk_percent' => $systemInfo['disk']['percent'] ?? 0,
                'temperature' => $systemInfo['temperature'] ?? null,
                'video_count' => count($videos),
                'playlist_count' => count($playlist),
                'service_active' => $serviceStatus['active'],
                'disk_free' => formatBytes($systemInfo['disk']['free'] ?? 0)
            ];
            
            jsonResponse(true, $stats);
            break;
            
        // Action non reconnue
        default:
            jsonResponse(false, null, 'Action non reconnue', 404);
            break;
    }
    
} catch (Exception $e) {
    error_log("API Error: " . $e->getMessage());
    jsonResponse(false, null, 'Erreur interne du serveur', 500);
}
?>