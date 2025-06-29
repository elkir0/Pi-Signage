<?php
/**
 * Pi Signage Digital - API Status
 * Endpoint pour récupérer le statut du système
 * @version 2.0.0
 */

// Headers pour l'API
header('Content-Type: application/json');
header('Cache-Control: no-cache, must-revalidate');

// Inclure la configuration
define('INCLUDED', true);
require_once '../includes/config.php';
require_once '../includes/functions.php';

// Vérifier l'authentification (optionnel pour certains endpoints)
session_start();
$authenticated = isset($_SESSION['user']) && isset($_SESSION['login_time']);

// Si pas authentifié, retourner seulement les infos publiques
if (!$authenticated) {
    http_response_code(401);
    echo json_encode([
        'error' => 'Non authentifié',
        'message' => 'Authentification requise pour accéder aux données complètes'
    ]);
    exit;
}

try {
    // Récupérer les informations système
    $systemInfo = getSystemInfo();
    $diskUsage = getDiskUsage();
    $services = getServicesStatus();
    $videos = getVideoList();
    
    // Construire la réponse
    $response = [
        'timestamp' => date('c'),
        'hostname' => gethostname(),
        'uptime' => $systemInfo['uptime'],
        'services' => [
            'vlc' => [
                'status' => $services['vlc'] ?? false,
                'name' => 'VLC Media Player',
                'service' => 'vlc-signage.service'
            ],
            'glances' => [
                'status' => $services['glances'] ?? false,
                'name' => 'Glances Monitoring',
                'service' => 'glances.service'
            ],
            'lightdm' => [
                'status' => $services['lightdm'] ?? false,
                'name' => 'Display Manager',
                'service' => 'lightdm.service'
            ],
            'watchdog' => [
                'status' => $services['watchdog'] ?? false,
                'name' => 'System Watchdog',
                'service' => 'pi-signage-watchdog.service'
            ]
        ],
        'system' => [
            'cpu_usage' => $systemInfo['cpu_usage'],
            'memory_usage' => $systemInfo['memory_usage'],
            'temperature' => $systemInfo['temperature'],
            'load_average' => sys_getloadavg()
        ],
        'storage' => [
            'total' => $diskUsage['total'],
            'used' => $diskUsage['used'],
            'free' => $diskUsage['free'],
            'percent' => $diskUsage['percent'],
            'videos_count' => count($videos),
            'videos_size' => array_sum(array_column($videos, 'size'))
        ],
        'network' => [
            'ip_address' => $_SERVER['SERVER_ADDR'] ?? 'unknown',
            'google_drive_configured' => file_exists('/home/signage/.config/rclone/rclone.conf')
        ],
        'last_sync' => null,
        'version' => VERSION
    ];
    
    // Ajouter l'heure de la dernière synchronisation si disponible
    $syncLogFile = LOG_DIR . '/sync.log';
    if (file_exists($syncLogFile)) {
        $lastModified = filemtime($syncLogFile);
        $response['last_sync'] = date('c', $lastModified);
    }
    
    // Retourner la réponse JSON
    echo json_encode($response, JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Erreur serveur',
        'message' => 'Impossible de récupérer le statut du système',
        'details' => $e->getMessage()
    ]);
}