#!/bin/bash

# =============================================================================
# Script de correction du cycle de dépendance systemd
# Version: 1.0.0
# Description: Corrige le problème de démarrage automatique Chromium Kiosk
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Correction du cycle de dépendance systemd ===${NC}"
echo ""

# 1. Sauvegarder la configuration actuelle
echo -e "${YELLOW}[1/5]${NC} Sauvegarde de la configuration actuelle..."
if [[ -f /etc/systemd/system/pi-signage.target ]]; then
    cp /etc/systemd/system/pi-signage.target /etc/systemd/system/pi-signage.target.bak
    echo -e "${GREEN}✓${NC} Sauvegarde créée: pi-signage.target.bak"
fi

# 2. Créer la nouvelle configuration corrigée
echo -e "${YELLOW}[2/5]${NC} Création de la configuration corrigée..."
cat > /etc/systemd/system/pi-signage.target << 'EOF'
[Unit]
Description=Pi Signage System Target
Documentation=Digital Signage Complete System
Requires=multi-user.target
After=multi-user.target
AllowIsolate=yes

[Install]
WantedBy=graphical.target
EOF

echo -e "${GREEN}✓${NC} Configuration pi-signage.target corrigée"

# 3. Activer les services nécessaires
echo -e "${YELLOW}[3/5]${NC} Activation des services..."

# Vérifier et activer x11-kiosk.service
if systemctl list-unit-files x11-kiosk.service >/dev/null 2>&1; then
    systemctl enable x11-kiosk.service
    echo -e "${GREEN}✓${NC} Service x11-kiosk.service activé"
else
    echo -e "${YELLOW}⚠${NC} Service x11-kiosk.service non trouvé"
fi

# Vérifier et activer chromium-kiosk.service
if systemctl list-unit-files chromium-kiosk.service >/dev/null 2>&1; then
    systemctl enable chromium-kiosk.service
    echo -e "${GREEN}✓${NC} Service chromium-kiosk.service activé"
else
    echo -e "${YELLOW}⚠${NC} Service chromium-kiosk.service non trouvé"
fi

# S'assurer que pi-signage-startup.service est activé
if systemctl list-unit-files pi-signage-startup.service >/dev/null 2>&1; then
    systemctl enable pi-signage-startup.service
    echo -e "${GREEN}✓${NC} Service pi-signage-startup.service activé"
fi

# 4. Recharger systemd
echo -e "${YELLOW}[4/5]${NC} Rechargement de systemd..."
systemctl daemon-reload
echo -e "${GREEN}✓${NC} Configuration systemd rechargée"

# 5. Vérifier la correction
echo -e "${YELLOW}[5/5]${NC} Vérification de la correction..."
echo ""

# Vérifier le cycle de dépendance
if systemd-analyze verify pi-signage.target 2>&1 | grep -q "cyclic"; then
    echo -e "${RED}✗${NC} ERREUR: Le cycle de dépendance persiste!"
    systemd-analyze verify pi-signage.target
else
    echo -e "${GREEN}✓${NC} Aucun cycle de dépendance détecté"
fi

# Afficher le statut des services
echo ""
echo "Statut des services:"
echo "-------------------"
systemctl is-enabled pi-signage-startup.service 2>/dev/null && echo -e "pi-signage-startup: ${GREEN}activé${NC}" || echo -e "pi-signage-startup: ${RED}désactivé${NC}"
systemctl is-enabled x11-kiosk.service 2>/dev/null && echo -e "x11-kiosk: ${GREEN}activé${NC}" || echo -e "x11-kiosk: ${RED}désactivé${NC}"
systemctl is-enabled chromium-kiosk.service 2>/dev/null && echo -e "chromium-kiosk: ${GREEN}activé${NC}" || echo -e "chromium-kiosk: ${RED}désactivé${NC}"

echo ""
echo -e "${GREEN}=== Correction terminée ===${NC}"
echo ""
echo "Pour appliquer les changements, redémarrez le système:"
echo -e "${YELLOW}sudo reboot${NC}"
echo ""
echo "Après le redémarrage, vérifiez avec:"
echo -e "${YELLOW}systemctl status pi-signage-startup${NC}"
echo -e "${YELLOW}journalctl -b -u pi-signage-startup${NC}"