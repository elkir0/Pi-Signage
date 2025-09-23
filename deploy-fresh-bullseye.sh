#!/bin/bash

# PiSignage - Déploiement complet sur Bullseye ARM64 fresh install
# Version optimisée sans overclocking hardware

set -e

PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║    PiSignage - Installation complète Bullseye ARM64       ║"
echo "║         Solution optimisée avec monitoring FPS            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Déploiement complet via SSH
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'DEPLOY_SCRIPT'

echo "📦 1/6 - Installation des dépendances..."
sudo apt-get update
sudo apt-get install -y \
    nginx \
    php8.2-fpm php8.2-cli php8.2-curl php8.2-mbstring \
    chromium-browser \
    xserver-xorg xinit \
    openbox \
    lightdm \
    ffmpeg \
    wget \
    git \
    unclutter

echo "🏗️ 2/6 - Création structure PiSignage..."
sudo mkdir -p /opt/pisignage/{web,media,scripts,config,logs}
sudo chown -R $USER:$USER /opt/pisignage

echo "⚙️ 3/6 - Configuration nginx..."
sudo tee /etc/nginx/sites-available/pisignage << 'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php index.html;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
        autoindex on;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex on;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

echo "🎬 4/6 - Téléchargement vidéos de test..."
cd /opt/pisignage/media

# Big Buck Bunny - Version optimisée H.264 Baseline
wget -O bunny_optimized.mp4 \
    "https://download.blender.org/demo/movies/BBB/bbb_sunflower_720p_30fps_normal.mp4"

# Conversion en H.264 Baseline optimisé pour RPi
ffmpeg -i bunny_optimized.mp4 \
    -c:v libx264 -profile:v baseline -level 3.1 \
    -preset fast -crf 23 \
    -c:a aac -b:a 128k \
    -movflags +faststart \
    -vf "scale=1280:720" \
    -r 30 \
    bunny_h264_baseline.mp4 -y

# Créer une version Main Profile pour comparaison
ffmpeg -i bunny_optimized.mp4 \
    -c:v libx264 -profile:v main -level 4.0 \
    -preset fast -crf 23 \
    -c:a aac -b:a 128k \
    -movflags +faststart \
    -vf "scale=1280:720" \
    -r 30 \
    bunny_h264_main.mp4 -y

echo "🌐 5/6 - Création interface web avec monitoring FPS..."
cat > /opt/pisignage/web/index.html << 'HTML'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage Player - Monitoring FPS</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            background: #000;
            color: #fff;
            font-family: 'Courier New', monospace;
            overflow: hidden;
            position: relative;
        }

        #video-player {
            width: 100vw;
            height: 100vh;
            object-fit: contain;
        }

        #stats-overlay {
            position: fixed;
            top: 20px;
            right: 20px;
            background: rgba(0, 0, 0, 0.9);
            border: 2px solid #4ade80;
            border-radius: 10px;
            padding: 20px;
            min-width: 300px;
            z-index: 1000;
        }

        #fps-display {
            font-size: 48px;
            font-weight: bold;
            text-align: center;
            margin-bottom: 15px;
            text-shadow: 0 0 10px currentColor;
        }

        .fps-good { color: #4ade80; border-color: #4ade80; }
        .fps-medium { color: #fbbf24; border-color: #fbbf24; }
        .fps-poor { color: #ef4444; border-color: #ef4444; }

        .stat-row {
            display: flex;
            justify-content: space-between;
            margin: 8px 0;
            padding: 5px 0;
            border-bottom: 1px solid #333;
        }

        .stat-label {
            color: #94a3b8;
            font-size: 12px;
        }

        .stat-value {
            color: #fff;
            font-weight: bold;
            font-size: 14px;
        }

        #video-info {
            position: fixed;
            bottom: 20px;
            left: 20px;
            background: rgba(0, 0, 0, 0.8);
            padding: 15px;
            border-radius: 8px;
            max-width: 400px;
        }

        .video-title {
            color: #4ade80;
            font-size: 16px;
            margin-bottom: 5px;
        }

        .video-codec {
            color: #94a3b8;
            font-size: 12px;
        }

        #progress-bar {
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: rgba(255, 255, 255, 0.1);
        }

        #progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #4ade80, #3b82f6);
            width: 0%;
            transition: width 0.3s;
        }
    </style>
</head>
<body>
    <video id="video-player" autoplay muted loop playsinline></video>

    <div id="stats-overlay">
        <div id="fps-display" class="fps-good">-- FPS</div>

        <div class="stat-row">
            <span class="stat-label">FPS Moyen</span>
            <span class="stat-value" id="fps-avg">--</span>
        </div>

        <div class="stat-row">
            <span class="stat-label">Min / Max</span>
            <span class="stat-value" id="fps-minmax">-- / --</span>
        </div>

        <div class="stat-row">
            <span class="stat-label">Frames Dropped</span>
            <span class="stat-value" id="dropped-frames">0</span>
        </div>

        <div class="stat-row">
            <span class="stat-label">Temps Écoulé</span>
            <span class="stat-value" id="elapsed-time">00:00</span>
        </div>

        <div class="stat-row">
            <span class="stat-label">Résolution</span>
            <span class="stat-value" id="resolution">--</span>
        </div>

        <div class="stat-row">
            <span class="stat-label">Décodeur</span>
            <span class="stat-value" id="decoder-info">Détection...</span>
        </div>
    </div>

    <div id="video-info">
        <div class="video-title" id="video-title">Chargement...</div>
        <div class="video-codec" id="video-codec">--</div>
    </div>

    <div id="progress-bar">
        <div id="progress-fill"></div>
    </div>

    <script>
        // Configuration de la playlist
        const playlist = [
            {
                src: '/media/bunny_h264_baseline.mp4',
                title: 'Big Buck Bunny - H.264 Baseline',
                codec: 'H.264 Baseline Profile L3.1 @ 30fps',
                duration: 30000 // 30 secondes par vidéo
            },
            {
                src: '/media/bunny_h264_main.mp4',
                title: 'Big Buck Bunny - H.264 Main',
                codec: 'H.264 Main Profile L4.0 @ 30fps',
                duration: 30000
            },
            {
                src: '/media/bunny_optimized.mp4',
                title: 'Big Buck Bunny - Original',
                codec: 'H.264 High Profile (Original)',
                duration: 30000
            }
        ];

        let currentVideoIndex = 0;
        let videoStartTime = Date.now();
        let playbackStartTime = Date.now();

        // Références DOM
        const video = document.getElementById('video-player');
        const fpsDisplay = document.getElementById('fps-display');
        const fpsAvg = document.getElementById('fps-avg');
        const fpsMinMax = document.getElementById('fps-minmax');
        const droppedFramesDisplay = document.getElementById('dropped-frames');
        const elapsedTimeDisplay = document.getElementById('elapsed-time');
        const resolutionDisplay = document.getElementById('resolution');
        const decoderDisplay = document.getElementById('decoder-info');
        const videoTitle = document.getElementById('video-title');
        const videoCodec = document.getElementById('video-codec');
        const progressFill = document.getElementById('progress-fill');
        const statsOverlay = document.getElementById('stats-overlay');

        // Monitoring FPS
        let frameCount = 0;
        let lastTime = performance.now();
        let fpsHistory = [];
        let minFps = 999;
        let maxFps = 0;
        let droppedFrames = 0;
        let totalDroppedFrames = 0;

        // Fonction de chargement de vidéo
        function loadVideo(index) {
            const videoData = playlist[index];
            video.src = videoData.src;
            videoTitle.textContent = videoData.title;
            videoCodec.textContent = videoData.codec;
            videoStartTime = Date.now();

            // Reset stats pour cette vidéo
            fpsHistory = [];
            minFps = 999;
            maxFps = 0;

            video.play().catch(err => {
                console.error('Erreur lecture:', err);
                // Retry après 1 seconde
                setTimeout(() => video.play(), 1000);
            });

            // Programmer la prochaine vidéo
            setTimeout(() => {
                currentVideoIndex = (currentVideoIndex + 1) % playlist.length;
                loadVideo(currentVideoIndex);
            }, videoData.duration);
        }

        // Calcul et affichage FPS
        function updateFPS() {
            frameCount++;
            const currentTime = performance.now();
            const delta = currentTime - lastTime;

            if (delta >= 1000) {
                const fps = Math.round((frameCount * 1000) / delta);
                fpsHistory.push(fps);

                // Garder seulement les 60 dernières valeurs
                if (fpsHistory.length > 60) {
                    fpsHistory.shift();
                }

                // Mise à jour min/max
                if (fps < minFps) minFps = fps;
                if (fps > maxFps) maxFps = fps;

                // Calcul moyenne
                const avgFps = fpsHistory.length > 0
                    ? Math.round(fpsHistory.reduce((a, b) => a + b, 0) / fpsHistory.length)
                    : 0;

                // Affichage FPS principal
                fpsDisplay.textContent = `${fps} FPS`;
                fpsAvg.textContent = avgFps;
                fpsMinMax.textContent = `${minFps} / ${maxFps}`;

                // Couleur selon performance
                statsOverlay.className = '';
                if (fps >= 28) {
                    fpsDisplay.className = 'fps-good';
                } else if (fps >= 24) {
                    fpsDisplay.className = 'fps-medium';
                } else {
                    fpsDisplay.className = 'fps-poor';
                }

                frameCount = 0;
                lastTime = currentTime;
            }

            // Mise à jour temps écoulé
            const elapsed = Math.floor((Date.now() - playbackStartTime) / 1000);
            const minutes = Math.floor(elapsed / 60);
            const seconds = elapsed % 60;
            elapsedTimeDisplay.textContent =
                `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;

            // Mise à jour barre de progression
            const progress = ((Date.now() - videoStartTime) / playlist[currentVideoIndex].duration) * 100;
            progressFill.style.width = Math.min(progress, 100) + '%';

            requestAnimationFrame(updateFPS);
        }

        // Monitoring frames dropped
        function updateVideoStats() {
            if (video.getVideoPlaybackQuality) {
                const quality = video.getVideoPlaybackQuality();
                droppedFrames = quality.droppedVideoFrames || 0;
                totalDroppedFrames = quality.totalVideoFrames
                    ? Math.round((droppedFrames / quality.totalVideoFrames) * 100)
                    : 0;
                droppedFramesDisplay.textContent = `${droppedFrames} (${totalDroppedFrames}%)`;
            } else if (video.webkitDroppedFrameCount !== undefined) {
                droppedFrames = video.webkitDroppedFrameCount;
                droppedFramesDisplay.textContent = droppedFrames;
            }
        }

        // Event handlers
        video.addEventListener('loadedmetadata', () => {
            resolutionDisplay.textContent = `${video.videoWidth}x${video.videoHeight}`;

            // Détection du décodeur
            if (video.webkitDecodedFrameCount !== undefined) {
                decoderDisplay.textContent = 'Hardware (WebKit)';
            } else if (video.mozDecodedFrames !== undefined) {
                decoderDisplay.textContent = 'Hardware (Mozilla)';
            } else {
                // Test MediaCapabilities API
                if ('MediaSource' in window && MediaSource.isTypeSupported) {
                    if (MediaSource.isTypeSupported('video/mp4; codecs="avc1.42E01E"')) {
                        decoderDisplay.textContent = 'H.264 Hardware';
                    } else {
                        decoderDisplay.textContent = 'Software';
                    }
                } else {
                    decoderDisplay.textContent = 'Inconnu';
                }
            }
        });

        video.addEventListener('error', (e) => {
            console.error('Erreur vidéo:', e);
            videoTitle.textContent = 'Erreur de lecture';
            // Passer à la vidéo suivante
            setTimeout(() => {
                currentVideoIndex = (currentVideoIndex + 1) % playlist.length;
                loadVideo(currentVideoIndex);
            }, 2000);
        });

        // Forcer reprise si pause
        video.addEventListener('pause', () => {
            video.play();
        });

        // Mise à jour stats toutes les secondes
        setInterval(updateVideoStats, 1000);

        // Démarrage
        loadVideo(0);
        requestAnimationFrame(updateFPS);
    </script>
</body>
</html>
HTML

echo "🚀 6/6 - Configuration du démarrage automatique..."

# Configuration LightDM pour autologin
sudo tee /etc/lightdm/lightdm.conf << 'LIGHTDM'
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
user-session=openbox
LIGHTDM

# Script de démarrage
cat > /opt/pisignage/scripts/start-kiosk.sh << 'KIOSK'
#!/bin/bash

# Attendre que le système soit prêt
sleep 5

# Variables d'environnement
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Désactiver économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Masquer le curseur après 3 secondes
unclutter -idle 3 &

# Lancer Chromium en mode kiosk avec optimisations
chromium-browser \
    --kiosk \
    --start-fullscreen \
    --noerrdialogs \
    --disable-infobars \
    --no-first-run \
    --disable-translate \
    --disable-features=TranslateUI \
    --check-for-update-interval=2592000 \
    --autoplay-policy=no-user-gesture-required \
    --use-gl=egl \
    --enable-gpu-rasterization \
    --enable-features=VaapiVideoDecoder \
    --disable-features=UseChromeOSDirectVideoDecoder \
    --disable-software-rasterizer \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --disable-features=AudioServiceOutOfProcess \
    --disable-print-preview \
    --disable-smooth-scrolling \
    --max-web-media-player-count=10 \
    --disable-web-security \
    --user-data-dir=/tmp/chromium \
    http://localhost &
KIOSK

chmod +x /opt/pisignage/scripts/start-kiosk.sh

# Autostart avec OpenBox
mkdir -p ~/.config/openbox
cat > ~/.config/openbox/autostart << 'AUTOSTART'
# Lancer le kiosk au démarrage
/opt/pisignage/scripts/start-kiosk.sh &
AUTOSTART

# Service systemd (alternative)
sudo tee /etc/systemd/system/pisignage-kiosk.service << 'SERVICE'
[Unit]
Description=PiSignage Kiosk Mode
After=graphical.target

[Service]
Type=simple
User=pi
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/home/pi/.Xauthority"
ExecStartPre=/bin/sleep 5
ExecStart=/opt/pisignage/scripts/start-kiosk.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable pisignage-kiosk
sudo systemctl enable lightdm

echo "✅ Installation terminée!"
echo "📊 Configuration GPU conservatrice (pas d'overclocking)"
sudo tee -a /boot/config.txt << 'BOOTCONFIG'

# === PiSignage - Configuration GPU Safe ===
# Mémoire GPU pour décodage vidéo
gpu_mem=128

# Driver vidéo optimisé (sans overclocking)
dtoverlay=vc4-kms-v3d
BOOTCONFIG

echo ""
echo "════════════════════════════════════════════"
echo " Installation complète! Redémarrage requis"
echo "════════════════════════════════════════════"
echo ""
echo "Le système va redémarrer..."
echo "Après redémarrage:"
echo "  - Interface web: http://192.168.1.103"
echo "  - Monitoring FPS sur l'écran HDMI"
echo "  - 3 vidéos en rotation (30 sec chacune)"
echo ""

sudo reboot

DEPLOY_SCRIPT