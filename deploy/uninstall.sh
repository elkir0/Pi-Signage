#!/bin/bash

# PiSignage Uninstallation Script
# Version: 1.0

set -e

LOG_FILE="/opt/pisignage/logs/uninstall.log"

echo "=== Désinstallation de PiSignage ==="
echo "Date: $(date)" | tee -a "$LOG_FILE"

# Vérification des privilèges root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root" 
   exit 1
fi

# Arrêt des services
echo "Arrêt des services..." | tee -a "$LOG_FILE"
systemctl stop pisignage.service || true
systemctl disable pisignage.service || true

# Suppression des services systemd
echo "Suppression des services systemd..." | tee -a "$LOG_FILE"
rm -f /etc/systemd/system/pisignage.service
systemctl daemon-reload

# Nettoyage des configurations
echo "Nettoyage des configurations..." | tee -a "$LOG_FILE"
# Suppression des configurations nginx si nécessaire

# Sauvegarde des données utilisateur
echo "Sauvegarde des médias..." | tee -a "$LOG_FILE"
if [ -d "/opt/pisignage/media" ]; then
    mkdir -p /tmp/pisignage-backup
    cp -r /opt/pisignage/media /tmp/pisignage-backup/
    echo "Médias sauvegardés dans /tmp/pisignage-backup/"
fi

echo "Désinstallation terminée!" | tee -a "$LOG_FILE"
echo "Note: Les médias ont été sauvegardés dans /tmp/pisignage-backup/"