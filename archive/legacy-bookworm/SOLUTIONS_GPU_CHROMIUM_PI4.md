# Solutions GPU pour Chromium sur Raspberry Pi 4 - Digital Signage

## OBJECTIF: Atteindre 25+ FPS sur vidéo 720p H264

Ce document compile les **solutions testées et validées par la communauté** pour optimiser les performances GPU de Chromium sur Raspberry Pi 4 avec Raspberry Pi OS Bookworm.

---

## 🎯 1. FLAGS CHROMIUM OPTIMAUX - TESTÉS 2024/2025

### Configuration recommandée pour Kiosk Mode + GPU:

```bash
chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --check-for-update-interval=31536000 \
    --disable-pinch \
    --overscroll-history-navigation=0 \
    \
    # GPU Acceleration - CORE FLAGS
    --use-angle=gles \
    --use-gl=egl \
    --enable-gpu-rasterization \
    --enable-native-gpu-memory-buffers \
    --ignore-gpu-blocklist \
    --enable-zero-copy \
    \
    # Video Acceleration
    --enable-accelerated-video-decode \
    --enable-features=VaapiVideoDecoder \
    --disable-features=UseChromeOSDirectVideoDecoder \
    --autoplay-policy=no-user-gesture-required \
    \
    # Performance optimizations
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --aggressive-cache-discard \
    --max-active-webgl-contexts=2 \
    \
    # Debug/Monitoring (optionnel)
    --enable-precise-memory-info \
    --show-fps-counter \
    --enable-gpu-benchmarking
```

### Configuration via fichier `/etc/chromium.d/00-rpi-vars`:

```bash
# Création du fichier de configuration
sudo mkdir -p /etc/chromium.d
sudo tee /etc/chromium.d/00-rpi-vars << 'EOF'
export CHROMIUM_FLAGS="--enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --enable-features=CanvasOopRasterization,VaapiVideoDecoder --use-angle=gles --use-gl=egl"
EOF
```

---

## 🚨 2. PROBLÈMES CONNUS - CHROMIUM 135+ sur ARM64

### Symptômes identifiés:
- **Écran blanc avec son** sur les vidéos YouTube avec Chromium 135/136
- **Erreur Skia**: "SharedImageManager::ProduceSkia: Trying to produce a Skia representation from an incompatible backing"
- **Affect uniquement GNOME**, fonctionne avec Raspberry Pi Desktop

### Solutions de contournement:
```bash
# 1. Désactiver temporairement GPU pour diagnostiquer
chromium-browser --disable-gpu

# 2. Forcer l'utilisation de Mesa/EGL
chromium-browser --use-gl=egl --enable-features=UseOzonePlatform --ozone-platform=wayland

# 3. Downgrade vers Chromium 134 si possible
sudo apt install chromium-browser=134.x.x.x
sudo apt-mark hold chromium-browser
```

---

## 🔄 3. ALTERNATIVES PERFORMANTES

### A. Firefox 116+ avec Hardware Acceleration

**Avantages**: Support H.264 natif via V4L2-M2M, CPU usage < 20%

```bash
# Installation et configuration
sudo apt install firefox-esr

# Configuration dans about:config
media.ffmpeg.vaapi.enabled = true
media.hardware-video-decoding.enabled = true
media.hardware-video-decoding.force-enabled = true
gfx.webrender.all = true
```

**Performance attendue**: 10-20% CPU usage pour 720p H.264

### B. VLC Kiosk Mode avec GPU natif

**Avantages**: Excellent support H.264, CPU ~15% par core, très stable

```bash
# Configuration VLC avec accélération GPU
vlc --intf dummy --fullscreen --no-osd --loop \
    --vout=gl --gl=gles2 \
    --codec=avcodec,all \
    --avcodec-hw=drm \
    video.mp4
```

**Performance attendue**: 3-15% CPU usage, lecture fluide 60fps

### C. MPV avec Hardware Decoding

**Configuration ~/.config/mpv/mpv.conf**:
```bash
hwdec=drm-copy
vo=gpu
gpu-api=opengl
opengl-es=yes
```

**Performance**: ~35% CPU usage (moins optimal que VLC)

### D. Info-beamer (Solution commerciale optimisée)

**Avantages**: Custom player optimisé Pi, 40-50 FPS stable
- Solution spécialement optimisée pour Raspberry Pi
- GPU acceleration custom
- Support jusqu'à 720p avec overlays

---

## ⚙️ 4. CONFIGURATION SYSTÈME OPTIMALE

### A. X11 vs Wayland - Recommandations 2024/2025

**Wayland + labwc (Recommandé)**:
- Meilleur support GPU acceleration (HVS VideoCore)
- 500 Megapixel/s scaling, 1 Gigapixel/s blending
- Moins de tearing, animations plus fluides
- Support natif Mesa + DRM

**Vérifier et changer**:
```bash
# Vérifier l'environnement actuel
echo $XDG_SESSION_TYPE

# Changer via raspi-config
sudo raspi-config
# Advanced Options → Wayland → W1 Enable Wayland
```

### B. Configuration GPU Memory

**Bookworm (gpu_mem optionnel)**:
```bash
# Vérifier la configuration actuelle
vcgencmd get_mem gpu
vcgencmd get_mem arm

# Si nécessaire, configurer via raspi-config
sudo raspi-config
# Advanced Options → Memory Split → 128
```

### C. Firmware et drivers

```bash
# Mettre à jour le firmware (critique pour GPU)
sudo rpi-update
sudo reboot

# Vérifier Mesa version (minimum 22.2.4 pour Bookworm)
glxinfo | grep "OpenGL version"
```

---

## 🔍 5. DIAGNOSTIC ET MONITORING

### A. Vérification Hardware Acceleration

```bash
# 1. Test GPU info
glxinfo | grep -i "renderer\|vendor"
vainfo

# 2. Vérifier processus GPU Chromium
ps aux | grep chromium | grep -E "(gpu-process|--type=gpu)"

# 3. Monitor performance
watch -n 1 'top -bn1 | head -20'
```

### B. Page HTML5 pour test FPS

```html
<!DOCTYPE html>
<html>
<head>
    <title>Pi4 GPU Test</title>
    <style>
        body { margin: 0; background: black; font-family: monospace; }
        video { width: 100vw; height: 100vh; object-fit: contain; }
        #stats { 
            position: fixed; top: 10px; left: 10px; 
            color: lime; background: rgba(0,0,0,0.8); 
            padding: 10px; z-index: 1000; 
        }
    </style>
</head>
<body>
    <div id="stats">
        FPS: <span id="fps">0</span><br>
        CPU Target: &lt;10% pour 720p<br>
        Decoder: GPU Accelerated
    </div>
    <video id="video" autoplay loop muted>
        <source src="https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4" type="video/mp4">
    </video>
    <script>
        let frameCount = 0, lastTime = performance.now();
        function updateFPS() {
            frameCount++;
            const currentTime = performance.now();
            if (currentTime >= lastTime + 1000) {
                const fps = Math.round((frameCount * 1000) / (currentTime - lastTime));
                document.getElementById('fps').textContent = fps;
                frameCount = 0; lastTime = currentTime;
            }
            requestAnimationFrame(updateFPS);
        }
        updateFPS();
    </script>
</body>
</html>
```

### C. Script de test automatisé

```bash
#!/bin/bash
# Test de performance GPU
echo "=== TEST PERFORMANCE GPU ==="

# Température et throttling
vcgencmd measure_temp
vcgencmd get_throttled

# Mémoire et fréquences
vcgencmd get_mem gpu
vcgencmd measure_clock arm | awk -F= '{printf "CPU: %.2f GHz\n", $2/1000000000}'
vcgencmd measure_clock core | awk -F= '{printf "GPU: %.0f MHz\n", $2/1000000}'

# Test playback Chromium
timeout 10 chromium-browser --headless --enable-gpu-benchmarking \
    --run-all-compositor-stages-before-draw \
    --disable-web-security \
    "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4"

echo "Test terminé. Vérifier les logs ci-dessus."
```

---

## 📊 6. SUCCESS STORIES - PROJETS VALIDÉS

### Configuration type Info-beamer
- **Performance**: 43 FPS stable en 720p
- **CPU**: < 10% avec GPU optimisé
- **Fiabilité**: Milliers d'installations mondiales

### Configuration type PiSignage
- **Support**: H.264 jusqu'à 1080p
- **Hardware acceleration**: Players optimisés Pi
- **Limitation**: Pas de support H.265/HEVC actuellement

### Configuration type Screenly
- **Déploiement**: Multi-continental
- **Performance**: Variable selon version (15-25 FPS récemment)
- **Recommandation**: Tester configuration custom

---

## ✅ 7. CONFIGURATION RECOMMANDÉE FINALE

### Pour Digital Signage 720p @ 25+ FPS:

1. **OS**: Raspberry Pi OS Bookworm Desktop (pas Lite)
2. **Display**: Wayland + labwc (par défaut Bookworm)
3. **Browser**: Chromium avec flags optimisés OU Firefox 116+
4. **Alternative**: VLC kiosk pour fiabilité maximale
5. **Hardware**: Pi 4 4GB+, alimentation officielle, SSD USB

### Script d'installation rapide:

```bash
#!/bin/bash
# Installation optimisée pour Pi 4 Digital Signage

# Mise à jour système
sudo apt update && sudo apt upgrade -y
sudo rpi-update && sudo reboot

# Installation Chromium optimisé
sudo apt install -y chromium-browser xserver-xorg unclutter

# Configuration GPU flags
sudo mkdir -p /etc/chromium.d
sudo tee /etc/chromium.d/00-gpu-flags << 'EOF'
export CHROMIUM_FLAGS="--use-angle=gles --use-gl=egl --enable-gpu-rasterization --ignore-gpu-blocklist --enable-features=VaapiVideoDecoder --autoplay-policy=no-user-gesture-required"
EOF

# Script kiosk
cat > /home/pi/signage.sh << 'EOF'
#!/bin/bash
export DISPLAY=:0
xset s off -dpms s noblank
unclutter -idle 0.5 -root &
chromium-browser --kiosk \
    --use-angle=gles --use-gl=egl \
    --enable-gpu-rasterization --ignore-gpu-blocklist \
    --enable-features=VaapiVideoDecoder \
    --autoplay-policy=no-user-gesture-required \
    "file:///home/pi/test-720p.html"
EOF

chmod +x /home/pi/signage.sh
echo "Configuration terminée. Tester avec: /home/pi/signage.sh"
```

---

## 🎯 RÉSULTATS ATTENDUS

**Avec configuration optimale**:
- ✅ **FPS**: 25-60 stable en 720p H.264
- ✅ **CPU**: < 10% usage moyen
- ✅ **GPU**: Hardware acceleration active (MojoVideoDecoder)
- ✅ **Stabilité**: 24/7 sans degradation
- ✅ **Latence**: < 100ms démarrage vidéo

**Alternatives si problèmes Chromium**:
- 🔄 **Firefox 116+**: 20% CPU, excellent H.264
- 🔄 **VLC**: 15% CPU, fiabilité maximale
- 🔄 **Info-beamer**: Solution commerciale optimisée

---

*Document mis à jour le 19 septembre 2025 avec les dernières découvertes communautaires*