# 🌐 Guide du Mode Chromium Kiosk

## Vue d'ensemble

Le mode Chromium Kiosk est une alternative moderne et légère au mode VLC Classic traditionnel. Il utilise un navigateur Chromium en mode kiosk avec un player HTML5 local pour la lecture des vidéos.

## 🎯 Avantages du Mode Chromium

### Performance
- **Démarrage rapide** : ~25 secondes (vs ~45s pour VLC)
- **Consommation mémoire réduite** : ~250MB (vs ~350MB)
- **CPU optimisé** : 10-20% en lecture 1080p

### Fonctionnalités
- **Support HTML5 natif** : Animations CSS, transitions fluides
- **Overlays dynamiques** : Affichage d'informations sur les vidéos
- **Contrôle WebSocket** : Commandes en temps réel
- **Interface moderne** : Player HTML5 responsive

### Maintenance
- **Une seule application** : Plus simple à gérer
- **Logs centralisés** : Debug facilité
- **Mise à jour facile** : Via interface web

## 📋 Prérequis

### Matériel
- Raspberry Pi 3B+, 4B ou 5
- 1GB RAM minimum (2GB+ recommandé)
- Carte SD 16GB minimum

### Formats vidéo supportés
- **H.264 (MP4)** : Recommandé
- **WebM** : Support natif
- **MOV** : Si codec H.264
- ⚠️ Pas de support : AVI, MKV, WMV, HEVC

## 🚀 Installation

### Installation automatique (recommandée)

```bash
# Cloner le projet
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/raspberry-pi-installer/scripts

# Lancer l'installation v2.3
sudo ./main_orchestrator_v2.sh

# Choisir "2) Chromium Kiosk" quand demandé
```

### Installation manuelle du module

```bash
# Installer uniquement le module Chromium
sudo ./03-chromium-kiosk.sh
```

## 🎮 Utilisation

### Contrôle du Player

```bash
# Commandes de base
sudo /opt/scripts/player-control.sh play     # Démarrer la lecture
sudo /opt/scripts/player-control.sh pause    # Mettre en pause
sudo /opt/scripts/player-control.sh next     # Vidéo suivante
sudo /opt/scripts/player-control.sh previous # Vidéo précédente
sudo /opt/scripts/player-control.sh reload   # Recharger le player

# État du service
sudo /opt/scripts/player-control.sh status

# Voir les logs
sudo /opt/scripts/player-control.sh logs
```

### Gestion de la Playlist

```bash
# Mettre à jour la playlist depuis /opt/videos
sudo /opt/scripts/update-playlist.sh

# La playlist est générée automatiquement toutes les 5 minutes
```

### Service Systemd

```bash
# Contrôle du service
sudo systemctl status chromium-kiosk
sudo systemctl restart chromium-kiosk
sudo systemctl stop chromium-kiosk
sudo systemctl start chromium-kiosk

# Logs du service
sudo journalctl -u chromium-kiosk -f
```

## 📁 Structure des Fichiers

```
/opt/
├── videos/                          # Dossier des vidéos
├── scripts/
│   ├── chromium-kiosk.sh           # Script principal de démarrage
│   ├── player-control.sh           # Script de contrôle
│   └── update-playlist.sh          # Mise à jour playlist
│
/var/www/pi-signage-player/
├── player.html                     # Page principale du player
├── css/player.css                  # Styles
├── js/player.js                    # Logique JavaScript
└── api/playlist.json               # Playlist JSON

/var/log/pi-signage/
└── chromium.log                    # Logs Chromium
```

## 🎨 Personnalisation

### Modifier l'apparence du player

1. **Éditer le CSS** :
```bash
sudo nano /var/www/pi-signage-player/css/player.css
```

2. **Modifier le JavaScript** :
```bash
sudo nano /var/www/pi-signage-player/js/player.js
```

3. **Recharger le player** :
```bash
sudo /opt/scripts/player-control.sh reload
```

### Ajouter des overlays personnalisés

Dans `/var/www/pi-signage-player/player.html`, modifier la section overlay :

```html
<div id="overlay" class="hidden">
    <div class="video-info">
        <span id="video-title"></span>
        <!-- Ajouter vos éléments ici -->
    </div>
</div>
```

## 🔧 Configuration Avancée

### Optimisations par modèle de Pi

Le script détecte automatiquement le modèle et applique les optimisations :

- **Pi 3B+** : Mode conservateur, GPU limité
- **Pi 4B** : Accélération hardware activée
- **Pi 5** : Performances maximales

### Modifier les flags Chromium

Éditer `/opt/scripts/chromium-kiosk.sh` :

```bash
CHROMIUM_FLAGS=(
    --kiosk
    --window-size=1920,1080
    # Ajouter vos flags ici
)
```

### API WebSocket

Le player écoute sur `ws://localhost:8889` pour les commandes :

```javascript
// Exemple de commande
ws.send(JSON.stringify({
    command: 'play'
}));
```

Commandes disponibles :
- `play` : Démarrer la lecture
- `pause` : Pause
- `next` : Vidéo suivante
- `previous` : Vidéo précédente
- `reload` : Recharger la page
- `update_playlist` : Recharger la playlist

## 🐛 Dépannage

### Le player ne démarre pas

1. Vérifier le service :
```bash
sudo systemctl status chromium-kiosk
```

2. Vérifier les logs :
```bash
tail -f /var/log/pi-signage/chromium.log
```

3. Vérifier X11 :
```bash
echo $DISPLAY  # Doit afficher :0
```

### Écran noir

1. Vérifier la playlist :
```bash
cat /var/www/pi-signage-player/api/playlist.json
```

2. Mettre à jour la playlist :
```bash
sudo /opt/scripts/update-playlist.sh
```

3. Vérifier les vidéos :
```bash
ls -la /opt/videos/
```

### Vidéo ne joue pas

1. Vérifier le format (doit être H.264/WebM)
2. Convertir si nécessaire :
```bash
ffmpeg -i video.avi -c:v libx264 -c:a aac video.mp4
```

### Performance lente

1. Vérifier la température :
```bash
vcgencmd measure_temp
```

2. Vérifier la mémoire :
```bash
free -h
```

3. Redémarrer si nécessaire :
```bash
sudo reboot
```

## 📊 Monitoring

### Accès au mode debug

1. Dans le player, appuyer sur `Ctrl+D`
2. Un panneau de debug apparaît avec les infos

### Métriques système

Via l'interface Glances : `http://[IP]:61208`

### Logs temps réel

```bash
# Logs Chromium
tail -f /var/log/pi-signage/chromium.log

# Logs système
sudo journalctl -u chromium-kiosk -f
```

## 🔄 Migration depuis VLC

### Convertir les vidéos

Script de conversion batch :

```bash
#!/bin/bash
for video in /opt/videos/*.{avi,mkv,wmv}; do
    if [[ -f "$video" ]]; then
        output="${video%.*}.mp4"
        ffmpeg -i "$video" -c:v libx264 -preset fast -crf 23 -c:a aac "$output"
    fi
done
```

### Basculer entre les modes

1. Arrêter le mode actuel :
```bash
sudo systemctl stop vlc-signage  # Si VLC actif
```

2. Désactiver l'ancien mode :
```bash
sudo systemctl disable vlc-signage
sudo systemctl disable lightdm
```

3. Activer Chromium :
```bash
sudo systemctl enable chromium-kiosk
sudo systemctl start chromium-kiosk
```

## 💡 Conseils et Astuces

### Optimiser les vidéos

- **Résolution** : 1920x1080 maximum
- **Bitrate** : 5-8 Mbps pour 1080p
- **Format** : MP4 avec H.264
- **Audio** : AAC 128kbps

### Planification

- Les vidéos jouent dans l'ordre alphabétique
- Préfixer avec des numéros : `01-intro.mp4`, `02-main.mp4`
- La playlist se met à jour automatiquement

### Sécurité

- Le player tourne en utilisateur non-privilégié
- Pas d'accès externe au WebSocket
- Interface web protégée par authentification

## 🆘 Support

En cas de problème :

1. Consulter les logs : `/var/log/pi-signage/chromium.log`
2. Utiliser le diagnostic : `sudo pi-signage-diag`
3. Vérifier ce guide de dépannage
4. Ouvrir une issue sur GitHub avec les logs

---

**Pi Signage Digital - Mode Chromium Kiosk** 🚀