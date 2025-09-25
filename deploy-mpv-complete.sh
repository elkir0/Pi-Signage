#!/bin/bash
# Deploy complete MPV configuration to production Raspberry Pi

PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "🚀 Déploiement complet MPV sur Raspberry Pi..."
echo "============================================="

# 1. Copy all updated files
echo "📤 [1/6] Copie des fichiers..."

# Scripts
sshpass -p "$PI_PASS" scp /opt/pisignage/scripts/mpv-*.{sh,py} $PI_USER@$PI_IP:/tmp/
sshpass -p "$PI_PASS" scp /opt/pisignage/scripts/download-bbb-720p.sh $PI_USER@$PI_IP:/tmp/

# Web files
sshpass -p "$PI_PASS" scp /opt/pisignage/web/index.php $PI_USER@$PI_IP:/tmp/
sshpass -p "$PI_PASS" scp /opt/pisignage/web/api/player.php $PI_USER@$PI_IP:/tmp/

# Installation script
sshpass -p "$PI_PASS" scp /opt/pisignage/install.sh $PI_USER@$PI_IP:/tmp/

# 2. Move files to correct locations
echo "📂 [2/6] Installation des fichiers..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
sudo mv /tmp/mpv-*.{sh,py} /opt/pisignage/scripts/
sudo mv /tmp/download-bbb-720p.sh /opt/pisignage/scripts/
sudo mv /tmp/index.php /opt/pisignage/web/
sudo mv /tmp/player.php /opt/pisignage/web/api/
sudo mv /tmp/install.sh /opt/pisignage/

# Permissions
sudo chown www-data:www-data /opt/pisignage/scripts/*.{sh,py}
sudo chmod +x /opt/pisignage/scripts/*.{sh,py}
sudo chown www-data:www-data /opt/pisignage/web -R
sudo chmod +x /opt/pisignage/install.sh
EOF

# 3. Install MPV if not installed
echo "📦 [3/6] Installation MPV et dépendances..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
if ! command -v mpv &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y mpv socat python3
fi
EOF

# 4. Create MPV config directory
echo "⚙️ [4/6] Configuration MPV..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
mkdir -p /home/pi/.config/mpv
mkdir -p /opt/pisignage/{logs,playlists}
sudo chown -R pi:pi /home/pi/.config/mpv
sudo chown -R www-data:www-data /opt/pisignage/{logs,playlists}

# Run setup to create optimized config
sudo -u pi /opt/pisignage/scripts/mpv-optimized.sh setup
EOF

# 5. Download Big Buck Bunny 720p if needed
echo "📥 [5/6] Téléchargement vidéo test 720p..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
if [ ! -f "/opt/pisignage/media/BigBuckBunny_720p.mp4" ]; then
    echo "Téléchargement Big Buck Bunny 1080p (340MB)..."
    cd /opt/pisignage/media
    sudo wget -q --show-progress -O BigBuckBunny_720p.mp4 \
        "http://distribution.bbb3d.renderfarming.net/video/mp4/bbb_sunflower_1080p_60fps_normal.mp4"
    sudo chown www-data:www-data BigBuckBunny_720p.mp4
else
    echo "Vidéo test déjà présente"
fi

# Remove old 320p version
sudo rm -f /opt/pisignage/media/BigBuckBunny.mp4
EOF

# 6. Update systemd service
echo "🔧 [6/6] Configuration service systemd..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
# Stop old VLC service if exists
sudo systemctl stop pisignage-vlc 2>/dev/null || true
sudo systemctl disable pisignage-vlc 2>/dev/null || true
sudo rm -f /etc/systemd/system/pisignage-vlc.service

# Create new MPV service
sudo tee /etc/systemd/system/pisignage-mpv.service > /dev/null << 'SERVICE'
[Unit]
Description=PiSignage MPV Player
After=graphical.target

[Service]
Type=simple
User=pi
Environment="DISPLAY=:0"
Environment="HOME=/home/pi"
ExecStartPre=/bin/sleep 5
ExecStart=/opt/pisignage/scripts/mpv-optimized.sh start
ExecStop=/opt/pisignage/scripts/mpv-optimized.sh stop
ExecStopPost=/opt/pisignage/scripts/mpv-optimized.sh fallback
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SERVICE

# Reload and enable
sudo systemctl daemon-reload
sudo systemctl enable pisignage-mpv

# Restart services
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm
EOF

echo ""
echo "✅ Déploiement terminé!"
echo ""
echo "🎬 Démarrage de MPV..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP "sudo systemctl start pisignage-mpv"

sleep 3

echo ""
echo "📊 Statut:"
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP "sudo systemctl status pisignage-mpv | head -10"

echo ""
echo "🌐 Interface web : http://$PI_IP/"
echo "📝 Logs : sudo journalctl -u pisignage-mpv -f"
echo "🎮 Contrôle : python3 /opt/pisignage/scripts/mpv-controller.py status"