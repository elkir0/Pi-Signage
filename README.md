# 📺 Pi Signage Digital - Solution Complète

**Solution tout-en-un de digital signage pour Raspberry Pi avec interface web de gestion**

[![Compatible](https://img.shields.io/badge/Compatible-Pi%203B%2B%20%7C%204B%20%7C%205-green.svg)](https://www.raspberrypi.org/)
[![Version](https://img.shields.io/badge/Version-2.4.0-blue.svg)]()
[![License](https://img.shields.io/badge/License-MIT-blue.svg)]()
[![Security](https://img.shields.io/badge/Security-Enhanced-brightgreen.svg)]()

> ✅ **Version stable 2.4.0** : Solution complète avec support audio, gestion de playlist, logo personnalisé et interface web améliorée.

## 🎯 Présentation

Pi Signage Digital est une solution professionnelle complète pour transformer vos Raspberry Pi en système d'affichage dynamique. Ce projet offre une installation automatisée avec une sécurité renforcée et une interface web moderne.

### 🎬 Nouveautés v2.4.0 - Version stable
- **Support audio complet** : Configuration HDMI/Jack avec volume réglable
- **Page de gestion de playlist** : Organisation de l'ordre de lecture
- **Logo Pi Signage intégré** : Branding personnalisé dans toute l'interface
- **API player.php** : Contrôle complet du player (play/pause/stop/next)
- **Téléchargement YouTube amélioré** : Format MP4 forcé, verbose persistant
- **Scripts utilitaires audio** : Configuration et test du son
- **Mise à jour automatique playlist** : Après upload ou téléchargement
- **Corrections majeures** : exec() PHP, format vidéo, playlist Chromium

### 🔐 Fonctionnalités de sécurité
- **Chiffrement des mots de passe** avec AES-256-CBC
- **Gestion d'erreurs robuste** avec retry logic
- **Permissions restrictives** sur tous les fichiers sensibles
- **Protection CSRF** dans l'interface web
- **Module de sécurité centralisé** pour tous les scripts
- **Authentification SHA-512** avec salt pour l'interface web

## 📁 Structure du Projet

```
Pi-Signage/
├── raspberry-pi-installer/       # Scripts d'installation et configuration
│   ├── scripts/                 # Modules d'installation
│   │   ├── 00-security-utils.sh # Module de sécurité centralisé
│   │   ├── 01-system-config.sh  # Configuration système
│   │   ├── 02-display-manager.sh # Gestionnaire d'affichage (pour VLC)
│   │   ├── 03-vlc-setup.sh      # Installation VLC Classic
│   │   ├── 03-chromium-kiosk.sh # Installation Chromium Kiosk (nouveau!)
│   │   ├── 04-rclone-gdrive.sh  # Synchronisation Google Drive
│   │   ├── 05-glances-setup.sh  # Monitoring
│   │   ├── 06-cron-setup.sh     # Tâches planifiées
│   │   ├── 07-services-setup.sh # Services systemd
│   │   ├── 08-diagnostic-tools.sh # Outils de diagnostic
│   │   ├── 09-web-interface-v2.sh # Interface web (nouvelle version)
│   │   └── main_orchestrator.sh # Script principal d'installation
│   ├── docs/                    # Documentation technique
│   └── examples/                # Fichiers de configuration exemple
│
└── web-interface/               # Interface web de gestion
    ├── public/                  # Fichiers accessibles publiquement
    ├── includes/                # Logique PHP et sécurité
    ├── api/                     # Points d'accès API REST
    ├── assets/                  # CSS, JS, images
    └── templates/               # Templates réutilisables
```

## 🚀 Installation Rapide

### Prérequis
- **Raspberry Pi** : 3B+, 4B (2GB minimum recommandé) ou 5
- **Carte SD** : 32GB minimum (Classe 10 ou supérieure)
- **OS** : Raspberry Pi OS Lite 64-bit (Bookworm)
- **Réseau** : Connexion internet stable

### Installation

#### Installation de la version 2.4.0

```bash
# Cloner le dépôt
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/raspberry-pi-installer/scripts

# Rendre les scripts exécutables
chmod +x *.sh

# Lancer l'installation v2.4.0
sudo ./main_orchestrator.sh
```

#### Installation sur VM/Headless pour tests

```bash
# Cloner le dépôt
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/raspberry-pi-installer/scripts

# Installation avec support Xvfb automatique
chmod +x *.sh
sudo ./main_orchestrator.sh

# Le script détecte automatiquement l'environnement VM et installe Xvfb
```

#### Résolution de problèmes

Si vous obtenez l'erreur "variable en lecture seule" :
```bash
# Option 1 : Nettoyer l'environnement
unset LOG_FILE CONFIG_FILE
sudo ./main_orchestrator.sh

# Option 2 : Utiliser un nouveau shell
sudo bash ./main_orchestrator.sh
```

#### Modes d'affichage disponibles (nouveau!)

**1. VLC Classic** (traditionnel)
- ✅ Support de tous les formats vidéo
- ✅ Stabilité éprouvée 24/7
- ✅ Optimisations hardware
- ❌ Plus de ressources (~350MB RAM)
- ❌ Démarrage plus lent (~45s)

**2. Chromium Kiosk** (moderne)
- ✅ Démarrage rapide (~25s)
- ✅ Moins de RAM (~250MB)
- ✅ Support HTML5/CSS/JS
- ✅ Overlays et transitions
- ❌ Formats limités (H.264/WebM)

L'installation est **modulaire** - vous pouvez choisir :
- Le mode d'affichage (VLC ou Chromium)
- Les composants à installer
- Le niveau de fonctionnalités

## 📖 Documentation

### Guides principaux
- **[🚀 Guide de démarrage rapide](raspberry-pi-installer/docs/quickstart_guide.md)**
- **[📘 Guide d'installation détaillé](raspberry-pi-installer/docs/README.md)**
- **[🔧 Guide technique complet](raspberry-pi-installer/docs/technical_guide.md)**
- **[🔐 Guide de sécurité](raspberry-pi-installer/docs/SECURITY.md)**
- **[🌐 Documentation interface web](web-interface/README.md)**
- **[📝 Guide de migration v2](raspberry-pi-installer/MIGRATION.md)**
- **[📺 Guide Chromium Kiosk](raspberry-pi-installer/docs/CHROMIUM_KIOSK_GUIDE.md)**
- **[🔧 Guide outils admin](raspberry-pi-installer/scripts/admin-tools/ADMIN-TOOLS-GUIDE.md)**

### Guides spécifiques
- [Dépannage](raspberry-pi-installer/docs/troubleshooting.md)
- [Proposition Chromium](raspberry-pi-installer/docs/CHROMIUM_KIOSK_PROPOSAL.md)
- [Changelog complet](CHANGELOG.md)

## ✨ Fonctionnalités

### 🖥️ Système Raspberry Pi
- ✅ **Deux modes de lecture** : VLC Classic ou Chromium Kiosk (nouveau!)
- ✅ **Lecture vidéos optimisée** : Support multi-formats avec VLC
- ✅ **Player HTML5 moderne** : Interface web avec Chromium
- ✅ **Synchronisation Google Drive** : Mise à jour automatique des contenus
- ✅ **Installation modulaire** : Choisissez uniquement ce dont vous avez besoin
- ✅ **Surveillance automatique** : Récupération en cas de problème
- ✅ **Sécurité renforcée** : Chiffrement, permissions strictes, validation

### 🌐 Interface Web
- ✅ **Dashboard moderne** : Vue d'ensemble en temps réel avec logo
- ✅ **Gestion des vidéos** : Upload, suppression, organisation
- ✅ **Gestion de playlist** : Page dédiée pour organiser l'ordre de lecture
- ✅ **Téléchargement YouTube** : Amélioré avec verbose persistant
- ✅ **API de contrôle** : player.php pour contrôler la lecture
- ✅ **Monitoring système** : CPU, RAM, température, stockage
- ✅ **Contrôle à distance** : Démarrer/arrêter les services
- ✅ **Page paramètres** : Gestion des services et mise à jour playlist
- ✅ **Détection du mode** : Interface adaptée selon VLC ou Chromium
- ✅ **Sécurité** : Authentification SHA-512, CSRF, headers de sécurité

### 🔐 Sécurité
- ✅ **Module de sécurité centralisé** : Fonctions réutilisables
- ✅ **Chiffrement AES-256-CBC** : Pour les mots de passe stockés
- ✅ **Hachage SHA-512** : Pour l'authentification web
- ✅ **Retry logic** : Gestion robuste des erreurs réseau
- ✅ **Permissions restrictives** : 600/640/750 selon les besoins
- ✅ **Journalisation de sécurité** : Audit des événements

## 🛠️ Configuration

### Configuration minimale
- **Pi 3B+** : 1GB RAM, carte SD 32GB
- **Pi 4B** : 2GB RAM recommandé, carte SD 32GB+
- **Pi 5** : Configuration par défaut, carte SD 64GB recommandé

### Ports utilisés
- **80** : Interface web (nginx)
- **61208** : Monitoring Glances
- **8080** : API VLC (localhost uniquement)
- **8888** : Player HTML5 Chromium (nouveau!)
- **8889** : WebSocket pour contrôle player (localhost)

## 🔧 Commandes Utiles

### Mode VLC Classic
```bash
# Contrôle du service
sudo systemctl status vlc-signage
sudo systemctl restart vlc-signage

# Logs
sudo journalctl -u vlc-signage -f
```

### Mode Chromium Kiosk
```bash
# Contrôle du player
sudo /opt/scripts/player-control.sh play
sudo /opt/scripts/player-control.sh pause
sudo /opt/scripts/player-control.sh next
sudo /opt/scripts/player-control.sh status

# Service
sudo systemctl status chromium-kiosk
sudo systemctl restart chromium-kiosk

# Mise à jour playlist
sudo /opt/scripts/update-playlist.sh

# Logs
tail -f /var/log/pi-signage/chromium.log
```

### Commun aux deux modes
```bash
# Diagnostic
sudo pi-signage-diag                 # Diagnostic complet

# Mise à jour
sudo /opt/scripts/util-update-web-interface.sh      # Mettre à jour l'interface web
#   (ajouter --full pour réinitialiser la configuration)

# Configuration
sudo /opt/scripts/util-configure-audio.sh      # Configurer l'audio (HDMI/Jack)
sudo /opt/scripts/util-test-audio.sh           # Tester le son
```

## 📊 Accès aux Interfaces

- **Interface web** : `http://[IP_DU_PI]/`
  - Utilisateur : `admin`
  - Mot de passe : défini lors de l'installation
  
- **Monitoring Glances** : `http://[IP_DU_PI]:61208`
  - Utilisateur : `admin`
  - Mot de passe : défini lors de l'installation

- **Player HTML5** (mode Chromium) : `http://[IP_DU_PI]:8888/player.html`
  - Accès local pour visualisation
  - Contrôle via WebSocket

## 🔄 Mises à jour

Le système inclut des scripts de mise à jour automatique :
- **yt-dlp** : Mis à jour chaque semaine automatiquement
- **Interface web** : Peut être mise à jour depuis GitHub

Pour une mise à jour manuelle :
```bash
cd /path/to/Pi-Signage
git pull
sudo /opt/scripts/util-update-web-interface.sh       # --full pour reinitialiser
```

## 📋 Changelog v2.4.0

### Nouvelles fonctionnalités
- ✅ **Support audio complet** : HDMI/Jack, volume 85% par défaut
- ✅ **Page playlist.php** : Gestion de l'ordre de lecture
- ✅ **API player.php** : Contrôle play/pause/stop/next/update_playlist
- ✅ **Logo Pi Signage** : Intégré dans navigation, login et favicon
- ✅ **Scripts audio** : util-configure-audio.sh et util-test-audio.sh
- ✅ **Wrapper yt-dlp** : Force le format MP4 pour compatibilité

### Corrections majeures
- ✅ Fonction exec() réactivée dans PHP pour yt-dlp
- ✅ Format vidéo YouTube forcé en MP4 (plus de MKV)
- ✅ Mise à jour automatique playlist après upload
- ✅ Verbose YouTube persistant avec bouton fermeture
- ✅ Autoplay avec son dans Chromium (attribut muted retiré)
- ✅ Support fichiers MKV dans update-playlist.sh

## 🤝 Contribution

Les contributions sont les bienvenues ! 

### Comment contribuer
1. 🍴 Fork le projet
2. 🔧 Créez votre branche (`git checkout -b feature/AmazingFeature`)
3. 📝 Committez vos changements (`git commit -m 'Add AmazingFeature'`)
4. 📤 Push vers la branche (`git push origin feature/AmazingFeature`)
5. 🔄 Ouvrez une Pull Request

### Domaines prioritaires
- 🔐 Améliorations de sécurité
- 🎨 Interface utilisateur
- 📱 Support mobile
- 🌍 Internationalisation
- 📊 Nouvelles fonctionnalités de monitoring

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

- La communauté Raspberry Pi
- Les contributeurs du projet
- Les projets open source utilisés (VLC, nginx, PHP, etc.)

## 📞 Support

- **Issues GitHub** : Pour signaler des bugs ou demander des fonctionnalités
- **Discussions** : Pour les questions générales et l'aide
- **Wiki** : Documentation communautaire (à venir)

---

**Pi Signage Digital** - Transformez vos Raspberry Pi en système d'affichage professionnel sécurisé 🚀🔐