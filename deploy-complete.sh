#!/bin/bash

# PiSignage v0.8.0 - Déploiement Complet
# Script tout-en-un pour installation production
# Auteur: Claude Code
# Date: 22/09/2025

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[DEPLOY] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[DEPLOY] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[DEPLOY] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[DEPLOY] INFO: $1${NC}"
}

# Vérification de l'environnement
check_environment() {
    log "Vérification de l'environnement..."

    # Vérifier qu'on est sur Raspberry Pi
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null && ! grep -q "BCM" /proc/cpuinfo 2>/dev/null; then
        error "Ce script est conçu pour Raspberry Pi uniquement"
    fi

    # Vérifier les privilèges
    if [[ $EUID -eq 0 ]]; then
        error "Ne pas exécuter en tant que root. Utilisez 'sudo' quand nécessaire."
    fi

    # Vérifier la connexion internet
    if ! ping -c 1 google.com &> /dev/null; then
        warn "Connexion internet non détectée - certaines fonctionnalités peuvent échouer"
    fi

    log "✅ Environnement validé"
}

# Validation des scripts
validate_scripts() {
    log "Validation des scripts d'installation..."

    if [ -x "/opt/pisignage/validate-installation.sh" ]; then
        if /opt/pisignage/validate-installation.sh; then
            log "✅ Validation réussie"
        else
            error "❌ Validation échouée - Vérifiez les erreurs ci-dessus"
        fi
    else
        error "Script de validation non trouvé"
    fi
}

# Installation complète
run_installation() {
    log "Démarrage de l'installation complète..."

    # 1. Installation principale
    if [ -x "/opt/pisignage/install.sh" ]; then
        log "Exécution de install.sh..."
        /opt/pisignage/install.sh
    else
        error "install.sh non trouvé ou non exécutable"
    fi

    log "✅ Installation principale terminée"
}

# Configuration du service
setup_service() {
    log "Configuration du service systemd..."

    if [ -f "/opt/pisignage/pisignage.service" ]; then
        # Copie et activation du service
        sudo cp "/opt/pisignage/pisignage.service" "/etc/systemd/system/"
        sudo systemctl daemon-reload
        sudo systemctl enable pisignage.service

        log "✅ Service installé et activé"
    else
        error "Fichier service non trouvé"
    fi
}

# Test de déploiement
test_deployment() {
    log "Test du déploiement..."

    # Test des services essentiels
    local services=("nginx" "php8.2-fpm")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "✅ $service actif"
        else
            error "❌ $service inactif"
        fi
    done

    # Test de l'interface web
    local ip=$(hostname -I | awk '{print $1}')
    if curl -s "http://localhost/health" | grep -q "PiSignage"; then
        log "✅ Interface web accessible"
        info "URL: http://$ip"
    else
        warn "Interface web non accessible - peut nécessiter redémarrage"
    fi

    # Test des scripts
    if [ -x "/opt/pisignage/scripts/vlc-control.sh" ]; then
        log "✅ Scripts VLC installés"
    else
        warn "Scripts VLC non trouvés"
    fi

    log "✅ Tests de déploiement terminés"
}

# Configuration post-installation
post_install_config() {
    log "Configuration post-installation..."

    # Création d'un média de test
    local test_media="/opt/pisignage/media/test.mp4"
    if [ ! -f "$test_media" ] && command -v ffmpeg >/dev/null 2>&1; then
        log "Création d'un média de test..."
        ffmpeg -f lavfi -i "testsrc2=duration=30:size=1920x1080:rate=30" \
               -f lavfi -i "sine=frequency=440:duration=30" \
               -c:v libx264 -preset ultrafast -c:a aac \
               -y "$test_media" 2>/dev/null || warn "Échec création média de test"
    fi

    # Configuration de base pour auto-démarrage
    local autostart_dir="/home/pi/.config/lxsession/LXDE-pi"
    if [ ! -d "$autostart_dir" ]; then
        sudo -u pi mkdir -p "$autostart_dir"
        log "✅ Répertoire autostart créé"
    fi

    # Message de bienvenue
    cat << 'EOF' | sudo tee /opt/pisignage/media/welcome.txt > /dev/null
🎉 PiSignage v0.8.0 installé avec succès !

📺 Système d'affichage digital pour Raspberry Pi
🔧 Installation complète terminée
🌐 Interface web disponible
📱 Prêt pour la production

Développé avec Claude Code
22/09/2025
EOF

    log "✅ Configuration post-installation terminée"
}

# Instructions finales
show_final_instructions() {
    local ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo "=============================================="
    echo "🎉 INSTALLATION PISIGNAGE v0.8.0 TERMINÉE"
    echo "=============================================="
    echo ""
    echo "📍 Installation réussie sur:"
    echo "   Raspberry Pi: $(grep "Model" /proc/cpuinfo | cut -d: -f2 | xargs)"
    echo "   IP: $ip"
    echo "   OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
    echo ""
    echo "🌐 Interface Web:"
    echo "   URL principale: http://$ip"
    echo "   Health check: http://$ip/health"
    echo "   API status: http://$ip/api/system.php"
    echo ""
    echo "🔧 Services installés:"
    echo "   ✅ Nginx (serveur web)"
    echo "   ✅ PHP 8.2-FPM (backend)"
    echo "   ✅ VLC (lecteur média)"
    echo "   ✅ PiSignage (service principal)"
    echo ""
    echo "📂 Répertoires importants:"
    echo "   Code: /opt/pisignage"
    echo "   Web: /opt/pisignage/web"
    echo "   Médias: /opt/pisignage/media"
    echo "   Logs: /opt/pisignage/logs"
    echo "   Scripts: /opt/pisignage/scripts"
    echo ""
    echo "⚡ Prochaines étapes:"
    echo "   1. sudo reboot  (OBLIGATOIRE pour GPU/overclocking)"
    echo "   2. Tester l'interface: http://$ip"
    echo "   3. Déployer vos médias dans /opt/pisignage/media"
    echo "   4. Configurer les playlists via l'interface"
    echo ""
    echo "🛠️ Commandes utiles:"
    echo "   sudo systemctl status pisignage"
    echo "   sudo systemctl restart pisignage"
    echo "   /opt/pisignage/scripts/vlc-control.sh status"
    echo "   /opt/pisignage/scripts/restart-web.sh"
    echo ""
    echo "📚 Support:"
    echo "   Documentation: /opt/pisignage/README.md"
    echo "   Logs: tail -f /opt/pisignage/logs/pisignage.log"
    echo "   GitHub: https://github.com/elkir0/Pi-Signage"
    echo ""
    echo "⚠️  IMPORTANT: Redémarrez maintenant avec 'sudo reboot'"
    echo "=============================================="
}

# Fonction principale
main() {
    echo ""
    log "🚀 Déploiement complet PiSignage v0.8.0"
    echo ""

    check_environment
    validate_scripts
    run_installation
    setup_service
    test_deployment
    post_install_config
    show_final_instructions

    echo ""
    log "✅ Déploiement complet terminé avec succès!"
    echo ""
    warn "⚠️  N'oubliez pas de redémarrer: sudo reboot"
}

# Gestion d'interruption
trap 'echo -e "\n${RED}Installation interrompue${NC}"; exit 1' INT TERM

# Exécution
main "$@"