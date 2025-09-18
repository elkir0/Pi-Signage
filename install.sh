#!/bin/bash
# =============================================================================
# install.sh - Installation complète PiSignage Desktop v3.0
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
LOG_FILE="/var/log/pisignage-setup.log"
VERBOSE=${VERBOSE:-false}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}"
    echo "==================================================================="
    echo "             PiSignage Desktop v3.0 - Installation"
    echo "==================================================================="
    echo -e "${NC}"
    echo "Installation modulaire pour Raspberry Pi OS Desktop"
    echo ""
}

check_requirements() {
    log "INFO" "Vérification des prérequis"
    
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}ERREUR: N'exécutez pas ce script en tant que root${NC}"
        exit 1
    fi
    
    if ! sudo -v; then
        echo -e "${RED}ERREUR: Privilèges sudo requis${NC}"
        exit 1
    fi
    
    log "INFO" "Prérequis validés"
}

execute_module() {
    local num="$1"
    local file="$2"
    local name="$3"
    
    echo ""
    echo -e "${GREEN}[$num/5] $name${NC}"
    echo "-------------------------------------------------------------------"
    
    if [[ ! -f "$MODULES_DIR/$file" ]]; then
        echo -e "${RED}ERREUR: Module $file non trouvé${NC}"
        return 1
    fi
    
    log "INFO" "Exécution du module: $file"
    
    if VERBOSE="$VERBOSE" bash "$MODULES_DIR/$file"; then
        echo -e "${GREEN}✓ Module $name terminé${NC}"
        return 0
    else
        echo -e "${RED}✗ Échec du module $name${NC}"
        return 1
    fi
}

show_summary() {
    echo ""
    echo -e "${GREEN}"
    echo "==================================================================="
    echo "             Installation PiSignage Desktop v3.0 Terminée!"
    echo "==================================================================="
    echo -e "${NC}"
    
    local ip_address=$(hostname -I | cut -d' ' -f1)
    
    echo "🎯 Accès au système:"
    echo "   Player:  http://$ip_address/"
    echo "   Admin:   http://$ip_address/admin.html"
    echo ""
    echo "📂 Dossiers:"
    echo "   Vidéos:  /opt/pisignage/videos/"
    echo "   Config:  /opt/pisignage/config/"
    echo ""
    echo "🛠 Commandes:"
    echo "   pisignage {play|pause|stop|restart|status}"
    echo "   pisignage-admin {start|stop|restart|status}"
    echo ""
    echo "🔄 Redémarrez maintenant: sudo reboot"
    echo ""
}

main() {
    print_header
    check_requirements
    
    # Créer le log
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo touch "$LOG_FILE"
    sudo chown "$(whoami):$(whoami)" "$LOG_FILE"
    
    log "INFO" "Début installation PiSignage Desktop v3.0"
    
    # Modules
    local modules=(
        "1:01-base-config.sh:Configuration de base"
        "2:02-web-interface.sh:Interface web"
        "3:03-media-player.sh:Media Player"
        "4:04-sync-optional.sh:Synchronisation cloud"
        "5:05-services.sh:Services systemd"
    )
    
    for module_def in "${modules[@]}"; do
        IFS=':' read -r num file name <<< "$module_def"
        
        if ! execute_module "$num" "$file" "$name"; then
            echo ""
            echo -e "${RED}Échec du module $num. Continuer ? (y/N)${NC}"
            read -r continue_install
            
            if [[ ! "$continue_install" =~ ^[yY] ]]; then
                echo "Installation interrompue"
                exit 1
            fi
        fi
    done
    
    show_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
