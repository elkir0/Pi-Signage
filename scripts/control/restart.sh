#!/bin/bash
# PiSignage Desktop v3.0 - Restart Script
# Redémarre le player PiSignage

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Fonctions utilitaires
info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

# Fonction principale
main() {
    echo "=== PiSignage Desktop v3.0 - Restart ==="
    
    info "Arrêt du player..."
    "$SCRIPT_DIR/stop.sh"
    
    info "Attente de 2 secondes..."
    sleep 2
    
    info "Démarrage du player..."
    "$SCRIPT_DIR/start.sh"
    
    info "PiSignage Desktop redémarré!"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi