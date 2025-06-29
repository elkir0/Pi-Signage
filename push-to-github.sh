#!/bin/bash

# Script de réorganisation et push vers GitHub pour Pi Signage
# À exécuter depuis le dossier "Pi Signage Digital"

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
CURRENT_DIR=$(pwd)
BACKUP_DIR="${CURRENT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${GREEN}=== Script de réorganisation Pi Signage pour GitHub ===${NC}"

# Vérifier qu'on est dans le bon dossier
if [[ ! -d "web" ]] || [[ ! -f "01-system-config.sh" ]]; then
    echo -e "${RED}Erreur: Ce script doit être exécuté depuis le dossier 'Pi Signage Digital'${NC}"
    exit 1
fi

# 1. Créer une sauvegarde
echo -e "\n${YELLOW}1. Création d'une sauvegarde...${NC}"
cp -r "$CURRENT_DIR" "$BACKUP_DIR"
echo -e "${GREEN}✓ Sauvegarde créée dans: $BACKUP_DIR${NC}"

# 2. Créer la nouvelle structure
echo -e "\n${YELLOW}2. Création de la nouvelle structure...${NC}"
mkdir -p raspberry-pi-installer/{scripts,install,docs,examples}
mkdir -p web/install

# 3. Déplacer les scripts d'installation Raspberry Pi
echo -e "\n${YELLOW}3. Déplacement des scripts Raspberry Pi...${NC}"
# Scripts principaux
mv 0*-*.sh raspberry-pi-installer/scripts/ 2>/dev/null || true
mv main_orchestrator.sh raspberry-pi-installer/scripts/ 2>/dev/null || true

# Fichiers install
if [[ -f "install/install.sh" ]]; then
    mv install/install.sh raspberry-pi-installer/
fi
if [[ -f "install/pi-signage-github-setup.sh" ]]; then
    mv install/pi-signage-github-setup.sh raspberry-pi-installer/
fi

# Documentation spécifique Raspberry Pi
for doc in README.md quickstart_guide.md technical_guide.md; do
    if [[ -f "$doc" ]]; then
        cp "$doc" raspberry-pi-installer/docs/
    fi
done

# Exemple de configuration
if [[ -f "example/config.conf.txt" ]]; then
    mv example/config.conf.txt raspberry-pi-installer/examples/config.conf.example
fi

# 4. Organiser l'interface web
echo -e "\n${YELLOW}4. Organisation de l'interface web...${NC}"
# L'interface web est déjà dans le bon dossier, on ajoute juste les fichiers de config
cat > web/install/nginx.conf << 'EOF'
# Configuration nginx pour Pi Signage Web Interface
# À placer dans /etc/nginx/sites-available/pi-signage

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    # Nom du serveur
    server_name _;
    
    # Racine du site
    root /var/www/pi-signage;
    
    # Index
    index index.php index.html;
    
    # Logs
    access_log /var/log/nginx/pi-signage.access.log;
    error_log /var/log/nginx/pi-signage.error.log;
    
    # Taille max upload (pour les vidéos)
    client_max_body_size 500M;
    client_body_timeout 300s;
    
    # Sécurité - Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Gestion des fichiers statiques
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Bloquer l'accès aux fichiers sensibles
    location ~ /\. {
        deny all;
    }
    
    location ~ /includes/ {
        deny all;
    }
    
    location ~ /temp/ {
        deny all;
    }
    
    # PHP
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        # Vérifier que le fichier existe
        try_files $uri =404;
        
        # FastCGI
        fastcgi_pass unix:/run/php/php8.2-fpm-pi-signage.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Timeouts pour les longs téléchargements
        fastcgi_read_timeout 300s;
        fastcgi_send_timeout 300s;
    }
    
    # API endpoints avec support SSE
    location ~ ^/api/ {
        # Headers pour Server-Sent Events
        add_header Cache-Control "no-cache";
        add_header X-Accel-Buffering "no";
        
        try_files $uri $uri/ =404;
        
        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.2-fpm-pi-signage.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
            
            # Désactiver la mise en buffer pour SSE
            fastcgi_buffering off;
            fastcgi_keep_conn on;
        }
    }
}
EOF

cat > web/install/php-fpm.conf << 'EOF'
; Configuration du pool PHP-FPM pour Pi Signage
; À placer dans /etc/php/8.2/fpm/pool.d/pi-signage.conf

[pi-signage]
; Nom du pool
; Utilisé pour les logs et la socket

; Utilisateur et groupe
user = www-data
group = www-data

; Socket Unix (plus rapide que TCP)
listen = /run/php/php8.2-fpm-pi-signage.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; Gestion des processus
; 'dynamic' = nombre de processus variable selon la charge
pm = dynamic

; Nombre maximum de processus enfants
pm.max_children = 10

; Nombre de processus au démarrage
pm.start_servers = 2

; Nombre minimum de processus en attente
pm.min_spare_servers = 1

; Nombre maximum de processus en attente
pm.max_spare_servers = 3

; Nombre de requêtes avant recyclage du processus
pm.max_requests = 500

; Timeout pour les requêtes
request_terminate_timeout = 300s

; Logs des requêtes lentes (debug)
slowlog = /var/log/php/8.2/fpm-pi-signage-slow.log
request_slowlog_timeout = 10s

; Variables d'environnement
env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp

; Configuration PHP spécifique à ce pool
; Limites mémoire
php_admin_value[memory_limit] = 256M
php_admin_value[post_max_size] = 500M
php_admin_value[upload_max_filesize] = 500M
php_admin_value[max_file_uploads] = 20

; Temps d'exécution
php_admin_value[max_execution_time] = 300
php_admin_value[max_input_time] = 300

; Sessions
php_admin_value[session.save_path] = /var/lib/php/sessions/pi-signage
php_admin_value[session.gc_maxlifetime] = 3600
php_admin_value[session.cookie_httponly] = 1

; Sécurité
php_admin_value[expose_php] = 0
php_admin_value[display_errors] = 0
php_admin_value[log_errors] = 1
php_admin_value[error_log] = /var/log/pi-signage/php-error.log

; Open basedir - Restriction d'accès aux fichiers
php_admin_value[open_basedir] = /var/www/pi-signage:/tmp:/usr/bin:/opt/videos:/var/log/pi-signage

; Configuration pour les téléchargements longs
php_admin_value[ignore_user_abort] = 1
php_admin_value[output_buffering] = 0

; Timezone
php_admin_value[date.timezone] = Europe/Paris
EOF

# 5. Créer un nouveau README principal
echo -e "\n${YELLOW}5. Création du README principal...${NC}"
cat > README.md << 'EOF'
# 📺 Pi Signage Digital - Solution Complète

**Solution tout-en-un de digital signage pour Raspberry Pi avec interface web de gestion**

[![Compatible](https://img.shields.io/badge/Compatible-Pi%203B%2B%20%7C%204B%20%7C%205-green.svg)](https://www.raspberrypi.org/)
[![Version](https://img.shields.io/badge/Version-2.0.0-blue.svg)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)]()

## 🎯 Présentation

Pi Signage Digital est une solution professionnelle complète pour transformer vos Raspberry Pi en système d'affichage dynamique. Ce repository contient :

- **Installation automatisée pour Raspberry Pi** : Scripts modulaires pour configurer votre Pi
- **Interface web de gestion** : Dashboard moderne pour contrôler vos écrans à distance

## 📁 Structure du Projet

```
Pi-Signage/
├── raspberry-pi-installer/    # Scripts d'installation et configuration Raspberry Pi
│   ├── scripts/              # Modules d'installation
│   ├── docs/                 # Documentation technique
│   └── examples/             # Fichiers de configuration exemple
│
└── web/                      # Interface web de gestion
    ├── src/                  # Code source PHP
    ├── api/                  # Endpoints API
    ├── assets/               # CSS, JS, images
    └── install/              # Scripts d'installation web
```

## 🚀 Installation Rapide

### 1. Sur le Raspberry Pi

```bash
# Cloner le repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/raspberry-pi-installer

# Lancer l'installation
chmod +x install.sh
sudo ./install.sh
```

### 2. Interface Web (optionnelle)

```bash
cd ../web/install
sudo ./install-web.sh
```

## 📖 Documentation

- **[Guide d'installation Raspberry Pi](raspberry-pi-installer/docs/README.md)**
- **[Guide de démarrage rapide](raspberry-pi-installer/docs/quickstart_guide.md)**
- **[Documentation interface web](web/docs/INSTALL.md)**
- **[Guide technique complet](raspberry-pi-installer/docs/technical_guide.md)**

## ✨ Fonctionnalités

### Système Raspberry Pi
- ✅ Lecture vidéos en boucle avec rotation aléatoire
- ✅ Synchronisation automatique Google Drive
- ✅ Installation modulaire en ~50 minutes
- ✅ Surveillance et récupération automatique
- ✅ Support multi-écrans

### Interface Web
- ✅ Dashboard temps réel
- ✅ Téléchargement YouTube direct
- ✅ Gestion des vidéos
- ✅ Visualisation des logs
- ✅ Contrôle à distance sécurisé

## 🛠️ Configuration Requise

- **Raspberry Pi** : 3B+, 4B (2GB+) ou 5
- **Carte SD** : 32GB minimum
- **OS** : Raspberry Pi OS Lite 64-bit
- **Réseau** : Connexion internet requise

## 🔧 Commandes Principales

```bash
# Sur le Raspberry Pi
sudo pi-signage status          # État des services
sudo pi-signage-diag           # Diagnostic complet
sudo pi-signage emergency      # Récupération d'urgence

# Synchronisation manuelle
sudo /opt/scripts/sync-videos.sh
```

## 📊 Interface Web

Accès : `http://[IP_DU_PI]/` ou `http://[IP_DU_PI]:61208` pour Glances

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- 🐛 Signaler des bugs
- 💡 Proposer des améliorations
- 🔧 Soumettre des pull requests

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

Merci à tous les contributeurs et à la communauté Raspberry Pi !

---

**Pi Signage Digital** - Transformez vos Raspberry Pi en système d'affichage professionnel 🚀
EOF

# 6. Créer/mettre à jour .gitignore
echo -e "\n${YELLOW}6. Création du .gitignore...${NC}"
cat > .gitignore << 'EOF'
# Logs
*.log
logs/

# Fichiers temporaires
temp/*
!temp/.gitkeep
*.tmp
*.temp

# Configuration locale
config.local.php
.env
*.conf.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Backup
*.backup
*.bak
*_backup_*

# Sessions PHP
sessions/

# Vidéos (trop lourdes pour Git)
*.mp4
*.avi
*.mkv
*.mov
*.wmv

# Archives
*.zip
*.tar.gz
*.rar

# Node modules (si ajout futur)
node_modules/

# Python
__pycache__/
*.pyc
venv/
EOF

# 7. Nettoyer les anciens dossiers vides
echo -e "\n${YELLOW}7. Nettoyage...${NC}"
find . -type d -empty -delete 2>/dev/null || true

# 8. Initialiser Git et configurer le remote
echo -e "\n${YELLOW}8. Initialisation Git...${NC}"
# Supprimer l'ancien .git s'il existe
rm -rf .git

# Initialiser un nouveau repository
git init

# Ajouter tous les fichiers
git add .

# Commit initial
git commit -m "Refactoring complet - Structure unifiée Pi Signage v2.0.0

- Réorganisation en deux modules principaux :
  - raspberry-pi-installer/ : Scripts d'installation Raspberry Pi
  - web/ : Interface web de gestion
- Ajout des fichiers de configuration nginx et php-fpm
- Documentation complète et unifiée
- Structure prête pour déploiement"

# Ajouter le remote GitHub
git remote add origin $GITHUB_REPO

# 9. Push vers GitHub
echo -e "\n${YELLOW}9. Push vers GitHub...${NC}"
echo -e "${YELLOW}Attention: Le push va écraser le contenu actuel du repository !${NC}"
read -p "Voulez-vous continuer ? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Forcer le push (écrase l'historique distant)
    git push -u origin main --force
    echo -e "${GREEN}✓ Push terminé avec succès !${NC}"
else
    echo -e "${YELLOW}Push annulé. Pour pusher plus tard :${NC}"
    echo "git push -u origin main --force"
fi

# 10. Résumé
echo -e "\n${GREEN}=== Réorganisation terminée ! ===${NC}"
echo -e "Structure créée :"
echo -e "  ${GREEN}✓${NC} raspberry-pi-installer/ - Scripts d'installation"
echo -e "  ${GREEN}✓${NC} web/ - Interface web"
echo -e "\nSauvegarde disponible dans : $BACKUP_DIR"
echo -e "\nRepository GitHub : $GITHUB_REPO"
echo -e "\nProchaines étapes :"
echo -e "1. Vérifier le repository : https://github.com/elkir0/Pi-Signage"
echo -e "2. Ajouter des tags : git tag -a v2.0.0 -m 'Version 2.0.0' && git push --tags"
echo -e "3. Créer une release sur GitHub"
