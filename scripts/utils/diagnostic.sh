#!/bin/bash
# PiSignage Desktop v3.0 - Diagnostic Script
# Diagnostic complet du système PiSignage

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly REPORT_FILE="/tmp/pisignage-diagnostic-$(date '+%Y%m%d_%H%M%S').txt"

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Variables
VERBOSE=false
SAVE_REPORT=false
FIX_ISSUES=false

# Fonctions utilitaires
info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$REPORT_FILE"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*" | tee -a "$REPORT_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$REPORT_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$REPORT_FILE"
}

# Aide
show_help() {
    cat << EOF
PiSignage Desktop v3.0 - Diagnostic Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Affiche cette aide
    -v, --verbose       Mode verbeux
    -s, --save          Sauvegarde le rapport
    -f, --fix           Tente de corriger les problèmes

Exemples:
    $0                  # Diagnostic standard
    $0 -v -s           # Diagnostic verbeux avec sauvegarde
    $0 -f              # Diagnostic avec correction automatique

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
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -s|--save)
                SAVE_REPORT=true
                shift
                ;;
            -f|--fix)
                FIX_ISSUES=true
                shift
                ;;
            *)
                error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# En-tête du rapport
create_report_header() {
    cat > "$REPORT_FILE" << EOF
PiSignage Desktop v3.0 - Rapport de Diagnostic
==============================================

Date: $(date)
Hostname: $(hostname)
Utilisateur: $(whoami)
Répertoire PiSignage: $BASE_DIR

EOF
}

# Diagnostic système
check_system() {
    echo | tee -a "$REPORT_FILE"
    info "=== DIAGNOSTIC SYSTÈME ==="
    
    # Version du système
    if [[ -f /etc/os-release ]]; then
        local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
        info "OS: $os_info"
    fi
    
    # Architecture
    local arch=$(uname -m)
    info "Architecture: $arch"
    
    # Raspberry Pi spécifique
    if [[ -f /proc/cpuinfo ]]; then
        if grep -q "Raspberry Pi" /proc/cpuinfo || grep -q "BCM" /proc/cpuinfo; then
            success "Raspberry Pi détecté"
            
            # Modèle
            local model=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//' || echo "Inconnu")
            info "Modèle: $model"
            
            # Température
            if [[ -f /opt/vc/bin/vcgencmd ]]; then
                local temp=$(/opt/vc/bin/vcgencmd measure_temp | cut -d= -f2)
                info "Température CPU: $temp"
                
                # Alerte température
                local temp_value=$(echo "$temp" | cut -d"'" -f1)
                if (( $(echo "$temp_value > 70" | bc -l) )); then
                    warn "Température élevée: $temp"
                fi
            fi
        else
            warn "Système non-Raspberry Pi"
        fi
    fi
    
    # Mémoire
    local memory_info=$(free -h | awk 'NR==2{printf "%s utilisé / %s total (%.1f%%)", $3, $2, $3/$2*100}')
    info "Mémoire: $memory_info"
    
    # Espace disque
    local disk_info=$(df -h / | awk 'NR==2{printf "%s utilisé / %s total (%s)", $3, $2, $5}')
    info "Disque: $disk_info"
    
    # Charge système
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')
    info "Charge système:$load_avg"
}

# Diagnostic des dépendances
check_dependencies() {
    echo | tee -a "$REPORT_FILE"
    info "=== DIAGNOSTIC DÉPENDANCES ==="
    
    local dependencies=(
        "chromium-browser"
        "xdotool"
        "unclutter"
        "nginx"
        "nodejs"
        "npm"
        "git"
        "curl"
        "wget"
        "vlc"
        "omxplayer"
        "ffmpeg"
    )
    
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if command -v "$dep" &> /dev/null; then
            if [[ "$VERBOSE" == true ]]; then
                local version=$(command -v "$dep" --version 2>/dev/null | head -n1 || echo "version inconnue")
                success "$dep installé ($version)"
            else
                success "$dep installé"
            fi
        else
            error "$dep manquant"
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        success "Toutes les dépendances sont installées"
    else
        warn "${#missing_deps[@]} dépendances manquantes"
        
        if [[ "$FIX_ISSUES" == true ]]; then
            info "Installation des dépendances manquantes..."
            apt-get update
            for dep in "${missing_deps[@]}"; do
                apt-get install -y "$dep" || warn "Échec installation $dep"
            done
        fi
    fi
}

# Diagnostic des services
check_services() {
    echo | tee -a "$REPORT_FILE"
    info "=== DIAGNOSTIC SERVICES ==="
    
    # Nginx
    if systemctl is-active --quiet nginx; then
        success "Nginx actif"
        
        # Configuration
        if [[ -f /etc/nginx/sites-enabled/pisignage ]]; then
            success "Configuration Nginx PiSignage présente"
        else
            warn "Configuration Nginx PiSignage manquante"
        fi
        
        # Test de connectivité
        if curl -sf http://localhost > /dev/null 2>&1; then
            success "Interface web accessible"
        else
            error "Interface web non accessible"
        fi
    else
        error "Nginx inactif"
        
        if [[ "$FIX_ISSUES" == true ]]; then
            info "Redémarrage de Nginx..."
            systemctl start nginx || error "Échec redémarrage Nginx"
        fi
    fi
    
    # X11/Display
    if [[ -n "${DISPLAY:-}" ]]; then
        success "DISPLAY configuré: $DISPLAY"
    else
        warn "DISPLAY non configuré"
        export DISPLAY=:0
    fi
    
    # Test X11
    if command -v xdpyinfo &> /dev/null; then
        if xdpyinfo > /dev/null 2>&1; then
            success "X11 accessible"
        else
            error "X11 non accessible"
        fi
    fi
}

# Diagnostic PiSignage
check_pisignage() {
    echo | tee -a "$REPORT_FILE"
    info "=== DIAGNOSTIC PISIGNAGE ==="
    
    # Version
    if [[ -f "$BASE_DIR/VERSION" ]]; then
        local version=$(cat "$BASE_DIR/VERSION")
        info "Version PiSignage: $version"
    else
        warn "Fichier VERSION manquant"
    fi
    
    # Structure des répertoires
    local required_dirs=(
        "scripts/control"
        "scripts/utils"
        "templates"
        "config"
        "videos"
        "logs"
        "web"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$BASE_DIR/$dir" ]]; then
            success "Répertoire $dir présent"
        else
            warn "Répertoire $dir manquant"
            
            if [[ "$FIX_ISSUES" == true ]]; then
                mkdir -p "$BASE_DIR/$dir"
                info "Répertoire $dir créé"
            fi
        fi
    done
    
    # Scripts principaux
    local required_scripts=(
        "install.sh"
        "uninstall.sh"
        "scripts/control/start.sh"
        "scripts/control/stop.sh"
        "scripts/control/status.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        local script_path="$BASE_DIR/$script"
        if [[ -f "$script_path" ]]; then
            if [[ -x "$script_path" ]]; then
                success "Script $script présent et exécutable"
            else
                warn "Script $script non exécutable"
                
                if [[ "$FIX_ISSUES" == true ]]; then
                    chmod +x "$script_path"
                    info "Permissions corrigées pour $script"
                fi
            fi
        else
            error "Script $script manquant"
        fi
    done
    
    # Processus en cours
    local pid_file="/tmp/pisignage.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            success "PiSignage en cours (PID: $pid)"
            
            # Informations du processus
            local process_info=$(ps -p "$pid" -o pid,ppid,cmd --no-headers)
            info "Processus: $process_info"
            
            # Utilisation mémoire
            local memory=$(ps -p "$pid" -o rss --no-headers | awk '{printf "%.1f MB", $1/1024}')
            info "Mémoire utilisée: $memory"
        else
            warn "Fichier PID présent mais processus absent"
            rm -f "$pid_file"
        fi
    else
        warn "PiSignage non démarré"
    fi
}

# Diagnostic réseau
check_network() {
    echo | tee -a "$REPORT_FILE"
    info "=== DIAGNOSTIC RÉSEAU ==="
    
    # Interfaces réseau
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    info "Interfaces: $(echo $interfaces | tr '\n' ' ')"
    
    # Adresses IP
    local ip_addresses=$(hostname -I)
    if [[ -n "$ip_addresses" ]]; then
        success "Adresses IP: $ip_addresses"
    else
        error "Aucune adresse IP"
    fi
    
    # Connectivité internet
    if ping -c 1 8.8.8.8 &> /dev/null; then
        success "Connectivité internet OK"
    else
        warn "Pas de connectivité internet"
    fi
    
    # DNS
    if nslookup google.com &> /dev/null; then
        success "Résolution DNS OK"
    else
        warn "Problème résolution DNS"
    fi
}

# Diagnostic des logs
check_logs() {
    echo | tee -a "$REPORT_FILE"
    info "=== DIAGNOSTIC LOGS ==="
    
    local log_files=(
        "$BASE_DIR/logs/pisignage.log"
        "$BASE_DIR/logs/install.log"
        "/var/log/nginx/error.log"
        "/var/log/syslog"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local size=$(du -h "$log_file" | cut -f1)
            info "Log $log_file: $size"
            
            if [[ "$VERBOSE" == true ]]; then
                echo "--- Dernières lignes de $log_file ---" >> "$REPORT_FILE"
                tail -n 5 "$log_file" >> "$REPORT_FILE" 2>/dev/null || true
                echo "--- Fin ---" >> "$REPORT_FILE"
            fi
        else
            warn "Log $log_file manquant"
        fi
    done
}

# Test de performance
check_performance() {
    echo | tee -a "$REPORT_FILE"
    info "=== TEST PERFORMANCE ==="
    
    # Test lecture vidéo
    if command -v ffmpeg &> /dev/null; then
        local test_video="/tmp/test_video.mp4"
        
        # Création d'une vidéo de test
        if ffmpeg -f lavfi -i testsrc=duration=5:size=1920x1080:rate=30 -pix_fmt yuv420p "$test_video" &>/dev/null; then
            success "Création vidéo test OK"
            
            # Test de décodage
            local decode_time=$(time ffmpeg -i "$test_video" -f null - 2>&1 | grep "real" | awk '{print $2}' || echo "N/A")
            info "Temps décodage: $decode_time"
            
            rm -f "$test_video"
        else
            warn "Échec création vidéo test"
        fi
    fi
    
    # Test GPU (Raspberry Pi)
    if [[ -f /opt/vc/bin/vcgencmd ]]; then
        local gpu_mem=$(/opt/vc/bin/vcgencmd get_mem gpu | cut -d= -f2)
        info "Mémoire GPU: $gpu_mem"
        
        if [[ "${gpu_mem%M}" -lt 64 ]]; then
            warn "Mémoire GPU faible (recommandé: 128M+)"
        fi
    fi
}

# Recommandations
show_recommendations() {
    echo | tee -a "$REPORT_FILE"
    info "=== RECOMMANDATIONS ==="
    
    # Analyse des problèmes détectés
    local issues=$(grep -c "ERROR" "$REPORT_FILE" 2>/dev/null || echo 0)
    local warnings=$(grep -c "WARN" "$REPORT_FILE" 2>/dev/null || echo 0)
    
    if [[ $issues -eq 0 && $warnings -eq 0 ]]; then
        success "Aucun problème détecté!"
    else
        if [[ $issues -gt 0 ]]; then
            error "$issues erreur(s) détectée(s)"
        fi
        if [[ $warnings -gt 0 ]]; then
            warn "$warnings avertissement(s)"
        fi
        
        echo | tee -a "$REPORT_FILE"
        info "Recommandations:"
        
        # Recommandations spécifiques
        if grep -q "Nginx inactif" "$REPORT_FILE"; then
            echo "• Redémarrer Nginx: sudo systemctl restart nginx" | tee -a "$REPORT_FILE"
        fi
        
        if grep -q "Température élevée" "$REPORT_FILE"; then
            echo "• Vérifier la ventilation du Raspberry Pi" | tee -a "$REPORT_FILE"
        fi
        
        if grep -q "manquant" "$REPORT_FILE"; then
            echo "• Réinstaller les dépendances manquantes" | tee -a "$REPORT_FILE"
        fi
        
        if grep -q "Mémoire GPU faible" "$REPORT_FILE"; then
            echo "• Augmenter gpu_mem dans /boot/config.txt" | tee -a "$REPORT_FILE"
        fi
    fi
}

# Résumé du diagnostic
show_summary() {
    echo | tee -a "$REPORT_FILE"
    success "=== RÉSUMÉ DU DIAGNOSTIC ==="
    
    local total_checks=$(grep -c "\[INFO\]" "$REPORT_FILE" 2>/dev/null || echo 0)
    local success_count=$(grep -c "\[OK\]" "$REPORT_FILE" 2>/dev/null || echo 0)
    local warning_count=$(grep -c "\[WARN\]" "$REPORT_FILE" 2>/dev/null || echo 0)
    local error_count=$(grep -c "\[ERROR\]" "$REPORT_FILE" 2>/dev/null || echo 0)
    
    info "Vérifications: $total_checks"
    success "Succès: $success_count"
    warn "Avertissements: $warning_count"
    error "Erreurs: $error_count"
    
    echo | tee -a "$REPORT_FILE"
    
    if [[ $error_count -eq 0 && $warning_count -eq 0 ]]; then
        success "PiSignage Desktop fonctionne parfaitement!"
    elif [[ $error_count -eq 0 ]]; then
        warn "PiSignage Desktop fonctionne avec quelques avertissements"
    else
        error "PiSignage Desktop a des problèmes à corriger"
    fi
    
    if [[ "$SAVE_REPORT" == true ]]; then
        echo
        info "Rapport sauvegardé: $REPORT_FILE"
    fi
}

# Fonction principale
main() {
    echo "=== PiSignage Desktop v3.0 - Diagnostic ==="
    
    # Parse des arguments
    parse_arguments "$@"
    
    # Création du rapport
    create_report_header
    
    # Diagnostic complet
    check_system
    check_dependencies
    check_services
    check_pisignage
    check_network
    check_logs
    check_performance
    show_recommendations
    show_summary
    
    # Nettoyage du rapport temporaire si pas de sauvegarde
    if [[ "$SAVE_REPORT" != true ]]; then
        rm -f "$REPORT_FILE"
    fi
    
    success "Diagnostic terminé!"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi