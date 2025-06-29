#!/usr/bin/env bash

# =============================================================================
# Module 08 - Création des Outils de Diagnostic
# Version: 2.0.0
# Description: Outils de diagnostic et dépannage pour Pi Signage
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly DIAG_SCRIPT="/opt/pi-signage-diag.sh"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# =============================================================================
# LOGGING
# =============================================================================

log_info() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [INFO] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${GREEN}[DIAG]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[DIAG]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[DIAG]${NC} $*" >&2
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
# CRÉATION DU SCRIPT DE DIAGNOSTIC PRINCIPAL
# =============================================================================

create_main_diagnostic_script() {
    log_info "Création du script de diagnostic principal..."
    
    cat > "$DIAG_SCRIPT" << 'EOF'
#!/bin/bash

# =============================================================================
# Pi Signage - Script de Diagnostic Complet
# =============================================================================

# Configuration
CONFIG_FILE="/etc/pi-signage/config.conf"
REPORT_FILE="/tmp/pi-signage-diagnostic-$(date +%Y%m%d-%H%M%S).txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# FONCTIONS D'AFFICHAGE
# =============================================================================

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# =============================================================================
# FONCTIONS DE DIAGNOSTIC
# =============================================================================

check_system_info() {
    print_header "INFORMATIONS SYSTÈME"
    
    echo "Date/Heure: $(date)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
    
    if [[ -f /proc/cpuinfo ]]; then
        local pi_model
        pi_model=$(grep "Model" /proc/cpuinfo | cut -d':' -f2 | xargs)
        echo "Modèle Pi: $pi_model"
    fi
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "OS: $PRETTY_NAME"
    fi
    
    local ip_addr
    ip_addr=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "N/A")
    echo "Adresse IP: $ip_addr"
    
    echo ""
}

check_services_status() {
    print_header "ÉTAT DES SERVICES"
    
    local services=("lightdm" "vlc-signage" "glances" "pi-signage-watchdog" "cron")
    local all_ok=true
    
    for service in "${services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            if systemctl is-enabled "$service" >/dev/null 2>&1; then
                print_ok "$service (actif et activé)"
            else
                print_warn "$service (actif mais non activé au démarrage)"
                all_ok=false
            fi
        else
            print_error "$service (inactif)"
            all_ok=false
        fi
    done
    
    echo ""
    return $([[ "$all_ok" == "true" ]] && echo 0 || echo 1)
}

check_processes() {
    print_header "PROCESSUS CRITIQUES"
    
    local processes=("vlc" "glances" "lightdm" "Xorg")
    local all_ok=true
    
    for process in "${processes[@]}"; do
        if pgrep -f "$process" >/dev/null 2>&1; then
            local count
            count=$(pgrep -f "$process" | wc -l)
            print_ok "$process ($count processus)"
        else
            print_error "$process (aucun processus)"
            all_ok=false
        fi
    done
    
    echo ""
    return $([[ "$all_ok" == "true" ]] && echo 0 || echo 1)
}

check_display() {
    print_header "AFFICHAGE ET X11"
    
    # Vérifier X11
    if [[ -n "${DISPLAY:-}" ]] || pgrep -f "X.*:7" >/dev/null 2>&1; then
        print_ok "Serveur X actif"
        
        # Vérifier la résolution
        if command -v xrandr >/dev/null 2>&1; then
            local resolution
            resolution=$(DISPLAY=:7.0 xrandr 2>/dev/null | grep -o '[0-9]\+x[0-9]\+' | head -1 || echo "Inconnue")
            print_info "Résolution: $resolution"
        fi
        
        # Vérifier l'utilisateur connecté
        if who | grep -q "signage"; then
            print_ok "Utilisateur signage connecté"
        else
            print_warn "Utilisateur signage non connecté"
        fi
    else
        print_error "Serveur X inactif"
    fi
    
    # Vérifier l'auto-login
    if [[ -f /etc/lightdm/lightdm.conf ]]; then
        if grep -q "autologin-user=signage" /etc/lightdm/lightdm.conf; then
            print_ok "Auto-login configuré"
        else
            print_warn "Auto-login non configuré"
        fi
    fi
    
    echo ""
}

check_videos() {
    print_header "VIDÉOS ET SYNCHRONISATION"
    
    local video_dir="/opt/videos"
    
    if [[ -d "$video_dir" ]]; then
        print_ok "Répertoire vidéos existe"
        
        local video_count
        video_count=$(find "$video_dir" -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" 2>/dev/null | wc -l)
        
        if [[ $video_count -gt 0 ]]; then
            print_ok "$video_count vidéo(s) trouvée(s)"
            
            # Taille totale
            local total_size
            total_size=$(du -sh "$video_dir" 2>/dev/null | cut -f1 || echo "0")
            print_info "Taille totale: $total_size"
            
            # Dernière modification
            local last_mod
            last_mod=$(find "$video_dir" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | xargs -I{} date -d @{} '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Inconnue")
            print_info "Dernière modification: $last_mod"
        else
            print_warn "Aucune vidéo trouvée"
        fi
    else
        print_error "Répertoire vidéos manquant"
    fi
    
    # Vérifier rclone
    if command -v rclone >/dev/null 2>&1; then
        print_ok "rclone installé"
        
        local rclone_config="/home/signage/.config/rclone/rclone.conf"
        if [[ -f "$rclone_config" ]]; then
            if rclone --config="$rclone_config" listremotes | grep -q "gdrive:"; then
                print_ok "Google Drive configuré"
            else
                print_warn "Google Drive non configuré"
            fi
        else
            print_warn "Configuration rclone manquante"
        fi
    else
        print_error "rclone non installé"
    fi
    
    echo ""
}

check_network() {
    print_header "RÉSEAU ET CONNECTIVITÉ"
    
    # Test connectivité générale
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        print_ok "Connectivité Internet"
        
        # Test Google Drive
        if ping -c 1 -W 5 drive.google.com >/dev/null 2>&1; then
            print_ok "Accès Google Drive"
        else
            print_warn "Problème d'accès à Google Drive"
        fi
        
        # Test résolution DNS
        if nslookup google.com >/dev/null 2>&1; then
            print_ok "Résolution DNS"
        else
            print_warn "Problème de résolution DNS"
        fi
    else
        print_error "Pas de connectivité Internet"
    fi
    
    # Afficher les interfaces réseau
    print_info "Interfaces réseau actives:"
    ip addr show | grep -E "^[0-9]+:" | grep -v "lo:" | while read -r line; do
        local interface
        interface=$(echo "$line" | cut -d: -f2 | xargs)
        local status
        status=$(echo "$line" | grep -o "state [A-Z]*" | cut -d' ' -f2)
        echo "  - $interface: $status"
    done
    
    echo ""
}

check_system_resources() {
    print_header "RESSOURCES SYSTÈME"
    
    # CPU et charge
    local load
    load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    print_info "Charge système: $load"
    
    # Mémoire
    local mem_info
    mem_info=$(free -h | awk 'NR==2{printf "Utilisée: %s/%s (%.0f%%)", $3, $2, $3/$2*100}')
    print_info "Mémoire: $mem_info"
    
    # Espace disque
    local disk_info
    disk_info=$(df -h / | awk 'NR==2{printf "Utilisé: %s/%s (%s)", $3, $2, $5}')
    print_info "Espace disque: $disk_info"
    
    # Température
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp=$((temp / 1000))
        
        if [[ $temp -lt 70 ]]; then
            print_ok "Température CPU: ${temp}°C"
        elif [[ $temp -lt 80 ]]; then
            print_warn "Température CPU: ${temp}°C (élevée)"
        else
            print_error "Température CPU: ${temp}°C (critique)"
        fi
    fi
    
    echo ""
}

check_logs() {
    print_header "LOGS ET ERREURS"
    
    # Vérifier les logs de pi-signage
    local log_dir="/var/log/pi-signage"
    if [[ -d "$log_dir" ]]; then
        print_ok "Répertoire de logs existe"
        
        local log_files
        log_files=$(find "$log_dir" -name "*.log" -type f | wc -l)
        print_info "$log_files fichier(s) de logs"
        
        # Dernières erreurs dans les logs
        print_info "Dernières erreurs (24h):"
        find "$log_dir" -name "*.log" -type f -mtime -1 -exec grep -l -i "error\|failed\|critical" {} \; 2>/dev/null | head -3 | while read -r logfile; do
            local error_count
            error_count=$(grep -c -i "error\|failed\|critical" "$logfile" 2>/dev/null || echo 0)
            echo "  - $(basename "$logfile"): $error_count erreur(s)"
        done
    else
        print_warn "Répertoire de logs manquant"
    fi
    
    # Vérifier les logs systemd pour nos services
    print_info "Erreurs récentes dans systemd:"
    local services=("vlc-signage" "glances" "pi-signage-watchdog")
    for service in "${services[@]}"; do
        local error_count
        error_count=$(journalctl -u "$service" --since "1 hour ago" --no-pager | grep -c -i "error\|failed" 2>/dev/null || echo 0)
        if [[ $error_count -gt 0 ]]; then
            echo "  - $service: $error_count erreur(s)"
        fi
    done
    
    echo ""
}

check_configuration() {
    print_header "CONFIGURATION"
    
    # Vérifier le fichier de configuration principal
    if [[ -f "$CONFIG_FILE" ]]; then
        print_ok "Fichier de configuration existe"
        
        # Charger et afficher les paramètres principaux
        source "$CONFIG_FILE"
        print_info "Hostname configuré: ${NEW_HOSTNAME:-'Non défini'}"
        print_info "Dossier Google Drive: ${GDRIVE_FOLDER:-'Non défini'}"
        print_info "Version d'installation: ${SCRIPT_VERSION:-'Inconnue'}"
        print_info "Date d'installation: ${INSTALL_DATE:-'Inconnue'}"
    else
        print_error "Fichier de configuration manquant"
    fi
    
    # Vérifier les fichiers de configuration critiques
    local config_files=(
        "/etc/lightdm/lightdm.conf:Configuration LightDM"
        "/home/signage/.config/vlc/vlcrc:Configuration VLC"
        "/etc/glances/glances.conf:Configuration Glances"
    )
    
    for config in "${config_files[@]}"; do
        local file="${config%:*}"
        local desc="${config#*:}"
        
        if [[ -f "$file" ]]; then
            print_ok "$desc présente"
        else
            print_warn "$desc manquante"
        fi
    done
    
    echo ""
}

generate_support_info() {
    print_header "INFORMATIONS DE SUPPORT"
    
    echo "Commandes utiles pour le dépannage:"
    echo ""
    echo "Services:"
    echo "  sudo pi-signage status          # État des services"
    echo "  sudo pi-signage restart         # Redémarrer tous les services"
    echo "  sudo pi-signage emergency       # Récupération d'urgence"
    echo ""
    echo "Logs:"
    echo "  sudo journalctl -u vlc-signage -f    # Logs VLC en temps réel"
    echo "  sudo journalctl -u glances -f        # Logs Glances en temps réel"
    echo "  tail -f /var/log/pi-signage/*.log    # Tous les logs Pi Signage"
    echo ""
    echo "Synchronisation:"
    echo "  sudo /opt/scripts/sync-videos.sh     # Synchronisation manuelle"
    echo "  sudo /opt/scripts/test-gdrive.sh     # Test Google Drive"
    echo ""
    echo "Interfaces web:"
    local ip_addr
    ip_addr=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "IP_ADDRESS")
    echo "  Glances: http://${ip_addr}:61208"
    echo ""
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    # Bannière
    cat << 'BANNER'
    ____  _    ____  _                              
   |  _ \(_)  / ___|(_) __ _ _ __   __ _  __ _  ___ 
   | |_) | |  \___ \| |/ _` | '_ \ / _` |/ _` |/ _ \
   |  __/| |   ___) | | (_| | | | | (_| | (_| |  __/
   |_|   |_|  |____/|_|\__, |_| |_|\__,_|\__, |\___|
                       |___/             |___/      

BANNER
    
    echo "  Diagnostic Pi Signage - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================================="
    echo ""
    
    # Rediriger également vers un fichier rapport
    exec > >(tee "$REPORT_FILE")
    
    # Exécuter tous les diagnostics
    local total_checks=0
    local failed_checks=0
    
    check_system_info
    ((total_checks++))
    
    if ! check_services_status; then
        ((failed_checks++))
    fi
    ((total_checks++))
    
    if ! check_processes; then
        ((failed_checks++))
    fi
    ((total_checks++))
    
    check_display
    ((total_checks++))
    
    check_videos
    ((total_checks++))
    
    check_network
    ((total_checks++))
    
    check_system_resources
    ((total_checks++))
    
    check_logs
    ((total_checks++))
    
    check_configuration
    ((total_checks++))
    
    generate_support_info
    
    # Résumé final
    print_header "RÉSUMÉ DU DIAGNOSTIC"
    
    local success_rate
    success_rate=$(( (total_checks - failed_checks) * 100 / total_checks ))
    
    if [[ $failed_checks -eq 0 ]]; then
        print_ok "Système en bon état ($success_rate% des vérifications réussies)"
    elif [[ $failed_checks -le 2 ]]; then
        print_warn "Système fonctionnel avec des avertissements ($success_rate% des vérifications réussies)"
    else
        print_error "Problèmes détectés nécessitant attention ($success_rate% des vérifications réussies)"
    fi
    
    echo ""
    echo "Rapport complet sauvegardé dans: $REPORT_FILE"
    echo ""
    
    # Code de sortie basé sur le nombre d'erreurs
    exit $failed_checks
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

main "$@"
EOF
    
    chmod +x "$DIAG_SCRIPT"
    
    log_info "Script de diagnostic principal créé: $DIAG_SCRIPT"
}

# =============================================================================
# CRÉATION D'OUTILS DE DIAGNOSTIC SPÉCIALISÉS
# =============================================================================

create_specialized_diagnostic_tools() {
    log_info "Création d'outils de diagnostic spécialisés..."
    
    # Outil de diagnostic VLC
    cat > "/opt/scripts/diag-vlc.sh" << 'EOF'
#!/bin/bash

# Diagnostic VLC spécialisé

echo "=== Diagnostic VLC ==="

# Vérifier le service
echo "Service VLC:"
systemctl status vlc-signage.service --no-pager -l

echo -e "\nProcessus VLC:"
ps aux | grep -v grep | grep vlc

echo -e "\nConfiguration VLC:"
if [[ -f /home/signage/.config/vlc/vlcrc ]]; then
    echo "✓ Fichier de configuration présent"
    echo "Paramètres principaux:"
    grep -E "^(intf|vout|fullscreen|random|loop)" /home/signage/.config/vlc/vlcrc
else
    echo "✗ Fichier de configuration manquant"
fi

echo -e "\nLogs VLC récents:"
journalctl -u vlc-signage.service --since "1 hour ago" --no-pager | tail -20

echo -e "\nTest de lecture vidéo:"
video_dir="/opt/videos"
if [[ -d "$video_dir" ]]; then
    video_count=$(find "$video_dir" -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" | wc -l)
    echo "Vidéos disponibles: $video_count"
    
    if [[ $video_count -gt 0 ]]; then
        echo "Première vidéo trouvée:"
        find "$video_dir" -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" | head -1
    fi
else
    echo "✗ Répertoire vidéos manquant"
fi
EOF
    
    # Outil de diagnostic réseau
    cat > "/opt/scripts/diag-network.sh" << 'EOF'
#!/bin/bash

# Diagnostic réseau spécialisé

echo "=== Diagnostic Réseau ==="

echo "Interfaces réseau:"
ip addr show

echo -e "\nTable de routage:"
ip route show

echo -e "\nTest de connectivité:"
echo -n "Google DNS (8.8.8.8): "
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ ÉCHEC"
fi

echo -n "Google Drive: "
if ping -c 1 -W 2 drive.google.com >/dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ ÉCHEC"
fi

echo -n "Résolution DNS: "
if nslookup google.com >/dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ ÉCHEC"
fi

echo -e "\nConfiguration DNS:"
cat /etc/resolv.conf

echo -e "\nStatistiques réseau:"
cat /proc/net/dev | grep -E "(eth0|wlan0|enx|wlx)" | head -5
EOF
    
    # Outil de diagnostic système
    cat > "/opt/scripts/diag-system.sh" << 'EOF'
#!/bin/bash

# Diagnostic système spécialisé

echo "=== Diagnostic Système ==="

echo "Informations CPU:"
grep -E "^(processor|model name|cpu MHz|cache size)" /proc/cpuinfo | head -8

echo -e "\nMémoire:"
free -h

echo -e "\nEspace disque:"
df -h

echo -e "\nCharge système:"
uptime

echo -e "\nTempérature:"
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp_celsius=$((temp / 1000))
    echo "CPU: ${temp_celsius}°C"
else
    echo "Information de température non disponible"
fi

echo -e "\nProcessus les plus consommateurs:"
ps aux --sort=-%cpu | head -10

echo -e "\nServices actifs:"
systemctl list-units --type=service --state=running | grep -E "(vlc|glances|lightdm)"

echo -e "\nJournalctl errors récentes:"
journalctl --since "1 hour ago" --priority=err --no-pager | tail -10
EOF
    
    # Rendre les scripts exécutables
    chmod +x /opt/scripts/diag-vlc.sh
    chmod +x /opt/scripts/diag-network.sh
    chmod +x /opt/scripts/diag-system.sh
    
    log_info "Outils de diagnostic spécialisés créés"
}

# =============================================================================
# CRÉATION D'UN OUTIL DE COLLECTE DE LOGS
# =============================================================================

create_log_collector() {
    log_info "Création de l'outil de collecte de logs..."
    
    cat > "/opt/scripts/collect-logs.sh" << 'EOF'
#!/bin/bash

# Collecteur de logs pour support technique

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
COLLECT_DIR="/tmp/pi-signage-logs-$TIMESTAMP"
ARCHIVE_FILE="/tmp/pi-signage-logs-$TIMESTAMP.tar.gz"

echo "=== Collecte des logs Pi Signage ==="
echo "Création du dossier: $COLLECT_DIR"

mkdir -p "$COLLECT_DIR"

# Configuration système
echo "Collecte des informations système..."
{
    echo "=== INFORMATIONS SYSTÈME ==="
    date
    hostname
    uptime
    cat /proc/cpuinfo | grep -E "^(Model|Revision)"
    cat /etc/os-release
    free -h
    df -h
} > "$COLLECT_DIR/system-info.txt"

# Services
echo "Collecte du statut des services..."
{
    echo "=== SERVICES ==="
    systemctl status lightdm vlc-signage glances pi-signage-watchdog --no-pager
} > "$COLLECT_DIR/services-status.txt"

# Configuration Pi Signage
echo "Collecte de la configuration..."
if [[ -f /etc/pi-signage/config.conf ]]; then
    cp /etc/pi-signage/config.conf "$COLLECT_DIR/pi-signage-config.conf"
fi

# Logs système
echo "Collecte des logs système..."
journalctl -u vlc-signage --no-pager > "$COLLECT_DIR/vlc-signage.log" 2>/dev/null || true
journalctl -u glances --no-pager > "$COLLECT_DIR/glances.log" 2>/dev/null || true
journalctl -u lightdm --no-pager > "$COLLECT_DIR/lightdm.log" 2>/dev/null || true
journalctl -u pi-signage-watchdog --no-pager > "$COLLECT_DIR/watchdog.log" 2>/dev/null || true

# Logs Pi Signage
echo "Collecte des logs Pi Signage..."
if [[ -d /var/log/pi-signage ]]; then
    cp -r /var/log/pi-signage "$COLLECT_DIR/"
fi

# Configuration LightDM
if [[ -f /etc/lightdm/lightdm.conf ]]; then
    cp /etc/lightdm/lightdm.conf "$COLLECT_DIR/"
fi

# Configuration VLC (anonymisée)
if [[ -f /home/signage/.config/vlc/vlcrc ]]; then
    cp /home/signage/.config/vlc/vlcrc "$COLLECT_DIR/"
fi

# Liste des vidéos (sans les noms complets pour la confidentialité)
echo "Collecte des informations vidéos..."
{
    echo "=== VIDÉOS ==="
    echo "Nombre de vidéos:"
    find /opt/videos -name "*.mp4" -o -name "*.avi" -o -name "*.mkv" -o -name "*.mov" 2>/dev/null | wc -l
    echo "Taille totale:"
    du -sh /opt/videos 2>/dev/null | cut -f1
    echo "Extensions trouvées:"
    find /opt/videos -type f 2>/dev/null | sed 's/.*\.//' | sort | uniq -c
} > "$COLLECT_DIR/videos-info.txt"

# Configuration réseau
echo "Collecte de la configuration réseau..."
{
    echo "=== RÉSEAU ==="
    ip addr show
    echo -e "\n=== ROUTAGE ==="
    ip route show
    echo -e "\n=== DNS ==="
    cat /etc/resolv.conf
} > "$COLLECT_DIR/network-config.txt"

# Test de connectivité
echo "Test de connectivité..."
{
    echo "=== TESTS DE CONNECTIVITÉ ==="
    echo -n "Google DNS: "
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo "OK"
    else
        echo "ÉCHEC"
    fi
    
    echo -n "Google Drive: "
    if ping -c 1 -W 2 drive.google.com >/dev/null 2>&1; then
        echo "OK"
    else
        echo "ÉCHEC"
    fi
} > "$COLLECT_DIR/connectivity-test.txt"

# Création de l'archive
echo "Création de l'archive..."
cd /tmp
tar -czf "$ARCHIVE_FILE" "pi-signage-logs-$TIMESTAMP/"

# Nettoyage
rm -rf "$COLLECT_DIR"

echo ""
echo "✓ Collecte terminée"
echo "Archive créée: $ARCHIVE_FILE"
echo "Taille: $(du -h "$ARCHIVE_FILE" | cut -f1)"
echo ""
echo "Vous pouvez maintenant envoyer ce fichier au support technique."
echo ""
EOF
    
    chmod +x /opt/scripts/collect-logs.sh
    
    log_info "Outil de collecte de logs créé"
}

# =============================================================================
# CRÉATION D'UN OUTIL DE RÉPARATION AUTOMATIQUE
# =============================================================================

create_auto_repair_tool() {
    log_info "Création de l'outil de réparation automatique..."
    
    cat > "/opt/scripts/auto-repair.sh" << 'EOF'
#!/bin/bash

# Outil de réparation automatique Pi Signage

LOG_FILE="/var/log/pi-signage/auto-repair.log"

# Fonction de logging
log_repair() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

echo "=== Outil de Réparation Automatique Pi Signage ==="
log_repair "Début de la réparation automatique"

# Créer le répertoire de logs
mkdir -p "$(dirname "$LOG_FILE")"

# 1. Vérifier et réparer les services
log_repair "Vérification des services..."
services=("lightdm" "vlc-signage" "glances")
for service in "${services[@]}"; do
    if ! systemctl is-active "$service" >/dev/null 2>&1; then
        log_repair "Redémarrage du service: $service"
        systemctl restart "$service"
        sleep 5
        
        if systemctl is-active "$service" >/dev/null 2>&1; then
            log_repair "Service $service redémarré avec succès"
        else
            log_repair "ÉCHEC: Service $service toujours inactif"
        fi
    else
        log_repair "Service $service OK"
    fi
done

# 2. Vérifier et réparer les permissions
log_repair "Vérification des permissions..."
chown -R signage:signage /home/signage/.config 2>/dev/null || true
chown signage:signage /opt/videos 2>/dev/null || true
chmod +x /opt/scripts/*.sh 2>/dev/null || true

# 3. Nettoyage mémoire
log_repair "Nettoyage mémoire..."
sync
echo 1 > /proc/sys/vm/drop_caches

# 4. Vérification espace disque
log_repair "Vérification espace disque..."
disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $disk_usage -gt 90 ]]; then
    log_repair "Espace disque critique ($disk_usage%), nettoyage..."
    
    # Nettoyage automatique
    apt-get clean
    find /tmp -type f -mtime +1 -delete 2>/dev/null || true
    find /var/log -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
    journalctl --vacuum-size=100M
    
    new_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    log_repair "Espace disque après nettoyage: $new_usage%"
fi

# 5. Test de connectivité et réparation
log_repair "Test de connectivité..."
if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
    log_repair "Problème de connectivité, tentative de réparation..."
    
    # Redémarrer le réseau
    systemctl restart networking 2>/dev/null || true
    sleep 10
    
    # Re-tester
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_repair "Connectivité restaurée"
    else
        log_repair "ÉCHEC: Connectivité toujours problématique"
    fi
else
    log_repair "Connectivité OK"
fi

# 6. Vérification et réparation de l'affichage
log_repair "Vérification de l'affichage..."
if ! pgrep -f "X.*:7" >/dev/null 2>&1; then
    log_repair "Serveur X inactif, redémarrage LightDM..."
    systemctl restart lightdm
    sleep 15
fi

# 7. Vérification VLC spécifique
log_repair "Vérification VLC..."
if systemctl is-active vlc-signage.service >/dev/null 2>&1; then
    if ! pgrep -f "vlc.*signage" >/dev/null 2>&1; then
        log_repair "Service VLC actif mais processus introuvable, redémarrage..."
        systemctl restart vlc-signage.service
    fi
fi

# 8. Rapport final
log_repair "Réparation automatique terminée"

echo ""
echo "✓ Réparation automatique terminée"
echo "Consultez les logs: $LOG_FILE"
echo ""
echo "Statut des services après réparation:"
for service in lightdm vlc-signage glances; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        echo "  ✓ $service: ACTIF"
    else
        echo "  ✗ $service: INACTIF"
    fi
done
EOF
    
    chmod +x /opt/scripts/auto-repair.sh
    
    log_info "Outil de réparation automatique créé"
}

# =============================================================================
# CRÉATION D'ALIAS ET RACCOURCIS
# =============================================================================

create_shortcuts() {
    log_info "Création des raccourcis et alias..."
    
    # Créer des liens symboliques pour un accès facile
    ln -sf "$DIAG_SCRIPT" /usr/local/bin/pi-signage-diag
    ln -sf /opt/scripts/collect-logs.sh /usr/local/bin/pi-signage-logs
    ln -sf /opt/scripts/auto-repair.sh /usr/local/bin/pi-signage-repair
    
    # Créer un script de menu principal
    cat > "/usr/local/bin/pi-signage-tools" << 'EOF'
#!/bin/bash

# Menu principal des outils Pi Signage

while true; do
    clear
    cat << 'BANNER'
    ____  _    ____  _                              
   |  _ \(_)  / ___|(_) __ _ _ __   __ _  __ _  ___ 
   | |_) | |  \___ \| |/ _` | '_ \ / _` |/ _` |/ _ \
   |  __/| |   ___) | | (_| | | | | (_| | (_| |  __/
   |_|   |_|  |____/|_|\__, |_| |_|\__,_|\__, |\___|
                       |___/             |___/      

BANNER
    
    echo "  Outils de Diagnostic et Maintenance"
    echo "=========================================="
    echo ""
    echo "1) Diagnostic complet"
    echo "2) Contrôle des services"
    echo "3) Réparation automatique"
    echo "4) Collecte de logs"
    echo "5) Diagnostic VLC"
    echo "6) Diagnostic réseau"
    echo "7) Diagnostic système"
    echo "8) Synchronisation manuelle"
    echo "9) Test Google Drive"
    echo "0) Quitter"
    echo ""
    read -p "Votre choix [0-9]: " choice
    
    case $choice in
        1)
            echo "Lancement du diagnostic complet..."
            /opt/pi-signage-diag.sh
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        2)
            echo "Contrôle des services..."
            pi-signage status
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        3)
            echo "Réparation automatique..."
            /opt/scripts/auto-repair.sh
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        4)
            echo "Collecte de logs..."
            /opt/scripts/collect-logs.sh
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        5)
            echo "Diagnostic VLC..."
            /opt/scripts/diag-vlc.sh
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        6)
            echo "Diagnostic réseau..."
            /opt/scripts/diag-network.sh
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        7)
            echo "Diagnostic système..."
            /opt/scripts/diag-system.sh
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        8)
            echo "Synchronisation manuelle..."
            /opt/scripts/sync-videos.sh
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        9)
            echo "Test Google Drive..."
            /opt/scripts/test-gdrive.sh
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        0)
            echo "Au revoir!"
            exit 0
            ;;
        *)
            echo "Choix invalide"
            sleep 2
            ;;
    esac
done
EOF
    
    chmod +x /usr/local/bin/pi-signage-tools
    
    log_info "Raccourcis et menu principal créés"
}

# =============================================================================
# VALIDATION DES OUTILS DE DIAGNOSTIC
# =============================================================================

validate_diagnostic_tools() {
    log_info "Validation des outils de diagnostic..."
    
    local errors=0
    
    # Vérification du script principal
    if [[ -f "$DIAG_SCRIPT" && -x "$DIAG_SCRIPT" ]]; then
        log_info "✓ Script de diagnostic principal créé"
    else
        log_error "✗ Script de diagnostic principal manquant"
        ((errors++))
    fi
    
    # Vérification des outils spécialisés
    local tools=(
        "/opt/scripts/diag-vlc.sh"
        "/opt/scripts/diag-network.sh"
        "/opt/scripts/diag-system.sh"
        "/opt/scripts/collect-logs.sh"
        "/opt/scripts/auto-repair.sh"
    )
    
    for tool in "${tools[@]}"; do
        if [[ -f "$tool" && -x "$tool" ]]; then
            log_info "✓ Outil $(basename "$tool") créé"
        else
            log_error "✗ Outil $(basename "$tool") manquant"
            ((errors++))
        fi
    done
    
    # Vérification des raccourcis
    local shortcuts=(
        "/usr/local/bin/pi-signage-diag"
        "/usr/local/bin/pi-signage-logs"
        "/usr/local/bin/pi-signage-repair"
        "/usr/local/bin/pi-signage-tools"
    )
    
    for shortcut in "${shortcuts[@]}"; do
        if [[ -L "$shortcut" ]] || [[ -f "$shortcut" ]]; then
            log_info "✓ Raccourci $(basename "$shortcut") créé"
        else
            log_error "✗ Raccourci $(basename "$shortcut") manquant"
            ((errors++))
        fi
    done
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Création Outils de Diagnostic ==="
    
    # Chargement de la configuration
    if ! load_config; then
        return 1
    fi
    
    # Étapes de création
    local steps=(
        "create_main_diagnostic_script"
        "create_specialized_diagnostic_tools"
        "create_log_collector"
        "create_auto_repair_tool"
        "create_shortcuts"
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
    if validate_diagnostic_tools; then
        log_info "Outils de diagnostic créés avec succès"
        
        log_info ""
        log_info "Outils de diagnostic disponibles :"
        log_info "  - pi-signage-diag     # Diagnostic complet"
        log_info "  - pi-signage-logs     # Collecte de logs"
        log_info "  - pi-signage-repair   # Réparation automatique"
        log_info "  - pi-signage-tools    # Menu interactif"
        log_info ""
        log_info "Scripts spécialisés :"
        log_info "  - /opt/scripts/diag-vlc.sh     # Diagnostic VLC"
        log_info "  - /opt/scripts/diag-network.sh # Diagnostic réseau"
        log_info "  - /opt/scripts/diag-system.sh  # Diagnostic système"
        log_info ""
        log_info "Exemple d'utilisation :"
        log_info "  sudo pi-signage-diag          # Diagnostic complet"
        log_info "  sudo pi-signage-tools         # Menu interactif"
    else
        log_warn "Outils de diagnostic créés avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Création Outils de Diagnostic ==="
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