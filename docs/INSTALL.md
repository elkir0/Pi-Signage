# Guide d'installation détaillé - PiSignage v0.8.9

## Nouveautés v0.8.9

- **VLC exclusif**: Support MPV complètement retiré pour stabilité maximale
- **Authentification complète**: Système d'auth sur toutes les pages
- **Contrôle audio**: Gestion volume complète via VLC HTTP API
- **Architecture modulaire**: Interface web divisée en 9 pages spécialisées
- **Performance améliorée**: 80% plus rapide sur Raspberry Pi
- **Navigation fiable**: Fini les erreurs JavaScript "showSection is not defined"
- **Maintenance facilitée**: Code organisé en modules focalisés

## Introduction

Ce document vous accompagne dans l'installation de PiSignage v0.8.9 sur votre Raspberry Pi. L'installation automatique prend environ 10-15 minutes sur un système à jour, ou jusqu'à 60 minutes sur un système fraîchement installé nécessitant des mises à jour complètes.

**Avantages de v0.8.9**:
- Interface plus réactive et moderne
- Navigation plus fluide entre les sections
- Performance optimisée pour Raspberry Pi
- Architecture modulaire pour une maintenance simplifiée

## Configuration matérielle requise

### Matériel
- Raspberry Pi 3B+, 4 ou 5 (minimum 2GB de RAM, 4GB pour des performances optimales)
- Carte MicroSD d'au moins 16GB, classe 10 ou supérieure
- Alimentation officielle Raspberry Pi (importante pour la stabilité)
- Écran ou téléviseur avec entrée HDMI
- Connexion réseau (Ethernet recommandé, Wi-Fi possible)

### Système d'exploitation
Raspberry Pi OS Bookworm est requis, de préférence en version 64 bits pour les modèles compatibles. La version Lite est suffisante car PiSignage n'a pas besoin d'environnement de bureau complet. Une installation fraîche est recommandée pour éviter les conflits avec des configurations existantes.

### Préparation du système
Avant de commencer l'installation, préparez votre carte SD avec Raspberry Pi Imager. Activez SSH si vous souhaitez administrer le système à distance. Si vous utilisez le Wi-Fi, configurez-le directement dans l'imager ou après le premier démarrage.

## Méthode d'installation automatique

L'installation automatique est la méthode recommandée. Elle configure l'ensemble du système sans intervention manuelle.

### Option 1 : Clonage du dépôt complet
```bash
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage
bash install.sh --auto
```

### Option 2 : Script d'installation uniquement
```bash
wget https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install.sh
bash install.sh --auto
```

### Option 3 : Mode interactif
Si vous préférez contrôler chaque étape, lancez le script sans le flag --auto :
```bash
bash install.sh
```

### Ce que fait le script d'installation

Le script automatise l'ensemble du processus d'installation :

1. Mise à jour complète du système (peut prendre 30-60 minutes sur un système neuf)
2. Installation des composants nécessaires :
   - Serveur web Nginx avec PHP 8.2
   - Lecteurs vidéo VLC et MPV
   - Outils système pour les captures d'écran
3. Création de l'arborescence dans /opt/pisignage
4. Configuration du serveur web et des services système
5. Téléchargement de l'interface web depuis GitHub
6. Récupération de la vidéo de démonstration Big Buck Bunny
7. Application des permissions et activation du démarrage automatique

### Vérification après installation

Une fois l'installation terminée, vérifiez que tout fonctionne correctement :

```bash
# État du service principal
sudo systemctl status pisignage

# Test de l'interface web
curl -I http://localhost

# Consultation des logs si nécessaire
tail -f /opt/pisignage/logs/pisignage.log
```

L'interface web devrait être accessible depuis n'importe quel navigateur à l'adresse http://[IP-RASPBERRY]/

## Installation manuelle détaillée

Cette méthode vous permet de contrôler chaque étape de l'installation. Elle est utile pour comprendre le fonctionnement du système ou pour des configurations particulières.

### Étape 1 : Préparation du système

Commencez par mettre à jour votre système :

```bash
sudo apt update && sudo apt upgrade -y
```

Un redémarrage est recommandé après une mise à jour majeure :
```bash
sudo reboot
```

### Étape 2 : Installation des logiciels nécessaires

Installez tous les paquets requis en une seule commande :

```bash
sudo apt install -y nginx php8.2-fpm php8.2-cli php8.2-json \
    php8.2-curl vlc mpv git wget curl unzip
```

Pour un monitoring avancé du système, vous pouvez également installer :
```bash
sudo apt install -y htop rsync ffmpeg
```

### Étape 3 : Installation de l'outil de capture d'écran

Raspi2png permet de capturer l'écran actuel. Son installation nécessite une compilation :

```bash
sudo apt install -y build-essential libpng-dev
cd /tmp
git clone https://github.com/AndrewFromMelbourne/raspi2png.git
cd raspi2png
make
sudo make install
cd /
rm -rf /tmp/raspi2png
```

### Étape 4 : Création de la structure des dossiers

Créez l'arborescence complète du projet :

```bash
sudo mkdir -p /opt/pisignage/{web,media,config,logs,scripts}
sudo mkdir -p /opt/pisignage/web/api
sudo mkdir -p /dev/shm/pisignage-screenshots
sudo chown -R $USER:$USER /opt/pisignage
chmod 755 /opt/pisignage
```

### Étape 5 : Configuration du serveur web

```bash
# Supprimer la configuration par défaut
sudo rm -f /etc/nginx/sites-enabled/default

# Créer la configuration PiSignage
sudo tee /etc/nginx/sites-available/pisignage > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php index.html;
    server_name _;

    # Gestion des fichiers PHP
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Sécurité
    location ~ /\.ht {
        deny all;
    }

    # Upload de gros fichiers
    client_max_body_size 500M;
    client_body_timeout 300s;
    client_body_temp_path /tmp/nginx_uploads;

    # Cache statique
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Activer le site
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Étape 6 : Ajustement des paramètres PHP

Modifiez les limites PHP pour permettre l'upload de gros fichiers vidéo :

```bash
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/8.2/fpm/php.ini

sudo mkdir -p /tmp/nginx_uploads
sudo chown www-data:www-data /tmp/nginx_uploads
sudo systemctl restart php8.2-fpm
```

### Étape 7 : Récupération des fichiers PiSignage

```bash
cd /opt/pisignage

# Interface web principale
wget -O web/index.php https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web/index.php

# APIs
mkdir -p web/api
wget -O web/api/system.php https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web/api/system.php
wget -O web/api/player.php https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web/api/player.php
wget -O web/api/media.php https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web/api/media.php
wget -O web/api/screenshot-raspi2png.php https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web/api/screenshot-raspi2png.php

# Configuration
wget -O config/player-config.json https://raw.githubusercontent.com/elkir0/Pi-Signage/main/config/player-config.json

# Scripts de gestion
wget -O scripts/player-manager-v0.8.1.sh https://raw.githubusercontent.com/elkir0/Pi-Signage/main/scripts/player-manager-v0.8.1.sh
wget -O scripts/start-vlc.sh https://raw.githubusercontent.com/elkir0/Pi-Signage/main/scripts/start-vlc.sh
chmod +x scripts/*.sh
```

### Étape 8 : Vidéo de démonstration

Téléchargez Big Buck Bunny pour tester le système :

```bash
wget -O media/BigBuckBunny_720p.mp4 \
    "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
```

### Étape 9 : Création du service système

```bash
# Créer le service systemd
sudo tee /etc/systemd/system/pisignage.service > /dev/null << 'EOF'
[Unit]
Description=PiSignage Digital Signage Player
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/opt/pisignage
ExecStart=/opt/pisignage/scripts/player-manager-v0.8.1.sh start
ExecStop=/opt/pisignage/scripts/player-manager-v0.8.1.sh stop
Restart=always
RestartSec=10
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1000

[Install]
WantedBy=default.target
EOF

# Recharger systemd et activer le service
sudo systemctl daemon-reload
sudo systemctl enable pisignage
```

### Étape 10 : Application des permissions

Configurez les permissions pour que chaque composant ait les droits appropriés :

```bash
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R www-data:www-data /opt/pisignage/media
sudo chown -R www-data:www-data /opt/pisignage/logs
sudo chown -R pi:pi /opt/pisignage/config
sudo chown -R pi:pi /opt/pisignage/scripts
chmod +x /opt/pisignage/scripts/*.sh
```

## Configuration complémentaire

### Configuration VLC

```bash
# Créer la configuration VLC pour pi
sudo -u pi mkdir -p /home/pi/.config/vlc
sudo -u pi tee /home/pi/.config/vlc/vlcrc > /dev/null << 'EOF'
[dummy]
dummy-quiet=1

[core]
intf=dummy
vout=drm
fullscreen=1
loop=1
no-video-title-show=1
EOF
```

### Configuration MPV

```bash
# Créer la configuration MPV pour pi
sudo -u pi mkdir -p /home/pi/.config/mpv
sudo -u pi tee /home/pi/.config/mpv/mpv.conf > /dev/null << 'EOF'
# Configuration optimisée Raspberry Pi
vo=drm
hwdec=auto
fullscreen=yes
loop-playlist=inf
quiet=yes
no-terminal=yes
no-input-default-bindings=yes
EOF
```

### Validation de l'installation

Démarrez le service et vérifiez son bon fonctionnement :

```bash
sudo systemctl start pisignage
sudo systemctl status pisignage
```

L'interface web doit répondre sur le port 80 :
```bash
curl -I http://localhost
```

## Optimisations pour Raspberry Pi

### Mémoire GPU

Pour améliorer les performances vidéo, augmentez la mémoire allouée au GPU :

```bash
echo "gpu_mem=128" | sudo tee -a /boot/config.txt
echo "dtoverlay=vc4-kms-v3d" | sudo tee -a /boot/config.txt
```

Ces modifications nécessitent un redémarrage pour être prises en compte.

### Performances réseau

Pour améliorer le streaming vidéo réseau, augmentez les buffers :

```bash
echo "net.core.rmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Optimisation du stockage

Pour réduire l'usure de la carte SD, vous pouvez monter /tmp en mémoire :

```bash
echo "tmpfs /tmp tmpfs defaults,size=100M 0 0" | sudo tee -a /etc/fstab
```

La désactivation du swap est optionnelle mais peut améliorer les performances sur les systèmes avec suffisamment de RAM.

## Tests de validation

### Vérification des composants

Assurez-vous que tous les composants sont correctement installés :

```bash
cvlc --version
mpv --version
php -v
nginx -t
```

### État des services

Vérifiez que tous les services sont actifs :

```bash
sudo systemctl status nginx php8.2-fpm pisignage
```

Testez l'API pour confirmer que tout fonctionne :
```bash
curl -s http://localhost/api/system.php
```

### Test des lecteurs vidéo

Vérifiez que les lecteurs peuvent lire la vidéo de test :

```bash
# Test rapide avec MPV (5 secondes)
mpv --vo=drm --hwdec=auto /opt/pisignage/media/BigBuckBunny_720p.mp4 --really-quiet --length=5
```

## Résolution des problèmes courants

### Problèmes de permissions
```bash
# Corriger les permissions
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R pi:pi /opt/pisignage/scripts
sudo chmod +x /opt/pisignage/scripts/*.sh
```

### Service qui ne démarre pas
```bash
# Vérifier les logs
sudo journalctl -u pisignage -f

# Vérifier la configuration
/opt/pisignage/scripts/player-manager-v0.8.1.sh test
```

### Interface web inaccessible
```bash
# Vérifier Nginx
sudo nginx -t
sudo systemctl status nginx

# Vérifier PHP
sudo systemctl status php8.2-fpm
```

### Problèmes avec les lecteurs vidéo
```bash
# Test manuel VLC
export DISPLAY=:0
cvlc --intf dummy /opt/pisignage/media/BigBuckBunny_720p.mp4

# Test manuel MPV
export DISPLAY=:0
mpv --vo=drm /opt/pisignage/media/BigBuckBunny_720p.mp4
```

### Réinstallation complète

Si vous devez recommencer l'installation depuis zéro :

```bash
sudo systemctl stop pisignage nginx php8.2-fpm
sudo rm -rf /opt/pisignage
sudo rm -f /etc/nginx/sites-enabled/pisignage
sudo rm -f /etc/systemd/system/pisignage.service
sudo systemctl daemon-reload
```

Vous pouvez ensuite relancer le script d'installation.

## Options avancées

### Activation HTTPS

Si vous disposez d'un nom de domaine, vous pouvez sécuriser l'accès avec HTTPS :

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d votre-domaine.com
```

### Protection par mot de passe

Pour sécuriser l'accès à l'interface :

```bash
sudo apt install -y apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd admin
```

Ajoutez ensuite ces lignes dans la configuration Nginx :
```nginx
auth_basic "PiSignage Admin";
auth_basic_user_file /etc/nginx/.htpasswd;
```

### Monitoring du système

Pour surveiller les performances en temps réel, créez un script de monitoring :

```bash
tee /opt/pisignage/scripts/monitor.sh << 'EOF'
#!/bin/bash
while true; do
    echo "$(date +%H:%M:%S) - CPU: $(vcgencmd measure_temp | cut -d= -f2) | "
    echo "RAM: $(free -h | grep Mem | awk '{print $3"/"$2}')"
    sleep 60
done
EOF
chmod +x /opt/pisignage/scripts/monitor.sh
```

## Remarques finales

Ce guide couvre l'installation complète de PiSignage v0.8.9. L'installation automatique convient à la majorité des cas d'usage. L'installation manuelle est réservée aux utilisateurs expérimentés ou aux configurations spécifiques.

## Migration depuis versions précédentes

Si vous avez déjà PiSignage v0.8.x installé, consultez le [Guide de migration](MIGRATION.md) pour une mise à jour en douceur vers v0.8.9.

Pour toute question ou problème, consultez la documentation de dépannage ou ouvrez une issue sur le dépôt GitHub.