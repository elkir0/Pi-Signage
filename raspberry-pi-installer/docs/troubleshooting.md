# 🔧 Pi Signage - Guide de dépannage v2.3.0

Ce guide vous aidera à résoudre les problèmes courants rencontrés avec Pi Signage Digital.

## 📋 Table des matières

- [Problèmes d'installation](#problèmes-dinstallation)
- [Problèmes d'interface web](#problèmes-dinterface-web)
- [Problèmes de lecture vidéo](#problèmes-de-lecture-vidéo)
- [Problèmes de synchronisation](#problèmes-de-synchronisation)
- [Problèmes de performance](#problèmes-de-performance)
- [Outils de diagnostic](#outils-de-diagnostic)

## 🚨 Problèmes d'installation

### Erreur "php8.2-json package not found"

**Symptôme** : L'installation échoue avec le message "Package php8.2-json is not available"

**Solution** : Ce package n'existe pas dans PHP 8.2 car JSON est intégré. Le script d'installation v2.3.0 corrige ce problème automatiquement.

```bash
# Si vous avez une ancienne version, mettez à jour :
git pull origin main
sudo ./install.sh
```

### Erreur "readonly variable" lors de l'installation

**Symptôme** : Message d'erreur concernant des variables en lecture seule

**Solution** :
```bash
# Option 1 : Nettoyer l'environnement
unset LOG_FILE CONFIG_FILE SCRIPT_DIR
sudo ./install.sh

# Option 2 : Utiliser un nouveau shell
sudo bash ./install.sh
```

### Installation sur VM/Headless - Pas d'affichage

**Symptôme** : Écran noir ou pas d'affichage sur VM (QEMU, UTM, VirtualBox)

**Solution** : La v2.3.0 détecte automatiquement l'environnement VM et installe Xvfb. Pour forcer manuellement :

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

**Symptôme** : Erreur 404 sur `/videos.php` ou `/settings.php`

**Solution** : Ces fichiers ont été ajoutés dans la v2.3.0. Mettez à jour :

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

### Problèmes avec les chemins relatifs

**Symptôme** : Erreurs "No such file or directory" avec des chemins comme "../includes/config.php"

**Solution** : La v2.3.0 utilise des chemins absolus. Vérifier que tous les fichiers utilisent :
```php
require_once dirname(__DIR__) . '/includes/config.php';
// Au lieu de :
require_once '../includes/config.php';
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
- Version de Pi Signage (v2.3.0)
- Mode d'affichage (VLC ou Chromium)
- Description détaillée du problème
- Contenu du diagnostic
- Archive des logs

4. **Créer une issue sur GitHub** avec toutes ces informations

## 🔄 Mise à jour vers v2.3.0

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
sudo ./install.sh
```

Les principales corrections de la v2.3.0 :
- ✅ Support VM/Headless avec Xvfb
- ✅ Authentification SHA-512 harmonisée
- ✅ Permissions corrigées
- ✅ Chemins absolus dans PHP
- ✅ Pages videos.php et settings.php ajoutées