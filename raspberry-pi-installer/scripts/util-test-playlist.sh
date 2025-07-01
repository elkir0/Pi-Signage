#!/usr/bin/env bash

# =============================================================================
# Test de mise à jour de la playlist
# =============================================================================

set -euo pipefail

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

echo -e "${GREEN}=== Test de mise à jour de la playlist ===${NC}"

# Vérifier que le script existe
if [[ -f "/opt/scripts/update-playlist.sh" ]]; then
    echo -e "${GREEN}[OK]${NC} Script update-playlist.sh trouvé"
    
    # Exécuter le script
    echo -e "\n${YELLOW}Exécution du script...${NC}"
    sudo /opt/scripts/update-playlist.sh
    
    # Vérifier le fichier playlist
    if [[ -f "/var/www/pi-signage-player/api/playlist.json" ]]; then
        echo -e "\n${GREEN}[OK]${NC} Fichier playlist.json trouvé"
        echo -e "\n${YELLOW}Contenu de la playlist:${NC}"
        cat /var/www/pi-signage-player/api/playlist.json | jq '.'
    else
        echo -e "${RED}[ERREUR]${NC} Fichier playlist.json non trouvé"
    fi
else
    echo -e "${RED}[ERREUR]${NC} Script update-playlist.sh non trouvé"
    
    # Chercher d'autres scripts
    echo -e "\n${YELLOW}Recherche d'autres scripts de playlist...${NC}"
    find /opt/scripts -name "*playlist*" -type f 2>/dev/null || echo "Aucun script trouvé"
fi

# Vérifier les vidéos
echo -e "\n${YELLOW}Vidéos dans /opt/videos:${NC}"
ls -la /opt/videos/ 2>/dev/null || echo "Dossier non trouvé"

echo -e "\n${GREEN}=== Test terminé ===${NC}"