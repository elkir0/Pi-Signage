#!/bin/bash

# Module d'installation des composants web
# Version: 1.0

MODULE_NAME="Web Components"
LOG_FILE="/opt/pisignage/logs/install-web.log"

echo "=== Installation du module: $MODULE_NAME ===" | tee -a "$LOG_FILE"

# Installation du serveur web et PHP
install_web_server() {
    echo "Installation du serveur web..." | tee -a "$LOG_FILE"
    
    apt-get install -y \
        nginx \
        php-fpm \
        php-cli \
        php-json \
        php-mbstring \
        php-curl \
        php-xml
    
    echo "Serveur web installé" | tee -a "$LOG_FILE"
}

# Configuration de nginx
configure_nginx() {
    echo "Configuration de nginx..." | tee -a "$LOG_FILE"
    
    # Création de la configuration nginx pour PiSignage
    cat > /etc/nginx/sites-available/pisignage << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /opt/pisignage/web;
    index index.php index.html index.htm;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    
    location /media/ {
        alias /opt/pisignage/media/;
        autoindex on;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
    
    # Activation du site
    ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    echo "Configuration nginx terminée" | tee -a "$LOG_FILE"
}

# Configuration des permissions web
configure_web_permissions() {
    echo "Configuration des permissions web..." | tee -a "$LOG_FILE"
    
    # Permissions pour le répertoire web
    chown -R www-data:www-data /opt/pisignage/web
    chmod -R 755 /opt/pisignage/web
    
    # Permissions pour les logs
    chown -R www-data:www-data /opt/pisignage/logs
    chmod -R 755 /opt/pisignage/logs
    
    echo "Permissions web configurées" | tee -a "$LOG_FILE"
}

# Fonction principale
main() {
    install_web_server
    configure_nginx
    configure_web_permissions
    
    # Redémarrage des services
    systemctl restart nginx
    systemctl restart php*-fpm
    systemctl enable nginx
    systemctl enable php*-fpm
    
    echo "Module $MODULE_NAME installé avec succès" | tee -a "$LOG_FILE"
}

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi