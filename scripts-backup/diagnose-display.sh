#!/bin/bash

echo "=== DIAGNOSTIC DISPLAY PISIGNAGE ==="
echo ""

echo "1. Vérification serveur X:"
if DISPLAY=:0 xset -q > /dev/null 2>&1; then
    echo "✅ Serveur X accessible sur DISPLAY=:0"
else
    echo "❌ Serveur X NON accessible"
    echo "   Tentative de redémarrage LightDM..."
    sudo systemctl restart lightdm
    sleep 5
fi

echo ""
echo "2. Processus graphiques:"
ps aux | grep -E "(Xorg|lightdm|openbox)" | grep -v grep

echo ""
echo "3. Variables d'environnement:"
echo "DISPLAY=$DISPLAY"
echo "USER=$USER"
echo "HOME=$HOME"

echo ""
echo "4. Test création fenêtre simple:"
DISPLAY=:0 xmessage -timeout 2 "Test PiSignage" > /dev/null 2>&1 &
if [ $? -eq 0 ]; then
    echo "✅ Création fenêtre réussie"
else
    echo "❌ Impossible de créer une fenêtre"
fi

echo ""
echo "5. Permissions X11:"
ls -la /tmp/.X11-unix/

echo ""
echo "6. Config GPU:"
vcgencmd get_mem gpu
vcgencmd measure_temp
vcgencmd get_throttled

echo ""
echo "7. Test VLC minimal:"
DISPLAY=:0 timeout 5 vlc --intf dummy --vout x11 /opt/pisignage/media/*.mp4 2>&1 | head -10

echo ""
echo "8. Test MPV minimal:"
DISPLAY=:0 timeout 5 mpv --vo=x11 /opt/pisignage/media/*.mp4 2>&1 | head -10

echo ""
echo "=== FIN DIAGNOSTIC ==="