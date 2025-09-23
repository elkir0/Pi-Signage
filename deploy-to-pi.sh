#!/bin/bash
#############################################
# PiSignage v0.8.0 - Deployment Script
# Deploy to Raspberry Pi Bookworm 64-bit
#############################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PI_HOST="${1:-192.168.1.103}"
PI_USER="${2:-pi}"
PI_PASS="${3:-raspberry}"

echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   PiSignage v0.8.0 Deployment         ║${NC}"
echo -e "${GREEN}║   Target: Bookworm 64-bit             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Target: ${PI_USER}@${PI_HOST}${NC}"

# Check connection
echo -e "\n${GREEN}📡 Test de connexion...${NC}"
if ! sshpass -p "$PI_PASS" ssh -o ConnectTimeout=5 ${PI_USER}@${PI_HOST} "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${RED}❌ Impossible de se connecter au Raspberry Pi${NC}"
    echo "Vérifiez l'adresse IP et les identifiants"
    exit 1
fi
echo -e "${GREEN}✅ Connexion établie${NC}"

# Step 1: Run installation script
echo -e "\n${GREEN}📦 Étape 1/5: Installation des dépendances...${NC}"
sshpass -p "$PI_PASS" ssh ${PI_USER}@${PI_HOST} "bash -s" < install-bookworm-64bit.sh

# Step 2: Copy web files
echo -e "\n${GREEN}📁 Étape 2/5: Déploiement interface web...${NC}"
sshpass -p "$PI_PASS" ssh ${PI_USER}@${PI_HOST} "sudo mkdir -p /opt/pisignage/web/api && sudo chown -R pi:pi /opt/pisignage"

# Copy main files
sshpass -p "$PI_PASS" scp -r web/index.php ${PI_USER}@${PI_HOST}:/opt/pisignage/web/
sshpass -p "$PI_PASS" scp -r web/index-GOLDEN-MASTER.php ${PI_USER}@${PI_HOST}:/opt/pisignage/web/
sshpass -p "$PI_PASS" scp -r web/config.php ${PI_USER}@${PI_HOST}:/opt/pisignage/web/
sshpass -p "$PI_PASS" scp -r web/functions.js ${PI_USER}@${PI_HOST}:/opt/pisignage/web/

# Copy API files
for api in system.php media.php playlist.php youtube.php screenshot.php upload.php logs.php schedule.php; do
    if [ -f "web/api/$api" ]; then
        sshpass -p "$PI_PASS" scp web/api/$api ${PI_USER}@${PI_HOST}:/opt/pisignage/web/api/
    fi
done

# Step 3: Copy scripts
echo -e "\n${GREEN}🔧 Étape 3/5: Déploiement scripts...${NC}"
sshpass -p "$PI_PASS" scp scripts/vlc-control.sh ${PI_USER}@${PI_HOST}:/opt/pisignage/scripts/
sshpass -p "$PI_PASS" scp scripts/vlc-start.sh ${PI_USER}@${PI_HOST}:/opt/pisignage/scripts/ 2>/dev/null || true
sshpass -p "$PI_PASS" scp scripts/screenshot.sh ${PI_USER}@${PI_HOST}:/opt/pisignage/scripts/ 2>/dev/null || true
sshpass -p "$PI_PASS" scp scripts/youtube-dl.sh ${PI_USER}@${PI_HOST}:/opt/pisignage/scripts/ 2>/dev/null || true

# Make scripts executable
sshpass -p "$PI_PASS" ssh ${PI_USER}@${PI_HOST} "sudo chmod +x /opt/pisignage/scripts/*.sh"

# Step 4: Set permissions
echo -e "\n${GREEN}🔐 Étape 4/5: Configuration permissions...${NC}"
sshpass -p "$PI_PASS" ssh ${PI_USER}@${PI_HOST} << 'EOF'
sudo chown -R www-data:www-data /opt/pisignage
sudo chmod -R 755 /opt/pisignage
sudo chmod -R 777 /opt/pisignage/media
sudo chmod -R 777 /opt/pisignage/screenshots
sudo chmod -R 777 /opt/pisignage/logs
sudo chmod -R 777 /dev/shm/pisignage 2>/dev/null || true
sudo usermod -a -G video www-data
EOF

# Step 5: Copy sample media (optional)
echo -e "\n${GREEN}📹 Étape 5/5: Copie médias (optionnel)...${NC}"
if [ -d "media" ] && [ "$(ls -A media)" ]; then
    echo "Copie des fichiers média..."
    sshpass -p "$PI_PASS" scp -r media/* ${PI_USER}@${PI_HOST}:/opt/pisignage/media/ 2>/dev/null || true
else
    echo "Pas de fichiers média à copier"
fi

# Copy documentation
echo -e "\n${GREEN}📚 Copie documentation...${NC}"
sshpass -p "$PI_PASS" scp INTERFACE-GOLDEN-MASTER.md ${PI_USER}@${PI_HOST}:/opt/pisignage/ 2>/dev/null || true
sshpass -p "$PI_PASS" scp CLAUDE.md ${PI_USER}@${PI_HOST}:/opt/pisignage/ 2>/dev/null || true

# Restart services
echo -e "\n${GREEN}🔄 Redémarrage services...${NC}"
sshpass -p "$PI_PASS" ssh ${PI_USER}@${PI_HOST} << 'EOF'
sudo systemctl daemon-reload
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm
sudo systemctl enable pisignage 2>/dev/null || true
EOF

# Test web interface
echo -e "\n${GREEN}🌐 Test interface web...${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://${PI_HOST} | grep -q "200"; then
    echo -e "${GREEN}✅ Interface web accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Interface web non accessible immédiatement${NC}"
    echo "Cela peut être normal au premier démarrage"
fi

# Final summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ DÉPLOIEMENT TERMINÉ !            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📝 Informations de connexion:${NC}"
echo -e "  Interface web: ${GREEN}http://${PI_HOST}${NC}"
echo -e "  SSH: ${GREEN}ssh ${PI_USER}@${PI_HOST}${NC}"
echo ""
echo -e "${YELLOW}📁 Emplacements:${NC}"
echo -e "  Web: /opt/pisignage/web"
echo -e "  Médias: /opt/pisignage/media"
echo -e "  Logs: /opt/pisignage/logs"
echo ""
echo -e "${YELLOW}🔧 Commandes utiles:${NC}"
echo -e "  Statut VLC: sudo /opt/pisignage/scripts/vlc-control.sh status"
echo -e "  Démarrer VLC: sudo /opt/pisignage/scripts/vlc-control.sh start"
echo -e "  Logs: tail -f /opt/pisignage/logs/pisignage.log"
echo ""
echo -e "${GREEN}Interface GOLDEN MASTER préservée avec menu latéral${NC}"
echo -e "${GREEN}VLC optimisé pour Bookworm 64-bit${NC}"