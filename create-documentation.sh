#!/bin/bash

cd /opt/pisignage/github-v0.9.0

# ═══════════════════════════════════════════════════════════════
# Documentation complète dans docs/
# ═══════════════════════════════════════════════════════════════

# 1. Guide d'installation détaillé
cat > docs/INSTALLATION.md << 'EOF'
# 📦 Guide d'Installation Détaillé - Pi-Signage v0.9.0

## Prérequis Matériels

- **Raspberry Pi 4 Model B** (2GB RAM minimum, 4GB recommandé)
- Carte SD 16GB minimum (32GB recommandé) Class 10 ou supérieure
- Alimentation officielle 5V/3A
- Câble HDMI
- Écran compatible HDMI
- Connexion internet (Ethernet ou WiFi)

## Prérequis Logiciels

- **Raspberry Pi OS Bookworm Lite 64-bit** (OBLIGATOIRE)
  - Télécharger : https://www.raspberrypi.com/software/operating-systems/
  - Version testée : 2025-09-20

## Installation Étape par Étape

### 1. Préparation de la carte SD

```bash
# Sur votre ordinateur, flasher l'image avec Raspberry Pi Imager
# Configurer SSH et WiFi si nécessaire
```

### 2. Premier démarrage

```bash
# Connexion SSH (mot de passe par défaut: raspberry)
ssh pi@IP_RASPBERRY

# Changer le mot de passe
passwd

# Mise à jour système
sudo apt update && sudo apt upgrade -y
```

### 3. Installation Pi-Signage

#### Méthode 1 : Installation automatique (recommandée)
```bash
wget -O - https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install.sh | sudo bash
```

#### Méthode 2 : Installation manuelle
```bash
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage
chmod +x install.sh
sudo ./install.sh
```

### 4. Configuration post-installation

Le système est configuré automatiquement. Après redémarrage :
- La vidéo démarre automatiquement en plein écran
- L'interface web est accessible sur http://IP_RASPBERRY/

### 5. Vérification

```bash
# Vérifier le statut
/opt/pisignage/scripts/vlc-control.sh status

# Vérifier l'interface web
curl http://localhost/api/system.php
```

## Configuration Avancée

### Modification de la résolution

```bash
# Éditer /boot/firmware/config.txt
sudo nano /boot/firmware/config.txt

# Ajouter (exemple pour 1920x1080)
hdmi_group=2
hdmi_mode=82
```

### Ajout de vidéos

1. Via l'interface web : Upload dans l'onglet Médias
2. Via SSH : Copier dans /opt/pisignage/media/
3. Via USB : Script de synchronisation disponible

## Dépannage

Voir [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
EOF

# 2. Architecture technique
cat > docs/ARCHITECTURE.md << 'EOF'
# 🏗️ Architecture Technique - Pi-Signage v0.9.0

## Vue d'ensemble

Pi-Signage utilise une architecture modulaire optimisée pour les performances sur Raspberry Pi.

## Stack Technologique

### Système
- **OS** : Raspberry Pi OS Bookworm Lite 64-bit
- **Kernel** : 6.12+ avec support V4L2/DRM
- **GPU** : Configuration par défaut (76MB) SUFFISANTE

### Lecture Vidéo
- **VLC 3.0.21** : Mode dummy, sans interface
- **Décodage** : Software optimisé (7% CPU pour 30 FPS)
- **Sortie** : X11 minimal avec xserver-xorg-core
- **Auto-start** : systemd + xinit

### Interface Web
- **Serveur** : Nginx 1.22
- **Backend** : PHP 8.2-FPM
- **API** : REST JSON
- **Frontend** : Vanilla JS (pas de framework)

## Architecture des Composants

```
┌─────────────────────────────────────────────┐
│                 RASPBERRY PI 4               │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────┐    ┌────────────┐           │
│  │   Boot   │───▶│  Auto-login │           │
│  └──────────┘    └────────────┘           │
│        │               │                    │
│        ▼               ▼                    │
│  ┌──────────┐    ┌────────────┐           │
│  │  systemd │───▶│   startx    │           │
│  └──────────┘    └────────────┘           │
│                        │                    │
│                        ▼                    │
│              ┌──────────────────┐          │
│              │  VLC Fullscreen  │          │
│              │   30+ FPS @ 7%   │          │
│              └──────────────────┘          │
│                                             │
│  ┌────────────────────────────────┐        │
│  │        Interface Web           │        │
│  │  ┌──────────┐  ┌────────────┐ │        │
│  │  │  Nginx   │──│  PHP-FPM    │ │        │
│  │  └──────────┘  └────────────┘ │        │
│  │         │            │         │        │
│  │         ▼            ▼         │        │
│  │  ┌──────────────────────────┐ │        │
│  │  │      API REST JSON       │ │        │
│  │  └──────────────────────────┘ │        │
│  └────────────────────────────────┘        │
└─────────────────────────────────────────────┘
```

## Flux de Données

1. **Boot** : 30 secondes jusqu'à la vidéo
2. **Auto-login** : getty@tty1 avec systemd
3. **X démarrage** : .bash_profile → startx
4. **VLC** : .xinitrc → start-video.sh
5. **Web** : Port 80 → Nginx → PHP → API

## Performance

### Métriques Clés
- Boot to video : 30 secondes
- CPU usage : 7% (VLC) + 3% (X.org)
- RAM : ~300MB total
- FPS : 30+ confirmé visuellement

### Optimisations Appliquées
- Pas de window manager (économie 100MB RAM)
- VLC en mode dummy (pas d'UI)
- Configuration GPU par défaut (pas d'overclocking)
- Services inutiles désactivés

## Sécurité

- Interface web en local seulement (pas d'exposition internet)
- Permissions minimales (www-data pour web)
- Pas de services SSH exposés par défaut
- Mises à jour automatiques désactivées

## Fichiers de Configuration

```
/opt/pisignage/
├── scripts/vlc-control.sh     # Contrôle VLC
├── web/index.php              # Interface principale
├── web/api/*.php              # Endpoints API
├── config/playlists.json      # Stockage playlists
├── media/                     # Vidéos
└── logs/                      # Logs système
```
EOF

# 3. Guide de dépannage
cat > docs/TROUBLESHOOTING.md << 'EOF'
# 🛠️ Guide de Dépannage - Pi-Signage v0.9.0

## Problèmes Fréquents et Solutions

### 1. Écran noir au démarrage

**Symptôme** : L'écran reste noir après le boot

**Solutions** :
```bash
# Vérifier si X est démarré
ps aux | grep Xorg

# Si non, démarrer manuellement
startx

# Vérifier les logs
cat /var/log/Xorg.0.log | grep EE
```

### 2. Vidéo ne démarre pas

**Symptôme** : X démarre mais pas de vidéo

**Solutions** :
```bash
# Vérifier VLC
/opt/pisignage/scripts/vlc-control.sh status

# Relancer VLC
/opt/pisignage/scripts/vlc-control.sh restart

# Vérifier les vidéos
ls -la /opt/pisignage/media/
```

### 3. Performance dégradée (<30 FPS)

**Symptôme** : Vidéo saccadée

**Solutions** :
```bash
# Vérifier throttling thermique
vcgencmd get_throttled
# Si != 0x0, problème de température ou alimentation

# Vérifier température
vcgencmd measure_temp
# Si > 70°C, ajouter ventilation

# Vérifier alimentation
dmesg | grep voltage
# Chercher "Under-voltage"
```

### 4. Interface web inaccessible

**Symptôme** : Erreur 404 ou connexion refusée

**Solutions** :
```bash
# Vérifier nginx
sudo systemctl status nginx
sudo systemctl restart nginx

# Vérifier PHP
sudo systemctl status php8.2-fpm
sudo systemctl restart php8.2-fpm

# Vérifier permissions
sudo chown -R www-data:www-data /opt/pisignage/web
```

### 5. Upload de vidéos échoue

**Symptôme** : Erreur lors de l'upload via l'interface

**Solutions** :
```bash
# Vérifier l'espace disque
df -h

# Vérifier permissions
sudo chmod 775 /opt/pisignage/media
sudo chown www-data:www-data /opt/pisignage/media

# Augmenter limite PHP
sudo nano /etc/php/8.2/fpm/php.ini
# upload_max_filesize = 500M
# post_max_size = 500M
sudo systemctl restart php8.2-fpm
```

### 6. VLC crash régulièrement

**Symptôme** : VLC se ferme inopinément

**Solutions** :
```bash
# Vérifier les logs
tail -f /opt/pisignage/logs/vlc.log

# Tester avec une vidéo simple
ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30:duration=10 \
       -c:v h264 /tmp/test.mp4
/opt/pisignage/scripts/vlc-control.sh start /tmp/test.mp4

# Réinstaller VLC
sudo apt-get install --reinstall vlc vlc-plugin-base
```

### 7. Boot automatique ne fonctionne pas

**Symptôme** : Doit se connecter manuellement

**Solutions** :
```bash
# Vérifier auto-login
cat /etc/systemd/system/getty@tty1.service.d/autologin.conf

# Reconfigurer
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf << AUTO
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
AUTO

# Vérifier .bash_profile
cat /home/pi/.bash_profile
```

## Commandes Utiles

### Monitoring
```bash
# CPU et mémoire
htop

# Température
watch vcgencmd measure_temp

# Utilisation disque
df -h

# Logs système
journalctl -xe
```

### Reset Complet
```bash
# Arrêter tous les services
sudo systemctl stop nginx php8.2-fpm
pkill vlc

# Nettoyer
rm -rf /opt/pisignage/logs/*
rm /tmp/vlc.pid

# Redémarrer
sudo reboot
```

## Support

Si le problème persiste :
1. Collecter les logs : `sudo journalctl -b > debug.log`
2. Créer une issue : https://github.com/elkir0/Pi-Signage/issues
3. Inclure : Version Pi, OS, logs, étapes reproduire
EOF

# 4. API Reference
cat > docs/API.md << 'EOF'
# 📡 API Reference - Pi-Signage v0.9.0

## Base URL

```
http://IP_RASPBERRY/api/
```

## Endpoints

### 1. System Information

**GET** `/api/system.php`

Retourne les informations système en temps réel.

**Response:**
```json
{
    "cpu": 7.5,
    "memory": 13.2,
    "temperature": 52.3,
    "disk": 8.1,
    "vlc_status": "En lecture (PID: 1234, CPU: 7%, MEM: 3%)",
    "uptime": "1234.56"
}
```

### 2. VLC Control

**GET** `/api/control.php?action={action}`

Contrôle le lecteur VLC.

**Actions:**
- `status` : État actuel
- `start` : Démarrer la lecture
- `stop` : Arrêter la lecture
- `restart` : Redémarrer

**Response:**
```json
{
    "status": "En lecture"
}
```

### 3. Playlist Management

**GET** `/api/playlist.php?action={action}`

Gestion des playlists.

**Actions:**
- `list` : Liste toutes les playlists
- `videos` : Liste les vidéos disponibles
- `play&id={id}` : Jouer une playlist

**POST** `/api/playlist.php`
- `action=create` : Créer une playlist
- `action=delete&id={id}` : Supprimer

**Response (videos):**
```json
{
    "videos": [
        {
            "name": "video.mp4",
            "size": 12345678,
            "duration": "120.5"
        }
    ]
}
```

### 4. Upload

**POST** `/api/upload.php`

Upload de vidéos.

**Body:** multipart/form-data
- `video` : Fichier vidéo (max 500MB)

**Response:**
```json
{
    "success": true,
    "file": "video.mp4",
    "size": 12345678,
    "message": "Upload réussi!"
}
```

### 5. YouTube Download

**POST** `/api/youtube.php`

Télécharge une vidéo YouTube.

**Body:**
- `url` : URL YouTube
- `quality` : 720p (optionnel)

**Response:**
```json
{
    "success": true,
    "file": "youtube_abc123.mp4",
    "message": "Téléchargement réussi!"
}
```

## Exemples d'utilisation

### Bash/cURL
```bash
# Status système
curl http://192.168.1.103/api/system.php

# Contrôle VLC
curl "http://192.168.1.103/api/control.php?action=restart"

# Liste vidéos
curl "http://192.168.1.103/api/playlist.php?action=videos"
```

### JavaScript
```javascript
// Status système
fetch('http://192.168.1.103/api/system.php')
    .then(res => res.json())
    .then(data => console.log(data));

// Upload vidéo
const formData = new FormData();
formData.append('video', fileInput.files[0]);
fetch('/api/upload.php', {
    method: 'POST',
    body: formData
});
```

### Python
```python
import requests

# Status système
r = requests.get('http://192.168.1.103/api/system.php')
print(r.json())

# YouTube download
r = requests.post('http://192.168.1.103/api/youtube.php', 
                  data={'url': 'https://youtube.com/watch?v=...'})
print(r.json())
```
EOF

# 5. CONTRIBUTING.md
cat > CONTRIBUTING.md << 'EOF'
# 🤝 Contribution à Pi-Signage

Merci de votre intérêt pour contribuer à Pi-Signage !

## Comment Contribuer

1. Fork le projet
2. Créez votre branche (`git checkout -b feature/AmazingFeature`)
3. Committez vos changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## Guidelines

- Testez sur un vrai Raspberry Pi 4
- Documentez vos changements
- Suivez le style de code existant
- Mettez à jour la documentation si nécessaire

## Tests

Avant de soumettre :
```bash
# Tester l'installation
sudo ./install.sh

# Vérifier les performances
/opt/pisignage/scripts/vlc-control.sh benchmark

# Tester l'interface web
curl http://localhost/api/system.php
```

## Rapport de Bugs

Utilisez les issues GitHub avec :
- Description claire du problème
- Étapes pour reproduire
- Version de Pi-Signage
- Modèle de Raspberry Pi
- Logs pertinents
EOF

# 6. LICENSE
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2025 Pi-Signage Contributors

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
EOF

echo "✅ Documentation complète créée dans docs/"
ls -la /opt/pisignage/github-v0.9.0/docs/
