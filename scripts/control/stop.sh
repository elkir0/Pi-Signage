#!/bin/bash
# PiSignage Desktop v3.0 - Stop Script
# Arrête le player PiSignage

set -euo pipefail

# Configuration
readonly PID_FILE="/tmp/pisignage.pid"

# Couleurs
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Fonctions utilitaires
info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Arrêt par PID
stop_by_pid() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            info "Arrêt du processus PiSignage (PID: $pid)..."
            kill "$pid"
            
            # Attendre l'arrêt
            local count=0
            while ps -p "$pid" > /dev/null 2>&1 && [[ $count -lt 30 ]]; do
                sleep 1
                ((count++))
            done
            
            # Force kill si nécessaire
            if ps -p "$pid" > /dev/null 2>&1; then
                warn "Arrêt forcé du processus..."
                kill -9 "$pid"
            fi
            
            rm -f "$PID_FILE"
            info "Processus arrêté"
        else
            warn "Processus PID $pid non trouvé"
            rm -f "$PID_FILE"
        fi
    fi
}

# Arrêt de tous les processus liés
stop_all_processes() {
    info "Arrêt de tous les processus PiSignage..."
    
    # Chromium avec pisignage
    pkill -f "chromium.*pisignage" || true
    
    # Processus génériques
    pkill -f "pisignage" || true
    
    # Unclutter
    pkill unclutter || true
    
    # VLC si utilisé
    pkill vlc || true
    
    info "Tous les processus arrêtés"
}

# Fonction principale
main() {
    echo "=== PiSignage Desktop v3.0 - Stop ==="
    
    stop_by_pid
    stop_all_processes
    
    info "PiSignage Desktop arrêté!"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi