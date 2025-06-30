#!/usr/bin/env bash

# =============================================================================
# Patch pour permettre l'installation sur VM/Environnement de test
# Version: 1.0.0
# Description: Modifie les scripts pour accepter les installations sur VM
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() {
    echo -e "${GREEN}[PATCH VM]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[PATCH VM]${NC} $*"
}

# =============================================================================
# CRÉATION D'UN FICHIER DE CONFIGURATION VM
# =============================================================================

create_vm_config() {
    log_info "Création de la configuration VM..."
    
    # Créer le répertoire si nécessaire
    mkdir -p /etc/pi-signage
    
    # Créer un fichier de configuration VM
    cat > /etc/pi-signage/vm-mode.conf << 'EOF'
# Configuration pour mode VM/Test
VM_MODE=true
VM_TYPE=qemu
VM_ARCH=$(uname -m)
VM_OS="debian-12"

# Émulation Pi 4B 4GB par défaut pour les tests
EMULATED_PI_MODEL="Raspberry Pi 4 Model B Rev 1.4"
EMULATED_PI_GENERATION="4"
EMULATED_PI_VARIANT="4B-4GB"
EMULATED_PI_REVISION="c03114"
EOF

    # Créer aussi le fichier attendu par les scripts
    cat > /tmp/pi-model.conf << 'EOF'
PI_MODEL="Raspberry Pi 4 Model B (VM Emulated)"
PI_GENERATION="4"
PI_VARIANT="4B-4GB-VM"
PI_REVISION="c03114"
EOF

    # Créer un faux device-tree pour les scripts
    mkdir -p /tmp/device-tree
    echo -n "Raspberry Pi 4 Model B Rev 1.4 (QEMU VM)" > /tmp/device-tree/model
    
    log_info "Configuration VM créée"
}

# =============================================================================
# PATCH DES SCRIPTS PRINCIPAUX
# =============================================================================

patch_orchestrator() {
    log_info "Patch du script orchestrateur..."
    
    # Créer une version patchée qui ne fail pas sur VM
    cat > /tmp/detect_pi_model_patch << 'EOF'
detect_pi_model() {
    log_info "Détection du modèle de Raspberry Pi..."
    
    local pi_generation=""
    local pi_variant=""
    
    # Vérifier si on est en mode VM
    if [[ -f /etc/pi-signage/vm-mode.conf ]]; then
        source /etc/pi-signage/vm-mode.conf
        log_warn "Mode VM détecté - Émulation $EMULATED_PI_MODEL"
        
        # Utiliser les valeurs émulées
        pi_generation="$EMULATED_PI_GENERATION"
        pi_variant="$EMULATED_PI_VARIANT"
        model="$EMULATED_PI_MODEL"
        revision="$EMULATED_PI_REVISION"
        
        # Créer la config
        cat > /tmp/pi-model.conf << EOCONF
PI_MODEL="$model (VM)"
PI_GENERATION="$pi_generation"
PI_VARIANT="$pi_variant"
PI_REVISION="$revision"
EOCONF
        
        log_info "Configuration VM appliquée: Pi $pi_generation ($pi_variant)"
        return 0
    fi
    
    # Détection normale pour vrai Pi
    if [[ -f /proc/device-tree/model ]]; then
        local model=$(tr -d '\0' < /proc/device-tree/model)
        local revision=$(cat /proc/cpuinfo | grep Revision | awk '{print $3}')
        
        echo "Modèle détecté: $model"
        echo "Révision: $revision"
        
        # Suite du code original...
EOF

    log_info "Patch créé"
}

# =============================================================================
# CRÉATION D'UN WRAPPER POUR L'INSTALLATION
# =============================================================================

create_vm_installer() {
    log_info "Création du wrapper d'installation VM..."
    
    cat > /usr/local/bin/pi-signage-vm-install << 'EOF'
#!/bin/bash

# Wrapper pour installation sur VM

echo "=== Pi Signage - Installation Mode VM ==="
echo ""
echo "Ce mode permet de tester l'installation sur une VM Debian/Ubuntu"
echo "Les optimisations spécifiques au Pi seront désactivées"
echo ""

# Activer le mode VM
mkdir -p /etc/pi-signage
cat > /etc/pi-signage/vm-mode.conf << 'EOCONF'
VM_MODE=true
VM_TYPE=qemu
VM_ARCH=$(uname -m)
VM_OS="$(lsb_release -si)-$(lsb_release -sr)"
EMULATED_PI_MODEL="Raspberry Pi 4 Model B Rev 1.4"
EMULATED_PI_GENERATION="4"
EMULATED_PI_VARIANT="4B-4GB"
EMULATED_PI_REVISION="c03114"
EOCONF

# Créer la config Pi émulée
cat > /tmp/pi-model.conf << 'EOCONF'
PI_MODEL="Raspberry Pi 4 Model B (VM Emulated)"
PI_GENERATION="4"
PI_VARIANT="4B-4GB-VM"
PI_REVISION="c03114"
EOCONF

echo "Mode VM activé - Émulation Pi 4B 4GB"
echo ""

# Demander quel script lancer
if [[ -f ./install.sh ]]; then
    echo "Lancement de l'installation..."
    exec ./install.sh "$@"
elif [[ -f ./main_orchestrator.sh ]]; then
    echo "Lancement de l'installation..."
    exec ./main_orchestrator.sh "$@"
else
    echo "ERREUR: Aucun script d'installation trouvé"
    exit 1
fi
EOF

    chmod +x /usr/local/bin/pi-signage-vm-install
    
    log_info "Wrapper créé: /usr/local/bin/pi-signage-vm-install"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== Patch VM pour Pi Signage ==="
    
    # Créer la configuration VM
    create_vm_config
    
    # Créer le wrapper
    create_vm_installer
    
    # Patcher les scripts si demandé
    if [[ "${1:-}" == "--patch-scripts" ]]; then
        patch_orchestrator
        log_info "Scripts patchés"
    fi
    
    echo ""
    log_info "=== Installation VM activée ==="
    echo ""
    echo "Pour installer Pi Signage sur cette VM :"
    echo ""
    echo "1. Option rapide (recommandée) :"
    echo "   sudo pi-signage-vm-install"
    echo ""
    echo "2. Option manuelle :"
    echo "   - Le mode VM est activé"
    echo "   - Lancez maintenant : sudo ./install.sh"
    echo ""
    echo "Note: Les optimisations Pi-spécifiques seront ignorées"
    echo ""
}

# Vérifier qu'on est root
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

main "$@"