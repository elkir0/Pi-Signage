#!/bin/bash

echo "=== Configuration vidéo test avec FPS ==="

# Création de la page HTML pour lire la vidéo en boucle
cat > /home/pi/video-test.html << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Vidéo FPS</title>
    <style>
        * { margin: 0; padding: 0; }
        body { 
            background: #000; 
            overflow: hidden;
            font-family: monospace;
        }
        video { 
            width: 100vw; 
            height: 100vh; 
            object-fit: contain;
        }
        #stats {
            position: fixed;
            top: 10px;
            left: 10px;
            color: #0f0;
            background: rgba(0,0,0,0.8);
            padding: 10px;
            font-size: 16px;
            z-index: 1000;
            border: 1px solid #0f0;
        }
    </style>
</head>
<body>
    <div id="stats">
        FPS: <span id="fps">0</span><br>
        Frame Time: <span id="frametime">0</span>ms<br>
        Video: 720p H.264 10s Loop
    </div>
    <video id="video" autoplay loop muted>
        <source src="https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4" type="video/mp4">
    </video>
    <script>
        // FPS Counter
        let frameCount = 0;
        let lastTime = performance.now();
        let fps = 0;
        
        function updateFPS() {
            frameCount++;
            const currentTime = performance.now();
            const deltaTime = currentTime - lastTime;
            
            if (deltaTime >= 1000) {
                fps = Math.round((frameCount * 1000) / deltaTime);
                document.getElementById('fps').textContent = fps;
                document.getElementById('frametime').textContent = Math.round(deltaTime / frameCount);
                frameCount = 0;
                lastTime = currentTime;
            }
            
            requestAnimationFrame(updateFPS);
        }
        
        // Start FPS counter
        updateFPS();
        
        // Log video events
        const video = document.getElementById('video');
        video.addEventListener('loadstart', () => console.log('Loading video...'));
        video.addEventListener('canplay', () => console.log('Video ready to play'));
        video.addEventListener('play', () => console.log('Video playing'));
        video.addEventListener('error', (e) => console.error('Video error:', e));
    </script>
</body>
</html>
EOF

# Mise à jour du script kiosk.sh
cat > /home/pi/kiosk.sh << 'EOF'
#!/bin/bash
# Désactive l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Cache le curseur
unclutter -idle 0.5 -root &

# Lance Chromium avec GPU et stats de performance
chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --check-for-update-interval=31536000 \
    --disable-pinch \
    --overscroll-history-navigation=0 \
    --enable-gpu-rasterization \
    --enable-accelerated-2d-canvas \
    --enable-accelerated-video-decode \
    --ignore-gpu-blocklist \
    --disable-gpu-sandbox \
    --enable-features=VaapiVideoDecoder \
    --use-gl=egl \
    --disable-features=UseChromeOSDirectVideoDecoder \
    --autoplay-policy=no-user-gesture-required \
    --enable-precise-memory-info \
    --enable-fps-counter \
    --show-fps-counter \
    --enable-gpu-benchmarking \
    file:///home/pi/video-test.html
EOF

chmod +x /home/pi/kiosk.sh
chown pi:pi /home/pi/video-test.html
chown pi:pi /home/pi/kiosk.sh

echo "✓ Configuration mise à jour!"
echo "✓ Vidéo: Big Buck Bunny 720p 10s (30MB)"
echo "✓ Affichage FPS activé"
echo ""
echo "Redémarrage dans 3 secondes..."
sleep 3
sudo reboot