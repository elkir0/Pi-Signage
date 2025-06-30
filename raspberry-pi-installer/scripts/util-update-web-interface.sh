#!/usr/bin/env bash

# =============================================================================
# Utilitaire de mise à jour de l'interface web Pi Signage
# Permet une mise à jour simple ou complète (réinitialisation configuration)
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Chemins
readonly WEB_ROOT="/var/www/pi-signage"
readonly GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
readonly WEB_INTERFACE_DIR="web-interface"
readonly LOG_FILE="/var/log/pi-signage/web-update.log"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FULL_UPDATE=false

# Fonctions de log
log_info() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${NC} $*"
    echo "$ts [INFO] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${NC} $*"
    echo "$ts [WARN] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} $*" >&2
    echo "$ts [ERROR] $*" >> "$LOG_FILE" 2>/dev/null || true
}

usage() {
    echo "Usage: $0 [--full]"
    echo "  --full  Réinitialise la configuration (nouveau mot de passe)"
}

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --full)
            FULL_UPDATE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Option inconnue: $1"
            usage
            exit 1
            ;;
    esac
done

# Vérification root
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Charger les fonctions de sécurité pour hash_password
if [[ -f "$SCRIPT_DIR/00-security-utils.sh" ]]; then
    source "$SCRIPT_DIR/00-security-utils.sh"
else
    hash_password() {
        local password="$1"
        local salt="${2:-$(openssl rand -hex 16)}"
        local hash
        hash=$(echo -n "${salt}${password}" | sha512sum | cut -d' ' -f1)
        echo "${salt}:${hash}"
    }
fi

update_simple() {
    log_info "Mise à jour simple de l'interface web"

    local temp_dir="/tmp/pi-signage-update-$(date +%s)"
    if git clone --depth 1 "$GITHUB_REPO" "$temp_dir" >> "$LOG_FILE" 2>&1; then
        log_info "Dépôt cloné"
    else
        log_error "Échec du clonage du dépôt"
        return 1
    fi

    local src="$temp_dir/$WEB_INTERFACE_DIR"
    if [[ ! -d "$src" ]]; then
        log_error "Répertoire $WEB_INTERFACE_DIR manquant dans le dépôt"
        rm -rf "$temp_dir"
        return 1
    fi

    cp -r "$src/public"/* "$WEB_ROOT/public/"
    cp -r "$src/api"/* "$WEB_ROOT/api/"
    if [[ -d "$src/assets" ]]; then
        cp -r "$src/assets"/* "$WEB_ROOT/assets/" 2>/dev/null || true
    fi
    cp -r "$src/templates"/* "$WEB_ROOT/templates/"
    find "$src/includes" -name '*.php' ! -name 'config.php' -exec cp {} "$WEB_ROOT/includes/" \;

    chown -R www-data:www-data "$WEB_ROOT"
    rm -rf "$temp_dir"
    log_info "Mise à jour simple terminée"
}

update_full() {
    log_warn "Mise à jour complète : la configuration sera réinitialisée"

    local temp_dir="/tmp/pi-signage-update-$(date +%s)"
    if git clone --depth 1 "$GITHUB_REPO" "$temp_dir" >> "$LOG_FILE" 2>&1; then
        log_info "Dépôt cloné"
    else
        log_error "Échec du clonage du dépôt"
        return 1
    fi

    local src="$temp_dir/$WEB_INTERFACE_DIR"
    if [[ ! -d "$src" ]]; then
        log_error "Répertoire $WEB_INTERFACE_DIR manquant dans le dépôt"
        rm -rf "$temp_dir"
        return 1
    fi

    rm -rf "$WEB_ROOT"
    mkdir -p "$WEB_ROOT"
    cp -r "$src"/* "$WEB_ROOT/"

    if [[ -f "$WEB_ROOT/includes/config.template.php" ]]; then
        cp "$WEB_ROOT/includes/config.template.php" "$WEB_ROOT/includes/config.php"

        while true; do
            read -rsp "Nouveau mot de passe admin : " pass1
            echo
            read -rsp "Confirmez le mot de passe   : " pass2
            echo
            if [[ "$pass1" == "$pass2" && ${#pass1} -ge 8 ]]; then
                break
            fi
            log_warn "Les mots de passe ne correspondent pas ou sont trop courts"
        done
        local hash
        hash=$(hash_password "$pass1")
        sed -i "s|{{WEB_ADMIN_PASSWORD_HASH}}|$hash|" "$WEB_ROOT/includes/config.php"
    else
        log_error "Template de configuration introuvable"
        rm -rf "$temp_dir"
        return 1
    fi

    chown -R www-data:www-data "$WEB_ROOT"
    rm -rf "$temp_dir"
    log_info "Mise à jour complète terminée"
}

if [[ "$FULL_UPDATE" == true ]]; then
    update_full
else
    update_simple
fi

exit 0

