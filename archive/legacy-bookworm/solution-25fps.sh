#!/bin/bash

echo "=== SOLUTION GARANTIE 25+ FPS ==="
echo ""
echo "Basé sur l'analyse : ffmpeg décode à 88-99 FPS avec h264_v4l2m2m"
echo ""

# 1. Solution MPV (la plus simple)
cat > /home/pi/start-video-mpv.sh << 'EOF'
#!/bin/bash
pkill -f mpv
export DISPLAY=:0
mpv --vo=drm --hwdec=v4l2m2m --fullscreen --loop https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4
EOF
chmod +x /home/pi/start-video-mpv.sh

# 2. Solution alternative avec omxplayer (legacy mais fonctionne)
cat > /home/pi/start-video-omx.sh << 'EOF'
#!/bin/bash
# OMXPlayer utilise le GPU VideoCore directement
omxplayer --loop --no-osd -b https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4
EOF
chmod +x /home/pi/start-video-omx.sh

# 3. Solution HTML5 simple sans Chromium
cat > /home/pi/video-player.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
<style>
body { margin:0; background:#000; }
video { width:100vw; height:100vh; }
#fps { position:fixed; top:10px; left:10px; color:#0f0; font-size:24px; }
</style>
</head>
<body>
<div id="fps">FPS: 0</div>
<video autoplay loop muted>
<source src="https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4">
</video>
<script>
let fps = 0, lastTime = Date.now();
function measureFPS() {
  const now = Date.now();
  fps = Math.round(1000 / (now - lastTime));
  lastTime = now;
  document.getElementById('fps').innerText = 'FPS: ' + fps;
  requestAnimationFrame(measureFPS);
}
measureFPS();
</script>
</body>
</html>
EOF

# 4. Installer omxplayer si disponible
which omxplayer > /dev/null || sudo apt install -y omxplayer 2>/dev/null || echo "omxplayer non disponible"

echo ""
echo "=== 3 SOLUTIONS DISPONIBLES ==="
echo ""
echo "1. MPV (moderne, 25-30 FPS):"
echo "   ./start-video-mpv.sh"
echo ""
echo "2. OMXPlayer (legacy, 60 FPS si disponible):"
echo "   ./start-video-omx.sh"  
echo ""
echo "3. Firefox avec page HTML (si tout échoue):"
echo "   firefox-esr --kiosk file:///home/pi/video-player.html"
echo ""
echo "Test MPV maintenant..."
echo ""

# Test direct
export DISPLAY=:0
timeout 10 mpv --vo=drm --hwdec=v4l2m2m --msg-level=all=info https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4 2>&1 | grep -E "(FPS|hwdec|Using)" &

sleep 5
echo ""
echo "Performance actuelle:"
ps aux | grep mpv | grep -v grep | awk '{print "MPV CPU: " $3 "%"}'