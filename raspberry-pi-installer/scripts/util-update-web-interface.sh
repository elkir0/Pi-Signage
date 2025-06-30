#!/usr/bin/env bash

# =============================================================================
# Utilitaire de mise à jour de l'interface web Pi Signage
# Version simplifiée et consolidée
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

# Vérification root
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Créer le répertoire de logs
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_info "=== Début de la mise à jour de l'interface web Pi Signage ==="

# Cloner le dépôt dans un répertoire temporaire
temp_dir="/tmp/pi-signage-update-$(date +%s)"
log_info "Clonage du dépôt GitHub..."

if git clone --depth 1 "$GITHUB_REPO" "$temp_dir" >> "$LOG_FILE" 2>&1; then
    log_info "Dépôt cloné avec succès"
else
    log_error "Échec du clonage du dépôt"
    exit 1
fi

# Vérifier que le répertoire web-interface existe
if [[ ! -d "$temp_dir/$WEB_INTERFACE_DIR" ]]; then
    log_error "Répertoire $WEB_INTERFACE_DIR non trouvé dans le dépôt"
    rm -rf "$temp_dir"
    exit 1
fi

# Sauvegarder la configuration actuelle
if [[ -f "$WEB_ROOT/includes/config.php" ]]; then
    log_info "Sauvegarde de la configuration actuelle..."
    cp "$WEB_ROOT/includes/config.php" "$temp_dir/config.backup.php"
fi

# Copier les nouveaux fichiers
log_info "Mise à jour des fichiers..."
src="$temp_dir/$WEB_INTERFACE_DIR"

# Créer les répertoires si nécessaire
mkdir -p "$WEB_ROOT"/{public,api,assets,includes,templates}

# Copier tous les fichiers
if [[ -d "$src/public" ]]; then
    cp -r "$src/public"/* "$WEB_ROOT/public/" 2>/dev/null || true
fi

if [[ -d "$src/api" ]]; then
    cp -r "$src/api"/* "$WEB_ROOT/api/" 2>/dev/null || true
fi

if [[ -d "$src/assets" ]]; then
    cp -r "$src/assets"/* "$WEB_ROOT/assets/" 2>/dev/null || true
fi

if [[ -d "$src/templates" ]]; then
    cp -r "$src/templates"/* "$WEB_ROOT/templates/" 2>/dev/null || true
fi

# Copier les includes sauf config.php
if [[ -d "$src/includes" ]]; then
    find "$src/includes" -name '*.php' ! -name 'config.php' -exec cp {} "$WEB_ROOT/includes/" \;
fi

# Restaurer la configuration si elle existait
if [[ -f "$temp_dir/config.backup.php" ]]; then
    log_info "Restauration de la configuration..."
    cp "$temp_dir/config.backup.php" "$WEB_ROOT/includes/config.php"
fi

# Corriger les permissions
log_info "Mise à jour des permissions..."
chown -R www-data:www-data "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -exec chmod 644 {} \;

# Permissions spéciales pour config.php
if [[ -f "$WEB_ROOT/includes/config.php" ]]; then
    chmod 640 "$WEB_ROOT/includes/config.php"
fi

# Nettoyer
rm -rf "$temp_dir"

# Redémarrer PHP-FPM pour appliquer les changements
log_info "Redémarrage de PHP-FPM..."
systemctl restart php8.2-fpm || log_warn "Impossible de redémarrer PHP-FPM"

log_info "=== Mise à jour terminée avec succès ==="
log_info "Interface web disponible sur: http://$(hostname -I | awk '{print $1}')/"

exit 0