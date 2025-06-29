# 🌐 Pi Signage Web Interface

Interface web moderne pour Pi Signage Digital - Gérez votre digital signage depuis votre navigateur

![Version](https://img.shields.io/badge/Version-2.0.0-blue.svg)
![PHP](https://img.shields.io/badge/PHP-8.2-purple.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 📸 Aperçu

Interface web complète pour gérer votre système Pi Signage Digital avec :
- 📊 Dashboard temps réel
- ⬇️ Téléchargement YouTube (vos propres vidéos)
- 📁 Gestionnaire de fichiers intégré
- 📈 Monitoring système
- 📋 Visualisation des logs
- 🔒 Authentification sécurisée

## 🚀 Installation Rapide

### Prérequis
- Pi Signage Digital installé (modules 01-09)
- nginx et PHP-FPM 8.2 configurés
- yt-dlp installé

### Installation Automatique
```bash
# Via le module 09 du système principal
sudo ./09-web-interface.sh
```

### Installation Manuelle
```bash
# 1. Cloner le repository
git clone https://github.com/votre-username/pi-signage-web.git
cd pi-signage-web

# 2. Copier les fichiers
sudo cp -r * /var/www/pi-signage/

# 3. Définir les permissions
sudo chown -R www-data:www-data /var/www/pi-signage
sudo chmod -R 755 /var/www/pi-signage
sudo chmod -R 775 /var/www/pi-signage/temp

# 4. Configurer nginx (voir ci-dessous)
```

## 📁 Structure des Fichiers

```
pi-signage-web/
├── index.php              # Page de connexion
├── dashboard.php          # Dashboard principal
├── download.php           # Téléchargement YouTube
├── logs.php              # Visualisation des logs
├── logout.php            # Déconnexion
├── includes/             # Fichiers PHP inclus
│   ├── config.php        # Configuration
│   ├── functions.php     # Fonctions utilitaires
│   └── session.php       # Gestion des sessions
├── assets/               # Ressources statiques
│   ├── css/
│   │   └── style.css     # Styles CSS
│   └── js/
│       └── main.js       # JavaScript principal
├── api/                  # Endpoints API
│   └── status.php        # API de statut système
└── temp/                 # Fichiers temporaires
```

## ⚙️ Configuration

### 1. Configuration nginx

Créez `/etc/nginx/sites-available/pi-signage` :

```nginx
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
    
    # Sécurité
    add_header X-Frame-Options "DENY";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    
    # PHP
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }
    
    # Interdire l'accès aux includes
    location ~ ^/includes/ {
        deny all;
    }
    
    # API
    location /api/ {
        try_files $uri $uri/ /api/index.php?$query_string;
    }
}
```

Activez le site :
```bash
sudo ln -s /etc/nginx/sites-available/pi-signage /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 2. Configuration PHP-FPM

Créez `/etc/php/8.2/fpm/pool.d/pi-signage.conf` :

```ini
[pi-signage]
user = www-data
group = www-data
listen = /run/php/php8.2-fpm-pi-signage.sock
listen.owner = www-data
listen.group = www-data

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

php_admin_value[memory_limit] = 64M
php_admin_value[upload_max_filesize] = 100M
php_admin_value[post_max_size] = 100M
php_admin_value[max_execution_time] = 300

php_admin_value[session.save_path] = /var/lib/php/sessions/pi-signage
```

### 3. Configuration des Permissions

```bash
# Permissions sudo pour contrôler VLC
echo 'www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart vlc-signage.service' | sudo tee /etc/sudoers.d/pi-signage-web
sudo chmod 440 /etc/sudoers.d/pi-signage-web
```

### 4. Configuration de l'Application

Éditez `/etc/pi-signage/config.conf` :

```bash
# Authentification web
WEB_ADMIN_USER="admin"
WEB_ADMIN_PASSWORD="votre_mot_de_passe_sécurisé"

# Dossier Google Drive
GDRIVE_FOLDER="Signage"
```

## 🎯 Utilisation

### Accès Initial

1. Ouvrez votre navigateur : `http://[IP_DU_PI]/`
2. Connectez-vous avec les identifiants configurés
3. Par défaut : `admin` / `[mot de passe défini]`

### Fonctionnalités Principales

#### Dashboard
- Vue d'ensemble du système
- Statistiques en temps réel
- Liste des vidéos
- Actions rapides

#### Téléchargement YouTube
1. Cliquez sur "Télécharger" dans le menu
2. Collez l'URL de votre vidéo YouTube
3. Sélectionnez la qualité (480p, 720p, 1080p)
4. Cliquez sur "Télécharger"

⚠️ **Important** : Téléchargez uniquement VOS PROPRES vidéos ou celles dont vous avez les droits.

#### Gestion des Vidéos
- Visualisation de la liste
- Suppression individuelle
- Informations (taille, date)
- Redémarrage automatique de VLC

#### Monitoring
- CPU, RAM, température
- État des services
- Espace disque
- Uptime système

#### Logs
- Visualisation des logs système
- Filtrage par type
- Export possible

## 🔐 Sécurité

### Authentification
- Sessions PHP sécurisées
- Timeout de session (1 heure)
- Protection CSRF
- Rate limiting

### Recommandations
1. **Changez le mot de passe par défaut**
2. **Utilisez HTTPS en production**
3. **Limitez l'accès au réseau local**
4. **Mettez à jour régulièrement**

### Configuration HTTPS (Optionnel)

```bash
# Installation Certbot
sudo apt install certbot python3-certbot-nginx

# Génération du certificat
sudo certbot --nginx -d votre-domaine.com
```

## 🛠️ Personnalisation

### Modifier le Thème

Éditez `assets/css/style.css` :

```css
:root {
    --primary-color: #4CAF50;  /* Couleur principale */
    --bg-dark: #1a1a1a;        /* Fond sombre */
    --bg-light: #2a2a2a;       /* Fond clair */
}
```

### Ajouter des Fonctionnalités

L'architecture modulaire permet d'ajouter facilement :
- Nouveaux endpoints API dans `/api/`
- Nouvelles pages PHP
- Modules JavaScript dans `assets/js/`

## 📊 API Endpoints

### GET /api/status.php
Retourne le statut système en JSON :

```json
{
  "vlc_status": true,
  "disk_usage": {
    "total": 31457280000,
    "used": 14173593600,
    "free": 17283686400,
    "percent": 45
  },
  "system_info": {
    "cpu_usage": 25.5,
    "memory_usage": 62.3,
    "temperature": 52.1,
    "uptime": "5j 12h 34m"
  }
}
```

## 🚨 Dépannage

### L'interface ne s'affiche pas
```bash
# Vérifier nginx
sudo systemctl status nginx
sudo tail -f /var/log/nginx/pi-signage-error.log

# Vérifier PHP-FPM
sudo systemctl status php8.2-fpm
```

### Erreur 500
```bash
# Vérifier les logs PHP
sudo tail -f /var/log/pi-signage/php-error.log

# Vérifier les permissions
ls -la /var/www/pi-signage/
```

### Téléchargement YouTube échoue
```bash
# Mettre à jour yt-dlp
sudo yt-dlp -U

# Test manuel
sudo -u www-data yt-dlp --version
```

## 🔄 Mise à jour

### Mise à jour de l'interface
```bash
cd /var/www/pi-signage
git pull origin main
sudo chown -R www-data:www-data .
```

### Mise à jour yt-dlp (automatique)
Une tâche cron met à jour yt-dlp chaque semaine automatiquement.

## 📝 Changelog

### Version 2.0.0 (2024-01)
- Interface complètement refaite
- Ajout du téléchargement YouTube
- Dashboard temps réel
- Système de logs amélioré
- Authentification renforcée

## 🤝 Contribution

Les contributions sont les bienvenues !

1. Fork le projet
2. Créez votre branche (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## 📄 License

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

- [TinyFileManager](https://github.com/prasathmani/tinyfilemanager) - Gestionnaire de fichiers intégré
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - Téléchargement YouTube
- Communauté Raspberry Pi

---

**Pi Signage Web Interface** - Gérez votre digital signage en toute simplicité ! 🚀