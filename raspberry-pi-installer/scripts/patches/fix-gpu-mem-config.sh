#!/usr/bin/env bash

# =============================================================================
# Fix GPU Memory Configuration
# Version: 1.0.0
# Description: Corrige la configuration gpu_mem pour l'accélération vidéo
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Chemins config.txt (peut varier selon la version)
CONFIG_PATHS=(
    "/boot/firmware/config.txt"
    "/boot/config.txt"
)

# Trouver le bon fichier config.txt
CONFIG_FILE=""
for path in "${CONFIG_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        CONFIG_FILE="$path"
        break
    fi
done

if [[ -z "$CONFIG_FILE" ]]; then
    echo -e "${RED}[ERROR]${NC} Impossible de trouver config.txt"
    exit 1
fi

echo -e "${GREEN}=== Fix GPU Memory Configuration ===${NC}"
echo "Fichier de configuration: $CONFIG_FILE"
echo

# Vérifier l'état actuel
current_gpu_mem=$(grep "^gpu_mem=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo "non défini")
echo "Configuration actuelle: gpu_mem=$current_gpu_mem"

if [[ "$current_gpu_mem" == "128" ]]; then
    echo -e "${GREEN}✓${NC} gpu_mem déjà configuré correctement"
else
    echo -e "${YELLOW}Configuration de gpu_mem=128...${NC}"
    
    # Backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    
    # Retirer les anciennes entrées gpu_mem
    sed -i '/^gpu_mem=/d' "$CONFIG_FILE"
    sed -i '/^#gpu_mem=/d' "$CONFIG_FILE"
    
    # Ajouter la nouvelle configuration
    echo "" >> "$CONFIG_FILE"
    echo "# Accélération GPU pour décodage vidéo H.264" >> "$CONFIG_FILE"
    echo "gpu_mem=128" >> "$CONFIG_FILE"
    
    echo -e "${GREEN}✓${NC} gpu_mem=128 configuré"
fi

# Vérifier dtoverlay
if grep -q "^dtoverlay=vc4-kms-v3d" "$CONFIG_FILE"; then
    echo -e "${GREEN}✓${NC} dtoverlay=vc4-kms-v3d présent"
else
    echo -e "${YELLOW}Ajout de dtoverlay=vc4-kms-v3d...${NC}"
    echo "dtoverlay=vc4-kms-v3d" >> "$CONFIG_FILE"
fi

# Vérifier les codecs après redémarrage
echo
echo -e "${YELLOW}=== Vérification des codecs ===${NC}"
for codec in H264 MPG2 WVC1; do
    status=$(vcgencmd codec_enabled $codec 2>/dev/null | cut -d= -f2 || echo "error")
    if [[ "$status" == "enabled" ]]; then
        echo -e "  ${GREEN}✓${NC} $codec: enabled"
    else
        echo -e "  ${RED}✗${NC} $codec: $status"
    fi
done

echo
echo -e "${YELLOW}=== Actions requises ===${NC}"
echo "1. Redémarrer le Raspberry Pi:"
echo "   sudo reboot"
echo
echo "2. Après redémarrage, vérifier:"
echo "   vcgencmd codec_enabled H264"
echo "   (doit retourner: H264=enabled)"
echo
echo "3. Dans Chromium, vérifier chrome://gpu"
echo "   Video Decode doit être 'Hardware accelerated'"

# Vérifier si un redémarrage est nécessaire
if [[ "$current_gpu_mem" != "128" ]]; then
    echo
    echo -e "${RED}IMPORTANT:${NC} Un redémarrage est nécessaire pour activer les changements"
    read -p "Redémarrer maintenant ? (o/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        echo "Redémarrage dans 5 secondes..."
        sleep 5
        sudo reboot
    fi
fi