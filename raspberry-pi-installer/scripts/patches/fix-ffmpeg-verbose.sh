#!/usr/bin/env bash

# =============================================================================
# Patch pour restaurer le verbose et optimiser ffmpeg
# Version: 1.0.0
# Description: Corrige les problèmes de feedback et optimise les ressources
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Chemins
readonly WEB_ROOT="/var/www/pi-signage"
readonly SCRIPTS_DIR="/opt/scripts"
readonly LOG_FILE="/var/log/pi-signage-setup.log"

log_info() {
    echo -e "${GREEN}[PATCH]${NC} $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PATCH] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    echo -e "${YELLOW}[PATCH]${NC} $*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PATCH-WARN] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}[PATCH]${NC} $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PATCH-ERROR] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# =============================================================================
# 1. MISE À JOUR DU WRAPPER YT-DLP AVEC VERBOSE
# =============================================================================

update_ytdlp_wrapper() {
    log_info "Mise à jour du wrapper yt-dlp avec support verbose..."
    
    cat > "$SCRIPTS_DIR/yt-dlp-wrapper.sh" << 'EOF'
#!/bin/bash
# Wrapper pour yt-dlp avec environnement correct et verbose

# Définir l'environnement
export HOME=/var/www
export PATH=/usr/local/bin:/usr/bin:/bin
export PYTHONIOENCODING=utf-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Créer le répertoire cache si nécessaire
mkdir -p /var/www/.cache/yt-dlp 2>/dev/null
chmod 755 /var/www/.cache 2>/dev/null
chown -R www-data:www-data /var/www/.cache 2>/dev/null

# Créer un fichier de progression temporaire
PROGRESS_FILE="/tmp/pi-signage-progress/yt-dlp-$(date +%s).progress"
mkdir -p /tmp/pi-signage-progress
chmod 777 /tmp/pi-signage-progress

# Fonction pour nettoyer en sortie
cleanup() {
    rm -f "$PROGRESS_FILE" 2>/dev/null
}
trap cleanup EXIT

# Exécuter yt-dlp avec les arguments - Forcer MP4 pour Chromium
# Afficher la progression sur stderr ET dans le fichier
exec /usr/local/bin/yt-dlp \
    --format "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
    --merge-output-format mp4 \
    --progress \
    --newline \
    --no-color \
    --progress-template "download:[download] %(progress._percent_str)s of %(progress._total_bytes_str)s at %(progress._speed_str)s ETA %(progress._eta_str)s" \
    --progress-template "postprocess:[postprocess] %(progress._percent_str)s" \
    "$@" 2>&1 | tee "$PROGRESS_FILE"
EOF
    
    chmod 755 "$SCRIPTS_DIR/yt-dlp-wrapper.sh"
    log_info "✓ Wrapper yt-dlp mis à jour avec support verbose"
}

# =============================================================================
# 2. CRÉER UN WRAPPER FFMPEG OPTIMISÉ
# =============================================================================

create_ffmpeg_wrapper() {
    log_info "Création du wrapper ffmpeg optimisé..."
    
    cat > "$SCRIPTS_DIR/ffmpeg-wrapper.sh" << 'EOF'
#!/bin/bash
# Wrapper pour ffmpeg avec optimisations pour Raspberry Pi

# Détecter le nombre de cores disponibles
CORES=$(nproc)
MAX_THREADS=$((CORES / 2))  # Utiliser la moitié des cores
if [ $MAX_THREADS -lt 1 ]; then
    MAX_THREADS=1
fi

# Détecter si l'accélération hardware est disponible
HW_ACCEL=""
if [ -e /dev/video10 ] || [ -e /dev/video11 ]; then
    # V4L2 disponible (Bookworm)
    HW_ACCEL="-c:v h264_v4l2m2m"
    echo "[INFO] Utilisation de l'accélération hardware V4L2"
fi

# Exécuter ffmpeg avec limitations de ressources et verbose
exec nice -n 10 ffmpeg \
    -threads $MAX_THREADS \
    -thread_queue_size 512 \
    $HW_ACCEL \
    -progress pipe:1 \
    -loglevel info \
    "$@"
EOF
    
    chmod 755 "$SCRIPTS_DIR/ffmpeg-wrapper.sh"
    log_info "✓ Wrapper ffmpeg créé avec optimisations"
}

# =============================================================================
# 3. MISE À JOUR DE LA CONFIGURATION PHP-FPM
# =============================================================================

update_php_fpm_config() {
    log_info "Mise à jour de la configuration PHP-FPM pour le streaming..."
    
    # Ajouter des configurations pour le streaming de sortie
    cat >> /etc/php/8.2/fpm/pool.d/pi-signage.conf << 'EOF'

; Configuration pour le streaming de sortie
php_admin_value[output_buffering] = Off
php_admin_value[implicit_flush] = On
php_admin_value[zlib.output_compression] = Off
php_admin_value[max_execution_time] = 600
php_admin_value[max_input_time] = 600

; Augmenter les limites pour les gros fichiers
php_admin_value[memory_limit] = 128M
php_admin_value[upload_max_filesize] = 150M
php_admin_value[post_max_size] = 150M
EOF
    
    systemctl restart php8.2-fpm
    log_info "✓ PHP-FPM configuré pour le streaming"
}

# =============================================================================
# 4. CRÉER UN SCRIPT DE CONVERSION VIDÉO OPTIMISÉ
# =============================================================================

create_video_converter() {
    log_info "Création du script de conversion vidéo optimisé..."
    
    cat > "$SCRIPTS_DIR/convert-video-optimized.sh" << 'EOF'
#!/bin/bash
# Script de conversion vidéo optimisé pour Raspberry Pi

set -euo pipefail

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Vérifier les arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_video> [output_video]"
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.*}_converted.mp4}"

# Détecter les caractéristiques du système
CORES=$(nproc)
MAX_THREADS=$((CORES / 2))
if [ $MAX_THREADS -lt 1 ]; then
    MAX_THREADS=1
fi

echo -e "${GREEN}[INFO]${NC} Conversion de: $INPUT"
echo -e "${GREEN}[INFO]${NC} Vers: $OUTPUT"
echo -e "${GREEN}[INFO]${NC} Utilisation de $MAX_THREADS threads"

# Options de conversion optimisées
FFMPEG_OPTS=(
    -threads $MAX_THREADS
    -c:v libx264
    -preset ultrafast      # Plus rapide, qualité acceptable
    -crf 23               # Qualité raisonnable
    -profile:v baseline   # Compatibilité maximale
    -level:v 3.1         # Compatible avec décodage hardware Pi
    -c:a aac
    -b:a 128k
    -ar 44100
    -movflags +faststart  # Optimiser pour streaming
    -progress pipe:1      # Afficher la progression
)

# Si accélération hardware disponible pour le décodage
if [ -e /dev/video10 ] || [ -e /dev/video11 ]; then
    echo -e "${GREEN}[INFO]${NC} Accélération hardware V4L2 détectée"
    # Note: h264_v4l2m2m pour l'encodage peut être instable
fi

# Lancer la conversion avec priorité réduite
echo -e "${YELLOW}[CONVERSION]${NC} Début de la conversion..."
if nice -n 10 ffmpeg -i "$INPUT" "${FFMPEG_OPTS[@]}" -y "$OUTPUT"; then
    echo -e "${GREEN}[SUCCESS]${NC} Conversion terminée: $OUTPUT"
    
    # Afficher les infos du fichier
    echo -e "${GREEN}[INFO]${NC} Informations du fichier converti:"
    ffprobe -v quiet -print_format json -show_format -show_streams "$OUTPUT" | \
        jq -r '.streams[] | select(.codec_type=="video") | "  Codec: \(.codec_name)\n  Résolution: \(.width)x\(.height)\n  Framerate: \(.r_frame_rate)"'
else
    echo -e "${RED}[ERROR]${NC} Échec de la conversion"
    exit 1
fi
EOF
    
    chmod 755 "$SCRIPTS_DIR/convert-video-optimized.sh"
    log_info "✓ Script de conversion vidéo créé"
}

# =============================================================================
# 5. CRÉER UN MONITEUR DE PROGRESSION
# =============================================================================

create_progress_monitor() {
    log_info "Création du moniteur de progression..."
    
    cat > "$SCRIPTS_DIR/progress-monitor.sh" << 'EOF'
#!/bin/bash
# Moniteur de progression pour les téléchargements et conversions

PROGRESS_DIR="/tmp/pi-signage-progress"
mkdir -p "$PROGRESS_DIR"

# Fonction pour lire la dernière ligne d'un fichier
get_last_progress() {
    local file="$1"
    if [ -f "$file" ]; then
        tail -n 1 "$file" 2>/dev/null || echo "En cours..."
    else
        echo "En attente..."
    fi
}

# Surveiller tous les fichiers de progression
while true; do
    clear
    echo "=== Progression des tâches ==="
    echo
    
    for progress_file in "$PROGRESS_DIR"/*.progress; do
        if [ -f "$progress_file" ]; then
            basename=$(basename "$progress_file" .progress)
            progress=$(get_last_progress "$progress_file")
            echo "[$basename] $progress"
        fi
    done
    
    if [ ! "$(ls -A $PROGRESS_DIR 2>/dev/null)" ]; then
        echo "Aucune tâche en cours"
    fi
    
    echo
    echo "Appuyez sur Ctrl+C pour quitter"
    sleep 1
done
EOF
    
    chmod 755 "$SCRIPTS_DIR/progress-monitor.sh"
    log_info "✓ Moniteur de progression créé"
}

# =============================================================================
# 6. METTRE À JOUR LES PERMISSIONS SUDO
# =============================================================================

update_sudoers() {
    log_info "Mise à jour des permissions sudo..."
    
    # Ajouter les nouveaux scripts aux permissions
    cat >> /etc/sudoers.d/pi-signage-web << 'EOF'
www-data ALL=(ALL) NOPASSWD: /opt/scripts/ffmpeg-wrapper.sh
www-data ALL=(ALL) NOPASSWD: /opt/scripts/convert-video-optimized.sh
www-data ALL=(ALL) NOPASSWD: /usr/bin/nice
EOF
    
    # Valider la configuration
    if visudo -c -f /etc/sudoers.d/pi-signage-web >/dev/null 2>&1; then
        log_info "✓ Permissions sudo mises à jour"
    else
        log_error "Configuration sudoers invalide!"
        return 1
    fi
}

# =============================================================================
# 7. CRÉER UN SCRIPT DE TEST
# =============================================================================

create_test_script() {
    log_info "Création du script de test..."
    
    cat > "$SCRIPTS_DIR/test-verbose-output.sh" << 'EOF'
#!/bin/bash
# Script de test pour vérifier le feedback verbose

echo "=== Test du feedback verbose ==="
echo

# Test 1: yt-dlp
echo "1. Test yt-dlp avec une courte vidéo:"
echo "Commande: sudo -u www-data /opt/scripts/yt-dlp-wrapper.sh -o /tmp/test.mp4 https://www.youtube.com/watch?v=jNQXAC9IVRw"
echo "Appuyez sur Entrée pour continuer..."
read

sudo -u www-data /opt/scripts/yt-dlp-wrapper.sh \
    -o /tmp/test.mp4 \
    "https://www.youtube.com/watch?v=jNQXAC9IVRw"

echo
echo "2. Test ffmpeg conversion:"
if [ -f /tmp/test.mp4 ]; then
    echo "Commande: /opt/scripts/ffmpeg-wrapper.sh -i /tmp/test.mp4 -c:v copy -c:a copy /tmp/test_converted.mp4"
    /opt/scripts/ffmpeg-wrapper.sh -i /tmp/test.mp4 -c:v copy -c:a copy /tmp/test_converted.mp4
fi

echo
echo "3. Nettoyage des fichiers de test..."
rm -f /tmp/test.mp4 /tmp/test_converted.mp4

echo
echo "=== Test terminé ==="
EOF
    
    chmod 755 "$SCRIPTS_DIR/test-verbose-output.sh"
    log_info "✓ Script de test créé"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== Application du patch verbose et optimisations ffmpeg ==="
    
    # Vérifier les prérequis
    if ! command -v ffmpeg >/dev/null 2>&1; then
        log_error "ffmpeg n'est pas installé"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_warn "Installation de jq pour le parsing JSON..."
        apt-get update && apt-get install -y jq
    fi
    
    # Appliquer les modifications
    update_ytdlp_wrapper
    create_ffmpeg_wrapper
    update_php_fpm_config
    create_video_converter
    create_progress_monitor
    update_sudoers
    create_test_script
    
    # Créer les répertoires nécessaires
    mkdir -p /tmp/pi-signage-progress
    chmod 777 /tmp/pi-signage-progress
    
    log_info ""
    log_info "=== Patch appliqué avec succès ==="
    log_info ""
    log_info "Nouveaux outils disponibles:"
    log_info "  - $SCRIPTS_DIR/ffmpeg-wrapper.sh : FFmpeg optimisé avec verbose"
    log_info "  - $SCRIPTS_DIR/convert-video-optimized.sh : Conversion vidéo optimisée"
    log_info "  - $SCRIPTS_DIR/progress-monitor.sh : Moniteur de progression"
    log_info "  - $SCRIPTS_DIR/test-verbose-output.sh : Script de test"
    log_info ""
    log_info "Le wrapper yt-dlp a été mis à jour pour afficher la progression."
    log_info "PHP-FPM a été configuré pour le streaming temps réel."
    log_info ""
    log_info "Pour tester: sudo $SCRIPTS_DIR/test-verbose-output.sh"
}

# Vérification root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

main "$@"