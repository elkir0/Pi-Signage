<?php
/**
 * Fonctions utilitaires pour l'interface web Pi Signage
 * Ce fichier sera copié dans /var/www/pi-signage/includes/functions.php
 */

// Protection contre l'accès direct
if (!defined('PI_SIGNAGE_WEB')) {
    die('Direct access not allowed');
}

/**
 * Vérifier le statut d'un service systemd
 */
function checkServiceStatus($service) {
    // Validation du nom de service
    if (!preg_match('/^[a-zA-Z0-9.-]+\.service$/', $service)) {
        return ['status' => 'error', 'message' => 'Invalid service name'];
    }
    
    // Utiliser shell_exec de manière sécurisée
    $cmd = escapeshellcmd("systemctl is-active " . escapeshellarg($service));
    $output = trim(shell_exec($cmd));
    
    return [
        'active' => ($output === 'active'),
        'status' => $output
    ];
}

/**
 * Obtenir les informations système
 */
function getSystemInfo() {
    $info = [];
    
    // CPU usage
    $load = sys_getloadavg();
    $info['cpu_load'] = [
        '1min' => $load[0],
        '5min' => $load[1],
        '15min' => $load[2]
    ];
    
    // Memory usage
    $meminfo = file_get_contents('/proc/meminfo');
    preg_match('/MemTotal:\s+(\d+)/', $meminfo, $matches);
    $total = isset($matches[1]) ? intval($matches[1]) * 1024 : 0;
    
    preg_match('/MemAvailable:\s+(\d+)/', $meminfo, $matches);
    $available = isset($matches[1]) ? intval($matches[1]) * 1024 : 0;
    
    $info['memory'] = [
        'total' => $total,
        'available' => $available,
        'used' => $total - $available,
        'percent' => $total > 0 ? round((($total - $available) / $total) * 100, 2) : 0
    ];
    
    // Disk usage
    $info['disk'] = [
        'total' => disk_total_space(VIDEO_DIR),
        'free' => disk_free_space(VIDEO_DIR),
        'used' => disk_total_space(VIDEO_DIR) - disk_free_space(VIDEO_DIR)
    ];
    
    // Temperature (Raspberry Pi specific)
    $temp_file = '/sys/class/thermal/thermal_zone0/temp';
    if (file_exists($temp_file)) {
        $temp = intval(file_get_contents($temp_file)) / 1000;
        $info['temperature'] = round($temp, 1);
    }
    
    return $info;
}

/**
 * Contrôler un service systemd
 */
function controlService($service, $action) {
    // Validation stricte
    $allowed_services = ['vlc-signage.service'];
    $allowed_actions = ['start', 'stop', 'restart', 'status'];
    
    if (!in_array($service, $allowed_services) || !in_array($action, $allowed_actions)) {
        return ['success' => false, 'error' => 'Invalid service or action'];
    }
    
    // Utiliser sudo de manière sécurisée
    $cmd = sprintf(
        "sudo /usr/bin/systemctl %s %s 2>&1",
        escapeshellarg($action),
        escapeshellarg($service)
    );
    
    $output = shell_exec($cmd);
    $return_code = 0;
    exec($cmd, $exec_output, $return_code);
    
    logActivity("SERVICE_CONTROL", "$action $service");
    
    return [
        'success' => ($return_code === 0),
        'output' => $output,
        'code' => $return_code
    ];
}

/**
 * Lister les vidéos
 */
function listVideos() {
    $videos = [];
    $allowed_extensions = ALLOWED_EXTENSIONS;
    
    if (!is_dir(VIDEO_DIR)) {
        return $videos;
    }
    
    $iterator = new DirectoryIterator(VIDEO_DIR);
    foreach ($iterator as $file) {
        if ($file->isFile()) {
            $ext = strtolower($file->getExtension());
            if (in_array($ext, $allowed_extensions)) {
                $videos[] = [
                    'name' => $file->getFilename(),
                    'size' => $file->getSize(),
                    'modified' => $file->getMTime(),
                    'path' => VIDEO_DIR . '/' . $file->getFilename()
                ];
            }
        }
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
    // Validation stricte du nom de fichier
    if (!isValidFilename($filename)) {
        return ['success' => false, 'error' => 'Invalid filename'];
    }
    
    $filepath = VIDEO_DIR . '/' . $filename;
    
    // Vérifier que le fichier existe et est dans le bon répertoire
    if (!file_exists($filepath) || !is_file($filepath)) {
        return ['success' => false, 'error' => 'File not found'];
    }
    
    // Vérifier que le chemin est bien dans VIDEO_DIR
    $realpath = realpath($filepath);
    $video_dir_real = realpath(VIDEO_DIR);
    if (strpos($realpath, $video_dir_real) !== 0) {
        return ['success' => false, 'error' => 'Invalid file path'];
    }
    
    // Supprimer le fichier
    if (unlink($filepath)) {
        logActivity("VIDEO_DELETE", $filename);
        return ['success' => true];
    } else {
        return ['success' => false, 'error' => 'Failed to delete file'];
    }
}

/**
 * Gérer l'upload d'une vidéo
 */
function handleVideoUpload(array $file) {
    if ($file['error'] !== UPLOAD_ERR_OK) {
        return ['success' => false, 'message' => 'Erreur lors de l\'upload'];
    }

    // Taille maximale
    if ($file['size'] > (MAX_UPLOAD_SIZE * 1024 * 1024)) {
        return ['success' => false, 'message' => 'Fichier trop volumineux'];
    }

    $originalName = basename($file['name']);
    $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));

    if (!in_array($ext, ALLOWED_EXTENSIONS)) {
        return ['success' => false, 'message' => 'Extension non autorisée'];
    }

    $base = preg_replace('/[^a-zA-Z0-9._-]/', '_', pathinfo($originalName, PATHINFO_FILENAME));
    $filename = $base . '.' . $ext;
    $destination = rtrim(VIDEO_DIR, '/') . '/' . $filename;

    if (!move_uploaded_file($file['tmp_name'], $destination)) {
        return ['success' => false, 'message' => 'Impossible de déplacer le fichier'];
    }

    chmod($destination, 0640);
    logActivity('VIDEO_UPLOAD', $filename);

    return ['success' => true, 'message' => 'Vidéo uploadée'];
}

/**
 * Télécharger une vidéo YouTube (limité aux vidéos de l'utilisateur)
 */
function downloadYouTubeVideo($url, $title = null, $progressFile = null) {
    // Validation de l'URL
    if (!filter_var($url, FILTER_VALIDATE_URL)) {
        return ['success' => false, 'error' => 'Invalid URL'];
    }
    
    // Vérifier que c'est une URL YouTube
    if (!preg_match('/^https?:\/\/(www\.)?(youtube\.com|youtu\.be)\//', $url)) {
        return ['success' => false, 'error' => 'Only YouTube URLs are allowed'];
    }
    
    // Générer un nom de fichier sécurisé
    if ($title) {
        $filename = preg_replace('/[^a-zA-Z0-9._-]/', '_', $title);
    } else {
        $filename = 'video_' . time();
    }
    
    // Construire la commande yt-dlp
    $output_path = VIDEO_DIR . '/' . $filename . '.%(ext)s';
    $cmd = sprintf(
        '%s -f "best[ext=mp4]/best" -o %s --no-playlist --restrict-filenames --newline %s',
        escapeshellcmd(YTDLP_BIN),
        escapeshellarg($output_path),
        escapeshellarg($url)
    );

    // Forcer H.264 en mode Chromium
    if (DISPLAY_MODE === 'chromium') {
        $cmd .= ' --recode-video mp4 --postprocessor-args "-c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -movflags +faststart"';
    }

    $cmd .= ' 2>&1';

    $descriptorspec = [
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w']
    ];

    if ($progressFile) {
        if (!is_dir(PROGRESS_DIR)) {
            mkdir(PROGRESS_DIR, 0777, true);
        }
        file_put_contents($progressFile, '0');
    }

    $process = proc_open($cmd, $descriptorspec, $pipes);
    if (!is_resource($process)) {
        return ['success' => false, 'error' => 'Process failed'];
    }

    $output = '';
    while (($line = fgets($pipes[1])) !== false) {
        $output .= $line;
        if ($progressFile && preg_match('/\[download\]\s+(\d+(?:\.\d+)?)%/', $line, $m)) {
            file_put_contents($progressFile, $m[1]);
        }
    }
    $stderr = stream_get_contents($pipes[2]);

    fclose($pipes[1]);
    fclose($pipes[2]);
    $status = proc_close($process);

    if ($progressFile) {
        file_put_contents($progressFile, '100');
    }

    logActivity("VIDEO_DOWNLOAD", $url);

    if ($status !== 0) {
        return ['success' => false, 'error' => 'Download failed', 'output' => $output . $stderr];
    }

    return ['success' => true, 'output' => $output];
}

/**
 * Obtenir les logs récents
 */
function getRecentLogs($logfile = 'vlc.log', $lines = 100) {
    $allowed_logs = ['vlc.log', 'web-activity.log', 'pi-signage-setup.log'];
    
    if (!in_array($logfile, $allowed_logs)) {
        return ['error' => 'Invalid log file'];
    }
    
    $filepath = LOG_DIR . '/' . $logfile;
    
    if (!file_exists($filepath)) {
        return ['error' => 'Log file not found'];
    }
    
    // Utiliser tail pour obtenir les dernières lignes
    $cmd = sprintf('tail -n %d %s', intval($lines), escapeshellarg($filepath));
    $output = shell_exec($cmd);
    
    return [
        'filename' => $logfile,
        'content' => $output,
        'lines' => substr_count($output, "\n")
    ];
}

/**
 * Formater la taille de fichier
 */
function formatFileSize($bytes) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $bytes = max($bytes, 0);
    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);
    $bytes /= pow(1024, $pow);
    
    return round($bytes, 2) . ' ' . $units[$pow];
}


/**
 * Vérifier l'espace disque disponible
 */
function checkDiskSpace() {
    $total = disk_total_space(VIDEO_DIR);
    $free = disk_free_space(VIDEO_DIR);
    $used = $total - $free;
    $percent = ($used / $total) * 100;
    
    return [
        'total' => $total,
        'free' => $free,
        'used' => $used,
        'percent' => round($percent, 2),
        'formatted' => [
            'total' => formatFileSize($total),
            'free' => formatFileSize($free),
            'used' => formatFileSize($used)
        ]
    ];
}