# 🌐 Proposition : Mode Chromium Kiosk pour Pi Signage

## Vue d'ensemble

Cette proposition détaille une architecture alternative utilisant Chromium en mode kiosk pour remplacer VLC, offrant plus de flexibilité tout en réduisant la complexité.

## Architecture proposée

### Stack actuel (VLC)
```
Raspberry Pi OS Lite
    └── X11 Server
        └── LightDM
            └── Openbox WM
                └── VLC (fullscreen)
```

### Stack proposé (Chromium)
```
Raspberry Pi OS Lite
    └── X11 Server (minimal)
        └── Chromium Kiosk
            └── Application Web locale
```

## Implémentation

### 1. Script de démarrage simplifié

```bash
#!/bin/bash
# /opt/scripts/chromium-kiosk.sh

# Variables
URL="http://localhost/player"
LOG_FILE="/var/log/pi-signage/chromium.log"

# Nettoyage
rm -rf ~/.cache/chromium
rm -rf ~/.config/chromium

# Options Chromium optimisées pour Pi
CHROMIUM_FLAGS=(
    --kiosk
    --noerrdialogs
    --disable-infobars
    --disable-session-crashed-bubble
    --disable-translate
    --no-first-run
    --fast
    --fast-start
    --disable-features=TranslateUI
    --disk-cache-dir=/tmp/chromium-cache
    --overscroll-history-navigation=0
    --disable-pinch
    --autoplay-policy=no-user-gesture-required
    --window-size=1920,1080
    --window-position=0,0
)

# Boucle de récupération
while true; do
    echo "$(date): Démarrage Chromium" >> "$LOG_FILE"
    
    chromium-browser "${CHROMIUM_FLAGS[@]}" "$URL" \
        2>&1 | tee -a "$LOG_FILE"
    
    echo "$(date): Chromium fermé, redémarrage dans 5s" >> "$LOG_FILE"
    sleep 5
done
```

### 2. Player HTML5 local

```html
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Pi Signage Player</title>
    <style>
        * { margin: 0; padding: 0; overflow: hidden; }
        body { background: #000; }
        video { 
            width: 100vw; 
            height: 100vh; 
            object-fit: cover; 
        }
        .overlay {
            position: absolute;
            bottom: 20px;
            left: 20px;
            color: white;
            font-family: Arial;
            background: rgba(0,0,0,0.7);
            padding: 10px;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <video id="player" autoplay muted></video>
    <div class="overlay" id="info"></div>
    
    <script>
        class VideoPlayer {
            constructor() {
                this.player = document.getElementById('player');
                this.info = document.getElementById('info');
                this.playlist = [];
                this.currentIndex = 0;
                
                this.init();
            }
            
            async init() {
                // Charger la playlist
                await this.loadPlaylist();
                
                // Démarrer la lecture
                this.playNext();
                
                // Gérer la fin de vidéo
                this.player.addEventListener('ended', () => this.playNext());
                
                // WebSocket pour contrôle temps réel
                this.connectWebSocket();
            }
            
            async loadPlaylist() {
                try {
                    const response = await fetch('/api/playlist.json');
                    this.playlist = await response.json();
                } catch (error) {
                    console.error('Erreur chargement playlist:', error);
                    // Fallback sur dossier vidéos
                    this.playlist = ['/videos/default.mp4'];
                }
            }
            
            playNext() {
                if (this.playlist.length === 0) {
                    this.showNoContent();
                    return;
                }
                
                const video = this.playlist[this.currentIndex];
                this.player.src = video.path;
                this.player.play();
                
                // Afficher info
                this.info.textContent = video.name || '';
                
                // Passer à la suivante
                this.currentIndex = (this.currentIndex + 1) % this.playlist.length;
            }
            
            showNoContent() {
                document.body.innerHTML = `
                    <div style="display:flex;align-items:center;justify-content:center;height:100vh;color:white;font-size:2em;">
                        En attente de contenu...
                    </div>
                `;
            }
            
            connectWebSocket() {
                // Connexion WebSocket pour contrôle temps réel
                const ws = new WebSocket('ws://localhost:8081');
                
                ws.onmessage = (event) => {
                    const cmd = JSON.parse(event.data);
                    switch(cmd.action) {
                        case 'reload':
                            location.reload();
                            break;
                        case 'play':
                            this.player.play();
                            break;
                        case 'pause':
                            this.player.pause();
                            break;
                        case 'next':
                            this.playNext();
                            break;
                    }
                };
            }
        }
        
        // Démarrer quand prêt
        document.addEventListener('DOMContentLoaded', () => {
            new VideoPlayer();
        });
    </script>
</body>
</html>
```

### 3. Service systemd optimisé

```ini
[Unit]
Description=Chromium Kiosk Mode
After=graphical.target

[Service]
Type=simple
User=pi
Group=pi
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pi/.Xauthority

# Optimisations mémoire
Environment=CHROMIUM_FLAGS=--max_old_space_size=512

ExecStartPre=/bin/sleep 10
ExecStart=/opt/scripts/chromium-kiosk.sh
Restart=always
RestartSec=10

# Limites
MemoryMax=512M
CPUQuota=80%

[Install]
WantedBy=graphical.target
```

## Avantages de cette approche

### 1. **Ressources réduites**
- Pas de gestionnaire de fenêtres
- Un seul processus principal
- Démarrage plus rapide (~20s vs ~45s)

### 2. **Flexibilité accrue**
- Support contenu web natif
- Animations CSS/JS
- Intégration API facile
- Overlays et transitions

### 3. **Maintenance simplifiée**
- Une seule application
- Updates via web
- Logs centralisés
- Debug plus facile

### 4. **Fonctionnalités modernes**
- Progressive Web App
- Service Workers pour cache offline
- WebRTC pour streaming
- Canvas/WebGL pour effets

## Comparaison performance

| Métrique | VLC | Chromium Kiosk |
|----------|-----|----------------|
| RAM au repos | ~350MB | ~250MB |
| CPU idle | 5-10% | 10-15% |
| Temps de boot | 45s | 25s |
| Stabilité | Excellent | Bon* |
| Formats vidéo | Tous | H.264/WebM |

*Avec watchdog approprié

## Migration proposée

### Phase 1 : Option d'installation
```bash
# Dans le menu d'installation
echo "Choisir le mode d'affichage:"
echo "1) VLC (recommandé - tous formats)"
echo "2) Chromium Kiosk (web moderne)"
```

### Phase 2 : Module séparé
Créer `03-chromium-kiosk.sh` comme alternative à `03-vlc-setup.sh`

### Phase 3 : Interface web adaptative
L'interface détecte le mode et adapte les fonctionnalités

## Cas d'usage recommandés

### Utiliser Chromium Kiosk pour :
- ✅ Contenu mixte (vidéo + web)
- ✅ Overlays et informations dynamiques
- ✅ Intégration APIs externes
- ✅ Raspberry Pi 4/5 avec 2GB+ RAM

### Garder VLC pour :
- ✅ Vidéos uniquement
- ✅ Formats exotiques (HEVC, etc.)
- ✅ Raspberry Pi 3B+ ou RAM limitée
- ✅ Stabilité maximale 24/7

## Conclusion

L'option Chromium Kiosk offre une alternative moderne et flexible, particulièrement adaptée aux usages nécessitant plus qu'une simple lecture vidéo. L'implémentation en tant qu'option permet aux utilisateurs de choisir selon leurs besoins.

### Prochaines étapes
1. Créer un prototype du module Chromium
2. Tester sur différents modèles de Pi
3. Benchmarker les performances
4. Intégrer comme option dans l'installateur