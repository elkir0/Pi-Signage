# Guide d'installation détaillé - Zaforge v0.12.0

## Nouveautés v0.12.0

- **Moteur unique Chromium HTML5**: VLC retiré ; le lecteur est `web/player.php` servi sur `/player`, affiché en kiosk par Chromium
- **Session graphique lightdm**: autologin de l'utilisateur `pi` → compositeur Wayland labwc → Chromium `--kiosk http://127.0.0.1/player`
- **Contrôle du lecteur via API web**: `web/api/display.php` (commandes next/prev/play/pause/reload, état live)
- **Volume système ALSA**: contrôle audio via `web/api/system.php` (set_volume/get_volume/toggle_mute) — plus de volume VLC
- **Playlists unifiées**: une seule source de vérité (`web/api/playlists.php`) + bouton « Diffuser à l'écran »
- **Programmation réelle (dayparting)**: exécuteur CLI `web/api/scheduler.php` lancé par cron 1×/minute
- **yt-dlp géré**: binaire dans `/opt/pisignage/bin`, mise à jour 1-clic depuis l'UI
- **Refonte UI**: design system clair/sombre, icônes SVG (aucun emoji), overlay d'infos vidéo
- **Performance améliorée**: optimisée pour Raspberry Pi 4/5

## Introduction

Ce document vous accompagne dans l'installation de Zaforge v0.12.0 sur votre Raspberry Pi. L'installation automatique prend environ 10-15 minutes sur un système à jour, ou jusqu'à 60 minutes sur un système fraîchement installé nécessitant des mises à jour complètes.

**Avantages de v0.12.0**:
- Moteur de lecture unique (Chromium HTML5) pour une maintenance simplifiée
- Interface plus réactive et moderne (design adaptatif clair/sombre)
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

**Raspberry Pi OS Trixie (Debian 13)** est le système de référence, de préférence en version 64 bits, pour les Raspberry Pi 4/5. La cible repose sur Wayland/labwc et le mode kiosk Chromium :
- Moteur de lecture unique Chromium HTML5 (Wayland)
- API REST complète pour contrôle à distance du lecteur et du kiosk
- Stack moderne lightdm (autologin) + labwc
- Voir [UPGRADE_TRIXIE.md](../UPGRADE_TRIXIE.md) pour installation complète

Une installation fraîche est recommandée pour éviter les conflits avec des configurations existantes.

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
   - Serveur web Nginx avec PHP 8.4-fpm
   - Chromium et la stack kiosk Wayland (labwc, lightdm)
   - yt-dlp installé dans /opt/pisignage/bin
   - Outils système pour les captures d'écran
3. Création de l'arborescence dans /opt/pisignage
4. Configuration du serveur web, de l'autologin lightdm et des crons système
5. Téléchargement de l'interface web depuis GitHub
6. Récupération de la vidéo de démonstration Big Buck Bunny
7. Application des permissions et activation du démarrage automatique du kiosk

### Vérification après installation

Une fois l'installation terminée, vérifiez que tout fonctionne correctement :

```bash
# État de la session graphique (autologin lightdm)
sudo systemctl status display-manager

# Test de l'interface web
curl -I http://localhost

# Test du lecteur Chromium (page servie sur /player)
curl -I http://localhost/player

# Vérifier que Chromium tourne en kiosk
pgrep -a chromium

# Consultation des logs si nécessaire
tail -f /opt/pisignage/logs/pisignage.log
```

L'interface web devrait être accessible depuis n'importe quel navigateur à l'adresse http://[IP-RASPBERRY]/ et le lecteur sur http://[IP-RASPBERRY]/player

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
sudo apt install -y nginx php8.4-fpm php8.4-cli \
    php8.4-curl git wget curl unzip \
    chromium chromium-l10n labwc lightdm
```

> **Note**: VLC n'est plus requis (retiré en v0.12). Le moteur de lecture unique est Chromium HTML5, affiché en kiosk via labwc sous Wayland.

yt-dlp est géré par PiSignage et installé dans `/opt/pisignage/bin` (téléchargé du dépôt officiel, mise à jour 1-clic depuis l'UI) :
```bash
sudo mkdir -p /opt/pisignage/bin
sudo wget -O /opt/pisignage/bin/yt-dlp \
    https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp
sudo chmod +x /opt/pisignage/bin/yt-dlp
```

Pour un monitoring avancé du système et le traitement média, vous pouvez également installer :
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
sudo mkdir -p /opt/pisignage/{web,media,config,logs,scripts,bin,playlists,data}
sudo mkdir -p /opt/pisignage/web/api
sudo mkdir -p /dev/shm/pisignage-screenshots
sudo chown -R $USER:$USER /opt/pisignage
chmod 755 /opt/pisignage
```

Rôle des répertoires clés :
- `playlists/` : source de vérité des playlists (`<slug>.json`)
- `config/` : pointeur de playlist active (`active-playlist.json`) et état du scheduler (`scheduler-state.json`)
- `data/` : programmation dayparting (`schedules.json`)
- `media/` : médias + `playlist.json` (la playlist effectivement diffusée à l'écran)
- `bin/` : binaires gérés par PiSignage (yt-dlp)

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
        fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
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
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' /etc/php/8.4/fpm/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' /etc/php/8.4/fpm/php.ini
sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.4/fpm/php.ini
sudo sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/8.4/fpm/php.ini

sudo mkdir -p /tmp/nginx_uploads
sudo chown www-data:www-data /tmp/nginx_uploads
sudo systemctl restart php8.4-fpm
```

### Étape 7 : Récupération des fichiers PiSignage

La méthode recommandée pour récupérer l'ensemble cohérent des fichiers (interface, APIs, lecteur, scripts) est de cloner le dépôt et de copier l'arborescence `web/` et `scripts/` :

```bash
cd /tmp
git clone https://github.com/elkir0/Pi-Signage.git
sudo cp -r Pi-Signage/web/. /opt/pisignage/web/
sudo cp -r Pi-Signage/scripts/. /opt/pisignage/scripts/
chmod +x /opt/pisignage/scripts/*.sh
```

L'arborescence `web/api` contient notamment :
- `display.php` : contrôle du lecteur Chromium (commandes play/pause/next/prev/reload, état live, lecture isolée)
- `playlists.php` + `playlists-core.php` : playlists unifiées (créer/maj/activer/supprimer, « Diffuser à l'écran »)
- `scheduler.php` : exécuteur CLI du dayparting (lancé par cron, voir Étape 9)
- `system.php` : volume système ALSA, redémarrage, cache, etc.
- `media.php` : gestion des médias (avec propagation des renommages/suppressions dans les playlists)
- `kiosk.php` : réglages d'affichage (mode kiosk, URL, flags Chromium, extinction d'écran)

> **Note**: les endpoints `playlist-simple.php`, `player.php` et `player-control.php` sont **dépréciés** (réponse HTTP 410). Le lecteur n'est plus VLC ; il n'y a plus de script `start-vlc.sh` ni de `player-manager`.

### Étape 8 : Vidéo de démonstration

Téléchargez Big Buck Bunny pour tester le système :

```bash
wget -O media/BigBuckBunny_720p.mp4 \
    "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
```

### Étape 9 : Session graphique (autologin lightdm) et crons

En v0.12, il n'y a plus de service systemd `pisignage` ni de lecteur VLC. Le lecteur est Chromium, lancé en kiosk au démarrage de la session graphique :

```
lightdm (autologin pi) → labwc (Wayland) → chromium --kiosk http://127.0.0.1/player
```

**Autologin lightdm** de l'utilisateur `pi` sur une session labwc :

```bash
sudo tee /etc/lightdm/lightdm.conf.d/50-pisignage-autologin.conf > /dev/null << 'EOF'
[Seat:*]
autologin-user=pi
autologin-session=labwc
EOF
```

**Lancement de Chromium en kiosk** au démarrage de labwc (autostart de la session) :

```bash
sudo -u pi mkdir -p /home/pi/.config/labwc
sudo -u pi tee /home/pi/.config/labwc/autostart > /dev/null << 'EOF'
chromium --kiosk --noerrdialogs --disable-infobars http://127.0.0.1/player &
EOF
```

> Les flags Chromium et l'URL du kiosk sont ensuite gérés depuis l'UI (page « Kiosk », API `web/api/kiosk.php`) et régénérés par `kiosk-apply`. Pour redémarrer la session graphique : `sudo systemctl restart display-manager`.

**Crons système** : deux tâches planifiées sont nécessaires.

- `pisignage-screen` : pilote l'extinction d'écran programmée.
- `pisignage-scheduler` : exécute le dayparting toutes les minutes (en `www-data`), lit `/opt/pisignage/data/schedules.json` et désigne la playlist active selon heure/jour/récurrence/priorité.

```bash
# Scheduler dayparting (1×/minute, en www-data)
sudo tee /etc/cron.d/pisignage-scheduler > /dev/null << 'EOF'
* * * * * www-data /usr/bin/php /opt/pisignage/web/api/scheduler.php >/dev/null 2>&1
EOF

# Extinction d'écran programmée
sudo tee /etc/cron.d/pisignage-screen > /dev/null << 'EOF'
* * * * * pi /opt/pisignage/scripts/screen-schedule.sh >/dev/null 2>&1
EOF

sudo chmod 644 /etc/cron.d/pisignage-scheduler /etc/cron.d/pisignage-screen
```

> Pour que le dayparting compare des heures locales (et non UTC), `web/config.php` aligne le fuseau horaire PHP sur `/etc/timezone`. Vérifiez le fuseau du système avec `timedatectl`.

### Étape 10 : Application des permissions

Configurez les permissions pour que chaque composant ait les droits appropriés :

```bash
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chown -R www-data:www-data /opt/pisignage/media
sudo chown -R www-data:www-data /opt/pisignage/logs
sudo chown -R www-data:www-data /opt/pisignage/playlists
sudo chown -R www-data:www-data /opt/pisignage/config
sudo chown -R www-data:www-data /opt/pisignage/data
sudo chown -R pi:pi /opt/pisignage/scripts
sudo chown -R www-data:www-data /opt/pisignage/bin
chmod +x /opt/pisignage/scripts/*.sh
chmod +x /opt/pisignage/bin/yt-dlp
```

> Le scheduler et les APIs web (PHP-FPM, www-data) écrivent dans `playlists/`, `config/`, `data/` et `media/`. Ces répertoires doivent donc appartenir à `www-data`.

## Configuration complémentaire

### Configuration du kiosk Chromium

Le moteur de lecture est Chromium en mode kiosk. La configuration (mode kiosk, URL du lecteur, flags Chromium, extinction d'écran programmée) se gère depuis l'UI (page « Kiosk », API `web/api/kiosk.php`) et est régénérée par `kiosk-apply` :

```bash
# Modifier les flags Chromium puis régénérer l'autostart
sudo nano /opt/pisignage/config/kiosk_flags
bash /opt/pisignage/scripts/kiosk-apply

# Changer l'URL du kiosk (par défaut http://127.0.0.1/player)
echo "http://127.0.0.1/player" | sudo tee /opt/pisignage/config/kiosk_url
bash /opt/pisignage/scripts/kiosk-apply
```

> **Note historique** : VLC et MPV ont été retirés. Depuis v0.12, PiSignage utilise un moteur de lecture unique Chromium HTML5 (page `web/player.php` servie sur `/player`), qui lit `/opt/pisignage/media/playlist.json`. Il n'y a plus de configuration `vlcrc`, plus d'interface HTTP VLC (port 8080), ni de mot de passe VLC.

### Validation de l'installation

Vérifiez que la session graphique et l'interface web fonctionnent :

```bash
sudo systemctl status display-manager
pgrep -a chromium
```

L'interface web doit répondre sur le port 80 :
```bash
curl -I http://localhost
curl -I http://localhost/player
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
chromium --version
/opt/pisignage/bin/yt-dlp --version
php -v
nginx -t
```

### État des services

Vérifiez que tous les services sont actifs :

```bash
sudo systemctl status nginx php8.4-fpm display-manager
```

Vérifiez que les crons sont en place :
```bash
ls -l /etc/cron.d/pisignage-scheduler /etc/cron.d/pisignage-screen
```

Testez les APIs pour confirmer que tout fonctionne :
```bash
curl -s http://localhost/api/system.php
curl -s "http://localhost/api/display.php?action=state"
curl -s http://localhost/api/playlists.php
```

### Test du lecteur vidéo

Vérifiez que le lecteur Chromium s'affiche bien et lit la playlist à l'écran :

```bash
# La page lecteur doit répondre (HTTP 200)
curl -I http://localhost/player

# Chromium doit tourner en kiosk
pgrep -a chromium

# Déclencher un rechargement du lecteur via l'API
curl -s -X POST "http://localhost/api/display.php?action=command" \
    -H "Content-Type: application/json" -d '{"cmd":"reload"}'
```

## Résolution des problèmes courants

### Problèmes de permissions
```bash
# Corriger les permissions
sudo chown -R www-data:www-data /opt/pisignage/web /opt/pisignage/media \
    /opt/pisignage/playlists /opt/pisignage/config /opt/pisignage/data
sudo chown -R pi:pi /opt/pisignage/scripts
sudo chmod +x /opt/pisignage/scripts/*.sh
```

### Session graphique / kiosk qui ne démarre pas
```bash
# Vérifier l'autologin lightdm
sudo systemctl status display-manager
sudo journalctl -u lightdm -n 50

# Vérifier l'autostart labwc et le processus Chromium
cat /home/pi/.config/labwc/autostart
pgrep -a chromium

# Redémarrer la session graphique
sudo systemctl restart display-manager
```

### Interface web inaccessible
```bash
# Vérifier Nginx
sudo nginx -t
sudo systemctl status nginx

# Vérifier PHP
sudo systemctl status php8.4-fpm
```

### Problèmes avec le lecteur vidéo
```bash
# La page lecteur doit répondre (HTTP 200)
curl -I http://localhost/player

# Vérifier l'état rapporté par le lecteur
curl -s "http://localhost/api/display.php?action=state"

# Forcer un rechargement du lecteur
curl -s -X POST "http://localhost/api/display.php?action=command" \
    -H "Content-Type: application/json" -d '{"cmd":"reload"}'

# Vérifier le processus Chromium en kiosk
pgrep -a chromium
```

### Dayparting (programmation) qui ne s'applique pas
```bash
# Exécuter le scheduler manuellement (comme le cron)
sudo -u www-data /usr/bin/php /opt/pisignage/web/api/scheduler.php

# Vérifier l'état du scheduler et le fuseau horaire
cat /opt/pisignage/config/scheduler-state.json
timedatectl
```

### Réinstallation complète

Si vous devez recommencer l'installation depuis zéro :

```bash
sudo systemctl stop nginx php8.4-fpm
sudo rm -rf /opt/pisignage
sudo rm -f /etc/nginx/sites-enabled/pisignage
sudo rm -f /etc/cron.d/pisignage-scheduler /etc/cron.d/pisignage-screen
sudo rm -f /etc/lightdm/lightdm.conf.d/50-pisignage-autologin.conf
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

Ce guide couvre l'installation complète de PiSignage v0.12.0. L'installation automatique convient à la majorité des cas d'usage. L'installation manuelle est réservée aux utilisateurs expérimentés ou aux configurations spécifiques.

## Migration depuis versions précédentes

Si vous avez déjà une version antérieure de PiSignage installée, consultez le [Guide de migration](MIGRATION.md) pour une mise à jour en douceur vers v0.12.0. La migration retire VLC, bascule la session graphique sur lightdm et unifie les playlists.

Pour toute question ou problème, consultez la documentation de dépannage ou ouvrez une issue sur le dépôt GitHub.