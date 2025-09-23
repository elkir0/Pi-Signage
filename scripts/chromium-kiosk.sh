#!/bin/bash

# PiSignage - Chromium Kiosk Mode avec accélération GPU

# Arrêter tout
pkill -f chromium
pkill -f vlc
pkill -f mpv
sleep 2

# Options Chromium pour accélération GPU sur Raspberry Pi
# Ces flags activent l'accélération hardware pour la vidéo

CHROMIUM_FLAGS=(
    --kiosk                                  # Mode kiosk plein écran
    --noerrdialogs                          # Pas de dialogues d'erreur
    --disable-infobars                      # Pas de barres d'info
    --no-first-run                          # Pas de premier démarrage
    --disable-translate                     # Pas de traduction
    --disable-features=TranslateUI          # Désactiver UI traduction
    --disk-cache-dir=/tmp/chromium-cache    # Cache temporaire
    --overscroll-history-navigation=0       # Pas de navigation geste
    --disable-pinch                         # Pas de pinch zoom

    # Accélération GPU pour Raspberry Pi
    --enable-gpu-rasterization              # Rastérisation GPU
    --enable-accelerated-video-decode       # Décodage vidéo accéléré
    --ignore-gpu-blocklist                  # Ignorer blocklist GPU
    --enable-gpu                            # Activer GPU
    --use-gl=egl                            # Utiliser EGL (optimal pour Pi)

    # Optimisations supplémentaires
    --disable-software-rasterizer           # Pas de rasterizer software
    --disable-background-timer-throttling   # Pas de throttling
    --disable-backgrounding-occluded-windows
    --disable-renderer-backgrounding
    --disable-features=Translate
    --disable-ipc-flooding-protection
    --disable-dev-shm-usage                # Important pour Pi

    # Autoplay vidéo
    --autoplay-policy=no-user-gesture-required
)

# URL de la page vidéo
URL="http://localhost/video.html"

echo "🚀 Lancement Chromium avec accélération GPU..."

# Lancer Chromium
DISPLAY=:0 chromium-browser "${CHROMIUM_FLAGS[@]}" "$URL" &

CHROME_PID=$!
echo "✅ Chromium lancé (PID: $CHROME_PID)"

# Monitoring
sleep 5
if ps -p $CHROME_PID > /dev/null; then
    echo "📊 Stats GPU:"
    vcgencmd measure_temp
    vcgencmd get_mem gpu

    echo ""
    echo "Chromium fonctionne avec accélération GPU"
    echo "Vidéo en lecture sur http://localhost/video.html"
else
    echo "❌ Chromium n'a pas démarré"
fi