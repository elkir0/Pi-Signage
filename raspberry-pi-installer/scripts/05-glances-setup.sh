#!/usr/bin/env bash

# =============================================================================
# Module 05 - Installation et Configuration Glances
# Version: 2.1.0
# Description: Installation Glances pour monitoring système
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly GLANCES_CONFIG="/etc/glances/glances.conf"
readonly GLANCES_SERVICE="/etc/systemd/system/glances.service"
readonly GLANCES_PASSWORD_FILE="/etc/glances/.htpasswd"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les fonctions de sécurité
if [[ -f "$SCRIPT_DIR/00-security-utils.sh" ]]; then
    source "$SCRIPT_DIR/00-security-utils.sh"
else
    echo "ERREUR: Fichier de sécurité manquant: 00-security-utils.sh" >&2
    exit 1
fi

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# =============================================================================
# LOGGING
# =============================================================================

log_info() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [INFO] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${GREEN}[GLANCES]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[GLANCES]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[GLANCES]${NC} $*" >&2
}

# =============================================================================
# CHARGEMENT DE LA CONFIGURATION
# =============================================================================

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "Configuration chargée"
    else
        log_error "Fichier de configuration introuvable"
        return 1
    fi
}

# =============================================================================
# INSTALLATION DE GLANCES
# =============================================================================

install_glances() {
    log_info "Installation de Glances et dépendances..."
    
    # Installation directe via apt (compatible Debian 11/12 et Raspberry Pi OS)
    local packages=(
        "glances"         # Installation via apt pour éviter les problèmes Python PEP 668
        "apache2-utils"   # Pour htpasswd
        "curl"
    )
    
    # Installation des paquets avec retry
    log_info "Installation de Glances via apt..."
    local install_cmd="apt-get install -y ${packages[*]}"
    if ! safe_execute "$install_cmd" 3 10; then
        log_error "Échec de l'installation de Glances après plusieurs tentatives"
        return 1
    fi
    
    log_info "Glances et dépendances installés avec succès"
    
    # Vérification de l'installation
    if command -v glances >/dev/null 2>&1; then
        local glances_version
        glances_version=$(glances --version 2>/dev/null | head -1 || echo "Version inconnue")
        log_info "Glances disponible: $glances_version"
    else
        log_error "Glances non disponible après installation"
        return 1
    fi
}

# =============================================================================
# CONFIGURATION DE GLANCES
# =============================================================================

configure_glances() {
    log_info "Configuration de Glances..."
    
    # Créer le répertoire de configuration
    mkdir -p /etc/glances
    
    # Configuration principale de Glances
    cat > "$GLANCES_CONFIG" << 'EOF'
[global]
# Refresh time in seconds
refresh=3
# History size
history_size=1200

[cpu]
# CPU warning/critical thresholds in %
user_careful=50
user_warning=70
user_critical=90
system_careful=50
system_warning=70
system_critical=90

[memory]
# Memory warning/critical thresholds in %
careful=65
warning=80
critical=95

[memswap]
# Swap warning/critical thresholds in %
careful=50
warning=70
critical=90

[load]
# Load warning/critical thresholds
# Based on number of CPU cores
careful=0.7
warning=1.0
critical=5.0

[network]
# Network interface to monitor (auto-detect if not specified)
# Hide localhost and docker interfaces
hide=lo,docker.*

[diskio]
# Disk I/O warning/critical thresholds in MB/s
careful=10
warning=20
critical=30

[fs]
# Filesystem warning/critical thresholds in %
careful=50
warning=70
critical=95

[temperature]
# Temperature warning/critical thresholds in °C
careful=60
warning=70
critical=80

[processlist]
# Process list configuration
max_processes=30
sort=cpu_percent

[containers]
# Docker containers monitoring (if Docker is installed)
disable=False

[web]
# Web server configuration
bind=0.0.0.0
port=61208
refresh=5
EOF
    
    log_info "Fichier de configuration Glances créé"
}

# =============================================================================
# CONFIGURATION DE L'AUTHENTIFICATION
# =============================================================================

configure_glances_auth() {
    log_info "Configuration de l'authentification Glances..."
    
    # Charger le mot de passe chiffré depuis la configuration
    if [[ -n "${GLANCES_PASSWORD_ENCRYPTED:-}" ]]; then
        # Déchiffrer le mot de passe
        local glances_password
        glances_password=$(decrypt_password "$GLANCES_PASSWORD_ENCRYPTED")
        
        if [[ -z "$glances_password" ]]; then
            log_warn "Impossible de déchiffrer le mot de passe Glances, authentification désactivée"
            return 0  # Continuer sans authentification plutôt qu'échouer
        fi
        
        # Créer le répertoire pour le fichier de mots de passe
        mkdir -p "$(dirname "$GLANCES_PASSWORD_FILE")"
        
        # Utiliser htpasswd pour créer le fichier de mots de passe
        # Username: admin, Password: depuis la configuration
        if echo "$glances_password" | htpasswd -i -c "$GLANCES_PASSWORD_FILE" admin; then
            log_info "Fichier de mots de passe créé"
            # Permissions sécurisées
            secure_file_permissions "$GLANCES_PASSWORD_FILE" "root" "root" "600"
            
            # Effacer le mot de passe de la mémoire
            glances_password=""
            
            # Logger l'événement de sécurité
            log_security_event "GLANCES_AUTH_CONFIGURED" "Authentification Glances configurée"
        else
            log_error "Échec de la création du fichier de mots de passe"
            return 1
        fi
    else
        log_warn "Mot de passe Glances non défini, pas d'authentification"
    fi
}

# =============================================================================
# CRÉATION DU SERVICE SYSTEMD
# =============================================================================

create_glances_service() {
    log_info "Création du service systemd Glances..."
    
    # Déterminer les options de démarrage
    local glances_options="--webserver --bind 0.0.0.0 --port 61208"
    
    # Ajouter l'authentification si configurée
    if [[ -f "$GLANCES_PASSWORD_FILE" ]]; then
        glances_options="$glances_options --password"
    fi
    
    # Créer le service systemd
    cat > "$GLANCES_SERVICE" << EOF
[Unit]
Description=Glances - System Monitor
Documentation=https://glances.readthedocs.io/
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/glances $glances_options --config $GLANCES_CONFIG
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=glances

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/tmp /var/log

# Environment
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
    
    # Recharger systemd et activer le service
    systemctl daemon-reload
    
    if systemctl enable glances.service; then
        log_info "Service Glances activé"
    else
        log_error "Échec de l'activation du service Glances"
        return 1
    fi
    
    log_info "Service systemd Glances créé et activé"
}

# =============================================================================
# CONFIGURATION DU PARE-FEU (OPTIONNEL)
# =============================================================================

configure_firewall() {
    log_info "Configuration du pare-feu pour Glances..."
    
    # Vérifier si UFW est installé et actif
    if command -v ufw >/dev/null 2>&1; then
        # Autoriser le port 61208 pour Glances
        ufw allow 61208/tcp comment "Glances web interface" 2>/dev/null || true
        log_info "Port 61208 autorisé dans le pare-feu"
    else
        log_info "UFW non installé, configuration du pare-feu ignorée"
    fi
}

# =============================================================================
# CRÉATION D'UN DASHBOARD PERSONNALISÉ
# =============================================================================

create_dashboard_config() {
    log_info "Création de la configuration dashboard personnalisée..."
    
    # Créer un fichier de configuration pour le dashboard Digital Signage
    cat > "/etc/glances/dashboard.conf" << 'EOF'
# Configuration Dashboard Digital Signage

[dashboard]
# Titre du dashboard
title=Digital Signage Monitor

# Sections à afficher
sections=system,cpu,memory,fs,network,processes

# Rafraîchissement en secondes
refresh=5

# Thème (dark/light)
theme=dark

[system]
# Informations système
show_hostname=True
show_os=True
show_uptime=True

[processes]
# Processus à surveiller spécifiquement
watch_list=vlc,rclone,lightdm,glances

[alerts]
# Configuration des alertes
enable=True
email_enable=False
EOF
    
    log_info "Configuration dashboard créée"
}

# =============================================================================
# SCRIPTS D'ADMINISTRATION GLANCES
# =============================================================================

create_glances_admin_scripts() {
    log_info "Création des scripts d'administration Glances..."
    
    # Script de démarrage/arrêt Glances
    cat > "/opt/scripts/glances-control.sh" << 'EOF'
#!/bin/bash

# Script de contrôle Glances

case "$1" in
    start)
        echo "Démarrage de Glances..."
        systemctl start glances.service
        ;;
    stop)
        echo "Arrêt de Glances..."
        systemctl stop glances.service
        ;;
    restart)
        echo "Redémarrage de Glances..."
        systemctl restart glances.service
        ;;
    status)
        echo "État de Glances:"
        systemctl status glances.service
        ;;
    logs)
        echo "Logs de Glances:"
        journalctl -u glances.service -f
        ;;
    web)
        local ip_addr
        ip_addr=$(hostname -I | awk '{print $1}')
        echo "Interface web Glances:"
        echo "  URL: http://${ip_addr}:61208"
        echo "  Utilisateur: admin"
        echo "  Mot de passe: (configuré lors de l'installation)"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|web}"
        exit 1
        ;;
esac
EOF
    
    # Script de changement de mot de passe
    cat > "/opt/scripts/glances-password.sh" << 'EOF'
#!/bin/bash

# Script de changement de mot de passe Glances

echo "=== Changement du mot de passe Glances ==="

# Demander le nouveau mot de passe
read -rsp "Nouveau mot de passe Glances: " new_password
echo

# Vérification de la longueur
if [[ ${#new_password} -lt 6 ]]; then
    echo "ERREUR: Le mot de passe doit contenir au moins 6 caractères"
    exit 1
fi

# Mettre à jour le fichier de mots de passe
password_file="/etc/glances/.htpasswd"
if echo "$new_password" | htpasswd -i "$password_file" admin; then
    echo "Mot de passe mis à jour avec succès"
    
    # Redémarrer Glances
    systemctl restart glances.service
    echo "Service Glances redémarré"
else
    echo "ERREUR: Échec de la mise à jour du mot de passe"
    exit 1
fi
EOF
    
    # Rendre les scripts exécutables
    chmod +x /opt/scripts/glances-control.sh
    chmod +x /opt/scripts/glances-password.sh
    
    log_info "Scripts d'administration Glances créés"
}

# =============================================================================
# VALIDATION DE L'INSTALLATION GLANCES
# =============================================================================

validate_glances_installation() {
    log_info "Validation de l'installation Glances..."
    
    local errors=0
    
    # Vérification de Glances
    if command -v glances >/dev/null 2>&1; then
        log_info "✓ Glances installé"
    else
        log_error "✗ Glances manquant"
        ((errors++))
    fi
    
    # Vérification du fichier de configuration
    if [[ -f "$GLANCES_CONFIG" ]]; then
        log_info "✓ Configuration Glances présente"
    else
        log_error "✗ Configuration Glances manquante"
        ((errors++))
    fi
    
    # Vérification du service
    if systemctl is-enabled glances.service >/dev/null 2>&1; then
        log_info "✓ Service Glances activé"
    else
        log_error "✗ Service Glances non activé"
        ((errors++))
    fi
    
    # Vérification de l'authentification
    if [[ -f "$GLANCES_PASSWORD_FILE" ]]; then
        log_info "✓ Authentification Glances configurée"
    else
        log_warn "⚠ Authentification Glances non configurée"
    fi
    
    # Vérification des scripts d'administration
    if [[ -f "/opt/scripts/glances-control.sh" && -x "/opt/scripts/glances-control.sh" ]]; then
        log_info "✓ Scripts d'administration créés"
    else
        log_error "✗ Scripts d'administration manquants"
        ((errors++))
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Installation Glances ==="
    
    # Chargement de la configuration
    if ! load_config; then
        return 1
    fi
    
    # Étapes d'installation
    local steps=(
        "install_glances"
        "configure_glances"
        "configure_glances_auth"
        "create_glances_service"
        "configure_firewall"
        "create_dashboard_config"
        "create_glances_admin_scripts"
    )
    
    local failed_steps=()
    
    for step in "${steps[@]}"; do
        log_info "Exécution: $step"
        if ! "$step"; then
            log_error "Échec de l'étape: $step"
            failed_steps+=("$step")
        fi
    done
    
    # Validation
    if validate_glances_installation; then
        log_info "Glances installé et configuré avec succès"
        
        # Afficher les informations d'accès
        local ip_addr
        ip_addr=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "IP_ADDRESS")
        
        log_info "Interface web Glances disponible sur:"
        log_info "  URL: http://${ip_addr}:61208"
        log_info "  Utilisateur: admin"
        log_info "  Mot de passe: (configuré)"
        log_info ""
        log_info "Commandes utiles:"
        log_info "  - Contrôle: /opt/scripts/glances-control.sh {start|stop|restart|status|logs|web}"
        log_info "  - Changer mot de passe: /opt/scripts/glances-password.sh"
    else
        log_warn "Glances installé avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Installation Glances ==="
    return 0
}

# =============================================================================
# EXÉCUTION
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

main "$@"