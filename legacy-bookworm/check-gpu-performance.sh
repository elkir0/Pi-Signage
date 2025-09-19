#!/bin/bash

echo "=== VÉRIFICATION PERFORMANCE GPU ET FPS ==="
echo ""

# Température et throttling
echo "État du système:"
vcgencmd measure_temp
vcgencmd get_throttled | awk '{
    val=strtonum($0); 
    if(val==0) print "Throttling: Aucun";
    else {
        printf "Throttling: ";
        if(and(val,0x1)) printf "Under-voltage ";
        if(and(val,0x2)) printf "Freq-cap ";
        if(and(val,0x4)) printf "Throttled ";
        if(and(val,0x8)) printf "Soft-temp-limit ";
        print "";
    }
}'

# Mémoire GPU
echo ""
echo "Mémoire GPU:"
vcgencmd get_mem gpu
vcgencmd get_mem arm

# Fréquences
echo ""
echo "Fréquences:"
vcgencmd measure_clock arm | awk -F= '{printf "CPU: %.2f GHz\n", $2/1000000000}'
vcgencmd measure_clock core | awk -F= '{printf "GPU: %.0f MHz\n", $2/1000000}'

# Processus Chromium
echo ""
echo "Chromium GPU Status:"
ps aux | grep chromium | grep -E "(gpu-process|--type=gpu)" | head -1
if [ $? -eq 0 ]; then
    echo "✓ Processus GPU actif"
else
    echo "✗ Pas de processus GPU détecté"
fi

# Vérifier les flags GPU
echo ""
echo "Flags GPU activés:"
ps aux | grep chromium | head -1 | grep -o "\-\-enable-[^ ]*gpu[^ ]*" | sort | uniq

# Test de téléchargement vidéo
echo ""
echo "Test vidéo (télécharge 1MB):"
timeout 3 curl -s -o /dev/null -w "Vitesse: %{speed_download} bytes/s\n" \
    -r 0-1048576 \
    https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4

echo ""
echo "=== FPS INFO ==="
echo "Le compteur FPS devrait être visible:"
echo "- En haut à gauche de l'écran (vert sur noir)"
echo "- Chromium FPS counter en haut à droite (si --show-fps-counter actif)"
echo ""
echo "La vidéo Big Buck Bunny 720p tourne en boucle"
echo "Format: H.264, 720p, 10 secondes, 30MB"