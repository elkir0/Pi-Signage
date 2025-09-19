<?php
// PiSignage API Control
// Version: 1.0

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST');
header('Access-Control-Allow-Headers: Content-Type');

// Configuration
$player_script = '/opt/pisignage/player-control.sh';
$media_dir = '/opt/pisignage/media';
$log_file = '/opt/pisignage/logs/api.log';

// Fonction de logging
function log_message($message) {
    global $log_file;
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($log_file, "[$timestamp] $message\n", FILE_APPEND | LOCK_EX);
}

// Fonction pour exécuter des commandes système
function execute_command($command) {
    $output = [];
    $return_code = 0;
    exec($command . ' 2>&1', $output, $return_code);
    return [
        'output' => implode("\n", $output),
        'return_code' => $return_code,
        'success' => $return_code === 0
    ];
}

// Fonction pour vérifier le statut du système
function check_system_status() {
    global $player_script;
    $result = execute_command("$player_script status");
    return [
        'status' => strpos($result['output'], 'actif') !== false ? 'online' : 'offline',
        'message' => $result['output']
    ];
}

// Fonction pour contrôler le lecteur
function control_player($command) {
    global $player_script;
    $allowed_commands = ['start', 'stop', 'restart', 'status'];
    
    if (!in_array($command, $allowed_commands)) {
        return [
            'success' => false,
            'message' => 'Commande non autorisée'
        ];
    }
    
    $result = execute_command("$player_script $command");
    log_message("Player command: $command - " . ($result['success'] ? 'SUCCESS' : 'FAILED'));
    
    return [
        'success' => $result['success'],
        'message' => $result['output']
    ];
}

// Fonction pour lister les médias
function list_media() {
    global $media_dir;
    $files = [];
    
    if (is_dir($media_dir)) {
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($media_dir, RecursiveDirectoryIterator::SKIP_DOTS)
        );
        
        foreach ($iterator as $file) {
            if ($file->isFile()) {
                $ext = strtolower(pathinfo($file->getFilename(), PATHINFO_EXTENSION));
                $allowed_exts = ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'avi', 'mkv', 'mov'];
                
                if (in_array($ext, $allowed_exts)) {
                    $files[] = [
                        'name' => $file->getFilename(),
                        'path' => $file->getPathname(),
                        'size' => $file->getSize(),
                        'type' => in_array($ext, ['mp4', 'avi', 'mkv', 'mov']) ? 'video' : 'image',
                        'modified' => date('Y-m-d H:i:s', $file->getMTime())
                    ];
                }
            }
        }
    }
    
    return $files;
}

// Traitement des requêtes
$action = $_GET['action'] ?? $_POST['action'] ?? '';

try {
    switch ($action) {
        case 'status':
            $response = check_system_status();
            break;
            
        case 'player':
            $command = $_GET['command'] ?? $_POST['command'] ?? '';
            $response = control_player($command);
            break;
            
        case 'media':
            $response = [
                'success' => true,
                'files' => list_media()
            ];
            break;
            
        case 'play':
            $file = $_GET['file'] ?? $_POST['file'] ?? '';
            if (empty($file)) {
                $response = [
                    'success' => false,
                    'message' => 'Fichier non spécifié'
                ];
            } else {
                $file_path = $media_dir . '/' . basename($file);
                if (file_exists($file_path)) {
                    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
                    if (in_array($ext, ['mp4', 'avi', 'mkv', 'mov'])) {
                        $result = execute_command("$player_script play-video '$file_path'");
                    } else {
                        $duration = $_GET['duration'] ?? $_POST['duration'] ?? 10;
                        $result = execute_command("$player_script play-image '$file_path' $duration");
                    }
                    
                    $response = [
                        'success' => $result['success'],
                        'message' => $result['output']
                    ];
                    
                    log_message("Play file: $file - " . ($result['success'] ? 'SUCCESS' : 'FAILED'));
                } else {
                    $response = [
                        'success' => false,
                        'message' => 'Fichier introuvable'
                    ];
                }
            }
            break;
            
        default:
            $response = [
                'success' => false,
                'message' => 'Action non reconnue'
            ];
            break;
    }
    
} catch (Exception $e) {
    log_message("API Error: " . $e->getMessage());
    $response = [
        'success' => false,
        'message' => 'Erreur interne du serveur'
    ];
}

echo json_encode($response, JSON_PRETTY_PRINT);
?>