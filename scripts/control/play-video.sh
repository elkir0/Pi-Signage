#!/bin/bash
# PiSignage Desktop v3.0 - Play Video Script
# Lance une vidéo spécifique

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly VIDEOS_DIR="$BASE_DIR/videos"
readonly LOG_FILE="$BASE_DIR/logs/video-player.log"

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Variables
VIDEO_FILE=""
PLAYER="auto"
FULLSCREEN=true
LOOP=false

# Fonctions utilitaires
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Aide
show_help() {
    cat << EOF
PiSignage Desktop v3.0 - Play Video Script

Usage: $0 [OPTIONS] VIDEO_FILE

Options:
    -h, --help          Affiche cette aide
    -p, --player PLAYER Lecteur à utiliser (vlc|omx|chromium|auto)
    -w, --windowed      Mode fenêtré (pas plein écran)
    -l, --loop          Lecture en boucle
    --list              Liste les vidéos disponibles

Exemples:
    $0 video.mp4                    # Lecture automatique
    $0 -p vlc video.mp4             # Forcer VLC
    $0 -l video.mp4                 # Lecture en boucle
    $0 --list                       # Lister les vidéos

Lecteurs supportés:
    vlc      - VLC Media Player (recommandé)
    omx      - OMXPlayer (hardware accelerated)
    chromium - Chromium browser (HTML5)
    auto     - Détection automatique

EOF
}

# Parse des arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--player)
                PLAYER="$2"
                shift 2
                ;;
            -w|--windowed)
                FULLSCREEN=false
                shift
                ;;
            -l|--loop)
                LOOP=true
                shift
                ;;
            --list)
                list_videos
                exit 0
                ;;
            -*)
                error "Option inconnue: $1"
                show_help
                exit 1
                ;;
            *)
                VIDEO_FILE="$1"
                shift
                ;;
        esac
    done
}

# Liste des vidéos
list_videos() {
    echo "=== Vidéos disponibles ==="
    echo
    
    if [[ ! -d "$VIDEOS_DIR" ]]; then
        warn "Répertoire vidéos non trouvé: $VIDEOS_DIR"
        return 1
    fi
    
    local videos=$(find "$VIDEOS_DIR" -type f \( -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" -o -name "*.webm" \) 2>/dev/null)
    
    if [[ -z "$videos" ]]; then
        warn "Aucune vidéo trouvée dans $VIDEOS_DIR"
        return 1
    fi
    
    echo "$videos" | while read -r video; do
        local filename=$(basename "$video")
        local size=$(du -h "$video" | cut -f1)
        echo "  $filename ($size)"
    done
}

# Validation du fichier vidéo
validate_video_file() {
    if [[ -z "$VIDEO_FILE" ]]; then
        error "Fichier vidéo requis"
        show_help
        exit 1
    fi
    
    # Chemin absolu ou relatif
    if [[ ! -f "$VIDEO_FILE" ]]; then
        # Essayer dans le répertoire vidéos
        local video_path="$VIDEOS_DIR/$VIDEO_FILE"
        if [[ -f "$video_path" ]]; then
            VIDEO_FILE="$video_path"
        else
            error "Fichier vidéo non trouvé: $VIDEO_FILE"
            exit 1
        fi
    fi
    
    info "Fichier vidéo: $VIDEO_FILE"
}

# Détection automatique du lecteur
detect_player() {
    if [[ "$PLAYER" == "auto" ]]; then
        if command -v vlc &> /dev/null; then
            PLAYER="vlc"
        elif command -v omxplayer &> /dev/null; then
            PLAYER="omx"
        elif command -v chromium-browser &> /dev/null; then
            PLAYER="chromium"
        else
            error "Aucun lecteur vidéo disponible"
            exit 1
        fi
    fi
    
    info "Lecteur sélectionné: $PLAYER"
}

# Lecture avec VLC
play_with_vlc() {
    info "Lecture avec VLC..."
    
    local vlc_args=(
        "--intf" "dummy"
        "--quiet"
    )
    
    if [[ "$FULLSCREEN" == true ]]; then
        vlc_args+=("--fullscreen")
    fi
    
    if [[ "$LOOP" == true ]]; then
        vlc_args+=("--loop")
    fi
    
    vlc_args+=("$VIDEO_FILE")
    
    vlc "${vlc_args[@]}" > "$LOG_FILE" 2>&1 &
    local pid=$!
    
    info "VLC démarré (PID: $pid)"
    echo "$pid" > "/tmp/pisignage-video.pid"
}

# Lecture avec OMXPlayer
play_with_omx() {
    info "Lecture avec OMXPlayer..."
    
    local omx_args=()
    
    if [[ "$LOOP" == true ]]; then
        omx_args+=("--loop")
    fi
    
    omx_args+=("$VIDEO_FILE")
    
    omxplayer "${omx_args[@]}" > "$LOG_FILE" 2>&1 &
    local pid=$!
    
    info "OMXPlayer démarré (PID: $pid)"
    echo "$pid" > "/tmp/pisignage-video.pid"
}

# Lecture avec Chromium
play_with_chromium() {
    info "Lecture avec Chromium..."
    
    local chromium_flags=(
        "--autoplay-policy=no-user-gesture-required"
        "--disable-infobars"
        "--disable-session-crashed-bubble"
    )
    
    if [[ "$FULLSCREEN" == true ]]; then
        chromium_flags+=("--start-fullscreen")
    fi
    
    # Conversion du chemin en URL file://
    local video_url="file://$VIDEO_FILE"
    
    chromium-browser "${chromium_flags[@]}" "$video_url" > "$LOG_FILE" 2>&1 &
    local pid=$!
    
    info "Chromium démarré (PID: $pid)"
    echo "$pid" > "/tmp/pisignage-video.pid"
}

# Arrêt de la lecture précédente
stop_previous_player() {
    local pid_file="/tmp/pisignage-video.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            info "Arrêt du lecteur précédent (PID: $pid)..."
            kill "$pid"
        fi
        rm -f "$pid_file"
    fi
    
    # Arrêt des lecteurs en cours
    pkill vlc || true
    pkill omxplayer || true
    pkill -f "chromium.*file://" || true
}

# Fonction principale
main() {
    echo "=== PiSignage Desktop v3.0 - Play Video ==="
    echo
    
    # Parse des arguments
    parse_arguments "$@"
    
    # Validation
    validate_video_file
    detect_player
    
    # Préparation
    mkdir -p "$BASE_DIR/logs"
    stop_previous_player
    
    # Lecture selon le lecteur
    case "$PLAYER" in
        "vlc")
            play_with_vlc
            ;;
        "omx")
            play_with_omx
            ;;
        "chromium")
            play_with_chromium
            ;;
        *)
            error "Lecteur non supporté: $PLAYER"
            exit 1
            ;;
    esac
    
    success "Lecture démarrée!"
    info "Logs: $LOG_FILE"
    
    if [[ "$LOOP" == true ]]; then
        info "Mode boucle activé"
    fi
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi