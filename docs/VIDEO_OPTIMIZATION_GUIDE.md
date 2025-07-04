# Guide d'Optimisation Vidéo pour Pi Signage

## Vue d'ensemble

Ce guide documente les optimisations vidéo appliquées à Pi Signage v2.4.8+ pour améliorer les performances de lecture vidéo sur Raspberry Pi 4, particulièrement pour les contenus 1080p affichés sur des écrans 4K.

## Optimisations Appliquées (Approche Prudente)

### 1. Configuration GPU Memory (gpu_mem)

**Fichier**: `01-system-config.sh`

- **Valeur configurée**: `gpu_mem=128`
- **Pourquoi**: Nécessaire pour activer l'accélération hardware H.264. Une valeur inférieure à 64MB désactive complètement les codecs hardware.
- **Impact**: Amélioration significative des performances de décodage vidéo sans impact notable sur la RAM système (seulement 128MB sur 2GB+).

### 2. Flags Chromium pour l'Accélération GPU

**Fichier**: `03-chromium-kiosk.sh`

Nouveaux flags ajoutés :
```bash
--use-gl=egl                    # Utilise EGL pour l'accélération GPU
--enable-gpu-rasterization      # Active la rastérisation GPU
--enable-native-gpu-memory-buffers  # Buffers GPU natifs
--ignore-gpu-blocklist          # Ignore la blocklist GPU
```

Flags spécifiques Wayland/X11 :
```bash
--enable-features=VaapiVideoDecoder,CanvasOopRasterization
--disable-features=UseChromeOSDirectVideoDecoder
```

**Impact**: Active le décodage hardware H.264 via V4L2/VAAPI, réduisant l'utilisation CPU de ~60% à ~30%.

### 3. Support V4L2 pour le Nouveau Stack de Décodage

**Paquets ajoutés**:
- `libv4l-dev` - Bibliothèques de développement V4L2
- `v4l-utils` - Utilitaires V4L2 pour la vérification

**Vérifications au démarrage**:
- Détection du codec H264 via `vcgencmd codec_enabled H264`
- Vérification du device `/dev/video10` (décodeur H264)

### 4. Configuration dtoverlay

**Ajout automatique si manquant**:
```
dtoverlay=vc4-kms-v3d
max_framebuffers=2
```

**Impact**: Active le driver KMS/DRM moderne nécessaire pour l'accélération GPU.

## Vérification des Optimisations

### 1. Vérifier l'Accélération Hardware

```bash
# Vérifier le codec H264
vcgencmd codec_enabled H264
# Doit retourner: H264=enabled

# Vérifier les devices V4L2
ls -la /dev/video*
# Doit montrer video10-16

# Vérifier dans Chromium (naviguer vers ces URLs)
chrome://gpu       # "Video Decode" doit être "Hardware accelerated"
chrome://media-internals  # Doit montrer "VaapiVideoDecoder"
```

### 2. Monitorer les Performances

```bash
# Pendant la lecture vidéo
htop  # L'utilisation CPU devrait être <40% pour du 1080p

# Vérifier la température
vcgencmd measure_temp
# Devrait rester <70°C
```

## Optimisations Non Appliquées (Trop Risquées)

Les optimisations suivantes du rapport n'ont PAS été appliquées pour maintenir la stabilité :

1. **Overclocking** - Risque de surchauffe sur Pi avec refroidissement passif
2. **Modification hdmi_enable_4kp60** - Laissé optionnel car augmente la consommation
3. **Changement de lecteur (VLC/MPV)** - Chromium reste pour la compatibilité web
4. **Modifications cmdline.txt** - Conformément aux exigences de stabilité

## Résolution des Problèmes

### Vidéo saccadée malgré les optimisations

1. Vérifier `gpu_mem` :
   ```bash
   cat /boot/config.txt | grep gpu_mem
   # Si <128, modifier avec:
   sudo sed -i 's/^gpu_mem=.*/gpu_mem=128/' /boot/config.txt
   sudo reboot
   ```

2. Vérifier la température :
   ```bash
   vcgencmd get_throttled
   # 0x0 = OK, autre = throttling
   ```

3. Pour le 4K, activer manuellement :
   ```bash
   echo "hdmi_enable_4kp60=1" | sudo tee -a /boot/config.txt
   sudo reboot
   ```

### L'accélération ne fonctionne pas

1. Vérifier les logs Chromium :
   ```bash
   sudo journalctl -u chromium-kiosk -f
   ```

2. Tester avec un flag de debug :
   ```bash
   chromium-browser --enable-logging=stderr --v=1 chrome://gpu
   ```

## Performances Attendues

Avec ces optimisations sur Raspberry Pi 4 (2GB RAM) :

| Contenu | Sans Optimisation | Avec Optimisation |
|---------|------------------|-------------------|
| 1080p30 H.264 | 80-100% CPU | 25-35% CPU |
| 1080p60 H.264 | 140%+ CPU (lag) | 35-45% CPU |
| YouTube 1080p | 120%+ CPU | 40-50% CPU |

## Recommandations

1. **Pour du contenu local** : Utiliser des vidéos H.264 1080p30 pour des performances optimales
2. **Pour du streaming** : Limiter à 720p si possible
3. **Écrans 4K** : L'upscaling hardware fonctionne automatiquement avec ces optimisations
4. **Refroidissement** : Un dissipateur passif est suffisant avec ces paramètres prudents

## Références

- [Raspberry Pi Video Documentation](https://www.raspberrypi.com/documentation/computers/config_txt.html#video-options)
- [Chromium Hardware Video Acceleration](https://www.chromium.org/developers/design-documents/video/)
- [V4L2 on Raspberry Pi](https://www.raspberrypi.com/documentation/computers/camera_software.html#v4l2)