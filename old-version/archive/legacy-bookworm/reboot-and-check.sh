#!/bin/bash

echo "=== REDEMARRAGE DU RASPBERRY PI ==="
echo "Le Pi va redémarrer..."

# Reboot the Pi
sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 "sudo reboot" 2>/dev/null

echo "Attente du redémarrage... (60 secondes)"
sleep 60

echo ""
echo "=== VERIFICATION APRES REDEMARRAGE ==="

# Check if Pi is back online and autologin worked
sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF' 2>/dev/null
echo "Pi is back online!"
echo ""
echo "Checking autologin status:"
who
echo ""
echo "Checking if GUI is running:"
ps aux | grep -E "(Xorg|lightdm)" | grep -v grep | head -2
echo ""
echo "Checking if video is playing:"
ps aux | grep chromium | grep -v grep | head -1
echo ""
echo "Current display:"
echo $DISPLAY
EOF

echo ""
echo "=== STATUT ==="
echo "Si l'autologin fonctionne, vous devriez voir:"
echo "- L'utilisateur 'pi' connecté sur tty7"  
echo "- Xorg en cours d'exécution"
echo "- La vidéo devrait être visible sur la TV!"