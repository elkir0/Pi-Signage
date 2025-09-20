#!/bin/bash
# =============================================================================
# Module 05: Services Système - PiSignage Desktop v3.0
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="/opt/pisignage"
USER="pisignage"
VERBOSE=${VERBOSE:-false}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[SERVICES] $1"
    fi
}

# Créer service systemd principal
create_systemd_service() {
    log "Création du service systemd pisignage..."
    
    cat > /tmp/pisignage.service << EOF
[Unit]
Description=PiSignage Desktop Digital Signage System
Documentation=https://github.com/elkir0/pisignage-desktop
After=network.target graphical.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
Group=$USER
Environment="DISPLAY=:0"
Environment="HOME=/home/$USER"
ExecStartPre=/bin/sleep 10
ExecStart=$BASE_DIR/scripts/player-control.sh start
ExecStop=$BASE_DIR/scripts/player-control.sh stop
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=pisignage

# Limites de ressources
LimitNOFILE=4096
Nice=-10

# Sécurité
PrivateTmp=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$BASE_DIR

[Install]
WantedBy=graphical.target
EOF
    
    # Installer le service
    sudo cp /tmp/pisignage.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable pisignage.service
    
    rm /tmp/pisignage.service
    
    echo -e "${GREEN}✓ Service systemd pisignage créé et activé${NC}"
}

# Main
main() {
    echo "Module 5: Services Système"
    echo "=========================="
    
    create_systemd_service
    
    echo ""
    echo -e "${GREEN}✓ Module services système terminé${NC}"
    
    return 0
}

# Exécution
main "$@"
