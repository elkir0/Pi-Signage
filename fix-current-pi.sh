#!/bin/bash

# Script pour réparer le Pi actuel sans réinstallation complète

echo "🔧 Réparation PiSignage sur Pi actuel"
echo ""

# 1. Arrêter tous les processus vidéo
echo "1. Arrêt des processus..."
pkill -f vlc
pkill -f mpv
pkill -f feh
sleep 2

# 2. Corriger la configuration GPU (retour aux valeurs sûres)
echo "2. Configuration GPU sûre..."
sudo sed -i '/^gpu_mem=/d' /boot/config.txt
sudo sed -i '/^gpu_freq=/d' /boot/config.txt
sudo sed -i '/^over_voltage=/d' /boot/config.txt
sudo sed -i '/^arm_freq=/d' /boot/config.txt
sudo sed -i '/^dtoverlay=vc4-kms-v3d/d' /boot/config.txt

# Ajouter config sûre
cat << EOF | sudo tee -a /boot/config.txt

# Configuration GPU sûre (sans overclocking)
gpu_mem=128
dtoverlay=vc4-fkms-v3d
EOF

# 3. Installer VLC si manquant
echo "3. Vérification VLC..."
if ! command -v vlc &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y vlc
fi

# 4. Créer script VLC ultra simple
echo "4. Création script VLC minimal..."
cat > /opt/pisignage/scripts/vlc-minimal.sh << 'EOF'
#!/bin/bash

# VLC le plus simple possible
VIDEO="/opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4"

# Tuer ancien
pkill -f vlc
sleep 2

# Lancer sans aucune option complexe
if [ -f "$VIDEO" ]; then
    DISPLAY=:0 cvlc --intf dummy --fullscreen --loop "$VIDEO" &
    echo "VLC lancé (minimal)"
else
    echo "Pas de vidéo"
fi
EOF

chmod +x /opt/pisignage/scripts/vlc-minimal.sh

# 5. Configurer autostart simple pour l'utilisateur pi
echo "5. Configuration autostart..."
sudo -u pi mkdir -p /home/pi/.config/openbox
cat > /tmp/autostart << 'EOF'
# Configuration minimale
xset s off -dpms
unclutter -idle 1 &
sleep 5
/opt/pisignage/scripts/vlc-minimal.sh &
EOF

sudo cp /tmp/autostart /home/pi/.config/openbox/autostart
sudo chown pi:pi /home/pi/.config/openbox/autostart

# 6. Réparer les services web
echo "6. Réparation services web..."
if [ -f /opt/pisignage/scripts/fix-web-services.sh ]; then
    sudo /opt/pisignage/scripts/fix-web-services.sh
fi

echo ""
echo "✅ Réparation terminée"
echo ""
echo "Configuration appliquée:"
echo "- GPU: 128MB (sans overclocking)"
echo "- Driver: FKMS (compatible)"
echo "- VLC: configuration minimale"
echo ""
echo "⚠️  IMPORTANT: Redémarrage nécessaire"
echo "   sudo reboot"
echo ""
echo "Si ça ne fonctionne toujours pas après reboot:"
echo "   wget -O- https://raw.githubusercontent.com/elkir0/Pi-Signage/main/deploy-fresh.sh | bash"