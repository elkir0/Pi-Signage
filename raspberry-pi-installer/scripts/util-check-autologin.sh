#!/bin/bash

# =============================================================================
# Utilitaire pour vérifier et rapporter l'autologin existant
# Version: 1.0.0
# Description: Détecte l'autologin sans le modifier
# =============================================================================

set -euo pipefail

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Vérification de l'autologin existant ===${NC}"
echo ""

AUTOLOGIN_USER=""
AUTOLOGIN_METHOD=""

# Vérifier LightDM
if [[ -f /etc/lightdm/lightdm.conf ]]; then
    if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf; then
        AUTOLOGIN_USER=$(grep "^autologin-user=" /etc/lightdm/lightdm.conf | cut -d'=' -f2)
        AUTOLOGIN_METHOD="LightDM"
        echo -e "${GREEN}✓${NC} Autologin LightDM configuré pour: $AUTOLOGIN_USER"
    fi
fi

# Vérifier GDM3
if [[ -f /etc/gdm3/custom.conf ]] && [[ -z "$AUTOLOGIN_USER" ]]; then
    if grep -q "AutomaticLoginEnable=true" /etc/gdm3/custom.conf; then
        AUTOLOGIN_USER=$(grep "AutomaticLogin=" /etc/gdm3/custom.conf | cut -d'=' -f2)
        AUTOLOGIN_METHOD="GDM3"
        echo -e "${GREEN}✓${NC} Autologin GDM3 configuré pour: $AUTOLOGIN_USER"
    fi
fi

# Vérifier SDDM
if [[ -f /etc/sddm.conf.d/autologin.conf ]] && [[ -z "$AUTOLOGIN_USER" ]]; then
    if grep -q "User=" /etc/sddm.conf.d/autologin.conf; then
        AUTOLOGIN_USER=$(grep "User=" /etc/sddm.conf.d/autologin.conf | cut -d'=' -f2)
        AUTOLOGIN_METHOD="SDDM"
        echo -e "${GREEN}✓${NC} Autologin SDDM configuré pour: $AUTOLOGIN_USER"
    fi
fi

# Vérifier systemd/getty (console)
if [[ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]] && [[ -z "$AUTOLOGIN_USER" ]]; then
    if grep -q "autologin" /etc/systemd/system/getty@tty1.service.d/autologin.conf; then
        AUTOLOGIN_USER=$(grep -oP 'autologin \K\w+' /etc/systemd/system/getty@tty1.service.d/autologin.conf || echo "")
        if [[ -n "$AUTOLOGIN_USER" ]]; then
            AUTOLOGIN_METHOD="Console (systemd)"
            echo -e "${GREEN}✓${NC} Autologin console configuré pour: $AUTOLOGIN_USER"
        fi
    fi
fi

# Résumé
echo ""
if [[ -n "$AUTOLOGIN_USER" ]]; then
    echo -e "${BLUE}Résumé:${NC}"
    echo "- Utilisateur: $AUTOLOGIN_USER"
    echo "- Méthode: $AUTOLOGIN_METHOD"
    echo "- Home: $(getent passwd "$AUTOLOGIN_USER" | cut -d: -f6)"
    
    # Exporter pour utilisation par d'autres scripts
    cat > /tmp/autologin-detected.conf << EOF
AUTOLOGIN_USER="$AUTOLOGIN_USER"
AUTOLOGIN_METHOD="$AUTOLOGIN_METHOD"
AUTOLOGIN_HOME="$(getent passwd "$AUTOLOGIN_USER" | cut -d: -f6)"
EOF
    
    echo ""
    echo -e "${YELLOW}Note:${NC} Pi Signage s'adaptera à cet utilisateur existant."
else
    echo -e "${YELLOW}⚠${NC} Aucun autologin détecté."
    echo "Pour activer l'autologin, utilisez:"
    echo "- raspi-config > System Options > Boot / Auto Login"
    echo "- Ou l'outil de configuration de votre environnement de bureau"
fi