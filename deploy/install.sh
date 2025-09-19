#!/bin/bash

# PiSignage Installation Script
# Version: 1.0

set -e

INSTALL_DIR="/opt/pisignage"
LOG_FILE="/opt/pisignage/logs/install.log"

echo "=== Installation de PiSignage ==="
echo "Date: $(date)" | tee -a "$LOG_FILE"

# Vérification des privilèges root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root" 
   exit 1
fi

# Création des répertoires de logs si nécessaire
mkdir -p /opt/pisignage/logs

# Mise à jour du système
echo "Mise à jour du système..." | tee -a "$LOG_FILE"
apt-get update && apt-get upgrade -y

# Installation des dépendances
echo "Installation des dépendances..." | tee -a "$LOG_FILE"
apt-get install -y \
    nginx \
    php-fpm \
    omxplayer \
    feh \
    chromium-browser \
    xorg \
    x11-xserver-utils \
    unclutter

# Configuration des services
echo "Configuration des services..." | tee -a "$LOG_FILE"
cp systemd/pisignage.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable pisignage.service

# Configuration de nginx
echo "Configuration de nginx..." | tee -a "$LOG_FILE"
# Configuration nginx sera ajoutée ici

# Démarrage des services
echo "Démarrage des services..." | tee -a "$LOG_FILE"
systemctl start nginx
systemctl start php7.4-fpm

echo "Installation terminée avec succès!" | tee -a "$LOG_FILE"
echo "Interface web disponible sur http://localhost"