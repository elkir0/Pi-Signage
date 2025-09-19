#!/bin/bash

echo "=== Installation piSignage avec Chromium Kiosk ==="

# 1. Installer les dépendances nécessaires
echo "Installation des dépendances..."
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    xserver-xorg \
    x11-xserver-utils \
    xinit \
    openbox \
    chromium \
    nginx \
    unclutter

# 2. Créer les répertoires nécessaires
sudo mkdir -p /opt/pisignage/videos
sudo mkdir -p /opt/pisignage/web

# 3. Créer le player HTML5 avec optimisations
cat << 'HTML' | sudo tee /opt/pisignage/web/index.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Pi Signage Player</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: black; overflow: hidden; cursor: none; }
        video { 
            width: 100vw; 
            height: 100vh; 
            object-fit: fill;
            background: black;
        }
    </style>
</head>
<body>
    <video id="player" autoplay loop muted playsinline>
        Your browser doesn't support HTML5 video.
    </video>
    <script>
        const videos = [
            'big_buck_bunny.mp4',
            'sample.mp4'
        ];
        
        let currentIndex = 0;
        const player = document.getElementById('player');
        
        function playNext() {
            player.src = '/videos/' + videos[currentIndex];
            player.play().catch(e => {
                console.error('Play failed:', e);
                player.muted = true;
                player.play();
            });
            
            currentIndex = (currentIndex + 1) % videos.length;
        }
        
        player.addEventListener('ended', playNext);
        player.addEventListener('error', () => {
            console.error('Video error, trying next');
            setTimeout(playNext, 1000);
        });
        
        // Start playing
        playNext();
        
        // Keep screen awake
        if ('wakeLock' in navigator) {
            navigator.wakeLock.request('screen').catch(console.error);
        }
    </script>
</body>
</html>
HTML

# 4. Configurer nginx
sudo tee /etc/nginx/sites-available/pisignage << 'NGINX'
server {
    listen 8080;
    server_name localhost;
    
    root /opt/pisignage/web;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /videos/ {
        alias /opt/pisignage/videos/;
        add_header Accept-Ranges bytes;
        add_header Cache-Control "public, max-age=3600";
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

# 5. Créer le script de démarrage
sudo tee /opt/pisignage/start_kiosk.sh << 'SCRIPT'
#!/bin/bash

# Attendre que le système soit prêt
sleep 5

# Configuration de l'environnement
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Désactiver l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Cacher le curseur
unclutter -idle 0 &

# Démarrer Chromium en mode kiosk avec optimisations GPU
chromium \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI \
    --overscroll-history-navigation=0 \
    --disable-pinch \
    --no-first-run \
    --check-for-update-interval=31536000 \
    --homepage="http://localhost:8080" \
    --enable-features=VaapiVideoDecoder \
    --use-gl=egl \
    --enable-gpu-rasterization \
    --enable-oop-rasterization \
    --ignore-gpu-blocklist \
    --disable-software-rasterizer \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --autoplay-policy=no-user-gesture-required \
    http://localhost:8080
SCRIPT

sudo chmod +x /opt/pisignage/start_kiosk.sh

# 6. Configuration de l'autologin
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'GETTY'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
GETTY

# 7. Configuration openbox et autostart X
mkdir -p /home/pi/.config/openbox
tee /home/pi/.config/openbox/autostart << 'AUTOSTART'
#!/bin/bash
/opt/pisignage/start_kiosk.sh &
AUTOSTART

chmod +x /home/pi/.config/openbox/autostart

# 8. Configurer le démarrage automatique de X
echo 'if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then' >> /home/pi/.profile
echo '    startx -- -nocursor' >> /home/pi/.profile
echo 'fi' >> /home/pi/.profile

# 9. Optimisation GPU (Pi 4)
if ! grep -q "gpu_mem=" /boot/firmware/config.txt 2>/dev/null; then
    if [ -f /boot/firmware/config.txt ]; then
        echo "gpu_mem=128" | sudo tee -a /boot/firmware/config.txt
        echo "dtoverlay=vc4-fkms-v3d" | sudo tee -a /boot/firmware/config.txt
    elif [ -f /boot/config.txt ]; then
        echo "gpu_mem=128" | sudo tee -a /boot/config.txt
        echo "dtoverlay=vc4-fkms-v3d" | sudo tee -a /boot/config.txt
    fi
fi

echo "=== Installation terminée ==="
echo "Le système va redémarrer dans 5 secondes..."
sleep 5
sudo reboot
