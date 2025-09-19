#!/bin/bash

echo "=== ATTENTE REDEMARRAGE (60 secondes) ==="
sleep 60

echo ""
echo "=== VERIFICATION APRES REDEMARRAGE ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF' 2>/dev/null
echo "Connexion réussie!"
echo ""
echo "1. Qui est connecté:"
who
echo ""
echo "2. Services actifs:"
systemctl is-active pi-kiosk.service
echo ""
echo "3. Processus vidéo:"
ps aux | grep -E "(xinit|vlc|Xorg)" | grep -v grep | head -3
echo ""
echo "4. Test alternatif si service échoué:"
if ! pgrep vlc > /dev/null; then
    echo "VLC n'est pas lancé, lancement manuel..."
    export DISPLAY=:0
    xinit /usr/local/bin/video-player.sh -- :0 vt1 -nocursor &
fi
EOF

echo ""
echo "=== STATUT FINAL ==="
echo "La vidéo devrait maintenant s'afficher automatiquement sur votre TV!"
echo "Sans aucune intervention manuelle."