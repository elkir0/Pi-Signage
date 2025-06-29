#!/usr/bin/env bash

# =============================================================================
# Pi Signage Digital - Orchestrateur Principal v2
# Version: 2.3.0
# Description: Script principal d'installation modulaire avec support Chromium Kiosk
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES GLOBALES
# =============================================================================

readonly SCRIPT_VERSION="2.3.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="/etc/pi-signage"
readonly CONFIG_FILE="$CONFIG_DIR/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly GITHUB_RAW="https://raw.githubusercontent.com/elkir0/Pi-Signage/main"

# Mode d'affichage global
DISPLAY_MODE=""

# Couleurs pour l'affichage
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Modules sélectionnés
selected_modules=()

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${NC} $*"
    echo "$timestamp [INFO] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${NC} $*"
    echo "$timestamp [WARN] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} $*" >&2
    echo "$timestamp [ERROR] $*" >> "$LOG_FILE" 2>/dev/null || true
}

error_exit() {
    log_error "$1"
    exit 1
}

# =============================================================================
# DÉTECTION DU SYSTÈME
# =============================================================================

check_system() {
    log_info "Vérification du système..."
    
    # Vérifier qu'on est root
    if [[ $EUID -ne 0 ]]; then
        error_exit "Ce script doit être exécuté en tant que root (sudo)"
    fi
    
    # Vérifier l'OS
    if [[ ! -f /etc/os-release ]]; then
        error_exit "Système d'exploitation non supporté"
    fi
    
    source /etc/os-release
    if [[ "$ID" != "raspbian" ]] && [[ "$ID" != "debian" ]]; then
        log_warn "Ce script est optimisé pour Raspberry Pi OS"
    fi
    
    # Vérifier l'architecture
    local arch=$(uname -m)
    if [[ "$arch" != "aarch64" ]] && [[ "$arch" != "armv7l" ]]; then
        log_warn "Architecture non standard: $arch"
    fi
    
    # Vérifier l'espace disque
    local free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $free_space -lt 5 ]]; then
        error_exit "Espace disque insuffisant (minimum 5GB requis)"
    fi
    
    log_info "Système vérifié avec succès"
}

# =============================================================================
# DÉTECTION DU MODÈLE DE RASPBERRY PI
# =============================================================================

detect_pi_model() {
    log_info "Détection du modèle de Raspberry Pi..."
    
    local pi_generation=""
    local pi_variant=""
    local model=""
    local revision=""
    
    # Vérifier si on est en mode VM
    if [[ -f /etc/pi-signage/vm-mode.conf ]]; then
        source /etc/pi-signage/vm-mode.conf
        log_warn "Mode VM détecté - Émulation $EMULATED_PI_MODEL"
        
        # Utiliser les valeurs émulées
        pi_generation="$EMULATED_PI_GENERATION"
        pi_variant="$EMULATED_PI_VARIANT"
        model="$EMULATED_PI_MODEL"
        revision="$EMULATED_PI_REVISION"
        
        # Créer la config
        cat > /tmp/pi-model.conf << EOF
PI_MODEL="$model (VM)"
PI_GENERATION="$pi_generation"
PI_VARIANT="$pi_variant"
PI_REVISION="$revision"
EOF
        
        log_info "Configuration VM appliquée: Pi $pi_generation ($pi_variant)"
        return 0
    fi
    
    # Détection normale pour vrai Pi
    if [[ -f /proc/device-tree/model ]]; then
        model=$(tr -d '\0' < /proc/device-tree/model)
        revision=$(cat /proc/cpuinfo | grep Revision | awk '{print $3}')
        
        echo "Modèle détecté: $model"
        echo "Révision: $revision"
        
        # Détection basée sur le modèle
        if [[ "$model" =~ "Raspberry Pi 4" ]]; then
            pi_generation="4"
            case "$revision" in
                *"c03111"*|*"c03112"*) pi_variant="4B-2GB" ;;
                *"c03114"*) pi_variant="4B-4GB" ;;
                *"c03115"*) pi_variant="4B-8GB" ;;
                *) pi_variant="4B" ;;
            esac
            log_info "Raspberry Pi 4 détecté ($pi_variant)"
        elif [[ "$model" =~ "Raspberry Pi 3" ]]; then
            pi_generation="3"
            if [[ "$model" =~ "Plus" ]]; then
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
        # Environnement non-Pi détecté (VM, conteneur, etc.)
        log_warn "Environnement non-Raspberry Pi détecté"
        log_warn "Activation du mode compatibilité VM"
        
        # Créer automatiquement la config VM
        mkdir -p /etc/pi-signage
        cat > /etc/pi-signage/vm-mode.conf << 'EOF'
# Configuration auto-générée pour mode VM/Test
VM_MODE=true
VM_TYPE=auto-detected
VM_ARCH=$(uname -m)
VM_OS="$(uname -s)"
EMULATED_PI_MODEL="Raspberry Pi 4 Model B Rev 1.4"
EMULATED_PI_GENERATION="4"
EMULATED_PI_VARIANT="4B-4GB"
EMULATED_PI_REVISION="c03114"
EOF
        
        # Réappeler la fonction pour charger la config VM
        detect_pi_model
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
        ["03-chromium-kiosk"]="Mode Chromium Kiosk (alternative moderne à VLC)"
        ["04-rclone-setup"]="Synchronisation Google Drive"
        ["05-glances-setup"]="Interface de monitoring web Glances"
        ["06-cron-setup"]="Tâches automatisées (sync, maintenance)"
        ["07-services-setup"]="Services systemd et watchdog"
        ["08-diagnostic-tools"]="Outils de diagnostic et dépannage"
        ["09-web-interface-v2"]="Interface web avec téléchargement YouTube"
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
    echo "2) Installation minimale (Player + sync Google Drive)"
    echo "3) Installation web (Player + interface web, sans Google Drive)"
    echo "4) Sélection personnalisée"
    echo
    
    read -p "Votre choix [1-4]: " install_choice
    
    case $install_choice in
        1)
            # Installation complète - demander le mode d'affichage
            select_display_mode
            
            if [[ $DISPLAY_MODE == "chromium" ]]; then
                selected_modules=(
                    "01-system-config"
                    "03-chromium-kiosk"
                    "04-rclone-setup"
                    "05-glances-setup"
                    "06-cron-setup"
                    "07-services-setup"
                    "08-diagnostic-tools"
                    "09-web-interface-v2"
                )
            else
                selected_modules=(
                    "01-system-config"
                    "02-display-manager"
                    "03-vlc-setup"
                    "04-rclone-setup"
                    "05-glances-setup"
                    "06-cron-setup"
                    "07-services-setup"
                    "08-diagnostic-tools"
                    "09-web-interface-v2"
                )
            fi
            log_info "Installation complète sélectionnée (mode $DISPLAY_MODE)"
            ;;
        2)
            # Installation minimale
            select_display_mode
            
            if [[ $DISPLAY_MODE == "chromium" ]]; then
                selected_modules=(
                    "01-system-config"
                    "03-chromium-kiosk"
                    "04-rclone-setup"
                    "06-cron-setup"
                    "07-services-setup"
                )
            else
                selected_modules=(
                    "01-system-config"
                    "02-display-manager"
                    "03-vlc-setup"
                    "04-rclone-setup"
                    "06-cron-setup"
                    "07-services-setup"
                )
            fi
            log_info "Installation minimale sélectionnée (mode $DISPLAY_MODE)"
            ;;
        3)
            # Installation web
            select_display_mode
            
            if [[ $DISPLAY_MODE == "chromium" ]]; then
                selected_modules=(
                    "01-system-config"
                    "03-chromium-kiosk"
                    "05-glances-setup"
                    "07-services-setup"
                    "08-diagnostic-tools"
                    "09-web-interface-v2"
                )
            else
                selected_modules=(
                    "01-system-config"
                    "02-display-manager"
                    "03-vlc-setup"
                    "05-glances-setup"
                    "07-services-setup"
                    "08-diagnostic-tools"
                    "09-web-interface-v2"
                )
            fi
            log_info "Installation web sélectionnée (mode $DISPLAY_MODE)"
            ;;
        4)
            # Sélection personnalisée
            selected_modules=("01-system-config")  # Toujours inclus
            
            # D'abord demander le mode d'affichage
            echo -e "\n${BLUE}Choisir le mode d'affichage:${NC}"
            echo "1) VLC Classic avec gestionnaire de fenêtres"
            echo "2) Chromium Kiosk (léger et moderne)"
            echo "3) Aucun (serveur headless)"
            read -p "Votre choix [1-3]: " display_choice
            
            case $display_choice in
                1)
                    selected_modules+=("02-display-manager" "03-vlc-setup")
                    DISPLAY_MODE="vlc"
                    ;;
                2)
                    selected_modules+=("03-chromium-kiosk")
                    DISPLAY_MODE="chromium"
                    ;;
                3)
                    DISPLAY_MODE="none"
                    ;;
            esac
            
            # Puis les autres modules
            for module in "${!modules_info[@]}"; do
                if [[ ! " ${essential_modules[@]} " =~ " ${module} " ]] && 
                   [[ ! " ${selected_modules[@]} " =~ " ${module} " ]]; then
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
    echo -e "  • Mode d'affichage: ${YELLOW}$DISPLAY_MODE${NC}"
    echo
    
    read -p "Confirmer la sélection ? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
        select_modules  # Redemander
    fi
}

# =============================================================================
# SÉLECTION DU MODE D'AFFICHAGE
# =============================================================================

select_display_mode() {
    echo -e "\n${BLUE}Choisir le mode d'affichage:${NC}"
    echo
    echo "1) ${YELLOW}VLC Classic${NC}"
    echo "   ✓ Support de tous les formats vidéo"
    echo "   ✓ Stabilité éprouvée 24/7"
    echo "   ✓ Optimisations hardware"
    echo "   ✗ Plus de ressources (~350MB RAM)"
    echo "   ✗ Démarrage plus lent"
    echo
    echo "2) ${CYAN}Chromium Kiosk${NC}"
    echo "   ✓ Démarrage rapide (~25s)"
    echo "   ✓ Moins de RAM (~250MB)"
    echo "   ✓ Support HTML5/CSS/JS"
    echo "   ✓ Overlays et transitions"
    echo "   ✗ Formats limités (H.264/WebM)"
    echo
    
    read -p "Votre choix [1-2]: " display_choice
    
    case $display_choice in
        2)
            DISPLAY_MODE="chromium"
            echo -e "${GREEN}Mode Chromium Kiosk sélectionné${NC}"
            ;;
        *)
            DISPLAY_MODE="vlc"
            echo -e "${GREEN}Mode VLC Classic sélectionné${NC}"
            ;;
    esac
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
    
    # Chromium Kiosk est une alternative à VLC + display manager
    if [[ " ${selected_modules[@]} " =~ " 03-chromium-kiosk " ]] && 
       [[ " ${selected_modules[@]} " =~ " 03-vlc-setup " ]]; then
        log_warn "Chromium Kiosk et VLC sont mutuellement exclusifs"
        log_warn "Utilisation de Chromium Kiosk uniquement"
        selected_modules=("${selected_modules[@]/03-vlc-setup}")
        selected_modules=("${selected_modules[@]/02-display-manager}")
    fi
    
    # L'interface web s'adapte au mode choisi
    if [[ " ${selected_modules[@]} " =~ " 09-web-interface-v2 " ]]; then
        if [[ ! " ${selected_modules[@]} " =~ " 03-vlc-setup " ]] && 
           [[ ! " ${selected_modules[@]} " =~ " 03-chromium-kiosk " ]]; then
            log_warn "L'interface web nécessite un mode d'affichage"
            if [[ $DISPLAY_MODE == "chromium" ]]; then
                selected_modules+=("03-chromium-kiosk")
            else
                selected_modules+=("02-display-manager" "03-vlc-setup")
            fi
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
        "03-chromium-kiosk"
        "04-rclone-setup"
        "05-glances-setup"
        "06-cron-setup"
        "07-services-setup"
        "08-diagnostic-tools"
        "09-web-interface-v2"
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
    
    # Charger les fonctions de sécurité
    if [[ -f "$SCRIPT_DIR/00-security-utils.sh" ]]; then
        source "$SCRIPT_DIR/00-security-utils.sh"
    else
        log_error "Module de sécurité manquant, utilisation de fonctions basiques"
        # Fonctions fallback
        encrypt_password() { echo -n "$1" | base64; }
        hash_password() { echo -n "$1" | sha256sum | cut -d' ' -f1; }
        validate_username() { [[ "$1" =~ ^[a-zA-Z0-9_]{3,32}$ ]]; }
    fi
    
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
        # Chiffrer le mot de passe immédiatement
        GLANCES_PASSWORD_ENCRYPTED=$(encrypt_password "$GLANCES_PASSWORD")
        # Ne plus garder le mot de passe en clair en mémoire
        GLANCES_PASSWORD=""
    else
        GLANCES_PASSWORD_ENCRYPTED=""
    fi
    
    # Configuration Interface Web (si le module est sélectionné)
    if [[ " ${selected_modules[@]} " =~ " 09-web-interface-v2 " ]]; then
        echo -e "\n${BLUE}Configuration Interface Web${NC}"
        read -rp "Nom d'utilisateur administrateur web [admin]: " WEB_ADMIN_USER
        WEB_ADMIN_USER=${WEB_ADMIN_USER:-admin}
        
        # Valider le nom d'utilisateur
        if ! validate_username "$WEB_ADMIN_USER"; then
            echo -e "${RED}Nom d'utilisateur invalide (3-32 caractères, alphanumériques uniquement)${NC}"
            WEB_ADMIN_USER="admin"
        fi
        
        read -rsp "Mot de passe administrateur web: " WEB_ADMIN_PASSWORD
        echo
        while [[ ${#WEB_ADMIN_PASSWORD} -lt 8 ]]; do
            echo -e "${RED}Le mot de passe doit contenir au moins 8 caractères${NC}"
            read -rsp "Mot de passe administrateur web: " WEB_ADMIN_PASSWORD
            echo
        done
        # Hacher le mot de passe immédiatement
        WEB_ADMIN_PASSWORD_HASH=$(hash_password "$WEB_ADMIN_PASSWORD")
        # Ne plus garder le mot de passe en clair
        WEB_ADMIN_PASSWORD=""
    else
        WEB_ADMIN_USER=""
        WEB_ADMIN_PASSWORD_HASH=""
    fi
    
    # Hostname (toujours demandé)
    read -rp "Nom d'hôte pour ce Pi [pi-signage]: " NEW_HOSTNAME
    NEW_HOSTNAME=${NEW_HOSTNAME:-pi-signage}
    
    # Sauvegarde de la configuration
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
# Configuration Pi Signage
# Version: $SCRIPT_VERSION
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# ATTENTION: Ce fichier contient des données sensibles chiffrées

GDRIVE_FOLDER="$GDRIVE_FOLDER"
GLANCES_PASSWORD_ENCRYPTED="$GLANCES_PASSWORD_ENCRYPTED"
WEB_ADMIN_USER="$WEB_ADMIN_USER"
WEB_ADMIN_PASSWORD_HASH="$WEB_ADMIN_PASSWORD_HASH"
VIDEO_DIR="/opt/videos"
NEW_HOSTNAME="$NEW_HOSTNAME"
SCRIPT_VERSION="$SCRIPT_VERSION"
INSTALL_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
INSTALLED_MODULES="${selected_modules[*]}"
DISPLAY_MODE="${DISPLAY_MODE:-vlc}"
EOF
    
    # Appliquer des permissions strictes
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
    
    # Vérification des services selon le mode d'affichage
    if [[ $DISPLAY_MODE == "chromium" ]]; then
        if systemctl is-enabled "chromium-kiosk" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Service chromium-kiosk activé"
        else
            echo -e "${RED}✗${NC} Service chromium-kiosk non activé"
            ((errors++))
        fi
    else
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
    fi
    
    if [[ " ${selected_modules[@]} " =~ " 05-glances-setup " ]]; then
        if systemctl is-enabled "glances" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Service glances activé"
        else
            echo -e "${RED}✗${NC} Service glances non activé"
            ((errors++))
        fi
    fi
    
    # Afficher le mode d'affichage utilisé
    echo -e "\n${BLUE}Mode d'affichage: ${YELLOW}$DISPLAY_MODE${NC}"
    
    # Recommandations spécifiques au mode
    if [[ $DISPLAY_MODE == "chromium" ]]; then
        echo -e "\n${CYAN}Recommandations pour Chromium Kiosk:${NC}"
        echo "• Utilisez des vidéos H.264 ou WebM pour une meilleure compatibilité"
        echo "• Le player HTML5 est accessible sur http://localhost:8888/player.html"
        echo "• Contrôle: /opt/scripts/player-control.sh {play|pause|next|...}"
    fi
    
    return $errors
}

# =============================================================================
# AFFICHAGE DE LA BANNIÈRE
# =============================================================================

show_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║         📺 Pi Signage Digital Installer v$SCRIPT_VERSION 📺         ║"
    echo "║                                                              ║"
    echo "║            Installation modulaire pour Raspberry Pi           ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo -e "${CYAN}Projet GitHub:${NC} https://github.com/elkir0/Pi-Signage"
    echo -e "${CYAN}Documentation:${NC} https://github.com/elkir0/Pi-Signage/wiki"
    echo
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    # Préparation
    mkdir -p "$(dirname "$LOG_FILE")"
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    # Affichage de la bannière
    show_banner
    
    # Vérifications système
    check_system
    detect_pi_model
    
    # Sélection des modules
    select_modules
    
    # Configuration utilisateur
    collect_configuration
    
    # Téléchargement/préparation des scripts
    download_scripts
    
    # Installation
    echo -e "\n${YELLOW}L'installation va commencer. Cela peut prendre 30 à 60 minutes.${NC}"
    echo "Vous pouvez suivre la progression dans: $LOG_FILE"
    echo
    read -p "Appuyez sur [Entrée] pour commencer l'installation..."
    
    if main_installation; then
        validate_installation
        
        echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║            Installation terminée avec succès! 🎉             ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${CYAN}Prochaines étapes:${NC}"
        echo "1. Redémarrer le système: sudo reboot"
        echo "2. Accéder à l'interface web: http://$(hostname -I | awk '{print $1}')/"
        echo "3. Ajouter des vidéos dans /opt/videos/"
        echo
        echo -e "${YELLOW}Mode d'affichage: $DISPLAY_MODE${NC}"
        
        if [[ $DISPLAY_MODE == "chromium" ]]; then
            echo -e "${CYAN}Player Chromium: http://localhost:8888/player.html${NC}"
        fi
    else
        echo -e "\n${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║          Installation terminée avec des erreurs              ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo "Consultez les logs pour plus de détails: $LOG_FILE"
    fi
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

main "$@"