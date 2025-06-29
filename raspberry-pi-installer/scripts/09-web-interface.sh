#!/usr/bin/env bash

# =============================================================================
# Module 09 - Installation Interface Web PHP
# Version: 2.1.0
# Description: Installation de l'interface web de gestion avec téléchargement YouTube
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
        "php8.2-json"
        "php8.2-curl"
        "php8.2-xml"
        "php8.2-mbstring"
        "php8.2-zip"
        "python3-pip"
        "ffmpeg"
    )
    
    # Installation
    if apt-get update && apt-get install -y "${packages[@]}"; then
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
; Note: shell_exec est nécessaire pour le contrôle des services via l'interface web
php_admin_value[disable_functions] = exec,passthru,system,proc_open,popen,curl_multi_exec,parse_ini_file,show_source,eval,file_get_contents,file_put_contents,fpassthru
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
    chown www-data:www-data /var/lib/php/sessions/pi-signage
    chmod 700 /var/lib/php/sessions/pi-signage
    
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
    root /var/www/pi-signage;
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
    
    # Interdire l'accès aux includes
    location ~ ^/includes/ {
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
    
    # API endpoint
    location /api/ {
        try_files $uri $uri/ /api/index.php?$query_string;
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
# DÉPLOIEMENT DES FICHIERS WEB
# =============================================================================

deploy_web_files() {
    log_info "Déploiement des fichiers de l'interface web..."
    
    # Créer la structure de répertoires
    mkdir -p "$WEB_ROOT"/{includes,api,assets,temp}
    
    # Copier les fichiers de configuration PHP depuis les templates
    if [[ -f "$SCRIPT_DIR/templates/web-config.php" ]]; then
        cp "$SCRIPT_DIR/templates/web-config.php" "$WEB_ROOT/includes/config.php"
        
        # Remplacer le placeholder du mot de passe hashé
        if [[ -n "${WEB_ADMIN_PASSWORD_HASH:-}" ]]; then
            sed -i "s|{{WEB_ADMIN_PASSWORD_HASH}}|$WEB_ADMIN_PASSWORD_HASH|g" "$WEB_ROOT/includes/config.php"
        else
            log_error "Mot de passe admin non défini"
            return 1
        fi
        
        log_info "Configuration PHP déployée"
    else
        log_error "Template de configuration manquant"
        return 1
    fi
    
    # Copier les fonctions PHP
    if [[ -f "$SCRIPT_DIR/templates/web-functions.php" ]]; then
        cp "$SCRIPT_DIR/templates/web-functions.php" "$WEB_ROOT/includes/functions.php"
        log_info "Fonctions PHP déployées"
    else
        log_error "Template de fonctions manquant"
        return 1
    fi
    
    # Créer la page d'index de base
    cat > "$WEB_ROOT/index.php" << 'PHP_EOF'
<?php
define('PI_SIGNAGE_WEB', true);
require_once 'includes/config.php';

// Si déjà authentifié, rediriger vers le dashboard
if (checkAuth()) {
    header('Location: dashboard.php');
    exit;
}

// Traitement du formulaire de connexion
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!validateCSRFToken($_POST['csrf_token'] ?? '')) {
        $error = 'Erreur de sécurité. Veuillez réessayer.';
    } else {
        $username = $_POST['username'] ?? '';
        $password = $_POST['password'] ?? '';
        
        if ($username === ADMIN_USERNAME && validatePassword($password)) {
            session_start();
            $_SESSION['authenticated'] = true;
            $_SESSION['username'] = $username;
            $_SESSION['last_activity'] = time();
            
            logActivity('LOGIN_SUCCESS');
            header('Location: dashboard.php');
            exit;
        } else {
            $error = 'Identifiants invalides';
            logActivity('LOGIN_FAILED', $username);
        }
    }
}

session_start();
$csrf_token = generateCSRFToken();
setSecurityHeaders();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi Signage - Connexion</title>
    <style>
        body { font-family: Arial, sans-serif; background: #f0f0f0; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .login-box { background: white; padding: 2rem; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); width: 300px; }
        h1 { text-align: center; color: #333; }
        input { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #ddd; border-radius: 4px; box-sizing: border-box; }
        button { width: 100%; padding: 10px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; }
        button:hover { background: #0056b3; }
        .error { color: #dc3545; text-align: center; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="login-box">
        <h1>Pi Signage</h1>
        <?php if ($error): ?>
            <div class="error"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>
        <form method="post">
            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrf_token) ?>">
            <input type="text" name="username" placeholder="Nom d'utilisateur" required autofocus>
            <input type="password" name="password" placeholder="Mot de passe" required>
            <button type="submit">Se connecter</button>
        </form>
    </div>
</body>
</html>
PHP_EOF

    # API de statut sécurisée
    cat > "$WEB_ROOT/api/status.php" << 'PHP_EOF'
<?php
define('PI_SIGNAGE_WEB', true);
require_once '../includes/config.php';
require_once '../includes/functions.php';

// Vérifier l'authentification
if (!checkAuth()) {
    http_response_code(401);
    exit(json_encode(['error' => 'Unauthorized']));
}

// Protection CSRF pour les requêtes POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);
    if (!validateCSRFToken($data['csrf_token'] ?? '')) {
        http_response_code(403);
        exit(json_encode(['error' => 'CSRF token validation failed']));
    }
}

setSecurityHeaders();
header('Content-Type: application/json');

$status = [
    'vlc_status' => checkServiceStatus('vlc-signage.service'),
    'disk_usage' => checkDiskSpace(),
    'system_info' => getSystemInfo()
];

echo json_encode($status);
PHP_EOF
    
    # Télécharger TinyFileManager
    log_info "Téléchargement de TinyFileManager..."
    if curl -L https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php \
         -o "$WEB_ROOT/filemanager.php"; then
        log_info "TinyFileManager téléchargé"
        
        # Configuration sécurisée de TinyFileManager
        sed -i "s|^\$root_path = .*|\$root_path = '/opt/videos';|" "$WEB_ROOT/filemanager.php"
        sed -i "s|^\$use_auth = .*|\$use_auth = true;|" "$WEB_ROOT/filemanager.php"
        
        # Restreindre les permissions de TinyFileManager
        sed -i "s|^\$edit_files = .*|\$edit_files = false;|" "$WEB_ROOT/filemanager.php"
        sed -i "s|^\$delete_files = .*|\$delete_files = true;|" "$WEB_ROOT/filemanager.php"
        sed -i "s|^\$upload_files = .*|\$upload_files = true;|" "$WEB_ROOT/filemanager.php"
        sed -i "s|^\$create_folders = .*|\$create_folders = false;|" "$WEB_ROOT/filemanager.php"
    else
        log_warn "Échec du téléchargement de TinyFileManager"
    fi
    
    # Permissions sécurisées
    if command -v secure_dir_permissions >/dev/null 2>&1; then
        secure_dir_permissions "$WEB_ROOT" "www-data" "www-data" "750"
        secure_dir_permissions "$WEB_ROOT/temp" "www-data" "www-data" "770"
        secure_dir_permissions "$WEB_ROOT/includes" "www-data" "www-data" "750"
        secure_dir_permissions "$WEB_ROOT/api" "www-data" "www-data" "750"
    else
        chown -R www-data:www-data "$WEB_ROOT"
        chmod -R 750 "$WEB_ROOT"
        chmod -R 770 "$WEB_ROOT/temp"
    fi
    
    log_info "Fichiers web déployés"
}

# =============================================================================
# CONFIGURATION SUDOERS POUR REDÉMARRAGE VLC
# =============================================================================

configure_sudoers() {
    log_info "Configuration des permissions sudo pour l'interface web..."
    
    # Permettre à www-data de redémarrer VLC
    cat > /etc/sudoers.d/pi-signage-web << 'EOF'
# Permettre à l'interface web de contrôler les services
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl start vlc-signage.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl status vlc-signage.service
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

create_update_script() {
    log_info "Création du script de mise à jour yt-dlp..."
    
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
    
    # Ajouter une tâche cron pour mise à jour hebdomadaire
    cat > /etc/cron.d/pi-signage-ytdlp-update << 'EOF'
# Mise à jour hebdomadaire de yt-dlp
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 4 * * 1 root /opt/scripts/update-ytdlp.sh
EOF
    
    # Permissions sécurisées pour cron
    if command -v secure_file_permissions >/dev/null 2>&1; then
        secure_file_permissions "/etc/cron.d/pi-signage-ytdlp-update" "root" "root" "644"
    else
        chmod 644 /etc/cron.d/pi-signage-ytdlp-update
    fi
    
    log_info "Script de mise à jour créé"
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
    if [[ -f "$WEB_ROOT/index.php" ]]; then
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
    log_info "=== DÉBUT: Installation Interface Web ==="
    
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
        "configure_sudoers"
        "configure_vlc_http"
        "create_update_script"
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
    else
        log_warn "Interface web installée avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Installation Interface Web ==="
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