#!/bin/bash

# PiSignage v0.8.1 GOLDEN - Script de Validation Post-Installation
# Vérifie que tous les composants sont correctement installés et fonctionnels

set -e

# Configuration
PISIGNAGE_DIR="/opt/pisignage"
PHP_VERSION="8.2"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Compteurs
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Fonction de test
run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TESTS_TOTAL++))
    printf "%-50s" "Test: $test_name"

    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}[PASS]${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test avec message détaillé
run_detailed_test() {
    local test_name="$1"
    local test_command="$2"
    local success_msg="$3"
    local error_msg="$4"

    ((TESTS_TOTAL++))
    echo -e "${BLUE}[TEST]${NC} $test_name"

    if eval "$test_command" &>/dev/null; then
        echo -e "  ${GREEN}✓ $success_msg${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗ $error_msg${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Banner
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "=================================================================="
    echo "     PiSignage v0.8.1 GOLDEN - VALIDATION POST-INSTALLATION      "
    echo "=================================================================="
    echo "  Vérification complète de tous les composants installés         "
    echo "=================================================================="
    echo -e "${NC}"
    echo ""
}

# Tests des services système
test_system_services() {
    echo -e "${PURPLE}=== TESTS DES SERVICES SYSTÈME ===${NC}"
    echo ""

    run_detailed_test \
        "Service Nginx" \
        "systemctl is-active --quiet nginx" \
        "Nginx est actif et opérationnel" \
        "Nginx n'est pas démarré ou a des erreurs"

    run_detailed_test \
        "Service PHP-FPM" \
        "systemctl is-active --quiet php${PHP_VERSION}-fpm" \
        "PHP-FPM v$PHP_VERSION fonctionne correctement" \
        "PHP-FPM n'est pas actif"

    run_detailed_test \
        "Service seatd (Wayland)" \
        "systemctl is-active --quiet seatd" \
        "seatd actif (support Wayland OK)" \
        "seatd inactif (support Wayland limité)"

    echo ""
}

# Tests des fichiers critiques
test_critical_files() {
    echo -e "${PURPLE}=== TESTS DES FICHIERS CRITIQUES ===${NC}"
    echo ""

    local critical_files=(
        "$PISIGNAGE_DIR/web/index.php:Interface web principale"
        "$PISIGNAGE_DIR/web/config.php:Configuration PHP"
        "$PISIGNAGE_DIR/scripts/player-manager.sh:Gestionnaire de lecteur"
        "$PISIGNAGE_DIR/scripts/display-monitor.sh:Monitoring système"
        "/etc/nginx/sites-enabled/pisignage:Configuration Nginx"
        "/etc/systemd/system/pisignage.service:Service PiSignage"
        "$PISIGNAGE_DIR/config/mpv/mpv.conf:Configuration MPV"
    )

    for file_info in "${critical_files[@]}"; do
        local file_path="${file_info%:*}"
        local file_desc="${file_info#*:}"

        run_detailed_test \
            "$file_desc" \
            "[ -f '$file_path' ]" \
            "Fichier présent: $file_path" \
            "Fichier manquant: $file_path"
    done

    echo ""
}

# Tests des permissions
test_permissions() {
    echo -e "${PURPLE}=== TESTS DES PERMISSIONS ===${NC}"
    echo ""

    run_detailed_test \
        "Répertoire media accessible en écriture" \
        "[ -w '$PISIGNAGE_DIR/media' ]" \
        "Permissions d'écriture OK sur /media" \
        "Pas de permissions d'écriture sur /media"

    run_detailed_test \
        "Répertoire uploads accessible en écriture" \
        "[ -w '$PISIGNAGE_DIR/uploads' ]" \
        "Permissions d'écriture OK sur /uploads" \
        "Pas de permissions d'écriture sur /uploads"

    run_detailed_test \
        "Répertoire logs accessible en écriture" \
        "[ -w '$PISIGNAGE_DIR/logs' ]" \
        "Permissions d'écriture OK sur /logs" \
        "Pas de permissions d'écriture sur /logs"

    run_detailed_test \
        "Accès DRM (accélération HW)" \
        "[ -r '/dev/dri/card0' ] && [ -r '/dev/dri/renderD128' ]" \
        "Accès DRM disponible (accélération HW possible)" \
        "Accès DRM limité (vérifiez les groupes video/render)"

    echo ""
}

# Tests des lecteurs vidéo
test_media_players() {
    echo -e "${PURPLE}=== TESTS DES LECTEURS VIDÉO ===${NC}"
    echo ""

    run_detailed_test \
        "Installation MPV" \
        "command -v mpv" \
        "MPV installé et accessible" \
        "MPV non trouvé dans le PATH"

    run_detailed_test \
        "Installation VLC" \
        "command -v vlc" \
        "VLC installé et accessible" \
        "VLC non trouvé dans le PATH"

    run_detailed_test \
        "Installation FFmpeg" \
        "command -v ffmpeg" \
        "FFmpeg installé (support de conversion)" \
        "FFmpeg non trouvé"

    # Test des décodeurs V4L2 (accélération HW)
    if command -v ffmpeg &>/dev/null; then
        run_detailed_test \
            "Décodeurs V4L2 (accélération HW)" \
            "ffmpeg -decoders 2>/dev/null | grep -E 'h264_v4l2m2m|hevc_v4l2m2m'" \
            "Décodeurs V4L2M2M disponibles (accélération HW OK)" \
            "Pas de décodeurs V4L2M2M (software decoding uniquement)"
    fi

    echo ""
}

# Tests de l'interface web
test_web_interface() {
    echo -e "${PURPLE}=== TESTS DE L'INTERFACE WEB ===${NC}"
    echo ""

    run_detailed_test \
        "Accessibilité de l'interface web" \
        "curl -s -o /dev/null -w '%{http_code}' http://localhost/ | grep -q '200'" \
        "Interface web accessible (HTTP 200)" \
        "Interface web inaccessible (vérifiez Nginx/PHP)"

    # Test de la configuration PHP
    if curl -s http://localhost/ | grep -q "PiSignage"; then
        run_detailed_test \
            "Contenu de l'interface" \
            "curl -s http://localhost/ | grep -q 'PiSignage'" \
            "Interface PiSignage chargée correctement" \
            "Contenu de l'interface invalide"
    fi

    # Test de l'upload de fichiers (simulation)
    run_detailed_test \
        "Support PHP pour uploads" \
        "php -r 'echo (ini_get(\"file_uploads\") ? \"1\" : \"0\");' | grep -q '1'" \
        "PHP configuré pour les uploads de fichiers" \
        "Uploads PHP désactivés"

    # Test de la limite d'upload
    local upload_limit=$(php -r 'echo ini_get("upload_max_filesize");')
    if [[ "$upload_limit" == *"M" ]] && [ "${upload_limit//M/}" -ge 100 ]; then
        echo -e "  ${GREEN}✓ Limite d'upload PHP: $upload_limit${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗ Limite d'upload trop faible: $upload_limit${NC}"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))

    echo ""
}

# Tests de la configuration réseau
test_network_config() {
    echo -e "${PURPLE}=== TESTS DE LA CONFIGURATION RÉSEAU ===${NC}"
    echo ""

    local ip_address=$(hostname -I | awk '{print $1}')

    run_detailed_test \
        "Adresse IP attribuée" \
        "[ -n '$ip_address' ]" \
        "Adresse IP: $ip_address" \
        "Aucune adresse IP détectée"

    if [ -n "$ip_address" ]; then
        run_detailed_test \
            "Interface web accessible via IP" \
            "curl -s -o /dev/null -w '%{http_code}' http://$ip_address/ | grep -q '200'" \
            "Interface accessible via http://$ip_address/" \
            "Interface inaccessible via l'IP réseau"
    fi

    echo ""
}

# Tests des fonctionnalités système
test_system_features() {
    echo -e "${PURPLE}=== TESTS DES FONCTIONNALITÉS SYSTÈME ===${NC}"
    echo ""

    # Test de la température du Pi
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        local temp_celsius=$((temp / 1000))

        if [ $temp_celsius -lt 85 ]; then
            echo -e "  ${GREEN}✓ Température CPU: ${temp_celsius}°C (OK)${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}✗ Température CPU: ${temp_celsius}°C (ÉLEVÉE!)${NC}"
            ((TESTS_FAILED++))
        fi
        ((TESTS_TOTAL++))
    fi

    # Test de l'espace disque
    local disk_usage=$(df "$PISIGNAGE_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $disk_usage -lt 90 ]; then
        echo -e "  ${GREEN}✓ Espace disque: ${disk_usage}% utilisé${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗ Espace disque critique: ${disk_usage}% utilisé${NC}"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))

    # Test de la mémoire
    local mem_usage=$(free | grep Mem: | awk '{printf("%.0f", $3/$2 * 100.0)}')
    if [ $mem_usage -lt 90 ]; then
        echo -e "  ${GREEN}✓ Utilisation mémoire: ${mem_usage}%${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗ Mémoire critique: ${mem_usage}%${NC}"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))

    echo ""
}

# Génération du rapport final
generate_report() {
    local ip_address=$(hostname -I | awk '{print $1}')

    echo -e "${CYAN}"
    echo "=================================================================="
    echo "                    RAPPORT DE VALIDATION"
    echo "=================================================================="
    echo -e "${NC}"

    echo -e "${BLUE}Tests exécutés:${NC} $TESTS_TOTAL"
    echo -e "${GREEN}Tests réussis:${NC} $TESTS_PASSED"
    echo -e "${RED}Tests échoués:${NC} $TESTS_FAILED"
    echo ""

    local success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 VALIDATION COMPLÈTE RÉUSSIE ! ($success_rate%)${NC}"
        echo -e "${GREEN}✅ PiSignage v0.8.1 GOLDEN est parfaitement opérationnel${NC}"
        echo ""
        echo -e "${CYAN}🌐 Interface web accessible:${NC}"
        echo "   • http://localhost/"
        [ -n "$ip_address" ] && echo "   • http://$ip_address/"
        echo ""
        echo -e "${CYAN}🎮 Contrôle des services:${NC}"
        echo "   • sudo systemctl status pisignage"
        echo "   • $PISIGNAGE_DIR/start-pisignage.sh"
        echo ""
        echo -e "${PURPLE}✨ Votre affichage dynamique est prêt à l'emploi !${NC}"

    elif [ $success_rate -ge 80 ]; then
        echo -e "${YELLOW}⚠️  VALIDATION PARTIELLE ($success_rate%)${NC}"
        echo -e "${YELLOW}PiSignage devrait fonctionner mais avec des limitations${NC}"
        echo ""
        echo -e "${BLUE}💡 Recommandations:${NC}"
        echo "   • Vérifiez les tests échoués ci-dessus"
        echo "   • Consultez les logs: /var/log/pisignage-install.log"
        echo "   • Relancez l'installation si nécessaire"

    else
        echo -e "${RED}❌ VALIDATION ÉCHOUÉE ($success_rate%)${NC}"
        echo -e "${RED}PiSignage nécessite des corrections avant utilisation${NC}"
        echo ""
        echo -e "${BLUE}🔧 Actions recommandées:${NC}"
        echo "   • Relancez le script d'installation"
        echo "   • Vérifiez les prérequis système"
        echo "   • Consultez la documentation"
        return 1
    fi

    echo ""
    echo -e "${CYAN}=================================================================="
    echo -e "${NC}"

    return 0
}

# Fonction principale
main() {
    print_banner

    echo -e "${BLUE}Démarrage de la validation PiSignage v0.8.1 GOLDEN...${NC}"
    echo ""

    # Exécution de tous les tests
    test_system_services
    test_critical_files
    test_permissions
    test_media_players
    test_web_interface
    test_network_config
    test_system_features

    # Rapport final
    if generate_report; then
        exit 0
    else
        exit 1
    fi
}

# Point d'entrée
main "$@"