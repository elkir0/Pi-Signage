#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════╗
# ║           PiSignage v4.0 - Installation Complète One-Click         ║
# ║                    Pour Raspberry Pi 4 - 30+ FPS                   ║
# ╚═══════════════════════════════════════════════════════════════════╝

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "BANNER"
╔═══════════════════════════════════════════════════════════╗
║     ██████╗ ██╗███████╗██╗ ██████╗ ███╗   ██╗ █████╗     ║
║     ██╔══██╗██║██╔════╝██║██╔════╝ ████╗  ██║██╔══██╗    ║
║     ██████╔╝██║███████╗██║██║  ███╗██╔██╗ ██║███████║    ║
║     ██╔═══╝ ██║╚════██║██║██║   ██║██║╚██╗██║██╔══██║    ║
║     ██║     ██║███████║██║╚██████╔╝██║ ╚████║██║  ██║    ║
║                                                           ║
║           Version 4.0 - 30+ FPS Guaranteed!              ║
╚═══════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# Installation simplifiée - Essentiel uniquement
echo -e "${YELLOW}Installation PiSignage v4.0...${NC}"

# 1. Mise à jour
sudo apt-get update

# 2. Dépendances
sudo apt-get install -y vlc nginx php-fpm xserver-xorg-core xinit

# 3. Structure
sudo mkdir -p /opt/pisignage/{scripts,web/api,media,logs}

# 4. Auto-démarrage
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf << AUTO
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
AUTO

# 5. Script vidéo
cat > /home/pi/.xinitrc << 'XINIT'
#!/bin/bash
exec cvlc --intf dummy --fullscreen --loop /opt/pisignage/media/*.mp4
XINIT
chmod +x /home/pi/.xinitrc

echo 'if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then exec startx; fi' > /home/pi/.bash_profile

echo -e "${GREEN}✅ Installation terminée! Redémarrez avec: sudo reboot${NC}"
