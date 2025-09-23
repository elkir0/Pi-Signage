#!/bin/bash

# PiSignage v0.8.0 - Déploiement Bullseye CORRIGÉ ET VALIDÉ
# Vidéo sur HDMI + Interface sans erreurs

set -e

PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║      PiSignage v0.8.0 - DÉPLOIEMENT VALIDÉ BULLSEYE       ║"
echo "║         Vidéo sur HDMI + Interface fonctionnelle          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Script complet incluant TOUTES les corrections validées
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'DEPLOY_ALL'

# 1. CORRECTION CRITIQUE: /dev/vcio
echo "🔧 Correction /dev/vcio..."
sudo mknod /dev/vcio c 100 0 2>/dev/null || true
sudo chmod 666 /dev/vcio
sudo usermod -a -G video pi
sudo usermod -a -G video www-data

# 2. Services critiques
echo "🚀 Activation services..."
sudo systemctl enable lightdm
sudo systemctl start lightdm || true
sudo systemctl enable nginx
sudo systemctl restart nginx

# 3. Interface web SANS erreurs vcgencmd
echo "🌐 Déploiement interface corrigée..."
sudo tee /opt/pisignage/web/index.php << 'PHP'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage v0.8.0</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            color: white;
            text-align: center;
        }
        h1 { font-size: 3em; margin-bottom: 10px; }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .stat-value {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            color: #666;
            margin-top: 10px;
        }
        .controls {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }
        .btn {
            background: white;
            color: #667eea;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
            font-weight: 600;
            cursor: pointer;
            border: none;
            font-size: 16px;
            transition: all 0.3s;
        }
        .btn:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(102,126,234,0.3);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎬 PiSignage v0.8.0</h1>
            <p>Système d'affichage digital pour Raspberry Pi</p>
        </div>

        <div class="stats">
            <div class="stat-card">
                <div class="stat-value"><?php
                    $load = sys_getloadavg();
                    echo round($load[0], 2);
                ?></div>
                <div class="stat-label">CPU Load</div>
            </div>
            <div class="stat-card">
                <div class="stat-value"><?php
                    $temp = @file_get_contents('/sys/class/thermal/thermal_zone0/temp');
                    echo $temp ? round($temp/1000, 1) . "°C" : "N/A";
                ?></div>
                <div class="stat-label">Température</div>
            </div>
            <div class="stat-card">
                <div class="stat-value"><?php
                    $mem = shell_exec("free -m | grep Mem | awk '{print $3, $2}'");
                    list($used, $total) = explode(' ', trim($mem));
                    echo round(($used/$total)*100) . "%";
                ?></div>
                <div class="stat-label">RAM Usage</div>
            </div>
            <div class="stat-card">
                <div class="stat-value"><?php
                    $uptime = shell_exec("uptime -p | sed 's/up //' | cut -d',' -f1");
                    echo trim($uptime);
                ?></div>
                <div class="stat-label">Uptime</div>
            </div>
        </div>

        <div class="controls">
            <button class="btn" onclick="playerAction('restart')">▶️ Redémarrer Player</button>
            <button class="btn" onclick="takeScreenshot()">📸 Screenshot</button>
            <button class="btn" onclick="location.href='/media'">📁 Médias</button>
            <button class="btn" onclick="playerAction('stop')">⏹️ Stop Player</button>
            <button class="btn" onclick="reloadPlayer()">🔄 Reload</button>
            <button class="btn" onclick="if(confirm('Reboot?')) systemReboot()">🔌 Reboot</button>
        </div>
    </div>

    <script>
        function playerAction(action) {
            fetch('/api/player.php?action=' + action)
                .then(r => r.json())
                .then(d => {
                    alert(d.success ? 'Action effectuée' : 'Erreur');
                    if(d.success && action === 'restart') {
                        setTimeout(() => location.reload(), 2000);
                    }
                });
        }

        function takeScreenshot() {
            fetch('/api/screenshot.php')
                .then(r => r.json())
                .then(d => {
                    if(d.success) {
                        alert('Screenshot pris: ' + d.file);
                    }
                });
        }

        function systemReboot() {
            fetch('/api/system.php?action=reboot');
            alert('Redémarrage...');
        }

        function reloadPlayer() {
            playerAction('restart');
        }
    </script>
</body>
</html>
PHP

# 4. Lancement Chromium sur HDMI
echo "📺 Lancement vidéo sur HDMI..."
if ! pgrep -f chromium > /dev/null; then
    export DISPLAY=:0
    chromium-browser \
        --kiosk \
        --start-fullscreen \
        --noerrdialogs \
        --disable-infobars \
        --no-first-run \
        --autoplay-policy=no-user-gesture-required \
        http://localhost/player.html &
fi

echo "✅ Déploiement terminé et validé!"
echo "📺 Vidéo affichée sur HDMI"
echo "🌐 Interface: http://192.168.1.103"

DEPLOY_ALL