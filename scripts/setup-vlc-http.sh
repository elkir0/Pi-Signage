#!/bin/bash
###############################################################################
# PiSignage - Setup VLC HTTP Interface
# NOTE: This script is deprecated. HTTP interface is now integrated
# into the main pisignage-vlc.service. Use systemctl to manage VLC.
###############################################################################

echo "⚠️  NOTICE: VLC HTTP interface is now integrated into pisignage-vlc.service"
echo "   No separate vlc-http service is needed."
echo ""
echo "Current VLC service status:"
systemctl status pisignage-vlc.service --no-pager -l
echo ""
echo "To restart VLC with HTTP interface:"
echo "  sudo systemctl restart pisignage-vlc"
echo ""
echo "HTTP interface will be available at: http://localhost:8080"
echo "Password: pisignage"
echo ""
exit 0

# Legacy configuration below (not executed)
echo "Configuring VLC HTTP interface..."

# Create VLC config directory
mkdir -p ~/.config/vlc

# Create VLC configuration with HTTP interface
cat > ~/.config/vlc/vlcrc << 'EOF'
# VLC Configuration for PiSignage
[core]
# Interface
intf=http
extraintf=http,dummy

# HTTP Interface
http-host=0.0.0.0
http-port=8080
http-password=pisignage

# Video Output (Raspberry Pi optimized)
vout=xcb_x11

# Audio Output
aout=alsa

# Performance
file-caching=2000
network-caching=1000
live-caching=1000

# Playlist
playlist-autostart=1
random=0
loop=0
repeat=0

# OSD
osd=1
video-title-show=0
video-title-timeout=0

# Fullscreen
fullscreen=1
video-on-top=1

[http]
# HTTP Interface settings
http-password=pisignage

[rc]
# Remote control interface
rc-host=localhost:4212

EOF

# Create systemd service for VLC with HTTP interface
sudo tee /etc/systemd/system/vlc-http.service > /dev/null << 'EOF'
[Unit]
Description=VLC Media Player with HTTP Interface
After=network.target display-manager.service

[Service]
Type=simple
User=pi
Group=video
Environment="DISPLAY=:0"
Environment="HOME=/home/pi"

# Start VLC with HTTP interface
ExecStart=/usr/bin/vlc \
    --intf http \
    --extraintf dummy \
    --http-host 0.0.0.0 \
    --http-port 8080 \
    --http-password pisignage \
    --fullscreen \
    --no-video-title-show \
    --loop \
    --playlist-autostart \
    /opt/pisignage/media/

ExecStop=/usr/bin/killall vlc
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable vlc-http.service

echo "VLC HTTP interface configured!"
echo "Access at: http://localhost:8080"
echo "Password: pisignage"
echo ""
echo "To start VLC with HTTP interface:"
echo "  sudo systemctl start vlc-http"
echo ""
echo "To test HTTP interface:"
echo "  curl -u :pisignage http://localhost:8080/requests/status.json"