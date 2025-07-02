#!/bin/bash

# =============================================================================
# Configuration Google Drive (optionnel)
# Version: 1.0.0
# Description: Synchronisation automatique avec Google Drive
# =============================================================================

set -euo pipefail

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VIDEOS_DIR="$HOME/Videos"
RCLONE_CONFIG="$HOME/.config/rclone/rclone.conf"

echo -e "${BLUE}=== Configuration Google Drive ===${NC}"
echo ""

# Installer rclone
if ! command -v rclone &> /dev/null; then
    echo -e "${YELLOW}Installation de rclone...${NC}"
    curl https://rclone.org/install.sh | sudo bash
fi

# Configurer rclone
echo -e "${YELLOW}Configuration de Google Drive...${NC}"
echo "Suivez les instructions pour vous connecter à votre compte Google."
echo ""

rclone config create gdrive drive scope drive.readonly

# Créer le script de synchronisation
cat > "$HOME/sync-gdrive.sh" << EOF
#!/bin/bash
# Synchronisation avec Google Drive

echo "Synchronisation avec Google Drive..."
rclone sync gdrive:/videos "$VIDEOS_DIR" --progress

# Redémarrer VLC si de nouvelles vidéos
if [[ \$(find "$VIDEOS_DIR" -mmin -5 -type f | wc -l) -gt 0 ]]; then
    echo "Nouvelles vidéos détectées, redémarrage de VLC..."
    ~/pi-signage-control.sh restart
fi

echo "Synchronisation terminée"
EOF

chmod +x "$HOME/sync-gdrive.sh"

# Ajouter la synchronisation au cron (toutes les heures)
(crontab -l 2>/dev/null; echo "0 * * * * $HOME/sync-gdrive.sh >> $HOME/sync-gdrive.log 2>&1") | crontab -

echo ""
echo -e "${GREEN}✓ Configuration terminée !${NC}"
echo ""
echo "Commandes disponibles :"
echo "• Synchronisation manuelle : ~/sync-gdrive.sh"
echo "• Synchronisation automatique : toutes les heures"
echo ""
echo "Placez vos vidéos dans le dossier 'videos' de votre Google Drive."