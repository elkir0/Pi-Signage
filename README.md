# 🖥️ PiSignage v0.8.0

**Solution de Digital Signage Complète pour Raspberry Pi**

[![Version](https://img.shields.io/badge/Version-0.8.0-blue.svg)](https://github.com/elkir0/Pi-Signage)
[![PHP](https://img.shields.io/badge/PHP-8.2+-green.svg)](https://php.net)
[![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi-red.svg)](https://raspberrypi.org)

## 📋 Description

PiSignage v0.8.0 est une solution complète de digital signage développée spécifiquement pour Raspberry Pi. Cette version offre une interface web moderne et intuitive pour la gestion complète de votre affichage numérique.

## ✨ Fonctionnalités

### 🎮 Interface Web Moderne
- **Dashboard en temps réel** - Surveillance système (CPU, RAM, température)
- **Design responsive** - Compatible desktop, tablette et mobile
- **Interface glassmorphism** - Design moderne avec effets visuels

### 📁 Gestion Média Avancée
- **Upload multifichiers** - Support drag & drop
- **Formats supportés** : MP4, AVI, MKV, JPG, PNG, MP3, WAV
- **Aperçus automatiques** - Miniatures pour images et vidéos
- **Informations détaillées** - Durée, résolution, taille
- **Gestion intelligente** - Renommage, duplication, suppression sécurisée

### 📝 Créateur de Playlists
- **Interface drag & drop** - Création intuitive
- **Playlists dynamiques** - Modification en temps réel
- **Aperçu en direct** - Visualisation du contenu
- **Gestion des conflits** - Vérification avant suppression

### ▶️ Contrôle Lecteur VLC
- **Contrôles complets** - Play, pause, stop, suivant, précédent
- **Réglage volume** - Contrôle en temps réel
- **Lecture de playlists** - Support playlists complètes
- **Lecture fichier unique** - Mode direct
- **Status en temps réel** - Affichage état lecteur

### 📺 Téléchargement YouTube
- **Support yt-dlp** - Téléchargements optimisés
- **Choix qualité** - 360p à meilleure qualité
- **Audio uniquement** - Extraction audio MP3
- **Barre de progression** - Suivi téléchargement
- **Historique** - Suivi des téléchargements

### 📸 Capture d'Écran
- **Capture temps réel** - Screenshot instantané
- **Auto-capture** - Programmation automatique
- **Historique** - Conservation des captures
- **Multiple formats** - Support différents outils

### ⏰ Programmation Horaire
- **Schedules avancés** - Programmation par jour/heure
- **Playlists programmées** - Activation automatique
- **Gestion calendrier** - Interface intuitive
- **Répétition** - Programmes récurrents

### ⚙️ Configuration Système
- **Affichage** - Résolution, rotation écran
- **Audio** - Sortie, volume par défaut
- **Réseau** - Hostname, timezone
- **Actions système** - Redémarrage, extinction

## 🏗️ Architecture Technique

### Structure du Projet
```
/opt/pisignage/
├── VERSION                 # Version 0.8.0
├── README.md              # Documentation
├── CLAUDE.md              # Contexte développement
├── web/                   # Interface web PHP
│   ├── index.php         # Interface principale
│   ├── config.php        # Configuration système
│   └── api/              # APIs REST
│       ├── system.php    # Informations système
│       ├── media.php     # Gestion médias
│       ├── playlist.php  # Gestion playlists
│       ├── player.php    # Contrôle VLC
│       ├── screenshot.php # Captures d'écran
│       ├── youtube.php   # Téléchargement YouTube
│       ├── upload.php    # Upload fichiers
│       └── scheduler.php # Programmation
├── scripts/              # Scripts système
│   ├── vlc-control.sh    # Contrôle VLC
│   ├── screenshot.sh     # Capture écran
│   └── youtube-dl.sh     # Download YouTube
├── media/                # Stockage médias
├── config/               # Configuration
│   ├── playlists/       # Playlists JSON
│   └── schedules/       # Programmation
├── logs/                 # Logs système
└── screenshots/          # Captures d'écran
```

### Stack Technique
- **Backend** : PHP 8.2+ avec APIs REST
- **Frontend** : HTML5, CSS3, JavaScript Vanilla
- **Base de données** : SQLite pour la configuration
- **Lecteur média** : VLC avec interface HTTP
- **Serveur web** : Nginx optimisé
- **Scripts** : Bash pour l'automatisation

### APIs REST Disponibles

#### `/api/system.php`
- `GET` - Informations système (CPU, RAM, température)
- `POST` - Actions système (redémarrage, configuration)

#### `/api/media.php`
- `GET` - Liste des médias avec métadonnées
- `POST` - Actions sur médias (renommage, duplication)
- `DELETE` - Suppression sécurisée

#### `/api/playlist.php`
- `GET` - Liste des playlists
- `POST` - Création/modification playlists
- `DELETE` - Suppression playlists

#### `/api/player.php`
- `GET` - Status VLC
- `POST` - Contrôles de lecture

#### `/api/youtube.php`
- `POST` - Téléchargement YouTube
- `GET` - Informations vidéo

#### `/api/screenshot.php`
- `POST` - Capture d'écran
- `GET` - Historique captures

#### `/api/upload.php`
- `POST` - Upload multifichiers

#### `/api/scheduler.php`
- `GET` - Liste programmations
- `POST` - Création programmation
- `PUT` - Modification
- `DELETE` - Suppression

## 🚀 Installation Rapide

### Prérequis
- Raspberry Pi 3B+ ou plus récent
- Raspberry Pi OS (Bullseye ou plus récent)
- Connexion Internet

### Installation Automatique
```bash
# Cloner le repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Lancer l'installation
sudo bash install.sh

# Démarrer les services
sudo systemctl enable pisignage
sudo systemctl start pisignage
```

### Installation Manuelle

#### 1. Dépendances Système
```bash
# Mise à jour système
sudo apt update && sudo apt upgrade -y

# Installation PHP et Nginx
sudo apt install -y nginx php8.2-fpm php8.2-sqlite3 php8.2-gd php8.2-curl

# Installation VLC
sudo apt install -y vlc vlc-plugin-base

# Outils additionnels
sudo apt install -y ffmpeg imagemagick scrot yt-dlp
```

#### 2. Configuration Nginx
```bash
# Copier la configuration
sudo cp config/nginx/pisignage.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/pisignage.conf /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Redémarrer Nginx
sudo systemctl restart nginx
```

#### 3. Configuration PHP
```bash
# Optimisation PHP pour uploads
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini

sudo systemctl restart php8.2-fpm
```

#### 4. Configuration VLC
```bash
# Créer configuration VLC
mkdir -p ~/.config/vlc
echo 'http 0.0.0.0 8080 vlcpassword' > ~/.config/vlc/vlcrc

# Permissions
sudo usermod -a -G audio,video $USER
```

#### 5. Déploiement Application
```bash
# Copier les fichiers
sudo cp -r web/ /opt/pisignage/
sudo cp -r scripts/ /opt/pisignage/
sudo chmod +x /opt/pisignage/scripts/*.sh

# Créer dossiers
sudo mkdir -p /opt/pisignage/{media,config,logs,screenshots}
sudo chown -R www-data:www-data /opt/pisignage/
```

## 🔧 Configuration

### Accès Interface Web
- **URL** : `http://[IP_RASPBERRY_PI]`
- **Port** : 80 (HTTP) / 443 (HTTPS)

### Configuration VLC
- **Interface HTTP** : Port 8080
- **Mot de passe** : vlcpassword
- **Mode** : Plein écran automatique

### Répertoires Importants
- **Médias** : `/opt/pisignage/media/`
- **Logs** : `/opt/pisignage/logs/`
- **Config** : `/opt/pisignage/config/`
- **Screenshots** : `/opt/pisignage/screenshots/`

## 📊 Monitoring et Logs

### Logs Système
```bash
# Logs PiSignage
tail -f /opt/pisignage/logs/pisignage.log

# Logs VLC
tail -f /opt/pisignage/logs/vlc.log

# Logs YouTube
tail -f /opt/pisignage/logs/youtube.log

# Logs Nginx
sudo tail -f /var/log/nginx/error.log
```

### Surveillance Système
```bash
# Status des services
sudo systemctl status nginx
sudo systemctl status php8.2-fpm

# Processus VLC
ps aux | grep vlc

# Utilisation disque
df -h /opt/pisignage/media/
```

## 🛠️ Scripts Utilitaires

### Contrôle VLC
```bash
# Démarrer VLC
/opt/pisignage/scripts/vlc-control.sh start

# Lire un fichier
/opt/pisignage/scripts/vlc-control.sh play /path/to/video.mp4

# Status
/opt/pisignage/scripts/vlc-control.sh status
```

### Capture d'Écran
```bash
# Capture manuelle
/opt/pisignage/scripts/screenshot.sh take

# Status outil capture
/opt/pisignage/scripts/screenshot.sh status
```

### YouTube Download
```bash
# Télécharger vidéo
/opt/pisignage/scripts/youtube-dl.sh download "https://youtube.com/watch?v=..."

# Audio uniquement
/opt/pisignage/scripts/youtube-dl.sh audio "https://youtube.com/watch?v=..."
```

## 🔒 Sécurité

### Permissions Fichiers
```bash
# Médias accessibles en lecture
chmod 644 /opt/pisignage/media/*

# Scripts exécutables
chmod +x /opt/pisignage/scripts/*.sh

# Configuration protégée
chmod 600 /opt/pisignage/config/pisignage.db
```

### Pare-feu (Optionnel)
```bash
# UFW basique
sudo ufw allow 80/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

## 🚨 Dépannage

### Problèmes Courants

#### VLC ne démarre pas
```bash
# Vérifier processus
ps aux | grep vlc

# Redémarrer VLC
/opt/pisignage/scripts/vlc-control.sh restart

# Vérifier logs
tail -f /opt/pisignage/logs/vlc.log
```

#### Interface web inaccessible
```bash
# Status Nginx
sudo systemctl status nginx

# Status PHP
sudo systemctl status php8.2-fpm

# Vérifier configuration
sudo nginx -t
```

#### Upload ne fonctionne pas
```bash
# Vérifier permissions
ls -la /opt/pisignage/media/

# Corriger permissions
sudo chown -R www-data:www-data /opt/pisignage/media/
```

#### YouTube download échoue
```bash
# Vérifier yt-dlp
yt-dlp --version

# Mettre à jour
sudo pip3 install --upgrade yt-dlp
```

### Commandes de Diagnostic
```bash
# Test complet système
curl -s http://localhost/api/system.php | python3 -m json.tool

# Test API média
curl -s http://localhost/api/media.php?action=list | python3 -m json.tool

# Test VLC
curl -s --user ":vlcpassword" http://localhost:8080/requests/status.xml
```

## 📈 Optimisations Performance

### Raspberry Pi 4 Recommandations
```bash
# GPU Memory Split
echo 'gpu_mem=128' | sudo tee -a /boot/config.txt

# Overclocking sécurisé
echo 'arm_freq=1800' | sudo tee -a /boot/config.txt
echo 'over_voltage=6' | sudo tee -a /boot/config.txt
```

### Cache Nginx
```bash
# Configuration cache dans nginx.conf
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=media_cache:10m max_size=1g;
```

## 🔄 Mise à Jour

### Mise à jour v0.8.0
```bash
# Sauvegarder médias et config
sudo cp -r /opt/pisignage/media/ ~/backup_media/
sudo cp -r /opt/pisignage/config/ ~/backup_config/

# Télécharger nouvelle version
git pull origin main

# Redémarrer services
sudo systemctl restart nginx php8.2-fpm
```

## 🤝 Contribution

### Développement Local
```bash
# Fork du projet
git clone https://github.com/VOTRE_USERNAME/Pi-Signage.git

# Créer branche feature
git checkout -b feature/nouvelle-fonctionnalite

# Tests
php -S localhost:8000 -t web/
```

### Structure du Code
- **PHP** : PSR-12 coding standard
- **JavaScript** : ES6+ avec JSDoc
- **CSS** : Méthodologie BEM
- **Bash** : ShellCheck compatible

## 📄 Licence

MIT License - voir [LICENSE](LICENSE) pour détails

## 👥 Auteurs

- **Développeur Principal** : [elkir0](https://github.com/elkir0)
- **Contributions** : Voir [CONTRIBUTORS.md](CONTRIBUTORS.md)

## 🙏 Remerciements

- **VLC Team** pour le lecteur média
- **Raspberry Pi Foundation** pour la plateforme
- **PHP Community** pour les outils
- **Contributeurs Open Source**

## 📞 Support

### Documentation
- **Wiki** : [GitHub Wiki](https://github.com/elkir0/Pi-Signage/wiki)
- **FAQ** : [Foire aux questions](https://github.com/elkir0/Pi-Signage/wiki/FAQ)

### Contact
- **Issues** : [GitHub Issues](https://github.com/elkir0/Pi-Signage/issues)
- **Discussions** : [GitHub Discussions](https://github.com/elkir0/Pi-Signage/discussions)

### Communauté
- **Discord** : [Serveur PiSignage](https://discord.gg/pisignage)
- **Reddit** : [r/PiSignage](https://reddit.com/r/PiSignage)

---

<div align="center">

**🖥️ PiSignage v0.8.0 - Digital Signage pour Raspberry Pi 🖥️**

[🏠 Accueil](https://github.com/elkir0/Pi-Signage) • [📖 Documentation](https://github.com/elkir0/Pi-Signage/wiki) • [🐛 Issues](https://github.com/elkir0/Pi-Signage/issues) • [💬 Discussions](https://github.com/elkir0/Pi-Signage/discussions)

</div>