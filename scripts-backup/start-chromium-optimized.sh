#!/bin/bash

# ===========================================
# CHROMIUM OPTIMISÉ 60 FPS - RASPBERRY PI 4
# ===========================================
# Script de lancement Chromium avec optimisations GPU maximales
# Version: 1.0.0
# Date: 2025-09-22
# Auteur: Agent DevOps PiSignage

set -e

# Variables de configuration
DISPLAY_URL="${1:-http://localhost/player.html}"
LOG_FILE="/var/log/pisignage/chromium-performance.log"
PID_FILE="/var/run/pisignage/chromium.pid"

# Créer dossiers logs si inexistants
mkdir -p /var/log/pisignage
mkdir -p /var/run/pisignage

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Arrêter Chromium existant
cleanup_chromium() {
    log "Nettoyage processus Chromium existants..."
    pkill -f chromium-browser || true
    pkill -f chrome || true
    sleep 2

    # Force kill si nécessaire
    pkill -9 -f chromium-browser || true
    rm -f "$PID_FILE"
}

# Optimisations système pré-lancement
optimize_system() {
    log "Application optimisations système..."

    # Priorité CPU maximale pour Chromium
    echo "Optimisation scheduler..."

    # Vider caches système
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

    # Optimisation network stack pour streaming
    echo 'net.core.rmem_max = 16777216' > /proc/sys/net/core/rmem_max 2>/dev/null || true
    echo 'net.core.wmem_max = 16777216' > /proc/sys/net/core/wmem_max 2>/dev/null || true

    # GPU governor en performance
    echo performance > /sys/class/devfreq/*/governor 2>/dev/null || true

    log "Optimisations système appliquées"
}

# Vérification GPU
check_gpu() {
    log "Vérification configuration GPU..."

    GPU_MEM=$(vcgencmd get_mem gpu | cut -d= -f2)
    ARM_FREQ=$(vcgencmd measure_clock arm | cut -d= -f2)
    GPU_FREQ=$(vcgencmd measure_clock gpu | cut -d= -f2)
    TEMP=$(vcgencmd measure_temp | cut -d= -f2)

    log "GPU Memory: $GPU_MEM"
    log "ARM Frequency: $ARM_FREQ Hz"
    log "GPU Frequency: $GPU_FREQ Hz"
    log "Temperature: $TEMP"

    # Vérifications critiques
    if [ "${GPU_MEM%M*}" -lt 256 ]; then
        log "ATTENTION: GPU Memory < 256MB, performance non optimale"
    fi

    if [ "${TEMP%'*}" -gt 75 ]; then
        log "ATTENTION: Température élevée: $TEMP"
    fi
}

# Configuration environnement
setup_environment() {
    log "Configuration environnement Chromium..."

    # Variables d'environnement pour performance GPU maximale
    export DISPLAY=:0
    export CHROMIUM_FLAGS=""

    # Optimisations mémoire
    export MALLOC_ARENA_MAX=2
    export MALLOC_MMAP_THRESHOLD_=131072
    export MALLOC_TRIM_THRESHOLD_=131072
    export MALLOC_TOP_PAD_=131072
    export MALLOC_MMAP_MAX_=65536

    # Optimisations GPU
    export LIBGL_ALWAYS_INDIRECT=0
    export LIBGL_ALWAYS_SOFTWARE=0
    export VDPAU_DRIVER=v3d
    export MESA_GL_VERSION_OVERRIDE=4.5
    export MESA_GLSL_VERSION_OVERRIDE=450

    # Optimisations V4L2 pour hardware decode
    export GST_V4L2_USE_LIBV4L2=1

    log "Environnement configuré"
}

# Lancement Chromium avec tous les flags d'optimisation
launch_chromium() {
    log "Lancement Chromium optimisé pour 60 FPS..."

    # Array des flags Chromium optimisés
    CHROMIUM_FLAGS=(
        # ===========================================
        # OPTIMISATIONS GPU FONDAMENTALES
        # ===========================================
        --enable-gpu
        --enable-gpu-rasterization
        --enable-oop-rasterization
        --enable-accelerated-2d-canvas
        --enable-accelerated-video-decode
        --enable-accelerated-mjpeg-decode
        --enable-gpu-memory-buffer-video-frames
        --enable-native-gpu-memory-buffers
        --enable-zero-copy
        --canvas-oop-rasterization
        --enable-gpu-compositing
        --enable-hardware-overlays

        # ===========================================
        # OPTIMISATIONS RENDU AVANCÉES
        # ===========================================
        --use-gl=egl
        --enable-vulkan
        --enable-features=VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization,UseSkiaRenderer
        --disable-features=UseChromeOSDirectVideoDecoder
        --ignore-gpu-blacklist
        --ignore-gpu-blocklist
        --disable-gpu-driver-bug-workarounds
        --disable-gpu-sandbox

        # ===========================================
        # OPTIMISATIONS PERFORMANCE
        # ===========================================
        --max-tiles-for-interest-area=512
        --default-tile-width=512
        --default-tile-height=512
        --num-raster-threads=4
        --enable-checker-imaging
        --enable-prefer-compositing-to-lcd-text

        # ===========================================
        # OPTIMISATIONS RÉSEAU/STREAMING
        # ===========================================
        --aggressive-cache-discard
        --enable-tcp-fast-open
        --enable-quic
        --enable-experimental-web-platform-features

        # ===========================================
        # OPTIMISATIONS MÉMOIRE
        # ===========================================
        --memory-pressure-off
        --max_old_space_size=512
        --js-flags="--max-old-space-size=512 --optimize-for-size"
        --renderer-process-limit=1
        --max-gum-fps=60

        # ===========================================
        # OPTIMISATIONS AFFICHAGE
        # ===========================================
        --force-device-scale-factor=1
        --disable-smooth-scrolling
        --disable-scroll-bounce
        --enable-fast-unload
        --enable-experimental-canvas-features
        --enable-experimental-web-platform-features

        # ===========================================
        # OPTIMISATIONS AUDIO/VIDEO
        # ===========================================
        --autoplay-policy=no-user-gesture-required
        --disable-web-security
        --disable-features=TranslateUI
        --enable-features=MediaFoundationH264Encoding
        --enable-accelerated-mjpeg-decode
        --enable-accelerated-video

        # ===========================================
        # DÉSACTIVATIONS POUR PERFORMANCE
        # ===========================================
        --disable-extensions
        --disable-plugins
        --disable-java
        --disable-background-timer-throttling
        --disable-backgrounding-occluded-windows
        --disable-renderer-backgrounding
        --disable-background-networking
        --disable-ipc-flooding-protection
        --disable-dev-shm-usage
        --disable-software-rasterizer

        # ===========================================
        # MODE KIOSK OPTIMISÉ
        # ===========================================
        --kiosk
        --no-first-run
        --noerrdialogs
        --disable-infobars
        --disable-translate
        --disable-suggestions-service
        --disable-save-password-bubble
        --disable-session-crashed-bubble
        --disable-restore-session-state
        --start-maximized
        --window-position=0,0
        --window-size=1920,1080

        # ===========================================
        # SÉCURITÉ ADAPTÉE
        # ===========================================
        --disable-web-security
        --disable-same-origin-policy
        --allow-running-insecure-content
        --ignore-certificate-errors
        --ignore-ssl-errors
        --ignore-certificate-errors-spki-list

        # ===========================================
        # DEBUG ET MONITORING
        # ===========================================
        --enable-logging
        --log-level=0
        --enable-gpu-benchmarking
        --show-fps-counter

        # URL à afficher
        "$DISPLAY_URL"
    )

    log "Flags Chromium configurés: ${#CHROMIUM_FLAGS[@]} options"

    # Lancement avec priorité haute et monitoring
    nohup nice -n -10 ionice -c 1 -n 4 /usr/lib/chromium-browser/chromium-browser "${CHROMIUM_FLAGS[@]}" \
        > "$LOG_FILE.stdout" 2> "$LOG_FILE.stderr" &

    CHROMIUM_PID=$!
    echo "$CHROMIUM_PID" > "$PID_FILE"

    log "Chromium lancé avec PID: $CHROMIUM_PID"
    log "URL chargée: $DISPLAY_URL"

    # Optimisations post-lancement
    sleep 5
    if [ -d "/proc/$CHROMIUM_PID" ]; then
        # Priorité temps réel pour thread principal
        chrt -f -p 50 "$CHROMIUM_PID" 2>/dev/null || true

        # Affinité CPU (cores 2-3 pour Chromium)
        taskset -cp 2,3 "$CHROMIUM_PID" 2>/dev/null || true

        log "Optimisations post-lancement appliquées"
    else
        log "ERREUR: Chromium non démarré correctement"
        exit 1
    fi
}

# Monitoring continu
monitor_performance() {
    log "Démarrage monitoring performance..."

    while true; do
        if [ -f "$PID_FILE" ] && [ -d "/proc/$(cat $PID_FILE)" ]; then
            PID=$(cat "$PID_FILE")

            # Stats CPU/Mémoire
            CPU_USAGE=$(ps -p "$PID" -o %cpu --no-headers | tr -d ' ')
            MEM_USAGE=$(ps -p "$PID" -o %mem --no-headers | tr -d ' ')

            # Stats GPU
            GPU_TEMP=$(vcgencmd measure_temp | cut -d= -f2)
            GPU_MEM_USED=$(vcgencmd get_mem gpu | cut -d= -f2)

            # Log stats si CPU > 80% ou température > 75°C
            if (( $(echo "$CPU_USAGE > 80" | bc -l) )) || (( $(echo "${GPU_TEMP%'*} > 75" | bc -l) )); then
                log "PERFORMANCE: CPU=$CPU_USAGE% MEM=$MEM_USAGE% GPU_TEMP=$GPU_TEMP GPU_MEM=$GPU_MEM_USED"
            fi

            sleep 30
        else
            log "Chromium arrêté - fin du monitoring"
            break
        fi
    done &
}

# ===========================================
# SCRIPT PRINCIPAL
# ===========================================

log "=== DÉMARRAGE CHROMIUM OPTIMISÉ 60 FPS ==="
log "URL: $DISPLAY_URL"

# Nettoyage préalable
cleanup_chromium

# Optimisations système
optimize_system

# Vérification GPU
check_gpu

# Configuration environnement
setup_environment

# Lancement Chromium optimisé
launch_chromium

# Démarrage monitoring
monitor_performance

log "=== CHROMIUM OPTIMISÉ DÉMARRÉ AVEC SUCCÈS ==="

# Maintenir le script actif
wait