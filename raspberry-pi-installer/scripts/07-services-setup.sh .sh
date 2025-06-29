#!/usr/bin/env bash

# =============================================================================
# Module 07 - Configuration des Services Systemd
# Version: 2.0.0
# Description: Configuration et optimisation des services systemd
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly SYSTEMD_DIR="/etc/systemd/system"
readonly WATCHDOG_SERVICE="/etc/systemd/system/pi-signage-watchdog.service"

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
    echo -e "${GREEN}[SERVICES]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[SERVICES]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[SERVICES]${NC} $*" >&2
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
# CONFIGURATION DES TARGETS SYSTEMD
# =============================================================================

configure_systemd_targets() {
    log_info "Configuration des targets systemd..."
    
    # S'assurer que le système démarre en mode graphique
    systemctl set-default graphical.target
    
    # Configurer les services pour un démarrage rapide
    log_info "Configuration pour démarrage rapide"
    
    # Désactiver les services non nécessaires pour un système kiosque
    local services_to_disable=(
        "apt-daily.service"
        "apt-daily.timer" 
        "apt-daily-upgrade.service"
        "apt-daily-upgrade.timer"
        "man-db.service"
        "man-db.timer"
        "systemd-timesyncd.service"  # On utilisera NTP si nécessaire
        "plymouth-start.service"
        "plymouth-read-write.service"
        "plymouth-quit-wait.service"
        "plymouth-quit.service"
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            log_info "Désactivation du service: $service"
            systemctl disable "$service" 2>/dev/null || true
            systemctl mask "$service" 2>/dev/null || true
        fi
    done
    
    log_info "Configuration des targets terminée"
}

# =============================================================================
# CRÉATION DU SERVICE WATCHDOG
# =============================================================================

create_watchdog_service() {
    log_info "Création du service de surveillance (watchdog)..."
    
    # Script du watchdog
    cat > "/opt/scripts/pi-signage-watchdog.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# Pi Signage Watchdog - Surveillance des services critiques
# =============================================================================

LOG_FILE="/var/log/pi-signage/watchdog.log"
CRITICAL_SERVICES=("lightdm" "vlc-signage" "glances")
CHECK_INTERVAL=30

# Fonction de logging
log_watchdog() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Fonction de vérification des services
check_critical_services() {
    local failed_services=()
    local restart_needed=false
    
    for service in "${CRITICAL_SERVICES[@]}"; do
        if ! systemctl is-active "$service" >/dev/null 2>&1; then
            log_watchdog "SERVICE CRITIQUE INACTIF: $service"
            failed_services+=("$service")
            restart_needed=true
            
            # Tentative de redémarrage
            log_watchdog "Tentative de redémarrage: $service"
            if systemctl restart "$service"; then
                log_watchdog "Service $service redémarré avec succès"
                sleep 5
                
                # Vérification après redémarrage
                if systemctl is-active "$service" >/dev/null 2>&1; then
                    log_watchdog "Service $service maintenant actif"
                else
                    log_watchdog "ÉCHEC: Service $service toujours inactif après redémarrage"
                fi
            else
                log_watchdog "ÉCHEC: Impossible de redémarrer $service"
            fi
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log_watchdog "Tous les services critiques sont actifs"
    else
        log_watchdog "Services ayant nécessité une intervention: ${failed_services[*]}"
    fi
}

# Fonction de vérification de l'affichage
check_display() {
    # Vérifier si X11 est actif
    if ! pgrep -f "X.*:7" >/dev/null 2>&1; then
        log_watchdog "PROBLÈME: Serveur X non actif"
        
        # Redémarrer LightDM pour relancer X11
        systemctl restart lightdm
        log_watchdog "Redémarrage de LightDM"
        sleep 10
    fi
    
    # Vérifier si l'utilisateur signage est connecté
    if ! who | grep -q "signage"; then
        log_watchdog "PROBLÈME: Utilisateur signage non connecté"
        # LightDM devrait gérer l'auto-login
    fi
}

# Fonction de vérification VLC spécifique
check_vlc_process() {
    if systemctl is-active vlc-signage.service >/dev/null 2>&1; then
        # Le service est actif, mais VLC fonctionne-t-il vraiment ?
        if ! pgrep -f "vlc.*signage" >/dev/null 2>&1; then
            log_watchdog "PROBLÈME: Service VLC actif mais processus VLC introuvable"
            systemctl restart vlc-signage.service
            log_watchdog "Redémarrage forcé du service VLC"
        fi
    fi
}

# Fonction de vérification de la mémoire
check_memory_usage() {
    local mem_usage
    mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [[ $mem_usage -gt 95 ]]; then
        log_watchdog "ALERTE: Mémoire critique (${mem_usage}%)"
        
        # Actions de libération mémoire
        sync
        echo 1 > /proc/sys/vm/drop_caches
        log_watchdog "Cache mémoire vidé"
        
        # Si toujours critique, redémarrer VLC
        local new_mem_usage
        new_mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        if [[ $new_mem_usage -gt 90 ]]; then
            log_watchdog "Mémoire toujours critique, redémarrage VLC"
            systemctl restart vlc-signage.service
        fi
    fi
}

# Fonction principale de surveillance
main_watchdog_loop() {
    log_watchdog "=== Démarrage du watchdog Pi Signage ==="
    
    while true; do
        log_watchdog "Cycle de vérification"
        
        # Vérifications
        check_critical_services
        check_display
        check_vlc_process
        check_memory_usage
        
        # Attendre avant le prochain cycle
        sleep $CHECK_INTERVAL
    done
}

# Signal handler pour arrêt propre
cleanup() {
    log_watchdog "Arrêt du watchdog"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Création du répertoire de logs
mkdir -p "$(dirname "$LOG_FILE")"

# Démarrage de la surveillance
main_watchdog_loop
EOF
    
    chmod +x /opt/scripts/pi-signage-watchdog.sh
    
    # Service systemd pour le watchdog
    cat > "$WATCHDOG_SERVICE" << 'EOF'
[Unit]
Description=Pi Signage Watchdog Service
Documentation=Pi Signage System Monitor
After=multi-user.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/opt/scripts/pi-signage-watchdog.sh
Restart=always
RestartSec=15
StandardOutput=journal
StandardError=journal
SyslogIdentifier=pi-signage-watchdog

# Sécurité
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Activer le service watchdog
    systemctl daemon-reload
    systemctl enable pi-signage-watchdog.service
    
    log_info "Service watchdog créé et activé"
}

# =============================================================================
# OPTIMISATION DES SERVICES EXISTANTS
# =============================================================================

optimize_existing_services() {
    log_info "Optimisation des services existants..."
    
    # Optimisation du service VLC
    if [[ -f "$SYSTEMD_DIR/vlc-signage.service" ]]; then
        log_info "Optimisation du service VLC"
        
        # Ajouter des options de redémarrage robustes
        if ! grep -q "RestartSec=" "$SYSTEMD_DIR/vlc-signage.service"; then
            sed -i '/Restart=always/a RestartSec=10' "$SYSTEMD_DIR/vlc-signage.service"
        fi
        
        if ! grep -q "StartLimitBurst=" "$SYSTEMD_DIR/vlc-signage.service"; then
            sed -i '/\[Service\]/a StartLimitBurst=5' "$SYSTEMD_DIR/vlc-signage.service"
            sed -i '/StartLimitBurst=5/a StartLimitInterval=300' "$SYSTEMD_DIR/vlc-signage.service"
        fi
    fi
    
    # Optimisation du service Glances
    if [[ -f "$SYSTEMD_DIR/glances.service" ]]; then
        log_info "Optimisation du service Glances"
        
        # S'assurer qu'il démarre après le réseau
        if ! grep -q "network-online.target" "$SYSTEMD_DIR/glances.service"; then
            sed -i 's/After=network.target/After=network.target network-online.target/' "$SYSTEMD_DIR/glances.service"
            sed -i 's/Wants=network.target/Wants=network.target network-online.target/' "$SYSTEMD_DIR/glances.service"
        fi
    fi
    
    # Recharger systemd après modifications
    systemctl daemon-reload
    
    log_info "Optimisation des services terminée"
}

# =============================================================================
# CRÉATION D'UN SERVICE DE RÉCUPÉRATION D'URGENCE
# =============================================================================

create_emergency_recovery_service() {
    log_info "Création du service de récupération d'urgence..."
    
    # Script de récupération d'urgence
    cat > "/opt/scripts/emergency-recovery.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# Script de récupération d'urgence Pi Signage
# =============================================================================

LOG_FILE="/var/log/pi-signage/emergency.log"

# Fonction de logging
log_emergency() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
    echo "$*"
}

# Fonction de récupération complète
emergency_recovery() {
    log_emergency "=== RÉCUPÉRATION D'URGENCE ACTIVÉE ==="
    
    # Arrêter tous les services pi-signage
    log_emergency "Arrêt des services..."
    systemctl stop vlc-signage.service 2>/dev/null || true
    systemctl stop glances.service 2>/dev/null || true
    systemctl stop pi-signage-watchdog.service 2>/dev/null || true
    
    # Tuer tous les processus VLC
    log_emergency "Arrêt forcé de VLC..."
    pkill -f vlc 2>/dev/null || true
    sleep 3
    pkill -9 -f vlc 2>/dev/null || true
    
    # Nettoyage mémoire
    log_emergency "Nettoyage mémoire..."
    sync
    echo 3 > /proc/sys/vm/drop_caches
    
    # Vérification de l'espace disque
    log_emergency "Vérification espace disque..."
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $disk_usage -gt 95 ]]; then
        log_emergency "Espace disque critique, nettoyage d'urgence..."
        
        # Nettoyage agressif
        apt-get clean
        find /tmp -type f -delete 2>/dev/null || true
        find /var/log -name "*.log" -type f -mtime +1 -delete 2>/dev/null || true
        journalctl --vacuum-size=50M
    fi
    
    # Redémarrage des services
    log_emergency "Redémarrage des services..."
    systemctl restart lightdm.service
    sleep 15
    
    systemctl start glances.service
    sleep 5
    
    systemctl start vlc-signage.service
    sleep 10
    
    systemctl start pi-signage-watchdog.service
    
    log_emergency "Récupération d'urgence terminée"
}

# Point d'entrée
mkdir -p "$(dirname "$LOG_FILE")"
emergency_recovery
EOF
    
    chmod +x /opt/scripts/emergency-recovery.sh
    
    # Service de récupération d'urgence (déclenchement manuel)
    cat > "$SYSTEMD_DIR/pi-signage-emergency.service" << 'EOF'
[Unit]
Description=Pi Signage Emergency Recovery
Documentation=Emergency recovery for Pi Signage system

[Service]
Type=oneshot
User=root
Group=root
ExecStart=/opt/scripts/emergency-recovery.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=pi-signage-emergency

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    log_info "Service de récupération d'urgence créé"
}

# =============================================================================
# CONFIGURATION DES DÉPENDANCES DE SERVICES
# =============================================================================

configure_service_dependencies() {
    log_info "Configuration des dépendances entre services..."
    
    # Créer un target personnalisé pour pi-signage
    cat > "$SYSTEMD_DIR/pi-signage.target" << 'EOF'
[Unit]
Description=Pi Signage System Target
Documentation=Digital Signage Complete System
Requires=graphical.target
After=graphical.target
AllowIsolate=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Modifier les services pour qu'ils dépendent du target pi-signage
    local services=("vlc-signage.service" "glances.service" "pi-signage-watchdog.service")
    
    for service in "${services[@]}"; do
        if [[ -f "$SYSTEMD_DIR/$service" ]]; then
            # Ajouter la dépendance au target pi-signage
            if ! grep -q "PartOf=pi-signage.target" "$SYSTEMD_DIR/$service"; then
                sed -i '/\[Unit\]/a PartOf=pi-signage.target' "$SYSTEMD_DIR/$service"
            fi
        fi
    done
    
    systemctl daemon-reload
    systemctl enable pi-signage.target
    
    log_info "Dépendances de services configurées"
}

# =============================================================================
# CRÉATION D'UN SCRIPT DE CONTRÔLE GLOBAL
# =============================================================================

create_global_control_script() {
    log_info "Création du script de contrôle global..."
    
    cat > "/opt/scripts/pi-signage-control.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# Script de contrôle global Pi Signage
# =============================================================================

SERVICES=("lightdm" "vlc-signage" "glances" "pi-signage-watchdog")

# Fonctions de contrôle
start_all() {
    echo "Démarrage de tous les services Pi Signage..."
    for service in "${SERVICES[@]}"; do
        echo "Démarrage: $service"
        systemctl start "$service"
    done
    echo "Tous les services démarrés"
}

stop_all() {
    echo "Arrêt de tous les services Pi Signage..."
    for service in "${SERVICES[@]}"; do
        echo "Arrêt: $service"
        systemctl stop "$service"
    done
    echo "Tous les services arrêtés"
}

restart_all() {
    echo "Redémarrage de tous les services Pi Signage..."
    stop_all
    sleep 5
    start_all
}

status_all() {
    echo "État des services Pi Signage:"
    for service in "${SERVICES[@]}"; do
        local status
        if systemctl is-active "$service" >/dev/null 2>&1; then
            status="✓ ACTIF"
        else
            status="✗ INACTIF"
        fi
        printf "  %-20s %s\n" "$service:" "$status"
    done
}

enable_all() {
    echo "Activation de tous les services Pi Signage..."
    for service in "${SERVICES[@]}"; do
        echo "Activation: $service"
        systemctl enable "$service"
    done
    echo "Tous les services activés"
}

disable_all() {
    echo "Désactivation de tous les services Pi Signage..."
    for service in "${SERVICES[@]}"; do
        echo "Désactivation: $service"
        systemctl disable "$service"
    done
    echo "Tous les services désactivés"
}

emergency_recovery() {
    echo "Lancement de la récupération d'urgence..."
    systemctl start pi-signage-emergency.service
}

show_logs() {
    local service="$1"
    if [[ -n "$service" ]]; then
        echo "Logs pour $service:"
        journalctl -u "$service" -f
    else
        echo "Logs globaux Pi Signage:"
        journalctl -t pi-signage -f
    fi
}

# Menu d'utilisation
usage() {
    echo "Usage: $0 {start|stop|restart|status|enable|disable|emergency|logs [service]}"
    echo ""
    echo "Commandes:"
    echo "  start      - Démarrer tous les services"
    echo "  stop       - Arrêter tous les services"
    echo "  restart    - Redémarrer tous les services"
    echo "  status     - Afficher l'état des services"
    echo "  enable     - Activer tous les services au démarrage"
    echo "  disable    - Désactiver tous les services au démarrage"
    echo "  emergency  - Lancer la récupération d'urgence"
    echo "  logs       - Afficher les logs (optionnel: spécifier un service)"
    echo ""
    echo "Services disponibles pour logs: ${SERVICES[*]}"
}

# Point d'entrée
case "${1:-}" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    restart)
        restart_all
        ;;
    status)
        status_all
        ;;
    enable)
        enable_all
        ;;
    disable)
        disable_all
        ;;
    emergency)
        emergency_recovery
        ;;
    logs)
        show_logs "${2:-}"
        ;;
    *)
        usage
        exit 1
        ;;
esac
EOF
    
    chmod +x /opt/scripts/pi-signage-control.sh
    
    # Créer un lien symbolique pour un accès facile
    ln -sf /opt/scripts/pi-signage-control.sh /usr/local/bin/pi-signage
    
    log_info "Script de contrôle global créé"
}

# =============================================================================
# VALIDATION DE LA CONFIGURATION DES SERVICES
# =============================================================================

validate_services_setup() {
    log_info "Validation de la configuration des services..."
    
    local errors=0
    
    # Vérification des services créés
    local services=("pi-signage-watchdog.service" "pi-signage-emergency.service")
    for service in "${services[@]}"; do
        if [[ -f "$SYSTEMD_DIR/$service" ]]; then
            log_info "✓ Service $service créé"
            
            # Vérifier si le service peut être activé
            if systemctl enable "$service" 2>/dev/null; then
                log_info "✓ Service $service activé"
            else
                log_error "✗ Impossible d'activer le service $service"
                ((errors++))
            fi
        else
            log_error "✗ Service $service manquant"
            ((errors++))
        fi
    done
    
    # Vérification du target personnalisé
    if [[ -f "$SYSTEMD_DIR/pi-signage.target" ]]; then
        log_info "✓ Target pi-signage créé"
    else
        log_error "✗ Target pi-signage manquant"
        ((errors++))
    fi
    
    # Vérification des scripts
    local scripts=(
        "/opt/scripts/pi-signage-watchdog.sh"
        "/opt/scripts/emergency-recovery.sh"
        "/opt/scripts/pi-signage-control.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" && -x "$script" ]]; then
            log_info "✓ Script $script créé et exécutable"
        else
            log_error "✗ Script $script manquant ou non exécutable"
            ((errors++))
        fi
    done
    
    # Vérification du lien symbolique
    if [[ -L "/usr/local/bin/pi-signage" ]]; then
        log_info "✓ Commande globale 'pi-signage' disponible"
    else
        log_error "✗ Commande globale 'pi-signage' manquante"
        ((errors++))
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Configuration Services ==="
    
    # Chargement de la configuration
    if ! load_config; then
        return 1
    fi
    
    # Étapes de configuration
    local steps=(
        "configure_systemd_targets"
        "create_watchdog_service"
        "optimize_existing_services"
        "create_emergency_recovery_service"
        "configure_service_dependencies"
        "create_global_control_script"
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
    if validate_services_setup; then
        log_info "Configuration des services terminée avec succès"
        
        log_info ""
        log_info "Services et outils créés :"
        log_info "  - Service watchdog : surveillance continue"
        log_info "  - Service récupération d'urgence : réparation automatique"
        log_info "  - Target pi-signage : gestion groupée"
        log_info "  - Commande globale : pi-signage {start|stop|restart|status|emergency}"
        log_info ""
        log_info "Utilisation :"
        log_info "  sudo pi-signage status    # État des services"
        log_info "  sudo pi-signage restart   # Redémarrer tout"
        log_info "  sudo pi-signage emergency # Récupération d'urgence"
    else
        log_warn "Configuration des services terminée avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Configuration Services ==="
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