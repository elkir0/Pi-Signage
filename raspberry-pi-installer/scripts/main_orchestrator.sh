#!/usr/bin/env bash

# =============================================================================
# Digital Signage - Script Principal (Orchestrateur)
# Version: 2.1.0
# Compatible avec: Raspberry Pi OS Lite (32/64-bit), Raspberry Pi 3B+/4
# Mise à jour: Ajout du module web et sélection interactive des modules
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# CONSTANTES
# =============================================================================

readonly SCRIPT_VERSION="2.1.0"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly SCRIPTS_DIR="/tmp/pi-signage-scripts"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# =============================================================================
# LOGGING
# =============================================================================

init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/pi-signage-setup.log"
    chmod 644 "$LOG_FILE" 2>/dev/null || true
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
}

log_info() {
    log "INFO" "$@"
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    log "WARN" "$@"
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    log "ERROR" "$@"
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# =============================================================================
# CONTRÔLES PRÉLIMINAIRES
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "Ce script doit être exécuté en tant que root. Utilisez: sudo $0"
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "OS détecté: $PRETTY_NAME"
        
        # Vérifier si c'est bien un Raspberry Pi OS
        if [[ ! "$ID" =~ ^(raspbian|debian)$ ]]; then
            log_warn "OS non testé détecté. Continuez à vos risques et périls."
        fi
    else
        log_warn "Impossible de détecter la version de l'OS"
    fi
}

check_internet() {
    log_info "Vérification de la connexion internet..."
    if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        error_exit "Pas de connexion internet. Vérifiez votre réseau."
    fi
    log_info "Connexion internet OK"
}

detect_pi_model() {
    local model revision
    
    if [[ -f /proc/cpuinfo ]]; then
        model=$(grep "Model" /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | xargs || echo "Unknown")
        revision=$(grep "Revision" /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | xargs || echo "Unknown")
        
        log_info "Modèle détecté: $model (Revision: $revision)"
        
        # Détection précise du modèle pour optimisations
        local pi_generation=""
        local pi_variant=""
        
        if [[ "$model" =~ "Raspberry Pi 4" ]]; then
            pi_generation="4"
            if [[ "$model" =~ "8GB" ]]; then
                pi_variant="8GB"
            elif [[ "$model" =~ "4GB" ]]; then
                pi_variant="4GB"
            elif [[ "$model" =~ "2GB" ]]; then
                pi_variant="2GB"
            else
                pi_variant="4GB"  # Default pour Pi 4
            fi
            log_info "Raspberry Pi 4 détecté ($pi_variant)"
        elif [[ "$model" =~ "Raspberry Pi 3" ]]; then
            pi_generation="3"
            if [[ "$model" =~ "Model B Plus" ]] || [[ "$model" =~ "3B+" ]]; then
                pi_variant="3B+"
            else
                pi_variant="3B"
            fi
            log_info "Raspberry Pi 3 détecté ($pi_variant)"
        elif [[ "$model" =~ "Raspberry Pi 5" ]]; then
            pi_generation="5"
            pi_variant="5"
            log_info "Raspberry Pi 5 détecté (support expérimental)"
        else
            pi_generation="3"  # Fallback conservateur
            pi_variant="unknown"
            log_warn "Modèle Pi non reconnu, utilisation des paramètres Pi 3"
        fi
        
        # Stockage des informations pour les autres scripts
        cat > /tmp/pi-model.conf << EOF
PI_MODEL="$model"
PI_GENERATION="$pi_generation"
PI_VARIANT="$pi_variant"
PI_REVISION="$revision"
EOF
        
    else
        error_exit "Impossible de détecter le modèle de Raspberry Pi"
    fi
}

# =============================================================================
# SÉLECTION DES MODULES
# =============================================================================

select_modules() {
    echo -e "\n${CYAN}=== Sélection des Modules d'Installation ===${NC}"
    echo "Choisissez les modules à installer :"
    echo
    
    # Définition des modules disponibles avec descriptions
    declare -A modules_info=(
        ["01-system-config"]="Configuration système de base (recommandé)"
        ["02-display-manager"]="Gestionnaire d'affichage X11/LightDM (requis pour VLC)"
        ["03-vlc-setup"]="Lecteur vidéo VLC en mode kiosque"
        ["04-rclone-setup"]="Synchronisation Google Drive"
        ["05-glances-setup"]="Interface de monitoring web Glances"
        ["06-cron-setup"]="Tâches automatisées (sync, maintenance)"
        ["07-services-setup"]="Services systemd et watchdog"
        ["08-diagnostic-tools"]="Outils de diagnostic et dépannage"
        ["09-web-interface"]="Interface web avec téléchargement YouTube"
    )
    
    # Modules essentiels toujours installés
    local essential_modules=("01-system-config")
    
    # Affichage des options
    echo -e "${YELLOW}Modules essentiels (toujours installés):${NC}"
    for module in "${essential_modules[@]}"; do
        echo "  ✓ $module - ${modules_info[$module]}"
    done
    
    echo -e "\n${BLUE}Modules optionnels:${NC}"
    echo "1) Installation complète (tous les modules) - ${GREEN}RECOMMANDÉ${NC}"
    echo "2) Installation minimale (VLC + sync Google Drive uniquement)"
    echo "3) Installation web (VLC + interface web, sans Google Drive)"
    echo "4) Sélection personnalisée"
    echo
    
    read -p "Votre choix [1-4]: " install_choice
    
    case $install_choice in
        1)
            # Installation complète
            selected_modules=(
                "01-system-config"
                "02-display-manager"
                "03-vlc-setup"
                "04-rclone-setup"
                "05-glances-setup"
                "06-cron-setup"
                "07-services-setup"
                "08-diagnostic-tools"
                "09-web-interface"
            )
            log_info "Installation complète sélectionnée"
            ;;
        2)
            # Installation minimale
            selected_modules=(
                "01-system-config"
                "02-display-manager"
                "03-vlc-setup"
                "04-rclone-setup"
                "06-cron-setup"
                "07-services-setup"
            )
            log_info "Installation minimale sélectionnée"
            ;;
        3)
            # Installation web
            selected_modules=(
                "01-system-config"
                "02-display-manager"
                "03-vlc-setup"
                "05-glances-setup"
                "07-services-setup"
                "08-diagnostic-tools"
                "09-web-interface"
            )
            log_info "Installation web sélectionnée"
            ;;
        4)
            # Sélection personnalisée
            selected_modules=("01-system-config")  # Toujours inclus
            
            for module in "${!modules_info[@]}"; do
                if [[ ! " ${essential_modules[@]} " =~ " ${module} " ]]; then
                    read -p "Installer $module - ${modules_info[$module]} ? (y/N) " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        selected_modules+=("$module")
                    fi
                fi
            done
            ;;
        *)
            log_error "Choix invalide"
            select_modules  # Redemander
            return
            ;;
    esac
    
    # Vérification des dépendances
    check_module_dependencies
    
    # Afficher le résumé
    echo -e "\n${GREEN}Modules sélectionnés pour l'installation:${NC}"
    for module in "${selected_modules[@]}"; do
        echo "  • $module - ${modules_info[$module]}"
    done
    echo
    
    read -p "Confirmer la sélection ? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
        select_modules  # Redemander
    fi
}

# =============================================================================
# VÉRIFICATION DES DÉPENDANCES ENTRE MODULES
# =============================================================================

check_module_dependencies() {
    # VLC nécessite le display manager
    if [[ " ${selected_modules[@]} " =~ " 03-vlc-setup " ]] && 
       [[ ! " ${selected_modules[@]} " =~ " 02-display-manager " ]]; then
        log_warn "VLC nécessite le gestionnaire d'affichage, ajout automatique..."
        selected_modules+=("02-display-manager")
    fi
    
    # L'interface web nécessite certains modules
    if [[ " ${selected_modules[@]} " =~ " 09-web-interface " ]]; then
        if [[ ! " ${selected_modules[@]} " =~ " 03-vlc-setup " ]]; then
            log_warn "L'interface web nécessite VLC, ajout automatique..."
            selected_modules+=("02-display-manager" "03-vlc-setup")
        fi
    fi
    
    # Les crons nécessitent les services
    if [[ " ${selected_modules[@]} " =~ " 06-cron-setup " ]] && 
       [[ ! " ${selected_modules[@]} " =~ " 07-services-setup " ]]; then
        selected_modules+=("07-services-setup")
    fi
    
    # Trier les modules dans l'ordre correct
    local ordered_modules=()
    local module_order=(
        "01-system-config"
        "02-display-manager"
        "03-vlc-setup"
        "04-rclone-setup"
        "05-glances-setup"
        "06-cron-setup"
        "07-services-setup"
        "08-diagnostic-tools"
        "09-web-interface"
    )
    
    for module in "${module_order[@]}"; do
        if [[ " ${selected_modules[@]} " =~ " ${module} " ]]; then
            ordered_modules+=("$module")
        fi
    done
    
    selected_modules=("${ordered_modules[@]}")
}

# =============================================================================
# CONFIGURATION UTILISATEUR
# =============================================================================

collect_configuration() {
    echo -e "\n${BLUE}=== Configuration Digital Signage ===${NC}"
    echo "Veuillez fournir les informations suivantes :"
    echo
    
    # Configuration Google Drive (si le module est sélectionné)
    if [[ " ${selected_modules[@]} " =~ " 04-rclone-setup " ]]; then
        echo -e "${BLUE}Configuration Google Drive${NC}"
        echo "Vous authentifierez Google Drive plus tard dans l'installation"
        read -rp "Nom du dossier Google Drive pour les vidéos [Signage]: " GDRIVE_FOLDER
        GDRIVE_FOLDER=${GDRIVE_FOLDER:-Signage}
    else
        GDRIVE_FOLDER="Non configuré"
    fi
    
    # Configuration Glances (si le module est sélectionné)
    if [[ " ${selected_modules[@]} " =~ " 05-glances-setup " ]]; then
        echo -e "\n${BLUE}Configuration Monitoring${NC}"
        read -rsp "Mot de passe pour l'interface web Glances: " GLANCES_PASSWORD
        echo
        while [[ ${#GLANCES_PASSWORD} -lt 6 ]]; do
            echo -e "${RED}Le mot de passe doit contenir au moins 6 caractères${NC}"
            read -rsp "Mot de passe Glances: " GLANCES_PASSWORD
            echo
        done
    else
        GLANCES_PASSWORD=""
    fi
    
    # Configuration Interface Web (si le module est sélectionné)
    if [[ " ${selected_modules[@]} " =~ " 09-web-interface " ]]; then
        echo -e "\n${BLUE}Configuration Interface Web${NC}"
        read -rp "Nom d'utilisateur administrateur web [admin]: " WEB_ADMIN_USER
        WEB_ADMIN_USER=${WEB_ADMIN_USER:-admin}
        
        read -rsp "Mot de passe administrateur web: " WEB_ADMIN_PASSWORD
        echo
        while [[ ${#WEB_ADMIN_PASSWORD} -lt 6 ]]; do
            echo -e "${RED}Le mot de passe doit contenir au moins 6 caractères${NC}"
            read -rsp "Mot de passe administrateur web: " WEB_ADMIN_PASSWORD
            echo
        done
    else
        WEB_ADMIN_USER=""
        WEB_ADMIN_PASSWORD=""
    fi
    
    # Hostname (toujours demandé)
    read -rp "Nom d'hôte pour ce Pi [pi-signage]: " NEW_HOSTNAME
    NEW_HOSTNAME=${NEW_HOSTNAME:-pi-signage}
    
    # Sauvegarde de la configuration
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
# Configuration Pi Signage
GDRIVE_FOLDER="$GDRIVE_FOLDER"
GLANCES_PASSWORD="$GLANCES_PASSWORD"
WEB_ADMIN_USER="$WEB_ADMIN_USER"
WEB_ADMIN_PASSWORD="$WEB_ADMIN_PASSWORD"
VIDEO_DIR="/opt/videos"
NEW_HOSTNAME="$NEW_HOSTNAME"
SCRIPT_VERSION="$SCRIPT_VERSION"
INSTALL_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
INSTALLED_MODULES="${selected_modules[*]}"
EOF
    chmod 600 "$CONFIG_FILE"
    
    log_info "Configuration sauvegardée dans $CONFIG_FILE"
}

# =============================================================================
# TÉLÉCHARGEMENT DES SCRIPTS MODULAIRES
# =============================================================================

download_scripts() {
    log_info "Préparation des scripts modulaires..."
    
    mkdir -p "$SCRIPTS_DIR"
    cd "$SCRIPTS_DIR"
    
    # Note: Dans un vrai déploiement, ces scripts seraient téléchargés depuis un repo
    # Pour cette démonstration, nous créons les scripts localement
    
    echo "Scripts modulaires prêts dans $SCRIPTS_DIR"
}

# =============================================================================
# EXÉCUTION DES MODULES
# =============================================================================

execute_module() {
    local module_name="$1"
    local script_path="$SCRIPTS_DIR/${module_name}.sh"
    
    log_info "Exécution du module: $module_name"
    
    if [[ -f "$script_path" ]]; then
        chmod +x "$script_path"
        if bash "$script_path"; then
            log_info "Module $module_name installé avec succès"
            return 0
        else
            log_error "Échec du module $module_name"
            return 1
        fi
    else
        log_error "Script $script_path introuvable"
        return 1
    fi
}

# =============================================================================
# INSTALLATION PRINCIPALE
# =============================================================================

main_installation() {
    log_info "Début de l'installation modulaire..."
    
    local failed_modules=()
    
    for module in "${selected_modules[@]}"; do
        if ! execute_module "$module"; then
            failed_modules+=("$module")
            log_error "Échec du module: $module"
            
            # Demander si on continue ou si on arrête
            echo -e "\n${YELLOW}Le module $module a échoué.${NC}"
            read -p "Voulez-vous continuer l'installation ? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                error_exit "Installation interrompue par l'utilisateur"
            fi
        fi
    done
    
    # Rapport des modules échoués
    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        log_warn "Modules ayant échoué: ${failed_modules[*]}"
        return 1
    fi
    
    return 0
}

# =============================================================================
# VALIDATION FINALE
# =============================================================================

validate_installation() {
    log_info "Validation de l'installation..."
    
    local errors=0
    
    echo -e "\n${BLUE}=== Validation du Système ===${NC}"
    
    # Vérification des services critiques selon les modules installés
    if [[ " ${selected_modules[@]} " =~ " 02-display-manager " ]]; then
        if systemctl is-enabled "lightdm" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Service lightdm activé"
        else
            echo -e "${RED}✗${NC} Service lightdm non activé"
            ((errors++))
        fi
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 03-vlc-setup " ]]; then
        if systemctl is-enabled "vlc-signage" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Service vlc-signage activé"
        else
            echo -e "${RED}✗${NC} Service vlc-signage non activé"
            ((errors++))
        fi
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 05-glances-setup " ]]; then
        if systemctl is-enabled "glances" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Service glances activé"
        else
            echo -e "${RED}✗${NC} Service glances non activé"
            ((errors++))
        fi
    fi
    
    # Vérification des exécutables
    if [[ " ${selected_modules[@]} " =~ " 03-vlc-setup " ]] && command -v "vlc" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Commande vlc disponible"
    elif [[ " ${selected_modules[@]} " =~ " 03-vlc-setup " ]]; then
        echo -e "${RED}✗${NC} Commande vlc manquante"
        ((errors++))
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 04-rclone-setup " ]] && command -v "rclone" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Commande rclone disponible"
    elif [[ " ${selected_modules[@]} " =~ " 04-rclone-setup " ]]; then
        echo -e "${RED}✗${NC} Commande rclone manquante"
        ((errors++))
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 09-web-interface " ]] && command -v "yt-dlp" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Commande yt-dlp disponible"
    elif [[ " ${selected_modules[@]} " =~ " 09-web-interface " ]]; then
        echo -e "${RED}✗${NC} Commande yt-dlp manquante"
        ((errors++))
    fi
    
    # Vérification des répertoires
    if [[ -d "/opt/videos" ]]; then
        echo -e "${GREEN}✓${NC} Répertoire vidéos créé"
    else
        echo -e "${RED}✗${NC} Répertoire vidéos manquant"
        ((errors++))
    fi
    
    echo -e "\nValidation terminée: $errors erreur(s)"
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    # Initialisation
    init_logging
    clear
    
    # Bannière
    cat << 'EOF'
    ____  _    ____  _                              
   |  _ \(_)  / ___|(_) __ _ _ __   __ _  __ _  ___ 
   | |_) | |  \___ \| |/ _` | '_ \ / _` |/ _` |/ _ \
   |  __/| |   ___) | | (_| | | | | (_| | (_| |  __/
   |_|   |_|  |____/|_|\__, |_| |_|\__,_|\__, |\___|
                       |___/             |___/      

EOF
    
    echo "  Digital Signage Setup - Version Modulaire"
    echo "  Version: $SCRIPT_VERSION"
    echo "  Compatible: Raspberry Pi 3B+, 4B, 5 (expérimental)"
    echo "  Architecture: Scripts séparés, installation flexible"
    echo "======================================================"
    echo
    
    log_info "Démarrage de l'installation Digital Signage v$SCRIPT_VERSION"
    
    # Contrôles préliminaires
    check_root
    check_os
    detect_pi_model
    check_internet
    
    # Sélection des modules
    select_modules
    
    # Configuration utilisateur
    collect_configuration
    
    # Téléchargement des scripts modulaires
    download_scripts
    
    # Installation modulaire
    if main_installation; then
        log_info "Installation modulaire terminée avec succès"
    else
        log_warn "Installation modulaire terminée avec des avertissements"
    fi
    
    # Configuration interactive rclone (si installé)
    if [[ " ${selected_modules[@]} " =~ " 04-rclone-setup " ]]; then
        echo -e "\n${YELLOW}=== Configuration Manuelle Requise ===${NC}"
        echo "Configuration de l'accès Google Drive nécessaire."
        echo "Cette étape nécessite une authentification manuelle."
        echo
        read -p "Appuyez sur Entrée pour continuer avec la configuration Google Drive..."
        
        # Exécution de la configuration rclone
        if command -v rclone >/dev/null 2>&1; then
            rclone config
        else
            log_warn "rclone non installé, configuration manuelle requise"
        fi
    fi
    
    # Validation finale
    if validate_installation; then
        show_success_message
    else
        show_warning_message
    fi
    
    # Proposition de redémarrage
    echo
    read -p "Voulez-vous redémarrer maintenant ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Redémarrage du système..."
        sync
        reboot
    fi
}

# =============================================================================
# MESSAGES FINAUX
# =============================================================================

show_success_message() {
    source "$CONFIG_FILE"
    local ip_addr
    ip_addr=$(hostname -I | awk '{print $1}')
    
    echo -e "\n${GREEN}=== Installation Terminée avec Succès ! ===${NC}"
    echo
    echo "Informations Système:"
    echo "  • Nom d'hôte: $NEW_HOSTNAME"
    echo "  • Adresse IP: $ip_addr"
    echo "  • Répertoire vidéos: /opt/videos"
    
    # Afficher les informations selon les modules installés
    if [[ " ${selected_modules[@]} " =~ " 04-rclone-setup " ]]; then
        echo "  • Dossier Google Drive: $GDRIVE_FOLDER"
    fi
    
    echo
    echo "Services installés:"
    
    if [[ " ${selected_modules[@]} " =~ " 03-vlc-setup " ]]; then
        echo "  • VLC: Démarrage automatique au boot"
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 05-glances-setup " ]]; then
        echo "  • Glances: http://${ip_addr}:61208"
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 09-web-interface " ]]; then
        echo "  • Interface Web: http://${ip_addr}/"
        echo "    - Utilisateur: $WEB_ADMIN_USER"
        echo "    - Téléchargement YouTube disponible"
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 06-cron-setup " ]]; then
        echo "  • Synchronisation: Toutes les 6 heures"
    fi
    
    echo
    echo "Prochaines Étapes:"
    
    if [[ " ${selected_modules[@]} " =~ " 09-web-interface " ]]; then
        echo "  1. Connectez-vous à l'interface web: http://${ip_addr}/"
        echo "  2. Téléchargez vos vidéos YouTube directement"
    elif [[ " ${selected_modules[@]} " =~ " 04-rclone-setup " ]]; then
        echo "  1. Ajoutez des vidéos dans le dossier Google Drive: $GDRIVE_FOLDER"
        echo "  2. Les vidéos se synchroniseront automatiquement"
    else
        echo "  1. Ajoutez des vidéos dans /opt/videos"
    fi
    
    echo "  3. Redémarrez pour démarrer: sudo reboot"
    
    echo
    echo "Commandes Utiles:"
    
    if [[ " ${selected_modules[@]} " =~ " 08-diagnostic-tools " ]]; then
        echo "  • Diagnostic: sudo /opt/pi-signage-diag.sh"
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 04-rclone-setup " ]]; then
        echo "  • Sync manuel: sudo /opt/sync-videos.sh"
        echo "  • Reconfigurer Drive: sudo rclone config"
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 03-vlc-setup " ]]; then
        echo "  • Logs VLC: sudo journalctl -u vlc-signage -f"
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 09-web-interface " ]]; then
        echo "  • Mise à jour yt-dlp: sudo yt-dlp -U"
    fi
}

show_warning_message() {
    echo -e "\n${YELLOW}=== Installation Terminée avec des Problèmes ===${NC}"
    echo "Consultez le fichier de log: $LOG_FILE"
    
    if [[ " ${selected_modules[@]} " =~ " 08-diagnostic-tools " ]]; then
        echo "Exécutez le diagnostic: sudo /opt/pi-signage-diag.sh"
    fi
}

# =============================================================================
# EXÉCUTION DU SCRIPT
# =============================================================================

# Variables globales pour les modules sélectionnés
declare -a selected_modules

main "$@"