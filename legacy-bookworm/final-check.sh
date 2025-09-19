#!/bin/bash

echo "=== VERIFICATION FINALE ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF' 2>/dev/null

echo "Processus en cours:"
ps aux | grep -E "(boot-video|mplayer|vlc)" | grep -v grep

echo ""
echo "Service status:"
systemctl status boot-video.service --no-pager | head -10

echo ""
echo "Installation mplayer si absent:"
if ! command -v mplayer &> /dev/null; then
    sudo apt install -y mplayer
fi

echo ""
echo "=== REDEMARRAGE FINAL ==="
echo "Je vais redémarrer pour que tout soit propre."
sudo reboot

EOF

echo ""
echo "Le Pi redémarre..."
echo "Après redémarrage (60 secondes), vous devriez voir:"
echo "- PAS d'écran de login"
echo "- La vidéo qui tourne en boucle directement"