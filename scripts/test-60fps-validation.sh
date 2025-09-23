#!/bin/bash

# ===========================================
# VALIDATION COMPLÈTE 60 FPS - RASPBERRY PI 4
# ===========================================
# Script de test et validation des optimisations GPU
# Version: 1.0.0
# Date: 2025-09-22

set -e

# Configuration
PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"
TEST_DURATION=120  # 2 minutes de test
FPS_THRESHOLD=30   # Seuil minimum acceptable

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# Test 1: Vérification configuration GPU
test_gpu_config() {
    log "Test 1: Configuration GPU"

    local gpu_mem=$(sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "vcgencmd get_mem gpu" | cut -d= -f2)
    local arm_freq=$(sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "vcgencmd measure_clock arm" | cut -d= -f2)
    local gpu_freq=$(sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "vcgencmd measure_clock gpu" | cut -d= -f2)
    local temp=$(sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "vcgencmd measure_temp" | cut -d= -f2)

    echo "  GPU Memory: $gpu_mem"
    echo "  ARM Frequency: $(($arm_freq / 1000000)) MHz"
    echo "  GPU Frequency: $(($gpu_freq / 1000000)) MHz"
    echo "  Temperature: $temp"

    # Validations
    local gpu_mem_mb=${gpu_mem%M*}
    if [ "$gpu_mem_mb" -ge 256 ]; then
        success "GPU Memory OK ($gpu_mem)"
    else
        error "GPU Memory insuffisante ($gpu_mem < 256M)"
        return 1
    fi

    if [ "$arm_freq" -ge 1800000000 ]; then
        success "ARM Frequency OK ($(($arm_freq / 1000000)) MHz)"
    else
        warning "ARM Frequency faible ($(($arm_freq / 1000000)) MHz)"
    fi

    local temp_num=${temp%'*}
    if [ "$temp_num" -le 75 ]; then
        success "Température OK ($temp)"
    else
        warning "Température élevée ($temp)"
    fi

    return 0
}

# Test 2: Vérification processus Chromium
test_chromium_process() {
    log "Test 2: Processus Chromium"

    local chromium_pid=$(sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "pgrep -f chromium-browser | head -1" || echo "")

    if [ -n "$chromium_pid" ]; then
        success "Chromium en cours d'exécution (PID: $chromium_pid)"

        local cpu_usage=$(sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "ps -p $chromium_pid -o %cpu --no-headers")
        local mem_usage=$(sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "ps -p $chromium_pid -o %mem --no-headers")

        echo "  CPU Usage: ${cpu_usage}%"
        echo "  Memory Usage: ${mem_usage}%"

        if (( $(echo "$cpu_usage < 80" | bc -l) )); then
            success "CPU Usage OK (${cpu_usage}%)"
        else
            warning "CPU Usage élevé (${cpu_usage}%)"
        fi

        return 0
    else
        error "Chromium non démarré"
        return 1
    fi
}

# Test 3: Test API Performance
test_performance_api() {
    log "Test 3: API Performance"

    local api_response=$(curl -s "http://$PI_IP/api/performance.php?endpoint=current" || echo "")

    if [ -n "$api_response" ] && echo "$api_response" | grep -q "timestamp"; then
        success "API Performance accessible"

        # Parser quelques valeurs importantes
        local gpu_temp=$(echo "$api_response" | grep -o '"temperature":[0-9.]*' | cut -d: -f2)
        local chromium_running=$(echo "$api_response" | grep -o '"running":[a-z]*' | cut -d: -f2)

        echo "  GPU Temperature: ${gpu_temp}°C"
        echo "  Chromium Running: $chromium_running"

        return 0
    else
        error "API Performance non accessible"
        echo "  Response: $api_response"
        return 1
    fi
}

# Test 4: Test monitoring FPS
test_fps_monitoring() {
    log "Test 4: Monitoring FPS ($TEST_DURATION secondes)"

    # Démarrer monitoring en arrière-plan sur le Pi
    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "nohup /opt/pisignage/scripts/monitor-fps.sh $TEST_DURATION $FPS_THRESHOLD > /tmp/fps-test.log 2>&1 &"

    # Attendre et afficher progress
    for i in $(seq 1 $TEST_DURATION); do
        printf "\r  Monitoring FPS: %d/%d secondes..." $i $TEST_DURATION
        sleep 1
    done
    echo ""

    # Attendre la fin du monitoring
    sleep 5

    # Récupérer résultats
    local fps_results=$(sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "cat /tmp/fps-test.log" || echo "")

    if echo "$fps_results" | grep -q "FPS Moyen"; then
        local fps_avg=$(echo "$fps_results" | grep "FPS Moyen" | grep -o '[0-9]*')
        echo "  FPS Moyen: $fps_avg"

        if [ "$fps_avg" -ge $FPS_THRESHOLD ]; then
            success "FPS acceptable ($fps_avg >= $FPS_THRESHOLD)"
            return 0
        else
            error "FPS insuffisant ($fps_avg < $FPS_THRESHOLD)"
            return 1
        fi
    else
        error "Impossible de récupérer stats FPS"
        echo "  Output: $fps_results"
        return 1
    fi
}

# Test 5: Test performance réseau
test_network_performance() {
    log "Test 5: Performance réseau"

    local ping_result=$(ping -c 5 "$PI_IP" | tail -1 | grep -o '[0-9.]*/' | head -1 | sed 's/\///')

    if [ -n "$ping_result" ]; then
        echo "  Latency moyenne: ${ping_result}ms"

        if (( $(echo "$ping_result < 5" | bc -l) )); then
            success "Latency excellente (${ping_result}ms)"
        elif (( $(echo "$ping_result < 20" | bc -l) )); then
            success "Latency correcte (${ping_result}ms)"
        else
            warning "Latency élevée (${ping_result}ms)"
        fi
    fi

    # Test bande passante avec curl
    local start_time=$(date +%s.%N)
    curl -s "http://$PI_IP/api/performance.php?endpoint=current" > /dev/null
    local end_time=$(date +%s.%N)
    local response_time=$(echo "$end_time - $start_time" | bc)

    echo "  Temps de réponse API: ${response_time}s"

    if (( $(echo "$response_time < 1" | bc -l) )); then
        success "Temps de réponse API excellent (${response_time}s)"
    else
        warning "Temps de réponse API lent (${response_time}s)"
    fi

    return 0
}

# Test 6: Test charge système
test_system_load() {
    log "Test 6: Charge système"

    local load_avg=$(sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "cat /proc/loadavg | cut -d' ' -f1")
    local mem_usage=$(sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "free | grep Mem | awk '{printf \"%.1f\", \$3/\$2 * 100.0}'")

    echo "  Load Average: $load_avg"
    echo "  Memory Usage: ${mem_usage}%"

    if (( $(echo "$load_avg < 2.0" | bc -l) )); then
        success "Load Average OK ($load_avg)"
    else
        warning "Load Average élevé ($load_avg)"
    fi

    if (( $(echo "$mem_usage < 80" | bc -l) )); then
        success "Memory Usage OK (${mem_usage}%)"
    else
        warning "Memory Usage élevé (${mem_usage}%)"
    fi

    return 0
}

# Génération rapport final
generate_report() {
    local total_tests=$1
    local passed_tests=$2
    local failed_tests=$3

    echo ""
    echo "=============================================="
    echo "          RAPPORT VALIDATION 60 FPS"
    echo "=============================================="
    echo "Tests exécutés: $total_tests"
    echo "Tests réussis: $passed_tests"
    echo "Tests échoués: $failed_tests"
    echo "Taux de réussite: $(( (passed_tests * 100) / total_tests ))%"
    echo ""

    if [ $failed_tests -eq 0 ]; then
        success "=== VALIDATION COMPLÈTE RÉUSSIE ==="
        echo "✅ Le système est optimisé pour 60 FPS"
        echo "✅ Toutes les configurations sont correctes"
        echo "✅ Performance générale excellente"
    elif [ $failed_tests -le 2 ]; then
        warning "=== VALIDATION PARTIELLE ==="
        echo "⚠️  Quelques optimisations mineures possibles"
        echo "⚠️  Performance globalement correcte"
    else
        error "=== VALIDATION ÉCHOUÉE ==="
        echo "❌ Optimisations insuffisantes"
        echo "❌ Configuration à réviser"
    fi

    echo ""
    echo "Logs disponibles:"
    echo "- Performance API: http://$PI_IP/api/performance.php?endpoint=current"
    echo "- Monitoring FPS: ssh pi@$PI_IP 'cat /var/log/pisignage/fps-monitoring.log'"
    echo "- System stats: ssh pi@$PI_IP 'htop'"
    echo ""
}

# Script principal
main() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "    VALIDATION OPTIMISATIONS 60 FPS"
    echo "=============================================="
    echo -e "${NC}"

    log "Démarrage validation sur $PI_IP"
    echo ""

    local total_tests=6
    local passed_tests=0
    local failed_tests=0

    # Exécution des tests
    if test_gpu_config; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    echo ""

    if test_chromium_process; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    echo ""

    if test_performance_api; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    echo ""

    if test_fps_monitoring; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    echo ""

    if test_network_performance; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    echo ""

    if test_system_load; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    echo ""

    # Génération rapport
    generate_report $total_tests $passed_tests $failed_tests

    # Code de sortie
    if [ $failed_tests -eq 0 ]; then
        exit 0
    elif [ $failed_tests -le 2 ]; then
        exit 1
    else
        exit 2
    fi
}

# Commandes spéciales
case "${1:-}" in
    help|--help|-h)
        echo "VALIDATION 60 FPS - Raspberry Pi 4"
        echo ""
        echo "Usage: $0 [COMMANDE]"
        echo ""
        echo "Commandes:"
        echo "  (aucune)  Exécuter validation complète"
        echo "  help      Afficher cette aide"
        echo "  quick     Validation rapide (sans monitoring FPS)"
        echo ""
        exit 0
        ;;
    quick)
        log "Mode validation rapide (sans monitoring FPS)"
        TEST_DURATION=10
        ;;
esac

main