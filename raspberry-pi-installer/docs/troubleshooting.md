# 🔧 Pi Signage - Guide de dépannage v2.4.8

Ce guide vous aidera à résoudre les problèmes courants rencontrés avec Pi Signage Digital.

> 🆕 **v2.4.8** : Nouvelles sections pour Bookworm, Wayland/labwc et résolution des problèmes spécifiques aux environnements graphiques modernes.

## 📋 Table des matières

- [Problèmes d'installation](#problèmes-dinstallation)
- [Problèmes spécifiques Bookworm](#problèmes-spécifiques-bookworm)
- [Problèmes Wayland/labwc](#problèmes-waylandlabwc)
- [Problèmes d'interface web](#problèmes-dinterface-web)
- [Problèmes de lecture vidéo](#problèmes-de-lecture-vidéo)
- [Problèmes de synchronisation](#problèmes-de-synchronisation)
- [Problèmes de performance](#problèmes-de-performance)
- [Problèmes audio](#problèmes-audio)
- [Outils de diagnostic](#outils-de-diagnostic)

## 🚨 Problèmes d'installation

### Écran noir après installation

**Symptôme** : Écran totalement noir après redémarrage, pas d'affichage

**Cause** : Problème de configuration X11 ou de service d'affichage

**Solution** : La version 2.4.8 détecte automatiquement votre environnement graphique
```bash
# Mettre à jour vers la dernière version
cd ~/Pi-Signage
git pull origin main

# Relancer l'installation
cd raspberry-pi-installer/scripts
sudo ./main_orchestrator.sh
```

La version actuelle :
- Détecte automatiquement X11/Wayland/labwc
- Configure l'autologin via raspi-config
- Utilise les configurations par défaut du Pi
- S'adapte à votre environnement graphique existant

### Mode Chromium Kiosk - Pas de démarrage automatique

**Symptôme** : Après installation en mode Chromium, seulement une invite de commande au redémarrage

**Cause** : Cycle de dépendance systemd empêchant le démarrage des services

**Solution rapide** :
```bash
# Utiliser le script de diagnostic avec correction automatique
sudo pi-signage-diag --fix-chromium-cycle
sudo reboot
```

**Solution manuelle** :
```bash
# 1. Corriger le fichier pi-signage.target
sudo tee /etc/systemd/system/pi-signage.target << 'EOF'
[Unit]
Description=Pi Signage System Target
Documentation=Digital Signage Complete System
Requires=multi-user.target
After=multi-user.target
AllowIsolate=yes

[Install]
WantedBy=graphical.target
EOF

# 2. Activer les services nécessaires
sudo systemctl enable x11-kiosk.service
sudo systemctl enable chromium-kiosk.service
sudo systemctl enable pi-signage-startup.service

# 3. Recharger et redémarrer
sudo systemctl daemon-reload
sudo reboot
```

**Vérification après redémarrage** :
```bash
# Vérifier le statut
sudo systemctl status pi-signage-startup
sudo journalctl -b -u pi-signage-startup

# Diagnostic complet mode Chromium
sudo pi-signage-diag --verify-chromium
```

## 🚨 Autres problèmes d'installation

### Erreurs dpkg sur Raspberry Pi

**Symptôme** : Messages d'erreur dpkg pendant l'installation, paquets non configurés

**Cause** : Interruption d'installation précédente, coupure de courant, manque d'espace

**Solution** :
```bash
# Utiliser le script de vérification automatique
cd ~/Pi-Signage/raspberry-pi-installer/scripts
./dpkg-health-check.sh --auto

# Ou réparer manuellement
sudo dpkg --configure -a
sudo apt-get update --fix-missing
sudo apt-get install -f
```

Pour plus de détails, consultez le [Guide de dépannage dpkg](../../../docs/dpkg-troubleshooting.md).

### Erreur "php8.2-json package not found"

**Symptôme** : L'installation échoue avec le message "Package php8.2-json is not available"

**Solution** : Ce package n'existe pas dans PHP 8.2 car JSON est intégré. Le script d'installation v2.4.0 corrige ce problème automatiquement.

```bash
# Si vous avez une ancienne version, mettez à jour :
git pull origin main
sudo ./main_orchestrator.sh
```

### Erreur "readonly variable" lors de l'installation

**Symptôme** : Message d'erreur concernant des variables en lecture seule

**Solution** :
```bash
# Option 1 : Nettoyer l'environnement
unset LOG_FILE CONFIG_FILE SCRIPT_DIR
sudo ./main_orchestrator.sh

# Option 2 : Utiliser un nouveau shell
sudo bash ./main_orchestrator.sh
```

### Installation sur VM/Headless - Pas d'affichage

**Symptôme** : Écran noir ou pas d'affichage sur VM (QEMU, UTM, VirtualBox)

**Solution** : La v2.4.0 détecte automatiquement l'environnement VM et installe Xvfb. Pour forcer manuellement :

```bash
# Créer le marqueur VM
sudo touch /etc/pi-signage/vm-mode.conf

# Réinstaller le module Chromium
sudo ./03-chromium-kiosk.sh

# Vérifier Xvfb
ps aux | grep Xvfb
```

### Erreur de permissions sur les scripts

**Symptôme** : "Permission denied" lors de l'exécution des scripts

**Solution** :
```bash
# Corriger les permissions
sudo chmod 755 /opt/scripts/*.sh
sudo chown root:root /opt/scripts/*.sh
```

## 🆕 Problèmes spécifiques Bookworm

### LightDM désactivé mais pas de démarrage Chromium

**Symptôme** : Après installation sur Bookworm, le système démarre sur le bureau normal sans kiosque

**Cause** : L'autologin n'est pas configuré correctement pour Bookworm

**Solution** :
```bash
# Configurer l'autologin via raspi-config
sudo raspi-config nonint do_boot_behaviour B2

# Vérifier la configuration
cat /etc/lightdm/lightdm.conf | grep autologin

# Redémarrer
sudo reboot
```

### Chromium ne démarre pas sur Wayland

**Symptôme** : Message d'erreur "Failed to connect to Wayland display"

**Solution** :
```bash
# Vérifier l'environnement
echo $XDG_SESSION_TYPE  # Doit afficher "wayland"
echo $WAYLAND_DISPLAY   # Doit afficher "wayland-1"

# Si manquant, forcer X11
sudo nano /opt/scripts/chromium-kiosk.sh
# Remplacer --ozone-platform=wayland par --ozone-platform=x11
```

## 🖥️ Problèmes Wayland/labwc

### labwc autostart ne fonctionne pas

**Symptôme** : labwc démarre mais pas Chromium/VLC

**Cause** : Mauvais chemin ou permissions du fichier autostart

**Solution** :
```bash
# Vérifier le fichier autostart
ls -la /etc/xdg/labwc/autostart

# Créer/corriger si nécessaire
sudo mkdir -p /etc/xdg/labwc
sudo tee /etc/xdg/labwc/autostart << 'EOF'
#!/bin/bash
sleep 2
/opt/scripts/chromium-kiosk.sh &
EOF

sudo chmod +x /etc/xdg/labwc/autostart
```

### Permissions GPU manquantes

**Symptôme** : "Permission denied" accès /dev/dri/card0

**Solution** :
```bash
# Ajouter l'utilisateur aux groupes nécessaires
sudo usermod -a -G video,render signage

# Installer et configurer seatd
sudo apt-get install -y seatd
sudo systemctl enable seatd
sudo usermod -a -G _seatd signage

# Appliquer les règles udev
sudo udevadm control --reload-rules
sudo udevadm trigger

# Redémarrer
sudo reboot
```

### Chromium plein écran incorrect sur Wayland

**Symptôme** : Chromium ne remplit pas tout l'écran, barres visibles

**Cause** : Ordre incorrect des flags Chromium pour Wayland

**Solution** :
```bash
# Éditer le script
sudo nano /opt/scripts/chromium-kiosk.sh

# S'assurer que l'ordre est :
# --start-maximized (DOIT être AVANT --start-fullscreen)
# --start-fullscreen
# --kiosk

# Redémarrer le service
sudo systemctl restart chromium-kiosk
```

## 🌐 Problèmes d'interface web

### Erreur 500 - Internal Server Error

**Symptôme** : Page blanche ou erreur 500 lors de l'accès à l'interface

**Causes et solutions** :

1. **Permissions incorrectes**
```bash
# Vérifier les permissions
ls -la /var/www/pi-signage/

# Corriger si nécessaire
sudo chown -R www-data:www-data /var/www/pi-signage/
sudo chmod 755 /var/www/pi-signage/
sudo chmod 640 /var/www/pi-signage/includes/config.php
```

2. **PHP-FPM non démarré**
```bash
# Vérifier le statut
sudo systemctl status php8.2-fpm

# Redémarrer si nécessaire
sudo systemctl restart php8.2-fpm
```

3. **Erreur dans config.php**
```bash
# Vérifier les logs PHP
sudo tail -f /var/log/pi-signage/php-error.log
```

4. **Fonction exec() désactivée** (erreur avec YouTube)
```bash
# Vérifier la configuration PHP
grep disable_functions /etc/php/8.2/fpm/pool.d/pi-signage.conf

# Doit ne PAS contenir 'exec'
# Si présent, retirer et redémarrer PHP
sudo systemctl restart php8.2-fpm
```

### Authentification échoue

**Symptôme** : Impossible de se connecter avec le mot de passe défini

**Solution** : Vérifier le format du hash SHA-512

```bash
# Vérifier le format du hash
sudo grep ADMIN_PASSWORD_HASH /var/www/pi-signage/includes/config.php

# Le format doit être : 'salt:hash' (avec les deux points)
# Exemple : 'a1b2c3d4:e5f6g7h8i9j0...'
```

Si le format est incorrect, régénérer le hash :
```bash
# Dans le script d'installation, la fonction hash_password génère le bon format
sudo /opt/scripts/web-password.sh  # Si ce script existe
```

### Pages manquantes (404)

**Symptôme** : Erreur 404 sur `/videos.php`, `/settings.php` ou `/playlist.php`

**Solution** : Ces fichiers ont été ajoutés dans les versions récentes. Mettez à jour :

```bash
# Mettre à jour l'interface web
sudo /opt/scripts/update-web-interface.sh
# Ajouter --full pour réinitialiser la configuration

# Ou réinstaller manuellement
cd /path/to/Pi-Signage
git pull origin main
sudo ./raspberry-pi-installer/scripts/09-web-interface-v2.sh
```

### Upload de vidéos ne fonctionne pas

**Symptômes possibles** :
- Bouton upload inactif
- Erreur après upload
- Vidéo n'apparaît pas dans la liste

**Solutions** :

1. **Vérifier l'espace disque**
```bash
df -h /opt/videos
# Doit avoir au moins 1GB libre
```

2. **Vérifier les permissions**
```bash
ls -la /opt/videos/
# Doit être : drwxr-xr-x www-data www-data

# Corriger si nécessaire
sudo chown -R www-data:www-data /opt/videos
sudo chmod 755 /opt/videos
```

3. **Vérifier la limite de taille**
```bash
# Limite définie dans PHP-FPM (150MB par défaut)
grep upload_max_filesize /etc/php/8.2/fpm/pool.d/pi-signage.conf
grep post_max_size /etc/php/8.2/fpm/pool.d/pi-signage.conf
```

### Téléchargement YouTube échoue

**Symptômes** :
- Erreur 500 sur youtube.php
- Téléchargement produit des fichiers MKV au lieu de MP4
- Verbose se ferme automatiquement

**Solutions** :

1. **Vérifier le wrapper yt-dlp**
```bash
ls -la /usr/local/bin/yt-dlp
# Doit être exécutable (755)

# Tester manuellement
sudo -u www-data /usr/local/bin/yt-dlp --version
```

2. **Vérifier le format de sortie**
```bash
# Le wrapper doit forcer MP4
cat /usr/local/bin/yt-dlp | grep format
# Doit contenir: --format "best[ext=mp4]/best" --merge-output-format mp4
```

### Problèmes avec les chemins relatifs

**Symptôme** : Erreurs "No such file or directory" avec des chemins comme "../includes/config.php"

**Solution** : La v2.3.0 utilise des chemins absolus. Vérifier que tous les fichiers utilisent :
```php
require_once dirname(__DIR__) . '/includes/config.php';
// Au lieu de :
require_once '../includes/config.php';
```

### Images manquantes (logo/favicon)

**Symptômes** :
- Logo Pi Signage non visible dans l'interface
- Favicon absent dans l'onglet du navigateur
- Icônes cassées dans la navigation

**Solutions** :

1. **Utiliser le script de réparation automatique**
```bash
sudo /opt/scripts/util-fix-missing-images.sh
```

2. **Via le menu de diagnostic**
```bash
sudo pi-signage-tools
# Choisir option 12
```

3. **Téléchargement manuel**
```bash
# Logo
sudo wget -O /var/www/pi-signage/public/assets/images/logo.png \
  https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web-interface/public/assets/images/logo.png

# Favicon
sudo wget -O /var/www/pi-signage/public/assets/images/favicon.ico \
  https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web-interface/public/assets/images/favicon.ico

# Permissions
sudo chown www-data:www-data /var/www/pi-signage/public/assets/images/*
sudo systemctl reload nginx
```

## 🎬 Problèmes de lecture vidéo

### Mode VLC - Pas de lecture

**Symptôme** : VLC démarre mais ne lit pas les vidéos

**Solutions** :

1. **Vérifier le service**
```bash
sudo systemctl status vlc-signage
sudo journalctl -u vlc-signage -f
```

2. **Vérifier les vidéos**
```bash
ls -la /opt/videos/
# Doit contenir au moins un fichier vidéo
```

3. **Tester manuellement**
```bash
sudo -u signage /opt/scripts/vlc-signage.sh
```

### Mode Chromium - Player ne charge pas

**Symptôme** : Page blanche ou erreur dans Chromium

**Solutions** :

1. **Vérifier le service web du player**
```bash
# Le player doit être accessible sur le port 8888
curl http://localhost:8888/player.html
```

2. **Vérifier les logs**
```bash
sudo tail -f /var/log/pi-signage/chromium.log
```

3. **Vérifier la playlist**
```bash
cat /opt/videos/playlist.json
# Doit contenir un JSON valide avec les vidéos
```

## 🔄 Problèmes de synchronisation

### Google Drive ne synchronise pas

**Symptôme** : Les nouvelles vidéos n'apparaissent pas

**Note importante** : En mode Chromium, la playlist doit être mise à jour manuellement ou automatiquement après ajout de vidéos.

**Solutions** :

1. **Vérifier la configuration rclone**
```bash
sudo -u signage rclone listremotes
# Doit afficher : gdrive:
```

2. **Tester la connexion**
```bash
sudo /opt/scripts/test-gdrive.sh
```

3. **Synchronisation manuelle**
```bash
sudo /opt/scripts/sync-videos.sh
```

4. **Vérifier les logs**
```bash
tail -f /var/log/pi-signage/sync.log
```

5. **Mise à jour playlist (mode Chromium)**
```bash
# Après synchronisation, mettre à jour la playlist
sudo /opt/scripts/update-playlist.sh

# Ou depuis l'interface web
# Paramètres > Update Playlist
```

### Erreur d'authentification Google

**Solution** : Reconfigurer rclone
```bash
sudo /opt/scripts/setup-gdrive.sh
```

## 📊 Problèmes de performance

### Utilisation CPU élevée

**Symptôme** : CPU constamment au-dessus de 80%

**Solutions** :

1. **Identifier le processus**
```bash
htop
# ou
sudo glances
```

2. **Pour VLC** : Vérifier l'accélération matérielle
```bash
grep -i hardware /home/signage/.config/vlc/vlcrc
```

3. **Pour Chromium** : Désactiver les effets inutiles
```bash
# Ajouter dans le script de lancement :
--disable-features=TranslateUI
--disable-background-timer-throttling
```

### Température élevée

**Symptôme** : Température > 80°C

**Solutions** :

1. **Vérifier la température**
```bash
vcgencmd measure_temp
```

2. **Améliorer le refroidissement**
- Ajouter un dissipateur thermique
- Installer un ventilateur
- Vérifier la ventilation du boîtier

3. **Réduire la charge**
- Baisser la résolution des vidéos
- Limiter le framerate à 30fps
- Désactiver les services non essentiels

## 🎙️ Problèmes audio

### Pas de son dans les vidéos

**Symptôme** : Vidéos muettes alors qu'elles contiennent de l'audio

**Solutions** :

1. **Vérifier la configuration audio**
```bash
# Lancer l'utilitaire de configuration
sudo /opt/scripts/util-configure-audio.sh

# Choisir :
# 1 = Jack (sortie audio analogique)
# 2 = HDMI (sortie numérique)
```

2. **Tester l'audio**
```bash
sudo /opt/scripts/util-test-audio.sh
# Vous devriez entendre un bip de test
```

3. **Vérifier le volume**
```bash
alsamixer
# Utiliser les flèches pour ajuster
# S'assurer que le canal n'est pas muté (MM)
```

4. **Mode Chromium - Vérifier le player**
```bash
# Le player ne doit pas avoir l'attribut 'muted'
grep muted /var/www/pi-signage/public/player.html
# Ne doit rien retourner
```

### Son uniquement sur HDMI/Jack

**Solution** : Forcer la sortie audio
```bash
# Pour HDMI
sudo amixer cset numid=3 2

# Pour Jack (sortie analogique)
sudo amixer cset numid=3 1

# Pour automatique
sudo amixer cset numid=3 0
```

## 🛠️ Outils de diagnostic

### Diagnostic complet

```bash
# Diagnostic automatique
sudo pi-signage-diag

# Génère un rapport complet avec :
# - État des services
# - Utilisation ressources
# - Connectivité réseau
# - Espace disque
# - Logs récents
```

### Collecte de logs pour support

```bash
# Collecter tous les logs
sudo pi-signage-logs

# Crée une archive dans /tmp/
# Contient tous les logs nécessaires au support
```

### Commandes de diagnostic rapide

```bash
# État général
sudo pi-signage status

# Services individuels
sudo systemctl status vlc-signage
sudo systemctl status chromium-kiosk
sudo systemctl status nginx
sudo systemctl status php8.2-fpm

# Logs en temps réel
sudo journalctl -f
sudo tail -f /var/log/pi-signage/*.log

# Ressources système
df -h          # Espace disque
free -h        # Mémoire
htop           # Processus
vcgencmd measure_temp  # Température
```

### Réparation automatique

```bash
# Tente de réparer les problèmes courants
sudo pi-signage-repair

# Mode urgence (réinstalle les services)
sudo pi-signage emergency
```

## 📞 Obtenir de l'aide

Si les solutions ci-dessus ne résolvent pas votre problème :

1. **Exécuter le diagnostic**
```bash
sudo pi-signage-diag > diagnostic.txt
```

2. **Collecter les logs**
```bash
sudo pi-signage-logs
```

3. **Informations à fournir** :
- Modèle de Raspberry Pi
- Version de Pi Signage (v2.4.0)
- Mode d'affichage (VLC ou Chromium)
- Description détaillée du problème
- Contenu du diagnostic
- Archive des logs
- Configuration audio si pertinent

4. **Créer une issue sur GitHub** avec toutes ces informations

## 🔄 Mise à jour vers v2.4.0

Si vous avez une version antérieure :

```bash
# Sauvegarder la configuration
sudo cp -r /etc/pi-signage /etc/pi-signage.backup

# Mettre à jour
cd /path/to/Pi-Signage
git fetch origin
git checkout main
git pull

# Réinstaller
cd raspberry-pi-installer/scripts
sudo ./main_orchestrator.sh
```

Les principales nouveautés de la v2.4.0 :
- ✅ Support audio complet (HDMI/Jack)
- ✅ Page playlist.php pour gestion ordre de lecture
- ✅ API player.php pour contrôle
- ✅ Logo Pi Signage intégré
- ✅ Téléchargement YouTube format MP4 forcé
- ✅ Scripts audio : configure et test
- ✅ Mise à jour automatique playlist après upload