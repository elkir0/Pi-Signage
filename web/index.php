<?php
/**
 * PiSignage Web Interface Complete
 * Version: 3.1.0  
 * Date: 2025-09-19
 * 
 * Interface web complète avec toutes les fonctionnalités :
 * - Dashboard avec widgets
 * - Gestion des playlists
 * - Téléchargement YouTube
 * - Screenshots d'écran
 * - Scheduling avancé
 * - Upload drag & drop
 * - Multi-zones
 * - Statistiques en temps réel
 */

session_start();
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Configuration
define('MEDIA_DIR', '/opt/pisignage/media/');
define('CONTROL_SCRIPT', '/opt/pisignage/scripts/vlc-control.sh');
define('UPLOAD_DIR', '/opt/pisignage/media/');
define('MAX_UPLOAD_SIZE', 500 * 1024 * 1024); // 500MB
define('SCREENSHOT_SCRIPT', '/opt/pisignage/scripts/screenshot.sh');
define('YOUTUBE_SCRIPT', '/opt/pisignage/scripts/youtube-dl.sh');
define('PLAYLIST_API', '/api/playlist.php');
define('YOUTUBE_API', '/api/youtube.php');

// Helper functions
function executeCommand($command) {
    $output = shell_exec($command . ' 2>&1');
    return $output;
}

function getSystemInfo() {
    $info = [];
    
    // Hostname
    $info['hostname'] = trim(executeCommand('hostname'));
    
    // Uptime
    $uptime = executeCommand('uptime -p');
    $info['uptime'] = $uptime ? trim($uptime) : 'N/A';
    
    // CPU Temperature
    $temp = executeCommand('cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null');
    $info['cpu_temp'] = $temp ? round(intval($temp) / 1000, 1) : 0;
    
    // Memory usage
    $memory = executeCommand('free -m | grep Mem');
    if (preg_match('/Mem:\s+(\d+)\s+(\d+)/', $memory, $matches)) {
        $info['mem_total'] = $matches[1];
        $info['mem_used'] = $matches[2];
        $info['mem_percent'] = round(($matches[2] / $matches[1]) * 100);
    } else {
        $info['mem_percent'] = 0;
    }
    
    // Disk usage
    $disk = executeCommand('df -h / | tail -1');
    if (preg_match('/(\d+)%/', $disk, $matches)) {
        $info['disk_percent'] = $matches[1];
    } else {
        $info['disk_percent'] = 0;
    }
    
    // VLC status
    $vlc_check = executeCommand('pgrep vlc');
    $info['vlc_running'] = !empty(trim($vlc_check));
    
    // Screenshot disponible
    $info['screenshot_available'] = file_exists(SCREENSHOT_SCRIPT);
    
    // YouTube download disponible
    $info['youtube_available'] = file_exists(YOUTUBE_SCRIPT) && command_exists('yt-dlp');
    
    return $info;
}

function getMediaFiles() {
    $files = [];
    if (is_dir(MEDIA_DIR)) {
        $extensions = ['mp4', 'avi', 'mkv', 'mov', 'webm', 'jpg', 'jpeg', 'png', 'gif'];
        $videos = glob(MEDIA_DIR . '*.{' . implode(',', $extensions) . '}', GLOB_BRACE);
        foreach ($videos as $file) {
            $files[] = [
                'name' => basename($file),
                'path' => $file,
                'type' => getFileType($file),
                'size' => filesize($file),
                'size_formatted' => formatBytes(filesize($file)),
                'duration' => getMediaDuration($file),
                'modified' => date('Y-m-d H:i', filemtime($file))
            ];
        }
    }
    return $files;
}

function getFileType($file) {
    $mime = mime_content_type($file);
    if (strpos($mime, 'video/') === 0) return 'video';
    if (strpos($mime, 'image/') === 0) return 'image';
    return 'unknown';
}

function getMediaDuration($file) {
    if (getFileType($file) === 'image') return 5; // 5 secondes par défaut pour les images
    
    if (command_exists('ffprobe')) {
        $cmd = 'ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ' . escapeshellarg($file);
        $output = shell_exec($cmd);
        if ($output && is_numeric(trim($output))) {
            return (int)round(floatval(trim($output)));
        }
    }
    return 0;
}

function command_exists($cmd) {
    return shell_exec("which $cmd") !== null;
}

function takeScreenshot() {
    if (!file_exists(SCREENSHOT_SCRIPT)) {
        return false;
    }
    
    // Exécuter le script et récupérer seulement stdout
    $output = shell_exec(SCREENSHOT_SCRIPT . ' 2>/dev/null');
    $screenshotPath = trim($output);
    
    // Vérifier que le fichier existe et est dans le bon répertoire web
    if (file_exists($screenshotPath) && strpos($screenshotPath, '/opt/pisignage/web/assets/screenshots/') === 0) {
        // Retourner le chemin relatif web
        return str_replace('/opt/pisignage/web/', '', $screenshotPath);
    }
    
    return false;
}

function formatBytes($bytes, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}

// Handle API requests
if (isset($_GET['action'])) {
    header('Content-Type: application/json');
    
    switch ($_GET['action']) {
        case 'status':
            $system = getSystemInfo();
            echo json_encode(['success' => true, 'data' => $system]);
            break;
            
        case 'screenshot':
            $screenshot = takeScreenshot();
            if ($screenshot) {
                echo json_encode(['success' => true, 'screenshot' => $screenshot]);
            } else {
                echo json_encode(['success' => false, 'message' => 'Impossible de prendre une capture']);
            }
            break;
            
        case 'play':
            $video = $_POST['video'] ?? '';
            if ($video) {
                $videoPath = MEDIA_DIR . basename($video);
                if (file_exists($videoPath)) {
                    $cmd = sprintf('sudo -u pi %s play "%s"', CONTROL_SCRIPT, $videoPath);
                    $result = executeCommand($cmd);
                    echo json_encode(['success' => true, 'message' => 'Playing: ' . $video]);
                } else {
                    echo json_encode(['success' => false, 'message' => 'Video file not found']);
                }
            } else {
                // Play default
                $cmd = sprintf('sudo -u pi %s play', CONTROL_SCRIPT);
                $result = executeCommand($cmd);
                echo json_encode(['success' => true, 'message' => 'Playing default video']);
            }
            break;
            
        case 'stop':
            $cmd = sprintf('sudo -u pi %s stop', CONTROL_SCRIPT);
            $result = executeCommand($cmd);
            echo json_encode(['success' => true, 'message' => 'Playback stopped']);
            break;
            
        case 'restart':
            $cmd = sprintf('sudo -u pi %s restart', CONTROL_SCRIPT);
            $result = executeCommand($cmd);
            echo json_encode(['success' => true, 'message' => 'Player restarted']);
            break;
            
        case 'list':
            $files = getMediaFiles();
            echo json_encode(['success' => true, 'files' => $files]);
            break;
            
        case 'upload':
            if (isset($_FILES['video'])) {
                $uploadFile = UPLOAD_DIR . basename($_FILES['video']['name']);
                
                if ($_FILES['video']['size'] > MAX_UPLOAD_SIZE) {
                    echo json_encode(['success' => false, 'message' => 'File too large (max 500MB)']);
                } elseif (move_uploaded_file($_FILES['video']['tmp_name'], $uploadFile)) {
                    chmod($uploadFile, 0644);
                    // Retourner la liste des fichiers mise à jour
                    $files = getMediaFiles();
                    echo json_encode([
                        'success' => true, 
                        'message' => 'File uploaded successfully',
                        'files' => $files
                    ]);
                } else {
                    echo json_encode(['success' => false, 'message' => 'Upload failed']);
                }
            } else {
                echo json_encode(['success' => false, 'message' => 'No file provided']);
            }
            break;
            
        case 'delete':
            $video = $_POST['video'] ?? '';
            if ($video) {
                $videoPath = MEDIA_DIR . basename($video);
                if (file_exists($videoPath) && unlink($videoPath)) {
                    echo json_encode(['success' => true, 'message' => 'File deleted']);
                } else {
                    echo json_encode(['success' => false, 'message' => 'Delete failed']);
                }
            }
            break;
            
        case 'system_restart':
            // Redémarrer le système
            echo json_encode(['success' => true, 'message' => 'Redémarrage programmé...']);
            // Envoyer la réponse avant de redémarrer
            if (ob_get_level()) ob_end_flush();
            flush();
            // Redémarrer après 2 secondes
            shell_exec('sleep 2 && sudo reboot > /dev/null 2>&1 &');
            break;
            
        case 'system_shutdown':
            // Éteindre le système
            echo json_encode(['success' => true, 'message' => 'Extinction programmée...']);
            // Envoyer la réponse avant d'éteindre
            if (ob_get_level()) ob_end_flush();
            flush();
            // Éteindre après 2 secondes
            shell_exec('sleep 2 && sudo shutdown -h now > /dev/null 2>&1 &');
            break;
            
        default:
            echo json_encode(['success' => false, 'message' => 'Unknown action']);
    }
    exit;
}

// Get initial data
$systemInfo = getSystemInfo();
$mediaFiles = getMediaFiles();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage - Interface Complète v3.1.0</title>
    <style>
        :root {
            --primary: #6366f1;
            --primary-dark: #4f46e5;
            --primary-light: #a5b4fc;
            --success: #10b981;
            --success-dark: #059669;
            --danger: #ef4444;
            --danger-dark: #dc2626;
            --warning: #f59e0b;
            --warning-dark: #d97706;
            --info: #3b82f6;
            --info-dark: #2563eb;
            --bg: #f8fafc;
            --bg-dark: #1e293b;
            --card-bg: #ffffff;
            --card-bg-dark: #334155;
            --text: #1e293b;
            --text-light: #64748b;
            --text-dark: #f1f5f9;
            --border: #e2e8f0;
            --border-dark: #475569;
            --shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
            --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: var(--bg);
            color: var(--text);
            line-height: 1.6;
            overflow-x: hidden;
        }

        /* Header */
        .header {
            background: linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%);
            color: white;
            padding: 2rem 0;
            box-shadow: var(--shadow-lg);
            position: relative;
            overflow: hidden;
        }

        .header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grid" width="10" height="10" patternUnits="userSpaceOnUse"><path d="M 10 0 L 0 0 0 10" fill="none" stroke="rgba(255,255,255,0.1)" stroke-width="1"/></pattern></defs><rect width="100" height="100" fill="url(%23grid)"/></svg>');
            opacity: 0.3;
        }

        .header-content {
            max-width: 1400px;
            margin: 0 auto;
            padding: 0 2rem;
            position: relative;
            z-index: 1;
        }

        .header h1 {
            font-size: 3rem;
            margin-bottom: 0.5rem;
            font-weight: 700;
            text-shadow: 0 2px 4px rgba(0,0,0,0.3);
        }

        .header p {
            font-size: 1.2rem;
            opacity: 0.9;
            margin-bottom: 1rem;
        }

        .header-controls {
            display: flex;
            gap: 1rem;
            flex-wrap: wrap;
            margin-top: 1.5rem;
        }

        /* Container */
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 2rem;
        }

        /* Navigation Tabs */
        .nav-tabs {
            display: flex;
            background: var(--card-bg);
            border-radius: 12px;
            padding: 0.5rem;
            margin-bottom: 2rem;
            box-shadow: var(--shadow);
            overflow-x: auto;
        }

        .nav-tab {
            padding: 1rem 1.5rem;
            background: transparent;
            border: none;
            border-radius: 8px;
            font-size: 1rem;
            font-weight: 500;
            color: var(--text-light);
            cursor: pointer;
            transition: all 0.2s;
            white-space: nowrap;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .nav-tab.active {
            background: var(--primary);
            color: white;
            box-shadow: var(--shadow);
        }

        .nav-tab:hover:not(.active) {
            background: var(--bg);
            color: var(--text);
        }

        /* Tab Content */
        .tab-content {
            display: none;
        }

        .tab-content.active {
            display: block;
        }

        /* Stats Grid */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .stat-card {
            background: var(--card-bg);
            padding: 2rem;
            border-radius: 16px;
            box-shadow: var(--shadow);
            display: flex;
            align-items: center;
            gap: 1.5rem;
            transition: all 0.3s;
            position: relative;
            overflow: hidden;
        }

        .stat-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
            background: var(--primary);
            transform: scaleY(0);
            transition: transform 0.3s;
        }

        .stat-card:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-lg);
        }

        .stat-card:hover::before {
            transform: scaleY(1);
        }

        .stat-icon {
            width: 64px;
            height: 64px;
            border-radius: 16px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.8rem;
            flex-shrink: 0;
        }

        .stat-icon.status { background: linear-gradient(135deg, #10b981, #059669); color: white; }
        .stat-icon.cpu { background: linear-gradient(135deg, #ef4444, #dc2626); color: white; }
        .stat-icon.memory { background: linear-gradient(135deg, #6366f1, #4f46e5); color: white; }
        .stat-icon.disk { background: linear-gradient(135deg, #f59e0b, #d97706); color: white; }
        .stat-icon.media { background: linear-gradient(135deg, #8b5cf6, #7c3aed); color: white; }

        .stat-content h3 {
            font-size: 0.875rem;
            color: var(--text-light);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 0.5rem;
            font-weight: 600;
        }

        .stat-content p {
            font-size: 2rem;
            font-weight: 700;
            color: var(--text);
        }

        .stat-content .sub-text {
            font-size: 0.875rem;
            color: var(--text-light);
            margin-top: 0.25rem;
        }

        /* Cards */
        .card {
            background: var(--card-bg);
            border-radius: 16px;
            padding: 2rem;
            box-shadow: var(--shadow);
            margin-bottom: 2rem;
            transition: all 0.3s;
        }

        .card:hover {
            box-shadow: var(--shadow-lg);
        }

        .card h2 {
            font-size: 1.5rem;
            margin-bottom: 1.5rem;
            color: var(--text);
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .card h2::before {
            content: '';
            width: 4px;
            height: 1.5rem;
            background: var(--primary);
            border-radius: 2px;
        }

        /* Grid Layouts */
        .grid-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 2rem;
        }

        .grid-3 {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 2rem;
        }

        @media (max-width: 768px) {
            .grid-2, .grid-3 {
                grid-template-columns: 1fr;
            }
        }

        /* Buttons */
        .btn {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.75rem 1.5rem;
            border: none;
            border-radius: 10px;
            font-size: 1rem;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
            text-decoration: none;
            box-shadow: var(--shadow);
        }

        .btn:hover {
            transform: translateY(-1px);
            box-shadow: var(--shadow-lg);
        }

        .btn:active {
            transform: translateY(0);
        }

        .btn-primary {
            background: var(--primary);
            color: white;
        }

        .btn-primary:hover {
            background: var(--primary-dark);
        }

        .btn-success {
            background: var(--success);
            color: white;
        }

        .btn-success:hover {
            background: var(--success-dark);
        }

        .btn-danger {
            background: var(--danger);
            color: white;
        }

        .btn-danger:hover {
            background: var(--danger-dark);
        }

        .btn-warning {
            background: var(--warning);
            color: white;
        }

        .btn-warning:hover {
            background: var(--warning-dark);
        }

        .btn-info {
            background: var(--info);
            color: white;
        }

        .btn-info:hover {
            background: var(--info-dark);
        }

        .btn-secondary {
            background: var(--text-light);
            color: white;
        }

        .btn-secondary:hover {
            background: var(--text);
        }

        .btn-outline {
            background: transparent;
            border: 2px solid var(--primary);
            color: var(--primary);
        }

        .btn-outline:hover {
            background: var(--primary);
            color: white;
        }

        .btn-small {
            padding: 0.5rem 1rem;
            font-size: 0.875rem;
        }

        .btn-large {
            padding: 1rem 2rem;
            font-size: 1.125rem;
        }

        .btn-group {
            display: flex;
            gap: 0.75rem;
            flex-wrap: wrap;
        }

        /* Upload Zone */
        .upload-zone {
            border: 3px dashed var(--border);
            border-radius: 16px;
            padding: 3rem 2rem;
            text-align: center;
            transition: all 0.3s;
            cursor: pointer;
            background: var(--bg);
        }

        .upload-zone:hover,
        .upload-zone.dragover {
            border-color: var(--primary);
            background: rgba(99, 102, 241, 0.05);
            transform: scale(1.02);
        }

        .upload-zone .icon {
            font-size: 3rem;
            margin-bottom: 1rem;
            color: var(--text-light);
        }

        .upload-input {
            display: none;
        }

        /* Progress Bar */
        .progress-bar {
            width: 100%;
            height: 12px;
            background: var(--border);
            border-radius: 6px;
            overflow: hidden;
            margin: 1rem 0;
            display: none;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, var(--primary), var(--primary-light));
            transition: width 0.3s;
            position: relative;
        }

        .progress-fill::after {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(90deg, transparent, rgba(255,255,255,0.3), transparent);
            animation: shimmer 2s infinite;
        }

        @keyframes shimmer {
            0% { transform: translateX(-100%); }
            100% { transform: translateX(100%); }
        }

        /* Media List */
        .media-list {
            max-height: 500px;
            overflow-y: auto;
            border: 1px solid var(--border);
            border-radius: 12px;
            background: var(--card-bg);
        }

        .media-item {
            padding: 1.5rem;
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            gap: 1rem;
            transition: all 0.2s;
        }

        .media-item:hover {
            background: var(--bg);
        }

        .media-item:last-child {
            border-bottom: none;
        }

        .media-icon {
            width: 48px;
            height: 48px;
            border-radius: 8px;
            background: var(--primary);
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.2rem;
        }

        .media-info {
            flex: 1;
        }

        .media-name {
            font-weight: 600;
            margin-bottom: 0.25rem;
            color: var(--text);
        }

        .media-meta {
            font-size: 0.875rem;
            color: var(--text-light);
        }

        .media-actions {
            display: flex;
            gap: 0.5rem;
        }

        /* Screenshot */
        .screenshot-container {
            text-align: center;
            position: relative;
        }

        .screenshot-preview {
            max-width: 100%;
            height: auto;
            border-radius: 12px;
            box-shadow: var(--shadow);
            margin: 1rem 0;
        }

        .screenshot-placeholder {
            width: 100%;
            height: 200px;
            border: 2px dashed var(--border);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--text-light);
            background: var(--bg);
            margin: 1rem 0;
        }

        /* YouTube Section */
        .youtube-section {
            background: linear-gradient(135deg, #ff0000, #cc0000);
            color: white;
            padding: 2rem;
            border-radius: 16px;
            margin-bottom: 2rem;
        }

        .youtube-form {
            display: flex;
            gap: 1rem;
            margin-top: 1rem;
            flex-wrap: wrap;
        }

        .youtube-input {
            flex: 1;
            min-width: 300px;
            padding: 0.75rem 1rem;
            border: 2px solid rgba(255,255,255,0.3);
            border-radius: 8px;
            background: rgba(255,255,255,0.1);
            color: white;
            font-size: 1rem;
        }

        .youtube-input::placeholder {
            color: rgba(255,255,255,0.7);
        }

        .youtube-quality {
            padding: 0.75rem 1rem;
            border: 2px solid rgba(255,255,255,0.3);
            border-radius: 8px;
            background: rgba(255,255,255,0.1);
            color: white;
            font-size: 1rem;
        }

        /* Playlist Builder */
        .playlist-builder {
            background: var(--card-bg);
            border-radius: 16px;
            padding: 2rem;
            border: 1px solid var(--border);
        }

        .playlist-item {
            background: var(--bg);
            padding: 1rem;
            border-radius: 8px;
            margin-bottom: 0.5rem;
            display: flex;
            align-items: center;
            gap: 1rem;
            cursor: move;
            transition: all 0.2s;
        }

        .playlist-item:hover {
            transform: translateX(4px);
            box-shadow: var(--shadow);
        }

        .playlist-item .handle {
            color: var(--text-light);
            cursor: grab;
        }

        .playlist-item .handle:active {
            cursor: grabbing;
        }

        /* Alerts */
        .alert {
            padding: 1rem 1.5rem;
            border-radius: 12px;
            margin: 1rem 0;
            border: 1px solid;
            display: none;
            animation: slideIn 0.3s ease;
        }

        .alert.success {
            background: rgba(16, 185, 129, 0.1);
            color: var(--success-dark);
            border-color: var(--success);
        }

        .alert.error {
            background: rgba(239, 68, 68, 0.1);
            color: var(--danger-dark);
            border-color: var(--danger);
        }

        .alert.warning {
            background: rgba(245, 158, 11, 0.1);
            color: var(--warning-dark);
            border-color: var(--warning);
        }

        .alert.info {
            background: rgba(59, 130, 246, 0.1);
            color: var(--info-dark);
            border-color: var(--info);
        }

        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(-1rem);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        /* Status Indicators */
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 0.5rem;
            animation: pulse 2s infinite;
        }

        .status-indicator.online {
            background: var(--success);
        }

        .status-indicator.offline {
            background: var(--danger);
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        /* Empty State */
        .empty-state {
            padding: 4rem 2rem;
            text-align: center;
            color: var(--text-light);
        }

        .empty-state .icon {
            font-size: 4rem;
            margin-bottom: 1rem;
            opacity: 0.5;
        }

        .empty-state h3 {
            font-size: 1.25rem;
            margin-bottom: 0.5rem;
            color: var(--text);
        }

        /* Loading Spinner */
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid rgba(255,255,255,.3);
            border-radius: 50%;
            border-top-color: #fff;
            animation: spin 1s ease-in-out infinite;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        /* Form Elements */
        .form-group {
            margin-bottom: 1.5rem;
        }

        .form-label {
            display: block;
            font-weight: 600;
            margin-bottom: 0.5rem;
            color: var(--text);
        }

        .form-input {
            width: 100%;
            padding: 0.75rem 1rem;
            border: 2px solid var(--border);
            border-radius: 8px;
            font-size: 1rem;
            transition: all 0.2s;
        }

        .form-input:focus {
            outline: none;
            border-color: var(--primary);
            box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
        }

        .form-select {
            width: 100%;
            padding: 0.75rem 1rem;
            border: 2px solid var(--border);
            border-radius: 8px;
            font-size: 1rem;
            background: var(--card-bg);
        }

        /* Responsive */
        @media (max-width: 768px) {
            .header-content {
                padding: 0 1rem;
            }
            
            .header h1 {
                font-size: 2rem;
            }
            
            .container {
                padding: 1rem;
            }
            
            .stats-grid {
                grid-template-columns: 1fr;
            }
            
            .nav-tabs {
                margin: 0 -1rem 2rem -1rem;
                border-radius: 0;
            }
            
            .youtube-form {
                flex-direction: column;
            }
            
            .youtube-input {
                min-width: auto;
            }
        }

        /* Dark mode support */
        @media (prefers-color-scheme: dark) {
            :root {
                --bg: #0f172a;
                --card-bg: #1e293b;
                --text: #f1f5f9;
                --text-light: #94a3b8;
                --border: #334155;
            }
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="header-content">
            <h1>🎬 PiSignage Control Center</h1>
            <p>Interface de gestion complète pour affichage numérique - Version 3.1.0</p>
            <div class="header-controls">
                <button class="btn btn-outline" onclick="takeScreenshot()">📸 Capture d'écran</button>
                <button class="btn btn-outline" onclick="refreshAllData()">🔄 Actualiser</button>
                <button class="btn btn-outline" onclick="toggleFullscreen()">🔍 Plein écran</button>
            </div>
        </div>
    </header>

    <div class="container">
        <!-- Navigation Tabs -->
        <nav class="nav-tabs">
            <button class="nav-tab active" onclick="switchTab('dashboard', event)">
                📊 Dashboard
            </button>
            <button class="nav-tab" onclick="switchTab('media', event)">
                🎵 Médias
            </button>
            <button class="nav-tab" onclick="switchTab('playlists', event)">
                📑 Playlists
            </button>
            <button class="nav-tab" onclick="switchTab('youtube', event)">
                📺 YouTube
            </button>
            <button class="nav-tab" onclick="switchTab('scheduling', event)">
                ⏰ Programmation
            </button>
            <button class="nav-tab" onclick="switchTab('display', event)">
                🖥️ Affichage
            </button>
            <button class="nav-tab" onclick="switchTab('settings', event)">
                ⚙️ Configuration
            </button>
        </nav>

        <!-- Dashboard Tab -->
        <div id="dashboard-tab" class="tab-content active">
            <!-- System Stats -->
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-icon status">
                        <span class="status-indicator <?php echo $systemInfo['vlc_running'] ? 'online' : 'offline'; ?>"></span>
                    </div>
                    <div class="stat-content">
                        <h3>Statut Lecteur</h3>
                        <p id="player-status"><?php echo $systemInfo['vlc_running'] ? 'En lecture' : 'Arrêté'; ?></p>
                        <div class="sub-text">VLC Media Player</div>
                    </div>
                </div>
                
                <div class="stat-card">
                    <div class="stat-icon cpu">🌡️</div>
                    <div class="stat-content">
                        <h3>Température CPU</h3>
                        <p id="cpu-temp"><?php echo $systemInfo['cpu_temp']; ?>°C</p>
                        <div class="sub-text">Raspberry Pi</div>
                    </div>
                </div>
                
                <div class="stat-card">
                    <div class="stat-icon memory">💾</div>
                    <div class="stat-content">
                        <h3>Mémoire RAM</h3>
                        <p id="memory-usage"><?php echo $systemInfo['mem_percent']; ?>%</p>
                        <div class="sub-text">Utilisation mémoire</div>
                    </div>
                </div>
                
                <div class="stat-card">
                    <div class="stat-icon disk">💿</div>
                    <div class="stat-content">
                        <h3>Stockage</h3>
                        <p id="disk-usage"><?php echo $systemInfo['disk_percent']; ?>%</p>
                        <div class="sub-text">Espace disque utilisé</div>
                    </div>
                </div>

                <div class="stat-card">
                    <div class="stat-icon media">🎬</div>
                    <div class="stat-content">
                        <h3>Fichiers média</h3>
                        <p id="media-count"><?php echo count($mediaFiles); ?></p>
                        <div class="sub-text">Vidéos et images</div>
                    </div>
                </div>
            </div>

            <div class="grid-2">
                <!-- Player Controls -->
                <div class="card">
                    <h2>🎮 Contrôles du lecteur</h2>
                    <div class="btn-group">
                        <button class="btn btn-success" onclick="playerAction('play')">
                            ▶️ Lecture
                        </button>
                        <button class="btn btn-warning" onclick="playerAction('restart')">
                            🔄 Redémarrer
                        </button>
                        <button class="btn btn-danger" onclick="playerAction('stop')">
                            ⏹️ Arrêter
                        </button>
                    </div>
                </div>

                <!-- Screenshot Preview -->
                <div class="card">
                    <h2>📸 Aperçu écran</h2>
                    <div class="screenshot-container">
                        <div id="screenshot-placeholder" class="screenshot-placeholder">
                            <div>
                                <div style="font-size: 2rem; margin-bottom: 0.5rem;">📺</div>
                                <div>Cliquez pour prendre une capture d'écran</div>
                            </div>
                        </div>
                        <img id="screenshot-preview" class="screenshot-preview" style="display: none;" alt="Screenshot">
                        <button class="btn btn-primary" onclick="takeScreenshot()">
                            📸 Prendre une capture
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Media Tab -->
        <div id="media-tab" class="tab-content">
            <div class="grid-2">
                <!-- Upload Section -->
                <div class="card">
                    <h2>📤 Upload de médias</h2>
                    <div class="upload-zone" id="uploadZone">
                        <input type="file" id="fileInput" class="upload-input" accept="video/*,image/*" multiple>
                        <div class="icon">📁</div>
                        <h3>Glissez vos fichiers ici</h3>
                        <p>ou cliquez pour sélectionner</p>
                        <p style="font-size: 0.875rem; color: var(--text-light); margin-top: 1rem;">
                            Formats supportés: MP4, AVI, MKV, MOV, WEBM, JPG, PNG, GIF<br>
                            Taille max: 500MB
                        </p>
                    </div>
                    <div class="progress-bar" id="progressBar">
                        <div class="progress-fill" id="progressFill"></div>
                    </div>
                </div>

                <!-- Quick Actions -->
                <div class="card">
                    <h2>⚡ Actions rapides</h2>
                    <div class="btn-group">
                        <button class="btn btn-info" onclick="downloadTestVideos()">
                            📥 Vidéos de test
                        </button>
                        <button class="btn btn-warning" onclick="optimizeMedia()">
                            🔧 Optimiser médias
                        </button>
                        <button class="btn btn-danger" onclick="cleanupMedia()">
                            🗑️ Nettoyer
                        </button>
                    </div>
                </div>
            </div>

            <!-- Media Library -->
            <div class="card">
                <h2>📁 Bibliothèque de médias</h2>
                <div id="mediaList" class="media-list">
                    <?php if (empty($mediaFiles)): ?>
                        <div class="empty-state">
                            <div class="icon">🎬</div>
                            <h3>Aucun fichier média</h3>
                            <p>Uploadez des vidéos ou images pour commencer</p>
                        </div>
                    <?php else: ?>
                        <?php foreach ($mediaFiles as $file): ?>
                            <div class="media-item">
                                <div class="media-icon">
                                    <?php echo $file['type'] === 'video' ? '🎬' : '🖼️'; ?>
                                </div>
                                <div class="media-info">
                                    <div class="media-name"><?php echo htmlspecialchars($file['name']); ?></div>
                                    <div class="media-meta">
                                        <?php echo $file['size_formatted']; ?> • 
                                        <?php echo $file['duration']; ?>s • 
                                        <?php echo $file['modified']; ?>
                                    </div>
                                </div>
                                <div class="media-actions">
                                    <button class="btn btn-success btn-small" onclick="playVideo('<?php echo htmlspecialchars($file['name']); ?>')">
                                        ▶️ Lire
                                    </button>
                                    <button class="btn btn-info btn-small" onclick="addToPlaylist('<?php echo htmlspecialchars($file['name']); ?>')">
                                        ➕ Playlist
                                    </button>
                                    <button class="btn btn-danger btn-small" onclick="deleteVideo('<?php echo htmlspecialchars($file['name']); ?>')">
                                        🗑️
                                    </button>
                                </div>
                            </div>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </div>
            </div>
        </div>

        <!-- Playlists Tab -->
        <div id="playlists-tab" class="tab-content">
            <div class="grid-2">
                <!-- Playlist Manager -->
                <div class="card">
                    <h2>📑 Gestionnaire de playlists</h2>
                    <div class="btn-group">
                        <button class="btn btn-primary" onclick="createPlaylist()">
                            ➕ Nouvelle playlist
                        </button>
                        <button class="btn btn-info" onclick="importPlaylist()">
                            📥 Importer
                        </button>
                        <button class="btn btn-secondary" onclick="exportPlaylist()">
                            📤 Exporter
                        </button>
                    </div>
                    <div id="playlistList" class="media-list" style="margin-top: 1rem;">
                        <!-- Playlists will be loaded here -->
                    </div>
                </div>

                <!-- Playlist Builder -->
                <div class="card">
                    <h2>🎵 Éditeur de playlist</h2>
                    <div class="playlist-builder">
                        <div class="form-group">
                            <label class="form-label">Nom de la playlist</label>
                            <input type="text" class="form-input" id="playlistName" placeholder="Ma nouvelle playlist">
                        </div>
                        <div class="form-group">
                            <label class="form-label">Description</label>
                            <input type="text" class="form-input" id="playlistDescription" placeholder="Description optionnelle">
                        </div>
                        <div id="playlistItems">
                            <div class="empty-state">
                                <div class="icon">🎵</div>
                                <p>Glissez des médias ici pour créer une playlist</p>
                            </div>
                        </div>
                        <div class="btn-group">
                            <button class="btn btn-success" onclick="savePlaylist()">
                                💾 Sauvegarder
                            </button>
                            <button class="btn btn-secondary" onclick="clearPlaylist()">
                                🗑️ Vider
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- YouTube Tab -->
        <div id="youtube-tab" class="tab-content">
            <div class="youtube-section">
                <h2 style="color: white; margin-bottom: 1rem;">📺 Téléchargement YouTube</h2>
                <p style="opacity: 0.9;">Téléchargez des vidéos YouTube directement dans votre bibliothèque</p>
                <div class="youtube-form">
                    <input type="text" class="youtube-input" id="youtubeUrl" placeholder="https://www.youtube.com/watch?v=...">
                    <select class="youtube-quality" id="youtubeQuality">
                        <option value="720p">HD 720p (recommandé)</option>
                        <option value="480p">SD 480p</option>
                        <option value="360p">SD 360p</option>
                        <option value="best">Meilleure qualité</option>
                        <option value="worst">Plus faible qualité</option>
                    </select>
                    <input type="text" class="youtube-input" id="youtubeName" placeholder="Nom personnalisé (optionnel)" style="min-width: 200px;">
                    <button class="btn btn-primary" onclick="downloadYoutube()">
                        📥 Télécharger
                    </button>
                </div>
            </div>

            <div class="grid-2">
                <!-- Video Preview -->
                <div class="card">
                    <h2>🎬 Aperçu vidéo</h2>
                    <div id="videoPreview">
                        <div class="empty-state">
                            <div class="icon">🎬</div>
                            <p>Entrez une URL YouTube pour voir l'aperçu</p>
                        </div>
                    </div>
                    <button class="btn btn-info" onclick="previewYoutube()">
                        🔍 Aperçu
                    </button>
                </div>

                <!-- Download Queue -->
                <div class="card">
                    <h2>📥 File de téléchargement</h2>
                    <div id="downloadQueue" class="media-list">
                        <div class="empty-state">
                            <div class="icon">📥</div>
                            <p>Aucun téléchargement en cours</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Scheduling Tab -->
        <div id="scheduling-tab" class="tab-content">
            <div class="grid-2">
                <!-- Schedule Builder -->
                <div class="card">
                    <h2>⏰ Programmateur</h2>
                    <div class="form-group">
                        <label class="form-label">Playlist</label>
                        <select class="form-select" id="schedulePlaylist">
                            <option value="">Sélectionner une playlist</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Jours de la semaine</label>
                        <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
                            <label><input type="checkbox" value="monday"> Lundi</label>
                            <label><input type="checkbox" value="tuesday"> Mardi</label>
                            <label><input type="checkbox" value="wednesday"> Mercredi</label>
                            <label><input type="checkbox" value="thursday"> Jeudi</label>
                            <label><input type="checkbox" value="friday"> Vendredi</label>
                            <label><input type="checkbox" value="saturday"> Samedi</label>
                            <label><input type="checkbox" value="sunday"> Dimanche</label>
                        </div>
                    </div>
                    <div class="grid-2">
                        <div class="form-group">
                            <label class="form-label">Heure de début</label>
                            <input type="time" class="form-input" id="scheduleStartTime">
                        </div>
                        <div class="form-group">
                            <label class="form-label">Heure de fin</label>
                            <input type="time" class="form-input" id="scheduleEndTime">
                        </div>
                    </div>
                    <button class="btn btn-primary" onclick="saveSchedule()">
                        💾 Programmer
                    </button>
                </div>

                <!-- Active Schedules -->
                <div class="card">
                    <h2>📅 Programmations actives</h2>
                    <div id="activeSchedules" class="media-list">
                        <div class="empty-state">
                            <div class="icon">📅</div>
                            <p>Aucune programmation définie</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Display Tab -->
        <div id="display-tab" class="tab-content">
            <div class="grid-2">
                <!-- Display Settings FONCTIONNELS -->
                <div class="card">
                    <h2>🖥️ Configuration affichage</h2>
                    
                    <div class="form-group">
                        <label class="form-label">Volume audio (%)</label>
                        <input type="range" class="form-input" id="displayVolume" min="0" max="100" value="80" onchange="updateVolume(this.value)">
                        <div style="text-align: center; margin-top: 0.5rem;">
                            <span id="volumeValue">80</span>%
                        </div>
                    </div>
                    
                    <div class="form-group">
                        <label class="form-label">Durée d'affichage des images (secondes)</label>
                        <input type="number" class="form-input" id="imageDuration" value="10" min="1" max="300" step="1">
                        <small style="color: #666;">Temps d'affichage par défaut pour les images dans les playlists</small>
                    </div>
                    
                    <div class="form-group">
                        <label class="form-label">Mode de lecture</label>
                        <select class="form-select" id="playbackMode">
                            <option value="loop">Boucle infinie</option>
                            <option value="once">Une fois</option>
                            <option value="random">Aléatoire</option>
                        </select>
                    </div>
                    
                    <button class="btn btn-primary btn-full" onclick="saveDisplaySettings()">
                        💾 Sauvegarder les paramètres
                    </button>
                </div>

                <!-- Playlist Active -->
                <div class="card">
                    <h2>📋 Playlist Active</h2>
                    <div id="activePlaylistInfo">
                        <div class="empty-state">
                            <div class="icon">📁</div>
                            <p>Playlist par défaut (tous les médias)</p>
                        </div>
                    </div>
                    
                    <div class="form-group" style="margin-top: 1rem;">
                        <label class="form-label">Changer de playlist</label>
                        <select class="form-select" id="activePlaylistSelect" onchange="changeActivePlaylist(this.value)">
                            <option value="default">Playlist par défaut</option>
                        </select>
                    </div>
                    
                    <div class="btn-group" style="margin-top: 1rem;">
                        <button class="btn btn-success" onclick="restartPlaylist()">
                            🔄 Redémarrer playlist
                        </button>
                        <button class="btn btn-info" onclick="refreshPlaylistInfo()">
                            🔃 Actualiser infos
                        </button>
                    </div>
                </div>
            </div>
            
            <div class="card" style="margin-top: 1rem;">
                <h2>ℹ️ Informations système</h2>
                <div id="displayInfo" style="font-family: monospace; padding: 1rem; background: #f5f5f5; border-radius: 4px;">
                    <div>Chargement des informations...</div>
                </div>
                <button class="btn btn-secondary" onclick="getPlaylistStatus()" style="margin-top: 1rem;">
                    📊 Statut du lecteur
                </button>
            </div>
        </div>

        <!-- Settings Tab -->
        <div id="settings-tab" class="tab-content">
            <div class="grid-2">
                <!-- System Settings -->
                <div class="card">
                    <h2>⚙️ Configuration système</h2>
                    <div class="form-group">
                        <label class="form-label">Nom d'affichage</label>
                        <input type="text" class="form-input" id="systemName" value="PiSignage Display">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Démarrage automatique</label>
                        <select class="form-select" id="autoStart">
                            <option value="true">Activé</option>
                            <option value="false">Désactivé</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Mode veille après (minutes)</label>
                        <input type="number" class="form-input" id="sleepTimeout" value="0" min="0" max="1440">
                        <small style="color: var(--text-light);">0 = jamais</small>
                    </div>
                    <button class="btn btn-success" onclick="saveSystemSettings()">
                        💾 Sauvegarder
                    </button>
                </div>

                <!-- Network Settings -->
                <div class="card">
                    <h2>🌐 Configuration réseau</h2>
                    <div class="form-group">
                        <label class="form-label">WiFi SSID</label>
                        <input type="text" class="form-input" id="wifiSSID" readonly>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Adresse IP</label>
                        <input type="text" class="form-input" id="ipAddress" readonly>
                    </div>
                    <div class="btn-group">
                        <button class="btn btn-info" onclick="scanWiFi()">
                            📡 Scanner WiFi
                        </button>
                        <button class="btn btn-warning" onclick="resetNetwork()">
                            🔄 Reset réseau
                        </button>
                    </div>
                </div>
            </div>

            <!-- Maintenance -->
            <div class="card">
                <h2>🔧 Maintenance</h2>
                <div class="grid-3">
                    <div>
                        <h3>Sauvegarde</h3>
                        <div class="btn-group">
                            <button class="btn btn-info" onclick="createBackup()">
                                💾 Créer sauvegarde
                            </button>
                            <button class="btn btn-warning" onclick="restoreBackup()">
                                📥 Restaurer
                            </button>
                        </div>
                    </div>
                    <div>
                        <h3>Système</h3>
                        <div class="btn-group">
                            <button class="btn btn-warning" onclick="restartSystem()">
                                🔄 Redémarrer
                            </button>
                            <button class="btn btn-danger" onclick="shutdownSystem()">
                                ⏻ Éteindre
                            </button>
                        </div>
                    </div>
                    <div>
                        <h3>Logs</h3>
                        <div class="btn-group">
                            <button class="btn btn-info" onclick="viewLogs()">
                                📄 Voir logs
                            </button>
                            <button class="btn btn-warning" onclick="clearLogs()">
                                🗑️ Vider logs
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Global Alert -->
        <div id="alert" class="alert"></div>
    </div>

    <script>
        // Global variables
        let currentTab = 'dashboard';
        let mediaFiles = <?php echo json_encode($mediaFiles); ?>;
        let playlists = [];
        let activePlaylist = null;
        let downloadQueue = [];

        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            setupUpload();
            loadPlaylists();
            loadDownloadQueue();
            setupVolumeSlider();
            
            // Auto-refresh every 30 seconds
            setInterval(refreshSystemStats, 30000);
            
            // Auto-refresh download queue every 5 seconds
            setInterval(updateDownloadQueue, 5000);
        });

        // Tab Management
        function switchTab(tabName, e) {
            // Hide all tabs
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
            });
            
            // Remove active class from all nav tabs
            document.querySelectorAll('.nav-tab').forEach(tab => {
                tab.classList.remove('active');
            });
            
            // Show selected tab
            document.getElementById(tabName + '-tab').classList.add('active');
            
            // Add active class to the clicked button (if event provided)
            if (e && e.target) {
                e.target.classList.add('active');
            } else {
                // Find and activate the corresponding nav button
                document.querySelectorAll('.nav-tab').forEach(tab => {
                    if (tab.onclick && tab.onclick.toString().includes(tabName)) {
                        tab.classList.add('active');
                    }
                });
            }
            
            currentTab = tabName;
            
            // Load tab-specific data
            if (tabName === 'playlists') {
                loadPlaylists();
            } else if (tabName === 'youtube') {
                updateDownloadQueue();
            }
        }

        // Screenshot functionality
        function takeScreenshot() {
            const placeholder = document.getElementById('screenshot-placeholder');
            const preview = document.getElementById('screenshot-preview');
            
            placeholder.innerHTML = '<div class="loading"></div><div>Capture en cours...</div>';
            
            fetch('/api/screenshot.php', {
                method: 'POST'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    preview.src = data.screenshot + '?t=' + Date.now();
                    preview.style.display = 'block';
                    placeholder.style.display = 'none';
                    showAlert('Capture d\'écran prise avec succès', 'success');
                } else {
                    placeholder.innerHTML = `
                        <div>
                            <div style="font-size: 2rem; margin-bottom: 0.5rem;">❌</div>
                            <div>Erreur: ${data.message}</div>
                        </div>
                    `;
                    showAlert('Erreur lors de la capture: ' + data.message, 'error');
                }
            })
            .catch(error => {
                placeholder.innerHTML = `
                    <div>
                        <div style="font-size: 2rem; margin-bottom: 0.5rem;">❌</div>
                        <div>Erreur de connexion</div>
                    </div>
                `;
                showAlert('Erreur de connexion: ' + error, 'error');
            });
        }

        // Upload functionality
        function setupUpload() {
            const zone = document.getElementById('uploadZone');
            const input = document.getElementById('fileInput');

            // Attacher l'event listener à l'input file
            input.addEventListener('change', (e) => handleFiles(e.target.files));

            zone.addEventListener('click', () => input.click());

            zone.addEventListener('dragover', (e) => {
                e.preventDefault();
                zone.classList.add('dragover');
            });

            zone.addEventListener('dragleave', () => {
                zone.classList.remove('dragover');
            });

            zone.addEventListener('drop', (e) => {
                e.preventDefault();
                zone.classList.remove('dragover');
                handleFiles(e.dataTransfer.files);
            });

            input.addEventListener('change', (e) => {
                handleFiles(e.target.files);
            });
        }

        function handleFiles(files) {
            for (let file of files) {
                uploadFile(file);
            }
        }

        async function uploadFile(file) {
            console.log('📤 Uploading file:', file.name, 'Size:', file.size);
            
            const CHUNK_SIZE = 2 * 1024 * 1024; // 2MB par chunk
            const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
            const fileId = Date.now() + '_' + Math.random().toString(36).substr(2, 9);
            
            const progressBar = document.getElementById('progressBar');
            const progressFill = document.getElementById('progressFill');
            let progressText = document.getElementById('progressText');
            
            // Créer l'élément de texte de progression s'il n'existe pas
            if (!progressText) {
                progressText = document.createElement('div');
                progressText.id = 'progressText';
                progressText.style.cssText = 'text-align:center;margin-top:5px;font-size:12px;color:#666;';
                if (progressBar && progressBar.parentNode) {
                    progressBar.parentNode.insertBefore(progressText, progressBar.nextSibling);
                }
            }
            
            progressBar.style.display = 'block';
            progressFill.style.width = '0%';
            
            // Vérifier s'il y a déjà des chunks uploadés (reprise après interruption)
            let uploadedChunks = [];
            try {
                const checkResponse = await fetch(`/api/upload-chunked.php?action=check&fileId=${fileId}`);
                const checkData = await checkResponse.json();
                if (checkData.success && checkData.uploadedChunks) {
                    uploadedChunks = checkData.uploadedChunks;
                }
            } catch (e) {
                console.log('Nouvel upload, pas de chunks existants');
            }
            
            try {
                // Upload par chunks
                for (let chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
                    // Passer les chunks déjà uploadés
                    if (uploadedChunks.includes(chunkIndex)) {
                        continue;
                    }
                    
                    const start = chunkIndex * CHUNK_SIZE;
                    const end = Math.min(start + CHUNK_SIZE, file.size);
                    const chunk = file.slice(start, end);
                    
                    const response = await fetch('/api/upload-chunked.php?action=upload', {
                        method: 'POST',
                        headers: {
                            'X-File-Name': file.name,
                            'X-Chunk-Index': chunkIndex,
                            'X-Total-Chunks': totalChunks,
                            'X-File-Id': fileId
                        },
                        body: chunk
                    });
                    
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    
                    const result = await response.json();
                    
                    if (!result.success) {
                        throw new Error(result.error || 'Upload échoué');
                    }
                    
                    // Mettre à jour la progression
                    const progress = ((chunkIndex + 1) / totalChunks) * 100;
                    progressFill.style.width = progress + '%';
                    
                    // Afficher le texte de progression
                    const uploaded = (chunkIndex + 1) * CHUNK_SIZE;
                    const uploadedMB = Math.min(uploaded, file.size) / (1024 * 1024);
                    const totalMB = file.size / (1024 * 1024);
                    progressText.textContent = `${uploadedMB.toFixed(1)} MB / ${totalMB.toFixed(1)} MB (${Math.round(progress)}%)`;
                    
                    // Si upload complet
                    if (result.complete) {
                        console.log('✅ Upload terminé:', result);
                        progressFill.style.width = '100%';
                        progressText.textContent = 'Upload terminé !';
                        
                        // Rafraîchir la liste des médias
                        if (result.files) {
                            updateMediaList(result.files);
                        } else {
                            refreshMediaList();
                        }
                        
                        setTimeout(() => {
                            progressBar.style.display = 'none';
                            if (progressText) progressText.textContent = '';
                        }, 2000);
                        
                        showAlert(`✅ ${file.name} uploadé avec succès`, 'success');
                    }
                }
            } catch (error) {
                console.error('❌ Upload error:', error);
                progressFill.style.backgroundColor = '#e74c3c';
                progressText.textContent = 'Erreur : ' + error.message;
                
                // Permettre la reprise
                showAlert(`❌ Erreur: ${error.message}. Réessayez pour reprendre l'upload.`, 'error');
                
                setTimeout(() => {
                    progressBar.style.display = 'none';
                    progressFill.style.backgroundColor = '#3498db';
                    if (progressText) progressText.textContent = '';
                }, 3000);
            }
        }

        // Player controls
        function playerAction(action) {
            fetch('?action=' + action, {
                method: 'POST'
            })
            .then(response => response.json())
            .then(data => {
                showAlert(data.message, data.success ? 'success' : 'error');
                refreshSystemStats();
            })
            .catch(error => {
                showAlert('Action failed: ' + error, 'error');
            });
        }

        function playVideo(video) {
            fetch('/api/control.php?action=play', {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'video=' + encodeURIComponent(video)
            })
            .then(response => response.json())
            .then(data => {
                showAlert(data.message, data.success ? 'success' : 'error');
                refreshSystemStats();
            })
            .catch(error => {
                showAlert('Play failed: ' + error, 'error');
            });
        }

        function deleteVideo(video) {
            if (!confirm('Supprimer ' + video + ' ?')) return;

            fetch('/api/control.php?action=delete', {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'video=' + encodeURIComponent(video)
            })
            .then(response => response.json())
            .then(data => {
                showAlert(data.message, data.success ? 'success' : 'error');
                if (data.success) {
                    refreshMediaList();
                }
            })
            .catch(error => {
                showAlert('Delete failed: ' + error, 'error');
            });
        }

        // System data refresh
        function refreshSystemStats() {
            fetch('/api/control.php?action=status')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    updateSystemStats(data.data);
                }
            });
        }

        function updateSystemStats(data) {
            // Update status indicators
            document.querySelectorAll('.status-indicator').forEach(el => {
                el.className = 'status-indicator ' + (data.vlc_running ? 'online' : 'offline');
            });

            // Update stat values
            document.getElementById('player-status').textContent = 
                data.vlc_running ? 'En lecture' : 'Arrêté';
            document.getElementById('cpu-temp').textContent = data.cpu_temp + '°C';
            document.getElementById('memory-usage').textContent = data.mem_percent + '%';
            document.getElementById('disk-usage').textContent = data.disk_percent + '%';
        }


        // Missing function: updateMediaList - updates the media list with new data
        function updateMediaList(files) {
            const mediaListContainer = document.getElementById('mediaList');
            
            if (!files || files.length === 0) {
                mediaListContainer.innerHTML = `
                    <div class="empty-state">
                        <div class="icon">🎬</div>
                        <h3>Aucun fichier média</h3>
                        <p>Uploadez des vidéos ou images pour commencer</p>
                    </div>
                `;
                return;
            }
            
            let html = '';
            files.forEach(file => {
                const icon = file.type === 'video' ? '🎬' : '🖼️';
                html += `
                    <div class="media-item">
                        <div class="media-icon">${icon}</div>
                        <div class="media-info">
                            <div class="media-name">${file.name}</div>
                            <div class="media-meta">
                                ${file.size_formatted} • ${file.duration}s • ${file.modified}
                            </div>
                        </div>
                        <div class="media-actions">
                            <button class="btn btn-success btn-small" onclick="playVideo('${file.name}')">
                                ▶️ Lire
                            </button>
                            <button class="btn btn-secondary btn-small" onclick="addToPlaylist('${file.name}')">
                                ➕ Ajouter
                            </button>
                            <button class="btn btn-danger btn-small" onclick="deleteMedia('${file.name}')">
                                🗑️ Supprimer
                            </button>
                        </div>
                    </div>
                `;
            });
            
            mediaListContainer.innerHTML = html;
        }
        function refreshMediaList() {
            fetch('/api/playlist.php?action=list')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    updateMediaList(data.files);
                    document.getElementById('media-count').textContent = data.files.length;
                }
            });
        }

        function refreshAllData() {
            showAlert('Actualisation en cours...', 'info');
            refreshSystemStats();
            refreshMediaList();
            loadPlaylists();
            updateDownloadQueue();
            showAlert('Données actualisées', 'success');
        }

        // YouTube functionality
        function previewYoutube() {
            const url = document.getElementById('youtubeUrl').value;
            if (!url) {
                showAlert('Veuillez entrer une URL YouTube', 'warning');
                return;
            }

            const preview = document.getElementById('videoPreview');
            preview.innerHTML = '<div class="loading"></div><div>Chargement des informations...</div>';

            // Call YouTube API to get video info
            fetch('/api/youtube.php?action=info&url=' + encodeURIComponent(url))
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    preview.innerHTML = `
                        <div style="text-align: left;">
                            <h3>${data.info.title}</h3>
                            <p><strong>Auteur:</strong> ${data.info.uploader}</p>
                            <p><strong>Durée:</strong> ${data.info.duration_formatted}</p>
                            <p><strong>Vues:</strong> ${data.info.view_count.toLocaleString()}</p>
                            <p>${data.info.description}</p>
                        </div>
                    `;
                } else {
                    preview.innerHTML = `
                        <div class="empty-state">
                            <div class="icon">❌</div>
                            <p>Erreur: ${data.error}</p>
                        </div>
                    `;
                }
            })
            .catch(error => {
                preview.innerHTML = `
                    <div class="empty-state">
                        <div class="icon">❌</div>
                        <p>Erreur de connexion</p>
                    </div>
                `;
            });
        }

        function downloadYoutube() {
            const url = document.getElementById('youtubeUrl').value;
            const quality = document.getElementById('youtubeQuality').value;
            const customName = document.getElementById('youtubeName').value;

            if (!url) {
                showAlert('Veuillez entrer une URL YouTube', 'warning');
                return;
            }

            const data = {
                url: url,
                quality: quality,
                name: customName || null
            };

            fetch('/api/youtube.php?action=download', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(data)
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Téléchargement démarré', 'success');
                    // Clear form
                    document.getElementById('youtubeUrl').value = '';
                    document.getElementById('youtubeName').value = '';
                    // Update download queue
                    updateDownloadQueue();
                } else {
                    showAlert('Erreur: ' + data.error, 'error');
                }
            })
            .catch(error => {
                showAlert('Erreur de connexion: ' + error, 'error');
            });
        }

        function updateDownloadQueue() {
            fetch('/api/youtube.php?action=status')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    displayDownloadQueue(data.downloads.queue);
                }
            })
            .catch(error => {
                console.error('Error updating download queue:', error);
            });
        }

        function displayDownloadQueue(queue) {
            const container = document.getElementById('downloadQueue');
            
            if (queue.length === 0) {
                container.innerHTML = `
                    <div class="empty-state">
                        <div class="icon">📥</div>
                        <p>Aucun téléchargement en cours</p>
                    </div>
                `;
                return;
            }

            container.innerHTML = queue.map(item => {
                let statusIcon = '⏳';
                let statusColor = 'var(--text-light)';
                
                switch(item.status) {
                    case 'downloading':
                        statusIcon = '📥';
                        statusColor = 'var(--info)';
                        break;
                    case 'completed':
                        statusIcon = '✅';
                        statusColor = 'var(--success)';
                        break;
                    case 'failed':
                        statusIcon = '❌';
                        statusColor = 'var(--danger)';
                        break;
                    case 'cancelled':
                        statusIcon = '🚫';
                        statusColor = 'var(--warning)';
                        break;
                }

                return `
                    <div class="media-item">
                        <div class="media-icon" style="background: ${statusColor};">
                            ${statusIcon}
                        </div>
                        <div class="media-info">
                            <div class="media-name">${item.custom_name || item.video_id}</div>
                            <div class="media-meta">
                                ${item.quality} • ${item.message}
                                ${item.progress > 0 ? ` • ${item.progress}%` : ''}
                            </div>
                        </div>
                        <div class="media-actions">
                            ${item.status === 'downloading' ? 
                                `<button class="btn btn-danger btn-small" onclick="cancelDownload('${item.id}')">❌</button>` : 
                                ''
                            }
                        </div>
                    </div>
                `;
            }).join('');
        }

        function cancelDownload(downloadId) {
            fetch('/api/youtube.php?action=cancel', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({id: downloadId})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Téléchargement annulé', 'info');
                    updateDownloadQueue();
                } else {
                    showAlert('Erreur: ' + data.error, 'error');
                }
            });
        }

        // Playlist functionality
        function loadPlaylists() {
            fetch('/api/playlist.php?action=list')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    displayPlaylists(data.playlists);
                    playlists = data.playlists;
                    activePlaylist = data.active_playlist;
                }
            })
            .catch(error => {
                console.error('Error loading playlists:', error);
            });
        }

        function displayPlaylists(playlistArray) {
            const container = document.getElementById('playlistList');
            
            if (playlistArray.length === 0) {
                container.innerHTML = `
                    <div class="empty-state">
                        <div class="icon">📑</div>
                        <p>Aucune playlist créée</p>
                    </div>
                `;
                return;
            }

            container.innerHTML = playlistArray.map(playlist => `
                <div class="media-item">
                    <div class="media-icon" style="background: ${playlist.id === activePlaylist ? 'var(--success)' : 'var(--primary)'};">
                        📑
                    </div>
                    <div class="media-info">
                        <div class="media-name">
                            ${playlist.name}
                            ${playlist.id === activePlaylist ? ' (Active)' : ''}
                        </div>
                        <div class="media-meta">
                            ${playlist.items.length} éléments • ${playlist.modified}
                        </div>
                    </div>
                    <div class="media-actions">
                        <button class="btn btn-success btn-small" onclick="activatePlaylist('${playlist.id}')">
                            ▶️
                        </button>
                        <button class="btn btn-info btn-small" onclick="editPlaylist('${playlist.id}')">
                            ✏️
                        </button>
                        <button class="btn btn-danger btn-small" onclick="deletePlaylist('${playlist.id}')">
                            🗑️
                        </button>
                    </div>
                </div>
            `).join('');
        }

        function createPlaylist() {
            const name = document.getElementById('playlistName').value;
            const description = document.getElementById('playlistDescription').value;
            
            if (!name) {
                showAlert('Veuillez entrer un nom pour la playlist', 'warning');
                return;
            }

            const playlist = {
                name: name,
                description: description,
                items: [],
                settings: {
                    loop: true,
                    shuffle: false,
                    transition: 'fade',
                    transition_duration: 1000
                }
            };

            fetch('/api/playlist.php', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(playlist)
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist créée avec succès', 'success');
                    loadPlaylists();
                    clearPlaylistForm();
                } else {
                    showAlert('Erreur: ' + data.error, 'error');
                }
            });
        }

        function clearPlaylistForm() {
            document.getElementById('playlistName').value = '';
            document.getElementById('playlistDescription').value = '';
            document.getElementById('playlistItems').innerHTML = `
                <div class="empty-state">
                    <div class="icon">🎵</div>
                    <p>Glissez des médias ici pour créer une playlist</p>
                </div>
            `;
        }

        function activatePlaylist(playlistId) {
            fetch(`/api/playlist.php?id=${playlistId}&action=activate`, {
                method: 'PUT'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist activée', 'success');
                    loadPlaylists();
                } else {
                    showAlert('Erreur: ' + data.error, 'error');
                }
            });
        }

        function deletePlaylist(playlistId) {
            if (!confirm('Supprimer cette playlist ?')) return;

            fetch(`/api/playlist.php?id=${playlistId}`, {
                method: 'DELETE'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist supprimée', 'success');
                    loadPlaylists();
                } else {
                    showAlert('Erreur: ' + data.error, 'error');
                }
            });
        }
        
        // Fonction pour éditer une playlist
        function editPlaylist(playlistId) {
            const playlist = playlists.find(p => p.id === playlistId);
            if (!playlist) {
                showAlert('Playlist introuvable', 'error');
                return;
            }
            
            // Pré-remplir le formulaire avec les données de la playlist
            document.getElementById('playlist-name').value = playlist.name || '';
            document.getElementById('playlist-loop').checked = playlist.loop || false;
            document.getElementById('playlist-random').checked = playlist.random || false;
            document.getElementById('playlist-transition').value = playlist.transition || 'none';
            
            // Afficher les vidéos de la playlist
            const container = document.getElementById('playlist-videos');
            container.innerHTML = '';
            
            if (playlist.videos && playlist.videos.length > 0) {
                playlist.videos.forEach(video => {
                    const videoItem = document.createElement('div');
                    videoItem.className = 'playlist-item';
                    videoItem.innerHTML = `
                        <span>${video}</span>
                        <button class="btn btn-danger btn-sm" onclick="removeFromPlaylist('${video}')">
                            <i class="fas fa-times"></i>
                        </button>
                    `;
                    container.appendChild(videoItem);
                });
            }
            
            // Mettre à jour le bouton pour sauvegarder au lieu de créer
            const saveBtn = document.querySelector('#playlist-form button[onclick="createPlaylist()"]');
            if (saveBtn) {
                saveBtn.setAttribute('onclick', `updatePlaylist('${playlistId}')`);
                saveBtn.innerHTML = '<i class="fas fa-save"></i> Mettre à jour';
            }
            
            showAlert('Mode édition activé', 'info');
        }
        
        // Fonction pour mettre à jour une playlist
        function updatePlaylist(playlistId) {
            const name = document.getElementById('playlist-name').value;
            const videos = Array.from(document.querySelectorAll('#playlist-videos .playlist-item span'))
                .map(span => span.textContent);
            
            if (!name) {
                showAlert('Nom requis', 'error');
                return;
            }
            
            const playlist = {
                id: playlistId,
                name: name,
                videos: videos,
                loop: document.getElementById('playlist-loop').checked,
                random: document.getElementById('playlist-random').checked,
                transition: document.getElementById('playlist-transition').value
            };
            
            fetch('/api/playlist.php', {
                method: 'PUT',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({action: 'update', playlist: playlist})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist mise à jour', 'success');
                    loadPlaylists();
                    clearPlaylistForm();
                    
                    // Réinitialiser le bouton
                    const saveBtn = document.querySelector('#playlist-form button[onclick*="updatePlaylist"]');
                    if (saveBtn) {
                        saveBtn.setAttribute('onclick', 'createPlaylist()');
                        saveBtn.innerHTML = '<i class="fas fa-save"></i> Créer Playlist';
                    }
                } else {
                    showAlert('Erreur: ' + (data.error || 'Mise à jour échouée'), 'error');
                }
            })
            .catch(error => {
                console.error('Update error:', error);
                showAlert('Erreur de mise à jour', 'error');
            });
        }
        
        // Fonction pour importer une playlist
        function importPlaylist() {
            const input = document.createElement('input');
            input.type = 'file';
            input.accept = '.json';
            
            input.onchange = function(e) {
                const file = e.target.files[0];
                if (!file) return;
                
                const reader = new FileReader();
                reader.onload = function(event) {
                    try {
                        const playlist = JSON.parse(event.target.result);
                        
                        // Valider la structure
                        if (!playlist.name || !Array.isArray(playlist.videos)) {
                            throw new Error('Format de playlist invalide');
                        }
                        
                        // Créer la playlist importée
                        fetch('/api/playlist.php', {
                            method: 'POST',
                            headers: {'Content-Type': 'application/json'},
                            body: JSON.stringify({action: 'create', playlist: playlist})
                        })
                        .then(response => response.json())
                        .then(data => {
                            if (data.success) {
                                showAlert(`Playlist "${playlist.name}" importée`, 'success');
                                loadPlaylists();
                            } else {
                                showAlert('Erreur d\'import: ' + data.error, 'error');
                            }
                        });
                        
                    } catch (error) {
                        showAlert('Fichier invalide: ' + error.message, 'error');
                    }
                };
                
                reader.readAsText(file);
            };
            
            input.click();
        }
        
        // Fonction pour exporter une playlist
        function exportPlaylist() {
            if (playlists.length === 0) {
                showAlert('Aucune playlist à exporter', 'warning');
                return;
            }
            
            // Si une seule playlist, l'exporter directement
            if (playlists.length === 1) {
                downloadPlaylistAsJSON(playlists[0]);
                return;
            }
            
            // Si plusieurs playlists, demander laquelle exporter
            const select = document.createElement('select');
            select.className = 'form-control';
            select.innerHTML = '<option value="">Choisir une playlist...</option>';
            
            playlists.forEach(playlist => {
                const option = document.createElement('option');
                option.value = playlist.id;
                option.textContent = playlist.name;
                select.appendChild(option);
            });
            
            // Créer un modal simple
            const modal = document.createElement('div');
            modal.className = 'modal';
            modal.style.cssText = 'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);background:white;padding:20px;border-radius:5px;box-shadow:0 2px 10px rgba(0,0,0,0.2);z-index:10000';
            modal.innerHTML = `
                <h4>Exporter une playlist</h4>
                <div style="margin: 15px 0"></div>
                <div style="display:flex;gap:10px;margin-top:15px">
                    <button class="btn btn-primary" id="export-confirm">Exporter</button>
                    <button class="btn btn-secondary" id="export-cancel">Annuler</button>
                </div>
            `;
            modal.querySelector('div').appendChild(select);
            
            // Ajouter un fond sombre
            const overlay = document.createElement('div');
            overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);z-index:9999';
            
            document.body.appendChild(overlay);
            document.body.appendChild(modal);
            
            // Gérer les événements
            document.getElementById('export-confirm').onclick = () => {
                const selectedId = select.value;
                if (selectedId) {
                    const playlist = playlists.find(p => p.id === selectedId);
                    if (playlist) {
                        downloadPlaylistAsJSON(playlist);
                    }
                }
                document.body.removeChild(modal);
                document.body.removeChild(overlay);
            };
            
            document.getElementById('export-cancel').onclick = () => {
                document.body.removeChild(modal);
                document.body.removeChild(overlay);
            };
        }
        
        // Fonction helper pour télécharger une playlist en JSON
        function downloadPlaylistAsJSON(playlist) {
            const dataStr = JSON.stringify(playlist, null, 2);
            const dataUri = 'data:application/json;charset=utf-8,' + encodeURIComponent(dataStr);
            
            const exportFileDefaultName = `playlist_${playlist.name.replace(/\s+/g, '_')}_${Date.now()}.json`;
            
            const linkElement = document.createElement('a');
            linkElement.setAttribute('href', dataUri);
            linkElement.setAttribute('download', exportFileDefaultName);
            linkElement.click();
            
            showAlert(`Playlist "${playlist.name}" exportée`, 'success');
        }
        
        // Fonction pour retirer une vidéo de la playlist en cours d'édition
        function removeFromPlaylist(video) {
            const container = document.getElementById('playlist-videos');
            const items = container.querySelectorAll('.playlist-item');
            
            items.forEach(item => {
                const videoName = item.querySelector('span').textContent;
                if (videoName === video) {
                    item.remove();
                }
            });
        }

        // Utility functions
        function setupVolumeSlider() {
            const slider = document.getElementById('displayVolume');
            const valueDisplay = document.getElementById('volumeValue');
            
            slider.addEventListener('input', function() {
                valueDisplay.textContent = this.value;
            });
        }
        
        // Load download queue
        function loadDownloadQueue() {
            fetch('/api/youtube.php?action=queue')
                .then(response => response.json())
                .then(data => {
                    if (data.success && data.queue) {
                        downloadQueue = data.queue;
                        updateDownloadQueueDisplay();
                    }
                })
                .catch(error => console.log('Error loading download queue:', error));
        }
        
        // Update download queue display
        function updateDownloadQueueDisplay() {
            const queueElement = document.getElementById('downloadQueue');
            if (!queueElement) return;
            
            if (downloadQueue.length === 0) {
                queueElement.innerHTML = '<p>Aucun téléchargement en cours</p>';
                return;
            }
            
            let html = '<div class="download-list">';
            downloadQueue.forEach(item => {
                html += `
                    <div class="download-item">
                        <span>${item.title || 'Téléchargement...'}</span>
                        <span class="status">${item.status || 'En cours'}</span>
                    </div>
                `;
            });
            html += '</div>';
            queueElement.innerHTML = html;
        }

        function showAlert(message, type) {
            const alert = document.getElementById('alert');
            alert.className = 'alert ' + type;
            alert.textContent = message;
            alert.style.display = 'block';
            
            setTimeout(() => {
                alert.style.display = 'none';
            }, 5000);
        }

        function toggleFullscreen() {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen();
            } else {
                document.exitFullscreen();
            }
        }

        // Placeholder functions for advanced features
        function downloadTestVideos() {
            showAlert('Téléchargement des vidéos de test en cours...', 'info');
            
            fetch('/api/media.php?action=download-test-videos', {
                method: 'GET'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`✅ ${data.message}. ${data.files.length} fichiers téléchargés`, 'success');
                    // Rafraîchir la liste des médias
                    loadMediaLibrary();
                } else {
                    showAlert('❌ Erreur: ' + (data.error || 'Téléchargement échoué'), 'error');
                }
            })
            .catch(error => {
                showAlert('❌ Erreur réseau: ' + error.message, 'error');
            });
        }

        function optimizeMedia() {
            const files = document.querySelectorAll('.media-item input[type="checkbox"]:checked');
            if (files.length === 0) {
                showAlert('⚠️ Veuillez sélectionner au moins un fichier à optimiser', 'warning');
                return;
            }
            
            const file = files[0].closest('.media-item').dataset.filename;
            showAlert('🔧 Optimisation en cours...', 'info');
            
            const formData = new FormData();
            formData.append('action', 'optimize');
            formData.append('file', file);
            
            fetch('/api/media.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`✅ Optimisation démarrée pour ${data.input}`, 'success');
                    // Optionnel: polling pour vérifier la progression
                    setTimeout(() => {
                        loadMediaLibrary();
                    }, 5000);
                } else {
                    showAlert('❌ Erreur: ' + (data.error || 'Optimisation échouée'), 'error');
                }
            })
            .catch(error => {
                showAlert('❌ Erreur réseau: ' + error.message, 'error');
            });
        }

        function cleanupMedia() {
            if (!confirm('Supprimer les fichiers inutilisés ? Cette action est irréversible.')) return;
            
            showAlert('🔍 Analyse des fichiers inutilisés...', 'info');
            
            // Première requête : simulation (dry run)
            fetch('/api/media.php?action=cleanup&dry_run=true', {
                method: 'GET'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    const message = `📊 ${data.totalUnused} fichiers inutilisés trouvés (${data.freedSpaceFormatted} à libérer)`;
                    if (data.totalUnused > 0 && confirm(message + '\n\nConfirmer la suppression ?')) {
                        // Vraie suppression
                        return fetch('/api/media.php?action=cleanup&dry_run=false');
                    } else {
                        showAlert('ℹ️ Aucun fichier à supprimer ou suppression annulée', 'info');
                        return null;
                    }
                } else {
                    throw new Error(data.error || 'Erreur lors de l\'analyse');
                }
            })
            .then(response => {
                if (response) {
                    return response.json();
                }
                return null;
            })
            .then(data => {
                if (data) {
                    if (data.success) {
                        showAlert(`✅ ${data.deletedFiles.length} fichiers supprimés. ${data.freedSpaceFormatted} libérés`, 'success');
                        loadMediaLibrary();
                    } else {
                        showAlert('❌ Erreur: ' + (data.error || 'Suppression échouée'), 'error');
                    }
                }
            })
            .catch(error => {
                showAlert('❌ Erreur: ' + error.message, 'error');
            });
        }

        function addToPlaylist(filename) {
            showAlert(`${filename} ajouté au presse-papiers`, 'info');
        }

        function savePlaylist() {
            createPlaylist();
        }

        function clearPlaylist() {
            clearPlaylistForm();
        }

        function saveSchedule() {
            const schedule = {
                days: [],
                playlist: document.getElementById('schedulePlaylist').value,
                startTime: document.getElementById('scheduleStartTime').value,
                endTime: document.getElementById('scheduleEndTime').value,
                enabled: true,
                created: new Date().toISOString()
            };
            
            // Récupérer les jours sélectionnés
            const dayCheckboxes = document.querySelectorAll('input[name="scheduleDays"]:checked');
            dayCheckboxes.forEach(cb => schedule.days.push(cb.value));
            
            if (!schedule.playlist || schedule.days.length === 0 || !schedule.startTime || !schedule.endTime) {
                showAlert('⚠️ Veuillez remplir tous les champs obligatoires', 'warning');
                return;
            }
            
            // Sauvegarder dans localStorage pour l'instant
            let schedules = JSON.parse(localStorage.getItem('pisignage_schedules') || '[]');
            schedule.id = Date.now().toString();
            schedules.push(schedule);
            
            localStorage.setItem('pisignage_schedules', JSON.stringify(schedules));
            
            showAlert('✅ Programmation sauvegardeé avec succès', 'success');
            
            // Réinitialiser le formulaire
            document.getElementById('schedulePlaylist').value = '';
            document.getElementById('scheduleStartTime').value = '';
            document.getElementById('scheduleEndTime').value = '';
            dayCheckboxes.forEach(cb => cb.checked = false);
            
            // Recharger la liste des programmations actives
            loadActiveSchedules();
        }

        // Fonction pour mettre à jour le volume
        function updateVolume(value) {
            document.getElementById('volumeValue').textContent = value;
            // Appliquer le volume via amixer
            fetch('/api/settings.php', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    action: 'save-settings',
                    settings: {display_volume: value}
                })
            });
        }

        // Fonction pour sauvegarder les paramètres d'affichage
        function saveDisplaySettings() {
            const settings = {
                display_volume: document.getElementById('displayVolume').value,
                image_duration: document.getElementById('imageDuration').value,
                playback_mode: document.getElementById('playbackMode').value
            };
            
            fetch('/api/settings.php', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({action: 'save-settings', settings: settings})
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Paramètres sauvegardés', 'success');
                    // Mettre à jour la config de la playlist
                    updatePlaylistConfig();
                } else {
                    showAlert('Erreur: ' + data.error, 'error');
                }
            });
        }

        // Fonction pour changer la playlist active
        function changeActivePlaylist(playlistId) {
            if (!playlistId) return;
            
            fetch(`/api/playlist.php?action=play&id=${playlistId}`)
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`Playlist "${data.playing}" activée`, 'success');
                    refreshPlaylistInfo();
                } else {
                    showAlert('Erreur: ' + data.error, 'error');
                }
            });
        }

        // Fonction pour redémarrer la playlist
        function restartPlaylist() {
            fetch('/api/control.php?action=stop')
            .then(() => {
                setTimeout(() => {
                    fetch('/api/control.php?action=start')
                    .then(() => {
                        showAlert('Playlist redémarrée', 'success');
                        refreshPlaylistInfo();
                    });
                }, 1000);
            });
        }

        // Fonction pour rafraîchir les infos de la playlist
        function refreshPlaylistInfo() {
            fetch('/api/control.php?action=status')
            .then(response => response.json())
            .then(data => {
                const info = document.getElementById('activePlaylistInfo');
                if (data.status && data.status.includes('En lecture')) {
                    info.innerHTML = `
                        <div style="padding: 1rem; background: #e8f5e9; border-radius: 4px;">
                            <div style="color: #2e7d32; font-weight: bold;">▶️ ${data.status}</div>
                        </div>
                    `;
                } else {
                    info.innerHTML = `
                        <div class="empty-state">
                            <div class="icon">⏸️</div>
                            <p>Lecteur arrêté</p>
                        </div>
                    `;
                }
            });
            
            // Rafraîchir la liste des playlists
            loadPlaylistsForSelect();
        }

        // Fonction pour obtenir le statut détaillé
        function getPlaylistStatus() {
            const bash = '/opt/pisignage/scripts/playlist-engine.sh status';
            
            fetch('/api/control.php', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({action: 'exec', command: bash})
            })
            .then(response => response.text())
            .then(output => {
                document.getElementById('displayInfo').innerHTML = `<pre>${output}</pre>`;
            })
            .catch(() => {
                // Fallback : utiliser l'ancien système
                fetch('/api/control.php?action=status')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('displayInfo').innerHTML = `<pre>Status: ${data.status}</pre>`;
                });
            });
        }

        // Fonction pour charger les playlists dans le select
        function loadPlaylistsForSelect() {
            fetch('/api/playlist.php?action=list')
            .then(response => response.json())
            .then(data => {
                const select = document.getElementById('activePlaylistSelect');
                select.innerHTML = '<option value="default">Playlist par défaut</option>';
                
                if (data.playlists && data.playlists.length > 0) {
                    data.playlists.forEach(playlist => {
                        const option = document.createElement('option');
                        option.value = playlist.id;
                        option.textContent = playlist.name;
                        select.appendChild(option);
                    });
                }
            });
        }

        // Fonction pour mettre à jour la configuration de la playlist
        function updatePlaylistConfig() {
            const imageDuration = document.getElementById('imageDuration').value;
            const playbackMode = document.getElementById('playbackMode').value;
            
            // Sauvegarder dans le JSON de configuration
            fetch('/api/playlist.php', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    action: 'update-config',
                    config: {
                        default_item_duration: imageDuration,
                        playback_mode: playbackMode
                    }
                })
            });
        }

        function saveSystemSettings() {
            const settings = {
                display_resolution: document.getElementById('displayResolution').value,
                display_orientation: document.getElementById('displayOrientation').value,
                display_volume: document.getElementById('displayVolume').value,
                auto_start: document.getElementById('autoStart').checked ? 'true' : 'false',
                debug_mode: document.getElementById('debugMode').checked ? 'true' : 'false'
            };
            
            showAlert('💾 Sauvegarde en cours...', 'info');
            
            const formData = new FormData();
            formData.append('action', 'save-settings');
            
            Object.keys(settings).forEach(key => {
                formData.append(`settings[${key}]`, settings[key]);
            });
            
            fetch('/api/settings.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('✅ Configuration système sauvegardée', 'success');
                    // Mettre à jour l'interface si nécessaire
                    if (settings.display_volume) {
                        updateVolumeDisplay(settings.display_volume);
                    }
                } else {
                    showAlert('❌ Erreur: ' + (data.error || 'Sauvegarde échouée'), 'error');
                }
            })
            .catch(error => {
                showAlert('❌ Erreur réseau: ' + error.message, 'error');
            });
        }

        function scanWiFi() {
            showAlert('📶 Scan WiFi en cours...', 'info');
            
            fetch('/api/settings.php?action=scan-wifi', {
                method: 'GET'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    const networks = data.networks;
                    if (networks.length === 0) {
                        showAlert('⚠️ Aucun réseau WiFi détecté', 'warning');
                        return;
                    }
                    
                    // Créer une liste des réseaux
                    let networkList = '📶 Réseaux détectés:\n\n';
                    networks.forEach(network => {
                        const signalBars = '█'.repeat(Math.ceil(network.signal / 25));
                        networkList += `${network.ssid} ${signalBars} (${network.signal}%)\n`;
                    });
                    
                    // Afficher dans une boîte de dialogue ou mise à jour de l'interface
                    showAlert('✅ ' + networks.length + ' réseaux trouvés', 'success');
                    
                    // Optionnel: populer un select avec les réseaux
                    const ssidSelect = document.getElementById('networkSSID');
                    if (ssidSelect) {
                        // Vider les options existantes sauf la première
                        while (ssidSelect.options.length > 1) {
                            ssidSelect.remove(1);
                        }
                        
                        // Ajouter les nouveaux réseaux
                        networks.forEach(network => {
                            const option = document.createElement('option');
                            option.value = network.ssid;
                            option.textContent = `${network.ssid} (${network.signal}%)`;
                            ssidSelect.appendChild(option);
                        });
                    }
                    
                    console.log('Réseaux WiFi:', networks);
                } else {
                    showAlert('❌ Erreur: ' + (data.error || 'Scan WiFi échoué'), 'error');
                }
            })
            .catch(error => {
                showAlert('❌ Erreur réseau: ' + error.message, 'error');
            });
        }

        function resetNetwork() {
            if (!confirm('Réinitialiser la configuration réseau ? Cette action peut interrompre la connexion.')) return;
            
            showAlert('🔄 Réinitialisation du réseau...', 'warning');
            
            fetch('/api/settings.php?action=reset-network', {
                method: 'POST'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('✅ Configuration réseau réinitialisée', 'success');
                    showAlert('⚠️ La connexion peut être interrompue. Veuillez patienter...', 'warning');
                    
                    // Tentative de reconnexion après 10 secondes
                    setTimeout(() => {
                        showAlert('🔄 Tentative de reconnexion...', 'info');
                        // Test de connectivité
                        fetch('/api/settings.php?action=ping', { method: 'GET' })
                        .then(() => {
                            showAlert('✅ Connexion rétablie', 'success');
                        })
                        .catch(() => {
                            showAlert('⚠️ Connexion non rétablie. Vérifiez la configuration.', 'warning');
                        });
                    }, 10000);
                } else {
                    showAlert('❌ Erreur: ' + (data.error || 'Réinitialisation échouée'), 'error');
                }
            })
            .catch(error => {
                showAlert('❌ Erreur réseau: ' + error.message, 'error');
            });
        }

        function createBackup() {
            showAlert('💾 Création de la sauvegarde...', 'info');
            
            fetch('/api/settings.php?action=backup', {
                method: 'POST'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    const sizeFormatted = formatBytes(data.size);
                    showAlert(`✅ Sauvegarde créée: ${data.filename} (${sizeFormatted})`, 'success');
                    
                    // Optionnel: proposer le téléchargement
                    if (confirm('Voulez-vous télécharger la sauvegarde ?')) {
                        const link = document.createElement('a');
                        link.href = `/backups/${data.filename}`;
                        link.download = data.filename;
                        link.click();
                    }
                    
                    // Rafraîchir la liste des sauvegardes
                    loadBackupsList();
                } else {
                    showAlert('❌ Erreur: ' + (data.error || 'Création de sauvegarde échouée'), 'error');
                    if (data.details) {
                        console.error('Détails:', data.details);
                    }
                }
            })
            .catch(error => {
                showAlert('❌ Erreur réseau: ' + error.message, 'error');
            });
        }

        function restoreBackup() {
            // D'abord, charger la liste des sauvegardes disponibles
            fetch('/api/settings.php?action=list-backups', {
                method: 'GET'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success && data.backups.length > 0) {
                    // Créer une boîte de dialogue de sélection
                    let backupOptions = 'Sélectionnez une sauvegarde à restaurer:\n\n';
                    data.backups.forEach((backup, index) => {
                        const sizeFormatted = formatBytes(backup.size);
                        backupOptions += `${index + 1}. ${backup.name} (${backup.date}) - ${sizeFormatted}\n`;
                    });
                    
                    const selection = prompt(backupOptions + '\nEntrez le numéro (1-' + data.backups.length + '):');
                    const backupIndex = parseInt(selection) - 1;
                    
                    if (backupIndex >= 0 && backupIndex < data.backups.length) {
                        const selectedBackup = data.backups[backupIndex];
                        
                        if (confirm(`Restaurer ${selectedBackup.name} ? Cette action remplacera la configuration actuelle.`)) {
                            performRestore(selectedBackup.name);
                        }
                    } else {
                        showAlert('⚠️ Sélection annulée', 'info');
                    }
                } else {
                    showAlert('⚠️ Aucune sauvegarde disponible', 'warning');
                }
            })
            .catch(error => {
                showAlert('❌ Erreur: ' + error.message, 'error');
            });
        }

        function restartSystem() {
            if (!confirm('Redémarrer le système ?')) return;
            showAlert('Redémarrage en cours...', 'warning');
            
            fetch('?action=system_restart', {
                method: 'POST'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Système redémarré. Reconnexion automatique dans 30s...', 'info');
                    // Tentative de reconnexion après 30 secondes
                    setTimeout(() => {
                        window.location.reload();
                    }, 30000);
                } else {
                    showAlert('Erreur: ' + (data.message || 'Redémarrage échoué'), 'error');
                }
            })
            .catch(error => {
                showAlert('Erreur: ' + error.message, 'error');
            });
        }

        function shutdownSystem() {
            if (!confirm('Éteindre le système ?')) return;
            showAlert('Extinction en cours...', 'warning');
            
            fetch('?action=system_shutdown', {
                method: 'POST'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Système éteint. Cette page ne sera plus accessible.', 'info');
                } else {
                    showAlert('Erreur: ' + (data.message || 'Extinction échouée'), 'error');
                }
            })
            .catch(error => {
                showAlert('Erreur: ' + error.message, 'error');
            });
        }

        function viewLogs() {
            const logType = prompt('Type de log à consulter:\n\n1. PiSignage (pisignage)\n2. VLC (vlc)\n3. Nginx (nginx)\n4. PHP (php)\n\nEntrez le nom ou numéro:', 'pisignage');
            
            if (!logType) return;
            
            // Mapper les numéros aux noms
            const logTypeMap = {
                '1': 'pisignage',
                '2': 'vlc', 
                '3': 'nginx',
                '4': 'php'
            };
            
            const actualLogType = logTypeMap[logType] || logType;
            const lines = prompt('Nombre de lignes à afficher (10-1000):', '100');
            
            if (!lines || isNaN(lines)) return;
            
            showAlert('📜 Chargement des logs...', 'info');
            
            fetch(`/api/settings.php?action=view-logs&type=${actualLogType}&lines=${lines}`, {
                method: 'GET'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Créer une fenêtre modale pour afficher les logs
                    const modal = document.createElement('div');
                    modal.style.cssText = `
                        position: fixed;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100%;
                        background: rgba(0,0,0,0.8);
                        z-index: 10000;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        padding: 20px;
                    `;
                    
                    const logContainer = document.createElement('div');
                    logContainer.style.cssText = `
                        background: #1a1a1a;
                        color: #00ff00;
                        font-family: 'Courier New', monospace;
                        font-size: 12px;
                        padding: 20px;
                        border-radius: 8px;
                        width: 90%;
                        height: 80%;
                        overflow: auto;
                        position: relative;
                    `;
                    
                    const header = document.createElement('div');
                    header.style.cssText = `
                        position: sticky;
                        top: 0;
                        background: #1a1a1a;
                        padding-bottom: 10px;
                        border-bottom: 1px solid #333;
                        margin-bottom: 10px;
                    `;
                    header.innerHTML = `
                        <h3 style="margin: 0; color: #fff;">📜 Logs ${data.type} (${data.lines} dernières lignes)</h3>
                        <button onclick="this.closest('.modal').remove()" style="position: absolute; top: 0; right: 0; background: #ff4444; color: white; border: none; padding: 5px 10px; cursor: pointer;">❌ Fermer</button>
                    `;
                    
                    const logContent = document.createElement('pre');
                    logContent.style.cssText = `
                        margin: 0;
                        white-space: pre-wrap;
                        word-wrap: break-word;
                    `;
                    logContent.textContent = data.content || 'Aucun contenu';
                    
                    logContainer.appendChild(header);
                    logContainer.appendChild(logContent);
                    modal.appendChild(logContainer);
                    modal.className = 'modal';
                    
                    document.body.appendChild(modal);
                    
                    showAlert(`✅ Logs ${data.type} chargés`, 'success');
                } else {
                    showAlert('❌ Erreur: ' + (data.error || 'Chargement des logs échoué'), 'error');
                }
            })
            .catch(error => {
                showAlert('❌ Erreur réseau: ' + error.message, 'error');
            });
        }

        function clearLogs() {
            const logType = prompt('Type de log à vider:\n\n1. Tous les logs (all)\n2. PiSignage (pisignage)\n3. VLC (vlc)\n\nEntrez le nom ou numéro:', 'all');
            
            if (!logType) return;
            
            // Mapper les numéros aux noms
            const logTypeMap = {
                '1': 'all',
                '2': 'pisignage',
                '3': 'vlc'
            };
            
            const actualLogType = logTypeMap[logType] || logType;
            
            if (!confirm(`Vider les logs ${actualLogType} ? Cette action est irréversible.`)) return;
            
            showAlert('🗑️ Nettoyage des logs...', 'info');
            
            const formData = new FormData();
            formData.append('action', 'clear-logs');
            formData.append('type', actualLogType);
            
            fetch('/api/settings.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`✅ ${data.message}`, 'success');
                } else {
                    showAlert('❌ Erreur: ' + (data.error || 'Nettoyage échoué'), 'error');
                }
            })
            .catch(error => {
                showAlert('❌ Erreur réseau: ' + error.message, 'error');
            });
        }
        
        // Helper functions
        function formatBytes(bytes) {
            if (bytes === 0) return '0 B';
            const k = 1024;
            const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }
        
        function performRestore(backupName) {
            showAlert('📥 Restauration en cours...', 'warning');
            
            const formData = new FormData();
            formData.append('action', 'restore');
            formData.append('backup', backupName);
            
            fetch('/api/settings.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('✅ Restauration terminée avec succès', 'success');
                    showAlert('🔄 Redémarrage recommandé pour appliquer tous les changements', 'info');
                } else {
                    showAlert('❌ Erreur: ' + (data.error || 'Restauration échouée'), 'error');
                }
            })
            .catch(error => {
                showAlert('❌ Erreur réseau: ' + error.message, 'error');
            });
        }
        
        function loadBackupsList() {
            // Cette fonction pourrait être implémentée pour rafraîchir une liste de sauvegardes
            // dans l'interface si nécessaire
            console.log('📋 Liste des sauvegardes à rafraîchir');
        }
        
        function updateVolumeDisplay(volume) {
            // Mettre à jour l'affichage du volume dans l'interface
            const volumeDisplays = document.querySelectorAll('.volume-display');
            volumeDisplays.forEach(display => {
                display.textContent = volume + '%';
            });
            
            // Mettre à jour les sliders de volume
            const volumeSliders = document.querySelectorAll('input[type="range"][id*="volume"]');
            volumeSliders.forEach(slider => {
                slider.value = volume;
            });
        }
        
        function loadActiveSchedules() {
            // Charger et afficher les programmations actives depuis localStorage
            const schedules = JSON.parse(localStorage.getItem('pisignage_schedules') || '[]');
            const container = document.getElementById('activeSchedules');
            
            if (!container) return;
            
            if (schedules.length === 0) {
                container.innerHTML = `
                    <div class="empty-state">
                        <div class="icon">📅</div>
                        <p>Aucune programmation active</p>
                    </div>
                `;
                return;
            }
            
            container.innerHTML = '';
            schedules.forEach(schedule => {
                const scheduleDiv = document.createElement('div');
                scheduleDiv.className = 'schedule-item';
                scheduleDiv.style.cssText = `
                    background: #f5f5f5;
                    padding: 10px;
                    margin: 5px 0;
                    border-radius: 4px;
                    border-left: 4px solid #007bff;
                `;
                
                scheduleDiv.innerHTML = `
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <strong>${schedule.playlist}</strong><br>
                            <small>${schedule.days.join(', ')} | ${schedule.startTime} - ${schedule.endTime}</small>
                        </div>
                        <button onclick="deleteSchedule('${schedule.id}')" class="btn btn-sm btn-danger">🗑️</button>
                    </div>
                `;
                
                container.appendChild(scheduleDiv);
            });
        }
        
        function deleteSchedule(scheduleId) {
            if (!confirm('Supprimer cette programmation ?')) return;
            
            let schedules = JSON.parse(localStorage.getItem('pisignage_schedules') || '[]');
            schedules = schedules.filter(s => s.id !== scheduleId);
            localStorage.setItem('pisignage_schedules', JSON.stringify(schedules));
            
            showAlert('✅ Programmation supprimée', 'success');
            loadActiveSchedules();
        }
        
    </script>
</body>
</html>