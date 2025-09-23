#!/bin/bash

# PiSignage v0.9.0 - Script de Tests Post-Déploiement
# Tests automatiques complets après déploiement

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TEST_LOG="/tmp/pisignage-post-tests.log"
PISIGNAGE_URL="http://localhost"
PISIGNAGE_DIR="/opt/pisignage"
TIMEOUT=30

# Compteurs de tests
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

# Fonction de log
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $message" | tee -a "$TEST_LOG"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message" | tee -a "$TEST_LOG"
            ((TESTS_FAILED++))
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$TEST_LOG"
            ((TESTS_WARNINGS++))
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$TEST_LOG"
            ;;
    esac
    echo "[$timestamp] [$level] $message" >> "$TEST_LOG"
}

# Fonction de test avec timeout
test_with_timeout() {
    local command="$1"
    local description="$2"
    local timeout_val="${3:-$TIMEOUT}"

    log "INFO" "Test: $description"

    if timeout "$timeout_val" bash -c "$command" &>/dev/null; then
        log "PASS" "$description"
        return 0
    else
        log "FAIL" "$description"
        return 1
    fi
}

# Fonction de test HTTP
test_http_endpoint() {
    local url="$1"
    local description="$2"
    local expected_code="${3:-200}"

    log "INFO" "Test HTTP: $description ($url)"

    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "$url")

    if [[ "$response_code" == "$expected_code" ]]; then
        log "PASS" "$description (HTTP $response_code)"
        return 0
    else
        log "FAIL" "$description (HTTP $response_code, attendu $expected_code)"
        return 1
    fi
}

# Fonction de test JSON API
test_json_api() {
    local url="$1"
    local description="$2"
    local expected_key="$3"

    log "INFO" "Test API JSON: $description"

    local response
    response=$(curl -s --connect-timeout 10 --max-time 30 "$url")

    if [[ -n "$response" ]] && echo "$response" | jq -e ".$expected_key" &>/dev/null; then
        log "PASS" "$description (JSON valide avec '$expected_key')"
        return 0
    else
        log "FAIL" "$description (JSON invalide ou clé '$expected_key' manquante)"
        return 1
    fi
}

# Test 1: Services système
test_system_services() {
    log "INFO" "=== Test des Services Système ==="

    local services=("nginx" "php7.4-fpm" "pisignage")

    for service in "${services[@]}"; do
        if systemctl is-active "$service" &>/dev/null; then
            log "PASS" "Service $service actif"
        else
            log "FAIL" "Service $service inactif"
        fi

        if systemctl is-enabled "$service" &>/dev/null; then
            log "PASS" "Service $service activé au démarrage"
        else
            log "WARN" "Service $service non activé au démarrage"
        fi
    done

    return 0
}

# Test 2: Structure des fichiers
test_file_structure() {
    log "INFO" "=== Test de la Structure des Fichiers ==="

    local required_dirs=(
        "$PISIGNAGE_DIR"
        "$PISIGNAGE_DIR/web"
        "$PISIGNAGE_DIR/scripts"
        "$PISIGNAGE_DIR/media"
        "$PISIGNAGE_DIR/logs"
        "$PISIGNAGE_DIR/screenshots"
    )

    local required_files=(
        "$PISIGNAGE_DIR/VERSION"
        "$PISIGNAGE_DIR/web/index.php"
        "$PISIGNAGE_DIR/scripts/start-signage.sh"
        "$PISIGNAGE_DIR/scripts/stop-signage.sh"
    )

    # Test des répertoires
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log "PASS" "Répertoire existe: $dir"
        else
            log "FAIL" "Répertoire manquant: $dir"
        fi
    done

    # Test des fichiers
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log "PASS" "Fichier existe: $file"
        else
            log "FAIL" "Fichier manquant: $file"
        fi
    done

    # Test des permissions
    if [[ -r "$PISIGNAGE_DIR/web/index.php" ]]; then
        log "PASS" "Fichier index.php lisible"
    else
        log "FAIL" "Fichier index.php non lisible"
    fi

    if [[ -x "$PISIGNAGE_DIR/scripts/start-signage.sh" ]]; then
        log "PASS" "Script start-signage.sh exécutable"
    else
        log "FAIL" "Script start-signage.sh non exécutable"
    fi

    return 0
}

# Test 3: Connectivité HTTP
test_http_connectivity() {
    log "INFO" "=== Test de Connectivité HTTP ==="

    # Test de la page principale
    test_http_endpoint "$PISIGNAGE_URL" "Page principale accessible"

    # Test des endpoints API
    local api_endpoints=(
        "/api/system.php"
        "/api/media.php"
    )

    for endpoint in "${api_endpoints[@]}"; do
        test_http_endpoint "$PISIGNAGE_URL$endpoint" "API endpoint: $endpoint"
    done

    # Test des répertoires statiques
    test_http_endpoint "$PISIGNAGE_URL/media/" "Répertoire média accessible" "200"

    return 0
}

# Test 4: APIs JSON
test_json_apis() {
    log "INFO" "=== Test des APIs JSON ==="

    # Test API System
    test_json_api "$PISIGNAGE_URL/api/system.php" "API System" "status"
    test_json_api "$PISIGNAGE_URL/api/system.php" "API System - Version" "version"
    test_json_api "$PISIGNAGE_URL/api/system.php" "API System - Services" "services"

    # Test API Media
    test_json_api "$PISIGNAGE_URL/api/media.php" "API Media" "status"

    return 0
}

# Test 5: Performance et temps de réponse
test_performance() {
    log "INFO" "=== Test de Performance ==="

    # Test du temps de réponse de la page principale
    local response_time
    response_time=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 10 --max-time 30 "$PISIGNAGE_URL")

    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        log "PASS" "Temps de réponse acceptable: ${response_time}s"
    elif (( $(echo "$response_time < 5.0" | bc -l) )); then
        log "WARN" "Temps de réponse lent: ${response_time}s"
    else
        log "FAIL" "Temps de réponse trop lent: ${response_time}s"
    fi

    # Test de la charge système
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local load_int=$(echo "$load_avg * 100" | bc 2>/dev/null | cut -d. -f1)

    if [[ $load_int -lt 100 ]]; then
        log "PASS" "Charge système normale: $load_avg"
    elif [[ $load_int -lt 200 ]]; then
        log "WARN" "Charge système élevée: $load_avg"
    else
        log "FAIL" "Charge système trop élevée: $load_avg"
    fi

    return 0
}

# Test 6: Fonctionnalités spécifiques
test_specific_features() {
    log "INFO" "=== Test des Fonctionnalités Spécifiques ==="

    # Test de l'upload de fichiers (simulé)
    if [[ -w "$PISIGNAGE_DIR/media" ]]; then
        log "PASS" "Répertoire media accessible en écriture"
    else
        log "FAIL" "Répertoire media non accessible en écriture"
    fi

    # Test des logs
    if [[ -w "$PISIGNAGE_DIR/logs" ]]; then
        log "PASS" "Répertoire logs accessible en écriture"

        # Test d'écriture de log
        local test_log="$PISIGNAGE_DIR/logs/test-$(date +%s).log"
        if echo "Test log entry" > "$test_log" 2>/dev/null; then
            log "PASS" "Écriture de log fonctionnelle"
            rm -f "$test_log"
        else
            log "FAIL" "Écriture de log échouée"
        fi
    else
        log "FAIL" "Répertoire logs non accessible en écriture"
    fi

    # Test de la capture d'écran (si disponible)
    if command -v scrot &>/dev/null || command -v gnome-screenshot &>/dev/null; then
        log "PASS" "Outil de capture d'écran disponible"
    else
        log "WARN" "Outil de capture d'écran non disponible"
    fi

    return 0
}

# Test 7: Configuration GPU et affichage
test_gpu_display() {
    log "INFO" "=== Test GPU et Affichage ==="

    # Test de la configuration GPU
    if [[ -f /boot/config.txt ]] && grep -q "gpu_mem=128" /boot/config.txt; then
        log "PASS" "Configuration GPU détectée"
    else
        log "WARN" "Configuration GPU non optimale"
    fi

    # Test du driver VC4
    if lsmod | grep -q vc4; then
        log "PASS" "Driver GPU VC4 chargé"
    else
        log "WARN" "Driver GPU VC4 non chargé"
    fi

    # Test de Chromium
    if command -v chromium-browser &>/dev/null; then
        log "PASS" "Chromium disponible"

        # Test du lancement de Chromium (sans interface graphique)
        if chromium-browser --version &>/dev/null; then
            log "PASS" "Chromium fonctionnel"
        else
            log "WARN" "Chromium installation possiblement incomplète"
        fi
    else
        log "FAIL" "Chromium non disponible"
    fi

    return 0
}

# Test 8: Sécurité de base
test_basic_security() {
    log "INFO" "=== Test de Sécurité de Base ==="

    # Test des permissions de fichiers sensibles
    if [[ $(stat -c %a "$PISIGNAGE_DIR/web/index.php") == "644" ]] || [[ $(stat -c %a "$PISIGNAGE_DIR/web/index.php") == "755" ]]; then
        log "PASS" "Permissions index.php sécurisées"
    else
        log "WARN" "Permissions index.php à vérifier"
    fi

    # Test que les répertoires sensibles ne sont pas accessibles via web
    test_http_endpoint "$PISIGNAGE_URL/scripts/" "Répertoire scripts protégé" "403"
    test_http_endpoint "$PISIGNAGE_URL/config/" "Répertoire config protégé" "403"

    # Test des headers de sécurité
    local security_headers
    security_headers=$(curl -s -I "$PISIGNAGE_URL" | grep -i "x-frame-options\|x-content-type-options")

    if [[ -n "$security_headers" ]]; then
        log "PASS" "Headers de sécurité présents"
    else
        log "WARN" "Headers de sécurité manquants"
    fi

    return 0
}

# Test 9: Monitoring et logs
test_monitoring_logs() {
    log "INFO" "=== Test du Monitoring et Logs ==="

    # Test de l'accessibilité des logs
    if [[ -d "$PISIGNAGE_DIR/logs" ]] && [[ -r "$PISIGNAGE_DIR/logs" ]]; then
        log "PASS" "Répertoire logs accessible"
    else
        log "FAIL" "Répertoire logs non accessible"
    fi

    # Test du service de monitoring
    if systemctl list-units | grep -q pisignage-monitor; then
        if systemctl is-active pisignage-monitor &>/dev/null; then
            log "PASS" "Service de monitoring actif"
        else
            log "WARN" "Service de monitoring inactif"
        fi
    else
        log "WARN" "Service de monitoring non configuré"
    fi

    # Test de l'espace disque
    local disk_usage
    disk_usage=$(df "$PISIGNAGE_DIR" | awk 'NR==2 {print $5}' | tr -d '%')

    if [[ $disk_usage -lt 80 ]]; then
        log "PASS" "Espace disque suffisant ($disk_usage%)"
    elif [[ $disk_usage -lt 90 ]]; then
        log "WARN" "Espace disque faible ($disk_usage%)"
    else
        log "FAIL" "Espace disque critique ($disk_usage%)"
    fi

    return 0
}

# Test final complet avec Puppeteer (si disponible)
test_with_puppeteer() {
    log "INFO" "=== Test Puppeteer (si disponible) ==="

    if command -v node &>/dev/null && [[ -f "$PISIGNAGE_DIR/package.json" ]]; then
        # Créer un test Puppeteer rapide
        local test_script="/tmp/pisignage-test.js"
        cat << 'EOF' > "$test_script"
const puppeteer = require('puppeteer');

(async () => {
    try {
        const browser = await puppeteer.launch({
            headless: true,
            args: ['--no-sandbox', '--disable-setuid-sandbox']
        });

        const page = await browser.newPage();
        await page.goto('http://localhost', { waitUntil: 'networkidle2' });

        const title = await page.title();
        console.log(`Title: ${title}`);

        if (title.includes('PiSignage')) {
            console.log('PUPPETEER_TEST_PASS');
        } else {
            console.log('PUPPETEER_TEST_FAIL');
        }

        await browser.close();
    } catch (error) {
        console.log('PUPPETEER_TEST_ERROR:', error.message);
    }
})();
EOF

        # Exécuter le test si Puppeteer est disponible
        cd "$PISIGNAGE_DIR"
        if npm list puppeteer &>/dev/null || npm list puppeteer --global &>/dev/null; then
            local puppeteer_result
            puppeteer_result=$(timeout 60 node "$test_script" 2>&1)

            if echo "$puppeteer_result" | grep -q "PUPPETEER_TEST_PASS"; then
                log "PASS" "Test Puppeteer réussi"
            elif echo "$puppeteer_result" | grep -q "PUPPETEER_TEST_FAIL"; then
                log "FAIL" "Test Puppeteer échoué"
            else
                log "WARN" "Test Puppeteer incertain: $puppeteer_result"
            fi
        else
            log "INFO" "Puppeteer non disponible (test ignoré)"
        fi

        rm -f "$test_script"
    else
        log "INFO" "Node.js/Puppeteer non configuré (test ignoré)"
    fi

    return 0
}

# Résumé des tests
show_test_summary() {
    echo
    echo "===== RÉSUMÉ DES TESTS POST-DÉPLOIEMENT ====="
    echo -e "${GREEN}Tests réussis:${NC} $TESTS_PASSED"
    echo -e "${YELLOW}Avertissements:${NC} $TESTS_WARNINGS"
    echo -e "${RED}Tests échoués:${NC} $TESTS_FAILED"
    echo "==============================================="

    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNINGS))
    local success_rate=0
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$(( TESTS_PASSED * 100 / total_tests ))
    fi

    echo "Taux de réussite: $success_rate%"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ Déploiement validé avec succès${NC}"
        echo -e "🌐 Interface accessible: $PISIGNAGE_URL"
        return 0
    elif [[ $TESTS_FAILED -le 2 ]] && [[ $success_rate -ge 80 ]]; then
        echo -e "${YELLOW}⚠ Déploiement acceptable avec quelques problèmes${NC}"
        echo -e "🌐 Interface accessible: $PISIGNAGE_URL"
        return 0
    else
        echo -e "${RED}✗ Déploiement avec problèmes critiques${NC}"
        echo "Veuillez vérifier les échecs avant de continuer."
        return 1
    fi
}

# Fonction principale
main() {
    echo "PiSignage v0.9.0 - Tests Post-Déploiement"
    echo "========================================="
    echo

    log "INFO" "Début des tests post-déploiement..."
    log "INFO" "Log détaillé: $TEST_LOG"

    # Attendre que les services soient prêts
    log "INFO" "Attente que les services soient prêts..."
    sleep 10

    # Exécuter tous les tests
    local test_functions=(
        "test_system_services"
        "test_file_structure"
        "test_http_connectivity"
        "test_json_apis"
        "test_performance"
        "test_specific_features"
        "test_gpu_display"
        "test_basic_security"
        "test_monitoring_logs"
        "test_with_puppeteer"
    )

    for test_func in "${test_functions[@]}"; do
        echo
        $test_func
    done

    # Afficher le résumé
    show_test_summary
}

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi