#!/usr/bin/env bash

# =============================================================================
# Module 09 - Installation Interface Web PHP (Version 2.0)
# Version: 2.2.0
# Description: Installation de l'interface web depuis GitHub
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly WEB_ROOT="/var/www/pi-signage"
readonly NGINX_CONFIG="/etc/nginx/sites-available/pi-signage"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# URL du dépôt GitHub
readonly GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
readonly WEB_INTERFACE_DIR="web-interface"

# Charger les fonctions de sécurité
if [[ -f "$SCRIPT_DIR/00-security-utils.sh" ]]; then
    source "$SCRIPT_DIR/00-security-utils.sh"
else
    echo "ERREUR: Fichier de sécurité manquant: 00-security-utils.sh" >&2
    exit 1
fi

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
    echo -e "${GREEN}[WEB]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[WEB]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[WEB]${NC} $*" >&2
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
# INSTALLATION NGINX ET PHP
# =============================================================================

install_web_server() {
    log_info "Installation de nginx et PHP-FPM..."
    
    # Paquets nécessaires
    local packages=(
        "nginx"
        "php8.2-fpm"
        "php8.2-cli"
        "php8.2-common"
        "php8.2-curl"
        "php8.2-xml"
        "php8.2-mbstring"
        "php8.2-zip"
        "python3-pip"
        "ffmpeg"
        "git"  # Ajout de git pour cloner le dépôt
    )
    
    # Installation
    if safe_execute "apt-get update && apt-get install -y ${packages[*]}" 3 10; then
        log_info "Paquets web installés avec succès"
    else
        log_error "Échec de l'installation des paquets web"
        return 1
    fi
    
    # Vérification
    if command -v nginx >/dev/null 2>&1 && command -v php >/dev/null 2>&1; then
        log_info "nginx et PHP installés correctement"
    else
        log_error "Installation incomplète"
        return 1
    fi
}

# =============================================================================
# INSTALLATION YT-DLP
# =============================================================================

install_ytdlp() {
    log_info "Installation de yt-dlp..."
    
    # Télécharger la dernière version de yt-dlp
    if curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp; then
        chmod a+rx /usr/local/bin/yt-dlp
        log_info "yt-dlp installé avec succès"
        
        # Vérifier l'installation
        local version
        version=$(yt-dlp --version 2>/dev/null || echo "Version inconnue")
        log_info "yt-dlp version: $version"
    else
        log_error "Échec du téléchargement de yt-dlp"
        return 1
    fi
}

# =============================================================================
# CONFIGURATION PHP-FPM
# =============================================================================

configure_php_fpm() {
    log_info "Configuration de PHP-FPM pour Raspberry Pi..."
    
    # Configuration optimisée pour Pi
    cat > /etc/php/8.2/fpm/pool.d/pi-signage.conf << 'EOF'
[pi-signage]
user = www-data
group = www-data
listen = /run/php/php8.2-fpm-pi-signage.sock
listen.owner = www-data
listen.group = www-data

; Configuration optimisée pour Raspberry Pi
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 500

; Limites mémoire
php_admin_value[memory_limit] = 64M
php_admin_value[upload_max_filesize] = 100M
php_admin_value[post_max_size] = 100M
php_admin_value[max_execution_time] = 300

; Sécurité
; Note: shell_exec, exec, file_get_contents, file_put_contents et proc_open sont nécessaires pour l'interface web
php_admin_value[disable_functions] = passthru,system,popen,curl_multi_exec,parse_ini_file,show_source,eval
php_admin_flag[allow_url_fopen] = off
php_admin_flag[allow_url_include] = off
php_admin_flag[expose_php] = off

; Sessions
php_admin_value[session.save_path] = /var/lib/php/sessions/pi-signage
php_admin_value[session.cookie_httponly] = 1
php_admin_value[session.use_only_cookies] = 1

; Logs
php_admin_value[error_log] = /var/log/pi-signage/php-error.log
php_admin_flag[log_errors] = on
php_admin_flag[display_errors] = off
EOF
    
    # Créer le répertoire de sessions
    mkdir -p /var/lib/php/sessions/pi-signage
    secure_dir_permissions "/var/lib/php/sessions/pi-signage" "www-data" "www-data" "700"
    
    # Créer le répertoire de logs PHP
    mkdir -p /var/log/pi-signage
    secure_dir_permissions "/var/log/pi-signage" "www-data" "www-data" "755"
    
    # Créer le fichier de log PHP s'il n'existe pas
    touch /var/log/pi-signage/php-error.log
    chown www-data:www-data /var/log/pi-signage/php-error.log
    chmod 644 /var/log/pi-signage/php-error.log
    
    # Créer le répertoire cache pour www-data (nécessaire pour yt-dlp)
    mkdir -p /var/www/.cache
    secure_dir_permissions "/var/www/.cache" "www-data" "www-data" "755"
    
    # Redémarrer PHP-FPM
    systemctl restart php8.2-fpm
    
    log_info "PHP-FPM configuré"
}

# =============================================================================
# CONFIGURATION NGINX
# =============================================================================

configure_nginx() {
    log_info "Configuration de nginx..."
    
    # Configuration du site
    cat > "$NGINX_CONFIG" << 'EOF'
server {
    listen 80;
    listen [::]:80;
    
    server_name _;
    root /var/www/pi-signage/public;
    index index.php index.html;
    
    # Logs
    access_log /var/log/nginx/pi-signage-access.log;
    error_log /var/log/nginx/pi-signage-error.log;
    
    # Limite de taille pour l'upload
    client_max_body_size 100M;
    
    # Sécurité
    add_header X-Frame-Options "DENY";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    
    # Interdire l'accès aux fichiers cachés
    location ~ /\. {
        deny all;
    }
    
    # Interdire l'accès direct aux includes
    location ~ ^/(includes|config|templates)/ {
        deny all;
    }
    
    # PHP
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm-pi-signage.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Timeout pour les téléchargements longs
        fastcgi_read_timeout 300;
    }
    
    # Fichiers statiques
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1d;
        add_header Cache-Control "public, immutable";
    }
    
    # API endpoint - Route vers le répertoire API parent
    location /api/ {
        alias /var/www/pi-signage/api/;
        try_files $uri $uri/ =404;
        
        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php8.2-fpm-pi-signage.sock;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            
            # Timeout pour les téléchargements longs
            fastcgi_read_timeout 300;
        }
    }
}
EOF
    
    # Activer le site
    ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/pi-signage
    
    # Désactiver le site par défaut
    rm -f /etc/nginx/sites-enabled/default
    
    # Test de configuration
    if nginx -t; then
        log_info "Configuration nginx valide"
        systemctl restart nginx
    else
        log_error "Configuration nginx invalide"
        return 1
    fi
}

# =============================================================================
# DÉPLOIEMENT DES FICHIERS WEB DEPUIS GITHUB
# =============================================================================

deploy_web_files() {
    log_info "Déploiement des fichiers de l'interface web depuis GitHub..."
    
    # Créer un répertoire temporaire pour le clone
    local temp_dir="/tmp/pi-signage-web-$(date +%s)"
    
    # Cloner le dépôt
    log_info "Clonage du dépôt GitHub..."
    if git clone --depth 1 "$GITHUB_REPO" "$temp_dir"; then
        log_info "Dépôt cloné avec succès"
    else
        log_error "Échec du clonage du dépôt"
        return 1
    fi
    
    # Vérifier que le répertoire web-interface existe
    if [[ ! -d "$temp_dir/$WEB_INTERFACE_DIR" ]]; then
        log_error "Répertoire $WEB_INTERFACE_DIR non trouvé dans le dépôt"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Copier les fichiers de l'interface web
    log_info "Copie des fichiers web..."
    mkdir -p "$WEB_ROOT"
    
    # Copier tout sauf config
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/public" "$WEB_ROOT/"
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/includes" "$WEB_ROOT/"
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/api" "$WEB_ROOT/"
    if [[ -d "$temp_dir/$WEB_INTERFACE_DIR/assets" ]]; then
        cp -r "$temp_dir/$WEB_INTERFACE_DIR/assets" "$WEB_ROOT/"
    else
        log_warn "Dossier assets non trouvé dans le dépôt"
    fi
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/templates" "$WEB_ROOT/"
    
    # Créer le fichier de configuration à partir du template
    if [[ -f "$temp_dir/$WEB_INTERFACE_DIR/includes/config.template.php" ]]; then
        cp "$temp_dir/$WEB_INTERFACE_DIR/includes/config.template.php" "$WEB_ROOT/includes/config.php"
        
        # Remplacer le placeholder du mot de passe hashé
        if [[ -n "${WEB_ADMIN_PASSWORD_HASH:-}" ]]; then
            sed -i "s|{{WEB_ADMIN_PASSWORD_HASH}}|$WEB_ADMIN_PASSWORD_HASH|g" "$WEB_ROOT/includes/config.php"
            log_info "Configuration PHP générée avec le mot de passe hashé"
        else
            log_error "Mot de passe admin non défini"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        log_error "Template de configuration manquant"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Créer les répertoires nécessaires
    mkdir -p "$WEB_ROOT/temp"
    mkdir -p "/opt/videos"
    mkdir -p "/tmp/pi-signage-progress"
    chmod 777 "/tmp/pi-signage-progress"
    
    # Gérer les assets - créer la structure dans public et les liens vers les fichiers
    if [[ -d "$WEB_ROOT/assets" ]]; then
        # Créer la structure dans public si elle n'existe pas
        mkdir -p "$WEB_ROOT/public/assets/"{css,js,images}
        
        # Créer des liens symboliques pour chaque fichier
        if [[ -f "$WEB_ROOT/assets/css/style.css" ]]; then
            ln -sf "$WEB_ROOT/assets/css/style.css" "$WEB_ROOT/public/assets/css/style.css"
            log_info "Lien créé pour style.css"
        fi
        
        if [[ -f "$WEB_ROOT/assets/js/main.js" ]]; then
            ln -sf "$WEB_ROOT/assets/js/main.js" "$WEB_ROOT/public/assets/js/main.js"
            log_info "Lien créé pour main.js"
        fi
        
        # Copier les images si elles existent
        if [[ -d "$WEB_ROOT/assets/images" ]]; then
            cp -r "$WEB_ROOT/assets/images/"* "$WEB_ROOT/public/assets/images/" 2>/dev/null || true
        fi
        
        # Créer aussi un lien pour dashboard.css s'il existe
        if [[ -f "$WEB_ROOT/assets/css/dashboard.css" ]]; then
            ln -sf "$WEB_ROOT/assets/css/dashboard.css" "$WEB_ROOT/public/assets/css/dashboard.css"
        elif [[ -f "$WEB_ROOT/public/assets/css/dashboard.css" ]]; then
            log_info "dashboard.css déjà présent"
        fi
        
        log_info "Assets configurés avec succès"
    else
        # Si pas d'assets, créer une structure minimale
        mkdir -p "$WEB_ROOT/public/assets/"{css,js,images}
        echo "/* Pi Signage Web Interface */" > "$WEB_ROOT/public/assets/css/style.css"
        echo "// Pi Signage Main JS" > "$WEB_ROOT/public/assets/js/main.js"
        log_info "Structure assets minimale créée"
    fi
    
    # Nettoyer le répertoire temporaire
    rm -rf "$temp_dir"
    
    # Nettoyer les fichiers de test
    rm -f "$WEB_ROOT/test.php" 2>/dev/null || true
    
    # Permissions sécurisées
    if command -v secure_dir_permissions >/dev/null 2>&1; then
        secure_dir_permissions "$WEB_ROOT" "www-data" "www-data" "755"
        secure_dir_permissions "$WEB_ROOT/temp" "www-data" "www-data" "770"
        secure_dir_permissions "$WEB_ROOT/includes" "www-data" "www-data" "755"
        secure_dir_permissions "$WEB_ROOT/api" "www-data" "www-data" "755"
        secure_dir_permissions "$WEB_ROOT/public" "www-data" "www-data" "755"
        secure_file_permissions "$WEB_ROOT/includes/config.php" "www-data" "www-data" "640"
    else
        chown -R www-data:www-data "$WEB_ROOT"
        chmod -R 755 "$WEB_ROOT"
        chmod -R 770 "$WEB_ROOT/temp"
        chmod 640 "$WEB_ROOT/includes/config.php"
    fi
    
    # S'assurer que /opt/videos est accessible par www-data
    if [[ -d "/opt/videos" ]]; then
        chown -R www-data:www-data "/opt/videos"
        chmod 755 "/opt/videos"
    fi
    
    log_info "Fichiers web déployés depuis GitHub"
}

# =============================================================================
# CONFIGURATION DU WRAPPER YT-DLP
# =============================================================================

configure_ytdlp_wrapper() {
    log_info "Configuration du wrapper yt-dlp..."
    
    # Créer le wrapper yt-dlp
    cat > /opt/scripts/yt-dlp-wrapper.sh << 'EOF'
#!/bin/bash
# Wrapper pour yt-dlp avec environnement correct

# Définir l'environnement
export HOME=/var/www
export PATH=/usr/local/bin:/usr/bin:/bin
export PYTHONIOENCODING=utf-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Créer le répertoire cache si nécessaire
mkdir -p /var/www/.cache/yt-dlp 2>/dev/null
chmod 755 /var/www/.cache 2>/dev/null
chown -R www-data:www-data /var/www/.cache 2>/dev/null

# Exécuter yt-dlp avec les arguments
exec /usr/local/bin/yt-dlp "$@"
EOF
    
    # Permissions sur le wrapper
    chmod 755 /opt/scripts/yt-dlp-wrapper.sh
    
    # Créer le répertoire cache pour www-data
    mkdir -p /var/www/.cache/yt-dlp
    chown -R www-data:www-data /var/www/.cache
    chmod -R 755 /var/www/.cache
    
    log_info "Wrapper yt-dlp configuré"
}

# =============================================================================
# CONFIGURATION SUDOERS POUR REDÉMARRAGE VLC
# =============================================================================

configure_sudoers() {
    log_info "Configuration des permissions sudo pour l'interface web..."
    
    # Permettre à www-data de redémarrer les services
    cat > /etc/sudoers.d/pi-signage-web << 'EOF'
# Permettre à l'interface web de contrôler les services
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl start vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl status vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart chromium-kiosk.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop chromium-kiosk.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl start chromium-kiosk.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl status chromium-kiosk.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart pi-signage-watchdog.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop pi-signage-watchdog.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl start pi-signage-watchdog.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl status pi-signage-watchdog.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart php8.2-fpm.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart glances.service
www-data ALL=(ALL) NOPASSWD: /opt/scripts/update-playlist.sh
www-data ALL=(ALL) NOPASSWD: /opt/scripts/yt-dlp-wrapper.sh
EOF
    
    # Permissions sécurisées pour sudoers
    if command -v secure_file_permissions >/dev/null 2>&1; then
        secure_file_permissions "/etc/sudoers.d/pi-signage-web" "root" "root" "440"
    else
        chmod 440 /etc/sudoers.d/pi-signage-web
    fi
    
    # Valider la configuration sudoers
    if ! visudo -c -f /etc/sudoers.d/pi-signage-web >/dev/null 2>&1; then
        log_error "Configuration sudoers invalide!"
        rm -f /etc/sudoers.d/pi-signage-web
        return 1
    fi
    
    log_info "Permissions sudo configurées"
}

# =============================================================================
# CONFIGURATION VLC POUR L'API HTTP
# =============================================================================

configure_vlc_http() {
    log_info "Configuration de l'interface HTTP de VLC..."
    
    # Mettre à jour le script VLC pour activer l'interface HTTP
    if [[ -f "/opt/scripts/vlc-signage.sh" ]]; then
        # Ajouter les options HTTP à VLC
        sed -i 's|vlc \\|vlc \\\n        --intf http \\\n        --http-host 127.0.0.1 \\\n        --http-port 8080 \\\n        --http-password "" \\|' /opt/scripts/vlc-signage.sh
        
        log_info "Interface HTTP VLC configurée"
    else
        log_warn "Script VLC introuvable, configuration manuelle nécessaire"
    fi
}

# =============================================================================
# CRÉATION D'UN SCRIPT DE MISE À JOUR
# =============================================================================

create_update_scripts() {
    log_info "Création des scripts de mise à jour..."
    
    # Script de mise à jour yt-dlp
    cat > /opt/scripts/update-ytdlp.sh << 'EOF'
#!/bin/bash

# Script de mise à jour yt-dlp

LOG_FILE="/var/log/pi-signage/ytdlp-update.log"

echo "$(date): Mise à jour yt-dlp" >> "$LOG_FILE"

if yt-dlp -U >> "$LOG_FILE" 2>&1; then
    echo "$(date): Mise à jour réussie" >> "$LOG_FILE"
else
    echo "$(date): Échec de la mise à jour" >> "$LOG_FILE"
fi
EOF
    
    chmod +x /opt/scripts/update-ytdlp.sh
    
    # Script de mise à jour de l'interface web
    cat > /opt/scripts/update-web-interface.sh << 'EOF'
#!/bin/bash

# Script de mise à jour de l'interface web depuis GitHub

set -euo pipefail

LOG_FILE="/var/log/pi-signage/web-update.log"
WEB_ROOT="/var/www/pi-signage"
GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
WEB_INTERFACE_DIR="web-interface"

echo "$(date): Début de la mise à jour de l'interface web" >> "$LOG_FILE"

# Créer un répertoire temporaire
temp_dir="/tmp/pi-signage-update-$(date +%s)"

# Cloner le dépôt
if git clone --depth 1 "$GITHUB_REPO" "$temp_dir" >> "$LOG_FILE" 2>&1; then
    echo "$(date): Dépôt cloné avec succès" >> "$LOG_FILE"
    
    # Sauvegarder la configuration actuelle
    cp "$WEB_ROOT/includes/config.php" "$temp_dir/config.backup.php"
    
    # Copier les nouveaux fichiers (sauf config)
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/public"/* "$WEB_ROOT/public/"
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/api"/* "$WEB_ROOT/api/"
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/assets"/* "$WEB_ROOT/assets/"
    cp -r "$temp_dir/$WEB_INTERFACE_DIR/templates"/* "$WEB_ROOT/templates/"
    
    # Copier les includes sauf config.php
    find "$temp_dir/$WEB_INTERFACE_DIR/includes" -name "*.php" ! -name "config.php" -exec cp {} "$WEB_ROOT/includes/" \;
    
    # Restaurer les permissions
    chown -R www-data:www-data "$WEB_ROOT"
    
    echo "$(date): Mise à jour terminée avec succès" >> "$LOG_FILE"
else
    echo "$(date): Échec du clonage du dépôt" >> "$LOG_FILE"
fi

# Nettoyer
rm -rf "$temp_dir"
EOF
    
    chmod +x /opt/scripts/update-web-interface.sh
    
    # Ajouter une tâche cron pour mise à jour hebdomadaire
    cat > /etc/cron.d/pi-signage-updates << 'EOF'
# Mise à jour hebdomadaire de yt-dlp et de l'interface web
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 4 * * 1 root /opt/scripts/update-ytdlp.sh
0 5 * * 1 root /opt/scripts/update-web-interface.sh
EOF
    
    # Permissions sécurisées pour cron
    if command -v secure_file_permissions >/dev/null 2>&1; then
        secure_file_permissions "/etc/cron.d/pi-signage-updates" "root" "root" "644"
    else
        chmod 644 /etc/cron.d/pi-signage-updates
    fi
    
    log_info "Scripts de mise à jour créés"
}

# =============================================================================
# VALIDATION DE L'INSTALLATION
# =============================================================================

validate_web_installation() {
    log_info "Validation de l'installation web..."
    
    local errors=0
    
    # Vérification des services
    if systemctl is-active nginx >/dev/null 2>&1; then
        log_info "✓ nginx actif"
    else
        log_error "✗ nginx inactif"
        ((errors++))
    fi
    
    if systemctl is-active php8.2-fpm >/dev/null 2>&1; then
        log_info "✓ PHP-FPM actif"
    else
        log_error "✗ PHP-FPM inactif"
        ((errors++))
    fi
    
    # Vérification yt-dlp
    if command -v yt-dlp >/dev/null 2>&1; then
        log_info "✓ yt-dlp installé"
    else
        log_error "✗ yt-dlp manquant"
        ((errors++))
    fi
    
    # Vérification des fichiers
    if [[ -f "$WEB_ROOT/public/index.php" ]]; then
        log_info "✓ Interface web déployée"
    else
        log_error "✗ Interface web manquante"
        ((errors++))
    fi
    
    # Test de l'interface web
    local ip_addr
    ip_addr=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost/" | grep -q "200\|302"; then
        log_info "✓ Interface web accessible"
    else
        log_warn "⚠ Interface web non accessible localement"
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Installation Interface Web ===="
    
    # Chargement de la configuration
    if ! load_config; then
        return 1
    fi
    
    # Étapes d'installation
    local steps=(
        "install_web_server"
        "install_ytdlp"
        "configure_php_fpm"
        "configure_nginx"
        "deploy_web_files"
        "configure_ytdlp_wrapper"
        "configure_sudoers"
        "configure_vlc_http"
        "create_update_scripts"
    )
    
    local failed_steps=()
    
    for step in "${steps[@]}"; do
        log_info "Exécution: $step"
        if ! "$step"; then
            log_error "Échec de l'étape: $step"
            failed_steps+=("$step")
        fi
    done
    
    # Appliquer le patch de correction des assets si nécessaire
    local patch_script="$SCRIPT_DIR/patches/fix-web-interface-assets.sh"
    if [[ -f "$patch_script" ]]; then
        log_info "Application du patch de correction des assets..."
        bash "$patch_script" || log_warn "Patch partiellement appliqué"
    fi
    
    # Validation
    if validate_web_installation; then
        log_info "Interface web installée avec succès"
        
        # Afficher les informations d'accès
        local ip_addr
        ip_addr=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "IP_ADDRESS")
        
        log_info ""
        log_info "Interface web disponible sur:"
        log_info "  URL: http://${ip_addr}/"
        log_info "  Utilisateur: admin"
        log_info "  Mot de passe: (configuré lors de l'installation)"
        log_info ""
        log_info "Fonctionnalités disponibles:"
        log_info "  - Téléchargement YouTube (vos propres vidéos)"
        log_info "  - Gestionnaire de fichiers intégré"
        log_info "  - Contrôle VLC"
        log_info "  - Monitoring système"
        log_info ""
        log_info "Scripts de mise à jour:"
        log_info "  - /opt/scripts/update-ytdlp.sh"
        log_info "  - /opt/scripts/update-web-interface.sh"
    else
        log_warn "Interface web installée avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Installation Interface Web ===="
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