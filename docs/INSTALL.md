<<<<<<< HEAD
# PiSignage Installation Guide

This comprehensive guide will walk you through the complete installation process for PiSignage on your Raspberry Pi.

## 📋 Prerequisites

### Hardware Requirements

- **Raspberry Pi 4** (2GB RAM minimum, 4GB+ recommended)
- **MicroSD Card** (16GB+ Class 10 or USB SSD for better performance)
- **Power Supply** (Official 5V/3A adapter recommended)
- **HDMI Cable** and compatible display
- **Network Connection** (Ethernet preferred, Wi-Fi supported)
- **Keyboard and Mouse** (for initial setup)

### Software Requirements

- **Raspberry Pi OS Desktop** (Bookworm or Bullseye)
- **SSH Access** (enabled during OS installation)
- **Internet Connection** (for package downloads)

## 🚀 Installation Methods

### Method 1: Quick Installation (Recommended)

This is the fastest way to get PiSignage running on your Raspberry Pi.

#### Step 1: Prepare Raspberry Pi OS

1. Download [Raspberry Pi Imager](https://www.raspberrypi.org/software/)
2. Flash **Raspberry Pi OS Desktop** to your SD card
3. **Before ejecting**, configure the following in the imager:
   - Enable SSH
   - Set username: `pi`
   - Set a secure password
   - Configure Wi-Fi (if using wireless)
   - Set locale settings

#### Step 2: First Boot and SSH Connection

1. Insert SD card and boot the Raspberry Pi
2. Find the Pi's IP address:
   ```bash
   # From your computer
   nmap -sn 192.168.1.0/24
   # Or check your router's admin panel
   ```

3. Connect via SSH:
   ```bash
   ssh pi@YOUR_PI_IP
   ```

#### Step 3: Install PiSignage

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Clone PiSignage repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Run installation
sudo make install
```

The installer will:
- Install all required packages (VLC, nginx, PHP, etc.)
- Configure system services
- Set up the web interface
- Configure hardware acceleration
- Create systemd services
- Set up automatic startup

#### Step 4: Verify Installation

```bash
# Check service status
make status

# Test video playback
./src/scripts/player-control.sh start

# Access web interface
# Open browser: http://YOUR_PI_IP/
```

### Method 2: Manual Installation

For users who prefer step-by-step control or need custom configurations.

#### Step 1: System Preparation

```bash
# Update package list
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y git curl wget htop nano

# Configure GPU memory
echo "gpu_mem=128" | sudo tee -a /boot/config.txt

# Enable hardware acceleration
echo "dtoverlay=vc4-kms-v3d" | sudo tee -a /boot/config.txt
echo "max_framebuffers=2" | sudo tee -a /boot/config.txt

# Reboot to apply changes
sudo reboot
```

#### Step 2: Install Media Player

```bash
# Install VLC with hardware acceleration support
sudo apt install -y vlc vlc-plugin-base

# Verify VLC installation
vlc --version
```

#### Step 3: Install Web Server

```bash
# Install nginx and PHP
sudo apt install -y nginx php8.2-fpm php8.2-cli php8.2-json php8.2-curl

# Start and enable services
sudo systemctl start nginx php8.2-fpm
sudo systemctl enable nginx php8.2-fpm
```

#### Step 4: Configure PiSignage

```bash
# Clone repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Copy web files
sudo cp -r web/* /var/www/html/

# Set permissions
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/

# Install systemd services
sudo cp src/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable vlc-signage
```

#### Step 5: Configure Nginx

```bash
# Backup default config
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

# Apply PiSignage nginx configuration
sudo cp src/config/nginx.conf /etc/nginx/sites-available/default

# Test configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
```

## 🔧 Post-Installation Configuration

### Display Configuration

#### For Standard HDMI Displays

```bash
# Edit boot configuration
sudo nano /boot/config.txt

# Add these lines for better compatibility:
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=16  # 1080p 60Hz
```

#### For 4K Displays

```bash
# In /boot/config.txt
hdmi_enable_4kp60=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt=3840 2160 60
```

### Network Configuration

#### Static IP Configuration

```bash
# Edit DHCP configuration
sudo nano /etc/dhcpcd.conf

# Add at the end:
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4
```

#### Wi-Fi Configuration

```bash
# Configure Wi-Fi
sudo raspi-config
# Navigate to: Network Options > Wi-Fi
# Or edit directly:
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
```

### Performance Optimization

#### GPU Optimization

```bash
# Edit /boot/config.txt
sudo nano /boot/config.txt

# Add GPU optimizations:
gpu_mem=128
gpu_freq=600
v3d_freq=600
over_voltage=2
arm_freq=1800
```

#### System Optimization

```bash
# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable hciuart
sudo systemctl disable avahi-daemon

# Configure automatic login
sudo raspi-config
# System Options > Boot / Auto Login > Desktop Autologin
```

## 🎯 Testing Installation

### Basic Functionality Test

```bash
# Run comprehensive tests
make test

# Test video playback
./tests/test-video-playback.sh

# Check web interface
curl -s http://localhost/ | grep -i pisignage
```

### Performance Test

```bash
# Monitor system performance
./src/scripts/performance-monitor.sh

# Check GPU acceleration
glxinfo | grep "OpenGL renderer"

# Verify hardware decoding
./tests/test-hardware-acceleration.sh
```

### Service Status Check

```bash
# Check all PiSignage services
make status

# Individual service checks
sudo systemctl status vlc-signage
sudo systemctl status nginx
sudo systemctl status php8.2-fpm
```

## 🐛 Troubleshooting Installation

### Common Installation Issues

#### Package Installation Failures

```bash
# Fix broken packages
sudo apt --fix-broken install

# Clear package cache
sudo apt clean && sudo apt autoclean

# Update package lists
sudo apt update --fix-missing
```

#### Permission Issues

```bash
# Fix web directory permissions
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/

# Fix PiSignage directory permissions
sudo chown -R pi:pi /opt/pisignage/
chmod +x /opt/pisignage/src/scripts/*.sh
```

#### Service Start Failures

```bash
# Check service logs
sudo journalctl -u vlc-signage -n 50
sudo journalctl -u nginx -n 50

# Restart services
sudo systemctl restart vlc-signage nginx php8.2-fpm

# Reload systemd daemon
sudo systemctl daemon-reload
```

### GPU Acceleration Issues

#### Verify GPU Setup

```bash
# Check GPU memory
vcgencmd get_mem gpu

# Verify OpenGL
glxinfo | grep -E "(OpenGL vendor|OpenGL renderer)"

# Test hardware decoding
./tests/test-gpu-acceleration.sh
```

#### Fix GPU Issues

```bash
# Ensure GPU packages are installed
sudo apt install -y mesa-utils libgl1-mesa-dri

# Add user to video group
sudo usermod -a -G video pi

# Reboot to apply changes
sudo reboot
```

### Network Access Issues

#### Firewall Configuration

```bash
# Check if UFW is active
sudo ufw status

# Allow HTTP traffic
sudo ufw allow 80/tcp
sudo ufw allow 22/tcp  # SSH

# Or disable firewall for testing
sudo ufw disable
```

#### Service Binding Issues

```bash
# Check what's listening on port 80
sudo netstat -tlnp | grep :80

# Restart nginx with proper configuration
sudo nginx -t && sudo systemctl restart nginx
```

## 🔄 Updating PiSignage

### Regular Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update PiSignage
cd /opt/pisignage
git pull origin main
sudo make install  # Re-run installer for updates
```

### Version Migration

```bash
# Backup current configuration
./src/scripts/backup-config.sh

# Pull latest version
git fetch --all
git checkout main
git pull

# Run migration script
./deploy/migrate.sh
```

## 📋 Installation Checklist

Use this checklist to ensure complete installation:

- [ ] Raspberry Pi OS Desktop installed and updated
- [ ] SSH access configured and working
- [ ] PiSignage repository cloned
- [ ] Installation completed without errors
- [ ] Services running (vlc-signage, nginx, php8.2-fpm)
- [ ] Web interface accessible
- [ ] Video playback working
- [ ] GPU acceleration verified
- [ ] Performance benchmarks satisfactory
- [ ] Network configuration optimized
- [ ] Automatic startup configured
- [ ] Backup strategy implemented

## 📞 Getting Help

If you encounter issues during installation:

1. **Check the logs**: `sudo journalctl -u vlc-signage -f`
2. **Run diagnostics**: `./src/scripts/diagnostics.sh`
3. **Consult troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
4. **Community support**: [GitHub Issues](https://github.com/elkir0/Pi-Signage/issues)
5. **Documentation**: [Project Wiki](https://github.com/elkir0/Pi-Signage/wiki)

## 🎉 Next Steps

After successful installation:

1. **Configure your first playlist**: Access the web interface
2. **Upload media content**: Use the media manager
3. **Set up monitoring**: Configure system alerts
4. **Customize settings**: Adjust performance and display options
5. **Plan maintenance**: Set up regular updates and backups

---

**Installation complete! Your Raspberry Pi is now a professional digital signage display.**
=======
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
>>>>>>> e3d23eed5cb67ecaebb350b4b797596c74b65e7a
