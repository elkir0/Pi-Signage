<?php
/**
 * Pi Signage Digital - Fonctions utilitaires
 * @version 2.0.0
 */

// Empêcher l'accès direct
if (!defined('INCLUDED')) {
    define('INCLUDED', true);
}

/**
 * Vérifier l'authentification
 */
function authenticate($username, $password) {
    return $username === ADMIN_USER && password_verify($password, ADMIN_PASSWORD_HASH);
}

/**
 * Vérifier si l'utilisateur est connecté
 */
function isLoggedIn() {
    return isset($_SESSION['user']) && 
           isset($_SESSION['login_time']) && 
           (time() - $_SESSION['login_time']) < SESSION_TIMEOUT;
}

/**
 * Récupérer la liste des vidéos
 */
function getVideoList() {
    $videos = [];
    
    if (!is_dir(VIDEO_DIR)) {
        return $videos;
    }
    
    $files = scandir(VIDEO_DIR);
    foreach ($files as $file) {
        if ($file === '.' || $file === '..') continue;
        
        $extension = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        if (in_array($extension, ALLOWED_VIDEO_FORMATS)) {
            $filepath = VIDEO_DIR . '/' . $file;
            $videos[] = [
                'name' => $file,
                'path' => $filepath,
                'size' => filesize($filepath),
                'modified' => filemtime($filepath),
                'extension' => $extension
            ];
        }
    }
    
    // Trier par date de modification décroissante
    usort($videos, function($a, $b) {
        return $b['modified'] - $a['modified'];
    });
    
    return $videos;
}

/**
 * Supprimer une vidéo
 */
function deleteVideo($videoPath) {
    // Sécurité : vérifier que le fichier est dans VIDEO_DIR
    $realPath = realpath($videoPath);
    $videoDir = realpath(VIDEO_DIR);
    
    if (!$realPath || strpos($realPath, $videoDir) !== 0) {
        return false;
    }
    
    // Vérifier que c'est bien une vidéo
    $extension = strtolower(pathinfo($realPath, PATHINFO_EXTENSION));
    if (!in_array($extension, ALLOWED_VIDEO_FORMATS)) {
        return false;
    }
    
    // Supprimer le fichier
    if (file_exists($realPath)) {
        unlink($realPath);
        
        // Redémarrer VLC pour prendre en compte le changement
        restartVLC();
        
        return true;
    }
    
    return false;
}

/**
 * Obtenir les informations système
 */
function getSystemInfo() {
    $info = [
        'cpu_usage' => 0,
        'memory_usage' => 0,
        'temperature' => 0,
        'uptime' => 'N/A'
    ];
    
    // CPU Usage
    $load = sys_getloadavg();
    $cores = trim(shell_exec("nproc"));
    $info['cpu_usage'] = round(($load[0] / $cores) * 100, 1);
    
    // Memory Usage
    $free = shell_exec("free");
    $free = (string)trim($free);
    $free_arr = explode("\n", $free);
    $mem = explode(" ", preg_replace('/\s+/', ' ', $free_arr[1]));
    $info['memory_usage'] = round(($mem[2] / $mem[1]) * 100, 1);
    
    // Temperature
    $temp_file = '/sys/class/thermal/thermal_zone0/temp';
    if (file_exists($temp_file)) {
        $temp = intval(file_get_contents($temp_file));
        $info['temperature'] = round($temp / 1000, 1);
    }
    
    // Uptime
    $uptime_seconds = floatval(explode(' ', file_get_contents('/proc/uptime'))[0]);
    $days = floor($uptime_seconds / 86400);
    $hours = floor(($uptime_seconds % 86400) / 3600);
    $minutes = floor(($uptime_seconds % 3600) / 60);
    
    if ($days > 0) {
        $info['uptime'] = "{$days}j {$hours}h {$minutes}m";
    } elseif ($hours > 0) {
        $info['uptime'] = "{$hours}h {$minutes}m";
    } else {
        $info['uptime'] = "{$minutes}m";
    }
    
    return $info;
}

/**
 * Obtenir l'utilisation du disque
 */
function getDiskUsage() {
    $df = disk_free_space('/');
    $dt = disk_total_space('/');
    $du = $dt - $df;
    
    return [
        'total' => $dt,
        'used' => $du,
        'free' => $df,
        'percent' => round(($du / $dt) * 100)
    ];
}

/**
 * Vérifier l'état des services
 */
function getServicesStatus() {
    $status = [];
    
    foreach (MONITORED_SERVICES as $name => $service) {
        $output = shell_exec("systemctl is-active {$service} 2>&1");
        $status[$name] = (trim($output) === 'active');
    }
    
    return $status;
}

/**
 * Vérifier l'état d'un service spécifique
 */
function checkServiceStatus($service) {
    $serviceName = MONITORED_SERVICES[$service] ?? $service;
    $output = shell_exec("systemctl is-active {$serviceName} 2>&1");
    return trim($output) === 'active';
}

/**
 * Redémarrer VLC
 */
function restartVLC() {
    $command = "sudo /usr/bin/systemctl restart vlc-signage.service 2>&1";
    $output = shell_exec($command);
    
    // Log l'action
    logAction('VLC restart', $output);
    
    // Attendre un peu pour que le service démarre
    sleep(2);
    
    return checkServiceStatus('vlc');
}

/**
 * Synchroniser les vidéos depuis Google Drive
 */
function syncVideos() {
    $command = "sudo /opt/scripts/sync-videos.sh 2>&1 &";
    $output = shell_exec($command);
    
    logAction('Manual sync triggered', $output);
    
    return true;
}

/**
 * Télécharger une vidéo YouTube
 */
function downloadYouTubeVideo($url, $quality = '720p') {
    // Validation de l'URL
    if (!filter_var($url, FILTER_VALIDATE_URL)) {
        return ['success' => false, 'error' => 'URL invalide'];
    }
    
    // Configuration de la qualité
    $format = match($quality) {
        '480p' => 'best[height<=480]/best',
        '720p' => 'best[height<=720]/best',
        '1080p' => 'best[height<=1080]/best',
        default => 'best'
    };
    
    // Construire la commande yt-dlp
    $cmd = sprintf(
        '%s -f "%s" -o "%s/%%(title)s.%%(ext)s" --restrict-filenames --no-playlist --no-overwrites "%s" 2>&1',
        YTDLP_BIN,
        $format,
        VIDEO_DIR,
        escapeshellarg($url)
    );
    
    // Log de démarrage
    logAction('YouTube download started', "URL: $url, Quality: $quality");
    
    // Exécuter le téléchargement
    $output = [];
    $return_var = 0;
    exec($cmd, $output, $return_var);
    
    if ($return_var === 0) {
        // Succès - redémarrer VLC pour prendre en compte la nouvelle vidéo
        restartVLC();
        
        return [
            'success' => true,
            'message' => 'Vidéo téléchargée avec succès'
        ];
    } else {
        // Erreur
        $error = implode("\n", $output);
        logAction('YouTube download error', $error);
        
        return [
            'success' => false,
            'error' => 'Erreur de téléchargement : ' . $error
        ];
    }
}

/**
 * Logger une action
 */
function logAction($action, $details = '') {
    $logFile = LOG_DIR . '/web-actions.log';
    $timestamp = date('Y-m-d H:i:s');
    $user = $_SESSION['user'] ?? 'anonymous';
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    
    $logEntry = sprintf(
        "[%s] [%s@%s] %s%s\n",
        $timestamp,
        $user,
        $ip,
        $action,
        $details ? " - $details" : ''
    );
    
    file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);
}

/**
 * Formater la taille des fichiers
 */
function formatBytes($bytes, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    $bytes = max($bytes, 0);
    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);
    
    $bytes /= pow(1024, $pow);
    
    return round($bytes, $precision) . ' ' . $units[$pow];
}

/**
 * Sécuriser une chaîne pour l'affichage
 */
function e($string) {
    return htmlspecialchars($string, ENT_QUOTES, 'UTF-8');
}

/**
 * Obtenir les logs récents
 */
function getRecentLogs($logFile, $lines = 100) {
    $file = LOG_DIR . '/' . $logFile;
    
    if (!file_exists($file)) {
        return [];
    }
    
    $command = sprintf('tail -n %d %s', $lines, escapeshellarg($file));
    $output = shell_exec($command);
    
    return array_reverse(explode("\n", trim($output)));
}

/**
 * Nettoyer le répertoire temporaire
 */
function cleanTempDir() {
    $files = glob(TEMP_DIR . '/*');
    $now = time();
    
    foreach ($files as $file) {
        // Supprimer les fichiers de plus d'une heure
        if (is_file($file) && ($now - filemtime($file)) > 3600) {
            unlink($file);
        }
    }
}