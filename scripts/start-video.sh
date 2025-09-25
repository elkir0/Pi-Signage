#!/bin/bash
# PiSignage - Script de démarrage vidéo corrigé

echo "=== Starting PiSignage Video Player ==="

# Configuration de l'environnement
export XDG_RUNTIME_DIR=/run/user/1000
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority
export HOME=/home/pi

# Arrêter les players existants
pkill -9 vlc 2>/dev/null
pkill -9 mpv 2>/dev/null
sleep 1

# Déterminer le fichier vidéo ou fallback
VIDEO_DIR="/opt/pisignage/media"
FALLBACK_IMAGE="$VIDEO_DIR/fallback-logo.jpg"

# Chercher une vidéo à lire
VIDEO_FILE=""
for ext in mp4 mkv avi mov webm; do
    FILE=$(ls "$VIDEO_DIR"/*.$ext 2>/dev/null | head -1)
    if [ -n "$FILE" ]; then
        VIDEO_FILE="$FILE"
        break
    fi
done

# Si pas de vidéo, créer une image fallback si elle n'existe pas
if [ -z "$VIDEO_FILE" ]; then
    echo "Aucune vidéo trouvée, affichage du fallback..."

    if [ ! -f "$FALLBACK_IMAGE" ]; then
        echo "Création de l'image fallback..."
        # Créer une image fallback avec ImageMagick
        convert -size 1920x1080 xc:black \
                -gravity center \
                -pointsize 72 \
                -fill white \
                -annotate +0+0 "PiSignage\nAucune vidéo disponible" \
                "$FALLBACK_IMAGE"
    fi

    # Afficher l'image avec feh
    if command -v feh &>/dev/null; then
        DISPLAY=:0 feh --fullscreen --hide-pointer --no-menus "$FALLBACK_IMAGE" &
        echo "✓ Image fallback affichée"
    else
        # Si feh n'est pas disponible, utiliser fbi sur framebuffer
        sudo fbi -T 1 -a --noverbose "$FALLBACK_IMAGE" 2>/dev/null &
        echo "✓ Image fallback affichée (framebuffer)"
    fi
    exit 0
fi

# Démarrer VLC avec la vidéo trouvée
echo "Lecture de: $(basename "$VIDEO_FILE")"

# Lancer VLC avec la configuration qui fonctionne
sudo -u pi bash -c "
    export XDG_RUNTIME_DIR=/run/user/1000
    export DISPLAY=:0
    cvlc --intf dummy \
         --vout x11 \
         --fullscreen \
         --loop \
         --no-video-title-show \
         '$VIDEO_FILE' > /opt/pisignage/logs/vlc.log 2>&1 &
"

VLC_PID=$!
echo "✓ VLC démarré (PID: $VLC_PID)"

# Vérifier que VLC fonctionne
sleep 3
if ps aux | grep -v grep | grep vlc > /dev/null; then
    echo "✓ VLC fonctionne correctement"
else
    echo "✗ VLC a échoué, tentative avec MPV..."

    # Essayer MPV comme fallback
    sudo -u pi bash -c "
        export XDG_RUNTIME_DIR=/run/user/1000
        export DISPLAY=:0
        export LIBGL_ALWAYS_SOFTWARE=1
        mpv --vo=x11 \
            --hwdec=no \
            --fullscreen \
            --loop-playlist=inf \
            '$VIDEO_FILE' > /opt/pisignage/logs/mpv.log 2>&1 &
    "

    echo "✓ MPV démarré en fallback"
fi

exit 0