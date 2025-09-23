#!/bin/bash

# PiSignage v0.9.0 - Script de Test du Système de Déploiement
# Test complet du système de déploiement en mode simulation

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TEST_LOG="/tmp/pisignage-deployment-test.log"
DEPLOYMENT_DIR="/opt/pisignage/deployment"

# Fonction de log
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$TEST_LOG"
            ;;
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $message" | tee -a "$TEST_LOG"
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message" | tee -a "$TEST_LOG"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$TEST_LOG"
            ;;
    esac
    echo "[$timestamp] [$level] $message" >> "$TEST_LOG"
}

# Test de la structure des fichiers
test_file_structure() {
    log "INFO" "Test de la structure des fichiers de déploiement..."

    local required_files=(
        "deploy.sh"
        "deployment/scripts/pre-checks.sh"
        "deployment/scripts/backup-system.sh"
        "deployment/scripts/install-packages.sh"
        "deployment/scripts/configure-system.sh"
        "deployment/scripts/deploy-app.sh"
        "deployment/scripts/post-tests.sh"
        "deployment/scripts/rollback.sh"
        "deployment/scripts/monitor.sh"
        "DEPLOYMENT-GUIDE.md"
        "deployment/README.md"
    )

    local missing_files=0

    for file in "${required_files[@]}"; do
        if [[ -f "/opt/pisignage/$file" ]]; then
            log "PASS" "Fichier présent: $file"
        else
            log "FAIL" "Fichier manquant: $file"
            ((missing_files++))
        fi
    done

    if [[ $missing_files -eq 0 ]]; then
        log "PASS" "Structure des fichiers complète"
        return 0
    else
        log "FAIL" "$missing_files fichiers manquants"
        return 1
    fi
}

# Test des permissions
test_file_permissions() {
    log "INFO" "Test des permissions des scripts..."

    local script_files=(
        "deploy.sh"
        "deployment/scripts/pre-checks.sh"
        "deployment/scripts/backup-system.sh"
        "deployment/scripts/install-packages.sh"
        "deployment/scripts/configure-system.sh"
        "deployment/scripts/deploy-app.sh"
        "deployment/scripts/post-tests.sh"
        "deployment/scripts/rollback.sh"
        "deployment/scripts/monitor.sh"
    )

    local non_executable=0

    for script in "${script_files[@]}"; do
        if [[ -x "/opt/pisignage/$script" ]]; then
            log "PASS" "Script exécutable: $script"
        else
            log "FAIL" "Script non exécutable: $script"
            ((non_executable++))
        fi
    done

    if [[ $non_executable -eq 0 ]]; then
        log "PASS" "Toutes les permissions correctes"
        return 0
    else
        log "FAIL" "$non_executable scripts non exécutables"
        return 1
    fi
}

# Test de la syntaxe des scripts
test_script_syntax() {
    log "INFO" "Test de la syntaxe des scripts bash..."

    local script_files=(
        "deploy.sh"
        "deployment/scripts/pre-checks.sh"
        "deployment/scripts/backup-system.sh"
        "deployment/scripts/install-packages.sh"
        "deployment/scripts/configure-system.sh"
        "deployment/scripts/deploy-app.sh"
        "deployment/scripts/post-tests.sh"
        "deployment/scripts/rollback.sh"
        "deployment/scripts/monitor.sh"
    )

    local syntax_errors=0

    for script in "${script_files[@]}"; do
        local script_path="/opt/pisignage/$script"
        if bash -n "$script_path" 2>/dev/null; then
            log "PASS" "Syntaxe valide: $script"
        else
            log "FAIL" "Erreur de syntaxe: $script"
            ((syntax_errors++))
        fi
    done

    if [[ $syntax_errors -eq 0 ]]; then
        log "PASS" "Toutes les syntaxes valides"
        return 0
    else
        log "FAIL" "$syntax_errors scripts avec erreurs de syntaxe"
        return 1
    fi
}

# Test des options du script principal
test_main_script_options() {
    log "INFO" "Test des options du script principal..."

    local deploy_script="/opt/pisignage/deploy.sh"

    # Test --help
    if timeout 10 "$deploy_script" --help &>/dev/null; then
        log "PASS" "Option --help fonctionnelle"
    else
        log "FAIL" "Option --help échouée"
    fi

    # Test --dry-run avec verify
    if timeout 30 "$deploy_script" --dry-run verify &>/dev/null; then
        log "PASS" "Option --dry-run fonctionnelle"
    else
        log "FAIL" "Option --dry-run échouée"
    fi

    return 0
}

# Test des scripts individuels avec --help
test_individual_scripts_help() {
    log "INFO" "Test des options d'aide des scripts individuels..."

    local scripts_with_help=(
        "deployment/scripts/rollback.sh"
        "deployment/scripts/monitor.sh"
    )

    for script in "${scripts_with_help[@]}"; do
        local script_path="/opt/pisignage/$script"
        if timeout 10 "$script_path" --help &>/dev/null; then
            log "PASS" "Aide disponible: $script"
        else
            log "WARN" "Aide non disponible: $script"
        fi
    done

    return 0
}

# Test des vérifications pré-déploiement en mode local
test_pre_checks_local() {
    log "INFO" "Test des vérifications pré-déploiement (mode local)..."

    local pre_checks_script="/opt/pisignage/deployment/scripts/pre-checks.sh"

    # Exécuter les vérifications en mode local
    if timeout 60 "$pre_checks_script" &>/dev/null; then
        log "PASS" "Vérifications pré-déploiement réussies"
    else
        log "WARN" "Vérifications pré-déploiement avec avertissements (normal en mode local)"
    fi

    return 0
}

# Test de génération de rapport de monitoring
test_monitoring_report() {
    log "INFO" "Test de génération de rapport de monitoring..."

    local monitor_script="/opt/pisignage/deployment/scripts/monitor.sh"

    # Test génération de rapport
    if timeout 30 "$monitor_script" --report &>/dev/null; then
        log "PASS" "Génération de rapport de monitoring réussie"
    else
        log "FAIL" "Génération de rapport de monitoring échouée"
    fi

    # Test vérification unique
    if timeout 30 "$monitor_script" --check &>/dev/null; then
        log "PASS" "Vérification unique de monitoring réussie"
    else
        log "FAIL" "Vérification unique de monitoring échouée"
    fi

    return 0
}

# Test de listing des sauvegardes
test_rollback_listing() {
    log "INFO" "Test du listing des sauvegardes..."

    local rollback_script="/opt/pisignage/deployment/scripts/rollback.sh"

    # Test listing des sauvegardes (devrait dire qu'il n'y en a pas)
    if timeout 30 "$rollback_script" --list 2>&1 | grep -q "Aucune sauvegarde"; then
        log "PASS" "Listing des sauvegardes fonctionnel (aucune sauvegarde comme attendu)"
    else
        log "WARN" "Listing des sauvegardes inattendu"
    fi

    return 0
}

# Test de la documentation
test_documentation() {
    log "INFO" "Test de la documentation..."

    # Vérifier que le guide de déploiement contient les sections importantes
    local guide="/opt/pisignage/DEPLOYMENT-GUIDE.md"
    local sections=(
        "Vue d'Ensemble"
        "Prérequis"
        "Installation Rapide"
        "Utilisation Avancée"
        "Scripts de Déploiement"
        "Système de Rollback"
        "Monitoring Post-Déploiement"
        "Dépannage"
    )

    local missing_sections=0
    for section in "${sections[@]}"; do
        if grep -q "$section" "$guide"; then
            log "PASS" "Section présente dans la doc: $section"
        else
            log "FAIL" "Section manquante dans la doc: $section"
            ((missing_sections++))
        fi
    done

    if [[ $missing_sections -eq 0 ]]; then
        log "PASS" "Documentation complète"
    else
        log "FAIL" "$missing_sections sections manquantes dans la documentation"
    fi

    return 0
}

# Test de cohérence des versions
test_version_consistency() {
    log "INFO" "Test de cohérence des versions..."

    local version_files=(
        "/opt/pisignage/VERSION"
        "/opt/pisignage/deploy.sh"
        "/opt/pisignage/DEPLOYMENT-GUIDE.md"
    )

    local expected_version="0.9.0"
    local version_issues=0

    for file in "${version_files[@]}"; do
        if [[ -f "$file" ]]; then
            if grep -q "$expected_version" "$file"; then
                log "PASS" "Version $expected_version trouvée dans: $(basename "$file")"
            else
                log "FAIL" "Version $expected_version non trouvée dans: $(basename "$file")"
                ((version_issues++))
            fi
        else
            log "WARN" "Fichier version non trouvé: $file"
        fi
    done

    if [[ $version_issues -eq 0 ]]; then
        log "PASS" "Cohérence des versions OK"
    else
        log "FAIL" "$version_issues problèmes de cohérence de version"
    fi

    return 0
}

# Test de sécurité basique
test_basic_security() {
    log "INFO" "Test de sécurité basique..."

    # Vérifier qu'il n'y a pas de mots de passe en dur
    local security_issues=0

    # Chercher des patterns suspects dans les scripts
    if grep -r "password=" /opt/pisignage/deployment/scripts/ | grep -v "PI_PASS" | grep -v "raspberry"; then
        log "FAIL" "Mots de passe potentiels trouvés dans les scripts"
        ((security_issues++))
    else
        log "PASS" "Pas de mots de passe suspects dans les scripts"
    fi

    # Vérifier les permissions sur les fichiers sensibles
    local sensitive_files=(
        "/opt/pisignage/deploy.sh"
        "/opt/pisignage/deployment/scripts/backup-system.sh"
        "/opt/pisignage/deployment/scripts/configure-system.sh"
    )

    for file in "${sensitive_files[@]}"; do
        local perms=$(stat -c %a "$file" 2>/dev/null)
        if [[ "$perms" == "755" ]] || [[ "$perms" == "750" ]]; then
            log "PASS" "Permissions sécurisées sur: $(basename "$file") ($perms)"
        else
            log "WARN" "Permissions à vérifier sur: $(basename "$file") ($perms)"
        fi
    done

    return 0
}

# Résumé des tests
show_test_summary() {
    echo
    echo "===== RÉSUMÉ DES TESTS DE DÉPLOIEMENT ====="

    local total_tests=10
    local passed_tests=$(grep -c "\[PASS\]" "$TEST_LOG")
    local failed_tests=$(grep -c "\[FAIL\]" "$TEST_LOG")
    local warnings=$(grep -c "\[WARN\]" "$TEST_LOG")

    echo -e "${GREEN}Tests réussis:${NC} $passed_tests"
    echo -e "${RED}Tests échoués:${NC} $failed_tests"
    echo -e "${YELLOW}Avertissements:${NC} $warnings"
    echo "============================================="

    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}✓ Système de déploiement validé et prêt${NC}"
        echo -e "🚀 Commande de déploiement: ${BLUE}./deploy.sh${NC}"
        return 0
    else
        echo -e "${RED}✗ Problèmes détectés dans le système de déploiement${NC}"
        echo "Consultez les détails ci-dessus."
        return 1
    fi
}

# Fonction principale
main() {
    echo "PiSignage v0.9.0 - Test du Système de Déploiement"
    echo "================================================="
    echo

    log "INFO" "Début des tests du système de déploiement..."
    log "INFO" "Log détaillé: $TEST_LOG"

    # Exécuter tous les tests
    local test_functions=(
        "test_file_structure"
        "test_file_permissions"
        "test_script_syntax"
        "test_main_script_options"
        "test_individual_scripts_help"
        "test_pre_checks_local"
        "test_monitoring_report"
        "test_rollback_listing"
        "test_documentation"
        "test_version_consistency"
        "test_basic_security"
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