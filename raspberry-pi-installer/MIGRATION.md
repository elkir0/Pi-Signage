# Guide de Migration - Pi Signage Digital

## Migration vers v2.4.9 - Optimisations Vidéo

### Changements majeurs

#### Performance vidéo
- **Accélération GPU H.264** : Configuration automatique gpu_mem=128
- **Support V4L2** : Nouveau stack de décodage Bookworm
- **Flags Chromium optimisés** : VaapiVideoDecoder activé par défaut
- **Réduction CPU** : De 60% à 30% pour vidéos 1080p

### Instructions de migration

```bash
# 1. Mettre à jour le code
cd ~/Pi-Signage
git pull origin main

# 2. Réinstaller pour appliquer les optimisations
cd raspberry-pi-installer/scripts
sudo ./main_orchestrator.sh

# 3. Vérifier après redémarrage
vcgencmd codec_enabled H264
# Doit retourner : H264=enabled
```

### Vérification des optimisations

```bash
# Vérifier gpu_mem
cat /boot/config.txt | grep gpu_mem
# Doit être : gpu_mem=128

# Si mode Chromium, vérifier GPU
chromium-browser chrome://gpu
# "Video Decode" doit être "Hardware accelerated"
```

## Migration vers v2.4.8 - Support Bookworm

### Changements majeurs

#### Environnement graphique
- **Détection automatique** : X11, Wayland, labwc
- **Autologin via raspi-config** : Méthode officielle et fiable
- **Support natif Wayland** : Configuration automatique pour Pi 4/5
- **Préservation des environnements existants** : Plus de réinstallation forcée

#### Configuration système
- **Boot manager simplifié** : Utilise l'autologin natif
- **Services utilisateur** : Support systemd --user pour Desktop
- **Permissions Wayland** : seatd et règles udev automatiques
- **Ordre des flags Chromium** : Corrigé pour Wayland

### Instructions de migration

```bash
# 1. Mettre à jour le code
cd ~/Pi-Signage
git pull origin main

# 2. Réinstaller avec la nouvelle version
cd raspberry-pi-installer/scripts
sudo ./main_orchestrator.sh

# 3. Le système va automatiquement :
# - Détecter votre environnement (X11/Wayland/labwc)
# - Configurer l'autologin approprié
# - Adapter les services au contexte
```

### Vérification post-migration

```bash
# Vérifier l'environnement détecté
cat /etc/pi-signage/config.conf | grep -E "DISPLAY_SERVER|COMPOSITOR|HAS_GUI"

# Vérifier l'autologin
cat /etc/lightdm/lightdm.conf | grep autologin

# Pour Wayland, vérifier labwc
ls -la /etc/xdg/labwc/autostart
```

## Migration Interface Web v1 vers v2

### Changements principaux

### Avant (v1)
- Le script `09-web-interface.sh` créait tous les fichiers PHP avec des commandes `cat`
- Difficile à maintenir et à faire évoluer
- Code mélangé avec la logique d'installation

### Après (v2)
- L'interface web est maintenue séparément dans `/web-interface/`
- Le script `09-web-interface-v2.sh` clone le code depuis GitHub
- Plus facile à maintenir, tester et faire évoluer

## Structure du projet

```
Pi-Signage/
├── raspberry-pi-installer/
│   └── scripts/
│       ├── 09-web-interface.sh      # Ancienne version (deprecated)
│       └── 09-web-interface-v2.sh   # Nouvelle version
└── web-interface/                    # Code de l'interface web
    ├── public/                       # Fichiers accessibles publiquement
    ├── includes/                     # Logique PHP
    ├── api/                          # Points d'accès API
    ├── assets/                       # CSS, JS, images
    └── templates/                    # Templates réutilisables
```

## Migration

### Pour utiliser la nouvelle version

1. **Remplacer le script dans votre installation**
   ```bash
   # Option 1 : Renommer simplement
   mv 09-web-interface-v2.sh 09-web-interface.sh
   
   # Option 2 : Utiliser le nouveau script install.sh
   ```

2. **Le nouveau script va automatiquement**
   - Cloner l'interface web depuis GitHub
   - Configurer les permissions
   - Générer le fichier de configuration avec les mots de passe

### Avantages

1. **Maintenance facilitée**
   - Modifications directes dans les fichiers PHP
   - Tests locaux possibles
   - Versioning Git approprié

2. **Mises à jour simplifiées**
   - Script de mise à jour automatique inclus
   - `update-web-interface.sh` met à jour depuis GitHub

3. **Développement amélioré**
   - Structure claire et modulaire
   - Séparation des responsabilités
   - Plus facile à contribuer

## Scripts de mise à jour

Le nouveau système inclut deux scripts de mise à jour :

```bash
# Mise à jour de yt-dlp
/opt/scripts/update-ytdlp.sh

# Mise à jour de l'interface web depuis GitHub
/opt/scripts/update-web-interface.sh
# Utiliser --full pour réinstaller la configuration
```

Ces scripts sont exécutés automatiquement chaque semaine via cron.

## Développement local

Pour tester l'interface web localement :

```bash
cd web-interface
php -S localhost:8000 -t public/
```

## Notes importantes

- Le fichier `includes/config.php` est généré à l'installation
- Les mots de passe sont toujours hashés/chiffrés
- La sécurité reste identique à la v1
- Compatible avec la même infrastructure (nginx, PHP-FPM)

## Problèmes connus lors de la migration v2.4.8

### 1. Services qui ne démarrent pas après migration

**Problème** : Les services restent sur l'ancienne configuration

**Solution** :
```bash
# Désactiver les anciens services
sudo systemctl disable x11-kiosk
sudo systemctl disable pi-signage-startup

# Recharger systemd
sudo systemctl daemon-reload

# Redémarrer
sudo reboot
```

### 2. Chromium ne fonctionne pas sur Wayland

**Problème** : Écran noir ou erreur de connexion Wayland

**Solution** :
```bash
# Vérifier les permissions
groups signage  # Doit inclure video, render, _seatd

# Si manquant
sudo usermod -a -G video,render,_seatd signage
sudo systemctl restart seatd
```

### 3. Autologin ne fonctionne pas

**Problème** : Le système demande un mot de passe au démarrage

**Solution** :
```bash
# Reconfigurer via raspi-config
sudo raspi-config nonint do_boot_behaviour B2

# Vérifier
systemctl get-default  # Doit être graphical.target
```

## Retour en arrière si nécessaire

Si vous rencontrez des problèmes majeurs :

```bash
# 1. Revenir à la version précédente
cd ~/Pi-Signage
git checkout v2.4.0

# 2. Réinstaller
cd raspberry-pi-installer/scripts
sudo ./main_orchestrator.sh

# 3. Désactiver les nouveaux services
sudo systemctl disable seatd
```