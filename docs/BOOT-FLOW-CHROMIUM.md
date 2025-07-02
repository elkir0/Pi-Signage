# Flux de démarrage Chromium Kiosk - Pi Signage Digital

## Vue d'ensemble

Après installation et redémarrage, le système démarre automatiquement en mode kiosk avec lecture vidéo en boucle.

## Séquence de démarrage

### 1. Boot système
- Le Raspberry Pi démarre normalement
- **AUCUNE** modification de `/boot/config.txt` ou `/boot/cmdline.txt`

### 2. Service pi-signage-startup (Boot Manager)
- **Service**: `pi-signage-startup.service`
- **Script**: `/opt/scripts/pi-signage-startup.sh`
- **Délai**: Attend 10 secondes puis démarre
- **Actions**:
  - Vérifie le mode d'affichage dans `/etc/pi-signage/display-mode.conf`
  - Si mode = "chromium", lance X11 et Chromium

### 3. Lancement X11 + Chromium
Le boot manager utilise l'une des méthodes suivantes :
1. **Via x11-kiosk.service** (si disponible)
2. **Via start-x11-kiosk.sh** (démarrage manuel)
3. **Via xinit direct** : `su - pi -c "xinit /opt/scripts/chromium-kiosk.sh -- :0 -nocursor"`

Note : Utilise l'utilisateur `pi` (pas `signage`)

### 4. Script chromium-kiosk.sh
- Configure l'environnement X11
- Désactive l'économiseur d'écran
- Lance Chromium avec les flags optimisés
- URL: `http://localhost:8888/player.html`
- **Boucle infinie** : Redémarre automatiquement si crash

### 5. Player HTML5
- Charge automatiquement la playlist depuis `/var/www/pi-signage-player/api/playlist.json`
- Lit les vidéos en boucle depuis `/opt/videos/`
- Passe à la vidéo suivante automatiquement
- Support WebSocket pour contrôle temps réel

### 6. Mise à jour playlist
- **Cron**: Toutes les 5 minutes
- **Script**: `/opt/scripts/update-playlist.sh`
- Scanne `/opt/videos/` pour les fichiers .mp4, .webm, .mov, .mkv
- Met à jour `/var/www/pi-signage-player/api/playlist.json`

## Services impliqués

1. **pi-signage-startup.service** (activé)
   - Gère le démarrage progressif
   - Lance les services selon le mode
   - Désactive automatiquement les services individuels pour éviter les conflits

2. **x11-kiosk.service** (désactivé par le boot manager)
   - Service de secours pour démarrer X11
   - Utilisé seulement si appelé manuellement

3. **nginx.service** (activé)
   - Sert le player HTML5 sur port 8888
   - Sert l'interface web sur port 80

## Fichiers importants

- `/etc/pi-signage/display-mode.conf` - Contient "chromium"
- `/opt/scripts/chromium-kiosk.sh` - Script principal
- `/var/www/pi-signage-player/player.html` - Player HTML5
- `/var/www/pi-signage-player/api/playlist.json` - Playlist générée
- `/opt/videos/` - Dossier des vidéos

## Vérification post-démarrage

```bash
# Utiliser l'outil de diagnostic intégré
sudo pi-signage-diag --verify-chromium

# Ou via le menu interactif
sudo pi-signage-tools
# Puis option 10 : Vérifier configuration Chromium

# Vérifier les services manuellement
systemctl status pi-signage-startup
systemctl status nginx
ps aux | grep chromium

# Voir les logs
journalctl -u pi-signage-startup -f
tail -f /var/log/pi-signage/chromium.log

# Vérifier la playlist
cat /var/www/pi-signage-player/api/playlist.json

# Contrôler le player
/opt/scripts/player-control.sh status
```

## Problèmes courants

1. **Écran noir** : Vérifier que X11 est démarré (`ps aux | grep X`)
2. **Pas de vidéo** : Vérifier que des vidéos sont dans `/opt/videos/`
3. **Player ne charge pas** : Vérifier nginx (`systemctl status nginx`)
4. **Playlist vide** : Exécuter manuellement `/opt/scripts/update-playlist.sh`

## Notes importantes

### Modifications du boot
**AUCUNE modification** n'est apportée aux fichiers de boot :
- `/boot/config.txt` reste intact
- `/boot/cmdline.txt` reste intact
- Toute configuration doit être faite manuellement via `raspi-config`

### Mode test intégré
Après installation, un mode test est proposé automatiquement.
Pour le relancer plus tard :
```bash
sudo pi-signage-tools
# Option 11 : Tester Chromium Kiosk
```

### Gestion des conflits
Le boot manager désactive automatiquement les services individuels :
- `x11-kiosk.service` est désactivé pour éviter les conflits
- Seul `pi-signage-startup.service` gère le démarrage