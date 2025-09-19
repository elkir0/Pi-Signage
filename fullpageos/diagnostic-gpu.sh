#!/bin/bash

# Diagnostic GPU avancé pour FullPageOS
# Ce script vérifie en détail l'accélération GPU

echo "======================================"
echo "   DIAGNOSTIC GPU AVANCÉ FULLPAGEOS"
echo "======================================"
echo ""

# Couleurs pour l'affichage
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fonction de test
check_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# 1. Info système
echo "=== SYSTÈME ==="
echo "Modèle: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo ""

# 2. Drivers GPU
echo "=== DRIVERS GPU ==="
if lsmod | grep -q vc4; then
    echo -e "${GREEN}✓${NC} Driver VC4 chargé"
    lsmod | grep vc4 | head -3
else
    echo -e "${RED}✗${NC} Driver VC4 non trouvé"
fi

if lsmod | grep -q v3d; then
    echo -e "${GREEN}✓${NC} Driver V3D chargé"
    lsmod | grep v3d | head -3
else
    echo -e "${RED}✗${NC} Driver V3D non trouvé"
fi
echo ""

# 3. Devices GPU
echo "=== DEVICES GPU ==="
if [ -d /dev/dri ]; then
    echo -e "${GREEN}✓${NC} /dev/dri présent"
    ls -la /dev/dri/
else
    echo -e "${RED}✗${NC} /dev/dri manquant"
fi
echo ""

# 4. V4L2 pour décodage vidéo
echo "=== DÉCODAGE VIDÉO V4L2 ==="
if [ -e /dev/video10 ]; then
    echo -e "${GREEN}✓${NC} /dev/video10 (H264 decode) présent"
    v4l2-ctl --list-formats-ext -d /dev/video10 2>/dev/null | head -5
else
    echo -e "${YELLOW}⚠${NC} /dev/video10 non trouvé"
fi
echo ""

# 5. Configuration GPU
echo "=== CONFIGURATION GPU ==="
echo "Mémoire GPU: $(vcgencmd get_mem gpu)"
echo "Fréquence GPU: $(vcgencmd measure_clock core | cut -d= -f2 | awk '{printf "%.0f MHz", $1/1000000}')"
echo "Température: $(vcgencmd measure_temp)"

# Throttling check
throttled=$(vcgencmd get_throttled | cut -d= -f2)
if [ "$throttled" = "0x0" ]; then
    echo -e "${GREEN}✓${NC} Pas de throttling"
else
    echo -e "${RED}✗${NC} Throttling détecté: $throttled"
    echo "  Causes possibles:"
    [ $((throttled & 0x1)) -ne 0 ] && echo "  - Under-voltage"
    [ $((throttled & 0x2)) -ne 0 ] && echo "  - Frequency cap"
    [ $((throttled & 0x4)) -ne 0 ] && echo "  - Throttled"
fi
echo ""

# 6. Process Chromium
echo "=== CHROMIUM GPU ==="
CHROMIUM_PID=$(pgrep -f chromium | head -1)
if [ -n "$CHROMIUM_PID" ]; then
    echo -e "${GREEN}✓${NC} Chromium actif (PID: $CHROMIUM_PID)"
    
    # Vérifier les flags GPU
    cmdline=$(ps -p $CHROMIUM_PID -o args= 2>/dev/null)
    
    echo "Flags GPU détectés:"
    echo "$cmdline" | grep -o "\-\-[a-z-]*gpu[a-z-]*" | sort | uniq | while read flag; do
        echo "  $flag"
    done
    
    # Vérifier le backend
    if echo "$cmdline" | grep -q "use-gl=egl"; then
        echo -e "  ${GREEN}✓${NC} Backend: EGL (GPU hardware)"
    elif echo "$cmdline" | grep -q "use-gl=desktop"; then
        echo -e "  ${GREEN}✓${NC} Backend: Desktop GL"
    elif echo "$cmdline" | grep -q "use-angle=swiftshader"; then
        echo -e "  ${RED}✗${NC} Backend: SwiftShader (SOFTWARE!)"
    else
        echo -e "  ${YELLOW}⚠${NC} Backend: Inconnu"
    fi
    
    # CPU usage
    CPU_USAGE=$(ps -p $CHROMIUM_PID -o %cpu= 2>/dev/null | tr -d ' ')
    if (( $(echo "$CPU_USAGE < 30" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "  ${GREEN}✓${NC} CPU: ${CPU_USAGE}% (GPU actif)"
    else
        echo -e "  ${YELLOW}⚠${NC} CPU: ${CPU_USAGE}% (vérifier GPU)"
    fi
else
    echo -e "${RED}✗${NC} Chromium non actif"
fi
echo ""

# 7. Test de décodage
echo "=== TEST DÉCODAGE H264 ==="
if command -v ffmpeg &> /dev/null; then
    echo "Test avec ffmpeg..."
    timeout 2 ffmpeg -hwaccel auto -i https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_30MB.mp4 -f null - 2>&1 | grep -E "(fps|speed)" | tail -1
else
    echo -e "${YELLOW}⚠${NC} ffmpeg non installé"
fi
echo ""

# 8. Résumé et recommandations
echo "=== RÉSUMÉ ==="

SCORE=0
MAX_SCORE=5

# Calcul du score
[ -d /dev/dri ] && ((SCORE++))
lsmod | grep -q vc4 && ((SCORE++))
[ -e /dev/video10 ] && ((SCORE++))
[ "$throttled" = "0x0" ] && ((SCORE++))
[ -n "$CHROMIUM_PID" ] && ((SCORE++))

echo "Score GPU: $SCORE/$MAX_SCORE"

if [ $SCORE -eq $MAX_SCORE ]; then
    echo -e "${GREEN}✅ EXCELLENT${NC} - GPU pleinement fonctionnel"
    echo "Vous devriez avoir 25-30+ FPS"
elif [ $SCORE -ge 3 ]; then
    echo -e "${YELLOW}⚠️  MOYEN${NC} - GPU partiellement fonctionnel"
    echo "Performances possiblement dégradées"
else
    echo -e "${RED}❌ PROBLÈME${NC} - GPU non fonctionnel"
    echo "Vérifiez la configuration"
fi

echo ""
echo "=== RECOMMANDATIONS ==="

if [ "$throttled" != "0x0" ]; then
    echo "• Utilisez une alimentation officielle 5V 3A"
fi

if ! lsmod | grep -q vc4; then
    echo "• Ajoutez dtoverlay=vc4-kms-v3d dans /boot/config.txt"
fi

if [ ! -d /dev/dri ]; then
    echo "• Vérifiez les drivers GPU dans raspi-config"
fi

if echo "$cmdline" | grep -q "swiftshader"; then
    echo "• Chromium utilise le rendu software!"
    echo "  Modifiez les flags dans /boot/fullpageos.txt"
fi

echo ""
echo "Pour plus d'aide: https://github.com/guysoft/FullPageOS/wiki"