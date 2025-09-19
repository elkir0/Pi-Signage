# 🚨 Installation Manuelle PiSignage - URGENT

## ⚡ Script d'Installation Rapide (COPIER-COLLER)

Connectez-vous à votre Raspberry Pi et exécutez ces commandes :

```bash
ssh pi@192.168.1.103
# Password: palmer00
```

### Étape 1 : Installation Complète (Une seule commande)

Copiez et collez cette commande ENTIÈRE :

```bash
cat > /tmp/install-pisignage.sh << 'INSTALL_END' && chmod +x /tmp/install-pisignage.sh && sudo /tmp/install-pisignage.sh
#!/bin/bash

echo "======================================"
echo "PiSignage Installation v3.1.0"
echo "======================================"

# Install packages
echo "[1/8] Installing packages..."
apt-get update
apt-get install -y nginx php-fpm php-json php-curl php-mbstring php-cli

# Create directories
echo "[2/8] Creating directories..."
mkdir -p /var/www/pisignage
mkdir -p /opt/pisignage/{media,logs,scripts,config}
chown -R www-data:www-data /var/www/pisignage
chown -R pi:pi /opt/pisignage

# Create VLC control script
echo "[3/8] Creating VLC control script..."
cat > /opt/pisignage/scripts/vlc-control.sh << 'VLC_END'
#!/bin/bash
ACTION=$1
VIDEO_PATH=$2

case $ACTION in
    play)
        pkill vlc 2>/dev/null
        sleep 1
        VIDEO=${VIDEO_PATH:-/home/pi/Big_Buck_Bunny_720_10s_30MB.mp4}
        [ ! -f "$VIDEO" ] && VIDEO=$(ls /opt/pisignage/media/*.mp4 2>/dev/null | head -1)
        [ ! -f "$VIDEO" ] && VIDEO="/home/pi/Big_Buck_Bunny_720_10s_30MB.mp4"
        DISPLAY=:0 cvlc --fullscreen --loop --no-video-title-show "$VIDEO" &
        echo "Playing: $VIDEO"
        ;;
    stop)
        pkill vlc
        echo "Stopped"
        ;;
    status)
        pgrep vlc > /dev/null && echo "VLC running" || echo "VLC stopped"
        ;;
    *)
        echo "Usage: $0 {play|stop|status}"
        ;;
esac
VLC_END
chmod +x /opt/pisignage/scripts/vlc-control.sh
chown pi:pi /opt/pisignage/scripts/vlc-control.sh

# Configure nginx
echo "[4/8] Configuring nginx..."
cat > /etc/nginx/sites-available/pisignage << 'NGINX_END'
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
NGINX_END
ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Create PHP interface
echo "[5/8] Creating web interface..."
cat > /var/www/pisignage/index.php << 'PHP_END'
<?php
error_reporting(E_ALL);
define('CONTROL_SCRIPT', '/opt/pisignage/scripts/vlc-control.sh');

function getSystemInfo() {
    $info = [];
    $info['hostname'] = trim(shell_exec('hostname'));
    $temp = shell_exec('cat /sys/class/thermal/thermal_zone0/temp');
    $info['cpu_temp'] = $temp ? round(intval($temp) / 1000, 1) : 0;
    $memory = shell_exec('free -m | grep Mem');
    preg_match('/Mem:\s+(\d+)\s+(\d+)/', $memory, $m);
    $info['mem_percent'] = isset($m[1]) ? round(($m[2] / $m[1]) * 100) : 0;
    $info['vlc_running'] = !empty(trim(shell_exec('pgrep vlc')));
    return $info;
}

if (isset($_GET['action'])) {
    header('Content-Type: application/json');
    switch ($_GET['action']) {
        case 'status':
            echo json_encode(['success' => true, 'data' => getSystemInfo()]);
            break;
        case 'play':
            shell_exec('sudo -u pi ' . CONTROL_SCRIPT . ' play 2>&1');
            echo json_encode(['success' => true, 'message' => 'Playing']);
            break;
        case 'stop':
            shell_exec('sudo -u pi ' . CONTROL_SCRIPT . ' stop 2>&1');
            echo json_encode(['success' => true, 'message' => 'Stopped']);
            break;
    }
    exit;
}
$sys = getSystemInfo();
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage Control</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .card {
            background: white;
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        h1 { color: #333; margin-bottom: 20px; }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
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
        .btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 6px;
            font-size: 1em;
            cursor: pointer;
            margin: 5px;
        }
        .btn:hover { background: #5a67d8; }
        .btn.success { background: #10b981; }
        .btn.success:hover { background: #059669; }
        .btn.danger { background: #ef4444; }
        .btn.danger:hover { background: #dc2626; }
        .status-on { color: #10b981; }
        .status-off { color: #ef4444; }
    </style>
</head>
<body>
    <div class="container">
        <div class="card">
            <h1>🎬 PiSignage Control Panel</h1>
            <div class="stats">
                <div class="stat">
                    <h3>Status</h3>
                    <p class="<?= $sys['vlc_running'] ? 'status-on' : 'status-off' ?>">
                        <?= $sys['vlc_running'] ? '● Playing' : '○ Stopped' ?>
                    </p>
                </div>
                <div class="stat">
                    <h3>CPU Temp</h3>
                    <p><?= $sys['cpu_temp'] ?>°C</p>
                </div>
                <div class="stat">
                    <h3>Memory</h3>
                    <p><?= $sys['mem_percent'] ?>%</p>
                </div>
                <div class="stat">
                    <h3>Host</h3>
                    <p><?= htmlspecialchars($sys['hostname']) ?></p>
                </div>
            </div>
            <div style="margin-top: 30px;">
                <button class="btn success" onclick="action('play')">▶ Play</button>
                <button class="btn danger" onclick="action('stop')">■ Stop</button>
                <button class="btn" onclick="location.reload()">↻ Refresh</button>
            </div>
        </div>
    </div>
    <script>
        function action(cmd) {
            fetch('?action=' + cmd, {method: 'POST'})
            .then(r => r.json())
            .then(d => {
                alert(d.message);
                setTimeout(() => location.reload(), 1000);
            });
        }
        setInterval(() => {
            fetch('?action=status')
            .then(r => r.json())
            .then(d => console.log('Status:', d.data));
        }, 10000);
    </script>
</body>
</html>
PHP_END
chown www-data:www-data /var/www/pisignage/index.php

# Setup permissions
echo "[6/8] Setting permissions..."
echo "www-data ALL=(pi) NOPASSWD: /opt/pisignage/scripts/vlc-control.sh" > /etc/sudoers.d/pisignage
echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/pkill vlc" >> /etc/sudoers.d/pisignage
chmod 440 /etc/sudoers.d/pisignage

# Copy video if exists
echo "[7/8] Setting up media..."
[ -f /home/pi/Big_Buck_Bunny_720_10s_30MB.mp4 ] && cp /home/pi/Big_Buck_Bunny_720_10s_30MB.mp4 /opt/pisignage/media/

# Restart services
echo "[8/8] Starting services..."
systemctl restart nginx php*-fpm
systemctl enable nginx php*-fpm

echo ""
echo "======================================"
echo "✅ Installation Complete!"
echo "Access: http://$(hostname -I | cut -d' ' -f1)/"
echo "======================================"
INSTALL_END
```

### Étape 2 : Vérification

Après l'installation, vérifiez que tout fonctionne :

```bash
# Test nginx
sudo systemctl status nginx

# Test PHP
sudo systemctl status php*-fpm

# Test web
curl http://localhost/
```

### Étape 3 : Accès à l'Interface

Ouvrez votre navigateur et allez à :
```
http://192.168.1.103/
```

## 🔧 Dépannage Rapide

Si le site ne fonctionne pas :

### Redémarrer les services
```bash
sudo systemctl restart nginx php*-fpm
```

### Vérifier les logs
```bash
sudo tail -f /var/log/nginx/error.log
```

### Vérifier les permissions
```bash
sudo chown -R www-data:www-data /var/www/pisignage
ls -la /var/www/pisignage/
```

### Tester PHP
```bash
php -v
php -l /var/www/pisignage/index.php
```

## 📝 Test Manuel du Contrôle VLC

```bash
# Tester le script de contrôle
/opt/pisignage/scripts/vlc-control.sh status
/opt/pisignage/scripts/vlc-control.sh play
/opt/pisignage/scripts/vlc-control.sh stop
```

## ✅ Checklist de Validation

- [ ] nginx est actif : `sudo systemctl status nginx`
- [ ] PHP-FPM est actif : `sudo systemctl status php*-fpm`
- [ ] Le fichier index.php existe : `ls /var/www/pisignage/`
- [ ] Le script VLC existe : `ls /opt/pisignage/scripts/`
- [ ] L'interface web répond : `curl http://localhost/`
- [ ] Le navigateur affiche l'interface : http://192.168.1.103/

## 🚨 Installation Alternative (Si la première échoue)

```bash
# 1. Télécharger et exécuter le script d'installation
wget -O install.sh https://raw.githubusercontent.com/elkir0/Pi-Signage/main/deploy/install.sh
chmod +x install.sh
sudo ./install.sh

# OU directement :
curl -sSL https://raw.githubusercontent.com/elkir0/Pi-Signage/main/deploy/install.sh | sudo bash
```

## 📞 Support

Si vous rencontrez des problèmes :
1. Vérifiez que le Pi est accessible : `ping 192.168.1.103`
2. Vérifiez SSH : `ssh pi@192.168.1.103`
3. Vérifiez les services : `sudo systemctl status nginx php*-fpm`

---

**IMPORTANT** : Ce script créera une interface web fonctionnelle sur http://192.168.1.103/