# Guide d'installation PiSignage Desktop v3.0

## 📋 Table des matières

- [Prérequis système](#-prérequis-système)
- [Préparation de l'environnement](#-préparation-de-lenvironnement)
- [Installation automatique](#-installation-automatique)
- [Installation modulaire](#-installation-modulaire)
- [Configuration post-installation](#-configuration-post-installation)
- [Optimisations optionnelles](#-optimisations-optionnelles)
- [Tests de validation](#-tests-de-validation)
- [Mise à jour](#-mise-à-jour)
- [Désinstallation](#-désinstallation)

## 🖥️ Prérequis système

### Matériel recommandé

| Composant | Minimum | Recommandé | Optimal |
|-----------|---------|------------|---------|
| **Raspberry Pi** | Pi 3B+ | Pi 4 (4GB) | Pi 4 (8GB) |
| **RAM** | 2GB | 4GB | 8GB |
| **Stockage** | 16GB (Classe 10) | 32GB (Classe 10) | 64GB+ (SSD USB) |
| **Réseau** | WiFi 2.4GHz | Ethernet + WiFi | Ethernet Gigabit |
| **Écran** | 1024x768 | 1920x1080 | 4K (avec Pi 4) |

### Système d'exploitation

```bash
# Versions supportées
- Raspberry Pi OS Desktop (Bookworm) - Recommandé
- Raspberry Pi OS Desktop (Bullseye) - Compatible
- Debian 12+ (Bookworm) - Compatible
- Ubuntu Desktop 22.04+ - Expérimental

# Architecture
- ARM64 (aarch64) - Recommandé
- ARMv7 (armhf) - Compatible Pi 3+
```

### Vérification du système

```bash
# Version du système
cat /etc/os-release

# Architecture
uname -m

# Mémoire disponible
free -h

# Espace disque
df -h

# GPU activé
vcgencmd get_mem gpu
# Résultat attendu: gpu=128M ou plus
```

## 🔧 Préparation de l'environnement

### 1. Mise à jour du système

```bash
# Mise à jour complète
sudo apt update && sudo apt upgrade -y

# Installation des outils de base
sudo apt install -y curl wget git htop nano

# Redémarrage si nécessaire
if [ -f /var/run/reboot-required ]; then
    sudo reboot
fi
```

### 2. Configuration GPU (obligatoire)

```bash
# Méthode 1: via raspi-config
sudo raspi-config
# > Advanced Options > Memory Split > 128

# Méthode 2: édition manuelle
echo 'gpu_mem=128' | sudo tee -a /boot/firmware/config.txt

# Vérification
grep gpu_mem /boot/firmware/config.txt
```

### 3. Configuration utilisateur

```bash
# Créer un utilisateur dédié (optionnel mais recommandé)
sudo adduser pisignage --gecos "PiSignage User" --disabled-password
sudo usermod -aG sudo,video,audio pisignage

# Ou utiliser l'utilisateur pi existant
sudo usermod -aG video,audio pi
```

### 4. Configuration réseau

```bash
# IP statique (optionnel mais recommandé)
sudo nano /etc/dhcpcd.conf

# Ajouter pour ethernet:
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8

# Redémarrer le service réseau
sudo systemctl restart dhcpcd
```

## 🚀 Installation automatique

### Méthode 1: Script d'installation directe

```bash
# Téléchargement et installation en une commande
curl -fsSL https://raw.githubusercontent.com/yourusername/pisignage-desktop/main/quick-install.sh | bash
```

### Méthode 2: Installation depuis les sources

```bash
# 1. Télécharger les sources
cd /tmp
wget https://github.com/yourusername/pisignage-desktop/archive/v3.0.0.tar.gz
tar -xzf v3.0.0.tar.gz
cd pisignage-desktop-3.0.0

# 2. Rendre exécutable
chmod +x install.sh

# 3. Installation standard
./install.sh

# 4. Installation avec logs détaillés
VERBOSE=true ./install.sh

# 5. Installation avec hostname personnalisé
HOSTNAME=mon-pisignage ./install.sh
```

### Méthode 3: Installation depuis Git

```bash
# 1. Cloner le repository
git clone https://github.com/yourusername/pisignage-desktop.git
cd pisignage-desktop

# 2. Sélectionner la version stable
git checkout v3.0.0

# 3. Installation
./install.sh
```

### Variables d'environnement

```bash
# Variables supportées
export VERBOSE=true              # Logs détaillés
export HOSTNAME=mon-pisignage    # Hostname personnalisé  
export INSTALL_DIR=/opt/pisignage # Répertoire d'installation
export WEB_PORT=8080             # Port web personnalisé
export SKIP_REBOOT=true          # Ne pas redémarrer automatiquement
export DRY_RUN=true              # Simulation sans modifications

# Exemple d'installation personnalisée
VERBOSE=true HOSTNAME=affichage-001 WEB_PORT=8080 ./install.sh
```

## 🔧 Installation modulaire

L'installation modulaire permet de choisir précisément les composants à installer.

### Module 1: Configuration de base (obligatoire)

```bash
cd modules/
sudo ./01-base-config.sh [hostname]

# Détails de ce module:
# - Création utilisateur pisignage
# - Installation paquets: nginx, php-fpm, yt-dlp, jq, curl
# - Configuration GPU (gpu_mem=128)
# - Création structure dossiers
# - Configuration hostname (optionnel)
```

### Module 2: Interface web (obligatoire)

```bash
sudo ./02-web-interface.sh

# Détails de ce module:
# - Déploiement interface HTML5/PHP
# - Configuration nginx
# - Création virtualhost
# - API REST endpoints
# - Interface d'administration
# - Configuration PHP-FPM
```

### Module 3: Player multimédia (obligatoire)

```bash
sudo ./03-media-player.sh

# Détails de ce module:
# - Configuration Chromium kiosk
# - Scripts de contrôle player
# - Autostart Desktop
# - Fallback VLC
# - Scripts de commande (pisignage play/pause/etc.)
```

### Module 4: Synchronisation cloud (optionnel)

```bash
sudo ./04-sync-optional.sh

# Détails de ce module:
# - Installation rclone
# - Configuration providers cloud
# - Scripts de synchronisation
# - Tâches cron automatiques
# - Commandes pisignage-sync
```

### Module 5: Services et monitoring (recommandé)

```bash
sudo ./05-services.sh

# Détails de ce module:
# - Services systemd
# - Watchdog automatique
# - Health check endpoints
# - Rotation logs
# - Scripts d'administration
```

### Installation sélective

```bash
# Installation minimale (player local uniquement)
sudo ./01-base-config.sh
sudo ./02-web-interface.sh
sudo ./03-media-player.sh

# Installation complète avec cloud
sudo ./01-base-config.sh
sudo ./02-web-interface.sh
sudo ./03-media-player.sh
sudo ./04-sync-optional.sh
sudo ./05-services.sh

# Installation serveur (sans player)
sudo ./01-base-config.sh
sudo ./02-web-interface.sh
sudo ./05-services.sh
```

## ⚙️ Configuration post-installation

### 1. Vérification de l'installation

```bash
# Status des services
sudo systemctl status pisignage.service
sudo systemctl status nginx.service
sudo systemctl status php8.2-fpm.service

# Test de l'interface web
curl -I http://localhost/
curl http://localhost/api/health.php

# Test des commandes
pisignage status
pisignage-admin status
```

### 2. Configuration initiale

```bash
# Configuration du player
sudo nano /opt/pisignage/config/player.json

# Configuration nginx (si modification nécessaire)
sudo nano /etc/nginx/sites-available/pisignage

# Configuration PHP (si modification nécessaire)
sudo nano /etc/php/8.2/fpm/pool.d/pisignage.conf
```

### 3. Ajout de médias de test

```bash
# Télécharger des vidéos de test
sudo mkdir -p /opt/pisignage/videos
cd /opt/pisignage/videos

# Vidéo Big Buck Bunny (Creative Commons)
sudo wget https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4

# Permissions
sudo chown -R pisignage:pisignage /opt/pisignage/videos/

# Test de lecture
pisignage play
```

### 4. Configuration cloud (si module installé)

```bash
# Configuration interactive rclone
rclone config

# Exemple Google Drive:
# Nom: gdrive
# Type: Google Drive
# Client ID: (laisser vide)
# Client Secret: (laisser vide)
# Scope: drive
# Token: (autorisation via navigateur)

# Test de connexion
rclone ls gdrive:

# Configuration auto-sync
pisignage-sync config
```

### 5. Configuration autostart

```bash
# Vérifier autostart Desktop
ls -la ~/.config/autostart/
cat ~/.config/autostart/pisignage.desktop

# Test autostart
sudo reboot
# Attendre le redémarrage et vérifier que le player démarre automatiquement
```

## 🚀 Optimisations optionnelles

### 1. Optimisations GPU

```bash
# Augmenter la mémoire GPU pour vidéos HD/4K
echo 'gpu_mem=256' | sudo tee -a /boot/firmware/config.txt

# Activer accélération hardware H.264
echo 'dtoverlay=vc4-kms-v3d' | sudo tee -a /boot/firmware/config.txt

# Optimiser fréquence GPU
echo 'gpu_freq=500' | sudo tee -a /boot/firmware/config.txt
```

### 2. Optimisations système

```bash
# Optimiser swappiness
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# Optimiser cache
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf

# Optimiser I/O scheduler
echo 'echo deadline > /sys/block/mmcblk0/queue/scheduler' | sudo tee -a /etc/rc.local
```

### 3. Optimisations réseau

```bash
# Optimiser buffer réseau
echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' | sudo tee -a /etc/sysctl.conf

# Désactiver IPv6 (si non utilisé)
echo 'net.ipv6.conf.all.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf
```

### 4. Optimisations stockage

```bash
# Monter /tmp en RAM
echo 'tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100m 0 0' | sudo tee -a /etc/fstab

# Optimiser mount options SD card
sudo nano /etc/fstab
# Modifier: PARTUUID=xxx / ext4 defaults,noatime,nodiratime 0 1
```

### 5. Optimisations energétiques

```bash
# Désactiver WiFi/Bluetooth si non utilisés
echo 'dtoverlay=disable-wifi' | sudo tee -a /boot/firmware/config.txt
echo 'dtoverlay=disable-bt' | sudo tee -a /boot/firmware/config.txt

# Désactiver HDMI si affichage fixe
echo '/opt/vc/bin/tvservice -o' | sudo tee -a /etc/rc.local
```

## ✅ Tests de validation

### 1. Tests automatisés

```bash
# Script de test complet
/opt/pisignage/scripts/test-installation.sh

# Tests individuels
/opt/pisignage/scripts/test-player.sh
/opt/pisignage/scripts/test-web.sh
/opt/pisignage/scripts/test-api.sh
```

### 2. Tests manuels

```bash
# Test 1: Services
systemctl is-active pisignage.service
systemctl is-active nginx.service
systemctl is-active php8.2-fpm.service

# Test 2: Interface web
curl -I http://localhost/
firefox http://localhost/admin.html

# Test 3: Player
pisignage play
pisignage pause
pisignage stop
pisignage status

# Test 4: API REST
curl -X GET http://localhost/api/health.php | jq
curl -X POST http://localhost/api/control.php \
  -H "Content-Type: application/json" \
  -d '{"action":"status"}'

# Test 5: Synchronisation (si installée)
pisignage-sync test
pisignage-sync status
```

### 3. Tests de charge

```bash
# Test lecture vidéo longue durée
pisignage play --loop --duration=3600

# Monitoring ressources
htop &
iotop &
watch -n 1 vcgencmd measure_temp

# Test mémoire
watch -n 1 free -h

# Test réseau
iperf3 -c serveur-test
```

### 4. Validation sécurité

```bash
# Vérifier les permissions
ls -la /opt/pisignage/
ls -la /var/www/html/

# Audit sécurité basique
sudo lynis audit system

# Test firewall
sudo ufw status
nmap localhost
```

## 🔄 Mise à jour

### Mise à jour automatique

```bash
# Via script d'administration
pisignage-admin update

# Via Git (si installé depuis les sources)
cd /opt/pisignage
git pull origin main
./update.sh
```

### Mise à jour manuelle

```bash
# 1. Sauvegarde
pisignage-admin backup

# 2. Télécharger nouvelle version
wget https://github.com/yourusername/pisignage-desktop/archive/v3.1.0.tar.gz
tar -xzf v3.1.0.tar.gz

# 3. Arrêter les services
sudo systemctl stop pisignage.service

# 4. Mise à jour
cd pisignage-desktop-3.1.0
./update.sh

# 5. Redémarrer
sudo systemctl start pisignage.service
```

### Mise à jour sélective modules

```bash
# Mise à jour interface web uniquement
cd modules/
sudo ./02-web-interface.sh --update

# Mise à jour player uniquement
sudo ./03-media-player.sh --update

# Mise à jour services uniquement
sudo ./05-services.sh --update
```

## 🗑️ Désinstallation

### Désinstallation complète

```bash
# Script de désinstallation automatique
sudo ./uninstall.sh

# Désinstallation avec suppression des données
sudo ./uninstall.sh --purge-data

# Désinstallation avec sauvegarde
sudo ./uninstall.sh --backup-data
```

### Désinstallation manuelle

```bash
# 1. Arrêter et désactiver les services
sudo systemctl stop pisignage.service
sudo systemctl disable pisignage.service
sudo rm /etc/systemd/system/pisignage.service

# 2. Supprimer la configuration nginx
sudo rm /etc/nginx/sites-enabled/pisignage
sudo rm /etc/nginx/sites-available/pisignage

# 3. Supprimer les fichiers
sudo rm -rf /opt/pisignage/

# 4. Supprimer l'utilisateur (optionnel)
sudo deluser pisignage

# 5. Nettoyer les paquets
sudo apt autoremove -y
```

### Sauvegarde avant désinstallation

```bash
# Sauvegarde configuration
sudo tar -czf pisignage-backup-$(date +%Y%m%d).tar.gz \
  /opt/pisignage/config/ \
  /opt/pisignage/videos/ \
  /opt/pisignage/images/ \
  /etc/nginx/sites-available/pisignage

# Sauvegarde base de données (si applicable)
mysqldump -u root -p pisignage > pisignage-db-backup.sql
```

## 🐛 Dépannage installation

### Problèmes courants

#### Erreur de permissions

```bash
# Solution
sudo chown -R pisignage:pisignage /opt/pisignage/
sudo chmod +x /opt/pisignage/scripts/*.sh
```

#### GPU non configuré

```bash
# Vérification
vcgencmd get_mem gpu

# Correction
echo 'gpu_mem=128' | sudo tee -a /boot/firmware/config.txt
sudo reboot
```

#### Services ne démarrent pas

```bash
# Diagnostic
sudo systemctl status pisignage.service
journalctl -u pisignage.service -f

# Réinstallation service
sudo ./modules/05-services.sh
```

#### Interface web inaccessible

```bash
# Vérifications
sudo nginx -t
sudo systemctl status nginx
sudo systemctl status php8.2-fpm

# Réinstallation
sudo ./modules/02-web-interface.sh
```

### Logs d'installation

```bash
# Logs principaux
tail -f /var/log/pisignage-setup.log

# Logs système
journalctl -f

# Logs nginx
tail -f /var/log/nginx/error.log

# Logs PHP
tail -f /var/log/php8.2-fpm.log
```

---

*Cette documentation d'installation complète vous guide à travers toutes les étapes nécessaires pour déployer PiSignage Desktop v3.0 avec succès.*