#!/bin/bash

# Module d'installation des composants de base
# Version: 1.0

MODULE_NAME="Base System"
LOG_FILE="/opt/pisignage/logs/install-base.log"

echo "=== Installation du module: $MODULE_NAME ===" | tee -a "$LOG_FILE"

# Installation des paquets de base
install_base_packages() {
    echo "Installation des paquets de base..." | tee -a "$LOG_FILE"
    
    apt-get update
    apt-get install -y \
        curl \
        wget \
        git \
        unzip \
        htop \
        vim \
        systemd \
        rsync \
        cron
    
    echo "Paquets de base installés avec succès" | tee -a "$LOG_FILE"
}

# Configuration du système de base
configure_base_system() {
    echo "Configuration du système de base..." | tee -a "$LOG_FILE"
    
    # Configuration du timezone
    timedatectl set-timezone Europe/Paris
    
    # Configuration des logs
    mkdir -p /opt/pisignage/logs
    chmod 755 /opt/pisignage/logs
    
    echo "Configuration de base terminée" | tee -a "$LOG_FILE"
}

# Fonction principale
main() {
    install_base_packages
    configure_base_system
    echo "Module $MODULE_NAME installé avec succès" | tee -a "$LOG_FILE"
}

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi