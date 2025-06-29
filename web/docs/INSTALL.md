# 📋 Guide d'Installation Détaillé - Pi Signage Web Interface

## Table des matières

1. [Prérequis](#prérequis)
2. [Installation Automatique](#installation-automatique)
3. [Installation Manuelle](#installation-manuelle)
4. [Configuration Post-Installation](#configuration-post-installation)
5. [Dépannage](#dépannage)
6. [Mise à jour](#mise-à-jour)

## 🔧 Prérequis

### Système requis

- **OS** : Raspberry Pi OS Lite 64-bit (recommandé) ou Debian/Ubuntu
- **Architecture** : ARM (armv7l, aarch64) ou x86_64
- **RAM** : 1GB minimum, 2GB recommandé
- **Stockage** : 8GB minimum d'espace libre

### Logiciels requis

- **nginx** : 1.18+
- **PHP** : 8.0+ (8.2 recommandé)
- **Python** : 3.8+ (pour yt-dlp)
- **Git** : Pour cloner le repository

### Pi Signage Core

L'interface web nécessite que Pi Signage Digital soit déjà installé avec au minimum :
- Module 01 (Configuration système)
- Module 03 (VLC)

## 🚀 Installation Automatique

### Méthode 1 : Script d'installation autonome

```bash
# Télécharger le script d'installation
wget https://raw.githubusercontent.com/votre-username/pi-signage-web/main/install-web.sh

# Rendre exécutable
chmod +x install-web.sh

# Lancer l'installation
sudo ./install-web.sh
```

Le script vous demandera :
- Nom d'utilisateur administrateur
- Mot de passe (minimum 6 caractères)

### Méthode 2 : Via le système Pi Signage principal

Si vous avez déjà installé Pi Signage Digital :

```bash
# Utiliser le module 09
sudo ./09-web-interface.sh
```

## 🔨 Installation Manuelle

### 1. Cloner le repository

```bash
# Se placer dans un répertoire temporaire
cd /tmp

# Cloner le projet
git clone https://github.com/votre-username/pi-signage-web.git
cd pi-signage-web
```

### 2. Installer les dépendances

```bash
# Mettre à jour le système
sudo apt update

# Installer nginx
sudo apt install -y nginx

# Installer PHP et extensions
sudo apt install -y \
    php8.2-fpm \
    php8.2-cli \
    php8.2-common \
    php8.2-json \
    php8.2-curl \
    php8.2-xml \
    php8.2-mbstring \
    php8.2-zip

# Installer Python et pip
sudo apt install -y python3 python3-pip
```

### 3. Installer yt-dlp

```bash
# Méthode recommandée
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
     -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

# Alternative avec pip
pip3 install yt-dlp
```

### 4. Déployer les fichiers web

```bash
# Créer le répertoire web
sudo mkdir -p /var/www/pi-signage

# Copier les fichiers
sudo cp -r src/* /var/www/pi-signage/

# Créer les répertoires nécessaires
sudo mkdir -p /var/www/pi-signage/temp
sudo mkdir -p /var/log/pi-signage
sudo mkdir -p /opt/videos

# Définir les permissions
sudo chown -R www-data:www-data /var/www/pi-signage
sudo chmod -R 755 /var/www/pi-signage
sudo chmod -R 775 /var/www/pi-signage/temp
sudo chown www-data:www-data /opt/videos
```

### 5. Configurer nginx

```bash
# Copier la configuration
sudo cp install/nginx.conf /etc/nginx/sites-available/pi-signage

# Activer le site
sudo ln -s /etc/nginx/sites-available/pi-signage /etc/nginx/sites-enabled/

# Désactiver le site par défaut
sudo rm -f /etc/nginx/sites-enabled/default

# Tester la configuration
sudo nginx -t

# Redémarrer nginx
sudo systemctl restart nginx
```

### 6. Configurer PHP-FPM

```bash
# Copier la configuration du pool
sudo cp install/php-fpm.conf /etc/php/8.2/fpm/pool.d/pi-signage.conf

# Créer le répertoire de sessions
sudo mkdir -p /var/lib/php/sessions/pi-signage
sudo chown www-data:www-data /var/lib/php/sessions/pi-signage
sudo chmod 700 /var/lib/php/sessions/pi-signage

# Redémarrer PHP-FPM
sudo systemctl restart php8.2-fpm
```

### 7. Configurer les permissions sudo

```bash
# Créer le fichier sudoers
echo 'www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart vlc-signage.service' | \
    sudo tee /etc/sudoers.d/pi-signage-web
sudo chmod 440 /etc/sudoers.d/pi-signage-web
```

### 8. Créer la configuration

```bash
# Créer le fichier de configuration
sudo mkdir -p /etc/pi-signage

# Configuration de base
cat << EOF | sudo tee /etc/pi-signage/config.conf
# Configuration Pi Signage Web
WEB_ADMIN_USER="admin"
WEB_ADMIN_PASSWORD="changeme"
GDRIVE_FOLDER="Signage"
VIDEO_DIR="/opt/videos"
EOF

sudo chmod 600 /etc/pi-signage/config.conf
```

## ⚙️ Configuration Post-Installation

### 1. Premier accès

1. Ouvrez votre navigateur : `http://[IP_DU_PI]/`
2. Connectez-vous avec les identifiants par défaut
3. **Important** : Changez immédiatement le mot de passe

### 2. Tester les fonctionnalités

#### Test de connexion
```bash
curl -I http://localhost/
# Devrait retourner HTTP/1.1 302 ou 200
```

#### Test PHP
```bash
echo "<?php phpinfo();" | sudo tee /var/www/pi-signage/test.php
curl http://localhost/test.php | grep "PHP Version"
sudo rm /var/www/pi-signage/test.php
```

#### Test yt-dlp
```bash
sudo -u www-data yt-dlp --version
```

### 3. Configuration HTTPS (Recommandé)

```bash
# Installer Certbot
sudo apt install -y certbot python3-certbot-nginx

# Pour un domaine public
sudo certbot --nginx -d votre-domaine.com

# Pour un certificat auto-signé (réseau local)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/pi-signage.key \
    -out /etc/ssl/certs/pi-signage.crt
```

### 4. Optimisations

#### Limite de mémoire PHP
```bash
# Éditer /etc/php/8.2/fpm/pool.d/pi-signage.conf
php_admin_value[memory_limit] = 128M  # Si vous avez plus de RAM
```

#### Cache nginx
```nginx
# Ajouter dans la configuration nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

## 🔧 Dépannage

### Erreur 502 Bad Gateway

```bash
# Vérifier PHP-FPM
sudo systemctl status php8.2-fpm
sudo systemctl restart php8.2-fpm

# Vérifier le socket
ls -la /run/php/php8.2-fpm-pi-signage.sock
```

### Page blanche

```bash
# Vérifier les logs PHP
sudo tail -f /var/log/pi-signage/php-error.log

# Vérifier les permissions
ls -la /var/www/pi-signage/
sudo chown -R www-data:www-data /var/www/pi-signage
```

### Téléchargement YouTube échoue

```bash
# Mettre à jour yt-dlp
sudo yt-dlp -U

# Test manuel
sudo -u www-data yt-dlp --version

# Vérifier les permissions sur /opt/videos
ls -la /opt/videos
sudo chown www-data:www-data /opt/videos
```

### VLC ne redémarre pas

```bash
# Vérifier sudoers
sudo cat /etc/sudoers.d/pi-signage-web

# Test manuel
sudo -u www-data sudo systemctl restart vlc-signage.service
```

## 🔄 Mise à jour

### Mise à jour de l'interface

```bash
cd /var/www/pi-signage
git pull origin main
sudo chown -R www-data:www-data .
```

### Mise à jour des dépendances

```bash
# yt-dlp
sudo yt-dlp -U

# PHP packages
sudo apt update
sudo apt upgrade php8.2-*
```

### Script de mise à jour automatique

Créez `/usr/local/bin/update-pi-signage-web` :

```bash
#!/bin/bash
echo "Mise à jour Pi Signage Web Interface..."

# Backup
sudo tar -czf /backup/pi-signage-web-$(date +%Y%m%d).tar.gz /var/www/pi-signage

# Update
cd /var/www/pi-signage
git pull origin main

# Permissions
sudo chown -R www-data:www-data .

# Restart services
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

echo "Mise à jour terminée !"
```

```bash
sudo chmod +x /usr/local/bin/update-pi-signage-web
```

## 📊 Vérification finale

Liste de vérification post-installation :

- [ ] Interface accessible via navigateur
- [ ] Authentification fonctionnelle
- [ ] Dashboard affiche les statistiques
- [ ] Téléchargement YouTube fonctionne
- [ ] VLC peut être redémarré depuis l'interface
- [ ] Logs visibles
- [ ] Mot de passe par défaut changé
- [ ] HTTPS configuré (si applicable)

---

Pour plus d'aide, consultez la [documentation principale](../README.md) ou ouvrez une [issue sur GitHub](https://github.com/votre-username/pi-signage-web/issues).