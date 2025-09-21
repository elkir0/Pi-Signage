#!/bin/bash
# PiSignage Desktop v3.0 - Benchmark Script
# Test de performance du système

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly RESULTS_FILE="/tmp/pisignage-benchmark-$(date '+%Y%m%d_%H%M%S').txt"
readonly TEST_VIDEO_DIR="/tmp/pisignage-benchmark"

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Variables
QUICK_TEST=false
SAVE_RESULTS=false
VERBOSE=false

# Fonctions utilitaires
info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$RESULTS_FILE"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*" | tee -a "$RESULTS_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$RESULTS_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$RESULTS_FILE"
}

# Aide
show_help() {
    cat << EOF
PiSignage Desktop v3.0 - Benchmark Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Affiche cette aide
    -q, --quick         Test rapide (5 minutes au lieu de 15)
    -s, --save          Sauvegarde les résultats
    -v, --verbose       Mode verbeux

Exemples:
    $0                  # Benchmark complet
    $0 -q -s           # Test rapide avec sauvegarde
    $0 -v              # Benchmark verbeux

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
            -q|--quick)
                QUICK_TEST=true
                shift
                ;;
            -s|--save)
                SAVE_RESULTS=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
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

# En-tête des résultats
create_results_header() {
    cat > "$RESULTS_FILE" << EOF
PiSignage Desktop v3.0 - Rapport de Benchmark
=============================================

Date: $(date)
Hostname: $(hostname)
Type de test: $(if [[ "$QUICK_TEST" == true ]]; then echo "Rapide"; else echo "Complet"; fi)

=== CONFIGURATION SYSTÈME ===
EOF

    # Informations système
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^ *//' || echo "Inconnu")
        echo "CPU: $cpu_model" >> "$RESULTS_FILE"
        
        local cpu_cores=$(nproc)
        echo "Cœurs CPU: $cpu_cores" >> "$RESULTS_FILE"
    fi
    
    # Mémoire
    local total_mem=$(free -h | awk 'NR==2{print $2}')
    echo "RAM totale: $total_mem" >> "$RESULTS_FILE"
    
    # GPU (Raspberry Pi)
    if [[ -f /opt/vc/bin/vcgencmd ]]; then
        local gpu_mem=$(/opt/vc/bin/vcgencmd get_mem gpu | cut -d= -f2)
        echo "Mémoire GPU: $gpu_mem" >> "$RESULTS_FILE"
    fi
    
    echo >> "$RESULTS_FILE"
}

# Préparation des tests
prepare_tests() {
    info "Préparation des tests..."
    
    # Création du répertoire de test
    mkdir -p "$TEST_VIDEO_DIR"
    
    # Arrêt des processus qui pourraient interférer
    pkill vlc 2>/dev/null || true
    pkill omxplayer 2>/dev/null || true
    pkill chromium 2>/dev/null || true
    
    # Nettoyage de la mémoire
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    success "Tests préparés"
}

# Test CPU
test_cpu() {
    echo | tee -a "$RESULTS_FILE"
    info "=== TEST CPU ==="
    
    local test_duration=30
    if [[ "$QUICK_TEST" == true ]]; then
        test_duration=10
    fi
    
    info "Test de calcul intensif ($test_duration secondes)..."
    
    # Test de calcul
    local start_time=$(date +%s.%N)
    timeout "$test_duration" bash -c 'while true; do echo "scale=5000; 4*a(1)" | bc -l > /dev/null; done' 2>/dev/null || true
    local end_time=$(date +%s.%N)
    
    local duration=$(echo "$end_time - $start_time" | bc)
    info "Durée effective: ${duration}s"
    
    # Score CPU (approximatif)
    local cpu_score=$(echo "scale=0; 1000 / $duration" | bc)
    success "Score CPU: $cpu_score points"
    
    # Température après test
    if [[ -f /opt/vc/bin/vcgencmd ]]; then
        local temp_after=$(/opt/vc/bin/vcgencmd measure_temp | cut -d= -f2)
        info "Température après test: $temp_after"
    fi
}

# Test mémoire
test_memory() {
    echo | tee -a "$RESULTS_FILE"
    info "=== TEST MÉMOIRE ==="
    
    local test_size="100M"
    if [[ "$QUICK_TEST" == true ]]; then
        test_size="50M"
    fi
    
    info "Test d'écriture mémoire ($test_size)..."
    
    # Test d'écriture
    local start_time=$(date +%s.%N)
    dd if=/dev/zero of=/tmp/benchmark_memory bs=1M count=${test_size%M} 2>/dev/null || true
    local end_time=$(date +%s.%N)
    
    local write_time=$(echo "$end_time - $start_time" | bc)
    local write_speed=$(echo "scale=2; ${test_size%M} / $write_time" | bc)
    success "Vitesse écriture: ${write_speed} MB/s"
    
    # Test de lecture
    start_time=$(date +%s.%N)
    dd if=/tmp/benchmark_memory of=/dev/null bs=1M 2>/dev/null || true
    end_time=$(date +%s.%N)
    
    local read_time=$(echo "$end_time - $start_time" | bc)
    local read_speed=$(echo "scale=2; ${test_size%M} / $read_time" | bc)
    success "Vitesse lecture: ${read_speed} MB/s"
    
    # Nettoyage
    rm -f /tmp/benchmark_memory
}

# Test disque
test_disk() {
    echo | tee -a "$RESULTS_FILE"
    info "=== TEST DISQUE ==="
    
    local test_size="100M"
    if [[ "$QUICK_TEST" == true ]]; then
        test_size="50M"
    fi
    
    info "Test écriture disque ($test_size)..."
    
    # Test d'écriture séquentielle
    local start_time=$(date +%s.%N)
    dd if=/dev/zero of=/tmp/benchmark_disk bs=1M count=${test_size%M} conv=fdatasync 2>/dev/null || true
    local end_time=$(date +%s.%N)
    
    local write_time=$(echo "$end_time - $start_time" | bc)
    local write_speed=$(echo "scale=2; ${test_size%M} / $write_time" | bc)
    success "Vitesse écriture disque: ${write_speed} MB/s"
    
    # Test de lecture séquentielle
    start_time=$(date +%s.%N)
    dd if=/tmp/benchmark_disk of=/dev/null bs=1M 2>/dev/null || true
    end_time=$(date +%s.%N)
    
    local read_time=$(echo "$end_time - $start_time" | bc)
    local read_speed=$(echo "scale=2; ${test_size%M} / $read_time" | bc)
    success "Vitesse lecture disque: ${read_speed} MB/s"
    
    # Test d'écriture aléatoire
    info "Test écriture aléatoire..."
    start_time=$(date +%s.%N)
    dd if=/dev/urandom of=/tmp/benchmark_random bs=1M count=10 conv=fdatasync 2>/dev/null || true
    end_time=$(date +%s.%N)
    
    local random_time=$(echo "$end_time - $start_time" | bc)
    local random_speed=$(echo "scale=2; 10 / $random_time" | bc)
    success "Vitesse écriture aléatoire: ${random_speed} MB/s"
    
    # Nettoyage
    rm -f /tmp/benchmark_disk /tmp/benchmark_random
}

# Test réseau
test_network() {
    echo | tee -a "$RESULTS_FILE"
    info "=== TEST RÉSEAU ==="
    
    # Test de connectivité
    local ping_time=$(ping -c 1 8.8.8.8 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}' || echo "N/A")
    if [[ "$ping_time" != "N/A" ]]; then
        success "Latence internet: ${ping_time}ms"
    else
        warn "Test de latence échoué"
    fi
    
    # Test de débit (si speedtest disponible)
    if command -v speedtest-cli &> /dev/null; then
        info "Test de débit internet..."
        local speed_result=$(speedtest-cli --simple 2>/dev/null || echo "Échec")
        if [[ "$speed_result" != "Échec" ]]; then
            echo "$speed_result" | while read -r line; do
                info "$line"
            done
        else
            warn "Test de débit échoué"
        fi
    else
        warn "speedtest-cli non installé, test de débit ignoré"
    fi
    
    # Test de débit local (entre interfaces)
    local localhost_speed=$(curl -o /dev/null -s -w "%{speed_download}" http://localhost/ 2>/dev/null || echo "0")
    if [[ "$localhost_speed" != "0" ]]; then
        local speed_mbps=$(echo "scale=2; $localhost_speed / 1024 / 1024" | bc)
        success "Débit localhost: ${speed_mbps} MB/s"
    fi
}

# Test vidéo
test_video() {
    echo | tee -a "$RESULTS_FILE"
    info "=== TEST VIDÉO ==="
    
    if ! command -v ffmpeg &> /dev/null; then
        warn "FFmpeg non installé, test vidéo ignoré"
        return 1
    fi
    
    # Création d'une vidéo de test
    local test_video="$TEST_VIDEO_DIR/test_1080p.mp4"
    local test_duration=10
    
    if [[ "$QUICK_TEST" == true ]]; then
        test_duration=5
    fi
    
    info "Création d'une vidéo de test (1080p, ${test_duration}s)..."
    if ! ffmpeg -f lavfi -i testsrc=duration=${test_duration}:size=1920x1080:rate=30 -pix_fmt yuv420p "$test_video" &>/dev/null; then
        error "Échec création vidéo de test"
        return 1
    fi
    
    local video_size=$(du -h "$test_video" | cut -f1)
    info "Taille vidéo test: $video_size"
    
    # Test de décodage
    info "Test de décodage vidéo..."
    local start_time=$(date +%s.%N)
    ffmpeg -i "$test_video" -f null - &>/dev/null || true
    local end_time=$(date +%s.%N)
    
    local decode_time=$(echo "$end_time - $start_time" | bc)
    local fps_actual=$(echo "scale=2; $test_duration / $decode_time" | bc)
    success "Performance décodage: ${fps_actual}x temps réel"
    
    # Test d'encodage
    info "Test d'encodage vidéo..."
    local encoded_video="$TEST_VIDEO_DIR/test_encoded.mp4"
    start_time=$(date +%s.%N)
    ffmpeg -i "$test_video" -c:v libx264 -preset fast "$encoded_video" &>/dev/null || true
    end_time=$(date +%s.%N)
    
    local encode_time=$(echo "$end_time - $start_time" | bc)
    local encode_fps=$(echo "scale=2; $test_duration / $encode_time" | bc)
    success "Performance encodage: ${encode_fps}x temps réel"
    
    # Test avec différents lecteurs
    test_video_players "$test_video"
}

# Test des lecteurs vidéo
test_video_players() {
    local test_video="$1"
    
    info "Test des lecteurs vidéo..."
    
    # Test VLC
    if command -v vlc &> /dev/null; then
        info "Test VLC..."
        local start_time=$(date +%s.%N)
        timeout 5 vlc --intf dummy --play-and-exit "$test_video" &>/dev/null || true
        local end_time=$(date +%s.%N)
        local vlc_time=$(echo "$end_time - $start_time" | bc)
        success "VLC temps de lancement: ${vlc_time}s"
    fi
    
    # Test OMXPlayer (Raspberry Pi)
    if command -v omxplayer &> /dev/null; then
        info "Test OMXPlayer..."
        local start_time=$(date +%s.%N)
        timeout 5 omxplayer --no-keys "$test_video" &>/dev/null || true
        local end_time=$(date +%s.%N)
        local omx_time=$(echo "$end_time - $start_time" | bc)
        success "OMXPlayer temps de lancement: ${omx_time}s"
    fi
}

# Test interface web
test_web_interface() {
    echo | tee -a "$RESULTS_FILE"
    info "=== TEST INTERFACE WEB ==="
    
    # Test de réponse
    local start_time=$(date +%s.%N)
    local http_code=$(curl -o /dev/null -s -w "%{http_code}" http://localhost/ || echo "000")
    local end_time=$(date +%s.%N)
    
    local response_time=$(echo "scale=3; ($end_time - $start_time) * 1000" | bc)
    
    if [[ "$http_code" == "200" ]]; then
        success "Interface web accessible (${response_time}ms)"
    else
        error "Interface web non accessible (code: $http_code)"
    fi
    
    # Test de charge
    if command -v ab &> /dev/null; then
        info "Test de charge (Apache Bench)..."
        local ab_result=$(ab -n 100 -c 10 http://localhost/ 2>/dev/null | grep "Requests per second" | awk '{print $4}' || echo "N/A")
        if [[ "$ab_result" != "N/A" ]]; then
            success "Requêtes par seconde: $ab_result"
        fi
    else
        warn "Apache Bench non installé, test de charge ignoré"
    fi
}

# Test de stress global
test_stress() {
    if [[ "$QUICK_TEST" == true ]]; then
        return 0
    fi
    
    echo | tee -a "$RESULTS_FILE"
    info "=== TEST DE STRESS ==="
    
    info "Test de stress combiné (CPU + Mémoire + IO)..."
    
    # Monitoring avant stress
    local temp_before=""
    if [[ -f /opt/vc/bin/vcgencmd ]]; then
        temp_before=$(/opt/vc/bin/vcgencmd measure_temp | cut -d= -f2)
        info "Température avant stress: $temp_before"
    fi
    
    local mem_before=$(free | awk 'NR==2{printf "%.1f%%", $3/$2*100}')
    info "Utilisation mémoire avant: $mem_before"
    
    # Lancement du stress test
    local stress_duration=60
    info "Stress test de ${stress_duration} secondes..."
    
    (
        # Stress CPU
        timeout "$stress_duration" bash -c 'while true; do echo "scale=1000; 4*a(1)" | bc -l > /dev/null; done' &
        
        # Stress mémoire
        timeout "$stress_duration" bash -c 'while true; do dd if=/dev/zero of=/tmp/stress_mem bs=1M count=50 2>/dev/null; rm -f /tmp/stress_mem; done' &
        
        # Stress IO
        timeout "$stress_duration" bash -c 'while true; do dd if=/dev/urandom of=/tmp/stress_io bs=1M count=10 2>/dev/null; rm -f /tmp/stress_io; done' &
        
        wait
    ) 2>/dev/null || true
    
    # Monitoring après stress
    sleep 5
    
    local temp_after=""
    if [[ -f /opt/vc/bin/vcgencmd ]]; then
        temp_after=$(/opt/vc/bin/vcgencmd measure_temp | cut -d= -f2)
        info "Température après stress: $temp_after"
        
        # Calcul de l'élévation de température
        if [[ -n "$temp_before" && -n "$temp_after" ]]; then
            local temp_diff=$(echo "${temp_after%°C} - ${temp_before%°C}" | bc)
            info "Élévation température: +${temp_diff}°C"
        fi
    fi
    
    local mem_after=$(free | awk 'NR==2{printf "%.1f%%", $3/$2*100}')
    info "Utilisation mémoire après: $mem_after"
    
    success "Test de stress terminé"
}

# Calcul du score global
calculate_score() {
    echo | tee -a "$RESULTS_FILE"
    info "=== SCORE GLOBAL ==="
    
    # Extraction des métriques
    local cpu_score=$(grep "Score CPU:" "$RESULTS_FILE" | awk '{print $3}' || echo "0")
    local mem_write=$(grep "Vitesse écriture:" "$RESULTS_FILE" | awk '{print $3}' || echo "0")
    local disk_write=$(grep "Vitesse écriture disque:" "$RESULTS_FILE" | awk '{print $4}' || echo "0")
    local video_decode=$(grep "Performance décodage:" "$RESULTS_FILE" | awk '{print $3}' | tr -d 'x' || echo "0")
    
    # Calcul du score composite (approximatif)
    local composite_score=$(echo "scale=0; ($cpu_score + $mem_write + $disk_write + $video_decode * 100) / 4" | bc 2>/dev/null || echo "0")
    
    success "Score composite: $composite_score points"
    
    # Classification
    if (( $(echo "$composite_score > 500" | bc -l) )); then
        success "Performance: EXCELLENTE"
    elif (( $(echo "$composite_score > 200" | bc -l) )); then
        success "Performance: BONNE"
    elif (( $(echo "$composite_score > 100" | bc -l) )); then
        warn "Performance: MOYENNE"
    else
        warn "Performance: FAIBLE"
    fi
}

# Nettoyage
cleanup() {
    info "Nettoyage..."
    
    # Suppression des fichiers de test
    rm -rf "$TEST_VIDEO_DIR"
    rm -f /tmp/benchmark_*
    rm -f /tmp/stress_*
    
    success "Nettoyage terminé"
}

# Résumé des résultats
show_summary() {
    echo | tee -a "$RESULTS_FILE"
    success "=== RÉSUMÉ DU BENCHMARK ==="
    
    local test_duration=$(grep "Durée totale:" "$RESULTS_FILE" | awk '{print $3}' || echo "N/A")
    info "Type de test: $(if [[ "$QUICK_TEST" == true ]]; then echo "Rapide"; else echo "Complet"; fi)"
    
    # Affichage des principales métriques
    grep -E "(Score CPU|Vitesse.*disque|Performance.*décodage|Score composite|Performance:)" "$RESULTS_FILE" | while read -r line; do
        echo "  $line"
    done
    
    echo | tee -a "$RESULTS_FILE"
    
    if [[ "$SAVE_RESULTS" == true ]]; then
        info "Résultats sauvegardés: $RESULTS_FILE"
    else
        info "Fichier temporaire: $RESULTS_FILE (sera supprimé)"
    fi
}

# Fonction principale
main() {
    echo "=== PiSignage Desktop v3.0 - Benchmark ==="
    echo
    
    # Parse des arguments
    parse_arguments "$@"
    
    local start_total=$(date +%s)
    
    # Initialisation
    create_results_header
    prepare_tests
    
    # Tests
    test_cpu
    test_memory
    test_disk
    test_network
    test_video
    test_web_interface
    test_stress
    
    # Finalisation
    local end_total=$(date +%s)
    local total_duration=$((end_total - start_total))
    echo "Durée totale: ${total_duration}s" >> "$RESULTS_FILE"
    
    calculate_score
    cleanup
    show_summary
    
    # Suppression du fichier temporaire si pas de sauvegarde
    if [[ "$SAVE_RESULTS" != true ]]; then
        rm -f "$RESULTS_FILE"
    fi
    
    success "Benchmark terminé!"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi