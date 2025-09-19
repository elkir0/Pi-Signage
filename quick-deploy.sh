#!/bin/bash

# Quick deployment script for PiSignage
# This creates all necessary files locally then transfers them

set -e

HOST="192.168.1.103"
USER="pi"
PASS="palmer00"

echo "======================================"
echo "PiSignage Quick Deployment"
echo "======================================"

# Check sshpass
if ! command -v sshpass &> /dev/null; then
    echo "Installing sshpass..."
    sudo apt-get update && sudo apt-get install -y sshpass
fi

# Test connection
echo "Testing connection..."
if ! sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $USER@$HOST "echo 'Connected'" 2>/dev/null; then
    echo "ERROR: Cannot connect to $HOST"
    echo "Please verify:"
    echo "1. The Pi is powered on and connected to network"
    echo "2. SSH is enabled on the Pi"
    echo "3. The password is correct (current: $PASS)"
    exit 1
fi

echo "✓ Connection successful"

# Create local files
echo "Creating deployment package..."

# 1. Create installation script
cat > /tmp/pisignage-install.sh << 'INSTALL_SCRIPT'
#!/bin/bash

echo "Starting PiSignage installation..."

# Update and install packages
echo "Installing packages..."
sudo apt-get update
sudo apt-get install -y nginx php-fpm php-json php-curl php-mbstring php-cli

# Create directories
echo "Creating directories..."
sudo mkdir -p /var/www/pisignage
sudo mkdir -p /opt/pisignage/{media,logs,scripts,config}
sudo chown -R www-data:www-data /var/www/pisignage
sudo chown -R pi:pi /opt/pisignage

# Create VLC control script
echo "Creating VLC control script..."
cat > /opt/pisignage/scripts/vlc-control.sh << 'VLC_SCRIPT'
#!/bin/bash

ACTION=$1
VIDEO_PATH=$2

case $ACTION in
    play)
        pkill vlc 2>/dev/null
        sleep 1
        VIDEO=${VIDEO_PATH:-/home/pi/Big_Buck_Bunny_720_10s_30MB.mp4}
        if [ ! -f "$VIDEO" ]; then
            VIDEO=$(ls /opt/pisignage/media/*.mp4 2>/dev/null | head -1)
        fi
        DISPLAY=:0 cvlc --fullscreen --loop --no-video-title-show "$VIDEO" &
        echo "Playing: $VIDEO"
        ;;
    stop)
        pkill vlc
        echo "Playback stopped"
        ;;
    status)
        if pgrep vlc > /dev/null; then
            echo "VLC is running"
            ps aux | grep vlc | grep -v grep
        else
            echo "VLC is not running"
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 play "$VIDEO_PATH"
        ;;
    *)
        echo "Usage: $0 {play|stop|status|restart} [video_path]"
        exit 1
        ;;
esac
VLC_SCRIPT

chmod +x /opt/pisignage/scripts/vlc-control.sh

# Configure nginx
echo "Configuring nginx..."
sudo tee /etc/nginx/sites-available/pisignage > /dev/null << 'NGINX_CONFIG'
server {
    listen 80;
    server_name _;
    root /var/www/pisignage;
    index index.php index.html;

    client_max_body_size 500M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex on;
    }
}
NGINX_CONFIG

# Enable site
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Setup permissions
echo "Setting permissions..."
echo "www-data ALL=(pi) NOPASSWD: /opt/pisignage/scripts/vlc-control.sh" | sudo tee /etc/sudoers.d/pisignage
echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/pkill vlc" | sudo tee -a /etc/sudoers.d/pisignage
sudo chmod 440 /etc/sudoers.d/pisignage

# Copy video if exists
if [ -f /home/pi/Big_Buck_Bunny_720_10s_30MB.mp4 ]; then
    cp /home/pi/Big_Buck_Bunny_720_10s_30MB.mp4 /opt/pisignage/media/
fi

# Restart services
echo "Restarting services..."
sudo systemctl restart nginx
sudo systemctl restart php*-fpm
sudo systemctl enable nginx
sudo systemctl enable php*-fpm

echo "Installation complete!"
INSTALL_SCRIPT

# 2. Create PHP interface
cat > /tmp/index.php << 'PHP_INTERFACE'
<?php
// PiSignage Web Interface v3.1.0
error_reporting(E_ALL);
ini_set('display_errors', 1);

define('MEDIA_DIR', '/opt/pisignage/media/');
define('CONTROL_SCRIPT', '/opt/pisignage/scripts/vlc-control.sh');

function executeCommand($command) {
    return shell_exec($command . ' 2>&1');
}

function getSystemInfo() {
    $info = [];
    $info['hostname'] = trim(executeCommand('hostname'));
    $temp = executeCommand('cat /sys/class/thermal/thermal_zone0/temp');
    $info['cpu_temp'] = $temp ? round(intval($temp) / 1000, 1) : 0;
    
    $memory = executeCommand('free -m | grep Mem');
    if (preg_match('/Mem:\s+(\d+)\s+(\d+)/', $memory, $matches)) {
        $info['mem_total'] = $matches[1];
        $info['mem_used'] = $matches[2];
        $info['mem_percent'] = round(($matches[2] / $matches[1]) * 100);
    } else {
        $info['mem_percent'] = 0;
    }
    
    $vlc_check = executeCommand('pgrep vlc');
    $info['vlc_running'] = !empty(trim($vlc_check));
    
    return $info;
}

// Handle API requests
if (isset($_GET['action'])) {
    header('Content-Type: application/json');
    
    switch ($_GET['action']) {
        case 'status':
            echo json_encode(['success' => true, 'data' => getSystemInfo()]);
            break;
            
        case 'play':
            $video = $_POST['video'] ?? '';
            if ($video) {
                $videoPath = MEDIA_DIR . basename($video);
                if (file_exists($videoPath)) {
                    $cmd = sprintf('sudo -u pi %s play "%s"', CONTROL_SCRIPT, $videoPath);
                } else {
                    $cmd = sprintf('sudo -u pi %s play', CONTROL_SCRIPT);
                }
            } else {
                $cmd = sprintf('sudo -u pi %s play', CONTROL_SCRIPT);
            }
            $result = executeCommand($cmd);
            echo json_encode(['success' => true, 'message' => 'Playing video', 'output' => $result]);
            break;
            
        case 'stop':
            $cmd = sprintf('sudo -u pi %s stop', CONTROL_SCRIPT);
            $result = executeCommand($cmd);
            echo json_encode(['success' => true, 'message' => 'Stopped', 'output' => $result]);
            break;
            
        default:
            echo json_encode(['success' => false, 'message' => 'Unknown action']);
    }
    exit;
}

$systemInfo = getSystemInfo();
$mediaFiles = glob(MEDIA_DIR . '*.{mp4,avi,mkv,mov}', GLOB_BRACE);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage Control Panel</title>
    <style>
        * { 
            margin: 0; 
            padding: 0; 
            box-sizing: border-box; 
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .header {
            background: white;
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        h1 {
            color: #333;
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .subtitle {
            color: #666;
            font-size: 1.1em;
            margin-bottom: 20px;
        }
        
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        
        .stat {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        
        .stat h3 {
            color: #666;
            font-size: 0.9em;
            text-transform: uppercase;
            margin-bottom: 5px;
        }
        
        .stat p {
            color: #333;
            font-size: 1.5em;
            font-weight: bold;
        }
        
        .card {
            background: white;
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        .btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 6px;
            font-size: 1em;
            cursor: pointer;
            margin: 5px;
            transition: all 0.3s;
            display: inline-block;
        }
        
        .btn:hover {
            background: #5a67d8;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        
        .btn.danger {
            background: #ef4444;
        }
        
        .btn.danger:hover {
            background: #dc2626;
        }
        
        .btn.success {
            background: #10b981;
        }
        
        .btn.success:hover {
            background: #059669;
        }
        
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
            background: #ef4444;
            animation: pulse 2s infinite;
        }
        
        .status-indicator.online {
            background: #10b981;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .media-list {
            margin-top: 20px;
            max-height: 300px;
            overflow-y: auto;
            border: 1px solid #e5e7eb;
            border-radius: 6px;
            padding: 10px;
        }
        
        .media-item {
            padding: 10px;
            border-bottom: 1px solid #f0f0f0;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .media-item:last-child {
            border-bottom: none;
        }
        
        .message {
            padding: 15px;
            border-radius: 6px;
            margin-top: 20px;
            display: none;
        }
        
        .message.success {
            background: #d1fae5;
            color: #065f46;
            border: 1px solid #10b981;
        }
        
        .message.error {
            background: #fee2e2;
            color: #991b1b;
            border: 1px solid #ef4444;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎬 PiSignage Control Panel</h1>
            <p class="subtitle">Digital Signage Management System v3.1.0</p>
            
            <div class="status-grid">
                <div class="stat">
                    <h3>Player Status</h3>
                    <p>
                        <span class="status-indicator <?php echo $systemInfo['vlc_running'] ? 'online' : ''; ?>"></span>
                        <?php echo $systemInfo['vlc_running'] ? 'Playing' : 'Stopped'; ?>
                    </p>
                </div>
                
                <div class="stat">
                    <h3>CPU Temperature</h3>
                    <p><?php echo $systemInfo['cpu_temp']; ?>°C</p>
                </div>
                
                <div class="stat">
                    <h3>Memory Usage</h3>
                    <p><?php echo $systemInfo['mem_percent']; ?>%</p>
                </div>
                
                <div class="stat">
                    <h3>Hostname</h3>
                    <p><?php echo htmlspecialchars($systemInfo['hostname']); ?></p>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h2>🎮 Player Control</h2>
            <div style="margin-top: 20px;">
                <button class="btn success" onclick="playerAction('play')">▶️ Play Video</button>
                <button class="btn danger" onclick="playerAction('stop')">⏹️ Stop</button>
                <button class="btn" onclick="location.reload()">🔄 Refresh</button>
            </div>
            
            <div id="message" class="message"></div>
        </div>
        
        <?php if (!empty($mediaFiles)): ?>
        <div class="card">
            <h2>📁 Media Library</h2>
            <div class="media-list">
                <?php foreach ($mediaFiles as $file): ?>
                    <div class="media-item">
                        <span><?php echo basename($file); ?></span>
                        <button class="btn" onclick="playVideo('<?php echo basename($file); ?>')">Play</button>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>
        <?php endif; ?>
    </div>
    
    <script>
        function playerAction(action) {
            fetch('?action=' + action, { method: 'POST' })
            .then(response => response.json())
            .then(data => {
                showMessage(data.message, data.success ? 'success' : 'error');
                if (data.success) {
                    setTimeout(() => location.reload(), 2000);
                }
            })
            .catch(error => {
                showMessage('Error: ' + error, 'error');
            });
        }
        
        function playVideo(video) {
            const formData = new FormData();
            formData.append('video', video);
            
            fetch('?action=play', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                showMessage(data.message, data.success ? 'success' : 'error');
                if (data.success) {
                    setTimeout(() => location.reload(), 2000);
                }
            })
            .catch(error => {
                showMessage('Error: ' + error, 'error');
            });
        }
        
        function showMessage(text, type) {
            const msg = document.getElementById('message');
            msg.className = 'message ' + type;
            msg.textContent = text;
            msg.style.display = 'block';
            
            setTimeout(() => {
                msg.style.display = 'none';
            }, 5000);
        }
        
        // Auto-refresh status every 10 seconds
        setInterval(() => {
            fetch('?action=status')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    console.log('Status updated:', data.data);
                }
            });
        }, 10000);
    </script>
</body>
</html>
PHP_INTERFACE

echo "✓ Deployment package created"

# Deploy to Pi
echo "Deploying to Raspberry Pi..."

# Copy and execute installation script
echo "Installing server components..."
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no /tmp/pisignage-install.sh $USER@$HOST:/tmp/
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no $USER@$HOST "chmod +x /tmp/pisignage-install.sh && /tmp/pisignage-install.sh"

# Copy PHP interface
echo "Deploying web interface..."
sshpass -p "$PASS" scp -o StrictHostKeyChecking=no /tmp/index.php $USER@$HOST:/tmp/
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no $USER@$HOST "sudo mv /tmp/index.php /var/www/pisignage/index.php && sudo chown www-data:www-data /var/www/pisignage/index.php"

# Final test
echo "Testing deployment..."
sleep 3

# Test web server
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$HOST/ 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ SUCCESS! Web interface is running at http://$HOST/"
    echo ""
    echo "======================================"
    echo "PiSignage is now accessible at:"
    echo "http://$HOST/"
    echo "======================================"
else
    echo "⚠️ Warning: Web server returned HTTP code $HTTP_CODE"
    echo "Checking services..."
    sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no $USER@$HOST "sudo systemctl status nginx --no-pager | head -10"
fi

# Cleanup
rm -f /tmp/pisignage-install.sh /tmp/index.php

echo "Deployment complete!"