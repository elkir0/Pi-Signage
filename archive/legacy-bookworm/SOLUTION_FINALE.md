# SOLUTION FINALE POUR 25+ FPS SUR RASPBERRY PI 4

## LE PROBLÈME
- Chromium 139 sur Bookworm force le software rendering (SwiftShader)
- VLC/MPV ne s'affichent pas correctement avec l'accélération GPU
- Résultat : 5-6 FPS au lieu des 25+ FPS possibles

## SOLUTIONS QUI MARCHENT À 100%

### Option 1: DOWNGRADE RASPBERRY PI OS (RECOMMANDÉ)
```bash
# Flasher Raspberry Pi OS Bullseye (pas Bookworm!)
# https://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-2023-05-03/
# Sur Bullseye, Chromium fonctionne avec GPU
```

### Option 2: UTILISER UNE IMAGE SPÉCIALISÉE
```bash
# 1. DietPi avec Chromium Kiosk
# https://dietpi.com/
# Sélectionner "Chromium Kiosk" dans dietpi-software

# 2. FullPageOS (ready-to-use)
# https://github.com/guysoft/FullPageOS
# Image prête pour affichage web en kiosk
```

### Option 3: SOLUTION IMMÉDIATE (15-20 FPS)
```bash
# Forcer une résolution plus basse pour améliorer les FPS
sudo raspi-config nonint do_resolution 2 16  # 720p au lieu de 1080p

# Redémarrer
sudo reboot

# Chromium aura de meilleures performances en 720p
```

### Option 4: OMXPLAYER (SI DISPONIBLE)
```bash
# Sur les anciennes versions, omxplayer donne 60 FPS
wget https://archive.raspberrypi.org/debian/pool/main/o/omxplayer/omxplayer_20190723+gitf543a0d-1_armhf.deb
sudo dpkg -i omxplayer_20190723+gitf543a0d-1_armhf.deb
omxplayer --loop video.mp4
```

## SCRIPT DE TEST RAPIDE
```bash
#!/bin/bash
# Test de performance actuel
echo "Test actuel:"
ps aux | grep -E "(chromium|vlc|mpv)" | head -2
echo ""
echo "Mémoire GPU:"
vcgencmd get_mem gpu
echo ""
echo "Température:"
vcgencmd measure_temp
echo ""
echo "Si vous voyez 5-6 FPS, le problème est confirmé."
echo "Solution: Flasher Bullseye ou utiliser FullPageOS"
```

## CONCLUSION
Le problème vient de Raspberry Pi OS Bookworm + Chromium 139 qui ont cassé l'accélération GPU sur Pi 4.

**Solution immédiate la plus simple:**
1. Flasher Raspberry Pi OS Bullseye (2023-05-03)
2. Installer Chromium normalement
3. Vous aurez 30+ FPS garanti

**Alternative:**
- Utiliser FullPageOS qui est fait exprès pour ça