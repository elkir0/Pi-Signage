#!/bin/bash

# PiSignage - VLC avec accélération GPU pour 30+ FPS
# Basé sur rapport technique d'optimisation Raspberry Pi 4

VIDEO="/opt/pisignage/media/Big_Buck_Bunny_720_10s_30MB.mp4"
LOG="/opt/pisignage/logs/vlc-gpu.log"

# Arrêt propre des processus existants
echo "🔧 Arrêt des processus vidéo existants..." > "$LOG"
pkill -f vlc 2>/dev/null
pkill -f mpv 2>/dev/null
sleep 2

# Vérifier température avant démarrage
TEMP=$(vcgencmd measure_temp | cut -d= -f2)
echo "📊 Température actuelle: $TEMP" >> "$LOG"

# Vérifier throttling (0x0 = pas de throttling)
THROTTLED=$(vcgencmd get_throttled | cut -d= -f2)
if [ "$THROTTLED" != "0x0" ]; then
    echo "⚠️  WARNING: Throttling détecté: $THROTTLED" >> "$LOG"
    echo "    Ajoutez un dissipateur pour performances optimales!" >> "$LOG"
fi

# Configuration VLC selon rapport technique
# IMPORTANT: Utiliser cvlc (pas vlc) + mode fullscreen OBLIGATOIRE
echo "🚀 Lancement VLC avec accélération GPU..." >> "$LOG"

# Options critiques selon le rapport:
# --intf dummy : Interface sans GUI (économie CPU)
# --fullscreen : OBLIGATOIRE pour DRM leasing (divise CPU par 2)
# --no-video-title-show : Pas de titre (économie rendu)
# --vout mmal_vout : Sortie MMAL pour Pi (si disponible)
# --mmal-display hdmi-1 : Sortie HDMI directe
# --avcodec-hw=mmal : Force décodage hardware MMAL
# --codec avcodec,mmal_decoder : Décodeurs avec MMAL prioritaire

export DISPLAY=:0
export VLC_VERBOSE=0

# Essayer d'abord avec MMAL (meilleure performance sur Pi)
echo "Test 1: VLC avec MMAL (10-15% CPU attendu)" >> "$LOG"
cvlc \
    --intf dummy \
    --fullscreen \
    --loop \
    --no-video-title-show \
    --no-osd \
    --quiet \
    --vout mmal_vout \
    --mmal-display hdmi-1 \
    --mmal-layer 10 \
    --avcodec-hw=mmal \
    --codec avcodec,mmal_decoder \
    --no-audio \
    --avcodec-threads=4 \
    --network-caching=1000 \
    --file-caching=1000 \
    --drop-late-frames \
    --skip-frames \
    "$VIDEO" > /tmp/vlc-mmal.log 2>&1 &

VLC_PID=$!
sleep 5

# Vérifier si VLC tourne
if ps -p $VLC_PID > /dev/null; then
    echo "✅ VLC lancé avec MMAL (PID: $VLC_PID)" >> "$LOG"

    # Monitorer performance
    CPU=$(ps aux | grep $VLC_PID | grep -v grep | awk '{print $3}')
    echo "📊 Utilisation CPU: ${CPU}%" >> "$LOG"

else
    echo "⚠️  MMAL échoué, fallback sur OpenGL ES2" >> "$LOG"

    # Fallback: OpenGL for Embedded Systems (recommandé dans rapport)
    cvlc \
        --intf dummy \
        --fullscreen \
        --loop \
        --no-video-title-show \
        --no-osd \
        --quiet \
        --vout gles2 \
        --no-audio \
        --avcodec-threads=4 \
        --drop-late-frames \
        --skip-frames \
        "$VIDEO" > /tmp/vlc-gles2.log 2>&1 &

    VLC_PID=$!
    sleep 5

    if ps -p $VLC_PID > /dev/null; then
        echo "✅ VLC lancé avec OpenGL ES2 (PID: $VLC_PID)" >> "$LOG"
    else
        echo "❌ Échec des deux modes, vérifier logs dans /tmp/" >> "$LOG"

        # Dernier recours: mode basique
        cvlc --intf dummy --fullscreen --loop "$VIDEO" &
        VLC_PID=$!
        echo "🔄 Mode basique lancé (PID: $VLC_PID)" >> "$LOG"
    fi
fi

# Afficher stats finales
sleep 3
if ps -p $VLC_PID > /dev/null; then
    echo "" >> "$LOG"
    echo "=== PERFORMANCE STATS ===" >> "$LOG"
    TEMP=$(vcgencmd measure_temp | cut -d= -f2)
    GPU_MEM=$(vcgencmd get_mem gpu | cut -d= -f2)
    THROTTLED=$(vcgencmd get_throttled | cut -d= -f2)
    CPU=$(ps aux | grep $VLC_PID | grep -v grep | awk '{print $3}')

    echo "🌡️  Température: $TEMP" >> "$LOG"
    echo "💾 GPU Mem: $GPU_MEM" >> "$LOG"
    echo "⚡ Throttling: $THROTTLED (0x0 = OK)" >> "$LOG"
    echo "📊 CPU VLC: ${CPU}%" >> "$LOG"

    if (( $(echo "$CPU < 20" | bc -l) )); then
        echo "✅ PERFORMANCE OPTIMALE (<20% CPU)" >> "$LOG"
    else
        echo "⚠️  Performance sous-optimale (>20% CPU)" >> "$LOG"
        echo "   Vérifier: gpu_mem=256 et dtoverlay=vc4-kms-v3d" >> "$LOG"
    fi
else
    echo "❌ VLC ne tourne pas!" >> "$LOG"
fi

# Afficher le log
cat "$LOG"