#!/bin/bash

echo "=== FORCAGE DU DESKTOP ET VIDEO ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF'
# Start LXDE desktop session
echo "Starting LXDE desktop..."
sudo systemctl restart lightdm

sleep 5

# Alternative: start X session manually
if ! pgrep -x "lxsession" > /dev/null; then
    echo "Starting X session manually..."
    startx &
    sleep 5
fi

# Check what's running
echo ""
echo "=== Current Status ==="
echo "Display managers:"
ps aux | grep -E "(lightdm|lxsession|lxpanel)" | grep -v grep

echo ""
echo "X Server:"
ps aux | grep Xorg | grep -v grep

echo ""
echo "Si vous voyez le bureau LXDE sur la TV,"
echo "double-cliquez sur l'icône du navigateur"
echo "ou appuyez sur Alt+F2 et tapez:"
echo "chromium-browser --kiosk file:///opt/videos/player.html"

EOF