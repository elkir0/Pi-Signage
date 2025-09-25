#!/bin/bash
# PiSignage - Configuration complète du système d'affichage
# Configure l'environnement graphique et le lancement automatique

echo "=== Configuration PiSignage Display System ==="

# 1. Installer les paquets nécessaires
echo "Installation des paquets graphiques..."
sudo apt-get update
sudo apt-get install -y \
    xserver-xorg \
    xinit \
    x11-xserver-utils \
    lightdm \
    openbox \
    unclutter

# 2. Configurer l'auto-login graphique
echo "Configuration auto-login..."
sudo mkdir -p /etc/lightdm/lightdm.conf.d
cat <<EOF | sudo tee /etc/lightdm/lightdm.conf.d/60-pisignage.conf
[SeatDefaults]
autologin-user=pi
autologin-user-timeout=0
xserver-command=X -nocursor
EOF

# 3. Créer le script de démarrage pour openbox
echo "Configuration openbox..."
mkdir -p /home/pi/.config/openbox
cat <<'EOF' | tee /home/pi/.config/openbox/autostart
# Désactiver l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Masquer le curseur après 1 seconde
unclutter -idle 1 &

# Attendre que le réseau soit prêt
sleep 5

# Lancer le player configuré (MPV ou VLC)
PLAYER=$(jq -r '.player.current' /opt/pisignage/config/player-config.json 2>/dev/null || echo "vlc")

if [ "$PLAYER" = "mpv" ]; then
    # Lancer MPV
    mpv --fullscreen \
        --loop-playlist=inf \
        --no-osc \
        --no-input-default-bindings \
        --hwdec=auto \
        --vo=x11 \
        /opt/pisignage/media/*.{mp4,mkv,avi,mov} &
else
    # Lancer VLC
    cvlc --fullscreen \
         --loop \
         --no-video-title-show \
         --intf dummy \
         /opt/pisignage/media/*.{mp4,mkv,avi,mov} &
fi
EOF

chmod +x /home/pi/.config/openbox/autostart

# 4. Créer un service systemd pour PiSignage
echo "Création du service systemd..."
cat <<EOF | sudo tee /etc/systemd/system/pisignage-display.service
[Unit]
Description=PiSignage Display Service
After=graphical.target

[Service]
Type=simple
User=pi
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/home/pi/.Xauthority"
ExecStart=/opt/pisignage/scripts/player-manager.sh start
Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

# 5. Activer les services
echo "Activation des services..."
sudo systemctl daemon-reload
sudo systemctl enable lightdm
sudo systemctl enable pisignage-display
sudo systemctl set-default graphical.target

# 6. Optimisations Raspberry Pi
echo "Application des optimisations..."
# Désactiver le bluetooth pour économiser les ressources
sudo systemctl disable bluetooth
sudo systemctl disable hciuart

# Augmenter la mémoire GPU si nécessaire
if ! grep -q "gpu_mem" /boot/config.txt; then
    echo "gpu_mem=128" | sudo tee -a /boot/config.txt
fi

# 7. Créer un script de test
cat <<'EOF' | tee /opt/pisignage/scripts/test-display.sh
#!/bin/bash
echo "Test du système d'affichage PiSignage..."

# Vérifier X11
if pgrep X > /dev/null; then
    echo "✓ X11 est en cours d'exécution"
else
    echo "✗ X11 n'est pas en cours d'exécution"
fi

# Vérifier le player
if pgrep -f "mpv|vlc" > /dev/null; then
    echo "✓ Le player vidéo est actif"
    pgrep -a -f "mpv|vlc" | head -1
else
    echo "✗ Aucun player vidéo actif"
fi

# Afficher le display
echo "DISPLAY=$DISPLAY"

# Tester une capture d'écran
if command -v import &> /dev/null; then
    DISPLAY=:0 import -window root /tmp/test-screenshot.png 2>/dev/null
    if [ -f /tmp/test-screenshot.png ]; then
        echo "✓ Capture d'écran réussie"
        ls -lh /tmp/test-screenshot.png
    else
        echo "✗ Échec de la capture d'écran"
    fi
fi
EOF

chmod +x /opt/pisignage/scripts/test-display.sh

echo ""
echo "=== Configuration terminée ==="
echo ""
echo "Actions effectuées:"
echo "✓ Paquets graphiques installés"
echo "✓ Auto-login configuré pour l'utilisateur pi"
echo "✓ Openbox configuré avec lancement automatique du player"
echo "✓ Service systemd pisignage-display créé"
echo "✓ Optimisations Raspberry Pi appliquées"
echo ""
echo "Pour démarrer le système maintenant:"
echo "  sudo systemctl start lightdm"
echo ""
echo "Pour redémarrer et appliquer tous les changements:"
echo "  sudo reboot"
echo ""
echo "Pour tester le système:"
echo "  /opt/pisignage/scripts/test-display.sh"