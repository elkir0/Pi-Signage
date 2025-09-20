<<<<<<< HEAD
# Documentation

Ce dossier contient la documentation du système PiSignage.

## Structure
- Guides d'installation
- Documentation d'utilisation
- Documentation technique
- FAQ et résolution de problèmes

## Contenu
Documentation complète pour l'installation, la configuration et l'utilisation du système d'affichage numérique.
=======
# PiSignage Desktop v3.0

[![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/yourusername/pisignage-desktop)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%20OS%20Desktop-red.svg)](https://www.raspberrypi.org/)
[![Status](https://img.shields.io/badge/status-stable-brightgreen.svg)](https://github.com/yourusername/pisignage-desktop/releases)

## 🎯 Présentation

PiSignage Desktop v3.0 est une solution moderne et modulaire d'affichage dynamique (digital signage) conçue spécifiquement pour Raspberry Pi OS Desktop. Cette version représente un refactoring complet privilégiant la simplicité, la modularité et l'intégration native avec l'environnement Desktop.

### 🚀 Nouveautés v3.0

- **Architecture modulaire** : 5 modules indépendants pour une installation sur-mesure
- **Interface web responsive** : Player HTML5 et interface d'administration moderne
- **Intégration Desktop native** : Utilise Chromium et les services systèmes intégrés
- **API REST complète** : Contrôle programmatique via endpoints REST
- **Synchronisation cloud** : Support Google Drive, Dropbox via rclone
- **Monitoring avancé** : Services systemd, health check et watchdog automatique

## 📋 Table des matières

- [Présentation](#-présentation)
- [Fonctionnalités](#-fonctionnalités)
- [Captures d'écran](#-captures-décran)
- [Installation rapide](#-installation-rapide)
- [Configuration](#-configuration)
- [Usage quotidien](#-usage-quotidien)
- [Architecture](#-architecture)
- [Dépannage](#-dépannage)
- [FAQ](#-faq)
- [Contribution](#-contribution)
- [Licence](#-licence)

## ✨ Fonctionnalités

### 🎥 Lecteur multimédia
- **Formats supportés** : MP4, WebM, AVI, MOV, MKV
- **Player HTML5** : Transition fluide, contrôles tactiles
- **Mode kiosk** : Affichage plein écran optimisé
- **Rotation automatique** : Playlists et lecture en boucle
- **Fallback VLC** : Compatibilité étendue pour tous formats

### 🌐 Interface web moderne
- **Design responsive** : Optimisé mobile et desktop
- **Player intégré** : Lecture directe dans le navigateur
- **Interface admin** : Gestion des médias et configuration
- **API REST** : Contrôle programmatique complet
- **Monitoring** : Health check et status en temps réel

### ☁️ Synchronisation cloud
- **Providers multiples** : Google Drive, Dropbox, OneDrive
- **Sync bidirectionnelle** : Upload et download automatique
- **Planification** : Tâches cron configurables
- **Gestion conflits** : Résolution intelligente des conflits

### 🔧 Administration système
- **Services systemd** : Intégration native Linux
- **Watchdog automatique** : Redémarrage en cas de problème
- **Logs centralisés** : Journald et fichiers locaux
- **Monitoring** : Métriques CPU, mémoire, disque
- **Auto-update** : Mise à jour via scripts dédiés

### 📱 Contrôle à distance
- **API REST** : Endpoints pour tous les contrôles
- **Interface web** : Contrôle via navigateur
- **CLI** : Commandes système intégrées
- **SSH** : Accès distant sécurisé

## 📸 Captures d'écran

### Interface Player Principal
```
[📺 Screenshot - Player en mode kiosk]
- Lecture vidéo plein écran
- Contrôles tactiles minimaux
- Transitions fluides
```

### Interface d'Administration
```
[⚙️ Screenshot - Interface admin]
- Dashboard de contrôle
- Gestion des médias
- Configuration système
- Monitoring en temps réel
```

### Application Mobile
```
[📱 Screenshot - Interface mobile]
- Design responsive
- Contrôles tactiles
- Status en temps réel
```

## 🚀 Installation rapide

### Prérequis système
- **Raspberry Pi** : Model 4+ recommandé (2GB RAM minimum)
- **OS** : Raspberry Pi OS Desktop (Bookworm+) ou Debian 12+
- **Stockage** : Carte SD 32GB+ (Classe 10)
- **Réseau** : Connexion Internet pour installation
- **GPU** : Accélération matérielle activée

### Installation automatique

```bash
# 1. Télécharger et extraire
wget https://github.com/yourusername/pisignage-desktop/archive/v3.0.0.tar.gz
tar -xzf v3.0.0.tar.gz
cd pisignage-desktop-3.0.0

# 2. Installation complète
chmod +x install.sh
./install.sh

# 3. Installation avec logs détaillés
VERBOSE=true ./install.sh

# 4. Redémarrage requis
sudo reboot
```

### Installation modulaire

```bash
# Installation module par module
cd modules/

# 1. Configuration base (obligatoire)
sudo ./01-base-config.sh

# 2. Interface web (obligatoire)
sudo ./02-web-interface.sh

# 3. Player multimédia (obligatoire)
sudo ./03-media-player.sh

# 4. Synchronisation cloud (optionnel)
sudo ./04-sync-optional.sh

# 5. Services et monitoring (recommandé)
sudo ./05-services.sh
```

### Vérification installation

```bash
# Status des services
pisignage-admin status

# Health check
curl http://localhost/api/health.php

# Interface web
firefox http://localhost/admin.html
```

## ⚙️ Configuration

### Configuration système

```bash
# Fichier principal de configuration
sudo nano /opt/pisignage/config/pisignage.conf

# Variables d'environnement
export PISIGNAGE_HOME=/opt/pisignage
export PISIGNAGE_LOG_LEVEL=INFO
export PISIGNAGE_WEB_PORT=80
```

### Configuration player

```json
// /opt/pisignage/config/player.json
{
    "player": {
        "autoplay": true,
        "loop": true,
        "volume": 1.0,
        "showControls": false,
        "transitionDelay": 1000
    },
    "display": {
        "fullscreen": true,
        "hidePointer": true,
        "disableScreensaver": true
    },
    "media": {
        "formats": ["mp4", "webm", "avi", "mov"],
        "defaultDuration": 30,
        "scaleMode": "fit"
    }
}
```

### Configuration réseau

```bash
# Configuration nginx
sudo nano /etc/nginx/sites-available/pisignage

# PHP-FPM (auto-détecté)
sudo nano /etc/php/8.2/fpm/pool.d/pisignage.conf

# Firewall (optionnel)
sudo ufw allow 80/tcp
sudo ufw allow 22/tcp
```

### Configuration cloud

```bash
# Configuration rclone interactive
rclone config

# Exemple Google Drive
# Provider: Google Drive
# Client ID: (défaut)
# Client Secret: (défaut)
# Scope: drive
# Token: (autorisation browser)
```

## 🎮 Usage quotidien

### Gestion des médias

```bash
# Ajouter des vidéos
sudo cp /home/pi/mes-videos/*.mp4 /opt/pisignage/videos/
sudo chown -R pisignage:pisignage /opt/pisignage/videos/

# Ajouter des images
sudo cp /home/pi/mes-images/*.jpg /opt/pisignage/images/
sudo chown -R pisignage:pisignage /opt/pisignage/images/

# Vérifier les médias
ls -la /opt/pisignage/videos/
ls -la /opt/pisignage/images/
```

### Contrôle du player

```bash
# Commandes de base
pisignage play          # Lecture
pisignage pause         # Pause
pisignage stop          # Arrêt
pisignage next          # Média suivant
pisignage previous      # Média précédent
pisignage restart       # Redémarrage player

# Status et information
pisignage status        # Status actuel
pisignage list          # Liste des médias
pisignage info          # Informations système
```

### Interface web

```bash
# Accès local
http://localhost/
http://localhost/admin.html

# Accès réseau
http://IP-DU-PI/
http://IP-DU-PI/admin.html

# API REST
curl -X GET http://localhost/api/videos.php
curl -X POST http://localhost/api/control.php -d '{"action":"play"}'
```

### Synchronisation cloud

```bash
# Commandes de synchronisation
pisignage-sync upload      # Upload vers cloud
pisignage-sync download    # Download depuis cloud
pisignage-sync sync        # Synchronisation bidirectionnelle
pisignage-sync status      # Status synchronisation

# Configuration
pisignage-sync config      # Configuration interactive
pisignage-sync test        # Test de connexion
```

### Administration système

```bash
# Gestion des services
pisignage-admin start      # Démarrage
pisignage-admin stop       # Arrêt
pisignage-admin restart    # Redémarrage
pisignage-admin status     # Status complet

# Monitoring
pisignage-admin health     # Health check
pisignage-admin logs       # Logs en temps réel
pisignage-admin stats      # Statistiques système

# Maintenance
pisignage-admin update     # Mise à jour
pisignage-admin backup     # Sauvegarde
pisignage-admin cleanup    # Nettoyage
```

## 🏗️ Architecture

### Structure des répertoires

```
/opt/pisignage/                 # Répertoire principal
├── videos/                     # Fichiers vidéo
├── images/                     # Fichiers image
├── playlists/                  # Listes de lecture
├── web/                        # Interface web
│   ├── public/                 # Fichiers publics
│   ├── api/                    # Endpoints API
│   ├── assets/                 # CSS, JS, images
│   └── includes/               # Fichiers PHP partagés
├── scripts/                    # Scripts de contrôle
│   ├── player.sh              # Script player principal
│   ├── sync.sh                # Script synchronisation
│   └── admin.sh               # Script administration
├── config/                     # Configuration
│   ├── pisignage.conf         # Configuration principale
│   ├── player.json            # Configuration player
│   └── rclone.conf            # Configuration cloud
├── logs/                       # Logs locaux
│   ├── player.log             # Logs player
│   ├── sync.log               # Logs synchronisation
│   └── admin.log              # Logs administration
└── templates/                  # Templates configuration
    ├── nginx.conf.template    # Template nginx
    ├── systemd.service.template # Template service
    └── autostart.desktop.template # Template autostart
```

### Services systemd

```bash
# Services principaux
pisignage.service              # Service principal
pisignage-watchdog.service     # Service surveillance
pisignage-sync.service         # Service synchronisation

# Timers
pisignage-watchdog.timer       # Timer surveillance
pisignage-sync.timer           # Timer synchronisation

# Gestion
systemctl status pisignage.service
systemctl enable pisignage.service
journalctl -u pisignage.service -f
```

### API REST

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/health.php` | GET | Health check système |
| `/api/videos.php` | GET | Liste des vidéos |
| `/api/images.php` | GET | Liste des images |
| `/api/playlists.php` | GET/POST | Gestion playlists |
| `/api/control.php` | POST | Contrôle player |
| `/api/status.php` | GET | Status player |
| `/api/config.php` | GET/POST | Configuration |
| `/api/logs.php` | GET | Consultation logs |

## 🔧 Dépannage

### Problèmes courants

#### Player ne démarre pas

```bash
# 1. Vérifier les services
pisignage-admin status

# 2. Vérifier les logs
journalctl -u pisignage.service -f

# 3. Redémarrer les services
sudo systemctl restart pisignage.service

# 4. Vérifier la configuration GPU
grep gpu_mem /boot/firmware/config.txt
# Doit contenir: gpu_mem=128
```

#### Interface web inaccessible

```bash
# 1. Vérifier nginx
sudo systemctl status nginx

# 2. Vérifier PHP-FPM
sudo systemctl status php8.2-fpm

# 3. Vérifier les permissions
sudo chown -R www-data:www-data /opt/pisignage/web/

# 4. Redémarrer les services web
sudo systemctl restart nginx php8.2-fpm
```

#### Vidéo ne s'affiche pas

```bash
# 1. Vérifier les codecs
ffprobe /opt/pisignage/videos/test.mp4

# 2. Vérifier les permissions
ls -la /opt/pisignage/videos/

# 3. Test en mode debug
VERBOSE=true pisignage play

# 4. Fallback VLC
/opt/pisignage/scripts/vlc-player.sh
```

#### Synchronisation cloud échoue

```bash
# 1. Tester la connexion
rclone test gdrive:

# 2. Vérifier la configuration
rclone config show

# 3. Test manuel
rclone ls gdrive:pisignage/

# 4. Logs de synchronisation
tail -f /opt/pisignage/logs/sync.log
```

### Logs et debugging

```bash
# Logs système (journald)
journalctl -u pisignage.service -f
journalctl -u pisignage-watchdog.service -f

# Logs applicatifs
tail -f /opt/pisignage/logs/player.log
tail -f /opt/pisignage/logs/sync.log
tail -f /opt/pisignage/logs/admin.log

# Logs installation
tail -f /var/log/pisignage-setup.log

# Mode debug
export PISIGNAGE_DEBUG=true
pisignage restart
```

### Performance et optimisation

```bash
# Monitoring ressources
htop
iotop
free -h
df -h

# Optimisation GPU
sudo raspi-config
# Advanced Options > Memory Split > 128

# Optimisation système
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
```

## ❓ FAQ

### Installation et configuration

**Q: Quels sont les prérequis minimum ?**
R: Raspberry Pi 4 avec 2GB RAM, carte SD 32GB classe 10, Raspberry Pi OS Desktop Bookworm.

**Q: Peut-on installer sur d'autres distributions ?**
R: Oui, Debian 12+ et Ubuntu 22.04+ sont supportés avec adaptations mineures.

**Q: Comment changer le port web par défaut ?**
R: Modifiez `/etc/nginx/sites-available/pisignage` et redémarrez nginx.

### Utilisation

**Q: Comment ajouter des vidéos en lots ?**
R: Utilisez `sudo cp /chemin/vers/videos/*.mp4 /opt/pisignage/videos/` puis `sudo chown -R pisignage:pisignage /opt/pisignage/videos/`.

**Q: Comment créer des playlists ?**
R: Via l'interface web `/admin.html` ou en créant des fichiers JSON dans `/opt/pisignage/playlists/`.

**Q: Comment contrôler à distance ?**
R: Via l'API REST, SSH, ou l'interface web mobile.

### Dépannage

**Q: Le player ne démarre pas après reboot ?**
R: Vérifiez que les services sont activés : `sudo systemctl enable pisignage.service`.

**Q: Vidéo saccadée ou lag ?**
R: Augmentez gpu_mem à 256, vérifiez le débit SD card, utilisez H.264 hardware decoding.

**Q: Comment faire un rollback ?**
R: Utilisez le script de désinstallation : `sudo ./uninstall.sh` puis restaurez une sauvegarde.

### Avancé

**Q: Comment personnaliser l'interface web ?**
R: Modifiez les fichiers dans `/opt/pisignage/web/assets/` et redémarrez nginx.

**Q: Comment ajouter des formats vidéo ?**
R: Installez des codecs supplémentaires et modifiez la configuration player.

**Q: Comment utiliser plusieurs écrans ?**
R: Chaque écran nécessite une instance séparée avec des ports différents.

## 🤝 Contribution

### Développement local

```bash
# Cloner le repository
git clone https://github.com/yourusername/pisignage-desktop.git
cd pisignage-desktop

# Branches de développement
git checkout develop

# Tests locaux
./scripts/test-modules.sh
./scripts/test-api.sh
```

### Guidelines de contribution

1. **Fork** le repository
2. **Créer** une branche feature (`git checkout -b feature/ma-feature`)
3. **Commiter** les changements (`git commit -m 'Ajout ma feature'`)
4. **Pousser** vers la branche (`git push origin feature/ma-feature`)
5. **Créer** une Pull Request

### Standards de code

- **Shell scripts** : Suivre les standards POSIX
- **PHP** : PSR-12 coding standards
- **JavaScript** : ES6+ avec JSLint
- **CSS** : BEM methodology
- **Documentation** : Markdown avec liens internes

### Tests

```bash
# Tests automatisés
./scripts/run-tests.sh

# Tests unitaires modules
./tests/test-base-config.sh
./tests/test-web-interface.sh
./tests/test-media-player.sh

# Tests API
curl -X GET http://localhost/api/health.php | jq
curl -X POST http://localhost/api/control.php -d '{"action":"status"}'
```

## 📄 Licence

Ce projet est distribué sous la licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

```
MIT License

Copyright (c) 2024 PiSignage Desktop Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📞 Support et communauté

- **Documentation** : [docs/](docs/)
- **Issues** : [GitHub Issues](https://github.com/yourusername/pisignage-desktop/issues)
- **Discussions** : [GitHub Discussions](https://github.com/yourusername/pisignage-desktop/discussions)
- **Wiki** : [GitHub Wiki](https://github.com/yourusername/pisignage-desktop/wiki)

---

*Fait avec ❤️ pour la communauté Raspberry Pi*
>>>>>>> e3d23eed5cb67ecaebb350b4b797596c74b65e7a
