#!/bin/bash

# Solution simple qui fonctionne après redémarrage
cat > /home/pi/start-video.sh << 'EOF'
#!/bin/bash

# Attendre que X soit prêt
sleep 5

# Désactiver l'écran de veille
export DISPLAY=:0
xset s off
xset -dpms
xset s noblank

# Lancer Chromium SANS GPU (software mais au moins ça marche)
chromium-browser \
    --kiosk \
    --disable-gpu \
    --disable-software-rasterizer \
    --disable-dev-shm-usage \
    --no-sandbox \
    --disable-infobars \
    --autoplay-policy=no-user-gesture-required \
    file:///home/pi/video-test.html
EOF

chmod +x /home/pi/start-video.sh

# Configurer l'autostart
sed -i 's|/home/pi/kiosk.*\.sh|/home/pi/start-video.sh|g' /home/pi/.bashrc
sed -i 's|Exec=.*|Exec=/home/pi/start-video.sh|' /home/pi/.config/autostart/kiosk.desktop

echo "Solution simple installée. Redémarrage..."
sudo reboot