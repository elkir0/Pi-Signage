#!/bin/bash

# Script de démarrage automatique PiSignage
# Corrige tous les problèmes identifiés

LOG="/opt/pisignage/logs/autostart.log"
VIDEO="/opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4"

echo "$(date) - Démarrage PiSignage" > "$LOG"

# Attendre que X soit prêt
sleep 10

# Vérifier que X est accessible
if ! DISPLAY=:0 xset -q > /dev/null 2>&1; then
    echo "$(date) - Erreur: X non accessible" >> "$LOG"
    exit 1
fi

# Arrêter tout processus vidéo existant
pkill -f vlc 2>/dev/null
pkill -f mpv 2>/dev/null
pkill -f feh 2>/dev/null
sleep 2

# Essayer MPV d'abord (plus stable sur ce Pi)
echo "$(date) - Lancement MPV..." >> "$LOG"
export DISPLAY=:0
mpv --fullscreen \
    --loop=inf \
    --no-audio \
    --vo=x11 \
    --really-quiet \
    "$VIDEO" > /tmp/mpv.log 2>&1 &

MPV_PID=$!
sleep 5

if ps -p $MPV_PID > /dev/null; then
    echo "$(date) - MPV lancé avec succès (PID: $MPV_PID)" >> "$LOG"
else
    echo "$(date) - MPV échoué, tentative avec VLC..." >> "$LOG"

    # Essayer VLC en fallback
    cvlc --intf dummy \
         --fullscreen \
         --loop \
         --no-video-title-show \
         --vout x11 \
         "$VIDEO" > /tmp/vlc.log 2>&1 &

    VLC_PID=$!
    sleep 5

    if ps -p $VLC_PID > /dev/null; then
        echo "$(date) - VLC lancé (PID: $VLC_PID)" >> "$LOG"
    else
        echo "$(date) - Échec VLC, affichage image fallback" >> "$LOG"

        # Créer image fallback si nécessaire
        if [ ! -f /opt/pisignage/media/fallback.jpg ]; then
            convert -size 1920x1080 gradient:'#2563eb-#7c3aed' \
                    -fill white -gravity center -pointsize 100 \
                    -annotate +0+0 "PiSignage v0.8.0\nAucune vidéo disponible" \
                    /opt/pisignage/media/fallback.jpg
        fi

        feh --fullscreen --hide-pointer /opt/pisignage/media/fallback.jpg &
        echo "$(date) - Image fallback affichée" >> "$LOG"
    fi
fi

echo "$(date) - Script terminé" >> "$LOG"