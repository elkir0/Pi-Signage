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
    $allowed_services = ['vlc-signage.service', 'chromium-kiosk.service'];
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
    
    // Mettre à jour la playlist si en mode Chromium
    if (DISPLAY_MODE === 'chromium' && file_exists('/opt/scripts/update-playlist.sh')) {
        exec('sudo /opt/scripts/update-playlist.sh 2>&1', $updateOutput, $updateStatus);
        if ($updateStatus === 0) {
            return ['success' => true, 'message' => 'Vidéo uploadée et playlist mise à jour'];
        }
    }

    return ['success' => true, 'message' => 'Vidéo uploadée'];
}

/**
 * Télécharger une vidéo YouTube (limité aux vidéos de l'utilisateur)
 */
function downloadYouTubeVideo($url, $title = null, $progressFile = null) {
    // Vérifier que yt-dlp existe
    if (!file_exists(YTDLP_BIN) || !is_executable(YTDLP_BIN)) {
        return ['success' => false, 'error' => 'yt-dlp not found or not executable'];
    }
    
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
    
    // Commande de base simplifiée
    $cmd = sprintf(
        '%s -o %s --no-playlist --restrict-filenames --newline',
        escapeshellcmd(YTDLP_BIN),
        escapeshellarg($output_path)
    );
    
    // Mode Chromium : forcer MP4 avec codec H.264
    if (DISPLAY_MODE === 'chromium') {
        // Format simple : meilleur MP4 disponible jusqu'à 1080p
        $cmd .= ' -f "best[ext=mp4][height<=1080]/best[ext=mp4]/best" --merge-output-format mp4';
    } else {
        // Mode VLC : accepter plus de formats
        $cmd .= ' -f "best[height<=1080]/best"';
    }
    
    // Ajouter l'URL à la fin
    $cmd .= ' ' . escapeshellarg($url);

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
        // Si échec, essayer avec une commande plus simple
        if (strpos($output . $stderr, 'Requested format is not available') !== false || 
            strpos($output . $stderr, 'Signature extraction failed') !== false) {
            
            $output .= "\n[INFO] Tentative avec paramètres simplifiés...\n";
            
            // Commande de fallback ultra-simple
            $fallback_cmd = sprintf(
                '%s -o %s --no-playlist %s 2>&1',
                escapeshellcmd(YTDLP_BIN),
                escapeshellarg($output_path),
                escapeshellarg($url)
            );
            
            exec($fallback_cmd, $fallback_output, $fallback_status);
            
            if ($fallback_status === 0) {
                $output .= implode("\n", $fallback_output);
                $status = 0; // Succès avec la commande de fallback
            } else {
                return ['success' => false, 'error' => 'Download failed', 'output' => $output . $stderr . "\n" . implode("\n", $fallback_output)];
            }
        } else {
            return ['success' => false, 'error' => 'Download failed', 'output' => $output . $stderr];
        }
    }

    // Mettre à jour la playlist si on est en mode Chromium
    if (DISPLAY_MODE === 'chromium' && file_exists('/opt/scripts/update-playlist.sh')) {
        exec('sudo /opt/scripts/update-playlist.sh 2>&1', $updateOutput, $updateStatus);
        if ($updateStatus === 0) {
            $output .= "\n[INFO] Playlist mise à jour automatiquement";
        } else {
            $output .= "\n[WARNING] Échec de la mise à jour de la playlist: " . implode("\n", $updateOutput);
        }
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

/**
 * Enregistrer une playlist personnalisée (adaptative VLC/Chromium)
 */
function savePlaylist(array $filenames) {
    $videos = [];

    foreach ($filenames as $name) {
        $base = basename($name);
        if (!isValidFilename($base)) {
            continue;
        }

        $path = VIDEO_DIR . '/' . $base;
        if (!file_exists($path)) {
            continue;
        }

        $videos[] = [
            'path' => '/videos/' . $base,
            'name' => $base
        ];
    }

    // Mode VLC : créer une playlist M3U ET redémarrer le service
    if (DISPLAY_MODE === 'vlc') {
        // Créer la playlist M3U
        $m3u_content = "#EXTM3U\n";
        foreach ($videos as $video) {
            $m3u_content .= VIDEO_DIR . '/' . $video['name'] . "\n";
        }
        
        // Sauvegarder la playlist M3U
        if (file_put_contents(PLAYLIST_FILE, $m3u_content) === false) {
            return false;
        }
        
        // Redémarrer le service VLC pour prendre en compte la nouvelle playlist
        $restart_result = controlService('vlc-signage.service', 'restart');
        if (!$restart_result['success']) {
            error_log("Échec du redémarrage VLC: " . ($restart_result['error'] ?? 'Unknown error'));
            // Ne pas faire échouer la sauvegarde pour autant
        }
        
        logActivity('VLC_PLAYLIST_SAVED', strval(count($videos)) . ' videos');
        return true;
    } 
    
    // Mode Chromium : créer la playlist JSON
    else {
        $playlist = [
            'version' => '1.0',
            'updated' => date('c'),
            'videos' => $videos
        ];

        $json = json_encode($playlist, JSON_PRETTY_PRINT);
        if ($json === false) {
            return false;
        }

        $dir = dirname(PLAYLIST_FILE);
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }

        if (file_put_contents(PLAYLIST_FILE, $json) === false) {
            return false;
        }

        chmod(PLAYLIST_FILE, 0644);
        @chown(PLAYLIST_FILE, 'www-data');

        logActivity('CHROMIUM_PLAYLIST_SAVED', strval(count($videos)) . ' videos');
        return true;
    }
}

/**
 * Lire la playlist actuelle (adaptative VLC/Chromium)
 */
function getCurrentPlaylist() {
    if (DISPLAY_MODE === 'vlc') {
        // Pour VLC, on retourne toutes les vidéos du répertoire
        // car VLC génère sa playlist dynamiquement
        $videos = listVideos();
        $playlist = [];
        foreach ($videos as $video) {
            $playlist[] = $video['name'];
        }
        return $playlist;
    } else {
        // Mode Chromium : lire le fichier JSON
        if (file_exists(PLAYLIST_FILE)) {
            $data = json_decode(file_get_contents(PLAYLIST_FILE), true);
            if (!empty($data['videos'])) {
                $playlist = [];
                foreach ($data['videos'] as $v) {
                    if (isset($v['name'])) {
                        $playlist[] = $v['name'];
                    }
                }
                return $playlist;
            }
        }
        return [];
    }
}
