#!/bin/bash
echo "=== Solution optimale pour Pi 4 avec bon framerate ==="

# Pour Raspberry Pi 4, la meilleure solution est d'utiliser VLC-nox sans X11
# ou d'utiliser le mode Lite de Raspberry Pi OS avec framebuffer direct

# Option 1 : VLC sans X (meilleure performance)
sudo apt-get install -y vlc-nox
cvlc --intf dummy --fullscreen --loop --vout fb /opt/pisignage/videos/test_video.mp4

# Option 2 : Utiliser Raspberry Pi OS Lite (sans desktop) avec kms
# Ajouter dans /boot/firmware/config.txt :
# dtoverlay=vc4-kms-v3d
# max_framebuffers=2

# Option 3 : Utiliser l'image officielle piSignage
# https://pisignage.com/players/pisignage-images

echo "Le problème actuel :"
echo "- X11 + Chromium = pas d'accélération GPU correcte"
echo "- VLC + X11 = performances moyennes"
echo "- ffplay = utilise trop de CPU"
echo ""
echo "Solution recommandée :"
echo "1. Utiliser Raspberry Pi OS Lite (sans desktop)"
echo "2. Installer vlc-nox"
echo "3. Lancer VLC directement sur framebuffer"
echo "OU"
echo "Télécharger l'image piSignage officielle qui est déjà optimisée"
