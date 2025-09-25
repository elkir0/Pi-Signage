#!/bin/bash
# PiSignage v0.8.1 - Script de démarrage VLC avec Big Buck Bunny

echo "=== PiSignage v0.8.1 - Démarrage VLC avec Big Buck Bunny ==="

# Configuration
VIDEO_FILE="/opt/pisignage/media/BigBuckBunny_720p.mp4"
LOG_FILE="/opt/pisignage/logs/vlc.log"
CONFIG_FILE="/opt/pisignage/config/player-config.json"

# Arrêter les lecteurs existants
echo "Arrêt des lecteurs existants..."
pkill -9 vlc 2>/dev/null
pkill -9 mpv 2>/dev/null
sleep 1

# Vérifier si Big Buck Bunny existe
if [ ! -f "$VIDEO_FILE" ]; then
    echo "❌ Erreur: Big Buck Bunny non trouvé à $VIDEO_FILE"
    echo "Recherche d'autres vidéos..."

    # Chercher une autre vidéo
    for ext in mp4 mkv avi mov webm; do
        FOUND=$(find /opt/pisignage/media -name "*.$ext" 2>/dev/null | head -1)
        if [ -n "$FOUND" ]; then
            VIDEO_FILE="$FOUND"
            echo "✓ Vidéo trouvée: $(basename "$VIDEO_FILE")"
            break
        fi
    done

    if [ ! -f "$VIDEO_FILE" ]; then
        echo "❌ Aucune vidéo disponible"
        exit 1
    fi
fi

# Détecter l'environnement d'affichage (Wayland ou X11)
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "📺 Environnement détecté: Wayland"
    export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}

    # Options VLC pour Wayland
    VLC_OPTIONS="
        --intf dummy
        --vout gles2
        --fullscreen
        --loop
        --no-video-title-show
        --quiet
        --no-osd
    "
else
    echo "📺 Environnement détecté: X11"
    export DISPLAY=${DISPLAY:-:0}
    export XAUTHORITY=${XAUTHORITY:-/home/$USER/.Xauthority}

    # Options VLC pour X11
    VLC_OPTIONS="
        --intf dummy
        --vout x11
        --fullscreen
        --loop
        --no-video-title-show
        --quiet
        --no-osd
    "
fi

# Démarrer VLC
echo "▶️ Démarrage de VLC avec $(basename "$VIDEO_FILE")..."
echo "Options: $VLC_OPTIONS"

# Lancer VLC avec les bonnes options
cvlc $VLC_OPTIONS "$VIDEO_FILE" > "$LOG_FILE" 2>&1 &

VLC_PID=$!
echo "✓ VLC démarré (PID: $VLC_PID)"

# Vérifier que VLC fonctionne
sleep 3
if ps -p $VLC_PID > /dev/null 2>&1; then
    echo "✅ VLC fonctionne correctement"

    # Mettre à jour la configuration
    if [ -f "$CONFIG_FILE" ]; then
        # Mettre à jour le player actuel à VLC
        sed -i 's/"current": "mpv"/"current": "vlc"/' "$CONFIG_FILE" 2>/dev/null
        echo "✓ Configuration mise à jour"
    fi
else
    echo "❌ VLC a échoué"
    echo "Vérifiez les logs dans: $LOG_FILE"
    tail -20 "$LOG_FILE"
    exit 1
fi

echo "═══════════════════════════════════════════════════════"
echo "✅ PiSignage v0.8.1 - VLC démarré avec succès"
echo "📽️ Vidéo: $(basename "$VIDEO_FILE")"
echo "📝 Logs: $LOG_FILE"
echo "🔧 PID: $VLC_PID"
echo "═══════════════════════════════════════════════════════"

exit 0