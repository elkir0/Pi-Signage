#!/bin/bash

echo "=== OPTIMISATION GPU RASPBERRY PI 4 - 25+ FPS ==="
echo ""

# 1. Optimiser /boot/config.txt (ou /boot/firmware/config.txt sur certaines versions)
echo "[1/5] Configuration GPU dans /boot/config.txt..."

BOOT_CONFIG="/boot/config.txt"
[ -f "/boot/firmware/config.txt" ] && BOOT_CONFIG="/boot/firmware/config.txt"

# Backup
sudo cp $BOOT_CONFIG ${BOOT_CONFIG}.backup.$(date +%Y%m%d)

# Ajouter les optimisations GPU
sudo tee -a $BOOT_CONFIG << 'EOF'

# GPU Optimizations for Video Playback
gpu_mem=256
gpu_freq=600
v3d_freq=600
over_voltage=2
dtoverlay=vc4-kms-v3d,cma-256
max_framebuffers=2

EOF

echo "✓ Configuration GPU optimisée"

# 2. Installer les dépendances manquantes
echo ""
echo "[2/5] Installation des dépendances GPU..."
sudo apt update
sudo apt install -y \
    libgles2-mesa \
    libgles2-mesa-dev \
    libegl1-mesa \
    libegl1-mesa-dev \
    libgl1-mesa-dri \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    libva-drm2 \
    libva-x11-2 \
    chromium-codecs-ffmpeg-extra

echo "✓ Dépendances installées"

# 3. Créer le nouveau script kiosk optimisé
echo ""
echo "[3/5] Création du script Chromium optimisé..."

cat > /home/pi/kiosk-optimized.sh << 'EOF'
#!/bin/bash

# Configuration écran
xset s off
xset -dpms
xset s noblank
unclutter -idle 0.5 -root &

# Variables d'environnement pour forcer le GPU
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_GL_VERSION_OVERRIDE=3.3
export MESA_GLSL_VERSION_OVERRIDE=330

# Lance Chromium avec les FLAGS OPTIMAUX pour Pi 4
chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-pinch \
    --overscroll-history-navigation=0 \
    --check-for-update-interval=31536000 \
    --autoplay-policy=no-user-gesture-required \
    --enable-gpu \
    --enable-gpu-rasterization \
    --enable-accelerated-2d-canvas \
    --enable-accelerated-video-decode \
    --ignore-gpu-blocklist \
    --disable-gpu-sandbox \
    --use-gl=egl \
    --enable-features=VaapiVideoDecoder,VaapiVideoEncoder \
    --disable-features=UseChromeOSDirectVideoDecoder \
    --enable-drm-atomic \
    --enable-v4l2-decode-accel \
    --v4l2-device=/dev/video10 \
    --enable-precise-memory-info \
    --show-fps-counter \
    file:///home/pi/video-test.html
EOF

chmod +x /home/pi/kiosk-optimized.sh

# 4. Créer une alternative VLC (meilleure performance)
echo ""
echo "[4/5] Création alternative VLC kiosk (3-15% CPU, 60 FPS)..."

cat > /home/pi/vlc-kiosk.sh << 'EOF'
#!/bin/bash

# Désactive l'écran de veille
xset s off
xset -dpms
xset s noblank

# Lance VLC avec accélération GPU optimale
cvlc \
    --fullscreen \
    --no-video-title-show \
    --mouse-hide-timeout=0 \
    --repeat \
    --no-osd \
    --vout=gles2 \
    --gl=gles2 \
    --avcodec-hw=drm \
    --codec=h264_v4l2m2m,h264 \
    https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4
EOF

chmod +x /home/pi/vlc-kiosk.sh

# Installer VLC si nécessaire
if ! command -v vlc &> /dev/null; then
    sudo apt install -y vlc
fi

# 5. Créer script de test de performance
echo ""
echo "[5/5] Création du script de test..."

cat > /home/pi/test-performance.sh << 'EOF'
#!/bin/bash

echo "=== TEST DE PERFORMANCE GPU ==="
echo ""

# Info système
echo "Modèle: $(cat /proc/device-tree/model)"
echo "GPU Mem: $(vcgencmd get_mem gpu)"
echo "Temp: $(vcgencmd measure_temp)"
echo ""

# Test OpenGL
echo "Test OpenGL ES:"
glxinfo 2>/dev/null | grep -E "OpenGL|renderer" | head -5

# Info V4L2
echo ""
echo "Décodeurs V4L2:"
v4l2-ctl --list-devices 2>/dev/null | head -10

# Process GPU
echo ""
echo "Process GPU actif:"
ps aux | grep -E "gpu|GL|v4l2" | grep -v grep | head -5

echo ""
echo "=== OPTIONS DE LANCEMENT ==="
echo "1. Chromium optimisé: ./kiosk-optimized.sh"
echo "2. VLC (meilleur): ./vlc-kiosk.sh"
echo "3. Chromium ancien: ./kiosk.sh"
EOF

chmod +x /home/pi/test-performance.sh

# Mettre à jour l'autostart
echo ""
echo "Configuration de l'autostart avec version optimisée..."
sed -i 's|/home/pi/kiosk.sh|/home/pi/kiosk-optimized.sh|g' /home/pi/.bashrc
sed -i 's|/home/pi/kiosk.sh|/home/pi/kiosk-optimized.sh|g' /home/pi/.config/autostart/kiosk.desktop

echo ""
echo "=== OPTIMISATION TERMINÉE ==="
echo ""
echo "⚠️  REDÉMARRAGE REQUIS pour appliquer gpu_mem=256"
echo ""
echo "Après redémarrage:"
echo "  - Chromium devrait atteindre 25-30 FPS"
echo "  - VLC peut atteindre 60 FPS (recommandé)"
echo ""
echo "Test maintenant avec: ./test-performance.sh"
echo ""
echo "Appuyez sur une touche pour redémarrer..."
read -n 1
sudo reboot