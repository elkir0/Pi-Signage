#!/usr/bin/env bash

# =============================================================================
# Script de déploiement propre Pi Signage v2.4.9
# Version: 2.4.9
# Description: Déploiement avec toutes les corrections intégrées
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
readonly INSTALLER_DIR="/home/pi/pi-signage-installer"
readonly VERSION="2.4.9"

log_info() { echo -e "${GREEN}[DEPLOY]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[DEPLOY]${NC} $*"; }
log_error() { echo -e "${RED}[DEPLOY]${NC} $*" >&2; }

# =============================================================================
# VÉRIFICATIONS PRÉLIMINAIRES
# =============================================================================

check_prerequisites() {
    log_info "=== Vérifications préliminaires ==="
    
    # Vérifier qu'on est sur Raspberry Pi
    if [[ ! -f /proc/device-tree/model ]]; then
        log_warn "Ce n'est pas un Raspberry Pi, continuez à vos risques"
    else
        local model=$(tr -d '\0' < /proc/device-tree/model)
        log_info "Modèle détecté: $model"
    fi
    
    # Vérifier l'OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "OS: $PRETTY_NAME"
        
        if [[ "$VERSION_CODENAME" == "bookworm" ]]; then
            log_info "✓ Raspberry Pi OS Bookworm détecté"
        else
            log_warn "OS non testé: $VERSION_CODENAME"
        fi
    fi
    
    # Vérifier l'espace disque
    local available=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available -lt 2 ]]; then
        log_error "Espace disque insuffisant: ${available}GB (minimum 2GB requis)"
        return 1
    fi
    log_info "✓ Espace disque: ${available}GB disponible"
    
    # Vérifier la connexion Internet
    if ping -c 1 github.com >/dev/null 2>&1; then
        log_info "✓ Connexion Internet OK"
    else
        log_error "Pas de connexion Internet"
        return 1
    fi
}

# =============================================================================
# TÉLÉCHARGEMENT DEPUIS GITHUB
# =============================================================================

download_from_github() {
    log_info "=== Téléchargement depuis GitHub ==="
    
    # Nettoyer les anciennes installations
    if [[ -d "$INSTALLER_DIR" ]]; then
        log_warn "Installation précédente détectée, suppression..."
        rm -rf "$INSTALLER_DIR"
    fi
    
    # Cloner le dépôt
    log_info "Clonage du dépôt..."
    if git clone --depth 1 "$GITHUB_REPO" "$INSTALLER_DIR"; then
        log_info "✓ Code source téléchargé"
    else
        log_error "Échec du téléchargement"
        return 1
    fi
    
    # Vérifier la structure
    if [[ -d "$INSTALLER_DIR/raspberry-pi-installer" ]]; then
        log_info "✓ Structure du projet valide"
    else
        log_error "Structure du projet invalide"
        return 1
    fi
}

# =============================================================================
# APPLICATION DES CORRECTIONS ESSENTIELLES
# =============================================================================

apply_essential_fixes() {
    log_info "=== Application des corrections essentielles ==="
    
    local fixes_script="$INSTALLER_DIR/raspberry-pi-installer/scripts/patches/essential-fixes.sh"
    
    # Vérifier si le script existe, sinon le créer
    if [[ ! -f "$fixes_script" ]]; then
        log_warn "Script de corrections non trouvé, création..."
        mkdir -p "$(dirname "$fixes_script")"
        
        # Créer le script de corrections inline
        cat > "$fixes_script" << 'FIXES_EOF'
#!/usr/bin/env bash
set -euo pipefail

# Créer les répertoires de logs avec les bonnes permissions
mkdir -p /var/log/pi-signage
chown -R pi:pi /var/log/pi-signage
chmod 755 /var/log/pi-signage

# Créer les fichiers de log
for log in chromium startup sync health php-error playlist-update; do
    touch "/var/log/pi-signage/${log}.log"
    chown pi:pi "/var/log/pi-signage/${log}.log"
    chmod 644 "/var/log/pi-signage/${log}.log"
done

echo "✓ Permissions des logs corrigées"
FIXES_EOF
    fi
    
    # Exécuter les corrections
    chmod +x "$fixes_script"
    if sudo bash "$fixes_script"; then
        log_info "✓ Corrections essentielles appliquées"
    else
        log_warn "Certaines corrections ont échoué"
    fi
}

# =============================================================================
# LANCEMENT DE L'INSTALLATION
# =============================================================================

run_installation() {
    log_info "=== Lancement de l'installation Pi Signage v$VERSION ==="
    
    cd "$INSTALLER_DIR/raspberry-pi-installer"
    
    # Rendre le script principal exécutable
    chmod +x install.sh
    
    # Configurer les variables pour l'installation
    export NEW_HOSTNAME="pi-signage"
    export INSTALL_MODE="auto"
    export SKIP_PROMPTS="yes"
    
    log_info "Démarrage de l'installation..."
    log_info "Cela peut prendre 15-30 minutes selon votre connexion"
    echo
    
    # Lancer l'installation
    sudo ./install.sh
}

# =============================================================================
# VÉRIFICATIONS POST-INSTALLATION
# =============================================================================

post_install_checks() {
    log_info "=== Vérifications post-installation ==="
    
    # Attendre un peu pour que les services démarrent
    sleep 10
    
    # Vérifier les services
    local services=(
        "nginx"
        "php8.2-fpm"
        "glances"
        "chromium-kiosk"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet $service; then
            echo -e "${GREEN}✓${NC} $service actif"
        else
            echo -e "${YELLOW}⚠${NC} $service inactif"
        fi
    done
    
    # Afficher les URLs d'accès
    local ip=$(hostname -I | awk '{print $1}')
    echo
    log_info "=== URLs d'accès ==="
    echo "Interface web: http://$ip/"
    echo "Glances: http://$ip:61208/"
    echo
    
    # Vérifier GPU
    if command -v vcgencmd >/dev/null 2>&1; then
        local gpu_mem=$(vcgencmd get_mem gpu | grep -oP '\d+')
        if [[ $gpu_mem -ge 128 ]]; then
            echo -e "${GREEN}✓${NC} GPU Memory: ${gpu_mem}MB"
        else
            echo -e "${YELLOW}⚠${NC} GPU Memory: ${gpu_mem}MB (128MB recommandé)"
        fi
    fi
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Pi Signage v$VERSION - Déploiement Propre         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Vérifications
    if ! check_prerequisites; then
        log_error "Vérifications préliminaires échouées"
        exit 1
    fi
    
    echo
    log_warn "Cette installation va:"
    echo "  - Télécharger Pi Signage depuis GitHub"
    echo "  - Appliquer les corrections essentielles"
    echo "  - Installer automatiquement tous les composants"
    echo "  - Configurer le système pour le digital signage"
    echo
    read -p "Continuer ? [O/n] " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Oo]$ ]] && [[ -n $REPLY ]]; then
        log_info "Installation annulée"
        exit 0
    fi
    
    # Téléchargement
    if ! download_from_github; then
        log_error "Échec du téléchargement"
        exit 1
    fi
    
    # Corrections
    apply_essential_fixes
    
    # Installation
    run_installation
    
    # Vérifications finales
    echo
    post_install_checks
    
    echo
    log_info "=== Installation terminée ==="
    echo
    echo "Prochaines étapes:"
    echo "1. Accédez à l'interface web pour configurer Pi Signage"
    echo "2. Uploadez vos vidéos via l'interface"
    echo "3. Si nécessaire, redémarrez avec: sudo reboot"
    echo
    echo "En cas de problème, consultez les logs:"
    echo "  - Installation: /var/log/pi-signage-setup.log"
    echo "  - Chromium: /var/log/pi-signage/chromium.log"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi