#!/bin/bash

# PiSignage v0.9.0 - Système de Déploiement Automatisé One-Click
# Spécialement conçu pour Raspberry Pi OS Bullseye (32-bit)
# Auteur: Claude DevOps Expert
# Date: 22/09/2025

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration globale
export PI_IP="192.168.1.103"
export PI_USER="pi"
export PI_PASS="raspberry"
export PROJECT_NAME="PiSignage"
export VERSION="0.9.0"
export DEPLOYMENT_DIR="/opt/pisignage"
export BACKUP_DIR="/opt/pisignage-backup-$(date +%Y%m%d-%H%M%S)"
export LOG_FILE="/tmp/pisignage-deploy-$(date +%Y%m%d-%H%M%S).log"

# Variables de contrôle
SKIP_BACKUPS=false
FORCE_INSTALL=false
DRY_RUN=false
VERBOSE=false

# Fonction de logging
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "DEBUG")
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} $message" | tee -a "$LOG_FILE"
            fi
            ;;
    esac
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Fonction d'aide
show_help() {
    cat << EOF
PiSignage v0.9.0 - Système de Déploiement Automatisé

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    deploy          Déploiement complet (défaut)
    verify          Vérifications pré-déploiement uniquement
    install         Installation packages uniquement
    configure       Configuration système uniquement
    test            Tests post-déploiement uniquement
    rollback        Rollback vers sauvegarde précédente
    monitor         Monitoring continu post-déploiement

OPTIONS:
    -h, --help         Afficher cette aide
    -v, --verbose      Mode verbeux
    -d, --dry-run      Simulation sans modifications
    -f, --force        Forcer l'installation même si déjà présente
    -s, --skip-backup  Ignorer les sauvegardes
    --ip IP            IP du Raspberry Pi (défaut: 192.168.1.103)
    --user USER        Utilisateur SSH (défaut: pi)
    --pass PASS        Mot de passe SSH (défaut: raspberry)

EXEMPLES:
    $0                                    # Déploiement standard
    $0 --verbose deploy                   # Déploiement avec logs détaillés
    $0 --dry-run verify                   # Simulation vérifications
    $0 --ip 192.168.1.104 deploy         # IP personnalisée
    $0 rollback                           # Rollback automatique

ÉTAPES DU DÉPLOIEMENT:
    1. Vérifications pré-déploiement
    2. Sauvegarde système existant
    3. Installation packages requis
    4. Configuration système complète
    5. Déploiement application
    6. Tests automatiques
    7. Validation finale

REQUIREMENTS:
    - sshpass installé localement
    - Raspberry Pi accessible en SSH
    - Connexion Internet sur le Pi
    - Au moins 2GB d'espace libre

EOF
}

# Fonction de vérification des prérequis locaux
check_local_requirements() {
    log "INFO" "Vérification des prérequis locaux..."

    # Vérifier sshpass
    if ! command -v sshpass &> /dev/null; then
        log "ERROR" "sshpass n'est pas installé. Installation requise:"
        log "INFO" "  sudo apt-get install sshpass"
        return 1
    fi

    # Vérifier que nous sommes dans le bon répertoire
    if [[ ! -f "./VERSION" ]] || [[ ! -d "./web" ]]; then
        log "ERROR" "Script doit être exécuté depuis le répertoire PiSignage (/opt/pisignage)"
        return 1
    fi

    # Vérifier la version
    local current_version=$(cat ./VERSION 2>/dev/null | tr -d '\n\r ')
    if [[ "$current_version" != "$VERSION" ]]; then
        log "WARN" "Version détectée: $current_version, attendue: $VERSION"
    fi

    log "INFO" "Prérequis locaux OK"
    return 0
}

# Fonction de test de connexion SSH
test_ssh_connection() {
    log "INFO" "Test de connexion SSH vers $PI_USER@$PI_IP..."

    if sshpass -p "$PI_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$PI_USER@$PI_IP" "echo 'SSH OK'" &>/dev/null; then
        log "INFO" "Connexion SSH réussie"
        return 0
    else
        log "ERROR" "Impossible de se connecter en SSH"
        log "INFO" "Vérifiez:"
        log "INFO" "  - IP: $PI_IP"
        log "INFO" "  - Utilisateur: $PI_USER"
        log "INFO" "  - Mot de passe: $PI_PASS"
        log "INFO" "  - SSH activé sur le Pi"
        return 1
    fi
}

# Fonction d'exécution de commande SSH avec gestion d'erreurs
ssh_exec() {
    local command="$1"
    local description="$2"

    log "DEBUG" "SSH EXEC: $description"
    log "DEBUG" "COMMAND: $command"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] $description"
        return 0
    fi

    local output
    local exit_code

    output=$(sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no "$PI_USER@$PI_IP" "$command" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log "DEBUG" "SUCCESS: $description"
        if [[ "$VERBOSE" == "true" && -n "$output" ]]; then
            echo "$output"
        fi
        return 0
    else
        log "ERROR" "ÉCHEC: $description"
        log "ERROR" "Code de sortie: $exit_code"
        log "ERROR" "Output: $output"
        return $exit_code
    fi
}

# Fonction de copie de fichiers via SCP avec gestion d'erreurs
scp_copy() {
    local local_path="$1"
    local remote_path="$2"
    local description="$3"

    log "DEBUG" "SCP COPY: $description"
    log "DEBUG" "FROM: $local_path TO: $PI_USER@$PI_IP:$remote_path"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] $description"
        return 0
    fi

    if sshpass -p "$PI_PASS" scp -o StrictHostKeyChecking=no -r "$local_path" "$PI_USER@$PI_IP:$remote_path" &>/dev/null; then
        log "DEBUG" "SUCCESS: $description"
        return 0
    else
        log "ERROR" "ÉCHEC: $description"
        return 1
    fi
}

# Fonction de vérifications pré-déploiement sur le Pi
run_pre_deployment_checks() {
    log "INFO" "Exécution des vérifications pré-déploiement..."

    # Exécuter le script de vérifications
    if ! ssh_exec "./deployment/scripts/pre-checks.sh" "Vérifications système Pi"; then
        log "ERROR" "Échec des vérifications pré-déploiement"
        return 1
    fi

    log "INFO" "Vérifications pré-déploiement réussies"
    return 0
}

# Fonction de sauvegarde du système existant
create_system_backup() {
    if [[ "$SKIP_BACKUPS" == "true" ]]; then
        log "INFO" "Sauvegardes ignorées (--skip-backup)"
        return 0
    fi

    log "INFO" "Création de la sauvegarde système..."

    if ! ssh_exec "./deployment/scripts/backup-system.sh" "Sauvegarde système"; then
        log "ERROR" "Échec de la sauvegarde système"
        return 1
    fi

    log "INFO" "Sauvegarde système créée avec succès"
    return 0
}

# Fonction d'installation des packages
install_system_packages() {
    log "INFO" "Installation des packages système..."

    if ! ssh_exec "./deployment/scripts/install-packages.sh" "Installation packages"; then
        log "ERROR" "Échec de l'installation des packages"
        return 1
    fi

    log "INFO" "Installation des packages terminée"
    return 0
}

# Fonction de configuration système
configure_system() {
    log "INFO" "Configuration du système..."

    if ! ssh_exec "./deployment/scripts/configure-system.sh" "Configuration système"; then
        log "ERROR" "Échec de la configuration système"
        return 1
    fi

    log "INFO" "Configuration système terminée"
    return 0
}

# Fonction de déploiement de l'application
deploy_application() {
    log "INFO" "Déploiement de l'application PiSignage..."

    if ! ssh_exec "./deployment/scripts/deploy-app.sh" "Déploiement application"; then
        log "ERROR" "Échec du déploiement de l'application"
        return 1
    fi

    log "INFO" "Déploiement de l'application terminé"
    return 0
}

# Fonction de tests post-déploiement
run_post_deployment_tests() {
    log "INFO" "Exécution des tests post-déploiement..."

    if ! ssh_exec "./deployment/scripts/post-tests.sh" "Tests post-déploiement"; then
        log "ERROR" "Échec des tests post-déploiement"
        return 1
    fi

    log "INFO" "Tests post-déploiement réussis"
    return 0
}

# Fonction de déploiement complet
deploy_complete() {
    log "INFO" "========================================"
    log "INFO" "DÉBUT DU DÉPLOIEMENT PISIGNAGE v$VERSION"
    log "INFO" "========================================"

    # 1. Vérifications locales
    if ! check_local_requirements; then
        return 1
    fi

    # 2. Test connexion SSH
    if ! test_ssh_connection; then
        return 1
    fi

    # 3. Copier les scripts de déploiement
    log "INFO" "Copie des scripts de déploiement..."
    if ! scp_copy "./deployment" "/tmp/" "Scripts de déploiement"; then
        return 1
    fi

    # 4. Rendre les scripts exécutables
    if ! ssh_exec "chmod +x /tmp/deployment/scripts/*.sh" "Permissions scripts"; then
        return 1
    fi

    # 5. Vérifications pré-déploiement
    if ! run_pre_deployment_checks; then
        return 1
    fi

    # 6. Sauvegarde système
    if ! create_system_backup; then
        return 1
    fi

    # 7. Installation packages
    if ! install_system_packages; then
        return 1
    fi

    # 8. Configuration système
    if ! configure_system; then
        return 1
    fi

    # 9. Déploiement application
    if ! deploy_application; then
        return 1
    fi

    # 10. Tests post-déploiement
    if ! run_post_deployment_tests; then
        return 1
    fi

    log "INFO" "========================================"
    log "INFO" "DÉPLOIEMENT RÉUSSI !"
    log "INFO" "========================================"
    log "INFO" "URL: http://$PI_IP"
    log "INFO" "Version: $VERSION"
    log "INFO" "Log: $LOG_FILE"

    return 0
}

# Fonction de rollback
rollback_deployment() {
    log "INFO" "Rollback du déploiement..."

    if ! ssh_exec "./deployment/scripts/rollback.sh" "Rollback système"; then
        log "ERROR" "Échec du rollback"
        return 1
    fi

    log "INFO" "Rollback terminé avec succès"
    return 0
}

# Fonction de monitoring
start_monitoring() {
    log "INFO" "Démarrage du monitoring..."

    if ! ssh_exec "./deployment/scripts/monitor.sh" "Monitoring système"; then
        log "ERROR" "Échec du démarrage du monitoring"
        return 1
    fi

    log "INFO" "Monitoring démarré"
    return 0
}

# Fonction de nettoyage
cleanup() {
    log "INFO" "Nettoyage des fichiers temporaires..."
    ssh_exec "rm -rf /tmp/deployment" "Nettoyage fichiers temporaires" || true
}

# Trap pour nettoyage automatique
trap cleanup EXIT

# Parsing des arguments
COMMAND="deploy"
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE_INSTALL=true
            shift
            ;;
        -s|--skip-backup)
            SKIP_BACKUPS=true
            shift
            ;;
        --ip)
            PI_IP="$2"
            shift 2
            ;;
        --user)
            PI_USER="$2"
            shift 2
            ;;
        --pass)
            PI_PASS="$2"
            shift 2
            ;;
        deploy|verify|install|configure|test|rollback|monitor)
            COMMAND="$1"
            shift
            ;;
        *)
            log "ERROR" "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Initialisation du log
echo "======================================" > "$LOG_FILE"
echo "PiSignage v$VERSION - Déploiement Log" >> "$LOG_FILE"
echo "Date: $(date)" >> "$LOG_FILE"
echo "Command: $COMMAND" >> "$LOG_FILE"
echo "Target: $PI_USER@$PI_IP" >> "$LOG_FILE"
echo "======================================" >> "$LOG_FILE"

log "INFO" "PiSignage v$VERSION - Déploiement automatisé"
log "INFO" "Commande: $COMMAND"
log "INFO" "Cible: $PI_USER@$PI_IP"
log "INFO" "Log: $LOG_FILE"

# Exécution de la commande
case $COMMAND in
    "deploy")
        deploy_complete
        exit_code=$?
        ;;
    "verify")
        check_local_requirements && test_ssh_connection && run_pre_deployment_checks
        exit_code=$?
        ;;
    "install")
        check_local_requirements && test_ssh_connection && install_system_packages
        exit_code=$?
        ;;
    "configure")
        check_local_requirements && test_ssh_connection && configure_system
        exit_code=$?
        ;;
    "test")
        check_local_requirements && test_ssh_connection && run_post_deployment_tests
        exit_code=$?
        ;;
    "rollback")
        check_local_requirements && test_ssh_connection && rollback_deployment
        exit_code=$?
        ;;
    "monitor")
        check_local_requirements && test_ssh_connection && start_monitoring
        exit_code=$?
        ;;
    *)
        log "ERROR" "Commande inconnue: $COMMAND"
        exit_code=1
        ;;
esac

if [[ $exit_code -eq 0 ]]; then
    log "INFO" "Opération '$COMMAND' réussie"
else
    log "ERROR" "Opération '$COMMAND' échouée (code: $exit_code)"
fi

exit $exit_code