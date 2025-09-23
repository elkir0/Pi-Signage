#!/bin/bash

# PiSignage v0.9.0 - Script de Configuration Système
# Configuration optimisée pour Raspberry Pi avec GPU et Chromium Kiosk 30+ FPS

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CONFIG_LOG="/tmp/pisignage-config.log"
PISIGNAGE_USER="pi"
PISIGNAGE_GROUP="pi"
PISIGNAGE_DIR="/opt/pisignage"

# Fonction de log
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$CONFIG_LOG"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$CONFIG_LOG"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$CONFIG_LOG"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$CONFIG_LOG"
            ;;
    esac
    echo "[$timestamp] [$level] $message" >> "$CONFIG_LOG"
}

# Configuration du boot Raspberry Pi
configure_raspberry_pi_boot() {
    log "INFO" "Configuration du boot Raspberry Pi..."

    local config_file="/boot/config.txt"
    local backup_file="/boot/config.txt.backup-$(date +%Y%m%d-%H%M%S)"

    # Sauvegarder la configuration existante
    if [[ -f "$config_file" ]]; then
        sudo cp "$config_file" "$backup_file"
        log "INFO" "Sauvegarde: $backup_file"
    fi

    # Configuration GPU optimisée
    log "INFO" "Configuration de la GPU..."

    # Supprime les anciennes configurations GPU si présentes
    sudo sed -i '/# PiSignage GPU Configuration/,/# End PiSignage GPU Configuration/d' "$config_file" 2>/dev/null || true

    # Ajouter la nouvelle configuration GPU optimisée
    cat << 'EOF' | sudo tee -a "$config_file" > /dev/null

# PiSignage GPU Configuration - v0.9.0
# Optimisée pour Chromium Kiosk 30+ FPS

# GPU Memory (128MB optimal pour affichage HD)
gpu_mem=128

# Enable GPU driver
dtoverlay=vc4-fkms-v3d

# GPU overclock pour performance
gpu_freq=500

# HDMI Configuration pour affichage stable
hdmi_group=2
hdmi_mode=82
hdmi_drive=2
hdmi_force_hotplug=1

# Disable overscan pour affichage complet
disable_overscan=1

# Audio via HDMI
hdmi_force_edid_audio=1

# Performance optimizations
arm_freq=1800
over_voltage=6
temp_limit=80

# Enable hardware acceleration
start_x=1

# Camera disabled pour libérer resources
start_gpu_mem=128
camera_auto_detect=0

# End PiSignage GPU Configuration
EOF

    log "SUCCESS" "Configuration GPU appliquée"
    return 0
}

# Configuration de Nginx
configure_nginx() {
    log "INFO" "Configuration de Nginx..."

    local nginx_conf="/etc/nginx/sites-available/pisignage"
    local nginx_default="/etc/nginx/sites-enabled/default"

    # Supprimer la configuration par défaut
    if [[ -f "$nginx_default" ]]; then
        sudo rm "$nginx_default"
        log "INFO" "Configuration Nginx par défaut supprimée"
    fi

    # Créer la configuration PiSignage
    cat << EOF | sudo tee "$nginx_conf" > /dev/null
# PiSignage v0.9.0 - Configuration Nginx optimisée
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root $PISIGNAGE_DIR/web;
    index index.php index.html index.htm;

    server_name _;

    # Optimisations pour Raspberry Pi
    client_max_body_size 100M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    keepalive_timeout 65;
    send_timeout 60s;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/x-javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/xhtml+xml
        application/xml
        font/eot
        font/otf
        font/ttf
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;

    # Cache statique optimisé
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|eot|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # API endpoints
    location /api/ {
        try_files \$uri \$uri/ /api/index.php?\$args;
    }

    # PHP handling
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;

        # Optimisations PHP
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_read_timeout 300;
    }

    # Media files
    location /media/ {
        alias $PISIGNAGE_DIR/media/;
        autoindex on;
        expires 1h;
    }

    # Screenshots
    location /screenshots/ {
        alias $PISIGNAGE_DIR/screenshots/;
        autoindex on;
        expires 5m;
    }

    # Logs
    location /logs/ {
        alias $PISIGNAGE_DIR/logs/;
        autoindex on;
        auth_basic "Logs Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    location ~ /(config|includes|scripts)/ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

    # Activer la configuration
    sudo ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/pisignage"

    # Tester la configuration
    if sudo nginx -t; then
        log "SUCCESS" "Configuration Nginx valide"
    else
        log "ERROR" "Configuration Nginx invalide"
        return 1
    fi

    # Redémarrer Nginx
    sudo systemctl reload nginx
    log "SUCCESS" "Nginx reconfiguré et redémarré"

    return 0
}

# Configuration de PHP
configure_php() {
    log "INFO" "Configuration de PHP 7.4..."

    local php_ini="/etc/php/7.4/fpm/php.ini"
    local php_fpm_conf="/etc/php/7.4/fpm/pool.d/www.conf"

    # Sauvegarder les configurations
    sudo cp "$php_ini" "$php_ini.backup-$(date +%Y%m%d-%H%M%S)"
    sudo cp "$php_fpm_conf" "$php_fpm_conf.backup-$(date +%Y%m%d-%H%M%S)"

    # Optimisations PHP pour Raspberry Pi
    log "INFO" "Application des optimisations PHP..."

    # Configuration php.ini
    sudo sed -i 's/max_execution_time = 30/max_execution_time = 300/' "$php_ini"
    sudo sed -i 's/max_input_time = 60/max_input_time = 300/' "$php_ini"
    sudo sed -i 's/memory_limit = 128M/memory_limit = 256M/' "$php_ini"
    sudo sed -i 's/post_max_size = 8M/post_max_size = 100M/' "$php_ini"
    sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 100M/' "$php_ini"
    sudo sed -i 's/;date.timezone =/date.timezone = Europe\/Paris/' "$php_ini"
    sudo sed -i 's/display_errors = Off/display_errors = On/' "$php_ini"
    sudo sed -i 's/;log_errors = On/log_errors = On/' "$php_ini"
    sudo sed -i 's/;error_log = php_errors.log/error_log = \/var\/log\/php_errors.log/' "$php_ini"

    # OPcache optimisations
    sudo sed -i 's/;opcache.enable=1/opcache.enable=1/' "$php_ini"
    sudo sed -i 's/;opcache.memory_consumption=128/opcache.memory_consumption=64/' "$php_ini"
    sudo sed -i 's/;opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=16/' "$php_ini"
    sudo sed -i 's/;opcache.max_accelerated_files=4000/opcache.max_accelerated_files=2000/' "$php_ini"
    sudo sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=60/' "$php_ini"

    # Configuration PHP-FPM pour Raspberry Pi
    log "INFO" "Configuration PHP-FPM..."

    sudo sed -i 's/pm = dynamic/pm = ondemand/' "$php_fpm_conf"
    sudo sed -i 's/pm.max_children = 5/pm.max_children = 3/' "$php_fpm_conf"
    sudo sed -i 's/pm.start_servers = 2/pm.start_servers = 1/' "$php_fpm_conf"
    sudo sed -i 's/pm.min_spare_servers = 1/pm.min_spare_servers = 1/' "$php_fpm_conf"
    sudo sed -i 's/pm.max_spare_servers = 3/pm.max_spare_servers = 2/' "$php_fpm_conf"
    sudo sed -i 's/;pm.process_idle_timeout = 10s;/pm.process_idle_timeout = 30s;/' "$php_fpm_conf"

    # Redémarrer PHP-FPM
    sudo systemctl restart php7.4-fpm
    log "SUCCESS" "PHP reconfiguré et redémarré"

    return 0
}

# Configuration des utilisateurs et permissions
configure_users_permissions() {
    log "INFO" "Configuration des utilisateurs et permissions..."

    # Créer le répertoire PiSignage
    sudo mkdir -p "$PISIGNAGE_DIR"
    sudo mkdir -p "$PISIGNAGE_DIR"/{web,api,media,logs,screenshots,config}

    # Permissions pour l'utilisateur pi
    sudo chown -R "$PISIGNAGE_USER:$PISIGNAGE_GROUP" "$PISIGNAGE_DIR"
    sudo chmod -R 755 "$PISIGNAGE_DIR"

    # Permissions spéciales pour www-data
    sudo chgrp -R www-data "$PISIGNAGE_DIR/web"
    sudo chgrp -R www-data "$PISIGNAGE_DIR/media"
    sudo chgrp -R www-data "$PISIGNAGE_DIR/logs"
    sudo chgrp -R www-data "$PISIGNAGE_DIR/screenshots"

    # Permissions d'écriture pour les uploads
    sudo chmod -R 775 "$PISIGNAGE_DIR/media"
    sudo chmod -R 775 "$PISIGNAGE_DIR/logs"
    sudo chmod -R 775 "$PISIGNAGE_DIR/screenshots"

    # Ajouter pi au groupe www-data
    sudo usermod -a -G www-data "$PISIGNAGE_USER"

    # Permissions pour les scripts
    if [[ -d "$PISIGNAGE_DIR/scripts" ]]; then
        sudo chmod +x "$PISIGNAGE_DIR/scripts"/*.sh
    fi

    log "SUCCESS" "Permissions configurées"
    return 0
}

# Configuration du service systemd pour PiSignage
configure_pisignage_service() {
    log "INFO" "Configuration du service PiSignage..."

    local service_file="/etc/systemd/system/pisignage.service"

    cat << EOF | sudo tee "$service_file" > /dev/null
[Unit]
Description=PiSignage Digital Signage v0.9.0
After=network.target nginx.service php7.4-fpm.service
Wants=network.target nginx.service php7.4-fpm.service

[Service]
Type=simple
User=$PISIGNAGE_USER
Group=$PISIGNAGE_GROUP
WorkingDirectory=$PISIGNAGE_DIR
ExecStart=/bin/bash $PISIGNAGE_DIR/scripts/start-signage.sh
ExecStop=/bin/bash $PISIGNAGE_DIR/scripts/stop-signage.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Environment variables
Environment=DISPLAY=:0
Environment=PISIGNAGE_ENV=production
Environment=PISIGNAGE_VERSION=0.9.0

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$PISIGNAGE_DIR

[Install]
WantedBy=multi-user.target
EOF

    # Recharger systemd et activer le service
    sudo systemctl daemon-reload
    sudo systemctl enable pisignage.service

    log "SUCCESS" "Service PiSignage configuré"
    return 0
}

# Configuration du mode kiosk Chromium
configure_chromium_kiosk() {
    log "INFO" "Configuration du mode kiosk Chromium..."

    local kiosk_service="/etc/systemd/system/pisignage-kiosk.service"
    local kiosk_script="$PISIGNAGE_DIR/scripts/start-kiosk.sh"

    # Créer le script de démarrage kiosk
    sudo mkdir -p "$PISIGNAGE_DIR/scripts"
    cat << 'EOF' | sudo tee "$kiosk_script" > /dev/null
#!/bin/bash

# PiSignage Kiosk Mode Script - Optimisé 30+ FPS
export DISPLAY=:0

# Attendre que X11 soit prêt
while ! xset q &>/dev/null; do
    echo "Attente de X11..."
    sleep 2
done

# Désactiver l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Masquer le curseur
unclutter -idle 0.1 -root &

# URL de l'interface PiSignage
PISIGNAGE_URL="http://localhost"

# Options Chromium optimisées pour Raspberry Pi 4
CHROMIUM_OPTIONS=(
    --kiosk
    --no-sandbox
    --disable-web-security
    --disable-features=TranslateUI
    --disable-translate
    --disable-infobars
    --disable-suggestions-service
    --disable-save-password-bubble
    --disable-session-crashed-bubble
    --disable-restore-session-state
    --disable-new-tab-first-run
    --disable-first-run-ui
    --disable-background-timer-throttling
    --disable-renderer-backgrounding
    --disable-backgrounding-occluded-windows
    --disable-background-networking
    --disable-sync
    --disable-default-apps
    --disable-extensions
    --disable-plugins
    --disable-preconnect-resource-hints
    --no-first-run
    --no-default-browser-check
    --no-crash-upload
    --incognito
    --window-position=0,0
    --start-maximized
    --enable-gpu
    --enable-gpu-memory-buffer-compositor-resources
    --enable-gpu-memory-buffer-video-frames
    --enable-accelerated-2d-canvas
    --enable-accelerated-video-decode
    --enable-native-gpu-memory-buffers
    --force-gpu-mem-available-mb=64
    --max_old_space_size=128
    --memory-pressure-off
    --aggressive-cache-discard
    --user-data-dir=/tmp/chromium-kiosk
)

echo "Démarrage de Chromium en mode kiosk..."
echo "URL: $PISIGNAGE_URL"

# Démarrer Chromium avec les options optimisées
exec chromium-browser "${CHROMIUM_OPTIONS[@]}" "$PISIGNAGE_URL"
EOF

    sudo chmod +x "$kiosk_script"

    # Créer le service systemd pour le kiosk
    cat << EOF | sudo tee "$kiosk_service" > /dev/null
[Unit]
Description=PiSignage Chromium Kiosk Mode
After=graphical-session.target pisignage.service
Wants=graphical-session.target pisignage.service

[Service]
Type=simple
User=$PISIGNAGE_USER
Group=$PISIGNAGE_GROUP
Environment=DISPLAY=:0
ExecStart=$kiosk_script
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical-session.target
EOF

    # Activer le service (mais pas le démarrer maintenant)
    sudo systemctl daemon-reload
    sudo systemctl enable pisignage-kiosk.service

    log "SUCCESS" "Mode kiosk Chromium configuré"
    return 0
}

# Configuration de l'auto-login
configure_auto_login() {
    log "INFO" "Configuration de l'auto-login..."

    local lightdm_conf="/etc/lightdm/lightdm.conf"

    # Créer ou modifier la configuration LightDM
    if [[ ! -f "$lightdm_conf" ]]; then
        sudo touch "$lightdm_conf"
    fi

    # Supprimer les anciennes configurations
    sudo sed -i '/autologin-user=/d' "$lightdm_conf"
    sudo sed -i '/autologin-user-timeout=/d' "$lightdm_conf"

    # Ajouter la configuration auto-login
    if ! grep -q "\[Seat:\*\]" "$lightdm_conf"; then
        echo "[Seat:*]" | sudo tee -a "$lightdm_conf" > /dev/null
    fi

    cat << EOF | sudo tee -a "$lightdm_conf" > /dev/null
autologin-user=$PISIGNAGE_USER
autologin-user-timeout=0
EOF

    # Configuration pour démarrer X11 automatiquement
    local xinitrc="/home/$PISIGNAGE_USER/.xinitrc"
    cat << 'EOF' | sudo -u "$PISIGNAGE_USER" tee "$xinitrc" > /dev/null
#!/bin/bash

# Démarrer l'environnement de bureau léger
exec startxfce4 &

# Attendre un peu puis démarrer le kiosk
sleep 10
systemctl --user start pisignage-kiosk.service
EOF

    sudo chmod +x "$xinitrc"

    log "SUCCESS" "Auto-login configuré"
    return 0
}

# Configuration du monitoring système
configure_monitoring() {
    log "INFO" "Configuration du monitoring..."

    local monitor_script="$PISIGNAGE_DIR/scripts/monitor-system.sh"

    cat << 'EOF' | sudo tee "$monitor_script" > /dev/null
#!/bin/bash

# Script de monitoring PiSignage
LOG_FILE="/opt/pisignage/logs/system-monitor.log"
INTERVAL=60  # secondes

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # CPU température
    if command -v vcgencmd &>/dev/null; then
        temp=$(vcgencmd measure_temp | cut -d= -f2)
    else
        temp="N/A"
    fi

    # Load average
    load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')

    # Mémoire
    mem_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')

    # Espace disque
    disk_usage=$(df / | awk 'NR==2{printf "%.1f%%", $5}')

    # Services
    nginx_status=$(systemctl is-active nginx 2>/dev/null || echo "inactive")
    php_status=$(systemctl is-active php7.4-fpm 2>/dev/null || echo "inactive")
    pisignage_status=$(systemctl is-active pisignage 2>/dev/null || echo "inactive")

    # Log
    echo "[$timestamp] TEMP:$temp LOAD:$load MEM:$mem_usage DISK:$disk_usage NGINX:$nginx_status PHP:$php_status PISIGNAGE:$pisignage_status" >> "$LOG_FILE"

    sleep $INTERVAL
done
EOF

    sudo chmod +x "$monitor_script"

    # Service systemd pour le monitoring
    local monitor_service="/etc/systemd/system/pisignage-monitor.service"
    cat << EOF | sudo tee "$monitor_service" > /dev/null
[Unit]
Description=PiSignage System Monitor
After=pisignage.service

[Service]
Type=simple
User=$PISIGNAGE_USER
Group=$PISIGNAGE_GROUP
ExecStart=$monitor_script
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable pisignage-monitor.service

    log "SUCCESS" "Monitoring configuré"
    return 0
}

# Configuration finale du système
finalize_system_config() {
    log "INFO" "Finalisation de la configuration système..."

    # Créer les fichiers de log
    sudo mkdir -p "$PISIGNAGE_DIR/logs"
    sudo touch "$PISIGNAGE_DIR/logs/system.log"
    sudo touch "$PISIGNAGE_DIR/logs/error.log"
    sudo touch "$PISIGNAGE_DIR/logs/access.log"

    # Permissions finales
    sudo chown -R "$PISIGNAGE_USER:$PISIGNAGE_GROUP" "$PISIGNAGE_DIR"
    sudo chmod -R 755 "$PISIGNAGE_DIR"
    sudo chmod -R 775 "$PISIGNAGE_DIR/logs"
    sudo chmod -R 775 "$PISIGNAGE_DIR/media"
    sudo chmod -R 775 "$PISIGNAGE_DIR/screenshots"

    # Recharger tous les services
    sudo systemctl daemon-reload

    # Activer les services au démarrage
    sudo systemctl enable nginx
    sudo systemctl enable php7.4-fpm
    sudo systemctl enable pisignage
    sudo systemctl enable pisignage-monitor

    log "SUCCESS" "Configuration système finalisée"
    return 0
}

# Fonction principale
main() {
    echo "PiSignage v0.9.0 - Configuration Système"
    echo "========================================"
    echo

    log "INFO" "Début de la configuration système..."
    log "INFO" "Log détaillé: $CONFIG_LOG"

    # Vérifier les permissions
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log "ERROR" "Permissions sudo requises"
        return 1
    fi

    # Étapes de configuration
    local steps=(
        "configure_raspberry_pi_boot"
        "configure_nginx"
        "configure_php"
        "configure_users_permissions"
        "configure_pisignage_service"
        "configure_chromium_kiosk"
        "configure_auto_login"
        "configure_monitoring"
        "finalize_system_config"
    )

    for step in "${steps[@]}"; do
        log "INFO" "Exécution: $step"
        if ! $step; then
            log "ERROR" "Échec à l'étape: $step"
            return 1
        fi
        echo
    done

    log "SUCCESS" "Configuration système terminée avec succès"
    log "INFO" "Redémarrage requis pour appliquer toutes les modifications"
    log "INFO" "Commande: sudo reboot"

    return 0
}

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi