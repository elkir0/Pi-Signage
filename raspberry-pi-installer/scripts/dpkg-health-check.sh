#!/usr/bin/env bash

# =============================================================================
# Script de vérification et réparation de dpkg pour Raspberry Pi
# Version: 1.0.0
# Description: Vérifie et répare automatiquement les problèmes dpkg courants
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# =============================================================================
# VÉRIFICATION DE L'ÉTAT DE DPKG
# =============================================================================

check_dpkg_status() {
    local status=0
    
    echo -e "\n${BLUE}=== Vérification de l'état de dpkg ===${NC}"
    
    # 1. Vérifier les processus dpkg/apt en cours
    echo -n "Processus dpkg/apt en cours: "
    if pgrep -x "dpkg|apt-get|apt" >/dev/null 2>&1; then
        echo -e "${YELLOW}OUI${NC}"
        pgrep -xa "dpkg|apt-get|apt" || true
        ((status++))
    else
        echo -e "${GREEN}NON${NC}"
    fi
    
    # 2. Vérifier les verrous
    echo -n "Verrous dpkg présents: "
    local locks_found=0
    for lock in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock; do
        if [[ -f "$lock" ]]; then
            if lsof "$lock" >/dev/null 2>&1; then
                echo -e "${RED}OUI (actif)${NC}"
                lsof "$lock" 2>/dev/null || true
                ((locks_found++))
                ((status++))
            fi
        fi
    done
    if [[ $locks_found -eq 0 ]]; then
        echo -e "${GREEN}NON${NC}"
    fi
    
    # 3. Vérifier les paquets non configurés
    echo -n "Paquets non configurés: "
    local unconfigured=$(dpkg --audit 2>&1 | grep -c "packages" || echo "0")
    if [[ $unconfigured -gt 0 ]]; then
        echo -e "${YELLOW}OUI ($unconfigured paquets)${NC}"
        ((status++))
    else
        echo -e "${GREEN}NON${NC}"
    fi
    
    # 4. Vérifier l'intégrité de la base dpkg
    echo -n "Base de données dpkg: "
    if [[ -d /var/lib/dpkg/updates ]] && [[ -n "$(ls -A /var/lib/dpkg/updates 2>/dev/null)" ]]; then
        echo -e "${YELLOW}Mises à jour en attente${NC}"
        ((status++))
    else
        echo -e "${GREEN}OK${NC}"
    fi
    
    # 5. Vérifier l'espace disque
    echo -n "Espace disque disponible: "
    local free_space=$(df -BG /var | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $free_space -lt 1 ]]; then
        echo -e "${RED}INSUFFISANT (<1GB)${NC}"
        ((status++))
    else
        echo -e "${GREEN}OK (${free_space}GB)${NC}"
    fi
    
    return $status
}

# =============================================================================
# RÉPARATION AUTOMATIQUE
# =============================================================================

auto_repair() {
    echo -e "\n${BLUE}=== Réparation automatique de dpkg ===${NC}"
    
    # 1. Arrêter les processus bloqués
    if pgrep -x "dpkg|apt-get|apt" >/dev/null 2>&1; then
        log_warn "Arrêt des processus dpkg/apt bloqués..."
        sudo killall -9 dpkg 2>/dev/null || true
        sudo killall -9 apt-get 2>/dev/null || true
        sudo killall -9 apt 2>/dev/null || true
        sleep 2
    fi
    
    # 2. Supprimer les verrous
    log_info "Suppression des verrous..."
    for lock in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock; do
        if [[ -f "$lock" ]] && ! lsof "$lock" >/dev/null 2>&1; then
            sudo rm -f "$lock"
        fi
    done
    
    # 3. Nettoyer le cache
    log_info "Nettoyage du cache..."
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/*
    
    # 4. Configurer dpkg
    log_info "Configuration de dpkg (peut prendre plusieurs minutes)..."
    if ! sudo dpkg --configure -a; then
        log_warn "Première tentative échouée, réessai avec options forcées..."
        sudo dpkg --configure -a --force-confold --force-confdef || true
    fi
    
    # 5. Mettre à jour les sources
    log_info "Mise à jour des sources de paquets..."
    if ! sudo apt-get update --fix-missing; then
        log_warn "Échec de la mise à jour, nouveau nettoyage..."
        sudo rm -rf /var/lib/apt/lists/*
        sudo apt-get clean
        sudo apt-get update || true
    fi
    
    # 6. Réparer les dépendances
    log_info "Réparation des dépendances..."
    sudo apt-get install -f -y || true
    
    # 7. Nettoyer les paquets inutiles
    log_info "Nettoyage final..."
    sudo apt-get autoremove -y || true
    sudo apt-get autoclean || true
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Vérification de santé dpkg/apt         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    
    # Vérifier qu'on est sur un Raspberry Pi ou en mode compatible
    if [[ ! -f /proc/device-tree/model ]] && [[ ! -f /etc/pi-signage/vm-mode.conf ]]; then
        log_warn "Ce script est optimisé pour Raspberry Pi"
    fi
    
    # Effectuer la vérification
    if check_dpkg_status; then
        echo -e "\n${GREEN}✓ Système dpkg/apt en bon état${NC}"
        exit 0
    else
        echo -e "\n${YELLOW}⚠ Problèmes détectés avec dpkg/apt${NC}"
        
        # Demander confirmation pour la réparation
        if [[ "${1:-}" == "--auto" ]]; then
            auto_repair
        else
            read -p "Voulez-vous tenter une réparation automatique ? (O/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Oo]$ ]] || [[ -z $REPLY ]]; then
                auto_repair
            else
                echo -e "\n${YELLOW}Commandes de réparation manuelle:${NC}"
                echo "sudo dpkg --configure -a"
                echo "sudo apt-get update --fix-missing"
                echo "sudo apt-get install -f"
                exit 1
            fi
        fi
        
        # Vérifier après réparation
        echo -e "\n${BLUE}=== Vérification après réparation ===${NC}"
        if check_dpkg_status; then
            echo -e "\n${GREEN}✓ Réparation réussie!${NC}"
            exit 0
        else
            echo -e "\n${RED}✗ Des problèmes persistent${NC}"
            echo "Consultez la documentation ou demandez de l'aide"
            exit 1
        fi
    fi
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi