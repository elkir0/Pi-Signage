#!/bin/bash
# Script d'installation automatisé pour piSignage

cd /home/pi/Pi-Signage/raspberry-pi-installer/scripts

# Exporter les variables pour éviter les prompts
export DISPLAY_MODE="chromium"
export WEB_USER="admin"
export WEB_PASSWORD="admin123"
export SELECTED_MODULES="1,2,3,4,5"
export AUTO_INSTALL="yes"

# Lancer l'installation
sudo bash ./main_orchestrator.sh << RESPONSES
2
2
y
admin
admin123
admin123
1,2,3,4,5
y
RESPONSES
