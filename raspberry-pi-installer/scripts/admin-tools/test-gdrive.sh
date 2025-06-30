#!/usr/bin/env bash

# =============================================================================
# Pi Signage - Test de connexion Google Drive
# Version: 2.3.0
# Description: Teste et diagnostique la connexion Google Drive via rclone
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly RCLONE_CONFIG="/root/.config/rclone/rclone.conf"
readonly TEST_LOG="/tmp/gdrive-test-$(date +%Y%m%d-%H%M%S).log"

# Variables par défaut
GDRIVE_FOLDER_NAME="Signage"
VERBOSE=false

# Charger la configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Compteurs pour le résumé
TESTS_PASSED=0
TESTS_FAILED=0

# Logging
log() {
    echo "$*" | tee -a "$TEST_LOG"
}

log_test() {
    echo -e "\n${BLUE}TEST:${NC} $1" | tee -a "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}✓ PASS:${NC} $1" | tee -a "$TEST_LOG"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1" | tee -a "$TEST_LOG"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${CYAN}ℹ INFO:${NC} $1" | tee -a "$TEST_LOG"
}

log_warning() {
    echo -e "${YELLOW}⚠ WARN:${NC} $1" | tee -a "$TEST_LOG"
}

# Vérifier les privilèges root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_fail "Ce script doit être exécuté avec sudo"
        exit 1
    fi
}

# Afficher l'aide
show_help() {
    echo -e "${BLUE}Pi Signage - Test Google Drive${NC}"
    echo
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Options:"
    echo "  -v, --verbose     Mode verbeux (affiche plus de détails)"
    echo "  -h, --help        Affiche cette aide"
    echo
    echo "Ce script teste:"
    echo "  • Installation et configuration de rclone"
    echo "  • Connexion à Google Drive"
    echo "  • Accès au dossier de synchronisation"
    echo "  • Permissions et quotas"
    echo "  • Vitesse de connexion"
}

# Bannière
show_banner() {
    clear
    log "╔══════════════════════════════════════════════════════════════╗"
    log "║         Pi Signage - Test de connexion Google Drive          ║"
    log "║                      Version 2.3.0                           ║"
    log "╚══════════════════════════════════════════════════════════════╝"
    log ""
    log "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    log "Dossier cible: $GDRIVE_FOLDER_NAME"
    log ""
}

# Test 1: Vérifier l'installation de rclone
test_rclone_installation() {
    log_test "Installation de rclone"
    
    if command -v rclone &> /dev/null; then
        local version=$(rclone version | head -1)
        log_success "rclone installé - $version"
        
        # Vérifier la version
        local major_version=$(echo "$version" | grep -oP 'v\K[0-9]+' || echo "0")
        if [[ $major_version -lt 1 ]]; then
            log_warning "Version ancienne de rclone détectée"
        fi
    else
        log_fail "rclone n'est pas installé"
        log_info "Installation: sudo apt-get install rclone"
        return 1
    fi
}

# Test 2: Vérifier la configuration rclone
test_rclone_config() {
    log_test "Configuration rclone"
    
    if [[ -f "$RCLONE_CONFIG" ]]; then
        log_success "Fichier de configuration trouvé"
        
        # Vérifier les permissions
        local perms=$(stat -c "%a" "$RCLONE_CONFIG")
        if [[ "$perms" == "600" ]] || [[ "$perms" == "400" ]]; then
            log_success "Permissions du fichier correctes ($perms)"
        else
            log_warning "Permissions non sécurisées: $perms (recommandé: 600)"
        fi
        
        # Vérifier si le remote gdrive existe
        if grep -q "^\[gdrive\]" "$RCLONE_CONFIG"; then
            log_success "Remote 'gdrive' configuré"
        else
            log_fail "Remote 'gdrive' non trouvé dans la configuration"
            log_info "Remotes disponibles:"
            rclone listremotes | sed 's/^/  • /'
            return 1
        fi
    else
        log_fail "Fichier de configuration non trouvé: $RCLONE_CONFIG"
        log_info "Configurez rclone avec: sudo rclone config"
        return 1
    fi
}

# Test 3: Tester la connexion basique
test_basic_connection() {
    log_test "Connexion à Google Drive"
    
    log_info "Tentative de connexion..."
    
    if rclone lsd "gdrive:" --max-depth 1 &>/dev/null; then
        log_success "Connexion établie avec succès"
    else
        log_fail "Impossible de se connecter à Google Drive"
        
        # Essayer de diagnostiquer le problème
        log_info "Diagnostic de l'erreur:"
        rclone lsd "gdrive:" --max-depth 1 2>&1 | tail -5 | sed 's/^/  /'
        
        return 1
    fi
}

# Test 4: Vérifier les quotas
test_quota() {
    log_test "Vérification des quotas Google Drive"
    
    local quota_info=$(rclone about "gdrive:" 2>/dev/null)
    
    if [[ -n "$quota_info" ]]; then
        log_success "Informations de quota récupérées"
        
        # Parser les informations
        local total=$(echo "$quota_info" | grep "Total:" | awk '{print $2}')
        local used=$(echo "$quota_info" | grep "Used:" | awk '{print $2}')
        local free=$(echo "$quota_info" | grep "Free:" | awk '{print $2}')
        
        log_info "Espace total: $total"
        log_info "Espace utilisé: $used"
        log_info "Espace libre: $free"
        
        # Vérifier l'espace libre (au moins 1GB)
        local free_bytes=$(rclone about "gdrive:" --json 2>/dev/null | grep -oP '"free":\K[0-9]+' || echo "0")
        if [[ $free_bytes -gt 1073741824 ]]; then
            log_success "Espace libre suffisant"
        else
            log_warning "Espace libre faible"
        fi
    else
        log_warning "Impossible de récupérer les informations de quota"
    fi
}

# Test 5: Vérifier le dossier de synchronisation
test_sync_folder() {
    log_test "Vérification du dossier '$GDRIVE_FOLDER_NAME'"
    
    # Lister les dossiers racine
    local folders=$(rclone lsd "gdrive:" 2>/dev/null)
    
    if echo "$folders" | grep -q " $GDRIVE_FOLDER_NAME$"; then
        log_success "Dossier '$GDRIVE_FOLDER_NAME' trouvé"
        
        # Compter les fichiers
        log_info "Analyse du contenu..."
        local file_count=$(rclone ls "gdrive:$GDRIVE_FOLDER_NAME" 2>/dev/null | wc -l || echo "0")
        local total_size=$(rclone size "gdrive:$GDRIVE_FOLDER_NAME" 2>/dev/null | grep "Total size:" | cut -d: -f2 || echo " inconnu")
        
        log_info "Nombre de fichiers: $file_count"
        log_info "Taille totale:$total_size"
        
        # Lister les types de fichiers
        if [[ $file_count -gt 0 ]]; then
            log_info "Types de fichiers:"
            rclone ls "gdrive:$GDRIVE_FOLDER_NAME" 2>/dev/null | awk -F. '{print $NF}' | sort | uniq -c | sort -nr | head -5 | sed 's/^/    /'
        fi
    else
        log_fail "Dossier '$GDRIVE_FOLDER_NAME' non trouvé"
        log_info "Dossiers disponibles à la racine:"
        echo "$folders" | awk '{print "  • " $5}' | head -10
        
        # Suggérer de créer le dossier
        log_info "Pour créer le dossier: rclone mkdir \"gdrive:$GDRIVE_FOLDER_NAME\""
    fi
}

# Test 6: Test de lecture/écriture
test_read_write() {
    log_test "Test de lecture/écriture"
    
    local test_file="/tmp/pi-signage-test-$(date +%s).txt"
    local remote_test="gdrive:$GDRIVE_FOLDER_NAME/test-$(date +%s).txt"
    
    # Créer un fichier test
    echo "Pi Signage test file - $(date)" > "$test_file"
    
    # Upload
    log_info "Test d'upload..."
    if rclone copy "$test_file" "$(dirname "$remote_test")" 2>/dev/null; then
        log_success "Upload réussi"
        
        # Vérifier que le fichier existe
        if rclone ls "$remote_test" &>/dev/null; then
            log_success "Fichier vérifié sur Drive"
            
            # Supprimer le fichier test
            if rclone delete "$remote_test" 2>/dev/null; then
                log_success "Suppression réussie"
            else
                log_warning "Impossible de supprimer le fichier test"
            fi
        else
            log_fail "Fichier non trouvé après upload"
        fi
    else
        log_fail "Échec de l'upload"
        log_warning "Vérifiez les permissions du dossier sur Google Drive"
    fi
    
    # Nettoyer
    rm -f "$test_file"
}

# Test 7: Test de bande passante
test_bandwidth() {
    log_test "Test de bande passante"
    
    log_info "Test de vitesse de téléchargement..."
    
    # Chercher un petit fichier vidéo pour le test
    local test_file=$(rclone ls "gdrive:$GDRIVE_FOLDER_NAME" 2>/dev/null | awk '$1 < 10485760 {print $2}' | head -1)
    
    if [[ -n "$test_file" ]]; then
        local start_time=$(date +%s)
        local temp_file="/tmp/bandwidth-test-$(date +%s)"
        
        if rclone copy "gdrive:$GDRIVE_FOLDER_NAME/$test_file" "/tmp" --stats-one-line --stats 1s 2>&1 | grep -oP '\d+\.\d+ [KMG]Bytes/s' | tail -1 | tee -a "$TEST_LOG"; then
            log_success "Test de bande passante terminé"
        else
            log_warning "Test de bande passante incomplet"
        fi
        
        rm -f "$temp_file"
    else
        log_info "Aucun fichier approprié pour le test de bande passante"
    fi
}

# Test 8: Vérifier la configuration réseau
test_network() {
    log_test "Configuration réseau"
    
    # DNS
    if nslookup drive.google.com &>/dev/null; then
        log_success "Résolution DNS fonctionnelle"
    else
        log_fail "Problème de résolution DNS"
    fi
    
    # Connectivité HTTPS
    if curl -s -o /dev/null -w "%{http_code}" "https://drive.google.com" | grep -q "200\|302"; then
        log_success "Connectivité HTTPS vers Google Drive"
    else
        log_fail "Problème de connectivité HTTPS"
    fi
    
    # Vérifier le proxy
    if [[ -n "${HTTP_PROXY:-}" ]] || [[ -n "${HTTPS_PROXY:-}" ]]; then
        log_warning "Proxy détecté - peut affecter la connexion"
        log_info "HTTP_PROXY: ${HTTP_PROXY:-non défini}"
        log_info "HTTPS_PROXY: ${HTTPS_PROXY:-non défini}"
    fi
}

# Résumé des tests
show_summary() {
    echo
    log "╔══════════════════════════════════════════════════════════════╗"
    log "║                      RÉSUMÉ DES TESTS                        ║"
    log "╚══════════════════════════════════════════════════════════════╝"
    log ""
    log "Tests réussis:  ${GREEN}$TESTS_PASSED${NC}"
    log "Tests échoués:  ${RED}$TESTS_FAILED${NC}"
    log ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log "${GREEN}✓ Tous les tests sont passés!${NC}"
        log ""
        log "La synchronisation Google Drive devrait fonctionner correctement."
        log "Lancez la synchronisation avec: sudo sync-videos.sh"
    else
        log "${RED}✗ Certains tests ont échoué${NC}"
        log ""
        log "Corrigez les problèmes ci-dessus avant de lancer la synchronisation."
        
        # Suggestions selon les échecs
        if ! command -v rclone &> /dev/null; then
            log ""
            log "Installation de rclone:"
            log "  sudo apt-get update && sudo apt-get install -y rclone"
        elif [[ ! -f "$RCLONE_CONFIG" ]]; then
            log ""
            log "Configuration de rclone:"
            log "  sudo rclone config"
            log "  • Créez un nouveau remote nommé 'gdrive'"
            log "  • Type: Google Drive"
            log "  • Suivez les instructions pour l'authentification"
        fi
    fi
    
    log ""
    log "Rapport complet: $TEST_LOG"
}

# Fonction principale
main() {
    # Traiter les arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Vérifications préliminaires
    check_root
    
    # Créer le fichier de log
    mkdir -p "$(dirname "$TEST_LOG")"
    
    # Afficher la bannière
    show_banner
    
    # Exécuter les tests
    test_rclone_installation
    
    # Si rclone n'est pas installé, arrêter là
    if ! command -v rclone &> /dev/null; then
        show_summary
        exit 1
    fi
    
    test_rclone_config
    
    # Si pas de config, arrêter là
    if [[ ! -f "$RCLONE_CONFIG" ]] || ! grep -q "^\[gdrive\]" "$RCLONE_CONFIG"; then
        show_summary
        exit 1
    fi
    
    # Tests de connexion
    test_network
    test_basic_connection
    
    # Si pas de connexion, arrêter là
    if ! rclone lsd "gdrive:" --max-depth 1 &>/dev/null; then
        show_summary
        exit 1
    fi
    
    # Tests avancés
    test_quota
    test_sync_folder
    test_read_write
    test_bandwidth
    
    # Afficher le résumé
    show_summary
    
    # Code de sortie selon les résultats
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Exécution
main "$@"