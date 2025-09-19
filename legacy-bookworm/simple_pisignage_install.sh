#!/bin/bash
set -e

echo "=== Installation simplifiée de piSignage avec Chromium ==="

# 1. Mise à jour du système
echo "Mise à jour du système..."
sudo apt-get update
sudo apt-get upgrade -y

# 2. Installation des dépendances
echo "Installation des dépendances..."
sudo apt-get install -y \
    chromium \
    xserver-xorg \
    x11-xserver-utils \
    xinit \
    openbox \
    nginx \
    php-fpm \
    unclutter \
    vlc

# 3. Configuration GPU pour Pi 4
echo "Configuration GPU..."
if ! grep -q "gpu_mem=" /boot/firmware/config.txt 2>/dev/null; then
    echo "gpu_mem=128" | sudo tee -a /boot/firmware/config.txt
    echo "dtoverlay=vc4-fkms-v3d" | sudo tee -a /boot/firmware/config.txt  
fi

# 4. Créer la structure des répertoires
echo "Création des répertoires..."
sudo mkdir -p /opt/pisignage/videos
sudo mkdir -p /opt/pisignage/web
sudo mkdir -p /var/log/pisignage

# 5. Créer le player HTML5
echo "Création du player HTML5..."
sudo tee /opt/pisignage/web/index.html > /dev/null << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Pi Signage Player</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; cursor: none; }
        body { background: black; overflow: hidden; }
        video { width: 100vw; height: 100vh; object-fit: fill; }
    </style>
</head>
<body>
    <video id="player" autoplay loop muted playsinline></video>
    <script>
        const player = document.getElementById('player');
        
        // Liste des vidéos disponibles
        fetch('/videos/')
            .then(r => r.text())
            .then(html => {
                const parser = new DOMParser();
                const doc = parser.parseFromString(html, 'text/html');
                const links = doc.querySelectorAll('a[href$=".mp4"], a[href$=".webm"]');
                const videos = Array.from(links).map(a => '/videos/' + a.getAttribute('href'));
                
                if (videos.length > 0) {
                    let currentIndex = 0;
                    
                    function playNext() {
                        player.src = videos[currentIndex];
                        player.play();
                        currentIndex = (currentIndex + 1) % videos.length;
                    }
                    
                    player.addEventListener('ended', playNext);
                    playNext();
                } else {
                    // Vidéo par défaut si aucune trouvée
                    player.src = '/videos/test_video.mp4';
                    player.play();
                }
            });
    </script>
</body>
</html>
HTML

# 6. Configuration nginx
echo "Configuration nginx..."
sudo tee /etc/nginx/sites-available/pisignage > /dev/null << 'NGINX'
server {
    listen 80;
    server_name _;
    
    root /opt/pisignage/web;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /videos/ {
        alias /opt/pisignage/videos/;
        autoindex on;
        add_header Accept-Ranges bytes;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

# 7. Script de démarrage Chromium
echo "Création du script de démarrage..."
sudo tee /opt/pisignage/start_kiosk.sh > /dev/null << 'SCRIPT'
#!/bin/bash

# Attendre le réseau
sleep 5

# Configuration écran
export DISPLAY=:0
xset s off
xset -dpms
xset s noblank
unclutter -idle 0 &

# Lancer Chromium en mode kiosk
chromium \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --no-first-run \
    --check-for-update-interval=31536000 \
    --disable-features=TranslateUI \
    --overscroll-history-navigation=0 \
    --disable-pinch \
    --enable-features=VaapiVideoDecoder \
    --use-gl=egl \
    --enable-gpu-rasterization \
    --enable-oop-rasterization \
    --ignore-gpu-blocklist \
    --autoplay-policy=no-user-gesture-required \
    http://localhost
SCRIPT
sudo chmod +x /opt/pisignage/start_kiosk.sh

# 8. Autologin et autostart
echo "Configuration autologin..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null << 'GETTY'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
GETTY

# 9. Configuration openbox autostart
mkdir -p /home/pi/.config/openbox
tee /home/pi/.config/openbox/autostart > /dev/null << 'AUTOSTART'
#!/bin/bash
/opt/pisignage/start_kiosk.sh &
AUTOSTART
chmod +x /home/pi/.config/openbox/autostart

# 10. Démarrage automatique de X
if ! grep -q "startx" /home/pi/.profile; then
    echo 'if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then' >> /home/pi/.profile
    echo '    startx -- -nocursor' >> /home/pi/.profile
    echo 'fi' >> /home/pi/.profile
fi

# Copier les vidéos existantes
if [ -d /opt/videos ]; then
    sudo cp /opt/videos/*.mp4 /opt/pisignage/videos/ 2>/dev/null || true
fi

echo "=== Installation terminée ===" 
echo "Le système va redémarrer dans 5 secondes..."
echo "Après redémarrage:"
echo "  - Interface web: http://$(hostname -I | cut -d' ' -f1)"
echo "  - Vidéos dans: /opt/pisignage/videos/"
sleep 5
sudo reboot
