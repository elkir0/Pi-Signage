#!/usr/bin/env bash

# =============================================================================
# Vérification complète Pi Signage
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}=== VÉRIFICATION COMPLÈTE PI SIGNAGE ===${NC}"
echo "Date: $(date)"
echo

# =============================================================================
# 1. GLANCES
# =============================================================================

echo -e "${YELLOW}1. GLANCES${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:61208/ | grep -q "200"; then
    echo -e "  ${GREEN}✓${NC} Glances accessible sur :61208"
    echo "  → Accès: http://$(hostname -I | awk '{print $1}'):61208"
else
    echo -e "  ${RED}✗${NC} Glances non accessible"
fi

# =============================================================================
# 2. PERFORMANCE VIDÉO
# =============================================================================

echo -e "\n${YELLOW}2. PERFORMANCE VIDÉO${NC}"

# GPU Memory
gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null | grep -oP '\d+' || echo "0")
if [[ "$gpu_mem" == "128" ]]; then
    echo -e "  ${GREEN}✓${NC} GPU Memory: 128MB"
else
    echo -e "  ${RED}✗${NC} GPU Memory: ${gpu_mem}MB (devrait être 128)"
fi

# Codec H264
if vcgencmd codec_enabled H264 2>/dev/null | grep -q "enabled"; then
    echo -e "  ${GREEN}✓${NC} Codec H264: activé"
else
    echo -e "  ${RED}✗${NC} Codec H264: désactivé"
fi

# Devices V4L2
if ls /dev/video1* 2>/dev/null | grep -q video; then
    echo -e "  ${GREEN}✓${NC} Devices V4L2: présents"
else
    echo -e "  ${RED}✗${NC} Devices V4L2: manquants"
fi

# Chromium GPU flags
if grep -q "VaapiVideoDecoder" /opt/scripts/chromium-kiosk.sh 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Flags GPU Chromium: configurés"
else
    echo -e "  ${RED}✗${NC} Flags GPU Chromium: manquants"
fi

# =============================================================================
# 3. AUDIO
# =============================================================================

echo -e "\n${YELLOW}3. AUDIO${NC}"

# PulseAudio
if command -v pulseaudio >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} PulseAudio: installé"
    if systemctl is-active --quiet pulseaudio 2>/dev/null || pgrep pulseaudio >/dev/null; then
        echo -e "  ${GREEN}✓${NC} PulseAudio: actif"
    else
        echo -e "  ${YELLOW}⚠${NC} PulseAudio: inactif"
    fi
else
    echo -e "  ${RED}✗${NC} PulseAudio: non installé"
fi

# Groupes audio
if groups pi | grep -q audio; then
    echo -e "  ${GREEN}✓${NC} Utilisateur pi dans groupe audio"
else
    echo -e "  ${RED}✗${NC} Utilisateur pi pas dans groupe audio"
fi

# =============================================================================
# 4. SERVICES
# =============================================================================

echo -e "\n${YELLOW}4. SERVICES${NC}"
for service in chromium-kiosk glances nginx php8.2-fpm; do
    if systemctl is-active --quiet $service; then
        echo -e "  ${GREEN}✓${NC} $service: actif"
    else
        echo -e "  ${RED}✗${NC} $service: inactif"
    fi
done

# =============================================================================
# 5. INTERFACE WEB
# =============================================================================

echo -e "\n${YELLOW}5. INTERFACE WEB${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200\|302"; then
    echo -e "  ${GREEN}✓${NC} Interface web accessible"
    echo "  → Accès: http://$(hostname -I | awk '{print $1}')/"
else
    echo -e "  ${RED}✗${NC} Interface web non accessible"
fi

# =============================================================================
# 6. RÉSUMÉ
# =============================================================================

echo -e "\n${BLUE}=== RÉSUMÉ ===${NC}"

# Compter les succès
total_checks=12
success_count=$(grep -c "✓" /tmp/verify_output_$$ 2>/dev/null || echo 0)

if [[ $success_count -eq $total_checks ]]; then
    echo -e "${GREEN}Tout fonctionne correctement !${NC}"
else
    echo -e "${YELLOW}Quelques points à vérifier${NC}"
    echo
    echo "Actions recommandées:"
    
    if ! vcgencmd codec_enabled H264 2>/dev/null | grep -q "enabled"; then
        echo "- Redémarrer pour activer gpu_mem=128"
    fi
    
    if ! systemctl is-active --quiet pulseaudio 2>/dev/null && ! pgrep pulseaudio >/dev/null; then
        echo "- Exécuter: sudo /opt/scripts/fix-audio-final.sh"
    fi
    
    if ! systemctl is-active --quiet chromium-kiosk; then
        echo "- Redémarrer Chromium: sudo systemctl restart chromium-kiosk"
    fi
fi

echo -e "\n${GREEN}=== Test de performance vidéo ===${NC}"
echo "Pour tester les performances:"
echo "1. Ouvrez l'interface web"
echo "2. Uploadez une vidéo MP4 1080p"
echo "3. Les FPS devraient être fluides (25-30 FPS)"
echo "4. Vérifiez l'utilisation CPU avec: htop"

# Cleanup
rm -f /tmp/verify_output_$$