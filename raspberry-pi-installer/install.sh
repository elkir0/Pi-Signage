#!/usr/bin/env bash

# =============================================================================
# Pi Signage Digital - Script d'installation principal
# Version: 2.3.0
# Description: Point d'entrée pour l'installation de Pi Signage
# =============================================================================

set -euo pipefail

# Couleurs pour l'affichage
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Bannière
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           📺 Pi Signage Digital - Installation 📺           ║"
    echo "║                      Version 2.3.0                           ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Vérification des prérequis
check_prerequisites() {
    echo -e "${BLUE}Vérification des prérequis...${NC}"
    
    # Vérifier qu'on est root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Ce script doit être exécuté en tant que root (sudo)${NC}"
        exit 1
    fi
    
    # Vérifier l'OS
    if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Attention: Ce script est optimisé pour Raspberry Pi${NC}"
        read -p "Continuer quand même ? (y/N) " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
    
    # Vérifier la connexion internet
    if ! ping -c 1 google.com &> /dev/null; then
        echo -e "${RED}❌ Connexion internet requise${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prérequis validés${NC}"
    echo
}

# Lancement de l'orchestrateur principal
launch_installation() {
    local orchestrator_path="./scripts/main_orchestrator.sh"
    
    if [[ -f "$orchestrator_path" ]]; then
        echo -e "${BLUE}Lancement de l'installation modulaire...${NC}"
        echo
        
        # Rendre exécutable et lancer
        chmod +x "$orchestrator_path"
        exec "$orchestrator_path"
    else
        echo -e "${RED}❌ Fichier orchestrateur introuvable: $orchestrator_path${NC}"
        echo -e "${YELLOW}Assurez-vous d'être dans le bon répertoire${NC}"
        exit 1
    fi
}

# Fonction principale
main() {
    show_banner
    check_prerequisites
    launch_installation
}

# Point d'entrée
main "$@"