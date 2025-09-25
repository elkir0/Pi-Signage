# PiSignage v0.8.0 - Guide Dual-Player (VLC/MPV)

## 📋 Vue d'ensemble

PiSignage v0.8.0 propose un système **dual-player** révolutionnaire permettant de choisir entre **VLC** et **MPV** selon vos besoins spécifiques, avec des optimisations dédiées Raspberry Pi 3/4/5.

### 🎯 Avantages du système dual-player

| Player | Avantages | Inconvénients | Usage recommandé |
|--------|-----------|---------------|-------------------|
| **MPV** | Performance optimale, GPU acceleration, faible latence | Interface limitée | **Par défaut** - Affichage continu |
| **VLC** | HTTP API riche, fonctionnalités avancées, streaming | Plus de ressources CPU | Contrôle avancé, streaming |

## 🔧 Architecture technique

```
/opt/pisignage/
├── config/
│   └── player-config.json          # Configuration centralisée
├── scripts/
│   ├── player-manager.sh           # Gestionnaire unifié VLC/MPV
│   └── unified-player-control.sh   # API de contrôle unifié
├── web/
│   ├── index.php                   # Interface avec sélecteur player
│   ├── functions.js                # Fonctions JavaScript dual-player
│   └── api/
│       ├── player.php              # API unifiée player
│       └── system.php              # API système avec support dual
└── install.sh                      # Installation dual-player
```

## 🚀 Installation

### Installation complète (recommandée)

```bash
# Téléchargement et installation
curl -O https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install.sh
chmod +x install.sh
./install.sh

# Le script installe automatiquement :
# - MPV + VLC
# - Configuration optimisée Pi3/Pi4/Pi5
# - Service systemd unifié
# - Interface web avec sélecteur
```

### Mise à jour depuis version précédente

```bash
# Sauvegarder configuration actuelle
cp /opt/pisignage/config/* /tmp/backup/

# Déployer dual-player
./deploy-dual-player-complete.sh

# Restaurer médias si nécessaire
```

## ⚙️ Configuration

### Fichier de configuration principal

**`/opt/pisignage/config/player-config.json`**

```json
{
  "player": {
    "default": "mpv",           // Player par défaut
    "current": "mpv",           // Player actuellement actif
    "available": ["mpv", "vlc"] // Players disponibles
  },
  "mpv": {
    "enabled": true,
    "optimizations": {
      "pi3": {
        "hwdec": "mmal-copy",          // Accélération Pi3
        "vo": "gpu",
        "demuxer-max-bytes": "50MiB"
      },
      "pi4": {
        "hwdec": "drm-copy",           // Accélération Pi4/5
        "scale": "ewa_lanczossharp",   // Upscaling qualité
        "demuxer-max-bytes": "100MiB"
      }
    }
  },
  "vlc": {
    "enabled": true,
    "http_port": 8080,
    "http_password": "signage123",
    "optimizations": {
      "pi3": {
        "vout": "mmal_xsplitter",      // Sortie vidéo Pi3
        "codec": "mmal"
      },
      "pi4": {
        "vout": "drm",                 // Sortie vidéo Pi4/5
        "avcodec-hw": "v4l2m2m"
      }
    }
  }
}
```

## 🎮 Utilisation

### Interface Web

1. **Accéder à l'interface** : `http://[IP_PI]/`
2. **Section Lecteur** : Sélectionner MPV/VLC avec les boutons radio
3. **Basculer** : Cliquer sur "Basculer Lecteur"
4. **Contrôles** : Play/Stop/Pause/Volume identiques pour les deux players

### Ligne de commande

```bash
# Gestionnaire principal
/opt/pisignage/scripts/player-manager.sh [action] [player]

# Actions disponibles :
sudo /opt/pisignage/scripts/player-manager.sh start mpv    # Démarrer MPV
sudo /opt/pisignage/scripts/player-manager.sh start vlc    # Démarrer VLC
sudo /opt/pisignage/scripts/player-manager.sh switch       # Basculer VLC↔MPV
sudo /opt/pisignage/scripts/player-manager.sh info         # Informations détaillées
sudo /opt/pisignage/scripts/player-manager.sh setup        # Configuration initiale

# Contrôle unifié
/opt/pisignage/scripts/unified-player-control.sh [action]

# Actions unifiées :
sudo /opt/pisignage/scripts/unified-player-control.sh play     # Lancer
sudo /opt/pisignage/scripts/unified-player-control.sh stop     # Arrêter
sudo /opt/pisignage/scripts/unified-player-control.sh next     # Suivant
sudo /opt/pisignage/scripts/unified-player-control.sh pause    # Pause
sudo /opt/pisignage/scripts/unified-player-control.sh current  # Player actuel
```

### Service systemd

```bash
# Contrôle du service unifié
sudo systemctl start pisignage-player     # Démarrer
sudo systemctl stop pisignage-player      # Arrêter
sudo systemctl restart pisignage-player   # Redémarrer
sudo systemctl status pisignage-player    # Statut

# Logs en temps réel
sudo journalctl -u pisignage-player -f
```

## 🔄 API REST

### Endpoints principaux

**GET `/api/player.php`** - Statut du player actuel
```json
{
  "success": true,
  "status": "MPV is running",
  "running": true
}
```

**GET `/api/player.php?action=current`** - Player actuel
```json
{
  "success": true,
  "current_player": "mpv"
}
```

**POST `/api/player.php`** - Contrôle du player
```json
{
  "action": "switch"          // switch, play, stop, pause, next, prev, volume
}
```

**POST `/api/system.php`** - Contrôle système
```json
{
  "action": "switch-player"   // switch-player, restart-player
}
```

### Exemples JavaScript

```javascript
// Récupérer le player actuel
fetch('/api/player.php?action=current')
  .then(response => response.json())
  .then(data => console.log('Player actuel:', data.current_player));

// Basculer entre VLC et MPV
fetch('/api/player.php', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ action: 'switch' })
});

// Contrôler la lecture
playerControl('play');   // Démarrer
playerControl('stop');   // Arrêter
playerControl('pause');  // Pause
```

## 📊 Optimisations par modèle

### Raspberry Pi 3
- **MPV** : `hwdec=mmal-copy`, `vo=gpu`, cache 50MB
- **VLC** : `vout=mmal_xsplitter`, `codec=mmal`, H264@30fps

### Raspberry Pi 4/5
- **MPV** : `hwdec=drm-copy`, upscaling `ewa_lanczossharp`, cache 100MB
- **VLC** : `vout=drm`, `avcodec-hw=v4l2m2m`, caching optimisé

### Auto-détection
Le système détecte automatiquement le modèle de Pi via `/proc/cpuinfo` et applique les optimisations appropriées.

## 🔧 Dépannage

### Player ne démarre pas

```bash
# Vérifier les logs
sudo journalctl -u pisignage-player -n 50

# Tester manuellement
sudo -u pi /opt/pisignage/scripts/player-manager.sh start mpv
sudo -u pi /opt/pisignage/scripts/player-manager.sh start vlc

# Reconfigurer
sudo -u pi /opt/pisignage/scripts/player-manager.sh setup
```

### Problèmes d'affichage HDMI

```bash
# MPV - Test direct
mpv --vo=drm --hwdec=drm-copy /opt/pisignage/media/*.mp4

# VLC - Test direct
cvlc --vout drm --fullscreen /opt/pisignage/media/*.mp4

# Vérifier configuration
cat /home/pi/.config/mpv/mpv.conf
cat /home/pi/.config/vlc/vlcrc
```

### Interface web ne répond pas

```bash
# Vérifier services web
sudo systemctl status nginx php8.2-fpm

# Tester API
curl http://localhost/api/player.php?action=current

# Permissions
sudo chown -R www-data:www-data /opt/pisignage
```

## 📈 Surveillance et logs

### Fichiers de logs

```bash
# Logs du service
sudo journalctl -u pisignage-player -f

# Logs MPV
tail -f /opt/pisignage/logs/mpv.log

# Logs VLC
tail -f /opt/pisignage/logs/vlc.log

# Logs système PiSignage
tail -f /opt/pisignage/logs/pisignage.log
```

### Monitoring des performances

```bash
# CPU usage temps réel
htop

# GPU usage (Pi4/5)
sudo vcgencmd measure_temp
sudo vcgencmd measure_clock arm
sudo vcgencmd get_mem gpu

# Processus actifs
ps aux | grep -E "(mpv|vlc)"
```

## 🎛️ Configuration avancée

### Personnaliser les optimisations

Éditer `/opt/pisignage/config/player-config.json` :

```json
{
  "mpv": {
    "optimizations": {
      "pi4": {
        "hwdec": "drm-copy",
        "vo": "gpu",
        "scale": "ewa_lanczossharp",      // Qualité upscaling
        "video-sync": "display-resample", // Sync display
        "interpolation": "yes"            // Interpolation temporelle
      }
    }
  }
}
```

### Ajouter formats audio/vidéo

Modifier les scripts pour supporter nouveaux formats :

```bash
# Dans player-manager.sh, ligne 175
ls "$MEDIA_DIR"/*.{mp4,avi,mkv,mov,jpg,png,webm,flv} 2>/dev/null > /tmp/mpv-playlist.txt
```

## 🔗 Intégration

### Avec Home Assistant

```yaml
# configuration.yaml
media_player:
  - platform: vlc
    host: 192.168.1.103
    port: 8080
    password: signage123
```

### Avec APIs externes

```python
import requests

# Basculer vers VLC pour streaming
requests.post('http://192.168.1.103/api/player.php',
              json={'action': 'switch'})

# Lancer contenu spécifique
requests.post('http://192.168.1.103/api/player.php',
              json={'action': 'play-file', 'file': 'video.mp4'})
```

## 📋 Checklist de validation

### ✅ Installation réussie
- [ ] Les deux players (MPV + VLC) sont installés
- [ ] Service `pisignage-player` actif
- [ ] Interface web accessible
- [ ] Sélecteur VLC/MPV fonctionnel

### ✅ Fonctionnement MPV
- [ ] Affichage vidéo HDMI
- [ ] Contrôles Play/Stop/Pause
- [ ] Socket IPC `/tmp/mpv-socket` créé
- [ ] Configuration `/home/pi/.config/mpv/mpv.conf`

### ✅ Fonctionnement VLC
- [ ] Affichage vidéo HDMI
- [ ] API HTTP accessible port 8080
- [ ] Configuration `/home/pi/.config/vlc/vlcrc`
- [ ] Password `signage123` configuré

### ✅ Basculement fonctionnel
- [ ] Interface web met à jour le sélecteur
- [ ] Commande CLI switch fonctionne
- [ ] Service redémarre correctement
- [ ] Configuration sauvegardée

---

## 🆘 Support

### Issues GitHub
https://github.com/elkir0/Pi-Signage/issues

### Documentation technique complète
- [Architecture système](./ARCHITECTURE.md)
- [Guide API](./API-REFERENCE.md)
- [Optimisations Pi](./PI-OPTIMIZATIONS.md)

### Communauté
- Discord : https://discord.gg/pisignage
- Forum : https://community.pisignage.org

---

**PiSignage v0.8.0** - Système d'affichage digital dual-player
*MPV par défaut, VLC en option, optimisé Raspberry Pi 3/4/5*