#!/bin/bash

# Pi-Signage v0.8.1 - Script de Validation Complet
# Test et validation de l'installation sur Raspberry Pi OS Bookworm
# Date: 2025-09-25

set -e

# Configuration
PISIGNAGE_DIR="/opt/pisignage"
LOG_FILE="/var/log/pisignage-validation.log"
REPORT_FILE="/tmp/pisignage-validation-report.txt"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Compteurs
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# Logging
log() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_FAILED++))
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_WARNED++))
}

info() {
    echo -e "${BLUE}[i]${NC} $1" | tee -a "$LOG_FILE"
}

header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}  $1${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
}

# Test unitaire avec résultat
run_test() {
    local test_name="$1"
    local test_cmd="$2"

    echo -n "  Testing $test_name... "

    if eval "$test_cmd" &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Début du rapport
start_report() {
    cat > "$REPORT_FILE" << EOF
═══════════════════════════════════════════════════════════════
     Pi-Signage v0.8.1 - Rapport de Validation
     Date: $(date '+%Y-%m-%d %H:%M:%S')
     Hostname: $(hostname)
═══════════════════════════════════════════════════════════════

EOF
}

# 1. VALIDATION SYSTÈME
validate_system() {
    header "1. VALIDATION SYSTÈME"

    # OS Version
    info "Vérification de l'OS..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        info "OS: $NAME $VERSION ($VERSION_CODENAME)"

        if [[ "$VERSION_CODENAME" == "bookworm" ]]; then
            log "OS Bookworm détecté"
        else
            warning "OS non-Bookworm détecté - compatibilité limitée"
        fi
    else
        error "Impossible de détecter l'OS"
    fi

    # Modèle Pi
    info "Détection du modèle Raspberry Pi..."
    if [ -f /proc/cpuinfo ]; then
        PI_MODEL=$(grep "Model" /proc/cpuinfo | cut -d':' -f2 | xargs || echo "Unknown")
        info "Modèle: $PI_MODEL"

        if [[ "$PI_MODEL" == *"Pi 4"* ]] || [[ "$PI_MODEL" == *"Pi 5"* ]]; then
            log "Modèle supporté avec accélération complète"
        elif [[ "$PI_MODEL" == *"Pi 3"* ]] || [[ "$PI_MODEL" == *"Zero 2"* ]]; then
            warning "Modèle avec accélération partielle"
        else
            warning "Modèle non testé"
        fi
    fi

    # Kernel
    info "Kernel: $(uname -r)"

    # Mémoire
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    info "Mémoire totale: ${TOTAL_MEM}MB"
    if [ "$TOTAL_MEM" -lt 512 ]; then
        warning "Mémoire faible (<512MB)"
    fi

    # Espace disque
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    info "Utilisation disque: ${DISK_USAGE}%"
    if [ "$DISK_USAGE" -gt 80 ]; then
        warning "Espace disque faible (>80%)"
    fi
}

# 2. VALIDATION DES PAQUETS
validate_packages() {
    header "2. VALIDATION DES PAQUETS"

    local required_packages=(
        "mpv"
        "vlc"
        "raspberrypi-ffmpeg"
        "seatd"
        "v4l-utils"
        "libdrm2"
        "mesa-utils"
    )

    for package in "${required_packages[@]}"; do
        run_test "$package" "dpkg -l | grep -q '^ii.*$package'"
    done

    # Test ffmpeg spécifique Raspberry Pi
    info "Test ffmpeg Raspberry Pi..."
    if ffmpeg -version 2>/dev/null | grep -q "raspberrypi"; then
        log "ffmpeg Raspberry Pi détecté"
    else
        if ffmpeg -decoders 2>/dev/null | grep -q "h264_v4l2m2m"; then
            log "Décodeurs V4L2M2M disponibles"
        else
            error "Pas de décodeurs V4L2M2M"
        fi
    fi
}

# 3. VALIDATION DES PERMISSIONS
validate_permissions() {
    header "3. VALIDATION DES PERMISSIONS"

    # Utilisateur courant
    CURRENT_USER="${USER:-$(whoami)}"
    info "Utilisateur: $CURRENT_USER"

    # Groupes requis
    local required_groups=("video" "render" "audio" "input")

    for group in "${required_groups[@]}"; do
        if id -nG "$CURRENT_USER" | grep -q "\b$group\b"; then
            log "Membre du groupe: $group"
        else
            error "Pas membre du groupe: $group"
        fi
    done

    # Accès DRM
    run_test "/dev/dri/card0" "[ -r /dev/dri/card0 ]"
    run_test "/dev/dri/renderD128" "[ -r /dev/dri/renderD128 ]"

    # Accès V4L2
    if ls /dev/video* 2>/dev/null | grep -E 'video1[0-9]' > /dev/null; then
        log "Devices V4L2 accessibles"
    else
        warning "Pas de devices V4L2 trouvés"
    fi
}

# 4. VALIDATION ENVIRONNEMENT GRAPHIQUE
validate_display() {
    header "4. VALIDATION ENVIRONNEMENT GRAPHIQUE"

    # Détection du serveur d'affichage
    if [ -n "$WAYLAND_DISPLAY" ]; then
        log "Wayland détecté: $WAYLAND_DISPLAY"

        # Test compositeur
        for compositor in labwc wayfire weston sway; do
            if pgrep -x "$compositor" > /dev/null; then
                log "Compositeur: $compositor"
                break
            fi
        done

        # Test seatd
        if systemctl is-active seatd >/dev/null 2>&1; then
            log "seatd actif"
        else
            error "seatd inactif"
        fi

        # XDG Runtime
        if [ -n "$XDG_RUNTIME_DIR" ]; then
            log "XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
        else
            warning "XDG_RUNTIME_DIR non défini"
        fi

    elif [ -n "$DISPLAY" ]; then
        log "X11 détecté: $DISPLAY"

        # Test X11
        if command -v xrandr &> /dev/null; then
            if xrandr 2>/dev/null | grep -q " connected"; then
                log "Écran X11 connecté"
            fi
        fi

    else
        warning "Mode TTY/console (pas d'environnement graphique)"

        # Test DRM direct
        if [ -e /dev/dri/card0 ]; then
            log "DRM direct disponible"
        fi
    fi
}

# 5. VALIDATION ACCÉLÉRATION MATÉRIELLE
validate_hw_acceleration() {
    header "5. VALIDATION ACCÉLÉRATION MATÉRIELLE"

    # Test V4L2
    info "Test V4L2-ctl..."
    if command -v v4l2-ctl &> /dev/null; then
        local v4l2_devices=$(v4l2-ctl --list-devices 2>/dev/null | grep -c "^/dev/video" || echo "0")
        info "Devices V4L2: $v4l2_devices"

        # Test décodeurs
        for device in /dev/video10 /dev/video11 /dev/video12; do
            if [ -e "$device" ]; then
                log "Device V4L2 trouvé: $device"
            fi
        done
    else
        warning "v4l2-ctl non installé"
    fi

    # Test Mesa/OpenGL
    info "Test OpenGL..."
    if command -v glxinfo &> /dev/null; then
        if glxinfo 2>/dev/null | grep -q "OpenGL renderer"; then
            RENDERER=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d':' -f2 | xargs)
            log "OpenGL renderer: $RENDERER"
        fi
    elif command -v eglinfo &> /dev/null; then
        if eglinfo 2>/dev/null | grep -q "EGL vendor"; then
            log "EGL disponible"
        fi
    else
        warning "Impossible de tester OpenGL/EGL"
    fi

    # Test DRM
    info "Test DRM..."
    if command -v modetest &> /dev/null; then
        if modetest -M vc4 -c 2>/dev/null | grep -q "CRTC"; then
            log "DRM VC4 disponible"
        elif modetest -M v3d -c 2>/dev/null | grep -q "CRTC"; then
            log "DRM V3D disponible"
        fi
    fi
}

# 6. TEST DES LECTEURS VIDÉO
test_video_players() {
    header "6. TEST DES LECTEURS VIDÉO"

    # Création vidéo de test si nécessaire
    TEST_VIDEO="/tmp/test-pisignage.mp4"
    if [ ! -f "$TEST_VIDEO" ]; then
        info "Création d'une vidéo de test..."
        ffmpeg -f lavfi -i testsrc=duration=5:size=320x240:rate=30 \
               -f lavfi -i sine=frequency=1000:duration=5 \
               -c:v h264 -c:a aac -y "$TEST_VIDEO" 2>/dev/null || \
        warning "Impossible de créer la vidéo de test"
    fi

    # Test MPV
    info "Test MPV..."
    if command -v mpv &> /dev/null; then
        # Test basique
        if timeout 5 mpv --vo=null --ao=null --frames=10 "$TEST_VIDEO" &>/dev/null; then
            log "MPV: décodage basique OK"
        else
            error "MPV: échec décodage basique"
        fi

        # Test avec accélération HW
        if timeout 5 mpv --hwdec=auto --vo=null --ao=null --frames=10 "$TEST_VIDEO" &>/dev/null; then
            log "MPV: accélération HW OK"
        else
            warning "MPV: pas d'accélération HW"
        fi

        # Version MPV
        MPV_VERSION=$(mpv --version | head -n1)
        info "Version: $MPV_VERSION"
    else
        error "MPV non installé"
    fi

    # Test VLC
    info "Test VLC..."
    if command -v vlc &> /dev/null; then
        # Test basique
        if timeout 5 vlc --intf=dummy --play-and-exit --stop-time=1 "$TEST_VIDEO" vlc://quit &>/dev/null; then
            log "VLC: lecture basique OK"
        else
            error "VLC: échec lecture"
        fi

        # Version VLC
        VLC_VERSION=$(vlc --version 2>/dev/null | head -n1)
        info "Version: $VLC_VERSION"
    else
        error "VLC non installé"
    fi
}

# 7. TEST DES SERVICES
test_services() {
    header "7. TEST DES SERVICES"

    # Test service systemd user
    info "Test services systemd user..."

    # Vérification que loginctl fonctionne
    if command -v loginctl &> /dev/null; then
        if loginctl show-user "$USER" &>/dev/null; then
            log "Session utilisateur active"

            # Linger status
            if loginctl show-user "$USER" | grep -q "Linger=yes"; then
                log "Linger activé (démarrage au boot)"
            else
                warning "Linger désactivé (pas de démarrage auto)"
            fi
        fi
    fi

    # Test si le service existe
    SERVICE_FILE="$HOME/.config/systemd/user/pisignage-player.service"
    if [ -f "$SERVICE_FILE" ]; then
        log "Service utilisateur présent"

        # Status du service
        if systemctl --user is-enabled pisignage-player.service &>/dev/null; then
            log "Service activé"
        else
            warning "Service désactivé"
        fi

        if systemctl --user is-active pisignage-player.service &>/dev/null; then
            log "Service actif"
        else
            info "Service inactif"
        fi
    else
        warning "Service utilisateur non installé"
    fi
}

# 8. TEST DE PERFORMANCE
test_performance() {
    header "8. TEST DE PERFORMANCE"

    # CPU
    info "Test CPU..."
    CPU_CORES=$(nproc)
    info "Cores CPU: $CPU_CORES"

    # Température
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
        TEMP_C=$((TEMP/1000))
        info "Température CPU: ${TEMP_C}°C"

        if [ "$TEMP_C" -gt 80 ]; then
            warning "Température élevée (>80°C)"
        elif [ "$TEMP_C" -gt 70 ]; then
            info "Température modérée (>70°C)"
        else
            log "Température normale"
        fi
    fi

    # Test de charge avec vidéo
    if [ -f "$TEST_VIDEO" ] && command -v mpv &>/dev/null; then
        info "Test de charge vidéo (10 secondes)..."

        # Lancement en arrière-plan
        timeout 10 mpv --vo=null --ao=null --hwdec=auto "$TEST_VIDEO" &>/dev/null &
        MPV_PID=$!

        sleep 2

        if kill -0 $MPV_PID 2>/dev/null; then
            # Mesure CPU
            CPU_USAGE=$(ps -p $MPV_PID -o %cpu= 2>/dev/null | xargs)
            info "Utilisation CPU MPV: ${CPU_USAGE}%"

            if (( $(echo "$CPU_USAGE > 50" | bc -l) )); then
                warning "Utilisation CPU élevée (>50%)"
            else
                log "Utilisation CPU acceptable"
            fi

            kill $MPV_PID 2>/dev/null || true
        fi
    fi
}

# 9. VALIDATION RÉSEAU (optionnel)
validate_network() {
    header "9. VALIDATION RÉSEAU (Optionnel)"

    # Connectivité
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        log "Connectivité Internet OK"
    else
        warning "Pas de connectivité Internet"
    fi

    # Interface réseau
    if command -v ip &>/dev/null; then
        INTERFACES=$(ip -o link show | grep "state UP" | awk '{print $2}' | sed 's/://')
        for iface in $INTERFACES; do
            info "Interface active: $iface"
        done
    fi
}

# 10. DIAGNOSTIC AVANCÉ
advanced_diagnostics() {
    header "10. DIAGNOSTIC AVANCÉ"

    # Vérification des logs
    info "Vérification des logs..."

    if [ -d "$PISIGNAGE_DIR/logs" ]; then
        log "Répertoire logs présent"

        # Taille des logs
        LOG_SIZE=$(du -sh "$PISIGNAGE_DIR/logs" 2>/dev/null | cut -f1)
        info "Taille des logs: $LOG_SIZE"
    else
        warning "Répertoire logs absent"
    fi

    # Test script player-manager
    if [ -f "$PISIGNAGE_DIR/scripts/player-manager-v0.8.1.sh" ]; then
        log "Script player-manager présent"

        # Test environnement
        if bash "$PISIGNAGE_DIR/scripts/player-manager-v0.8.1.sh" env &>/dev/null; then
            log "Détection environnement OK"
        else
            warning "Problème détection environnement"
        fi
    else
        error "Script player-manager absent"
    fi

    # Configuration MPV
    if [ -f "$HOME/.config/mpv/mpv.conf" ]; then
        log "Configuration MPV utilisateur présente"
    elif [ -f "$PISIGNAGE_DIR/config/mpv/mpv.conf" ]; then
        log "Configuration MPV globale présente"
    else
        warning "Configuration MPV absente"
    fi
}

# Génération du rapport final
generate_report() {
    header "RÉSUMÉ DU RAPPORT"

    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))

    cat >> "$REPORT_FILE" << EOF

═══════════════════════════════════════════════════════════════
                        RÉSULTATS
═══════════════════════════════════════════════════════════════

Tests réussis:  $TESTS_PASSED
Tests échoués:  $TESTS_FAILED
Avertissements: $TESTS_WARNED
Total:          $total_tests

EOF

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         RÉSUMÉ DES TESTS              ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}✓ Réussis:${NC}     $(printf "%3d" $TESTS_PASSED)                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${RED}✗ Échoués:${NC}     $(printf "%3d" $TESTS_FAILED)                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}! Avertis:${NC}     $(printf "%3d" $TESTS_WARNED)                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Total:          $(printf "%3d" $total_tests)                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"

    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ VALIDATION RÉUSSIE - Système prêt pour Pi-Signage v0.8.1${NC}"
        cat >> "$REPORT_FILE" << EOF

STATUT: ✅ VALIDATION RÉUSSIE
Le système est prêt pour Pi-Signage v0.8.1

EOF
    else
        echo ""
        echo -e "${RED}❌ VALIDATION ÉCHOUÉE - Corrections nécessaires${NC}"
        cat >> "$REPORT_FILE" << EOF

STATUT: ❌ VALIDATION ÉCHOUÉE
Des corrections sont nécessaires avant utilisation.

RECOMMANDATIONS:
1. Vérifier l'installation des paquets manquants
2. Corriger les permissions des groupes
3. Activer les services nécessaires
4. Consulter les logs pour plus de détails

EOF
    fi

    echo ""
    echo -e "${BLUE}📄 Rapport complet sauvegardé dans: $REPORT_FILE${NC}"
    echo -e "${BLUE}📋 Logs détaillés dans: $LOG_FILE${NC}"
}

# Programme principal
main() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Pi-Signage v0.8.1 - Validation Complète          ║${NC}"
    echo -e "${CYAN}║           Optimisé pour Bookworm/Wayland             ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"

    # Initialisation
    > "$LOG_FILE"
    start_report

    # Exécution des tests
    validate_system
    validate_packages
    validate_permissions
    validate_display
    validate_hw_acceleration
    test_video_players
    test_services
    test_performance
    validate_network
    advanced_diagnostics

    # Rapport final
    generate_report

    # Nettoyage
    [ -f "$TEST_VIDEO" ] && rm -f "$TEST_VIDEO"
}

# Lancement
main "$@"