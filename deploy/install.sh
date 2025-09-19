#!/bin/bash

# PiSignage Installation Script
# Version: 1.0

set -e

INSTALL_DIR="/opt/pisignage"
LOG_FILE="/opt/pisignage/logs/install.log"

echo "=== Installation de PiSignage ==="
echo "Date: $(date)" | tee -a "$LOG_FILE"

# V�rification des privil�ges root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit �tre ex�cut� en tant que root" 
   exit 1
fi

# Cr�ation des r�pertoires de logs si n�cessaire
mkdir -p /opt/pisignage/logs

# Mise � jour du syst�me
echo "Mise � jour du syst�me..." | tee -a "$LOG_FILE"
apt-get update && apt-get upgrade -y

# Installation des d�pendances
echo "Installation des d�pendances..." | tee -a "$LOG_FILE"
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
# Configuration nginx sera ajout�e ici

# D�marrage des services
echo "D�marrage des services..." | tee -a "$LOG_FILE"
systemctl start nginx
systemctl start php7.4-fpm

echo "Installation termin�e avec succ�s!" | tee -a "$LOG_FILE"
echo "Interface web disponible sur http://localhost"