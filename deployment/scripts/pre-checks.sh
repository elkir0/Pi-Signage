#!/bin/bash

# PiSignage v0.9.0 - Script de Vérifications Pré-Déploiement
# Vérifie tous les prérequis système avant déploiement

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Compteurs
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# Fonction de log
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $message"
            ((CHECKS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message"
            ((CHECKS_FAILED++))
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ((WARNINGS++))
            ;;
        "INFO")
            echo -e "[INFO] $message"
            ;;
    esac
}

# Vérification de l'OS
check_os() {
    log "INFO" "Vérification du système d'exploitation..."

    # Détecter la distribution
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log "INFO" "OS détecté: $PRETTY_NAME"

        # Vérifier si c'est Raspberry Pi OS
        if [[ "$ID" == "raspbian" ]] || [[ "$NAME" =~ "Raspberry Pi OS" ]]; then
            log "PASS" "Raspberry Pi OS détecté"

            # Vérifier la version (Bullseye recommandé)
            if [[ "$VERSION_CODENAME" == "bullseye" ]]; then
                log "PASS" "Version Bullseye (recommandée)"
            elif [[ "$VERSION_CODENAME" == "bookworm" ]]; then
                log "WARN" "Version Bookworm (supportée mais non testée)"
            else
                log "WARN" "Version $VERSION_CODENAME (peut nécessiter des ajustements)"
            fi
        else
            log "WARN" "OS non-Raspberry Pi détecté (supporté mais non optimal)"
        fi
    else
        log "FAIL" "Impossible de détecter l'OS"
        return 1
    fi

    # Vérifier l'architecture
    local arch=$(uname -m)
    case $arch in
        "armv7l")
            log "PASS" "Architecture ARMv7 (32-bit) - Optimal pour Pi 4"
            ;;
        "aarch64")
            log "PASS" "Architecture ARM64 (64-bit) - Compatible"
            ;;
        "x86_64")
            log "WARN" "Architecture x86_64 - Mode test/développement"
            ;;
        *)
            log "WARN" "Architecture $arch - Supportée mais non testée"
            ;;
    esac

    return 0
}

# Vérification des ressources système
check_system_resources() {
    log "INFO" "Vérification des ressources système..."

    # RAM
    local total_ram=$(free -m | awk 'NR==2{print $2}')
    if [[ $total_ram -ge 1024 ]]; then
        log "PASS" "RAM: ${total_ram}MB (≥1GB)"
    elif [[ $total_ram -ge 512 ]]; then
        log "WARN" "RAM: ${total_ram}MB (minimum 512MB, 1GB recommandé)"
    else
        log "FAIL" "RAM: ${total_ram}MB (insuffisant, minimum 512MB)"
    fi

    # Espace disque
    local available_disk=$(df / | awk 'NR==2 {print int($4/1024)}')
    if [[ $available_disk -ge 2048 ]]; then
        log "PASS" "Espace disque: ${available_disk}MB (≥2GB)"
    elif [[ $available_disk -ge 1024 ]]; then
        log "WARN" "Espace disque: ${available_disk}MB (minimum 1GB, 2GB recommandé)"
    else
        log "FAIL" "Espace disque: ${available_disk}MB (insuffisant, minimum 1GB)"
    fi

    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $1 }' | sed 's/,//')
    local load_int=$(echo "$load_avg * 100" | bc 2>/dev/null | cut -d. -f1)
    if [[ $load_int -lt 100 ]]; then
        log "PASS" "Charge système: $load_avg (normal)"
    elif [[ $load_int -lt 200 ]]; then
        log "WARN" "Charge système: $load_avg (élevée)"
    else
        log "FAIL" "Charge système: $load_avg (trop élevée pour déploiement)"
    fi

    return 0
}

# Vérification de la connectivité réseau
check_network() {
    log "INFO" "Vérification de la connectivité réseau..."

    # Test de connectivité Internet
    if ping -c 3 8.8.8.8 &>/dev/null; then
        log "PASS" "Connectivité Internet (ping 8.8.8.8)"
    else
        log "FAIL" "Pas de connectivité Internet"
        return 1
    fi

    # Test DNS
    if ping -c 1 google.com &>/dev/null; then
        log "PASS" "Résolution DNS fonctionnelle"
    else
        log "FAIL" "Problème de résolution DNS"
        return 1
    fi

    # Vérifier l'IP locale
    local local_ip=$(hostname -I | awk '{print $1}')
    if [[ -n "$local_ip" ]]; then
        log "PASS" "IP locale: $local_ip"
    else
        log "WARN" "Impossible de détecter l'IP locale"
    fi

    return 0
}

# Vérification des permissions et utilisateurs
check_permissions() {
    log "INFO" "Vérification des permissions et utilisateurs..."

    # Vérifier l'utilisateur courant
    local current_user=$(whoami)
    log "INFO" "Utilisateur courant: $current_user"

    # Vérifier sudo
    if sudo -n true 2>/dev/null; then
        log "PASS" "Permissions sudo disponibles"
    else
        log "FAIL" "Permissions sudo requises"
        return 1
    fi

    # Vérifier l'existence du groupe www-data
    if getent group www-data &>/dev/null; then
        log "PASS" "Groupe www-data existant"
    else
        log "WARN" "Groupe www-data manquant (sera créé)"
    fi

    # Vérifier les permissions sur /opt
    if [[ -w /opt ]]; then
        log "PASS" "Permissions d'écriture sur /opt"
    else
        log "FAIL" "Pas de permissions d'écriture sur /opt"
        return 1
    fi

    return 0
}

# Vérification des services système
check_services() {
    log "INFO" "Vérification des services système..."

    # Vérifier systemd
    if systemctl --version &>/dev/null; then
        log "PASS" "systemd disponible"
    else
        log "FAIL" "systemd requis"
        return 1
    fi

    # Vérifier les services conflictuels
    local conflicting_services=("apache2" "lighttpd")
    for service in "${conflicting_services[@]}"; do
        if systemctl is-active "$service" &>/dev/null; then
            log "WARN" "Service conflictuel actif: $service (sera arrêté)"
        fi
    done

    return 0
}

# Vérification des packages critiques
check_critical_packages() {
    log "INFO" "Vérification des packages critiques..."

    # Packages requis pour l'installation
    local required_packages=("curl" "wget" "unzip" "git")
    local missing_packages=()

    for package in "${required_packages[@]}"; do
        if command -v "$package" &>/dev/null; then
            log "PASS" "Package '$package' disponible"
        else
            log "WARN" "Package '$package' manquant (sera installé)"
            missing_packages+=("$package")
        fi
    done

    # Vérifier la disponibilité d'apt
    if command -v apt-get &>/dev/null; then
        log "PASS" "Gestionnaire de packages apt disponible"
    else
        log "FAIL" "Gestionnaire de packages apt requis"
        return 1
    fi

    return 0
}

# Vérification de la GPU et affichage
check_gpu_display() {
    log "INFO" "Vérification GPU et affichage..."

    # Vérifier la GPU Broadcom
    if lsmod | grep -q vc4; then
        log "PASS" "Driver GPU VC4 chargé"
    else
        log "WARN" "Driver GPU VC4 non chargé (sera configuré)"
    fi

    # Vérifier la mémoire GPU
    if command -v vcgencmd &>/dev/null; then
        local gpu_mem=$(vcgencmd get_mem gpu | cut -d= -f2 | cut -d'M' -f1)
        if [[ $gpu_mem -ge 128 ]]; then
            log "PASS" "Mémoire GPU: ${gpu_mem}MB (≥128MB)"
        else
            log "WARN" "Mémoire GPU: ${gpu_mem}MB (128MB recommandé)"
        fi
    else
        log "WARN" "vcgencmd non disponible (mode non-Pi)"
    fi

    # Vérifier la sortie vidéo
    if [[ -c /dev/fb0 ]]; then
        log "PASS" "Framebuffer disponible (/dev/fb0)"
    else
        log "WARN" "Framebuffer non détecté"
    fi

    return 0
}

# Vérification de l'état du système
check_system_state() {
    log "INFO" "Vérification de l'état du système..."

    # Vérifier les processus en cours
    local high_cpu_procs=$(ps aux | awk '$3 > 50 {print $11}' | head -5)
    if [[ -z "$high_cpu_procs" ]]; then
        log "PASS" "Pas de processus à forte charge CPU"
    else
        log "WARN" "Processus à forte charge CPU détectés"
    fi

    # Vérifier l'état des disques
    local disk_errors=$(dmesg | grep -i "error\|fail" | grep -v "ACPI" | tail -3)
    if [[ -z "$disk_errors" ]]; then
        log "PASS" "Pas d'erreurs disque récentes"
    else
        log "WARN" "Erreurs disque détectées dans dmesg"
    fi

    # Vérifier la température (si possible)
    if command -v vcgencmd &>/dev/null; then
        local temp=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
        local temp_int=${temp%.*}
        if [[ $temp_int -lt 70 ]]; then
            log "PASS" "Température CPU: ${temp}°C (normale)"
        elif [[ $temp_int -lt 80 ]]; then
            log "WARN" "Température CPU: ${temp}°C (élevée)"
        else
            log "FAIL" "Température CPU: ${temp}°C (trop élevée)"
        fi
    fi

    return 0
}

# Fonction de résumé
show_summary() {
    echo
    echo "===== RÉSUMÉ DES VÉRIFICATIONS ====="
    echo -e "${GREEN}Réussies:${NC} $CHECKS_PASSED"
    echo -e "${YELLOW}Avertissements:${NC} $WARNINGS"
    echo -e "${RED}Échecs:${NC} $CHECKS_FAILED"
    echo "===================================="

    if [[ $CHECKS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ Système prêt pour le déploiement${NC}"
        return 0
    else
        echo -e "${RED}✗ Problèmes critiques détectés${NC}"
        echo "Corrigez les échecs avant de continuer."
        return 1
    fi
}

# Fonction principale
main() {
    echo "PiSignage v0.9.0 - Vérifications Pré-Déploiement"
    echo "================================================="
    echo

    check_os
    check_system_resources
    check_network
    check_permissions
    check_services
    check_critical_packages
    check_gpu_display
    check_system_state

    show_summary
}

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi