#!/bin/bash
# PiSignage - VLC Production Launcher
# Configuration testée et validée pour Raspberry Pi

VIDEO="${1:-/opt/pisignage/media/BigBuckBunny_720p.mp4}"
PID_FILE="/tmp/vlc.pid"

# Arrêter VLC existant proprement
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Arrêt de VLC (PID: $OLD_PID)..."
        kill "$OLD_PID"
        sleep 2
    fi
fi

# Nettoyer les processus zombies
pkill -9 vlc 2>/dev/null
sleep 1

# Lancer VLC avec la configuration qui fonctionne
# IMPORTANT: Utiliser 'vlc' pas 'cvlc', et '-I dummy' pas '--intf dummy'
echo "Démarrage de VLC avec $VIDEO..."
vlc -I dummy --fullscreen --loop "$VIDEO" > /dev/null 2>&1 &

VLC_PID=$!
echo $VLC_PID > "$PID_FILE"

# Vérifier que VLC démarre bien
sleep 2
if kill -0 "$VLC_PID" 2>/dev/null; then
    echo "✅ VLC démarré avec succès (PID: $VLC_PID)"
    echo "📹 Lecture en boucle: $(basename "$VIDEO")"
    echo "📸 Screenshots disponibles via http://192.168.1.103/"
else
    echo "❌ Échec du démarrage de VLC"
    exit 1
fi