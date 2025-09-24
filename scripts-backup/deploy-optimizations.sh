#!/bin/bash

# ===========================================
# DÉPLOIEMENT OPTIMISATIONS 60 FPS - Pi 4
# ===========================================
# Script de déploiement automatique des optimisations GPU
# Version: 1.0.0
# Date: 2025-09-22

set -e

# Configuration
PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"
LOCAL_DIR="/opt/pisignage"
REMOTE_DIR="/opt/pisignage"

# Couleurs pour affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction de logging coloré
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Vérifier connexion SSH
check_ssh_connection() {
    log "Vérification connexion SSH vers $PI_IP..."

    if sshpass -p "$PI_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$PI_USER@$PI_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
        success "Connexion SSH établie"
        return 0
    else
        error "Impossible de se connecter au Raspberry Pi"
        return 1
    fi
}

# Backup configuration actuelle
backup_current_config() {
    log "Sauvegarde configuration actuelle..."

    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "
        sudo mkdir -p /home/pi/backup/$(date +%Y%m%d_%H%M%S)
        sudo cp /boot/config.txt /home/pi/backup/$(date +%Y%m%d_%H%M%S)/
        sudo cp -r /opt/pisignage /home/pi/backup/$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
    "

    success "Configuration sauvegardée"
}

# Déployer nouvelle configuration /boot/config.txt
deploy_boot_config() {
    log "Déploiement configuration /boot/config.txt optimisée..."

    # Copier fichier de config
    scp -o StrictHostKeyChecking=no "$LOCAL_DIR/config-optimized/boot-config-60fps.txt" "$PI_USER@$PI_IP:/tmp/config.txt" >/dev/null

    # Appliquer avec sudo
    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "
        sudo cp /tmp/config.txt /boot/config.txt
        sudo chown root:root /boot/config.txt
        sudo chmod 755 /boot/config.txt
    "

    success "Configuration /boot/config.txt déployée"
}

# Déployer scripts optimisés
deploy_scripts() {
    log "Déploiement scripts optimisés..."

    # Créer structure de dossiers
    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "
        sudo mkdir -p $REMOTE_DIR/scripts
        sudo mkdir -p /var/log/pisignage
        sudo mkdir -p /var/run/pisignage
        sudo chown -R pi:pi $REMOTE_DIR
        sudo chown -R pi:pi /var/log/pisignage
        sudo chown -R pi:pi /var/run/pisignage
    "

    # Copier scripts
    scp -o StrictHostKeyChecking=no "$LOCAL_DIR/scripts/start-chromium-optimized.sh" "$PI_USER@$PI_IP:$REMOTE_DIR/scripts/"
    scp -o StrictHostKeyChecking=no "$LOCAL_DIR/scripts/monitor-fps.sh" "$PI_USER@$PI_IP:$REMOTE_DIR/scripts/"

    # Rendre exécutables
    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "
        chmod +x $REMOTE_DIR/scripts/*.sh
        sudo chown pi:pi $REMOTE_DIR/scripts/*.sh
    "

    success "Scripts déployés et configurés"
}

# Déployer API de monitoring
deploy_api() {
    log "Déploiement API de monitoring..."

    # Créer dossier API si nécessaire
    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "
        sudo mkdir -p $REMOTE_DIR/web/api
        sudo chown -R www-data:www-data $REMOTE_DIR/web
    "

    # Copier API
    scp -o StrictHostKeyChecking=no "$LOCAL_DIR/web/api/performance.php" "$PI_USER@$PI_IP:$REMOTE_DIR/web/api/"

    # Permissions correctes
    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "
        sudo chown www-data:www-data $REMOTE_DIR/web/api/performance.php
        sudo chmod 644 $REMOTE_DIR/web/api/performance.php
    "

    success "API de monitoring déployée"
}

# Installer dépendances
install_dependencies() {
    log "Installation des dépendances..."

    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "
        sudo apt update -qq
        sudo apt install -y bc htop iotop mesa-utils 2>/dev/null || true
    "

    success "Dépendances installées"
}

# Optimiser configuration système
optimize_system_config() {
    log "Optimisation configuration système..."

    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "
        # Optimisations GPU
        echo 'CONF_SWAPSIZE=0' | sudo tee -a /etc/dphys-swapfile >/dev/null || true

        # Optimisations réseau
        echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf >/dev/null || true
        echo 'net.core.wmem_max = 16777216' | sudo tee -a /etc/sysctl.conf >/dev/null || true

        # Optimisations scheduler
        echo 'kernel.sched_rt_runtime_us = 950000' | sudo tee -a /etc/sysctl.conf >/dev/null || true
    "

    success "Configuration système optimisée"
}

# Créer service systemd pour auto-start
create_systemd_service() {
    log "Création service systemd pour Chromium optimisé..."

    # Créer fichier de service
    cat > /tmp/pisignage-chromium.service <<EOF
[Unit]
Description=PiSignage Chromium Optimized 60 FPS
After=network.target graphical.target
Wants=graphical.target

[Service]
Type=simple
User=pi
Group=pi
Environment=DISPLAY=:0
ExecStart=$REMOTE_DIR/scripts/start-chromium-optimized.sh
ExecStop=/usr/bin/pkill -f chromium-browser
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF

    # Déployer service
    scp -o StrictHostKeyChecking=no /tmp/pisignage-chromium.service "$PI_USER@$PI_IP:/tmp/"

    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "
        sudo mv /tmp/pisignage-chromium.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable pisignage-chromium.service
    "

    rm /tmp/pisignage-chromium.service

    success "Service systemd créé et activé"
}

# Tester configuration
test_configuration() {
    log "Test de la configuration déployée..."

    # Test accès SSH
    if ! sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
        error "Test SSH échoué"
        return 1
    fi

    # Test fichiers déployés
    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "
        if [ ! -f /boot/config.txt ]; then
            echo 'ERREUR: /boot/config.txt manquant'
            exit 1
        fi

        if [ ! -f $REMOTE_DIR/scripts/start-chromium-optimized.sh ]; then
            echo 'ERREUR: Script Chromium manquant'
            exit 1
        fi

        if [ ! -f $REMOTE_DIR/scripts/monitor-fps.sh ]; then
            echo 'ERREUR: Script monitoring manquant'
            exit 1
        fi

        if [ ! -f $REMOTE_DIR/web/api/performance.php ]; then
            echo 'ERREUR: API performance manquante'
            exit 1
        fi

        echo 'Tous les fichiers sont présents'
    "

    success "Configuration testée avec succès"
}

# Redémarrer Raspberry Pi
restart_raspberry_pi() {
    log "Redémarrage du Raspberry Pi pour appliquer optimisations..."

    sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "sudo shutdown -r +1 'Redémarrage pour optimisations GPU'" || true

    success "Redémarrage programmé dans 1 minute"
    warning "Attendre 2-3 minutes avant de tester"
}

# Fonction principale
main() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "  DÉPLOIEMENT OPTIMISATIONS 60 FPS - Pi 4"
    echo "=============================================="
    echo -e "${NC}"

    log "Démarrage déploiement sur $PI_IP"

    # Étapes de déploiement
    check_ssh_connection || exit 1
    backup_current_config
    deploy_boot_config
    deploy_scripts
    deploy_api
    install_dependencies
    optimize_system_config
    create_systemd_service
    test_configuration

    echo ""
    success "=== DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ==="

    echo ""
    log "Prochaines étapes:"
    echo "1. Redémarrer le Pi: ./deploy-optimizations.sh restart"
    echo "2. Attendre 2-3 minutes"
    echo "3. Tester: curl http://$PI_IP/api/performance.php?endpoint=current"
    echo "4. Monitoring FPS: ssh pi@$PI_IP '$REMOTE_DIR/scripts/monitor-fps.sh'"
    echo ""
}

# Commandes spéciales
case "${1:-}" in
    restart)
        restart_raspberry_pi
        exit 0
        ;;
    test)
        check_ssh_connection && test_configuration
        exit 0
        ;;
    *)
        main
        ;;
esac