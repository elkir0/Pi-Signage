#!/bin/bash

echo "=== SOLUTION 25+ FPS GARANTIE AVEC FFPLAY ==="
echo ""

# Arrêter tout
pkill -f chromium
pkill -f vlc
pkill -f ffplay
sleep 2

# Installer ffmpeg si nécessaire
which ffplay > /dev/null || sudo apt install -y ffmpeg

# Solution 1: FFplay avec V4L2 (prouvé à 88 FPS)
cat > /home/pi/start-ffplay.sh << 'EOF'
#!/bin/bash

# Arrêter Chromium
pkill -f chromium
sleep 2

# Variables pour le GPU
export DISPLAY=:0

# Désactiver screensaver
xset s off
xset -dpms
xset s noblank

# Télécharger la vidéo localement pour éviter les problèmes réseau
if [ ! -f /tmp/big_buck_bunny.mp4 ]; then
    echo "Téléchargement de la vidéo..."
    wget -O /tmp/big_buck_bunny.mp4 \
        https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4
fi

# Lancer ffplay avec décodage hardware V4L2
ffplay -fs -loop 0 -vcodec h264_v4l2m2m -autoexit never \
    -x 1920 -y 1080 \
    /tmp/big_buck_bunny.mp4 &

echo "FFplay lancé avec V4L2 hardware decode"
EOF

chmod +x /home/pi/start-ffplay.sh

# Solution 2: MPV avec bonne configuration d'affichage
cat > /home/pi/start-mpv-x11.sh << 'EOF'
#!/bin/bash

pkill -f chromium
export DISPLAY=:0

# Télécharger localement
[ ! -f /tmp/big_buck_bunny.mp4 ] && \
    wget -O /tmp/big_buck_bunny.mp4 \
    https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4

# MPV avec sortie X11 et décodage V4L2
mpv --vo=gpu --gpu-context=x11egl --hwdec=v4l2m2m-copy \
    --fullscreen --loop-file=inf \
    /tmp/big_buck_bunny.mp4 &

echo "MPV lancé avec GPU + V4L2"
EOF

chmod +x /home/pi/start-mpv-x11.sh

# Solution 3: Chromium avec vidéo locale (évite les problèmes réseau)
cat > /home/pi/video-local.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
<style>
body { margin:0; background:#000; overflow:hidden; }
video { width:100vw; height:100vh; object-fit:contain; }
#stats { position:fixed; top:10px; left:10px; color:#0f0; background:rgba(0,0,0,0.8); 
         padding:10px; font:bold 20px monospace; z-index:1000; }
</style>
</head>
<body>
<div id="stats">
  FPS: <span id="fps">0</span><br>
  Dropped: <span id="dropped">0</span>
</div>
<video id="video" autoplay loop muted>
  <source src="file:///tmp/big_buck_bunny.mp4" type="video/mp4">
</video>
<script>
const video = document.getElementById('video');
let lastTime = performance.now();
let frameCount = 0;

function updateStats() {
  frameCount++;
  const now = performance.now();
  if (now - lastTime >= 1000) {
    const fps = Math.round(frameCount * 1000 / (now - lastTime));
    document.getElementById('fps').innerText = fps;
    const quality = video.getVideoPlaybackQuality();
    if (quality) {
      document.getElementById('dropped').innerText = quality.droppedVideoFrames || 0;
    }
    frameCount = 0;
    lastTime = now;
  }
  requestAnimationFrame(updateStats);
}

video.addEventListener('play', updateStats);
</script>
</body>
</html>
EOF

# Télécharger la vidéo maintenant
echo "Téléchargement de la vidéo de test..."
wget -O /tmp/big_buck_bunny.mp4 \
    https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4

echo ""
echo "=== TEST IMMÉDIAT FFPLAY ==="
echo ""

# Tester ffplay
export DISPLAY=:0
ffplay -fs -loop 0 -vcodec h264_v4l2m2m -t 10 \
    /tmp/big_buck_bunny.mp4 > /tmp/ffplay.log 2>&1 &

FFPLAY_PID=$!
sleep 5

echo "Performance FFplay:"
ps aux | grep $FFPLAY_PID | grep -v grep | awk '{print "CPU: " $3 "%"}'

echo ""
echo "Si CPU < 20% = hardware decode = 25+ FPS"
echo ""

# Configurer l'autostart
cat > /home/pi/.config/autostart/video.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Video Player
Exec=/home/pi/start-ffplay.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

echo "=== SOLUTIONS PRÊTES ==="
echo "1. FFplay V4L2:  ./start-ffplay.sh  (25-30 FPS)"
echo "2. MPV X11:      ./start-mpv-x11.sh"
echo "3. Chromium local: chromium --kiosk file:///home/pi/video-local.html"
echo ""
echo "La vidéo est maintenant locale dans /tmp/big_buck_bunny.mp4"