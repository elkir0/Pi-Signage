#!/bin/bash

# PiSignage Uninstallation Script
# Version: 1.0

set -e

LOG_FILE="/opt/pisignage/logs/uninstall.log"

echo "=== D�sinstallation de PiSignage ==="
echo "Date: $(date)" | tee -a "$LOG_FILE"

# V�rification des privil�ges root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit �tre ex�cut� en tant que root" 
   exit 1
fi

# Arr�t des services
echo "Arr�t des services..." | tee -a "$LOG_FILE"
systemctl stop pisignage.service || true
systemctl disable pisignage.service || true

# Suppression des services systemd
echo "Suppression des services systemd..." | tee -a "$LOG_FILE"
rm -f /etc/systemd/system/pisignage.service
systemctl daemon-reload

# Nettoyage des configurations
echo "Nettoyage des configurations..." | tee -a "$LOG_FILE"
# Suppression des configurations nginx si n�cessaire

# Sauvegarde des donn�es utilisateur
echo "Sauvegarde des m�dias..." | tee -a "$LOG_FILE"
if [ -d "/opt/pisignage/media" ]; then
    mkdir -p /tmp/pisignage-backup
    cp -r /opt/pisignage/media /tmp/pisignage-backup/
    echo "M�dias sauvegard�s dans /tmp/pisignage-backup/"
fi

echo "D�sinstallation termin�e!" | tee -a "$LOG_FILE"
echo "Note: Les m�dias ont �t� sauvegard�s dans /tmp/pisignage-backup/"