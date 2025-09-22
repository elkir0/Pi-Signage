#!/bin/bash
# PiSignage v0.8.0 - Déploiement Architecture Screenshot Complète
# Script de déploiement automatique pour Raspberry Pi

set -e

VERSION="0.8.0"
LOG_FILE="/opt/pisignage/logs/screenshot-deployment.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                PiSignage v$VERSION                              ║${NC}"
    echo -e "${PURPLE}║            ARCHITECTURE SCREENSHOT ROBUSTE                   ║${NC}"
    echo -e "${PURPLE}║              Déploiement Automatique                        ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
    log_message "SUCCESS: $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
    log_message "INFO: $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
    log_message "WARNING: $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    log_message "ERROR: $1"
}

check_environment() {
    print_info "Vérification de l'environnement..."

    # Vérifier si on est sur Raspberry Pi
    if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        print_warning "Ce script est optimisé pour Raspberry Pi"
    fi

    # Vérifier les permissions sudo
    if ! sudo -n true 2>/dev/null; then
        print_error "Permissions sudo requises"
        exit 1
    fi

    # Vérifier l'espace disque
    local available_space=$(df /opt/pisignage | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then  # 1GB
        print_warning "Espace disque faible: ${available_space}KB disponible"
    fi

    print_status "Environnement validé"
}

install_dependencies() {
    print_info "Installation des dépendances système..."

    # Mise à jour des paquets
    sudo apt-get update -qq

    # Dépendances essentielles
    local packages=(
        "build-essential"
        "git"
        "cmake"
        "libpng-dev"
        "scrot"
        "imagemagick"
        "fbgrab"
    )

    local missing_packages=()
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$package" 2>/dev/null; then
            missing_packages+=("$package")
        fi
    done

    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_info "Installation: ${missing_packages[*]}"
        sudo apt-get install -y "${missing_packages[@]}"
    fi

    print_status "Dépendances installées"
}

deploy_raspi2png() {
    print_info "Déploiement raspi2png optimisé..."

    if [[ -x "/opt/pisignage/scripts/install-raspi2png.sh" ]]; then
        /opt/pisignage/scripts/install-raspi2png.sh
        print_status "raspi2png déployé avec optimisations"
    else
        print_error "Script install-raspi2png.sh non trouvé"
        return 1
    fi
}

deploy_system_optimizations() {
    print_info "Déploiement des optimisations système..."

    if [[ -x "/opt/pisignage/scripts/optimize-screenshot-vlc.sh" ]]; then
        /opt/pisignage/scripts/optimize-screenshot-vlc.sh
        print_status "Optimisations système déployées"
    else
        print_error "Script optimize-screenshot-vlc.sh non trouvé"
        return 1
    fi
}

configure_web_service() {
    print_info "Configuration du service web..."

    # Vérifier nginx
    if ! systemctl is-active --quiet nginx; then
        print_warning "Nginx non actif, tentative de démarrage..."
        sudo systemctl start nginx
    fi

    # Vérifier PHP-FPM
    if ! systemctl is-active --quiet php*-fpm; then
        print_warning "PHP-FPM non actif, tentative de démarrage..."
        sudo systemctl start php*-fpm
    fi

    # Permissions cache
    sudo mkdir -p /dev/shm/pisignage
    sudo chown -R www-data:www-data /dev/shm/pisignage
    sudo chmod 755 /dev/shm/pisignage

    # Permissions screenshots
    sudo chown -R www-data:www-data /opt/pisignage/screenshots
    sudo chmod 755 /opt/pisignage/screenshots

    print_status "Service web configuré"
}

run_performance_tests() {
    print_info "Exécution des tests de performance..."

    local test_results=()

    # Test 1: raspi2png disponible
    if command -v raspi2png >/dev/null 2>&1; then
        print_status "✓ raspi2png disponible"
        test_results+=("raspi2png: OK")
    else
        print_warning "✗ raspi2png non disponible"
        test_results+=("raspi2png: FAILED")
    fi

    # Test 2: DispmanX fonctionnel
    if /opt/pisignage/tools/test-dispmanx.sh >/dev/null 2>&1; then
        print_status "✓ DispmanX fonctionnel"
        test_results+=("dispmanx: OK")
    else
        print_warning "✗ DispmanX test failed"
        test_results+=("dispmanx: FAILED")
    fi

    # Test 3: Cache performance
    if [[ -w "/dev/shm/pisignage" ]]; then
        print_status "✓ Cache haute performance accessible"
        test_results+=("cache: OK")
    else
        print_warning "✗ Cache haute performance inaccessible"
        test_results+=("cache: FAILED")
    fi

    # Test 4: API fonctionnelle
    if curl -s "http://localhost/api/screenshot.php?action=status" | grep -q "success" 2>/dev/null; then
        print_status "✓ API screenshot accessible"
        test_results+=("api: OK")
    else
        print_warning "✗ API screenshot non accessible"
        test_results+=("api: FAILED")
    fi

    # Test 5: Capture wrapper
    if [[ -x "/opt/pisignage/config/screenshot/capture-wrapper.sh" ]]; then
        print_status "✓ Wrapper de capture disponible"
        test_results+=("wrapper: OK")
    else
        print_warning "✗ Wrapper de capture manquant"
        test_results+=("wrapper: FAILED")
    fi

    # Résumé des tests
    local failed_tests=0
    echo ""
    print_info "Résumé des tests:"
    for result in "${test_results[@]}"; do
        if [[ "$result" == *"FAILED" ]]; then
            echo -e "  ${RED}✗${NC} $result"
            ((failed_tests++))
        else
            echo -e "  ${GREEN}✓${NC} $result"
        fi
    done

    if [[ $failed_tests -eq 0 ]]; then
        print_status "Tous les tests passés avec succès"
        return 0
    else
        print_warning "$failed_tests test(s) échoué(s)"
        return 1
    fi
}

create_usage_documentation() {
    print_info "Création de la documentation d'usage..."

    cat > "/opt/pisignage/SCREENSHOT-USAGE.md" << 'EOF'
# 📸 Guide d'Usage - Architecture Screenshot PiSignage v0.8.0

## 🚀 Commandes Rapides

### Capture Manuelle Optimisée
```bash
# Capture rapide avec raspi2png
/opt/pisignage/config/screenshot/capture-wrapper.sh quick

# Capture avec méthode spécifique
/opt/pisignage/config/screenshot/capture-wrapper.sh capture /tmp/test.png raspi2png

# Test de performance (5 captures)
/opt/pisignage/config/screenshot/capture-wrapper.sh test
```

### API REST
```bash
# Capture via API
curl "http://localhost/api/screenshot.php?action=capture&format=png&quality=85"

# Liste des captures récentes
curl "http://localhost/api/screenshot.php?action=list&limit=5"

# Status de l'API
curl "http://localhost/api/screenshot.php?action=status"
```

### Monitoring Performance
```bash
# Performance récente
/opt/pisignage/config/screenshot/monitor-performance.sh performance

# État système
/opt/pisignage/config/screenshot/monitor-performance.sh system

# Tout
/opt/pisignage/config/screenshot/monitor-performance.sh all
```

## 📊 Performance Attendue

| Méthode | Raspberry Pi 2 | Raspberry Pi 3 | Raspberry Pi 4 |
|---------|----------------|----------------|----------------|
| raspi2png | 35-50ms | 25-35ms | 15-25ms |
| scrot | 50-80ms | 40-60ms | 30-50ms |
| fbgrab | 80-120ms | 60-100ms | 50-80ms |

## 🔧 Dépannage

### Capture Lente
```bash
# Vérifier GPU memory
vcgencmd get_mem gpu

# Ajuster si nécessaire (redémarrage requis)
echo "gpu_mem=256" | sudo tee -a /boot/config.txt
```

### Cache Plein
```bash
# Vérifier utilisation
du -sh /dev/shm/pisignage/

# Nettoyage manuel
sudo rm -rf /dev/shm/pisignage/screenshot_*
```

### VLC Impact
```bash
# Vérifier priorités
ps -eo pid,ni,comm | grep vlc

# Réajuster si nécessaire
/opt/pisignage/scripts/optimize-screenshot-vlc.sh
```

## 📈 Logs et Monitoring

- **Performance**: `/opt/pisignage/logs/screenshot-performance.log`
- **Installation**: `/opt/pisignage/logs/raspi2png-install.log`
- **Optimisation**: `/opt/pisignage/logs/screenshot-optimization.log`
- **API**: `/opt/pisignage/logs/pisignage.log`

EOF

    print_status "Documentation d'usage créée: /opt/pisignage/SCREENSHOT-USAGE.md"
}

show_deployment_summary() {
    local pi_model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Unknown Pi")
    local gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null || echo "gpu=unknown")
    local available_methods=()

    # Détecter méthodes disponibles
    command -v raspi2png >/dev/null 2>&1 && available_methods+=("raspi2png")
    command -v scrot >/dev/null 2>&1 && available_methods+=("scrot")
    command -v fbgrab >/dev/null 2>&1 && available_methods+=("fbgrab")
    command -v import >/dev/null 2>&1 && available_methods+=("import")

    cat << EOF

${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}
${PURPLE}║                    DÉPLOIEMENT TERMINÉ                      ║${NC}
${PURPLE}║                  PiSignage v$VERSION                           ║${NC}
${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}

${GREEN}🎯 CONFIGURATION DÉTECTÉE:${NC}
  • Modèle: $pi_model
  • GPU Memory: $gpu_mem
  • Méthodes: ${available_methods[*]}

${GREEN}🚀 ARCHITECTURE DÉPLOYÉE:${NC}
  • raspi2png optimisé avec compilation native
  • Cache haute performance /dev/shm
  • API REST complète avec rate limiting
  • Wrapper de capture intelligent
  • Monitoring et logs de performance

${GREEN}📊 PERFORMANCE OPTIMISÉE:${NC}
  • Priorités dynamiques VLC/Capture
  • CPU scaling intelligent
  • GPU memory optimisée
  • Compression adaptative

${GREEN}🔧 COMMANDES PRINCIPALES:${NC}
  • Test performance  : /opt/pisignage/config/screenshot/capture-wrapper.sh test
  • Monitoring        : /opt/pisignage/config/screenshot/monitor-performance.sh
  • API status        : curl localhost/api/screenshot.php?action=status
  • Documentation     : cat /opt/pisignage/SCREENSHOT-USAGE.md

${YELLOW}⚠️  ACTIONS REQUISES:${NC}
EOF

    # Vérifier si redémarrage nécessaire
    if grep -q "gpu_mem=" /boot/config.txt 2>/dev/null || grep -q "gpu_mem=" /boot/firmware/config.txt 2>/dev/null; then
        echo -e "  • ${YELLOW}Redémarrer le système pour appliquer les modifications GPU${NC}"
        echo -e "    ${BLUE}sudo reboot${NC}"
    fi

    echo -e "  • ${GREEN}Tester la capture: ${BLUE}/opt/pisignage/config/screenshot/capture-wrapper.sh test${NC}"
    echo -e "  • ${GREEN}Vérifier logs: ${BLUE}tail -f /opt/pisignage/logs/screenshot-performance.log${NC}"

    echo ""
    print_status "Architecture Screenshot PiSignage v$VERSION déployée avec succès!"
}

# Gestion des erreurs
error_handler() {
    print_error "Erreur lors du déploiement à la ligne $1"
    print_info "Vérifiez les logs: $LOG_FILE"
    exit 1
}
trap 'error_handler $LINENO' ERR

# Exécution principale
main() {
    # Créer répertoire logs
    mkdir -p "$(dirname "$LOG_FILE")"

    print_header

    print_info "Début du déploiement de l'architecture screenshot..."
    log_message "=== DÉBUT DÉPLOIEMENT SCREENSHOT ARCHITECTURE v$VERSION ==="

    check_environment
    install_dependencies
    deploy_raspi2png
    deploy_system_optimizations
    configure_web_service
    create_usage_documentation

    if run_performance_tests; then
        show_deployment_summary
        log_message "=== DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ==="
        exit 0
    else
        print_warning "Déploiement terminé avec des avertissements"
        print_info "Consultez les logs pour plus de détails: $LOG_FILE"
        log_message "=== DÉPLOIEMENT TERMINÉ AVEC AVERTISSEMENTS ==="
        exit 2
    fi
}

main "$@"