#!/bin/bash

# PiSignage v0.8.0 - Script de validation d'installation
# Teste tous les composants avant déploiement
# Auteur: Claude Code
# Date: 22/09/2025

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
ERRORS=0
WARNINGS=0

log() {
    echo -e "${GREEN}[VALID] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[VALID] WARNING: $1${NC}"
    ((WARNINGS++))
}

error() {
    echo -e "${RED}[VALID] ERROR: $1${NC}"
    ((ERRORS++))
}

info() {
    echo -e "${BLUE}[VALID] INFO: $1${NC}"
}

# Test de la structure des fichiers
test_file_structure() {
    log "Test de la structure des fichiers..."

    local required_files=(
        "/opt/pisignage/install.sh"
        "/opt/pisignage/setup-vlc.sh"
        "/opt/pisignage/setup-web.sh"
        "/opt/pisignage/optimize-pi.sh"
        "/opt/pisignage/pisignage.service"
        "/opt/pisignage/scripts/pisignage-start.sh"
        "/opt/pisignage/scripts/pisignage-stop.sh"
        "/opt/pisignage/scripts/pisignage-reload.sh"
    )

    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            if [ -x "$file" ]; then
                log "✅ $file (exécutable)"
            else
                warn "$file non exécutable"
            fi
        else
            error "$file manquant"
        fi
    done

    log "Test structure terminé"
}

# Test des dépendances système
test_system_dependencies() {
    log "Test des dépendances système..."

    local commands=(
        "nginx"
        "php8.2"
        "vlc"
        "python3"
        "curl"
        "wget"
        "git"
        "systemctl"
    )

    for cmd in "${commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log "✅ $cmd disponible"
        else
            warn "$cmd non installé"
        fi
    done

    # Test spécifique yt-dlp
    if command -v yt-dlp >/dev/null 2>&1; then
        log "✅ yt-dlp disponible"
    else
        warn "yt-dlp non installé"
    fi

    log "Test dépendances terminé"
}

# Test de la syntaxe des scripts
test_script_syntax() {
    log "Test de la syntaxe des scripts..."

    local scripts=(
        "/opt/pisignage/install.sh"
        "/opt/pisignage/setup-vlc.sh"
        "/opt/pisignage/setup-web.sh"
        "/opt/pisignage/optimize-pi.sh"
        "/opt/pisignage/scripts/pisignage-start.sh"
        "/opt/pisignage/scripts/pisignage-stop.sh"
        "/opt/pisignage/scripts/pisignage-reload.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if bash -n "$script" 2>/dev/null; then
                log "✅ $(basename "$script") syntaxe OK"
            else
                error "$(basename "$script") erreur de syntaxe"
            fi
        fi
    done

    log "Test syntaxe terminé"
}

# Test du service systemd
test_systemd_service() {
    log "Test du service systemd..."

    local service_file="/opt/pisignage/pisignage.service"

    if [ -f "$service_file" ]; then
        # Vérifier la syntaxe du service
        if systemd-analyze verify "$service_file" 2>/dev/null; then
            log "✅ Service systemd syntaxe OK"
        else
            warn "Service systemd problème de syntaxe"
        fi

        # Vérifier les chemins dans le service
        if grep -q "/opt/pisignage/scripts/pisignage-start.sh" "$service_file"; then
            log "✅ Chemins corrects dans le service"
        else
            error "Chemins incorrects dans le service"
        fi
    else
        error "Fichier service manquant"
    fi

    log "Test service terminé"
}

# Test des permissions
test_permissions() {
    log "Test des permissions..."

    local directories=(
        "/opt/pisignage"
        "/opt/pisignage/scripts"
        "/opt/pisignage/media"
        "/opt/pisignage/logs"
    )

    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            if [ -r "$dir" ] && [ -w "$dir" ]; then
                log "✅ $dir permissions OK"
            else
                warn "$dir permissions insuffisantes"
            fi
        else
            warn "$dir n'existe pas"
        fi
    done

    log "Test permissions terminé"
}

# Test des configurations par défaut
test_default_configs() {
    log "Test des configurations par défaut..."

    # Test du fichier VERSION
    if [ -f "/opt/pisignage/VERSION" ]; then
        local version=$(cat "/opt/pisignage/VERSION")
        if [ "$version" = "0.8.0" ]; then
            log "✅ Version correcte: $version"
        else
            warn "Version inattendue: $version"
        fi
    else
        warn "Fichier VERSION manquant"
    fi

    # Test de la structure web
    if [ -d "/opt/pisignage/web" ]; then
        log "✅ Répertoire web existe"
    else
        warn "Répertoire web manquant"
    fi

    log "Test configurations terminé"
}

# Test d'intégration des scripts
test_script_integration() {
    log "Test d'intégration des scripts..."

    # Test que les scripts se référencent correctement
    local main_scripts=(
        "/opt/pisignage/install.sh"
        "/opt/pisignage/setup-vlc.sh"
        "/opt/pisignage/setup-web.sh"
        "/opt/pisignage/optimize-pi.sh"
    )

    for script in "${main_scripts[@]}"; do
        if [ -f "$script" ]; then
            # Vérifier que le script contient la version correcte
            if grep -q "v0.8.0" "$script"; then
                log "✅ $(basename "$script") version correcte"
            else
                warn "$(basename "$script") version non spécifiée"
            fi

            # Vérifier les paths
            if grep -q "/opt/pisignage" "$script"; then
                log "✅ $(basename "$script") chemins corrects"
            else
                error "$(basename "$script") chemins incorrects"
            fi
        fi
    done

    log "Test intégration terminé"
}

# Test de sécurité basique
test_security() {
    log "Test de sécurité basique..."

    # Vérifier qu'aucun script ne contient de hardcoded passwords
    local suspicious_patterns=(
        "password="
        "passwd="
        "secret="
        "key="
    )

    for pattern in "${suspicious_patterns[@]}"; do
        if grep -r "$pattern" /opt/pisignage/ 2>/dev/null | grep -v "# " | grep -v "raspberry"; then
            warn "Pattern suspect trouvé: $pattern"
        fi
    done

    # Vérifier les permissions des scripts sensibles
    local sensitive_scripts=(
        "/opt/pisignage/scripts/pisignage-start.sh"
        "/opt/pisignage/scripts/pisignage-stop.sh"
    )

    for script in "${sensitive_scripts[@]}"; do
        if [ -f "$script" ]; then
            local perms=$(stat -c "%a" "$script")
            if [ "$perms" -le "755" ]; then
                log "✅ $(basename "$script") permissions sécurisées ($perms)"
            else
                warn "$(basename "$script") permissions trop larges ($perms)"
            fi
        fi
    done

    log "Test sécurité terminé"
}

# Génération du rapport
generate_report() {
    echo ""
    echo "=============================================="
    echo "📋 RAPPORT DE VALIDATION PISIGNAGE v0.8.0"
    echo "=============================================="
    echo ""
    echo "📊 Résultats:"
    echo "   Erreurs: $ERRORS"
    echo "   Avertissements: $WARNINGS"
    echo ""

    if [ $ERRORS -eq 0 ]; then
        if [ $WARNINGS -eq 0 ]; then
            echo -e "${GREEN}✅ VALIDATION RÉUSSIE - Prêt pour déploiement${NC}"
            echo ""
            echo "🚀 Commandes de déploiement:"
            echo "   sudo /opt/pisignage/install.sh"
            echo "   sudo reboot"
        else
            echo -e "${YELLOW}⚠️  VALIDATION OK AVEC AVERTISSEMENTS${NC}"
            echo ""
            echo "💡 Recommandations:"
            echo "   - Vérifier les avertissements ci-dessus"
            echo "   - Tester en environnement de développement"
        fi
    else
        echo -e "${RED}❌ VALIDATION ÉCHOUÉE - Corrections requises${NC}"
        echo ""
        echo "🔧 Actions requises:"
        echo "   - Corriger les erreurs listées ci-dessus"
        echo "   - Relancer la validation"
        echo "   - Ne pas déployer en production"
    fi

    echo ""
    echo "📄 Fichiers validés:"
    echo "   - Scripts d'installation: 4"
    echo "   - Scripts de service: 3"
    echo "   - Service systemd: 1"
    echo "   - Total: 8 composants"
    echo ""
    echo "🔗 Documentation:"
    echo "   - README.md: /opt/pisignage/README.md"
    echo "   - Logs: /opt/pisignage/logs/"
    echo "   - Version: $(cat /opt/pisignage/VERSION 2>/dev/null || echo 'Non trouvée')"
    echo ""
    echo "=============================================="
}

# Fonction principale
main() {
    echo ""
    log "🔍 Démarrage validation installation PiSignage v0.8.0"
    echo ""

    test_file_structure
    test_system_dependencies
    test_script_syntax
    test_systemd_service
    test_permissions
    test_default_configs
    test_script_integration
    test_security

    generate_report

    # Code de sortie basé sur les erreurs
    if [ $ERRORS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Exécution
main "$@"