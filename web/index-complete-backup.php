<?php
/**
 * PiSignage Web Interface Complete
 * Version: 3.1.0  
 * Date: 2025-09-19
 */

session_start();
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Configuration
define('MEDIA_DIR', '/opt/pisignage/media/');
define('CONTROL_SCRIPT', '/opt/pisignage/scripts/vlc-control.sh');
define('UPLOAD_DIR', '/opt/pisignage/media/');
define('MAX_UPLOAD_SIZE', 500 * 1024 * 1024); // 500MB

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
    $temp = executeCommand('cat /sys/class/thermal/thermal_zone0/temp');
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
    
    return $info;
}

function getMediaFiles() {
    $files = [];
    if (is_dir(MEDIA_DIR)) {
        $videos = glob(MEDIA_DIR . '*.{mp4,avi,mkv,mov,webm}', GLOB_BRACE);
        foreach ($videos as $video) {
            $files[] = [
                'name' => basename($video),
                'path' => $video,
                'size' => filesize($video),
                'size_formatted' => formatBytes(filesize($video)),
                'modified' => date('Y-m-d H:i', filemtime($video))
            ];
        }
    }
    return $files;
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
                    echo json_encode(['success' => true, 'message' => 'File uploaded successfully']);
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
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage Control Panel</title>
    <style>
        :root {
            --primary: #6366f1;
            --primary-dark: #4f46e5;
            --success: #10b981;
            --danger: #ef4444;
            --warning: #f59e0b;
            --bg: #f3f4f6;
            --card-bg: #ffffff;
            --text: #111827;
            --text-secondary: #6b7280;
            --border: #e5e7eb;
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
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }

        header {
            background: linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%);
            color: white;
            padding: 2rem;
            border-radius: 12px;
            margin-bottom: 2rem;
            box-shadow: 0 10px 30px rgba(99, 102, 241, 0.3);
        }

        header h1 {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
        }

        header p {
            opacity: 0.9;
            font-size: 1.1rem;
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }

        .stat-card {
            background: var(--card-bg);
            padding: 1.5rem;
            border-radius: 8px;
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
            display: flex;
            align-items: center;
            gap: 1rem;
        }

        .stat-icon {
            width: 48px;
            height: 48px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.5rem;
        }

        .stat-icon.status { background: rgba(16, 185, 129, 0.1); color: var(--success); }
        .stat-icon.cpu { background: rgba(239, 68, 68, 0.1); color: var(--danger); }
        .stat-icon.memory { background: rgba(99, 102, 241, 0.1); color: var(--primary); }
        .stat-icon.disk { background: rgba(245, 158, 11, 0.1); color: var(--warning); }

        .stat-content h3 {
            font-size: 0.875rem;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 0.25rem;
        }

        .stat-content p {
            font-size: 1.5rem;
            font-weight: 600;
        }

        .main-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 2rem;
            margin-top: 2rem;
        }

        @media (max-width: 768px) {
            .main-grid {
                grid-template-columns: 1fr;
            }
        }

        .card {
            background: var(--card-bg);
            border-radius: 12px;
            padding: 1.5rem;
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        }

        .card h2 {
            font-size: 1.5rem;
            margin-bottom: 1rem;
            padding-bottom: 1rem;
            border-bottom: 2px solid var(--border);
        }

        .btn {
            background: var(--primary);
            color: white;
            border: none;
            padding: 0.75rem 1.5rem;
            border-radius: 6px;
            font-size: 1rem;
            cursor: pointer;
            transition: all 0.2s;
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
        }

        .btn:hover {
            background: var(--primary-dark);
            transform: translateY(-1px);
        }

        .btn:active {
            transform: translateY(0);
        }

        .btn.btn-success { background: var(--success); }
        .btn.btn-success:hover { background: #059669; }
        
        .btn.btn-danger { background: var(--danger); }
        .btn.btn-danger:hover { background: #dc2626; }
        
        .btn.btn-warning { background: var(--warning); }
        .btn.btn-warning:hover { background: #d97706; }

        .btn-group {
            display: flex;
            gap: 0.5rem;
            flex-wrap: wrap;
            margin-top: 1rem;
        }

        .media-list {
            max-height: 400px;
            overflow-y: auto;
            border: 1px solid var(--border);
            border-radius: 6px;
            margin-top: 1rem;
        }

        .media-item {
            padding: 1rem;
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
            transition: background 0.2s;
        }

        .media-item:hover {
            background: var(--bg);
        }

        .media-item:last-child {
            border-bottom: none;
        }

        .media-info {
            flex: 1;
        }

        .media-name {
            font-weight: 500;
            margin-bottom: 0.25rem;
        }

        .media-meta {
            font-size: 0.875rem;
            color: var(--text-secondary);
        }

        .media-actions {
            display: flex;
            gap: 0.5rem;
        }

        .btn-small {
            padding: 0.5rem 1rem;
            font-size: 0.875rem;
        }

        .upload-zone {
            border: 2px dashed var(--border);
            border-radius: 8px;
            padding: 2rem;
            text-align: center;
            margin-top: 1rem;
            transition: all 0.3s;
            cursor: pointer;
        }

        .upload-zone:hover {
            border-color: var(--primary);
            background: rgba(99, 102, 241, 0.05);
        }

        .upload-zone.dragover {
            border-color: var(--primary);
            background: rgba(99, 102, 241, 0.1);
        }

        .upload-input {
            display: none;
        }

        .progress-bar {
            width: 100%;
            height: 8px;
            background: var(--border);
            border-radius: 4px;
            overflow: hidden;
            margin-top: 1rem;
            display: none;
        }

        .progress-fill {
            height: 100%;
            background: var(--primary);
            transition: width 0.3s;
        }

        .alert {
            padding: 1rem;
            border-radius: 6px;
            margin-bottom: 1rem;
            display: none;
        }

        .alert.success {
            background: rgba(16, 185, 129, 0.1);
            color: #047857;
            border: 1px solid rgba(16, 185, 129, 0.3);
        }

        .alert.error {
            background: rgba(239, 68, 68, 0.1);
            color: #b91c1c;
            border: 1px solid rgba(239, 68, 68, 0.3);
        }

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

        .empty-state {
            padding: 3rem;
            text-align: center;
            color: var(--text-secondary);
        }

        .empty-state svg {
            width: 64px;
            height: 64px;
            margin-bottom: 1rem;
            opacity: 0.5;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🎬 PiSignage Control Panel</h1>
            <p>Digital Signage Management System v3.1.0</p>
        </header>

        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-icon status">
                    <span class="status-indicator <?php echo $systemInfo['vlc_running'] ? 'online' : 'offline'; ?>"></span>
                </div>
                <div class="stat-content">
                    <h3>Player Status</h3>
                    <p><?php echo $systemInfo['vlc_running'] ? 'Playing' : 'Stopped'; ?></p>
                </div>
            </div>
            
            <div class="stat-card">
                <div class="stat-icon cpu">🌡️</div>
                <div class="stat-content">
                    <h3>CPU Temperature</h3>
                    <p><?php echo $systemInfo['cpu_temp']; ?>°C</p>
                </div>
            </div>
            
            <div class="stat-card">
                <div class="stat-icon memory">💾</div>
                <div class="stat-content">
                    <h3>Memory Usage</h3>
                    <p><?php echo $systemInfo['mem_percent']; ?>%</p>
                </div>
            </div>
            
            <div class="stat-card">
                <div class="stat-icon disk">💿</div>
                <div class="stat-content">
                    <h3>Disk Usage</h3>
                    <p><?php echo $systemInfo['disk_percent']; ?>%</p>
                </div>
            </div>
        </div>

        <div class="main-grid">
            <div class="card">
                <h2>🎮 Player Control</h2>
                <div class="btn-group">
                    <button class="btn btn-success" onclick="playerAction('play')">
                        ▶️ Play Default
                    </button>
                    <button class="btn btn-danger" onclick="playerAction('stop')">
                        ⏹️ Stop
                    </button>
                    <button class="btn btn-warning" onclick="playerAction('restart')">
                        🔄 Restart
                    </button>
                    <button class="btn" onclick="refreshStatus()">
                        🔄 Refresh
                    </button>
                </div>
            </div>

            <div class="card">
                <h2>📤 Upload Media</h2>
                <div class="upload-zone" id="uploadZone">
                    <input type="file" id="fileInput" class="upload-input" accept="video/*" multiple>
                    <p style="font-size: 1.5rem; margin-bottom: 0.5rem;">📁</p>
                    <p>Click or drag files to upload</p>
                    <p style="font-size: 0.875rem; color: var(--text-secondary); margin-top: 0.5rem;">
                        Supported: MP4, AVI, MKV, MOV, WEBM (Max 500MB)
                    </p>
                </div>
                <div class="progress-bar" id="progressBar">
                    <div class="progress-fill" id="progressFill"></div>
                </div>
            </div>
        </div>

        <div class="card" style="margin-top: 2rem;">
            <h2>📁 Media Library</h2>
            <div id="mediaList" class="media-list">
                <?php if (empty($mediaFiles)): ?>
                    <div class="empty-state">
                        <p>No media files found</p>
                        <p style="font-size: 0.875rem;">Upload videos to get started</p>
                    </div>
                <?php else: ?>
                    <?php foreach ($mediaFiles as $file): ?>
                        <div class="media-item">
                            <div class="media-info">
                                <div class="media-name"><?php echo htmlspecialchars($file['name']); ?></div>
                                <div class="media-meta">
                                    <?php echo $file['size_formatted']; ?> • 
                                    <?php echo $file['modified']; ?>
                                </div>
                            </div>
                            <div class="media-actions">
                                <button class="btn btn-success btn-small" 
                                        onclick="playVideo('<?php echo htmlspecialchars($file['name']); ?>')">
                                    ▶️ Play
                                </button>
                                <button class="btn btn-danger btn-small" 
                                        onclick="deleteVideo('<?php echo htmlspecialchars($file['name']); ?>')">
                                    🗑️
                                </button>
                            </div>
                        </div>
                    <?php endforeach; ?>
                <?php endif; ?>
            </div>
        </div>

        <div id="alert" class="alert"></div>
    </div>

    <script>
        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            setupUpload();
            setInterval(refreshStatus, 10000); // Auto-refresh every 10 seconds
        });

        // Upload handling
        function setupUpload() {
            const zone = document.getElementById('uploadZone');
            const input = document.getElementById('fileInput');

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

        function uploadFile(file) {
            const formData = new FormData();
            formData.append('video', file);

            const progressBar = document.getElementById('progressBar');
            const progressFill = document.getElementById('progressFill');

            progressBar.style.display = 'block';
            progressFill.style.width = '0%';

            const xhr = new XMLHttpRequest();

            xhr.upload.addEventListener('progress', (e) => {
                if (e.lengthComputable) {
                    const percentComplete = (e.loaded / e.total) * 100;
                    progressFill.style.width = percentComplete + '%';
                }
            });

            xhr.addEventListener('load', () => {
                progressBar.style.display = 'none';
                if (xhr.status === 200) {
                    const response = JSON.parse(xhr.responseText);
                    showAlert(response.message, response.success ? 'success' : 'error');
                    if (response.success) {
                        refreshMediaList();
                    }
                }
            });

            xhr.addEventListener('error', () => {
                progressBar.style.display = 'none';
                showAlert('Upload failed', 'error');
            });

            xhr.open('POST', '?action=upload');
            xhr.send(formData);
        }

        // Player controls
        function playerAction(action) {
            fetch('?action=' + action, {
                method: 'POST'
            })
            .then(response => response.json())
            .then(data => {
                showAlert(data.message, data.success ? 'success' : 'error');
                refreshStatus();
            })
            .catch(error => {
                showAlert('Action failed: ' + error, 'error');
            });
        }

        function playVideo(video) {
            fetch('?action=play', {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'video=' + encodeURIComponent(video)
            })
            .then(response => response.json())
            .then(data => {
                showAlert(data.message, data.success ? 'success' : 'error');
                refreshStatus();
            })
            .catch(error => {
                showAlert('Play failed: ' + error, 'error');
            });
        }

        function deleteVideo(video) {
            if (!confirm('Delete ' + video + '?')) return;

            fetch('?action=delete', {
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

        // Refresh functions
        function refreshStatus() {
            fetch('?action=status')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    updateStats(data.data);
                }
            });
        }

        function refreshMediaList() {
            fetch('?action=list')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    updateMediaList(data.files);
                }
            });
        }

        function updateStats(data) {
            // Update status indicators
            const statusElements = document.querySelectorAll('.status-indicator');
            statusElements.forEach(el => {
                el.className = 'status-indicator ' + (data.vlc_running ? 'online' : 'offline');
            });

            // Update stat values
            document.querySelector('.stat-card:nth-child(1) p').textContent = 
                data.vlc_running ? 'Playing' : 'Stopped';
            document.querySelector('.stat-card:nth-child(2) p').textContent = 
                data.cpu_temp + '°C';
            document.querySelector('.stat-card:nth-child(3) p').textContent = 
                data.mem_percent + '%';
            document.querySelector('.stat-card:nth-child(4) p').textContent = 
                data.disk_percent + '%';
        }

        function updateMediaList(files) {
            const container = document.getElementById('mediaList');
            
            if (files.length === 0) {
                container.innerHTML = `
                    <div class="empty-state">
                        <p>No media files found</p>
                        <p style="font-size: 0.875rem;">Upload videos to get started</p>
                    </div>
                `;
            } else {
                container.innerHTML = files.map(file => `
                    <div class="media-item">
                        <div class="media-info">
                            <div class="media-name">${file.name}</div>
                            <div class="media-meta">
                                ${file.size_formatted} • ${file.modified}
                            </div>
                        </div>
                        <div class="media-actions">
                            <button class="btn btn-success btn-small" 
                                    onclick="playVideo('${file.name}')">
                                ▶️ Play
                            </button>
                            <button class="btn btn-danger btn-small" 
                                    onclick="deleteVideo('${file.name}')">
                                🗑️
                            </button>
                        </div>
                    </div>
                `).join('');
            }
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
    </script>
</body>
</html>