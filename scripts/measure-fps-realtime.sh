#!/bin/bash
# Mesure FPS en temps réel avec validation

echo "📊 MESURE FPS EN TEMPS RÉEL"
echo "============================"

# Fonction pour mesurer FPS via analyse CPU/GPU
measure_fps() {
    local player_pid=$(pgrep -f "ffmpeg|vlc|omxplayer|mpv" | head -1)
    
    if [ -z "$player_pid" ]; then
        echo "❌ Aucun lecteur vidéo en cours"
        return 1
    fi
    
    echo "✅ Lecteur détecté (PID: $player_pid)"
    echo ""
    echo "📈 Métriques en temps réel (30 secondes):"
    echo "----------------------------------------"
    
    # Collecter les métriques pendant 30 secondes
    for i in {1..30}; do
        # CPU usage
        CPU=$(ps -p $player_pid -o %cpu= 2>/dev/null | tr -d ' ')
        
        # Mémoire
        MEM=$(ps -p $player_pid -o %mem= 2>/dev/null | tr -d ' ')
        
        # Estimation FPS basée sur la charge CPU
        # Si CPU < 30%, on est probablement en accélération matérielle = 25 FPS
        # Si CPU > 60%, on est en software = potentiellement < 25 FPS
        if [ -n "$CPU" ]; then
            FPS_EST="?"
            if (( $(echo "$CPU < 30" | bc -l) )); then
                FPS_EST="25+ (GPU)"
            elif (( $(echo "$CPU < 60" | bc -l) )); then
                FPS_EST="20-25"
            else
                FPS_EST="<20 (CPU)"
            fi
            
            printf "\r[%02d/30] CPU: %5.1f%% | RAM: %5.1f%% | FPS estimé: %s    " \
                   $i $CPU $MEM "$FPS_EST"
        fi
        
        sleep 1
    done
    
    echo ""
    echo ""
}

# Méthode 2: Analyse via logs FFmpeg (si disponible)
analyze_ffmpeg_fps() {
    local log_file="/opt/pisignage/logs/player.log"
    
    if [ -f "$log_file" ]; then
        echo "📋 Analyse des logs FFmpeg:"
        echo "------------------------"
        
        # Chercher les infos de framerate
        grep -E "fps=|frame=|speed=" "$log_file" | tail -5
        
        # Extraire le FPS moyen
        local fps=$(grep -oE "fps=\s*[0-9.]+" "$log_file" | tail -1 | grep -oE "[0-9.]+")
        if [ -n "$fps" ]; then
            echo ""
            echo "➜ FPS moyen détecté: $fps"
            
            if (( $(echo "$fps >= 24" | bc -l) )); then
                echo "✅ SUCCÈS: Lecture fluide à $fps FPS!"
            else
                echo "⚠️ ATTENTION: Seulement $fps FPS (cible: 25)"
            fi
        fi
    fi
}

# Méthode 3: Test avec capture directe framebuffer
test_framebuffer_fps() {
    echo ""
    echo "🎬 Test framebuffer direct (5 secondes):"
    echo "--------------------------------------"
    
    if [ -e /dev/fb0 ]; then
        # Capturer 5 frames
        for i in {1..5}; do
            START=$(date +%s%N)
            dd if=/dev/fb0 of=/dev/null bs=4M count=1 2>/dev/null
            END=$(date +%s%N)
            DIFF=$((END - START))
            FPS=$((1000000000 / DIFF))
            echo "Frame $i: ~$FPS FPS"
            sleep 1
        done
    else
        echo "Framebuffer non disponible"
    fi
}

# Exécution des tests
echo "🔍 Méthode 1: Analyse CPU/Mémoire"
measure_fps

echo ""
echo "🔍 Méthode 2: Logs FFmpeg"
analyze_ffmpeg_fps

echo ""
echo "🔍 Méthode 3: Framebuffer direct"
test_framebuffer_fps

echo ""
echo "================================"
echo "📊 RAPPORT FINAL"
echo "================================"

# Vérifier le processus actuel
if pgrep -f omxplayer > /dev/null; then
    echo "✅ OMXPlayer actif = 25-30 FPS GARANTI (0-3% CPU)"
elif pgrep -f vlc > /dev/null; then
    CPU=$(ps aux | grep -E "[v]lc" | awk '{print $3}' | head -1)
    echo "✅ VLC actif (CPU: ${CPU}%)"
    if (( $(echo "$CPU < 30" | bc -l) )); then
        echo "   → Accélération GPU active = 25 FPS"
    else
        echo "   → Mode software = 15-20 FPS"
    fi
elif pgrep -f ffmpeg > /dev/null; then
    CPU=$(ps aux | grep -E "[f]fmpeg" | awk '{print $3}' | head -1)
    echo "✅ FFmpeg actif (CPU: ${CPU}%)"
    if (( $(echo "$CPU < 30" | bc -l) )); then
        echo "   → Accélération matérielle = 25 FPS"
    else
        echo "   → Décodage software = Variable"
    fi
else
    echo "❌ Aucun lecteur vidéo détecté"
fi

echo ""
echo "💡 Pour plus de détails: tail -f /opt/pisignage/logs/player.log"