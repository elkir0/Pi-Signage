# 🚀 Guide d'Installation PiSignage v0.8.0

## 📋 Vue d'ensemble

Scripts d'installation complets pour déploiement production sur Raspberry Pi.
Système d'affichage digital optimisé avec interface web PHP et lecteur VLC.

## 🎯 Installation Rapide (Recommandée)

```bash
# 1. Validation des scripts
./validate-installation.sh

# 2. Installation complète (tout-en-un)
./deploy-complete.sh

# 3. Redémarrage obligatoire
sudo reboot
```

## 📦 Scripts Disponibles

### 🔧 Scripts Principaux

| Script | Description | Usage |
|--------|-------------|-------|
| `install.sh` | Installation principale | `./install.sh` |
| `setup-vlc.sh` | Configuration VLC + GPU | `./setup-vlc.sh` |
| `setup-web.sh` | Configuration Nginx + PHP | `./setup-web.sh` |
| `optimize-pi.sh` | Optimisations système | `./optimize-pi.sh` |

### ⚙️ Scripts de Service

| Script | Description | Usage |
|--------|-------------|-------|
| `pisignage-start.sh` | Démarrage du service | Automatique |
| `pisignage-stop.sh` | Arrêt du service | Automatique |
| `pisignage-reload.sh` | Rechargement à chaud | `systemctl reload pisignage` |

### 🧪 Scripts Utilitaires

| Script | Description | Usage |
|--------|-------------|-------|
| `validate-installation.sh` | Validation complète | `./validate-installation.sh` |
| `deploy-complete.sh` | Déploiement tout-en-un | `./deploy-complete.sh` |

## 📖 Installation Manuelle Détaillée

### Étape 1 : Validation
```bash
# Vérifier que tous les scripts sont présents et valides
./validate-installation.sh
```

### Étape 2 : Installation Système
```bash
# Installation des packages et services
./install.sh
```

### Étape 3 : Configuration Services
```bash
# Configuration web (nginx + PHP)
./setup-web.sh

# Configuration VLC et GPU
./setup-vlc.sh

# Optimisations système
./optimize-pi.sh
```

### Étape 4 : Service Systemd
```bash
# Installation du service
sudo cp pisignage.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pisignage
```

### Étape 5 : Redémarrage
```bash
# OBLIGATOIRE pour GPU et overclocking
sudo reboot
```

## 🔍 Vérification Post-Installation

### Services Actifs
```bash
sudo systemctl status nginx
sudo systemctl status php8.2-fpm
sudo systemctl status pisignage
```

### Interface Web
```bash
# Test de l'interface
curl http://localhost/health

# Devrait retourner: "PiSignage v0.8.0 OK"
```

### Lecteur VLC
```bash
# Contrôle VLC
/opt/pisignage/scripts/vlc-control.sh status
/opt/pisignage/scripts/vlc-control.sh start /path/to/video.mp4
```

## 📂 Structure des Fichiers

```
/opt/pisignage/
├── install.sh                 # Installation principale
├── setup-vlc.sh              # Configuration VLC
├── setup-web.sh              # Configuration web
├── optimize-pi.sh            # Optimisations Pi
├── pisignage.service         # Service systemd
├── deploy-complete.sh        # Déploiement complet
├── validate-installation.sh  # Validation
├── scripts/
│   ├── pisignage-start.sh    # Démarrage service
│   ├── pisignage-stop.sh     # Arrêt service
│   ├── pisignage-reload.sh   # Rechargement
│   ├── vlc-control.sh        # Contrôle VLC
│   ├── vlc-playlist.sh       # Playlists VLC
│   ├── restart-web.sh        # Redémarrage web
│   ├── test-upload.sh        # Test upload
│   └── system-monitor.sh     # Monitoring
├── web/                      # Interface web PHP
├── media/                    # Stockage médias
├── logs/                     # Logs système
└── config/                   # Configurations
```

## ⚙️ Configuration Système

### GPU et Mémoire
- **GPU Memory**: 128MB (256MB si Pi 4+ avec 4GB+ RAM)
- **Accélération**: VC4 FKMS V3D activée
- **HDMI**: Force hotplug et audio activés

### Overclocking Sécurisé
- **Pi 4**: ARM 1.75GHz, GPU 600MHz
- **Pi 3**: ARM 1.3GHz, GPU 400MHz
- **Limite température**: 80°C

### Services Optimisés
- **Bluetooth**: Désactivé
- **Services inutiles**: Supprimés
- **Boot rapide**: Activé
- **Tmpfs**: /tmp et /var/log

## 🌐 Interface Web

### URLs Disponibles
- **Principal**: `http://[IP_PI]/`
- **Health check**: `http://[IP_PI]/health`
- **Status nginx**: `http://[IP_PI]/nginx_status`
- **API système**: `http://[IP_PI]/api/system.php`

### Upload Configuration
- **Taille max**: 2GB
- **Timeout**: 300 secondes
- **Formats**: MP4, AVI, MKV, JPG, PNG, GIF

## 🎬 Contrôle VLC

### Commandes de Base
```bash
# Démarrer une vidéo
/opt/pisignage/scripts/vlc-control.sh start /path/to/video.mp4

# Arrêter VLC
/opt/pisignage/scripts/vlc-control.sh stop

# Status VLC
/opt/pisignage/scripts/vlc-control.sh status

# Redémarrer avec nouveau média
/opt/pisignage/scripts/vlc-control.sh restart /path/to/new-video.mp4
```

### Playlist
```bash
# Démarrer playlist
/opt/pisignage/scripts/vlc-playlist.sh start

# Arrêter playlist
/opt/pisignage/scripts/vlc-playlist.sh stop
```

## 📊 Monitoring

### Logs Système
```bash
# Logs principal
tail -f /opt/pisignage/logs/pisignage.log

# Logs VLC
tail -f /opt/pisignage/logs/vlc.log

# Logs monitoring
tail -f /opt/pisignage/logs/system-monitor.log
```

### Informations Système
```bash
# Température CPU
vcgencmd measure_temp

# Mémoire GPU
vcgencmd get_mem gpu

# Fréquences
vcgencmd measure_clock arm
vcgencmd measure_clock core
```

## 🔧 Maintenance

### Redémarrage Services Web
```bash
/opt/pisignage/scripts/restart-web.sh
```

### Test Upload
```bash
/opt/pisignage/scripts/test-upload.sh
```

### Monitoring Automatique
```bash
# Exécuté automatiquement toutes les 5 minutes
/opt/pisignage/scripts/system-monitor.sh
```

## ❗ Dépannage

### VLC ne démarre pas
```bash
# Vérifier X11
echo $DISPLAY
xset q

# Redémarrer service
sudo systemctl restart pisignage
```

### Interface web inaccessible
```bash
# Redémarrer services web
sudo systemctl restart nginx php8.2-fpm

# Vérifier configuration
sudo nginx -t
```

### Performance dégradée
```bash
# Vérifier température
vcgencmd measure_temp

# Vérifier mémoire
free -h

# Logs système
journalctl -u pisignage -f
```

## 📋 Prérequis Système

### Raspberry Pi Supportés
- Raspberry Pi 3B/3B+
- Raspberry Pi 4B (Recommandé)
- Raspberry Pi 400

### OS Requis
- Raspberry Pi OS (Bullseye/Bookworm)
- Debian 11/12 compatible

### Matériel Recommandé
- **RAM**: 2GB minimum, 4GB recommandé
- **Stockage**: Classe 10 micro-SD, 32GB minimum
- **Affichage**: HDMI 1080p minimum
- **Réseau**: Ethernet recommandé

## 🚀 Déploiement Production

### Checklist Finale
- [ ] Scripts validés avec `validate-installation.sh`
- [ ] Installation réussie avec `deploy-complete.sh`
- [ ] Redémarrage effectué
- [ ] Interface web accessible
- [ ] VLC fonctionnel
- [ ] Services systemd actifs
- [ ] Monitoring opérationnel

### Première Utilisation
1. Accéder à l'interface web
2. Uploader des médias via l'API
3. Créer des playlists
4. Configurer l'affichage automatique
5. Surveiller les logs

---

**PiSignage v0.8.0** - Système d'affichage digital pour Raspberry Pi
Développé avec Claude Code - 22/09/2025