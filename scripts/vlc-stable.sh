#!/bin/bash
# PiSignage - VLC Stable Launcher
# Lancement de VLC avec configuration optimisée pour éviter les redémarrages

VIDEO="${1:-/opt/pisignage/media/BigBuckBunny_720p.mp4}"
LOG="/opt/pisignage/logs/vlc-stable.log"

# Tuer VLC existant
pkill -9 vlc 2>/dev/null
sleep 2

# Options VLC optimisées pour stabilité
# --no-hw-dec : Désactiver l'accélération matérielle qui cause des problèmes
# --vout fb : Utiliser le framebuffer simple
# --no-video-title-show : Pas de titre
# --repeat : Répéter au lieu de --loop qui peut causer des problèmes

echo "[$(date)] Starting VLC with stable configuration" > $LOG

cvlc \
    --intf dummy \
    --fullscreen \
    --no-video-title-show \
    --no-hw-dec \
    --avcodec-hw none \
    --vout fb \
    --repeat \
    --no-osd \
    --quiet \
    "$VIDEO" >> $LOG 2>&1 &

PID=$!
echo "[$(date)] VLC started with PID: $PID" >> $LOG
echo $PID > /tmp/vlc.pid

# Monitorer VLC et le relancer si nécessaire
monitor_vlc() {
    while true; do
        sleep 30
        if ! kill -0 $PID 2>/dev/null; then
            echo "[$(date)] VLC crashed, restarting..." >> $LOG
            exec $0 "$VIDEO"
        fi
    done
}

# Lancer le monitoring en arrière-plan
monitor_vlc &

echo "VLC lancé en mode stable (PID: $PID)"
echo "Logs: tail -f $LOG"