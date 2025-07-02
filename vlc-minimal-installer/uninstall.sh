#!/bin/bash

# =============================================================================
# Désinstallation Pi Signage VLC Minimal
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Désinstallation Pi Signage VLC Minimal ===${NC}"
echo ""
echo "Cette action va :"
echo "- Supprimer la configuration de démarrage automatique"
echo "- Conserver VLC installé"
echo "- Conserver vos vidéos"
echo ""

read -p "Continuer ? (o/N) : " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "Annulé."
    exit 0
fi

# Arrêter VLC
if pgrep vlc > /dev/null; then
    echo "Arrêt de VLC..."
    pkill vlc
fi

# Supprimer l'autostart
if [[ -f "$HOME/.config/autostart/vlc-kiosk.desktop" ]]; then
    rm "$HOME/.config/autostart/vlc-kiosk.desktop"
    echo -e "${GREEN}✓${NC} Démarrage automatique supprimé"
fi

if [[ -f "$HOME/.config/autostart/disable-screensaver.desktop" ]]; then
    rm "$HOME/.config/autostart/disable-screensaver.desktop"
fi

# Supprimer la config LXDE si présente
if [[ -f "$HOME/.config/lxsession/LXDE-pi/autostart" ]]; then
    sed -i '/vlc/d' "$HOME/.config/lxsession/LXDE-pi/autostart"
fi

# Supprimer les scripts utilitaires
for script in pi-signage-control.sh pi-signage-usb-import.sh sync-gdrive.sh vlc-web-info.txt; do
    if [[ -f "$HOME/$script" ]]; then
        rm "$HOME/$script"
        echo -e "${GREEN}✓${NC} Script $script supprimé"
    fi
done

# Supprimer la configuration VLC (optionnel)
read -p "Supprimer la configuration VLC ? (o/N) : " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Oo]$ ]]; then
    rm -rf "$HOME/.config/vlc"
    echo -e "${GREEN}✓${NC} Configuration VLC supprimée"
fi

# Supprimer les tâches cron
crontab -l 2>/dev/null | grep -v sync-gdrive | crontab - 2>/dev/null || true

echo ""
echo -e "${GREEN}✓ Désinstallation terminée${NC}"
echo ""
echo "Pour désinstaller VLC complètement : sudo apt remove vlc"
echo "Vos vidéos sont conservées dans : $HOME/Videos"