#!/bin/bash

# =============================================================================
# Script de préparation du projet Pi Signage Web pour GitHub
# Ce script organise tous les fichiers dans la structure correcte
# =============================================================================

set -e

echo "=== Préparation du projet Pi Signage Web pour GitHub ==="

# Créer la structure de répertoires
echo "Création de la structure de répertoires..."

mkdir -p pi-signage-web/{src,install,docs,examples}
mkdir -p pi-signage-web/src/{includes,assets,api,temp}
mkdir -p pi-signage-web/src/assets/{css,js,img}
mkdir -p pi-signage-web/docs/screenshots

# Créer le .gitignore
cat > pi-signage-web/.gitignore << 'EOF'
# Logs
*.log
logs/
*.log.*

# Fichiers temporaires
temp/*
!temp/.gitkeep
*.tmp
*.cache

# Configuration locale
config.local.php
.env
.env.local

# IDE et éditeurs
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Backup
*.backup
*.bak
*.old

# Sessions PHP
sessions/
*.sess

# Uploads temporaires
uploads/temp/*

# Fichiers de test
test.php
phpinfo.php

# Documentation build
docs/_build/
*.pdf

# Node (si utilisé pour le build)
node_modules/
npm-debug.log
yarn-error.log
EOF

# Créer le README principal (utiliser le contenu déjà créé)
echo "Création du README principal..."
# Le README.md a déjà été créé dans un artifact précédent

# Créer le fichier .gitkeep pour garder les dossiers vides
touch pi-signage-web/src/temp/.gitkeep

# Créer le fichier LICENSE MIT
cat > pi-signage-web/LICENSE << 'EOF'
MIT License

Copyright (c) 2024 [Votre Nom ou Organisation]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# Créer le fichier nginx de configuration exemple
cat > pi-signage-web/install/nginx.conf << 'EOF'
# Configuration nginx pour Pi Signage Web Interface
# Copier vers /etc/nginx/sites-available/pi-signage

server {
    listen 80;
    listen [::]:80;
    
    server_name _;
    root /var/www/pi-signage;
    index index.php index.html;
    
    # Logs
    access_log /var/log/nginx/pi-signage-access.log;
    error_log /var/log/nginx/pi-signage-error.log;
    
    # Limite upload
    client_max_body_size 100M;
    
    # Headers de sécurité
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Masquer la version nginx
    server_tokens off;
    
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
        fastcgi_read_timeout 300;
    }
    
    # Fichiers statiques avec cache
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # API
    location /api/ {
        try_files $uri $uri/ /api/index.php?$query_string;
    }
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
    limit_req zone=login burst=5 nodelay;
}
EOF

# Créer le fichier PHP-FPM de configuration exemple
cat > pi-signage-web/install/php-fpm.conf << 'EOF'
; Configuration PHP-FPM pour Pi Signage Web Interface
; Copier vers /etc/php/8.2/fpm/pool.d/pi-signage.conf

[pi-signage]
user = www-data
group = www-data
listen = /run/php/php8.2-fpm-pi-signage.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; Configuration du pool
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 500

; Limites PHP
php_admin_value[memory_limit] = 64M
php_admin_value[upload_max_filesize] = 100M
php_admin_value[post_max_size] = 100M
php_admin_value[max_execution_time] = 300
php_admin_value[max_input_time] = 300

; Sécurité
php_admin_value[disable_functions] = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
php_admin_flag[allow_url_fopen] = off
php_admin_flag[allow_url_include] = off
php_admin_flag[expose_php] = off

; Sessions
php_admin_value[session.save_path] = /var/lib/php/sessions/pi-signage
php_admin_value[session.cookie_httponly] = 1
php_admin_value[session.use_only_cookies] = 1
php_admin_value[session.cookie_samesite] = Strict

; Logs
php_admin_value[error_log] = /var/log/pi-signage/php-error.log
php_admin_flag[log_errors] = on
php_admin_flag[display_errors] = off

; Paths
php_admin_value[open_basedir] = /var/www/pi-signage:/tmp:/opt/videos:/var/log/pi-signage:/etc/pi-signage
EOF

# Créer un favicon placeholder
echo "Création du favicon..."
# Créer un favicon base64 simple (carré vert)
echo "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAAbwAAAG8B8aLcQwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAABFSURBVDiNY2AYBaNgFAyEABMD5YDx0MCCjY2N8f///xkYGBj+M1DI8P///zOwsbExYgszMTAwMIxmolEwCkbBcAIAAPZMBkHLq2hTAAAAAElFTkSuQmCC" | base64 -d > pi-signage-web/src/assets/img/favicon.png

# Créer le fichier CONTRIBUTING.md
cat > pi-signage-web/CONTRIBUTING.md << 'EOF'
# Contributing to Pi Signage Web Interface

Nous sommes ravis que vous souhaitiez contribuer au projet Pi Signage Web Interface !

## Comment contribuer

1. **Fork** le repository
2. **Créez** une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. **Committez** vos changements (`git commit -m 'Add some AmazingFeature'`)
4. **Poussez** vers la branche (`git push origin feature/AmazingFeature`)
5. **Ouvrez** une Pull Request

## Standards de code

- PHP : PSR-12
- JavaScript : ESLint avec configuration standard
- CSS : BEM pour les classes

## Tests

Assurez-vous que votre code :
- Ne casse pas les fonctionnalités existantes
- Est testé sur au moins un Raspberry Pi réel
- Respecte les standards de sécurité

## Rapport de bugs

Utilisez les templates d'issues GitHub et incluez :
- Version de Pi Signage
- Modèle de Raspberry Pi
- Description détaillée du problème
- Étapes pour reproduire
- Logs pertinents

Merci pour votre contribution !
EOF

# Créer un script de déploiement
cat > pi-signage-web/deploy.sh << 'EOF'
#!/bin/bash

# Script de déploiement Pi Signage Web Interface
# Usage: ./deploy.sh [adresse_ip_pi]

PI_HOST="${1:-pi@raspberrypi.local}"
REMOTE_PATH="/tmp/pi-signage-web-deploy"

echo "Déploiement vers $PI_HOST..."

# Créer l'archive
tar -czf pi-signage-web.tar.gz src/ install/

# Copier sur le Pi
scp pi-signage-web.tar.gz "$PI_HOST:$REMOTE_PATH/"
scp install-web.sh "$PI_HOST:$REMOTE_PATH/"

# Exécuter l'installation
ssh "$PI_HOST" "cd $REMOTE_PATH && sudo ./install-web.sh"

# Nettoyage
rm pi-signage-web.tar.gz

echo "Déploiement terminé !"
EOF

chmod +x pi-signage-web/deploy.sh

# Créer le fichier .github/workflows/ci.yml pour GitHub Actions
mkdir -p pi-signage-web/.github/workflows
cat > pi-signage-web/.github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  lint:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.2'
        
    - name: PHP Syntax Check
      run: find src -name "*.php" -exec php -l {} \;
      
    - name: Check file permissions
      run: |
        find src -type f -name "*.php" -exec stat -c "%a %n" {} \; | grep -v "644" || true
        
  security:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Security Scan
      run: |
        # Vérifier les mots de passe en dur
        ! grep -r "password\s*=\s*[\"'][^\"']\+[\"']" src/ || exit 1
        
        # Vérifier les fonctions dangereuses
        ! grep -r "eval\s*(" src/ || exit 1
        ! grep -r "system\s*(" src/ || exit 1
EOF

# Message de fin
cat << 'MESSAGE'

=== Structure du projet créée avec succès ! ===

Arborescence créée :
pi-signage-web/
├── .github/
│   └── workflows/
│       └── ci.yml
├── src/
│   ├── index.php
│   ├── dashboard.php
│   ├── download.php
│   ├── logs.php
│   ├── settings.php
│   ├── filemanager.php
│   ├── logout.php
│   ├── includes/
│   │   ├── config.php
│   │   ├── functions.php
│   │   └── session.php
│   ├── assets/
│   │   ├── css/
│   │   │   └── style.css
│   │   ├── js/
│   │   │   └── main.js
│   │   └── img/
│   │       └── favicon.png
│   ├── api/
│   │   ├── status.php
│   │   ├── download.php
│   │   ├── upload.php
│   │   └── videos.php
│   └── temp/
│       └── .gitkeep
├── install/
│   ├── install.sh
│   ├── nginx.conf
│   └── php-fpm.conf
├── docs/
│   ├── INSTALL.md
│   ├── API.md
│   ├── SECURITY.md
│   └── screenshots/
├── examples/
│   └── config.conf.example
├── .gitignore
├── LICENSE
├── README.md
├── CONTRIBUTING.md
├── deploy.sh
└── install-web.sh

Prochaines étapes :
1. Copier tous les fichiers PHP créés dans src/
2. Copier la documentation dans docs/
3. Ajouter des captures d'écran dans docs/screenshots/
4. Initialiser Git : cd pi-signage-web && git init
5. Commit initial : git add . && git commit -m "Initial commit"
6. Créer le repo sur GitHub
7. Pousser : git remote add origin https://github.com/VOTRE_USERNAME/pi-signage-web.git
8. git push -u origin main

N'oubliez pas de :
- Remplacer [Votre Nom ou Organisation] dans LICENSE
- Remplacer votre-username dans les URLs GitHub
- Ajouter des screenshots de l'interface
- Tester l'installation complète sur un Pi réel

Bonne publication sur GitHub ! 🚀
MESSAGE