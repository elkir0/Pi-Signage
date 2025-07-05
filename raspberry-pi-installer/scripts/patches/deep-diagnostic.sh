#!/usr/bin/env bash

# =============================================================================
# Diagnostic approfondi Pi Signage
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}=== DIAGNOSTIC APPROFONDI PI SIGNAGE ===${NC}"
echo "Date: $(date)"
echo

# =============================================================================
# 1. GLANCES
# =============================================================================

echo -e "${YELLOW}=== 1. DIAGNOSTIC GLANCES ===${NC}"

# État du service
echo "État du service:"
systemctl status glances --no-pager | head -20

# Ports en écoute
echo -e "\nPorts Glances:"
netstat -tlnp 2>/dev/null | grep -E ":(61208|61209)" || echo "Aucun port Glances trouvé"

# Test direct
echo -e "\nTest d'accès direct:"
curl -s -o /dev/null -w "HTTP Code: %{http_code}\n" http://localhost:61208/ || echo "Échec curl"

# Logs récents
echo -e "\nDerniers logs Glances:"
journalctl -u glances -n 20 --no-pager

# =============================================================================
# 2. PERFORMANCE VIDÉO
# =============================================================================

echo -e "\n${YELLOW}=== 2. DIAGNOSTIC PERFORMANCE VIDÉO ===${NC}"

# GPU Memory
echo "Configuration GPU:"
echo -n "gpu_mem actuel: "
vcgencmd get_mem gpu 2>/dev/null || echo "Impossible de lire"

# Config.txt
echo -e "\nContenu de config.txt (gpu_mem):"
for config in /boot/firmware/config.txt /boot/config.txt; do
    if [[ -f "$config" ]]; then
        echo "Fichier: $config"
        grep -E "gpu_mem|dtoverlay=vc4" "$config" || echo "Aucune config GPU trouvée"
        break
    fi
done

# Codecs
echo -e "\nCodecs hardware:"
for codec in H264 MPG2 WVC1 MJPG VP8; do
    printf "%-8s: " "$codec"
    vcgencmd codec_enabled $codec 2>/dev/null || echo "error"
done

# V4L2 devices
echo -e "\nDevices V4L2:"
ls -la /dev/video* 2>/dev/null | grep video || echo "Aucun device video trouvé"

# Chromium flags
echo -e "\nFlags Chromium actuels:"
if [[ -f /opt/scripts/chromium-kiosk.sh ]]; then
    grep -E "(use-gl|gpu|VaapiVideoDecoder|accelerated)" /opt/scripts/chromium-kiosk.sh || echo "Aucun flag GPU trouvé"
fi

# Processus Chromium
echo -e "\nProcessus Chromium:"
ps aux | grep -v grep | grep chromium | head -5 || echo "Chromium non trouvé"

# =============================================================================
# 3. AUDIO
# =============================================================================

echo -e "\n${YELLOW}=== 3. DIAGNOSTIC AUDIO ===${NC}"

# Configuration ALSA
echo "Configuration audio ALSA:"
amixer cget numid=3 2>/dev/null || echo "Impossible de lire config ALSA"

# Volume
echo -e "\nVolume actuel:"
amixer get Master | grep -E "Mono:|Front Left:" || echo "Impossible de lire le volume"
amixer get PCM 2>/dev/null | grep -E "Mono:|Front Left:" || echo "PCM non disponible"

# PulseAudio
echo -e "\nPulseAudio:"
if command -v pulseaudio >/dev/null 2>&1; then
    echo "PulseAudio installé"
    sudo -u pi pactl info 2>/dev/null | head -5 || echo "PulseAudio non démarré pour l'utilisateur pi"
else
    echo "PulseAudio NON installé"
fi

# Groupes audio
echo -e "\nGroupes de l'utilisateur pi:"
groups pi | grep -o -E "(audio|pulse)" || echo "Pas dans les groupes audio"

# =============================================================================
# 4. SYSTÈME
# =============================================================================

echo -e "\n${YELLOW}=== 4. ÉTAT SYSTÈME ===${NC}"

# CPU et température
echo "CPU et température:"
vcgencmd measure_temp
echo -n "Throttling: "
vcgencmd get_throttled

# Mémoire
echo -e "\nMémoire:"
free -h

# Charge
echo -e "\nCharge système:"
uptime

# Espace disque
echo -e "\nEspace disque:"
df -h / /opt/videos

# =============================================================================
# 5. RECOMMANDATIONS
# =============================================================================

echo -e "\n${BLUE}=== RECOMMANDATIONS ===${NC}"

# Vérifier gpu_mem
if ! vcgencmd get_mem gpu 2>/dev/null | grep -q "gpu=128M"; then
    echo -e "${RED}1. GPU MEM INCORRECT!${NC}"
    echo "   Ajoutez 'gpu_mem=128' dans /boot/firmware/config.txt"
    echo "   Puis redémarrez"
fi

# Vérifier H264
if ! vcgencmd codec_enabled H264 2>/dev/null | grep -q "enabled"; then
    echo -e "${RED}2. CODEC H264 NON ACTIVÉ!${NC}"
    echo "   C'est lié au gpu_mem, corrigez et redémarrez"
fi

# Vérifier Glances
if ! netstat -tlnp 2>/dev/null | grep -q ":61208"; then
    echo -e "${RED}3. GLANCES N'ÉCOUTE PAS SUR 61208!${NC}"
    echo "   Exécutez le fix-all-issues-v2.sh"
fi

# Vérifier PulseAudio
if ! command -v pulseaudio >/dev/null 2>&1; then
    echo -e "${RED}4. PULSEAUDIO MANQUANT!${NC}"
    echo "   Installez avec: sudo apt-get install pulseaudio"
fi

echo -e "\n${GREEN}Fin du diagnostic${NC}"