#!/bin/bash

# À exécuter sur la carte SD montée sur un autre PC
# Remplacez /media/pi-root par le point de montage réel

MOUNT_POINT="/media/pi-root"  # Adapter selon votre système

echo "=== Désactivation de tous les services Pi Signage ==="

# Désactiver les services
sudo rm -f $MOUNT_POINT/etc/systemd/system/multi-user.target.wants/pi-signage-startup.service
sudo rm -f $MOUNT_POINT/etc/systemd/system/default.target.wants/pi-signage-startup.service
sudo rm -f $MOUNT_POINT/etc/systemd/system/graphical.target.wants/chromium-kiosk.service
sudo rm -f $MOUNT_POINT/etc/systemd/system/graphical.target.wants/vlc-signage.service

# Forcer le mode console
sudo ln -sf /lib/systemd/system/multi-user.target $MOUNT_POINT/etc/systemd/system/default.target

echo "Services désactivés. Le Pi devrait démarrer en mode console."