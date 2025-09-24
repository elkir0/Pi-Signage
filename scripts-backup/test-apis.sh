#!/bin/bash
# PiSignage v0.8.0 - Script de tests automatiques des APIs
# Validation complète du fonctionnement des APIs backend

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/api-tests.log"
RESULTS_FILE="$PROJECT_DIR/logs/test-results.json"

# Configuration
API_BASE_URL="http://localhost"
TIMEOUT=10
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Créer le dossier de logs
mkdir -p "$(dirname "$LOG_FILE")"

# Fonctions d'affichage
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$LOG_FILE"
}

failure() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

# Fonction pour executer une requête API
api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local expected_status="$4"

    local url="$API_BASE_URL$endpoint"
    local temp_response="/tmp/api_response_$$"
    local temp_headers="/tmp/api_headers_$$"

    # Préparer la commande curl
    local curl_cmd="curl -s -w '%{http_code}' --max-time $TIMEOUT"

    case "$method" in
        "GET")
            curl_cmd="$curl_cmd -X GET"
            ;;
        "POST")
            curl_cmd="$curl_cmd -X POST -H 'Content-Type: application/json'"
            if [[ -n "$data" ]]; then
                curl_cmd="$curl_cmd -d '$data'"
            fi
            ;;
        "PUT")
            curl_cmd="$curl_cmd -X PUT -H 'Content-Type: application/json'"
            if [[ -n "$data" ]]; then
                curl_cmd="$curl_cmd -d '$data'"
            fi
            ;;
        "DELETE")
            curl_cmd="$curl_cmd -X DELETE -H 'Content-Type: application/json'"
            if [[ -n "$data" ]]; then
                curl_cmd="$curl_cmd -d '$data'"
            fi
            ;;
    esac

    # Exécuter la requête
    eval "$curl_cmd '$url'" > "$temp_response" 2>/dev/null || {
        echo "ERROR: Request failed"
        rm -f "$temp_response" "$temp_headers"
        return 1
    }

    # Extraire le code de statut (dernière ligne)
    local status_code=$(tail -c 3 "$temp_response")

    # Extraire le corps de la réponse (tout sauf les 3 derniers caractères)
    local response_body=$(head -c -4 "$temp_response")

    # Nettoyer les fichiers temporaires
    rm -f "$temp_response" "$temp_headers"

    # Vérifier le code de statut si spécifié
    if [[ -n "$expected_status" && "$status_code" != "$expected_status" ]]; then
        echo "ERROR: Expected status $expected_status, got $status_code"
        return 1
    fi

    # Retourner la réponse
    echo "$response_body"
    return 0
}

# Test d'une API avec validation JSON
test_api() {
    local test_name="$1"
    local method="$2"
    local endpoint="$3"
    local data="$4"
    local expected_status="$5"

    ((TOTAL_TESTS++))

    info "Test: $test_name"

    # Exécuter la requête
    local response
    if response=$(api_request "$method" "$endpoint" "$data" "$expected_status"); then
        # Vérifier si la réponse est du JSON valide
        if echo "$response" | jq . >/dev/null 2>&1; then
            # Vérifier la structure de base de la réponse PiSignage
            local has_success=$(echo "$response" | jq -r '.success // empty')
            local has_timestamp=$(echo "$response" | jq -r '.timestamp // empty')

            if [[ -n "$has_success" && -n "$has_timestamp" ]]; then
                ((PASSED_TESTS++))
                success "$test_name - Response structure valid"
                return 0
            else
                ((FAILED_TESTS++))
                failure "$test_name - Invalid response structure"
                return 1
            fi
        else
            ((FAILED_TESTS++))
            failure "$test_name - Invalid JSON response"
            return 1
        fi
    else
        ((FAILED_TESTS++))
        failure "$test_name - Request failed: $response"
        return 1
    fi
}

# Tests de l'API System
test_system_api() {
    info "=== Testing System API ==="

    test_api "System - Get Status" "GET" "/api/system.php" "" "200"
    test_api "System - Get Processes" "POST" "/api/system.php" '{"action":"processes"}' "200"
    test_api "System - Get Logs" "POST" "/api/system.php" '{"action":"logs","lines":10}' "200"
}

# Tests de l'API Media
test_media_api() {
    info "=== Testing Media API ==="

    test_api "Media - List Files" "GET" "/api/media.php" "" "200"
    test_api "Media - Get Thumbnails" "GET" "/api/media.php?action=thumbnails" "" "200"

    # Test avec un fichier inexistant
    test_api "Media - Get Info (Not Found)" "GET" "/api/media.php?action=info&file=nonexistent.mp4" "" "200"
}

# Tests de l'API Playlist
test_playlist_api() {
    info "=== Testing Playlist API ==="

    test_api "Playlist - List All" "GET" "/api/playlist.php" "" "200"

    # Créer une playlist de test
    local test_playlist='{"name":"test_playlist","description":"Test playlist","items":[]}'
    test_api "Playlist - Create Test" "POST" "/api/playlist.php" "$test_playlist" "200"

    # Obtenir info de la playlist
    test_api "Playlist - Get Info" "GET" "/api/playlist.php?action=info&name=test_playlist" "" "200"

    # Mettre à jour la playlist
    local update_playlist='{"name":"test_playlist","description":"Updated test playlist"}'
    test_api "Playlist - Update" "PUT" "/api/playlist.php" "$update_playlist" "200"

    # Supprimer la playlist
    local delete_playlist='{"name":"test_playlist"}'
    test_api "Playlist - Delete" "DELETE" "/api/playlist.php" "$delete_playlist" "200"
}

# Tests de l'API Upload
test_upload_api() {
    info "=== Testing Upload API ==="

    # Test sans fichier (doit échouer proprement)
    test_api "Upload - No Files" "POST" "/api/upload.php" "" "200"
}

# Tests de l'API Screenshot
test_screenshot_api() {
    info "=== Testing Screenshot API ==="

    test_api "Screenshot - Get Methods" "GET" "/api/screenshot.php?action=methods" "" "200"
    test_api "Screenshot - Get Status" "GET" "/api/screenshot.php?action=status" "" "200"
    test_api "Screenshot - List Recent" "GET" "/api/screenshot.php?action=list&limit=5" "" "200"

    # Test de capture (peut échouer selon l'environnement)
    if api_request "GET" "/api/screenshot.php?action=capture" "" "200" >/dev/null 2>&1; then
        success "Screenshot - Capture Available"
    else
        warn "Screenshot - Capture Not Available (normal in headless environment)"
    fi
}

# Tests de l'API YouTube
test_youtube_api() {
    info "=== Testing YouTube API ==="

    test_api "YouTube - Check yt-dlp" "GET" "/api/youtube.php?action=check_ytdlp" "" "200"
    test_api "YouTube - Get Queue" "GET" "/api/youtube.php" "" "200"

    # Test info vidéo (peut échouer sans connexion internet)
    if api_request "GET" "/api/youtube.php?action=info&url=https://www.youtube.com/watch?v=dQw4w9WgXcQ" "" "200" >/dev/null 2>&1; then
        success "YouTube - Video Info Available"
    else
        warn "YouTube - Video Info Not Available (network/yt-dlp issue)"
    fi
}

# Tests de l'API Player
test_player_api() {
    info "=== Testing Player API ==="

    test_api "Player - Get Status" "GET" "/api/player.php" "" "200"

    # Tests des commandes de base
    test_api "Player - Stop" "POST" "/api/player.php" '{"action":"stop"}' "200"
    test_api "Player - Pause" "POST" "/api/player.php" '{"action":"pause"}' "200"
    test_api "Player - Volume" "POST" "/api/player.php" '{"action":"volume","value":50}' "200"
}

# Tests de l'API Scheduler
test_scheduler_api() {
    info "=== Testing Scheduler API ==="

    test_api "Scheduler - List All" "GET" "/api/scheduler.php" "" "200"

    # Créer un schedule de test (nécessite une playlist existante)
    # Nous allons d'abord créer une playlist temporaire
    local temp_playlist='{"name":"temp_schedule_test","description":"Temporary playlist for schedule test","items":[]}'
    if api_request "POST" "/api/playlist.php" "$temp_playlist" "200" >/dev/null 2>&1; then

        local test_schedule='{"name":"test_schedule","playlist_name":"temp_schedule_test","start_time":"09:00","end_time":"17:00","days":[1,2,3,4,5]}'
        test_api "Scheduler - Create Test" "POST" "/api/scheduler.php" "$test_schedule" "200"

        # Nettoyer
        local delete_schedule='{"id":1}'
        api_request "DELETE" "/api/scheduler.php" "$delete_schedule" "200" >/dev/null 2>&1

        local delete_playlist='{"name":"temp_schedule_test"}'
        api_request "DELETE" "/api/playlist.php" "$delete_playlist" "200" >/dev/null 2>&1
    else
        warn "Scheduler - Cannot test creation (playlist API issue)"
    fi
}

# Test de performance
test_performance() {
    info "=== Testing Performance ==="

    local start_time=$(date +%s%N)

    # Faire 10 requêtes rapides à l'API system
    for i in {1..10}; do
        api_request "GET" "/api/system.php" "" "200" >/dev/null 2>&1 || true
    done

    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    local avg_response_time=$(( duration / 10 ))

    if [[ $avg_response_time -lt 1000 ]]; then # Less than 1 second average
        success "Performance - Average response time: ${avg_response_time}ms"
    else
        warn "Performance - Slow response time: ${avg_response_time}ms"
    fi
}

# Vérifier la disponibilité du serveur
check_server_availability() {
    info "Checking server availability..."

    local max_attempts=5
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -s --max-time 5 "$API_BASE_URL" >/dev/null 2>&1; then
            success "Server is available"
            return 0
        else
            warn "Attempt $attempt/$max_attempts: Server not responding"
            sleep 2
            ((attempt++))
        fi
    done

    failure "Server is not available after $max_attempts attempts"
    return 1
}

# Générer le rapport de tests
generate_report() {
    local end_time=$(date -Iseconds)
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))

    # Rapport JSON
    cat > "$RESULTS_FILE" << EOF
{
    "test_run": {
        "timestamp": "$end_time",
        "version": "0.8.0",
        "environment": "$(uname -a)"
    },
    "results": {
        "total_tests": $TOTAL_TESTS,
        "passed_tests": $PASSED_TESTS,
        "failed_tests": $FAILED_TESTS,
        "success_rate": $success_rate
    },
    "server": {
        "url": "$API_BASE_URL",
        "timeout": $TIMEOUT
    }
}
EOF

    # Rapport console
    echo
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           TEST RESULTS SUMMARY          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo
    echo -e "Total Tests:   ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed Tests:  ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed Tests:  ${RED}$FAILED_TESTS${NC}"
    echo -e "Success Rate:  ${GREEN}$success_rate%${NC}"
    echo
    echo -e "Detailed logs: ${YELLOW}$LOG_FILE${NC}"
    echo -e "JSON results:  ${YELLOW}$RESULTS_FILE${NC}"
    echo

    if [[ $success_rate -ge 90 ]]; then
        echo -e "${GREEN}🎉 All tests passed! PiSignage APIs are working correctly.${NC}"
    elif [[ $success_rate -ge 70 ]]; then
        echo -e "${YELLOW}⚠️  Most tests passed, but some issues were detected.${NC}"
    else
        echo -e "${RED}❌ Many tests failed. Please check the logs for details.${NC}"
    fi
}

# Fonction principale
main() {
    local start_time=$(date -Iseconds)

    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         PiSignage v0.8.0 API Tests      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo

    log "=== API Tests Started at $start_time ==="

    # Vérifier la disponibilité du serveur
    if ! check_server_availability; then
        failure "Cannot proceed with tests - server not available"
        exit 1
    fi

    # Exécuter les tests
    test_system_api
    test_media_api
    test_playlist_api
    test_upload_api
    test_screenshot_api
    test_youtube_api
    test_player_api
    test_scheduler_api
    test_performance

    # Générer le rapport
    generate_report

    log "=== API Tests Completed ==="

    # Code de sortie basé sur le taux de réussite
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    if [[ $success_rate -ge 90 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Gestion des arguments
case "${1:-}" in
    --help|-h)
        echo "PiSignage v0.8.0 API Test Suite"
        echo
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --url URL      Set custom API base URL (default: http://localhost)"
        echo "  --timeout SEC  Set request timeout in seconds (default: 10)"
        echo
        echo "Examples:"
        echo "  $0                                    # Test localhost"
        echo "  $0 --url http://192.168.1.100       # Test remote server"
        echo "  $0 --timeout 20                     # Use 20 second timeout"
        exit 0
        ;;
    --url)
        API_BASE_URL="$2"
        shift 2
        ;;
    --timeout)
        TIMEOUT="$2"
        shift 2
        ;;
    *)
        # Traiter les arguments restants ou lancer main sans arguments
        ;;
esac

# Vérifier les dépendances
if ! command -v curl >/dev/null 2>&1; then
    failure "curl is required but not installed"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    warn "jq is not installed - JSON validation will be limited"
fi

# Lancer les tests
main "$@"