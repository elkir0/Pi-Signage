#!/bin/bash
# Deploy complete dual-player (VLC/MPV) configuration to production Raspberry Pi

PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "🚀 Déploiement complet dual-player VLC/MPV sur Raspberry Pi..."
echo "============================================================"

# 1. Copy all updated files
echo "📤 [1/7] Copie des fichiers dual-player..."

# Configuration
sshpass -p "$PI_PASS" scp /opt/pisignage/config/player-config.json $PI_USER@$PI_IP:/tmp/

# Scripts
sshpass -p "$PI_PASS" scp /opt/pisignage/scripts/player-manager.sh $PI_USER@$PI_IP:/tmp/
sshpass -p "$PI_PASS" scp /opt/pisignage/scripts/unified-player-control.sh $PI_USER@$PI_IP:/tmp/

# Web files
sshpass -p "$PI_PASS" scp /opt/pisignage/web/index.php $PI_USER@$PI_IP:/tmp/
sshpass -p "$PI_PASS" scp /opt/pisignage/web/functions.js $PI_USER@$PI_IP:/tmp/
sshpass -p "$PI_PASS" scp /opt/pisignage/web/api/player.php $PI_USER@$PI_IP:/tmp/

# Installation script
sshpass -p "$PI_PASS" scp /opt/pisignage/install.sh $PI_USER@$PI_IP:/tmp/

# 2. Move files to correct locations
echo "📂 [2/7] Installation des fichiers..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
# Create directories
sudo mkdir -p /opt/pisignage/{config,scripts,web/api}

# Move files
sudo mv /tmp/player-config.json /opt/pisignage/config/
sudo mv /tmp/player-manager.sh /opt/pisignage/scripts/
sudo mv /tmp/unified-player-control.sh /opt/pisignage/scripts/
sudo mv /tmp/index.php /opt/pisignage/web/
sudo mv /tmp/functions.js /opt/pisignage/web/
sudo mv /tmp/player.php /opt/pisignage/web/api/
sudo mv /tmp/install.sh /opt/pisignage/

# Permissions
sudo chown www-data:www-data /opt/pisignage/scripts/*.sh
sudo chmod +x /opt/pisignage/scripts/*.sh
sudo chown www-data:www-data /opt/pisignage/web -R
sudo chown www-data:www-data /opt/pisignage/config -R
sudo chmod +x /opt/pisignage/install.sh
EOF

# 3. Install VLC and MPV if not installed
echo "📦 [3/7] Installation VLC, MPV et dépendances..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
sudo apt-get update
sudo apt-get install -y vlc mpv socat jq python3
EOF

# 4. Setup player configurations
echo "⚙️ [4/7] Configuration des players..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
mkdir -p /home/pi/.config/{mpv,vlc}
mkdir -p /opt/pisignage/{logs,playlists}
sudo chown -R pi:pi /home/pi/.config
sudo chown -R www-data:www-data /opt/pisignage/{logs,playlists}

# Run setup to create optimized configs for both players
sudo -u pi /opt/pisignage/scripts/player-manager.sh setup

# Test configuration files
echo "Testing configurations..."
ls -la /home/pi/.config/mpv/mpv.conf
ls -la /home/pi/.config/vlc/vlcrc
EOF

# 5. Update systemd service
echo "🔧 [5/7] Configuration service systemd..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
# Stop and remove old services
sudo systemctl stop pisignage-mpv 2>/dev/null || true
sudo systemctl stop pisignage-vlc 2>/dev/null || true
sudo systemctl disable pisignage-mpv 2>/dev/null || true
sudo systemctl disable pisignage-vlc 2>/dev/null || true
sudo rm -f /etc/systemd/system/pisignage-mpv.service
sudo rm -f /etc/systemd/system/pisignage-vlc.service

# Create new unified service
sudo tee /etc/systemd/system/pisignage-player.service > /dev/null << 'SERVICE'
[Unit]
Description=PiSignage Unified Player (VLC/MPV)
After=graphical.target

[Service]
Type=simple
User=pi
Environment="DISPLAY=:0"
Environment="HOME=/home/pi"
ExecStartPre=/bin/sleep 5
ExecStart=/opt/pisignage/scripts/player-manager.sh start
ExecStop=/opt/pisignage/scripts/player-manager.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SERVICE

# Reload and enable
sudo systemctl daemon-reload
sudo systemctl enable pisignage-player

# Restart web services
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm
EOF

# 6. Download Big Buck Bunny 720p if needed
echo "📥 [6/7] Vérification vidéo test 720p..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
if [ ! -f "/opt/pisignage/media/BigBuckBunny_720p.mp4" ]; then
    echo "Téléchargement Big Buck Bunny 720p (340MB)..."
    cd /opt/pisignage/media
    sudo wget -q --show-progress -O BigBuckBunny_720p.mp4 \
        "http://distribution.bbb3d.renderfarming.net/video/mp4/bbb_sunflower_1080p_60fps_normal.mp4"
    sudo chown www-data:www-data BigBuckBunny_720p.mp4
else
    echo "✅ Vidéo test 720p déjà présente"
fi

# Remove old 320p version
sudo rm -f /opt/pisignage/media/BigBuckBunny.mp4
EOF

# 7. Start unified player service
echo "🎬 [7/7] Démarrage du service dual-player..."
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP << 'EOF'
# Test current player configuration
echo "Current player configuration:"
cat /opt/pisignage/config/player-config.json | jq '.player'

# Start the unified player service
sudo systemctl start pisignage-player
EOF

sleep 3

echo ""
echo "✅ Déploiement dual-player terminé!"
echo ""
echo "📊 Statut du service:"
sshpass -p "$PI_PASS" ssh $PI_USER@$PI_IP "sudo systemctl status pisignage-player --no-pager | head -15"

echo ""
echo "🎛️  Tests disponibles:"
echo "   • Interface web : http://$PI_IP/"
echo "   • Player actuel : ssh pi@$PI_IP '/opt/pisignage/scripts/player-manager.sh info'"
echo "   • Basculer VLC↔MPV : ssh pi@$PI_IP '/opt/pisignage/scripts/player-manager.sh switch'"
echo "   • Contrôle unifié : ssh pi@$PI_IP '/opt/pisignage/scripts/unified-player-control.sh status'"
echo ""
echo "📝 Logs : sudo journalctl -u pisignage-player -f"