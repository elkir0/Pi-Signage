#!/usr/bin/env bash

# =============================================================================
# Module 06 - Configuration des Tâches Cron
# Version: 2.0.0
# Description: Configuration des tâches automatisées (synchronisation, maintenance)
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly CRON_DIR="/etc/cron.d"
readonly LOGROTATE_CONFIG="/etc/logrotate.d/pi-signage"

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
    echo -e "${GREEN}[CRON]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[CRON]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[CRON]${NC} $*" >&2
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
# VÉRIFICATION DU SERVICE CRON
# =============================================================================

ensure_cron_service() {
    log_info "Vérification du service cron..."
    
    # Installer cron si nécessaire
    if ! command -v crontab >/dev/null 2>&1; then
        log_info "Installation du service cron..."
        apt-get update
        apt-get install -y cron
    fi
    
    # S'assurer que cron est activé et démarré
    if systemctl enable cron; then
        log_info "Service cron activé"
    else
        log_error "Échec de l'activation du service cron"
        return 1
    fi
    
    if systemctl start cron; then
        log_info "Service cron démarré"
    else
        log_warn "Problème lors du démarrage du service cron"
    fi
    
    # Vérifier le statut
    if systemctl is-active cron >/dev/null 2>&1; then
        log_info "Service cron actif"
    else
        log_error "Service cron inactif"
        return 1
    fi
}

# =============================================================================
# CONFIGURATION DE LA SYNCHRONISATION VIDÉOS
# =============================================================================

setup_video_sync_cron() {
    log_info "Configuration de la synchronisation automatique des vidéos..."
    
    # Tâche de synchronisation toutes les 6 heures
    cat > "$CRON_DIR/pi-signage-sync" << 'EOF'
# Synchronisation automatique des vidéos depuis Google Drive
# Toutes les 6 heures à partir de 6h du matin
0 6,12,18,0 * * * root /opt/scripts/sync-videos.sh >> /var/log/pi-signage/sync-cron.log 2>&1

# Synchronisation de vérification toutes les heures (en cas d'échec)
30 * * * * root /opt/scripts/sync-videos.sh --quick >> /var/log/pi-signage/sync-cron.log 2>&1
EOF
    
    log_info "Tâche de synchronisation vidéos configurée (toutes les 6h)"
}

# =============================================================================
# CONFIGURATION DE LA MAINTENANCE SYSTÈME
# =============================================================================

setup_system_maintenance_cron() {
    log_info "Configuration de la maintenance système automatique..."
    
    # Tâches de maintenance
    cat > "$CRON_DIR/pi-signage-maintenance" << 'EOF'
# Maintenance automatique du système Digital Signage

# Redémarrage hebdomadaire (dimanche à 3h du matin)
0 3 * * 0 root /sbin/shutdown -r +1 "Redémarrage de maintenance programmé" >> /var/log/pi-signage/maintenance.log 2>&1

# Nettoyage des logs (tous les jours à 2h du matin)
0 2 * * * root /opt/scripts/cleanup-logs.sh >> /var/log/pi-signage/maintenance.log 2>&1

# Vérification de l'espace disque (toutes les 4 heures)
0 */4 * * * root /opt/scripts/check-disk-space.sh >> /var/log/pi-signage/maintenance.log 2>&1

# Mise à jour automatique des paquets de sécurité (tous les dimanche à 1h)
0 1 * * 0 root apt-get update && apt-get upgrade -y --with-new-pkgs -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >> /var/log/pi-signage/maintenance.log 2>&1

# Vérification de la santé du système (toutes les heures)
15 * * * * root /opt/scripts/health-check.sh >> /var/log/pi-signage/health.log 2>&1
EOF
    
    log_info "Tâches de maintenance système configurées"
}

# =============================================================================
# CONFIGURATION DU MONITORING
# =============================================================================

setup_monitoring_cron() {
    log_info "Configuration du monitoring automatique..."
    
    # Tâches de monitoring
    cat > "$CRON_DIR/pi-signage-monitoring" << 'EOF'
# Monitoring automatique du système Digital Signage

# Surveillance VLC (toutes les 5 minutes)
*/5 * * * * root /opt/scripts/monitor-vlc.sh >> /var/log/pi-signage/monitoring.log 2>&1

# Surveillance de la connectivité réseau (toutes les 10 minutes)
*/10 * * * * root /opt/scripts/monitor-network.sh >> /var/log/pi-signage/monitoring.log 2>&1

# Rapport de statut quotidien (tous les jours à 8h)
0 8 * * * root /opt/scripts/daily-report.sh >> /var/log/pi-signage/reports.log 2>&1

# Surveillance de la température (toutes les 15 minutes)
*/15 * * * * root /opt/scripts/monitor-temperature.sh >> /var/log/pi-signage/monitoring.log 2>&1
EOF
    
    log_info "Tâches de monitoring configurées"
}

# =============================================================================
# CRÉATION DES SCRIPTS DE MAINTENANCE
# =============================================================================

create_maintenance_scripts() {
    log_info "Création des scripts de maintenance..."
    
    # Script de nettoyage des logs
    cat > "/opt/scripts/cleanup-logs.sh" << 'EOF'
#!/bin/bash

# Script de nettoyage des logs

LOG_DIR="/var/log/pi-signage"
MAX_AGE_DAYS=30

echo "$(date): Début du nettoyage des logs"

# Nettoyage des logs anciens
if [[ -d "$LOG_DIR" ]]; then
    find "$LOG_DIR" -name "*.log" -type f -mtime +$MAX_AGE_DAYS -delete
    echo "$(date): Logs de plus de $MAX_AGE_DAYS jours supprimés"
else
    echo "$(date): Répertoire de logs introuvable: $LOG_DIR"
fi

# Nettoyage des logs système liés à notre application
journalctl --vacuum-time=30d
journalctl --vacuum-size=100M

# Nettoyage du cache APT
apt-get clean

echo "$(date): Nettoyage terminé"
EOF
    
    # Script de vérification de l'espace disque
    cat > "/opt/scripts/check-disk-space.sh" << 'EOF'
#!/bin/bash

# Script de vérification de l'espace disque

THRESHOLD=90  # Seuil d'alerte en pourcentage
LOG_FILE="/var/log/pi-signage/disk-space.log"

# Fonction de logging
log_disk() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Vérification de l'espace disque
check_disk_usage() {
    local usage
    usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    log_disk "Utilisation disque: ${usage}%"
    
    if [[ $usage -gt $THRESHOLD ]]; then
        log_disk "ALERTE: Espace disque critique (${usage}% > ${THRESHOLD}%)"
        
        # Actions de nettoyage automatique
        log_disk "Nettoyage automatique en cours..."
        
        # Nettoyage des caches
        apt-get clean
        
        # Nettoyage des logs anciens
        find /var/log -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
        
        # Nouveau calcul
        local new_usage
        new_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
        log_disk "Nouvelle utilisation après nettoyage: ${new_usage}%"
        
        # Si toujours critique, redémarrer pour libérer la mémoire cache
        if [[ $new_usage -gt $THRESHOLD ]]; then
            log_disk "Espace toujours critique, programmation d'un redémarrage"
            shutdown -r +5 "Redémarrage automatique - espace disque critique"
        fi
    else
        log_disk "Espace disque OK (${usage}%)"
    fi
}

# Exécution
check_disk_usage
EOF
    
    # Script de vérification de santé
    cat > "/opt/scripts/health-check.sh" << 'EOF'
#!/bin/bash

# Script de vérification de la santé du système

LOG_FILE="/var/log/pi-signage/health.log"

# Fonction de logging
log_health() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Vérifications
check_services() {
    local services=("lightdm" "vlc-signage" "glances")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if ! systemctl is-active "$service" >/dev/null 2>&1; then
            failed_services+=("$service")
            log_health "SERVICE INACTIF: $service"
            
            # Tentative de redémarrage
            log_health "Tentative de redémarrage: $service"
            systemctl restart "$service" 2>/dev/null || true
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log_health "Tous les services sont actifs"
    else
        log_health "Services ayant eu des problèmes: ${failed_services[*]}"
    fi
}

check_temperature() {
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp=$((temp / 1000))
        
        log_health "Température CPU: ${temp}°C"
        
        if [[ $temp -gt 80 ]]; then
            log_health "ALERTE: Température élevée (${temp}°C)"
        fi
    fi
}

check_memory() {
    local mem_usage
    mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    log_health "Utilisation mémoire: ${mem_usage}%"
    
    if [[ $mem_usage -gt 90 ]]; then
        log_health "ALERTE: Mémoire critique (${mem_usage}%)"
    fi
}

# Exécution des vérifications
log_health "=== Vérification de santé ==="
check_services
check_temperature
check_memory
log_health "=== Fin de vérification ==="
EOF
    
    # Rendre les scripts exécutables
    chmod +x /opt/scripts/cleanup-logs.sh
    chmod +x /opt/scripts/check-disk-space.sh
    chmod +x /opt/scripts/health-check.sh
    
    log_info "Scripts de maintenance créés"
}

# =============================================================================
# CRÉATION DES SCRIPTS DE MONITORING
# =============================================================================

create_monitoring_scripts() {
    log_info "Création des scripts de monitoring..."
    
    # Script de surveillance VLC
    cat > "/opt/scripts/monitor-vlc.sh" << 'EOF'
#!/bin/bash

# Script de surveillance VLC

LOG_FILE="/var/log/pi-signage/vlc-monitor.log"

# Fonction de logging
log_vlc_monitor() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Vérification de VLC
if systemctl is-active vlc-signage.service >/dev/null 2>&1; then
    # Vérifier si VLC fonctionne réellement
    if pgrep -f "vlc.*signage" >/dev/null; then
        log_vlc_monitor "VLC fonctionne correctement"
    else
        log_vlc_monitor "PROBLÈME: Service VLC actif mais processus introuvable"
        systemctl restart vlc-signage.service
        log_vlc_monitor "Service VLC redémarré"
    fi
else
    log_vlc_monitor "PROBLÈME: Service VLC inactif"
    systemctl start vlc-signage.service
    log_vlc_monitor "Service VLC démarré"
fi
EOF
    
    # Script de surveillance réseau
    cat > "/opt/scripts/monitor-network.sh" << 'EOF'
#!/bin/bash

# Script de surveillance réseau

LOG_FILE="/var/log/pi-signage/network-monitor.log"

# Fonction de logging
log_network() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Test de connectivité
if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
    log_network "Connectivité Internet OK"
    
    # Test spécifique Google Drive
    if ping -c 1 -W 5 drive.google.com >/dev/null 2>&1; then
        log_network "Accès Google Drive OK"
    else
        log_network "PROBLÈME: Accès Google Drive échoué"
    fi
else
    log_network "PROBLÈME: Pas de connectivité Internet"
    
    # Tentative de redémarrage du réseau
    log_network "Tentative de redémarrage du réseau"
    systemctl restart networking 2>/dev/null || true
fi
EOF
    
    # Script de surveillance température
    cat > "/opt/scripts/monitor-temperature.sh" << 'EOF'
#!/bin/bash

# Script de surveillance de la température

LOG_FILE="/var/log/pi-signage/temperature.log"
TEMP_CRITICAL=85
TEMP_WARNING=75

# Fonction de logging
log_temp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Lecture de la température
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp_celsius=$((temp / 1000))
    
    log_temp "Température: ${temp_celsius}°C"
    
    if [[ $temp_celsius -gt $TEMP_CRITICAL ]]; then
        log_temp "CRITIQUE: Température trop élevée (${temp_celsius}°C)"
        # Actions d'urgence
        echo "Température critique détectée" | logger -t pi-signage
    elif [[ $temp_celsius -gt $TEMP_WARNING ]]; then
        log_temp "AVERTISSEMENT: Température élevée (${temp_celsius}°C)"
    fi
else
    log_temp "ERREUR: Impossible de lire la température"
fi
EOF
    
    # Script de rapport quotidien
    cat > "/opt/scripts/daily-report.sh" << 'EOF'
#!/bin/bash

# Script de rapport quotidien

REPORT_FILE="/var/log/pi-signage/daily-reports/report-$(date +%Y-%m-%d).log"

# Créer le répertoire des rapports
mkdir -p "$(dirname "$REPORT_FILE")"

# Génération du rapport
cat > "$REPORT_FILE" << EOF_REPORT
=== RAPPORT QUOTIDIEN DIGITAL SIGNAGE ===
Date: $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $(hostname)
Uptime: $(uptime)

=== SERVICES ===
LightDM: $(systemctl is-active lightdm.service)
VLC Signage: $(systemctl is-active vlc-signage.service)
Glances: $(systemctl is-active glances.service)

=== SYSTÈME ===
Température CPU: $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000"°C"}' || echo "N/A")
Utilisation disque: $(df / | awk 'NR==2 {print $5}')
Utilisation mémoire: $(free | awk 'NR==2{printf "%.0f%%", $3*100/$2}')

=== VIDÉOS ===
Nombre de vidéos: $(find /opt/videos -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" 2>/dev/null | wc -l)
Taille totale: $(du -sh /opt/videos 2>/dev/null | cut -f1 || echo "0")

=== RÉSEAU ===
Adresse IP: $(hostname -I | awk '{print $1}')
Test Google: $(ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && echo "OK" || echo "ÉCHEC")
Test Google Drive: $(ping -c 1 -W 2 drive.google.com >/dev/null 2>&1 && echo "OK" || echo "ÉCHEC")

=== FIN DU RAPPORT ===
EOF_REPORT

echo "Rapport quotidien généré: $REPORT_FILE"
EOF
    
    # Rendre les scripts exécutables
    chmod +x /opt/scripts/monitor-vlc.sh
    chmod +x /opt/scripts/monitor-network.sh
    chmod +x /opt/scripts/monitor-temperature.sh
    chmod +x /opt/scripts/daily-report.sh
    
    log_info "Scripts de monitoring créés"
}

# =============================================================================
# CONFIGURATION DE LOGROTATE
# =============================================================================

setup_logrotate() {
    log_info "Configuration de la rotation des logs..."
    
    # Configuration logrotate pour les logs de pi-signage
    cat > "$LOGROTATE_CONFIG" << 'EOF'
/var/log/pi-signage/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    maxsize 10M
}

/var/log/pi-signage/daily-reports/*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    maxsize 5M
}
EOF
    
    # Test de la configuration logrotate
    if logrotate -d "$LOGROTATE_CONFIG" >/dev/null 2>&1; then
        log_info "Configuration logrotate validée"
    else
        log_warn "Problème avec la configuration logrotate"
    fi
    
    log_info "Rotation des logs configurée"
}

# =============================================================================
# VALIDATION DE LA CONFIGURATION CRON
# =============================================================================

validate_cron_setup() {
    log_info "Validation de la configuration cron..."
    
    local errors=0
    
    # Vérification du service cron
    if systemctl is-active cron >/dev/null 2>&1; then
        log_info "✓ Service cron actif"
    else
        log_error "✗ Service cron inactif"
        ((errors++))
    fi
    
    # Vérification des fichiers de tâches cron
    local cron_files=(
        "pi-signage-sync"
        "pi-signage-maintenance"
        "pi-signage-monitoring"
    )
    
    for file in "${cron_files[@]}"; do
        if [[ -f "$CRON_DIR/$file" ]]; then
            log_info "✓ Fichier cron $file présent"
        else
            log_error "✗ Fichier cron $file manquant"
            ((errors++))
        fi
    done
    
    # Vérification des scripts
    local scripts=(
        "/opt/scripts/cleanup-logs.sh"
        "/opt/scripts/check-disk-space.sh"
        "/opt/scripts/health-check.sh"
        "/opt/scripts/monitor-vlc.sh"
        "/opt/scripts/monitor-network.sh"
        "/opt/scripts/monitor-temperature.sh"
        "/opt/scripts/daily-report.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" && -x "$script" ]]; then
            log_info "✓ Script $script créé et exécutable"
        else
            log_error "✗ Script $script manquant ou non exécutable"
            ((errors++))
        fi
    done
    
    # Vérification de logrotate
    if [[ -f "$LOGROTATE_CONFIG" ]]; then
        log_info "✓ Configuration logrotate présente"
    else
        log_error "✗ Configuration logrotate manquante"
        ((errors++))
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Configuration Cron ==="
    
    # Chargement de la configuration
    if ! load_config; then
        return 1
    fi
    
    # Étapes de configuration
    local steps=(
        "ensure_cron_service"
        "setup_video_sync_cron"
        "setup_system_maintenance_cron"
        "setup_monitoring_cron"
        "create_maintenance_scripts"
        "create_monitoring_scripts"
        "setup_logrotate"
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
    if validate_cron_setup; then
        log_info "Configuration cron terminée avec succès"
        
        log_info ""
        log_info "Tâches automatisées configurées :"
        log_info "  - Synchronisation vidéos : toutes les 6h"
        log_info "  - Maintenance système : quotidienne et hebdomadaire"
        log_info "  - Monitoring services : toutes les 5-15 minutes"
        log_info "  - Rapports quotidiens : tous les jours à 8h"
        log_info "  - Redémarrage hebdomadaire : dimanche 3h"
    else
        log_warn "Configuration cron terminée avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Configuration Cron ==="
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