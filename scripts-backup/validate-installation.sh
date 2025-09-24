#!/bin/bash
# PiSignage v0.8.0 - Script de validation complète de l'installation
# Vérifie que tous les composants sont fonctionnels

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/validation.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Compteurs
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

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
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
    ((PASSED_CHECKS++))
}

failure() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
    ((FAILED_CHECKS++))
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

# Fonction de test générique
check() {
    local test_name="$1"
    local test_command="$2"

    ((TOTAL_CHECKS++))

    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name"
        return 0
    else
        failure "$test_name"
        return 1
    fi
}

# Afficher le header
show_header() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              🔍 PiSignage v0.8.0 Validation 🔍               ║
║                                                              ║
║           Vérification complète de l'installation           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Vérifications système de base
check_system_basics() {
    info "=== Vérifications Système de Base ==="

    check "Répertoire principal PiSignage" "test -d '$PROJECT_DIR'"
    check "Fichier VERSION présent" "test -f '$PROJECT_DIR/VERSION'"
    check "Dossier web présent" "test -d '$PROJECT_DIR/web'"
    check "Dossier API présent" "test -d '$PROJECT_DIR/web/api'"
    check "Dossier scripts présent" "test -d '$PROJECT_DIR/scripts'"
    check "Dossier media présent" "test -d '$PROJECT_DIR/media'"
    check "Dossier config présent" "test -d '$PROJECT_DIR/config'"
    check "Dossier logs présent" "test -d '$PROJECT_DIR/logs'"

    # Vérifier la version
    if [[ -f "$PROJECT_DIR/VERSION" ]]; then
        local version=$(cat "$PROJECT_DIR/VERSION")
        if [[ "$version" == "0.8.0" ]]; then
            success "Version correcte: $version"
        else
            failure "Version incorrecte: $version (attendue: 0.8.0)"
        fi
    fi
}

# Vérifications des dépendances système
check_system_dependencies() {
    info "=== Vérifications Dépendances Système ==="

    local dependencies=(
        "nginx"
        "php"
        "php-fpm"
        "sqlite3"
        "curl"
        "wget"
        "git"
        "vlc"
        "ffmpeg"
        "scrot"
    )

    for dep in "${dependencies[@]}"; do
        check "Commande $dep disponible" "command -v $dep"
    done

    # Vérifications spécifiques PHP
    check "PHP version 7.4+" "php -v | grep -E 'PHP [7-9]\.[4-9]'"
    check "Extension PHP SQLite3" "php -m | grep -i sqlite3"
    check "Extension PHP cURL" "php -m | grep -i curl"
    check "Extension PHP GD" "php -m | grep -i gd"
}

# Vérifications des services
check_services() {
    info "=== Vérifications Services ==="

    check "Service Nginx actif" "systemctl is-active nginx"
    check "Service PHP-FPM actif" "systemctl is-active php7.4-fpm || systemctl is-active php-fpm"

    # Vérifier les ports d'écoute
    check "Nginx écoute sur port 80" "netstat -tuln | grep ':80 '"
    check "PHP-FPM socket actif" "test -S /var/run/php/php7.4-fpm.sock || test -S /run/php/php-fpm.sock"
}

# Vérifications des fichiers PHP
check_php_files() {
    info "=== Vérifications Fichiers PHP ==="

    local php_files=(
        "$PROJECT_DIR/web/config.php"
        "$PROJECT_DIR/web/index.php"
        "$PROJECT_DIR/web/api/system.php"
        "$PROJECT_DIR/web/api/media.php"
        "$PROJECT_DIR/web/api/playlist.php"
        "$PROJECT_DIR/web/api/upload.php"
        "$PROJECT_DIR/web/api/screenshot.php"
        "$PROJECT_DIR/web/api/youtube.php"
        "$PROJECT_DIR/web/api/player.php"
        "$PROJECT_DIR/web/api/scheduler.php"
    )

    for file in "${php_files[@]}"; do
        if [[ -f "$file" ]]; then
            check "Syntaxe PHP $(basename "$file")" "php -l '$file'"
        else
            failure "Fichier manquant: $(basename "$file")"
            ((TOTAL_CHECKS++))
        fi
    done
}

# Vérifications des APIs
check_apis() {
    info "=== Vérifications APIs ==="

    # Vérifier que le serveur web répond
    local base_url="http://localhost"
    local max_attempts=5
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -s --max-time 5 "$base_url" >/dev/null 2>&1; then
            success "Serveur web accessible"
            break
        else
            if [[ $attempt -eq $max_attempts ]]; then
                failure "Serveur web non accessible"
                ((TOTAL_CHECKS++))
                return
            fi
            warn "Tentative $attempt/$max_attempts: Serveur web non accessible"
            sleep 2
            ((attempt++))
        fi
    done

    # Tester les APIs principales
    local apis=(
        "system.php"
        "media.php"
        "playlist.php"
        "upload.php"
        "screenshot.php"
        "youtube.php"
        "player.php"
        "scheduler.php"
    )

    for api in "${apis[@]}"; do
        check "API $api répond" "curl -s --max-time 10 '$base_url/api/$api' | grep -q 'success'"
    done
}

# Vérifications des scripts
check_scripts() {
    info "=== Vérifications Scripts ==="

    local critical_scripts=(
        "deploy-bullseye-complete.sh"
        "install-yt-dlp.sh"
        "media-manager.sh"
        "system-monitor.sh"
        "test-apis.sh"
    )

    for script in "${critical_scripts[@]}"; do
        local script_path="$PROJECT_DIR/scripts/$script"
        check "Script $script présent" "test -f '$script_path'"
        check "Script $script exécutable" "test -x '$script_path'"

        # Vérification syntaxe bash basique
        if [[ -f "$script_path" ]]; then
            check "Syntaxe bash $script" "bash -n '$script_path'"
        fi
    done
}

# Vérifications des permissions
check_permissions() {
    info "=== Vérifications Permissions ==="

    check "Dossier media accessible en écriture" "test -w '$PROJECT_DIR/media'"
    check "Dossier config accessible en écriture" "test -w '$PROJECT_DIR/config'"
    check "Dossier logs accessible en écriture" "test -w '$PROJECT_DIR/logs'"
    check "Dossier screenshots accessible en écriture" "test -w '$PROJECT_DIR/screenshots'"

    # Vérifier que www-data peut écrire
    if command -v sudo >/dev/null 2>&1; then
        check "www-data peut écrire dans media" "sudo -u www-data test -w '$PROJECT_DIR/media'"
        check "www-data peut écrire dans logs" "sudo -u www-data test -w '$PROJECT_DIR/logs'"
    fi
}

# Vérifications optionnelles
check_optional_features() {
    info "=== Vérifications Fonctionnalités Optionnelles ==="

    # yt-dlp
    if command -v yt-dlp >/dev/null 2>&1; then
        success "yt-dlp installé: $(yt-dlp --version 2>/dev/null || echo 'version inconnue')"
    else
        warn "yt-dlp non installé (fonctionnalité YouTube indisponible)"
    fi

    # ImageMagick
    if command -v convert >/dev/null 2>&1; then
        success "ImageMagick installé"
    else
        warn "ImageMagick non installé (miniatures limitées)"
    fi

    # GPU Raspberry Pi
    if [[ -f /opt/vc/bin/vcgencmd ]]; then
        success "Outils GPU Raspberry Pi disponibles"
    else
        warn "Outils GPU Raspberry Pi non disponibles"
    fi

    # raspi2png
    if command -v raspi2png >/dev/null 2>&1; then
        success "raspi2png installé (captures GPU optimisées)"
    else
        warn "raspi2png non installé (captures standard)"
    fi
}

# Test de performance basique
check_performance() {
    info "=== Test de Performance ==="

    # Test de réponse API
    local start_time=$(date +%s%N)
    if curl -s --max-time 5 "http://localhost/api/system.php" >/dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local response_time=$(( (end_time - start_time) / 1000000 ))

        if [[ $response_time -lt 1000 ]]; then
            success "Temps de réponse API: ${response_time}ms"
        else
            warn "Temps de réponse API lent: ${response_time}ms"
        fi
    else
        failure "Test de performance échoué"
        ((TOTAL_CHECKS++))
    fi

    # Test d'espace disque
    local available_space=$(df "$PROJECT_DIR" | tail -1 | awk '{print $4}')
    if [[ $available_space -gt 1048576 ]]; then  # > 1GB
        success "Espace disque suffisant: $(( available_space / 1024 ))MB disponibles"
    else
        warn "Espace disque faible: $(( available_space / 1024 ))MB disponibles"
    fi
}

# Vérifications de sécurité basiques
check_security() {
    info "=== Vérifications Sécurité ==="

    # Vérifier que les fichiers sensibles ne sont pas accessibles via web
    local sensitive_files=(
        "config.php"
        "../scripts/deploy-bullseye-complete.sh"
        "../logs/pisignage.log"
        "../VERSION"
    )

    for file in "${sensitive_files[@]}"; do
        local url="http://localhost/$file"
        if curl -s --max-time 5 "$url" | grep -q "200 OK\|<?php\|#!/bin/bash"; then
            failure "Fichier sensible accessible: $file"
            ((TOTAL_CHECKS++))
        else
            success "Fichier sensible protégé: $file"
        fi
    done

    # Vérifier la configuration Nginx
    if nginx -t >/dev/null 2>&1; then
        success "Configuration Nginx valide"
    else
        failure "Configuration Nginx invalide"
        ((TOTAL_CHECKS++))
    fi
}

# Générer le rapport final
generate_final_report() {
    local success_rate=0
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        success_rate=$(( PASSED_CHECKS * 100 / TOTAL_CHECKS ))
    fi

    echo
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    RAPPORT DE VALIDATION                     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "Total des vérifications: ${BLUE}$TOTAL_CHECKS${NC}"
    echo -e "Vérifications réussies:  ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Vérifications échouées:  ${RED}$FAILED_CHECKS${NC}"
    echo -e "Taux de réussite:        ${GREEN}$success_rate%${NC}"
    echo

    # Diagnostic général
    if [[ $success_rate -ge 95 ]]; then
        echo -e "${GREEN}🎉 EXCELLENT ! PiSignage est parfaitement configuré et prêt pour la production.${NC}"
    elif [[ $success_rate -ge 85 ]]; then
        echo -e "${GREEN}✅ BIEN ! PiSignage est fonctionnel avec quelques améliorations mineures possibles.${NC}"
    elif [[ $success_rate -ge 70 ]]; then
        echo -e "${YELLOW}⚠️  CORRECT ! PiSignage fonctionne mais nécessite quelques corrections.${NC}"
    else
        echo -e "${RED}❌ PROBLÉMATIQUE ! Plusieurs composants critiques ne fonctionnent pas correctement.${NC}"
    fi

    echo
    echo -e "${BLUE}Prochaines étapes recommandées:${NC}"

    if [[ $success_rate -ge 85 ]]; then
        echo -e "  1. ${GREEN}Tester l'interface web: http://$(hostname -I | awk '{print $1}')${NC}"
        echo -e "  2. ${GREEN}Ajouter des fichiers médias dans /opt/pisignage/media/${NC}"
        echo -e "  3. ${GREEN}Créer des playlists via l'interface web${NC}"
        echo -e "  4. ${GREEN}Configurer l'autostart si souhaité${NC}"
    else
        echo -e "  1. ${YELLOW}Vérifier les logs détaillés: $LOG_FILE${NC}"
        echo -e "  2. ${YELLOW}Corriger les problèmes identifiés${NC}"
        echo -e "  3. ${YELLOW}Relancer la validation: $0${NC}"
        echo -e "  4. ${YELLOW}Consulter la documentation: BACKEND-IMPLEMENTATION-SUMMARY.md${NC}"
    fi

    echo
    echo -e "Log complet: ${YELLOW}$LOG_FILE${NC}"
    echo -e "Documentation: ${YELLOW}$PROJECT_DIR/BACKEND-IMPLEMENTATION-SUMMARY.md${NC}"
    echo

    # Code de sortie
    if [[ $success_rate -ge 85 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Fonction principale
main() {
    local start_time=$(date -Iseconds)

    show_header
    log "=== Validation PiSignage v0.8.0 démarrée à $start_time ==="

    check_system_basics
    check_system_dependencies
    check_services
    check_php_files
    check_apis
    check_scripts
    check_permissions
    check_optional_features
    check_performance
    check_security

    log "=== Validation terminée ==="
    generate_final_report
}

# Gestion des arguments
case "${1:-}" in
    --help|-h)
        echo "PiSignage v0.8.0 - Script de validation complète"
        echo
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Afficher cette aide"
        echo "  --quick        Validation rapide (composants critiques seulement)"
        echo "  --verbose      Affichage détaillé"
        echo
        echo "Ce script vérifie que tous les composants PiSignage sont"
        echo "correctement installés et configurés."
        echo
        exit 0
        ;;
    --quick)
        # Mode rapide - seulement les vérifications critiques
        info "Mode validation rapide activé"
        check_system_basics
        check_services
        check_apis
        generate_final_report
        ;;
    --verbose)
        # Mode verbeux
        set -x
        main
        ;;
    *)
        main
        ;;
esac