<?php
/**
 * PiSignage Desktop v3.0 - Fonctions utilitaires
 */

// Protection contre l'accès direct
if (!defined('PISIGNAGE_DESKTOP')) {
    die('Direct access not allowed');
}

/**
 * Obtenir les informations système
 */
function getSystemInfo() {
    $info = [];
    
    // CPU usage (load average)
    $load = sys_getloadavg();
    $info['cpu_load'] = [
        '1min' => round($load[0], 2),
        '5min' => round($load[1], 2),
        '15min' => round($load[2], 2)
    ];
    
    // CPU cores pour calculer le pourcentage
    $cores = 1;
    if (file_exists('/proc/cpuinfo')) {
        $cpuinfo = file_get_contents('/proc/cpuinfo');
        $cores = substr_count($cpuinfo, 'processor');
    }
    $info['cpu_percent'] = min(100, round(($load[0] / $cores) * 100, 1));
    
    // Memory usage
    if (file_exists('/proc/meminfo')) {
        $meminfo = file_get_contents('/proc/meminfo');
        preg_match('/MemTotal:\s+(\d+)/', $meminfo, $matches);
        $total = isset($matches[1]) ? intval($matches[1]) * 1024 : 0;
        
        preg_match('/MemAvailable:\s+(\d+)/', $meminfo, $matches);
        $available = isset($matches[1]) ? intval($matches[1]) * 1024 : 0;
        
        $info['memory'] = [
            'total' => $total,
            'available' => $available,
            'used' => $total - $available,
            'percent' => $total > 0 ? round((($total - $available) / $total) * 100, 1) : 0
        ];
    }
    
    // Disk usage
    $video_dir = VIDEO_DIR;
    if (is_dir($video_dir)) {
        $total = disk_total_space($video_dir);
        $free = disk_free_space($video_dir);
        $used = $total - $free;
        
        $info['disk'] = [
            'total' => $total,
            'free' => $free,
            'used' => $used,
            'percent' => $total > 0 ? round(($used / $total) * 100, 1) : 0
        ];
    }
    
    // Temperature (Raspberry Pi)
    $temp_file = '/sys/class/thermal/thermal_zone0/temp';
    if (file_exists($temp_file)) {
        $temp = intval(file_get_contents($temp_file)) / 1000;
        $info['temperature'] = round($temp, 1);
    }
    
    return $info;
}

/**
 * Vérifier le statut d'un service
 */
function checkServiceStatus($service) {
    $cmd = "systemctl is-active " . escapeshellarg($service) . " 2>/dev/null";
    $output = trim(shell_exec($cmd));
    
    return [
        'active' => ($output === 'active'),
        'status' => $output ?: 'unknown'
    ];
}

/**
 * Contrôler un service
 */
function controlService($service, $action) {
    $allowed_services = [PISIGNAGE_SERVICE, 'nginx'];
    $allowed_actions = ['start', 'stop', 'restart', 'status'];
    
    if (!in_array($service, $allowed_services) || !in_array($action, $allowed_actions)) {
        return ['success' => false, 'message' => 'Service ou action non autorisé'];
    }
    
    $cmd = "sudo systemctl " . escapeshellarg($action) . " " . escapeshellarg($service) . " 2>&1";
    $output = shell_exec($cmd);
    $exit_code = 0;
    exec($cmd, $dummy, $exit_code);
    
    return [
        'success' => ($exit_code === 0),
        'message' => trim($output),
        'exit_code' => $exit_code
    ];
}

/**
 * Lister les vidéos
 */
function listVideos() {
    $videos = [];
    $video_dir = VIDEO_DIR;
    
    if (!is_dir($video_dir)) {
        return $videos;
    }
    
    $allowed_ext = ALLOWED_EXTENSIONS;
    $files = scandir($video_dir);
    
    foreach ($files as $file) {
        if ($file === '.' || $file === '..') continue;
        
        $path = $video_dir . '/' . $file;
        if (!is_file($path)) continue;
        
        $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        if (!in_array($ext, $allowed_ext)) continue;
        
        $videos[] = [
            'name' => $file,
            'path' => $path,
            'size' => filesize($path),
            'modified' => filemtime($path),
            'extension' => $ext
        ];
    }
    
    // Trier par date de modification (plus récent en premier)
    usort($videos, function($a, $b) {
        return $b['modified'] - $a['modified'];
    });
    
    return $videos;
}

/**
 * Supprimer une vidéo
 */
function deleteVideo($filename) {
    // Validation du nom de fichier
    if (empty($filename) || strpos($filename, '..') !== false || strpos($filename, '/') !== false) {
        return ['success' => false, 'message' => 'Nom de fichier invalide'];
    }
    
    $path = VIDEO_DIR . '/' . $filename;
    
    if (!file_exists($path)) {
        return ['success' => false, 'message' => 'Fichier non trouvé'];
    }
    
    if (unlink($path)) {
        // Mettre à jour la playlist après suppression
        updatePlaylistFromVideos();
        return ['success' => true, 'message' => 'Vidéo supprimée avec succès'];
    } else {
        return ['success' => false, 'message' => 'Erreur lors de la suppression'];
    }
}

/**
 * Gérer l'upload de vidéo
 */
function handleVideoUpload($file) {
    if (!isset($file['error']) || is_array($file['error'])) {
        return ['success' => false, 'message' => 'Erreur de paramètre'];
    }
    
    // Vérifier les erreurs d'upload
    switch ($file['error']) {
        case UPLOAD_ERR_OK:
            break;
        case UPLOAD_ERR_NO_FILE:
            return ['success' => false, 'message' => 'Aucun fichier envoyé'];
        case UPLOAD_ERR_INI_SIZE:
        case UPLOAD_ERR_FORM_SIZE:
            return ['success' => false, 'message' => 'Fichier trop volumineux'];
        default:
            return ['success' => false, 'message' => 'Erreur inconnue'];
    }
    
    // Vérifier la taille
    if ($file['size'] > MAX_UPLOAD_SIZE * 1024 * 1024) {
        return ['success' => false, 'message' => 'Fichier trop volumineux (max ' . MAX_UPLOAD_SIZE . 'MB)'];
    }
    
    // Vérifier l'extension
    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!in_array($ext, ALLOWED_EXTENSIONS)) {
        return ['success' => false, 'message' => 'Type de fichier non autorisé'];
    }
    
    // Nettoyer le nom de fichier
    $filename = preg_replace('/[^a-zA-Z0-9_.-]/', '_', $file['name']);
    $destination = VIDEO_DIR . '/' . $filename;
    
    // Éviter l'écrasement
    $counter = 1;
    $original_name = pathinfo($filename, PATHINFO_FILENAME);
    $extension = pathinfo($filename, PATHINFO_EXTENSION);
    
    while (file_exists($destination)) {
        $filename = $original_name . '_' . $counter . '.' . $extension;
        $destination = VIDEO_DIR . '/' . $filename;
        $counter++;
    }
    
    if (move_uploaded_file($file['tmp_name'], $destination)) {
        // Mettre à jour la playlist après upload
        updatePlaylistFromVideos();
        return ['success' => true, 'message' => 'Vidéo uploadée avec succès', 'filename' => $filename];
    } else {
        return ['success' => false, 'message' => 'Erreur lors du déplacement du fichier'];
    }
}

/**
 * Charger la playlist
 */
function loadPlaylist() {
    if (!file_exists(PLAYLIST_FILE)) {
        return [];
    }
    
    $content = file_get_contents(PLAYLIST_FILE);
    $playlist = json_decode($content, true);
    
    return is_array($playlist) ? $playlist : [];
}

/**
 * Sauvegarder la playlist
 */
function savePlaylist($playlist) {
    $json = json_encode($playlist, JSON_PRETTY_PRINT);
    return file_put_contents(PLAYLIST_FILE, $json) !== false;
}

/**
 * Mettre à jour la playlist à partir des vidéos disponibles
 */
function updatePlaylistFromVideos() {
    $videos = listVideos();
    $playlist = [];
    
    foreach ($videos as $video) {
        $playlist[] = [
            'file' => $video['name'],
            'duration' => 30, // durée par défaut en secondes
            'enabled' => true
        ];
    }
    
    return savePlaylist($playlist);
}

/**
 * Formater la taille en bytes
 */
function formatBytes($bytes, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}

/**
 * Télécharger une vidéo YouTube (simplifié)
 */
function downloadYouTubeVideo($url) {
    if (!filter_var($url, FILTER_VALIDATE_URL)) {
        return ['success' => false, 'message' => 'URL invalide'];
    }
    
    // Validation YouTube
    if (!preg_match('/(?:youtube\.com|youtu\.be)/', $url)) {
        return ['success' => false, 'message' => 'URL YouTube invalide'];
    }
    
    // Commande yt-dlp simplifiée
    $output_dir = escapeshellarg(VIDEO_DIR);
    $safe_url = escapeshellarg($url);
    
    $cmd = "cd $output_dir && yt-dlp -f 'best[ext=mp4]' --no-playlist $safe_url 2>&1";
    $output = shell_exec($cmd);
    $exit_code = 0;
    exec($cmd, $dummy, $exit_code);
    
    if ($exit_code === 0) {
        updatePlaylistFromVideos();
        return ['success' => true, 'message' => 'Vidéo téléchargée avec succès', 'output' => $output];
    } else {
        return ['success' => false, 'message' => 'Erreur lors du téléchargement', 'output' => $output];
    }
}

/**
 * Contrôler le player
 */
function controlPlayer($action) {
    $allowed_actions = ['play', 'pause', 'stop', 'next', 'previous', 'reload'];
    
    if (!in_array($action, $allowed_actions)) {
        return ['success' => false, 'message' => 'Action non autorisée'];
    }
    
    // Pour Chromium, on utilise une API simple
    $url = PLAYER_URL . '/api/control';
    $data = json_encode(['action' => $action]);
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code === 200) {
        return ['success' => true, 'message' => 'Commande envoyée'];
    } else {
        return ['success' => false, 'message' => 'Erreur de communication avec le player'];
    }
}

/**
 * Logger une action
 */
function logAction($action, $details = '') {
    $log_entry = date('Y-m-d H:i:s') . " - $action";
    if ($details) {
        $log_entry .= " - $details";
    }
    $log_entry .= "\n";
    
    $log_file = '/tmp/pisignage-desktop.log';
    file_put_contents($log_file, $log_entry, FILE_APPEND | LOCK_EX);
}