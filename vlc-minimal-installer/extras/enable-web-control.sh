#!/bin/bash

# =============================================================================
# Activation du contrôle web VLC (optionnel)
# Version: 1.0.0
# Description: Permet de contrôler VLC via une interface web
# =============================================================================

set -euo pipefail

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Activation du contrôle web VLC ===${NC}"
echo ""

# Générer un mot de passe
echo -e "${YELLOW}Définissez un mot de passe pour l'interface web :${NC}"
read -s -p "Mot de passe : " password
echo ""

# Mettre à jour la configuration VLC
cat >> "$HOME/.config/vlc/vlcrc" << EOF

# Interface web
[intf] intf=http
[http] http-password=$password
[http] http-host=0.0.0.0
[http] http-port=8080
EOF

# Mettre à jour le fichier autostart
sed -i 's/--intf dummy/--intf http --extraintf dummy/' "$HOME/.config/autostart/vlc-kiosk.desktop"

# Créer un script d'information
cat > "$HOME/vlc-web-info.txt" << EOF
Interface web VLC activée !

Accès : http://$(hostname -I | awk '{print $1}'):8080
Mot de passe : $password

Contrôles disponibles :
- Play/Pause
- Volume
- Playlist
- Recherche
EOF

echo ""
echo -e "${GREEN}✓ Interface web activée !${NC}"
echo ""
cat "$HOME/vlc-web-info.txt"
echo ""
echo -e "${YELLOW}Redémarrez VLC pour appliquer les changements :${NC}"
echo "~/pi-signage-control.sh restart"