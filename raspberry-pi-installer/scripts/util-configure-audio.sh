#!/usr/bin/env bash

# =============================================================================
# Configuration audio pour Pi Signage
# =============================================================================

set -euo pipefail

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Vérification root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Ce script doit être exécuté en tant que root"
    exit 1
fi

echo -e "${GREEN}=== Configuration Audio Pi Signage ===${NC}"

# Fonction de sélection de sortie audio
configure_audio_output() {
    echo -e "\n${YELLOW}Sélection de la sortie audio:${NC}"
    echo "1) HDMI (par défaut)"
    echo "2) Jack 3.5mm (sortie analogique)"
    echo "3) Automatique"
    
    read -p "Votre choix [1-3]: " choice
    
    case $choice in
        1)
            echo -e "${GREEN}Configuration HDMI...${NC}"
            # Forcer la sortie HDMI
            amixer cset numid=3 2 2>/dev/null || true
            # NE PAS modifier /boot/config.txt - conformément aux exigences
            echo -e "${YELLOW}Note: Pas de modification de /boot/config.txt${NC}"
            ;;
        2)
            echo -e "${GREEN}Configuration Jack 3.5mm...${NC}"
            # Forcer la sortie analogique
            amixer cset numid=3 1 2>/dev/null || true
            ;;
        3)
            echo -e "${GREEN}Configuration automatique...${NC}"
            # Laisser le système choisir
            amixer cset numid=3 0 2>/dev/null || true
            ;;
        *)
            echo -e "${YELLOW}Choix invalide, configuration HDMI par défaut${NC}"
            amixer cset numid=3 2 2>/dev/null || true
            ;;
    esac
}

# Configuration du volume
configure_volume() {
    echo -e "\n${YELLOW}Configuration du volume:${NC}"
    
    # Mettre le volume à 85% par défaut
    amixer set PCM 85% 2>/dev/null || amixer set Master 85% 2>/dev/null || true
    
    echo -e "${GREEN}Volume configuré à 85%${NC}"
}

# Installation des paquets audio nécessaires
install_audio_packages() {
    echo -e "\n${YELLOW}Installation des paquets audio...${NC}"
    
    apt-get update
    apt-get install -y \
        alsa-utils \
        pulseaudio \
        pulseaudio-utils \
        pavucontrol
    
    echo -e "${GREEN}Paquets audio installés${NC}"
}

# Configuration pour l'utilisateur pi
configure_user_audio() {
    echo -e "\n${YELLOW}Configuration audio pour l'utilisateur pi...${NC}"
    
    # Ajouter pi au groupe audio
    usermod -a -G audio pi
    
    # Créer le fichier asoundrc pour l'utilisateur pi
    cat > /home/pi/.asoundrc << 'EOF'
pcm.!default {
    type hw
    card 0
}

ctl.!default {
    type hw
    card 0
}
EOF
    
    chown pi:pi /home/pi/.asoundrc
    
    echo -e "${GREEN}Utilisateur pi configuré pour l'audio${NC}"
}

# Test audio
test_audio() {
    echo -e "\n${YELLOW}Test audio...${NC}"
    echo -e "${YELLOW}Vous devriez entendre un son de test${NC}"
    
    # Test avec speaker-test
    speaker-test -t sine -f 1000 -l 1 2>/dev/null || true
    
    echo -e "${GREEN}Test terminé${NC}"
}

# Configuration Chromium pour le son
configure_chromium_audio() {
    echo -e "\n${YELLOW}Configuration de Chromium pour l'audio...${NC}"
    
    # Ajouter les flags nécessaires pour Chromium
    if [[ -f "/opt/scripts/chromium-kiosk.sh" ]]; then
        # Vérifier si les flags audio sont déjà présents
        if ! grep -q "autoplay-policy" /opt/scripts/chromium-kiosk.sh; then
            sed -i 's/chromium-browser \\/chromium-browser \\\n    --autoplay-policy=no-user-gesture-required \\/g' /opt/scripts/chromium-kiosk.sh
        fi
        echo -e "${GREEN}Chromium configuré pour l'autoplay avec son${NC}"
    else
        echo -e "${YELLOW}Script chromium-kiosk.sh non trouvé${NC}"
    fi
}

# Menu principal
echo -e "\n${GREEN}Configuration audio pour Pi Signage${NC}"
echo "Ce script va configurer l'audio pour votre installation Pi Signage"
echo ""

# Installation des paquets
install_audio_packages

# Configuration de la sortie
configure_audio_output

# Configuration du volume
configure_volume

# Configuration utilisateur
configure_user_audio

# Configuration Chromium
configure_chromium_audio

# Test
read -p "Voulez-vous tester l'audio maintenant? (o/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Oo]$ ]]; then
    test_audio
fi

echo -e "\n${GREEN}=== Configuration terminée ===${NC}"
echo -e "${YELLOW}Notes importantes:${NC}"
echo "- Un redémarrage peut être nécessaire pour appliquer tous les changements"
echo "- Le volume est configuré à 85%"
echo "- Pour ajuster le volume: alsamixer ou amixer set Master 90%"
echo "- Pour tester: speaker-test -t sine -f 1000 -l 1"

read -p "Voulez-vous redémarrer maintenant? (o/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Oo]$ ]]; then
    echo -e "${YELLOW}Redémarrage dans 5 secondes...${NC}"
    sleep 5
    reboot
fi