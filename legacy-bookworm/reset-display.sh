#!/bin/bash

echo "=== Réinitialisation de l'affichage Pi Signage ==="

# Arrêter tous les processus chromium
pkill -f chromium
pkill -f chrome
sleep 2

# Relancer chromium en mode kiosk sur le bon display
export DISPLAY=:99
export XAUTHORITY=/home/debiandev/.Xauthority

# URL de test (Google comme page simple)
URL="https://www.google.com"

echo "Lancement de chromium sur DISPLAY=$DISPLAY avec URL=$URL"

# Lancement avec les options GPU activées
chromium \
    --kiosk \
    --incognito \
    --disable-pinch \
    --overscroll-history-navigation=0 \
    --disable-features=TranslateUI \
    --enable-gpu-rasterization \
    --enable-accelerated-2d-canvas \
    --enable-accelerated-video-decode \
    --ignore-gpu-blocklist \
    --disable-gpu-sandbox \
    --use-gl=desktop \
    --enable-features=VaapiVideoDecoder \
    --no-sandbox \
    "$URL" &

echo "Chromium lancé avec PID: $!"
echo ""
echo "Pour vérifier l'affichage:"
echo "  - Connectez-vous en VNC sur le port 5900"
echo "  - Ou vérifiez directement sur l'écran physique"
echo ""
echo "Pour arrêter: pkill -f chromium"