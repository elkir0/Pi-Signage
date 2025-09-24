#!/bin/bash
# PiSignage - Setup autostart on Raspberry Pi

echo "📺 Configuration du démarrage automatique de VLC..."

# Create autostart directory
mkdir -p /home/pi/.config/autostart

# Create desktop entry for VLC
cat > /home/pi/.config/autostart/pisignage.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=PiSignage VLC Player
Exec=/opt/pisignage/scripts/autostart-vlc.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Create the autostart script
cat > /opt/pisignage/scripts/autostart-vlc.sh << 'EOF'
#!/bin/bash
# PiSignage - Autostart VLC on boot

# Wait for system to be ready
sleep 5

# Log startup
echo "$(date): Starting PiSignage VLC..." >> /opt/pisignage/logs/autostart.log

# Kill any existing MPV/VLC
pkill -f mpv 2>/dev/null
pkill -f vlc 2>/dev/null
sleep 2

# Start MPV in fullscreen
mpv --fullscreen \
    --loop-playlist=inf \
    --really-quiet \
    /opt/pisignage/media/*.mp4 \
    >> /opt/pisignage/logs/mpv.log 2>&1 &

echo "$(date): MPV started with PID $!" >> /opt/pisignage/logs/autostart.log
EOF

# Make script executable
chmod +x /opt/pisignage/scripts/autostart-vlc.sh

# Also add to bashrc for console login
echo "" >> /home/pi/.bashrc
echo "# PiSignage autostart" >> /home/pi/.bashrc
echo "if [ -z \"\$SSH_CLIENT\" ] && [ -z \"\$SSH_TTY\" ]; then" >> /home/pi/.bashrc
echo "    /opt/pisignage/scripts/autostart-vlc.sh &" >> /home/pi/.bashrc
echo "fi" >> /home/pi/.bashrc

# Create systemd user service
mkdir -p /home/pi/.config/systemd/user/

cat > /home/pi/.config/systemd/user/pisignage.service << 'EOF'
[Unit]
Description=PiSignage VLC Player
After=graphical-session.target

[Service]
Type=simple
ExecStart=/opt/pisignage/scripts/autostart-vlc.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Enable user service
systemctl --user daemon-reload
systemctl --user enable pisignage.service

echo "✅ Configuration terminée!"
echo ""
echo "VLC démarrera automatiquement au prochain boot via:"
echo "  1. ~/.config/autostart/pisignage.desktop (GUI)"
echo "  2. ~/.bashrc (console)"
echo "  3. systemd user service"