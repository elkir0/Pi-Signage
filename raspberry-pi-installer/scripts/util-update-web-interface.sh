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

fix_config_php_constant() {
    log_info "Vérification et correction de config.php..."
    
    local config_file="/var/www/pi-signage/includes/config.php"
    if [[ ! -f "$config_file" ]]; then
        log_warn "config.php non trouvé, skip"
        return 0
    fi
    
    # Corriger la redéfinition de PI_SIGNAGE_WEB
    if grep -q "define('PI_SIGNAGE_WEB', true);" "$config_file"; then
        log_info "Correction de la constante PI_SIGNAGE_WEB..."
        sed -i "s/define('PI_SIGNAGE_WEB', true);/exit('Direct access not permitted');/" "$config_file"
        log_info "Constante corrigée"
    fi
}

update_sudoers_permissions() {
    log_info "Mise à jour des permissions sudoers..."
    
    local sudoers_file="/etc/sudoers.d/pi-signage-web"
    if [[ ! -f "$sudoers_file" ]]; then
        log_warn "Fichier sudoers non trouvé, skip"
        return 0
    fi
    
    # Vérifier si la permission update-playlist existe déjà
    if ! grep -q "update-playlist.sh" "$sudoers_file"; then
        echo "www-data ALL=(ALL) NOPASSWD: /opt/scripts/update-playlist.sh" >> "$sudoers_file"
        chmod 440 "$sudoers_file"
        log_info "Permission update-playlist.sh ajoutée pour www-data"
    fi
}

fix_nginx_api_routing() {
    log_info "Vérification et correction du routage API nginx..."
    
    local nginx_config="/etc/nginx/sites-available/pi-signage"
    if [[ ! -f "$nginx_config" ]]; then
        log_warn "Configuration nginx non trouvée, skip"
        return 0
    fi
    
    # Vérifier si la correction est déjà appliquée
    if grep -q "alias /var/www/pi-signage/api/" "$nginx_config"; then
        log_info "Routage API déjà configuré correctement"
        return 0
    fi
    
    # Créer une sauvegarde
    cp "$nginx_config" "$nginx_config.bak.$(date +%Y%m%d_%H%M%S)"
    
    # Remplacer la configuration API
    local temp_file="/tmp/nginx-config-$(date +%s)"
    awk '
    /# API endpoint/ {
        print "    # API endpoint - Route vers le répertoire API parent"
        print "    location /api/ {"
        print "        alias /var/www/pi-signage/api/;"
        print "        try_files $uri $uri/ =404;"
        print "        "
        print "        location ~ \\.php$ {"
        print "            include snippets/fastcgi-php.conf;"
        print "            fastcgi_pass unix:/run/php/php8.2-fpm-pi-signage.sock;"
        print "            fastcgi_param SCRIPT_FILENAME $request_filename;"
        print "            "
        print "            # Timeout pour les téléchargements longs"
        print "            fastcgi_read_timeout 300;"
        print "        }"
        print "    }"
        # Skip jusqu'à la prochaine fermeture de bloc
        while (getline > 0 && $0 !~ /^[[:space:]]*}[[:space:]]*$/) {}
        next
    }
    { print }
    ' "$nginx_config" > "$temp_file"
    
    mv "$temp_file" "$nginx_config"
    
    # Créer le répertoire de progression si nécessaire
    mkdir -p /tmp/pi-signage-progress
    chmod 777 /tmp/pi-signage-progress
    
    # Tester et recharger nginx
    if nginx -t >> "$LOG_FILE" 2>&1; then
        log_info "Configuration nginx valide, rechargement..."
        systemctl reload nginx
        log_info "Routage API corrigé avec succès"
    else
        log_error "Configuration nginx invalide, restauration..."
        mv "$nginx_config.bak.$(date +%Y%m%d_%H%M%S)" "$nginx_config"
        return 1
    fi
}

if [[ "$FULL_UPDATE" == true ]]; then
    update_full
else
    update_simple
fi

# Toujours appliquer les corrections après la mise à jour
fix_nginx_api_routing
fix_config_php_constant
update_sudoers_permissions

exit 0

