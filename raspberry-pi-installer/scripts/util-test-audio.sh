#!/usr/bin/env bash

# =============================================================================
# Test audio Pi Signage
# =============================================================================

set -euo pipefail

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

echo -e "${GREEN}=== Test Audio Pi Signage ===${NC}"

# Vérifier le statut du son
echo -e "\n${YELLOW}Statut audio actuel:${NC}"
amixer get Master 2>/dev/null || amixer get PCM 2>/dev/null || echo "Contrôle de volume non trouvé"

# Afficher la sortie audio active
echo -e "\n${YELLOW}Sortie audio active:${NC}"
amixer cget numid=3 2>/dev/null || echo "Impossible de déterminer la sortie"

# Test de son
echo -e "\n${YELLOW}Test de son (5 secondes)...${NC}"
echo "Vous devriez entendre un bip"

# Utiliser speaker-test
speaker-test -t sine -f 1000 -l 1 -p 5 2>/dev/null || {
    echo -e "${RED}speaker-test non disponible${NC}"
    # Alternative avec aplay
    if command -v aplay >/dev/null 2>&1; then
        echo -e "${YELLOW}Test avec aplay...${NC}"
        # Générer un son de test
        (
            for i in {1..5000}; do
                echo -ne "\x00\x00"
            done
        ) | aplay -r 8000 -f S16_LE 2>/dev/null || echo "Échec du test aplay"
    fi
}

# Informations système
echo -e "\n${YELLOW}Informations audio système:${NC}"
echo "Cartes audio disponibles:"
aplay -l 2>/dev/null || echo "aplay non disponible"

echo -e "\n${YELLOW}Configuration ALSA:${NC}"
if [[ -f /home/pi/.asoundrc ]]; then
    cat /home/pi/.asoundrc
else
    echo "Pas de configuration .asoundrc"
fi

# Si Chromium est en cours d'exécution
if pgrep chromium > /dev/null; then
    echo -e "\n${GREEN}Chromium est en cours d'exécution${NC}"
    echo "Les vidéos devraient avoir du son"
else
    echo -e "\n${YELLOW}Chromium n'est pas en cours d'exécution${NC}"
fi

echo -e "\n${GREEN}=== Test terminé ===${NC}"
echo -e "${YELLOW}Conseils:${NC}"
echo "- Pour ajuster le volume: alsamixer"
echo "- Pour changer la sortie (HDMI/Jack): sudo amixer cset numid=3 2 (HDMI) ou 1 (Jack)"
echo "- Si pas de son dans les vidéos, vérifier que le player n'est pas en mode muet"