#!/usr/bin/env bash

# =============================================================================
# Script d'installation pour VM/Test
# Version: 1.0.0
# Description: Lance l'installation Pi Signage en mode VM
# =============================================================================

set -euo pipefail

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║         📺 Pi Signage - Installation Mode VM 📺             ║"
echo "║                                                              ║"
echo "║     Test sur VM Debian/Ubuntu avant déploiement réel         ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo

# Vérifier qu'on est root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

echo -e "${YELLOW}Configuration du mode VM...${NC}"

# Créer la configuration VM
mkdir -p /etc/pi-signage

cat > /etc/pi-signage/vm-mode.conf << 'EOF'
# Configuration pour mode VM/Test
VM_MODE=true
VM_TYPE=qemu
VM_ARCH=$(uname -m)
VM_OS="$(lsb_release -si 2>/dev/null || echo 'Unknown')-$(lsb_release -sr 2>/dev/null || echo 'Unknown')"

# Émulation Pi 4B 4GB par défaut pour les tests
EMULATED_PI_MODEL="Raspberry Pi 4 Model B Rev 1.4"
EMULATED_PI_GENERATION="4"
EMULATED_PI_VARIANT="4B-4GB"
EMULATED_PI_REVISION="c03114"
EOF

# Créer aussi le fichier pi-model.conf attendu
cat > /tmp/pi-model.conf << 'EOF'
PI_MODEL="Raspberry Pi 4 Model B (VM Emulated)"
PI_GENERATION="4"
PI_VARIANT="4B-4GB-VM"
PI_REVISION="c03114"
EOF

echo -e "${GREEN}✓ Mode VM activé - Émulation Pi 4B 4GB${NC}"
echo

# Détecter quel script est disponible
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/main_orchestrator_v2.sh" ]]; then
    echo -e "${GREEN}Script v2.3.0 détecté${NC}"
    echo "Lancement de l'installation avec choix du mode d'affichage..."
    echo
    exec "$SCRIPT_DIR/main_orchestrator_v2.sh" "$@"
elif [[ -f "$SCRIPT_DIR/main_orchestrator.sh" ]]; then
    echo -e "${GREEN}Script v2.2.0 détecté${NC}"
    echo "Lancement de l'installation classique..."
    echo
    exec "$SCRIPT_DIR/main_orchestrator.sh" "$@"
else
    echo -e "${RED}ERREUR: Aucun script d'installation trouvé${NC}"
    echo "Assurez-vous d'être dans le répertoire scripts/"
    exit 1
fi