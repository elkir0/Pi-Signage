#!/bin/bash

echo "=== REDEMARRAGE FINAL ET VERIFICATION ==="
echo ""

# Reboot
echo "Redémarrage du Raspberry Pi..."
sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 "sudo reboot" 2>/dev/null

echo "Attente 60 secondes pour le redémarrage..."
sleep 60

echo ""
echo "=== VERIFICATION POST-REBOOT ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF' 2>/dev/null
echo "Connexion réussie!"
echo ""
echo "1. Sessions actives:"
who

echo ""
echo "2. Processus graphiques:"
ps aux | grep -E "(Xorg|lightdm|lxsession)" | grep -v grep | head -3

echo ""  
echo "3. Chromium/Video:"
ps aux | grep chromium | grep -v grep | head -1

echo ""
echo "4. Services actifs:"
systemctl is-active lightdm
systemctl is-active graphical.target

echo ""
echo "=== STATUT FINAL ==="
if ps aux | grep chromium | grep -v grep > /dev/null; then
    echo "✅ SUCCES: La vidéo est en cours de lecture!"
else
    echo "⚠️  La vidéo n'est pas lancée automatiquement."
    echo "    Connectez-vous manuellement sur la TV:"
    echo "    Username: pi"
    echo "    Password: palmer00"
fi
EOF

echo ""
echo "==================================="
echo "VERIFIEZ VOTRE TV MAINTENANT!"
echo "==================================="
echo ""
echo "Vous devriez voir:"
echo "- Soit la vidéo Big Buck Bunny en lecture"
echo "- Soit le bureau LXDE (fond d'écran)"
echo "- Soit encore l'écran de login"
echo ""
echo "Dites-moi ce que vous voyez!"