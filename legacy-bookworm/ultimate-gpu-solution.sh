#!/bin/bash

echo "=== SOLUTION ULTIME POUR 25+ FPS ==="
echo ""
echo "Arrêt de tout..."
pkill -f chromium
pkill -f vlc
pkill -f mpv
sleep 2

# 1. Installer VLC et les codecs
echo "Installation VLC optimisé..."
sudo apt update
sudo apt install -y vlc vlc-plugin-base

# 2. Configurer pour utiliser le framebuffer directement
echo "Configuration du framebuffer..."
sudo usermod -a -G video pi

# 3. Créer le script VLC optimisé pour Pi 4
cat > /home/pi/vlc-gpu.sh << 'EOF'
#!/bin/bash

# Configuration pour forcer l'utilisation du GPU
export DISPLAY=:0

# Arrêter Chromium
pkill -f chromium

# Désactiver l'écran de veille
xset s off
xset -dpms  
xset s noblank

# Lancer VLC avec les bons paramètres pour Pi 4
cvlc \
    --fullscreen \
    --video-on-top \
    --no-video-title-show \
    --mouse-hide-timeout=0 \
    --loop \
    --no-osd \
    --vout=mmal_vout \
    --mmal-display=hdmi-1 \
    --mmal-layer=10 \
    --avcodec-hw=mmal \
    --codec=mmal,h264_mmal,any \
    https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4 &

echo "VLC lancé avec accélération MMAL (GPU VideoCore)"
EOF

chmod +x /home/pi/vlc-gpu.sh

# 4. Alternative avec ffplay (très léger)
cat > /home/pi/ffplay-gpu.sh << 'EOF'
#!/bin/bash

pkill -f chromium
export DISPLAY=:0

# ffplay avec décodage hardware
ffplay -fs -loop 0 -vcodec h264_v4l2m2m -an \
    https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4 &

echo "FFplay avec décodage V4L2 hardware"
EOF

chmod +x /home/pi/ffplay-gpu.sh

# 5. Solution Chromium Legacy (qui marchait avant)
cat > /home/pi/chromium-legacy.sh << 'EOF'
#!/bin/bash

# Downgrade vers une version qui fonctionne
echo "Installation Chromium 134 (dernière version stable avec GPU)..."
wget -q https://archive.raspberrypi.org/debian/pool/main/c/chromium-browser/chromium-browser_134.0.6478.92-rpt1_armhf.deb
wget -q https://archive.raspberrypi.org/debian/pool/main/c/chromium-browser/chromium-codecs-ffmpeg-extra_134.0.6478.92-rpt1_armhf.deb
sudo dpkg -i chromium*.deb

# Lancer avec GPU
export DISPLAY=:0
chromium-browser \
    --kiosk \
    --enable-gpu \
    --ignore-gpu-blocklist \
    --enable-gpu-rasterization \
    --enable-accelerated-2d-canvas \
    --use-gl=egl \
    --enable-features=VaapiVideoDecoder \
    --autoplay-policy=no-user-gesture-required \
    file:///home/pi/video-test.html
EOF

chmod +x /home/pi/chromium-legacy.sh

echo ""
echo "=== TEST IMMÉDIAT AVEC VLC ==="
echo ""

# Lancer VLC maintenant
export DISPLAY=:0
pkill -f chromium
sleep 2

# Test direct VLC
cvlc --fullscreen --loop --vout=mmal_vout --avcodec-hw=mmal \
    https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4 > /tmp/vlc-test.log 2>&1 &

VLC_PID=$!
sleep 5

echo "Performance VLC avec MMAL (GPU VideoCore):"
ps aux | grep $VLC_PID | grep -v grep | awk '{print "CPU: " $3 "%"}'

echo ""
echo "Si CPU < 15% = GPU actif = 30-60 FPS"
echo "Si CPU > 50% = software = 5-10 FPS"
echo ""
echo "Logs VLC:"
tail -5 /tmp/vlc-test.log

echo ""
echo "=== SOLUTIONS DISPONIBLES ==="
echo "1. VLC GPU:  ./vlc-gpu.sh  (RECOMMANDÉ)"
echo "2. FFplay:   ./ffplay-gpu.sh"
echo "3. Chromium: ./chromium-legacy.sh"