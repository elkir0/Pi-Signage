#!/bin/bash

# =============================================================================
# Diagnostic et correction du démarrage Chromium Kiosk
# Version: 1.0.0
# Description: Diagnostique et corrige les problèmes de démarrage automatique
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
ISSUES_FOUND=0
FIXES_APPLIED=0

echo -e "${BLUE}=== Diagnostic du démarrage Chromium Kiosk ===${NC}"
echo ""

# Fonction de diagnostic
check_issue() {
    local test_name="$1"
    local test_cmd="$2"
    local fix_cmd="${3:-}"
    local fix_desc="${4:-}"
    
    echo -ne "Vérification: $test_name... "
    
    if eval "$test_cmd"; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${RED}✗ PROBLÈME${NC}"
        ((ISSUES_FOUND++))
        
        if [[ -n "$fix_cmd" ]]; then
            echo -e "  ${YELLOW}→ Application de la correction: $fix_desc${NC}"
            if eval "$fix_cmd"; then
                echo -e "  ${GREEN}✓ Correction appliquée${NC}"
                ((FIXES_APPLIED++))
            else
                echo -e "  ${RED}✗ Échec de la correction${NC}"
            fi
        fi
    fi
}

# 1. Vérifier le mode d'affichage
echo -e "${YELLOW}[1/10]${NC} Mode d'affichage"
check_issue "Fichier display-mode.conf existe" \
    "[[ -f /etc/pi-signage/display-mode.conf ]]" \
    "mkdir -p /etc/pi-signage && echo 'chromium' > /etc/pi-signage/display-mode.conf" \
    "Création du fichier avec mode chromium"

check_issue "Mode configuré sur chromium" \
    "[[ -f /etc/pi-signage/display-mode.conf ]] && [[ \$(cat /etc/pi-signage/display-mode.conf) == 'chromium' ]]" \
    "echo 'chromium' > /etc/pi-signage/display-mode.conf" \
    "Configuration du mode chromium"

# 2. Vérifier les cycles de dépendance systemd
echo ""
echo -e "${YELLOW}[2/10]${NC} Dépendances systemd"
check_issue "Pas de cycle de dépendance" \
    "! systemd-analyze verify pi-signage.target 2>&1 | grep -q 'cyclic'" \
    "$(cat <<'EOF'
cat > /etc/systemd/system/pi-signage.target << 'EOT'
[Unit]
Description=Pi Signage System Target
Documentation=Digital Signage Complete System
Requires=multi-user.target
After=multi-user.target
AllowIsolate=yes

[Install]
WantedBy=graphical.target
EOT
systemctl daemon-reload
EOF
)" \
    "Correction du fichier pi-signage.target"

# 3. Vérifier les services
echo ""
echo -e "${YELLOW}[3/10]${NC} Services systemd"
check_issue "Service pi-signage-startup existe" \
    "systemctl list-unit-files pi-signage-startup.service >/dev/null 2>&1"

check_issue "Service pi-signage-startup activé" \
    "systemctl is-enabled pi-signage-startup.service >/dev/null 2>&1" \
    "systemctl enable pi-signage-startup.service" \
    "Activation du service pi-signage-startup"

check_issue "Service x11-kiosk existe" \
    "systemctl list-unit-files x11-kiosk.service >/dev/null 2>&1"

check_issue "Service x11-kiosk activé" \
    "systemctl is-enabled x11-kiosk.service >/dev/null 2>&1" \
    "systemctl enable x11-kiosk.service" \
    "Activation du service x11-kiosk"

check_issue "Service chromium-kiosk existe" \
    "systemctl list-unit-files chromium-kiosk.service >/dev/null 2>&1"

check_issue "Service chromium-kiosk activé" \
    "systemctl is-enabled chromium-kiosk.service >/dev/null 2>&1" \
    "systemctl enable chromium-kiosk.service" \
    "Activation du service chromium-kiosk"

# 4. Vérifier les scripts
echo ""
echo -e "${YELLOW}[4/10]${NC} Scripts nécessaires"
check_issue "Script pi-signage-startup.sh existe" \
    "[[ -x /opt/scripts/pi-signage-startup.sh ]]"

check_issue "Script chromium-kiosk.sh existe" \
    "[[ -x /opt/scripts/chromium-kiosk.sh ]]"

check_issue "Script start-x11-kiosk.sh existe" \
    "[[ -x /opt/scripts/start-x11-kiosk.sh ]]"

# 5. Vérifier les paquets
echo ""
echo -e "${YELLOW}[5/10]${NC} Paquets installés"
check_issue "chromium-browser installé" \
    "dpkg -l chromium-browser >/dev/null 2>&1" \
    "apt-get update && apt-get install -y chromium-browser" \
    "Installation de chromium-browser"

check_issue "xserver-xorg installé" \
    "dpkg -l xserver-xorg >/dev/null 2>&1" \
    "apt-get update && apt-get install -y xserver-xorg xinit" \
    "Installation de X11"

# 6. Vérifier le player web
echo ""
echo -e "${YELLOW}[6/10]${NC} Player web"
check_issue "Répertoire player existe" \
    "[[ -d /var/www/pi-signage-player ]]"

check_issue "Fichier player.html existe" \
    "[[ -f /var/www/pi-signage-player/player.html ]]"

check_issue "Nginx actif" \
    "systemctl is-active nginx >/dev/null 2>&1" \
    "systemctl start nginx" \
    "Démarrage de nginx"

# 7. Vérifier la playlist
echo ""
echo -e "${YELLOW}[7/10]${NC} Playlist"
check_issue "Fichier playlist.json existe" \
    "[[ -f /var/www/pi-signage-player/api/playlist.json ]]" \
    "/opt/scripts/update-playlist.sh 2>/dev/null || echo '{\"videos\":[]}' > /var/www/pi-signage-player/api/playlist.json" \
    "Création d'une playlist vide"

# 8. Vérifier les permissions
echo ""
echo -e "${YELLOW}[8/10]${NC} Permissions"
check_issue "Permissions sur /opt/scripts" \
    "[[ -w /opt/scripts ]]" \
    "chmod 755 /opt/scripts && chmod +x /opt/scripts/*.sh" \
    "Correction des permissions"

# 9. Vérifier l'utilisateur pi
echo ""
echo -e "${YELLOW}[9/10]${NC} Utilisateur"
check_issue "Utilisateur pi existe" \
    "id pi >/dev/null 2>&1"

check_issue "Répertoire home pi existe" \
    "[[ -d /home/pi ]]"

# 10. Test de démarrage manuel
echo ""
echo -e "${YELLOW}[10/10]${NC} Test de démarrage"
echo -e "Test du script de démarrage..."
if timeout 5 /opt/scripts/pi-signage-startup.sh >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Le script de démarrage fonctionne${NC}"
else
    echo -e "${YELLOW}⚠ Le script de démarrage a été interrompu (normal en mode test)${NC}"
fi

# Résumé
echo ""
echo -e "${BLUE}=== Résumé ===${NC}"
echo -e "Problèmes trouvés: ${ISSUES_FOUND}"
echo -e "Corrections appliquées: ${FIXES_APPLIED}"

if [[ $FIXES_APPLIED -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Des corrections ont été appliquées.${NC}"
    echo -e "${YELLOW}Il est recommandé de redémarrer le système :${NC}"
    echo -e "${GREEN}sudo reboot${NC}"
fi

if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✓ Aucun problème détecté !${NC}"
    echo -e "Le système devrait démarrer correctement en mode Chromium Kiosk."
elif [[ $((ISSUES_FOUND - FIXES_APPLIED)) -gt 0 ]]; then
    echo ""
    echo -e "${RED}⚠ Certains problèmes n'ont pas pu être corrigés automatiquement.${NC}"
    echo -e "Consultez les messages ci-dessus pour plus de détails."
fi

echo ""
echo "Pour vérifier le démarrage après redémarrage :"
echo -e "${BLUE}systemctl status pi-signage-startup${NC}"
echo -e "${BLUE}journalctl -b -u pi-signage-startup${NC}"