#!/usr/bin/env bash

# =============================================================================
# Fix final pour Chromium Kiosk
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

echo -e "${GREEN}=== Fix Final Chromium Kiosk ===${NC}"

# 1. Vérifier l'environnement graphique
echo -e "\n${YELLOW}1. Détection de l'environnement graphique...${NC}"
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "Environnement: Wayland (display: $WAYLAND_DISPLAY)"
    ENV_TYPE="wayland"
elif [[ -n "${DISPLAY:-}" ]]; then
    echo "Environnement: X11 (display: $DISPLAY)"
    ENV_TYPE="x11"
else
    echo "Pas d'environnement graphique détecté"
    ENV_TYPE="headless"
fi

# 2. Vérifier comment le système démarre
echo -e "\n${YELLOW}2. Vérification du mode de démarrage...${NC}"
if systemctl is-active --quiet lightdm; then
    echo "LightDM actif"
    DM="lightdm"
elif systemctl is-active --quiet gdm3; then
    echo "GDM3 actif"
    DM="gdm3"
else
    echo "Pas de display manager actif"
    DM="none"
fi

# 3. Recréer le script chromium-kiosk.sh correct
echo -e "\n${YELLOW}3. Création du script Chromium corrigé...${NC}"
cat > /opt/scripts/chromium-kiosk.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Attendre que le système soit prêt
sleep 5

# Log
LOG_FILE="/var/log/pi-signage/chromium.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "[$(date)] Démarrage Chromium Kiosk"

# URL du player local
PLAYER_URL="http://localhost:8888/player.html"

# Détecter l'environnement
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "[$(date)] Mode Wayland détecté"
    PLATFORM="wayland"
elif [[ -n "${DISPLAY:-}" ]]; then
    echo "[$(date)] Mode X11 détecté"
    PLATFORM="x11"
else
    echo "[$(date)] Pas d'environnement graphique, configuration X11"
    export DISPLAY=:0
    PLATFORM="x11"
fi

# Nettoyer les anciens processus
pkill -f chromium || true
sleep 2

# Flags Chromium de base
CHROMIUM_FLAGS=(
    --kiosk
    --noerrdialogs
    --disable-infobars
    --no-first-run
    --disable-translate
    --disable-features=TranslateUI
    --autoplay-policy=no-user-gesture-required
    --window-position=0,0
    --window-size=1920,1080
    --use-gl=egl
    --enable-gpu-rasterization
    --enable-accelerated-video-decode
    --enable-features=VaapiVideoDecoder
    --ignore-gpu-blocklist
)

# Ajouter les flags selon la plateforme
if [[ "$PLATFORM" == "wayland" ]]; then
    # Vérifier si Wayland est vraiment disponible
    if [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wayland-1" ]]; then
        CHROMIUM_FLAGS+=(--ozone-platform=wayland --enable-features=UseOzonePlatform)
    else
        echo "[$(date)] Wayland non disponible, bascule sur X11"
        CHROMIUM_FLAGS+=(--ozone-platform=x11)
    fi
else
    CHROMIUM_FLAGS+=(--display="${DISPLAY:-:0}")
fi

# Boucle infinie pour redémarrer si crash
while true; do
    echo "[$(date)] Lancement de Chromium avec flags: ${CHROMIUM_FLAGS[*]}"
    chromium-browser "${CHROMIUM_FLAGS[@]}" "$PLAYER_URL" || true
    echo "[$(date)] Chromium terminé, redémarrage dans 5s..."
    sleep 5
done
EOF

chmod +x /opt/scripts/chromium-kiosk.sh

# 4. Mettre à jour le service systemd
echo -e "\n${YELLOW}4. Mise à jour du service systemd...${NC}"
cat > /etc/systemd/system/chromium-kiosk.service << 'EOF'
[Unit]
Description=Chromium Kiosk Mode
After=graphical.target network.target

[Service]
Type=simple
User=pi
Group=pi
Environment="HOME=/home/pi"
Environment="USER=pi"
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/home/pi/.Xauthority"
Environment="XDG_RUNTIME_DIR=/run/user/1000"
ExecStartPre=/bin/bash -c 'echo "Waiting for display..." && sleep 10'
ExecStart=/opt/scripts/chromium-kiosk.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF

# 5. Si on est en mode Desktop, créer un autostart
if [[ -d /home/pi/.config ]]; then
    echo -e "\n${YELLOW}5. Configuration autostart pour Desktop...${NC}"
    
    # Pour LXDE
    if [[ -d /home/pi/.config/lxsession/LXDE-pi ]]; then
        mkdir -p /home/pi/.config/lxsession/LXDE-pi
        cat > /home/pi/.config/lxsession/LXDE-pi/autostart << 'EOF'
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash
@/opt/scripts/chromium-kiosk.sh
EOF
        chown -R pi:pi /home/pi/.config/lxsession
    fi
    
    # Pour labwc
    if [[ -d /etc/xdg/labwc ]]; then
        cat > /etc/xdg/labwc/autostart << 'EOF'
#!/bin/bash
sleep 3
/opt/scripts/chromium-kiosk.sh &
EOF
        chmod +x /etc/xdg/labwc/autostart
    fi
fi

# 6. Enable et démarrer
echo -e "\n${YELLOW}6. Activation du service...${NC}"
systemctl daemon-reload
systemctl enable chromium-kiosk
systemctl restart chromium-kiosk

sleep 5

# 7. Vérification
echo -e "\n${YELLOW}7. Vérification...${NC}"
if systemctl is-active --quiet chromium-kiosk; then
    echo -e "${GREEN}✓ Service Chromium actif${NC}"
    ps aux | grep chromium | grep -v grep | head -2
else
    echo -e "${RED}✗ Service inactif${NC}"
    echo "Essai de lancement direct..."
    
    # Essayer de lancer directement
    sudo -u pi bash -c 'export DISPLAY=:0; chromium-browser --kiosk --ozone-platform=x11 http://localhost:8888/player.html' &
    sleep 5
    
    if pgrep chromium > /dev/null; then
        echo -e "${GREEN}✓ Chromium lancé directement${NC}"
    else
        echo -e "${RED}✗ Impossible de lancer Chromium${NC}"
    fi
fi

echo -e "\n${GREEN}=== Terminé ===${NC}"
echo "Si l'écran est toujours noir, essayez:"
echo "1. sudo reboot"
echo "2. Ou connectez-vous physiquement au Pi et lancez:"
echo "   chromium-browser --kiosk http://localhost:8888/player.html"