#!/bin/bash

# PiSignage - Script d'installation propre
# Pour Raspberry Pi 4 avec Raspberry Pi OS
# Version sans overclocking, gpu_mem modérée

set -e

echo "╔══════════════════════════════════════════╗"
echo "║     PiSignage v0.8.0 - Installation      ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Vérifier qu'on est sur Raspberry Pi
if [ ! -f /proc/device-tree/model ]; then
    echo "❌ Ce script est conçu pour Raspberry Pi"
    exit 1
fi

echo "📍 Modèle détecté: $(cat /proc/device-tree/model)"
echo ""

# 1. Mise à jour système
echo "📦 1/8 - Mise à jour du système..."
sudo apt-get update
sudo apt-get upgrade -y

# 2. Installation des dépendances de base
echo "🔧 2/8 - Installation des dépendances..."
sudo apt-get install -y \
    nginx \
    php8.2-fpm php8.2-cli php8.2-curl php8.2-mbstring \
    vlc \
    xorg openbox lightdm \
    feh imagemagick \
    git curl wget \
    unclutter \
    scrot

# 3. Configuration GPU (modérée, sans overclocking)
echo "🎮 3/8 - Configuration GPU..."
if ! grep -q "^gpu_mem=" /boot/config.txt; then
    echo "" | sudo tee -a /boot/config.txt
    echo "# PiSignage GPU Configuration" | sudo tee -a /boot/config.txt
    echo "gpu_mem=128" | sudo tee -a /boot/config.txt
    echo "dtoverlay=vc4-fkms-v3d" | sudo tee -a /boot/config.txt
    echo "✅ GPU configuré avec 128MB (pas d'overclocking)"
else
    echo "⚠️  Configuration GPU déjà présente"
fi

# 4. Création structure PiSignage
echo "📁 4/8 - Création structure PiSignage..."
sudo mkdir -p /opt/pisignage/{web,scripts,media,logs,config,screenshots}
sudo chown -R $USER:$USER /opt/pisignage
sudo chmod -R 755 /opt/pisignage

# 5. Téléchargement depuis GitHub
echo "⬇️  5/8 - Récupération du code depuis GitHub..."
cd /tmp
if [ -d Pi-Signage ]; then
    rm -rf Pi-Signage
fi
git clone https://github.com/elkir0/Pi-Signage.git
cp -r Pi-Signage/* /opt/pisignage/
rm -rf Pi-Signage

# 6. Configuration Nginx
echo "🌐 6/8 - Configuration Nginx..."
sudo tee /etc/nginx/sites-available/pisignage > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php index.html;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex on;
    }

    location /screenshots {
        alias /opt/pisignage/screenshots;
        autoindex on;
    }
}
EOF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# 7. Configuration autologin et autostart
echo "🚀 7/8 - Configuration démarrage automatique..."

# LightDM autologin
sudo tee /etc/lightdm/lightdm.conf > /dev/null << 'EOF'
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
user-session=openbox
EOF

# OpenBox autostart pour utilisateur pi
sudo -u pi mkdir -p /home/pi/.config/openbox
sudo -u pi tee /home/pi/.config/openbox/autostart > /dev/null << 'EOF'
# Désactiver économiseur écran
xset s off
xset -dpms
xset s noblank

# Cacher curseur
unclutter -idle 1 -root &

# Attendre stabilisation
sleep 10

# Lancer VLC simple
if [ -f /opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4 ]; then
    cvlc --intf dummy --fullscreen --loop /opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4 &
else
    feh --fullscreen --hide-pointer /opt/pisignage/media/fallback-logo.jpg &
fi
EOF

# 8. Script VLC simple et stable
echo "📺 8/8 - Création script VLC..."
cat > /opt/pisignage/scripts/start-vlc-stable.sh << 'EOF'
#!/bin/bash

# Script VLC minimal et stable
VIDEO="/opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4"

# Arrêt propre
pkill -f vlc 2>/dev/null
sleep 2

if [ -f "$VIDEO" ]; then
    # Options VLC minimales pour stabilité
    # Pas d'accélération hardware problématique
    # Pas d'options complexes
    DISPLAY=:0 cvlc \
        --intf dummy \
        --fullscreen \
        --loop \
        --no-video-title-show \
        "$VIDEO" &

    echo "VLC lancé avec configuration stable"
else
    echo "Vidéo non trouvée: $VIDEO"
fi
EOF

chmod +x /opt/pisignage/scripts/start-vlc-stable.sh

# Télécharger vidéo de test si nécessaire
if [ ! -f /opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4 ]; then
    echo "📥 Téléchargement vidéo de test..."
    wget -q "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" \
         -O /opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4
fi

# Permissions finales
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R www-data:www-data /opt/pisignage/logs
sudo chown -R www-data:www-data /opt/pisignage/screenshots
sudo chown -R pi:pi /opt/pisignage/media
sudo chown -R pi:pi /opt/pisignage/scripts

echo ""
echo "✅ Installation terminée!"
echo ""
echo "📊 Configuration appliquée:"
echo "   - GPU: 128MB (pas d'overclocking)"
echo "   - VLC: configuration minimale stable"
echo "   - Autologin: utilisateur pi"
echo "   - Interface: http://$(hostname -I | cut -d' ' -f1)"
echo ""
echo "⚠️  Redémarrage nécessaire: sudo reboot"
echo ""
echo "Après redémarrage:"
echo "   1. VLC démarrera automatiquement"
echo "   2. Interface web accessible"
echo "   3. APIs fonctionnelles"