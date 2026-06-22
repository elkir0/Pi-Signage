# Documentation API - Zaforge v0.12.0

## Nouveautés v0.12.0

- **Moteur de lecture unique Chromium HTML5**: VLC retiré. Le player (`web/player.php` servi sur `/player`) lit `/opt/pisignage/media/playlist.json` et se recharge seul.
- **Endpoints unifiés**: playlists via `/api/playlists.php` (source de vérité unique), contrôle du moteur via `/api/display.php`.
- **Endpoints dépréciés (HTTP 410)**: `playlist-simple.php`, `player.php`, `player-control.php`.
- **Volume = ALSA système**: plus de « volume VLC ». Le volume passe par `/api/system.php` (`set_volume`/`get_volume`/`toggle_mute`).
- **Programmation (dayparting) réelle**: `/api/scheduler.php` est un exécuteur CLI lancé par cron 1×/minute (www-data).

## Vue d'ensemble

Zaforge v0.12.0 expose une API REST complète permettant de contrôler l'ensemble des fonctionnalités via des requêtes HTTP. L'API supporte les formats JSON et les uploads multipart/form-data.

Le moteur de lecture unique est **Chromium HTML5** en mode kiosk (Wayland/labwc). Le player web poll `/api/display.php` pour les commandes (toutes les 2s) et la version de playlist (toutes les 10s), puis se recharge automatiquement. VLC, MPV, l'interface HTTP VLC (port 8080) et le mot de passe VLC n'existent plus.

### URL de base
```
http://[IP-RASPBERRY]/api/
```

### Format des réponses
Toutes les réponses sont au format JSON avec la structure suivante :
```json
{
  "success": true|false,
  "data": {...},
  "message": "Message explicatif"
}
```

### Authentification
Tous les endpoints API nécessitent une authentification via session PHP. Les utilisateurs doivent être connectés via `/login.php` avant d'accéder aux APIs. Pour un déploiement en production externe, configurez HTTPS et un reverse proxy.

---

## Endpoints système

### GET /api/system.php
Retourne les informations système complètes.

**Réponse :**
```json
{
  "success": true,
  "data": {
    "hostname": "raspberrypi",
    "ip": "192.168.1.100",
    "version": "0.12.0",
    "php_version": "8.4.0",
    "platform": "Linux",
    "cpu_usage": 15.4,
    "memory": {
      "total": 4096,
      "used": 1024,
      "free": 3072,
      "percentage": 25.0
    },
    "disk": {
      "total": 32768,
      "used": 8192,
      "free": 24576,
      "percentage": 25.0
    },
    "temperature": 45.2,
    "uptime": "2 days, 14:30:25",
    "player_status": "Chromium kiosk running",
    "engine": "chromium",
    "media_files": 15,
    "playlist_count": 3,
    "last_screenshot": "2026-06-20 14:30:00"
  }
}
```

### POST /api/system.php
Exécute des actions système.

**Actions disponibles :**

#### Redémarrer le système
```json
{
  "action": "reboot"
}
```

#### Arrêter le système
```json
{
  "action": "shutdown"
}
```

#### Redémarrer la session graphique
Redémarre la session d'affichage (lightdm → labwc → Chromium kiosk). Équivaut à `sudo systemctl restart display-manager`.
```json
{
  "action": "restart-player"
}
```

### Contrôle du volume (ALSA système)

Le volume est le **volume système ALSA** (amixer). Il n'y a plus de « volume VLC ».

#### Obtenir le volume
```
GET /api/system.php?action=get_volume
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "volume": 75,
    "muted": false
  }
}
```

#### Régler le volume
```json
{
  "action": "set_volume",
  "value": 75
}
```
- `value` : 0-100 (pourcentage ALSA)

#### Basculer la sourdine
```json
{
  "action": "toggle_mute"
}
```

---

## Endpoints lecteur (moteur Chromium HTML5)

> Le contrôle du moteur de lecture réel passe par `/api/display.php`. Le player web (`/player`) poll `GET ?action=command` toutes les 2s et rapporte son état via `POST ?action=state`.

### POST /api/display.php?action=command
Envoie une commande au player en cours.

```json
{
  "cmd": "next"
}
```
- `cmd` : `next` | `prev` | `play` | `pause` | `reload`

### GET /api/display.php?action=command
Poll utilisé par le player pour récupérer la prochaine commande en attente.

### POST /api/display.php?action=state
Le player rapporte son état (média courant, index, lecture/pause).

### GET /api/display.php?action=state
Lecture de l'état live du player (pour l'admin).

**Réponse :**
```json
{
  "success": true,
  "data": {
    "playing": true,
    "current_media": "BigBuckBunny.mp4",
    "index": 2,
    "playlist": "default",
    "version": 7
  }
}
```

### POST /api/display.php?action=playmedia
Lit un média isolé (sans modifier la playlist active).

```json
{
  "action": "playmedia",
  "file": "video.mp4"
}
```

> **Note**: pour le réglage du volume, voir « Contrôle du volume (ALSA système) » dans les endpoints système. Le player Chromium HTML5 gère le `mute` par média (champ `mute` du schéma de playlist), distinct du volume ALSA global.

> **Endpoints dépréciés (HTTP 410)**: `player.php`, `player-control.php`. Utilisez `/api/display.php`.

---

## Endpoints médias

### GET /api/media.php
Gère les fichiers multimédias.

**Paramètres de requête :**

#### Lister tous les médias
```
GET /api/media.php?action=list
```

**Réponse :**
```json
{
  "success": true,
  "data": [
    {
      "filename": "video1.mp4",
      "size": 25600000,
      "size_human": "25.6 MB",
      "modified": "2025-09-25 14:30:00",
      "type": "video",
      "duration": 120.5,
      "resolution": "1920x1080"
    },
    {
      "filename": "image1.jpg",
      "size": 2048000,
      "size_human": "2.0 MB",
      "modified": "2025-09-25 10:15:00",
      "type": "image",
      "resolution": "1920x1080"
    }
  ]
}
```

#### Informations d'un fichier
```
GET /api/media.php?action=info&file=video1.mp4
```

#### Miniatures des médias
```
GET /api/media.php?action=thumbnails
```

### POST /api/media.php
Actions sur les médias.

#### Supprimer un fichier
```json
{
  "action": "delete",
  "filename": "video1.mp4"
}
```

#### Renommer un fichier
```json
{
  "action": "rename",
  "old_name": "video1.mp4",
  "new_name": "nouveau_nom.mp4"
}
```

---

## Endpoints playlists (unifiés)

> **Source de vérité unique** : `/api/playlists.php` (noyau partagé `web/api/playlists-core.php`).
> Chaque playlist est stockée dans `/opt/pisignage/playlists/<slug>.json`.
> Le pointeur de playlist active est `/opt/pisignage/config/active-playlist.json`.
> « Diffuser à l'écran » écrit `/opt/pisignage/media/playlist.json` et incrémente `version` ; le player recharge seul (poll version 10s + canal reload 2s).
>
> **Endpoint déprécié (HTTP 410)** : `playlist-simple.php`. Utilisez `/api/playlists.php`.

**Schéma de playlist :**
```json
{
  "name": "Ma playlist",
  "slug": "ma-playlist",
  "version": 3,
  "autoplay": true,
  "autoLoop": true,
  "items": [
    {
      "url": "video1.mp4",
      "type": "video",
      "name": "video1.mp4",
      "duration": 0,
      "fit": "contain",
      "mute": false,
      "loop": false,
      "transition": "none"
    }
  ]
}
```

### GET /api/playlists.php
Liste toutes les playlists et indique la playlist active.

**Réponse :**
```json
{
  "success": true,
  "data": {
    "playlists": [
      { "name": "Ma playlist", "slug": "ma-playlist", "items": 5 }
    ],
    "active": "ma-playlist"
  }
}
```

### GET /api/playlists.php?name=X
Obtient une playlist spécifique (par slug ou nom).

**Réponse :** objet playlist complet (voir schéma ci-dessus).

### POST /api/playlists.php
Créer ou mettre à jour une playlist.

```json
{
  "name": "Ma playlist",
  "items": [
    { "url": "video1.mp4", "type": "video", "duration": 0 },
    { "url": "image1.jpg", "type": "image", "duration": 10 }
  ],
  "autoplay": true,
  "autoLoop": true
}
```

### POST /api/playlists.php?action=activate&name=X
« Diffuser à l'écran » : désigne la playlist comme active, écrit `/opt/pisignage/media/playlist.json` et incrémente `version`.

**Réponse :**
```json
{
  "success": true,
  "data": { "active": "ma-playlist", "version": 4 },
  "message": "Playlist diffusée à l'écran"
}
```

### DELETE /api/playlists.php?name=X
Supprimer une playlist.

```json
{
  "name": "playlist-a-supprimer"
}
```

---

## Endpoints programmation (dayparting réel)

> **Architecture v0.12** : `web/api/scheduler.php` est un **exécuteur CLI** lancé par cron 1×/minute (en `www-data`, via `/etc/cron.d/pisignage-scheduler`). À chaque exécution il lit `/opt/pisignage/data/schedules.json` et désigne la playlist active selon heure/jour/récurrence/priorité (idempotent ; revert de la playlist en fin de fenêtre). L'état réel est écrit dans `/opt/pisignage/config/scheduler-state.json` et reflété dans l'UI.
>
> `web/config.php` aligne le fuseau horaire PHP sur `/etc/timezone` (sinon le dayparting comparerait des heures UTC à des heures locales).
>
> Les programmes sont gérés depuis l'UI « Programmation » et persistés dans `/opt/pisignage/data/schedules.json`.

**Schéma d'un programme (`schedules.json`) :**
```json
{
  "name": "Programme matinal",
  "start_time": "08:00",
  "end_time": "12:00",
  "days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
  "playlist": "playlist-travail",
  "priority": 10,
  "enabled": true
}
```

**État courant (`scheduler-state.json`) :**
```json
{
  "active_schedule": "Programme matinal",
  "active_playlist": "playlist-travail",
  "applied_at": "2026-06-20T08:00:00+02:00"
}
```

---

## Endpoints upload

### POST /api/upload.php
Upload de fichiers multimédias.

**Requête multipart/form-data :**
```html
<form enctype="multipart/form-data">
  <input type="file" name="media_files[]" multiple>
  <input type="hidden" name="action" value="upload">
</form>
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "uploaded_files": [
      {
        "filename": "nouveau_video.mp4",
        "size": 15728640,
        "status": "success"
      }
    ],
    "failed_files": [],
    "total_uploaded": 1
  }
}
```

---

## Endpoints capture d'écran

### GET /api/screenshot.php
Capture l'écran actuel.

**Paramètres de requête :**
- `format=png|jpg` (défaut: png)
- `quality=1-100` (pour JPEG, défaut: 80)
- `width=pixels` (redimensionnement, optionnel)
- `height=pixels` (redimensionnement, optionnel)

**Exemple :**
```
GET /api/screenshot.php?format=jpg&quality=90&width=1280
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "filename": "screenshot-20250925-143000.png",
    "path": "/opt/pisignage/web/screenshots/screenshot-20250925-143000.png",
    "url": "/screenshots/screenshot-20250925-143000.png",
    "size": 1024000,
    "timestamp": "2025-09-25 14:30:00"
  }
}
```

---

## Endpoints téléchargement YouTube

### POST /api/youtube.php
Télécharge une vidéo YouTube.

```json
{
  "action": "download",
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "quality": "720p",
  "filename": "ma_video"
}
```

### GET /api/youtube.php
Statut du téléchargement.

```
GET /api/youtube.php?action=status&id=download_id
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "status": "downloading",
    "progress": 45.7,
    "eta": "00:02:30",
    "filename": "ma_video.mp4"
  }
}
```

---

## Endpoints Kiosk Mode (Trixie uniquement) 🆕

> **Disponible uniquement sur Raspberry Pi OS Trixie (Debian 13)** avec mode kiosk Chromium activé

### GET /api/kiosk.php
Retourne le statut et la configuration du mode kiosk.

**Réponse :**
```json
{
  "success": true,
  "data": {
    "enabled": true,
    "url": "https://grafana.local/dashboard",
    "flags": "--incognito --noerrdialogs --disable-translate",
    "chromium_running": true,
    "autostart_exists": true
  },
  "message": "Kiosk status"
}
```

### GET /api/kiosk.php/url
Obtient l'URL actuelle du kiosk.

**Réponse :**
```json
{
  "success": true,
  "data": {
    "url": "https://grafana.local/dashboard"
  }
}
```

### PUT /api/kiosk.php/url
Met à jour l'URL du kiosk et régénère la configuration labwc.

**Requête :**
```json
{
  "url": "https://home-assistant.local:8123"
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "url": "https://home-assistant.local:8123",
    "applied": true,
    "message": "Autostart regenerated successfully"
  }
}
```

### GET /api/kiosk.php/flags
Obtient les flags Chromium actuels.

**Réponse :**
```json
{
  "success": true,
  "data": {
    "flags": "--incognito --noerrdialogs --force-device-scale-factor=1.5"
  }
}
```

### PUT /api/kiosk.php/flags
Met à jour les flags Chromium et régénère la configuration.

**Requête :**
```json
{
  "flags": "--incognito --noerrdialogs --high-dpi-support=1"
}
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "flags": "--incognito --noerrdialogs --high-dpi-support=1",
    "applied": true
  }
}
```

### POST /api/kiosk.php/restart
Redémarre le navigateur Chromium kiosk.

**Réponse :**
```json
{
  "success": true,
  "data": {
    "killed": true,
    "applied": true,
    "message": "Chromium killed. Will restart on next labwc session.",
    "note": "For immediate effect, logout/login or restart labwc session"
  }
}
```

**Flags Chromium recommandés :**
- **Basique**: `--incognito --noerrdialogs --disable-translate --no-first-run`
- **4K Display**: `--incognito --force-device-scale-factor=1.5 --high-dpi-support=1`
- **Performance**: `--incognito --disable-gpu-vsync --disable-infobars`

**Exemples d'utilisation :**
```bash
# Changer URL du kiosk
curl -X PUT http://[pi-ip]/api/kiosk.php/url \
  -H "Content-Type: application/json" \
  -d '{"url":"https://grafana.local/dashboard"}'

# Ajuster pour affichage 4K
curl -X PUT http://[pi-ip]/api/kiosk.php/flags \
  -H "Content-Type: application/json" \
  -d '{"flags":"--incognito --force-device-scale-factor=1.5 --high-dpi-support=1"}'

# Redémarrer Chromium
curl -X POST http://[pi-ip]/api/kiosk.php/restart
```

---

## Endpoints logs et monitoring

### GET /api/logs.php
Accès aux fichiers de logs.

**Paramètres de requête :**
- `file=pisignage|system|nginx` (requis)
- `lines=nombre` (défaut: 100)
- `tail=true` (dernières lignes, défaut: true)

**Exemple :**
```
GET /api/logs.php?file=pisignage&lines=50
```

### GET /api/performance.php
Métriques de performance temps réel.

**Réponse :**
```json
{
  "success": true,
  "data": {
    "timestamp": "2025-09-25T14:30:00Z",
    "cpu": {
      "usage": 25.4,
      "load_1min": 0.8,
      "load_5min": 0.6,
      "load_15min": 0.4
    },
    "memory": {
      "total": 4096,
      "available": 3072,
      "used": 1024,
      "percentage": 25.0
    },
    "gpu": {
      "temperature": 45.2,
      "memory_split": 128
    },
    "network": {
      "interface": "wlan0",
      "rx_bytes": 1024000,
      "tx_bytes": 512000,
      "signal_strength": -45
    }
  }
}
```

---

## Gestion d'erreurs

### Codes d'erreur communs

| Code | Description |
|------|-------------|
| 400 | Requête malformée |
| 404 | Endpoint non trouvé |
| 405 | Méthode HTTP non supportée |
| 410 | Endpoint déprécié et supprimé (voir « Endpoints dépréciés ») |
| 413 | Fichier trop volumineux |
| 500 | Erreur serveur interne |

### Endpoints dépréciés (HTTP 410)

Les endpoints suivants ont été supprimés en v0.12.0 et répondent désormais **HTTP 410 Gone** :

| Ancien endpoint | Remplacement |
|-----------------|--------------|
| `playlist-simple.php` | `/api/playlists.php` |
| `player.php` | `/api/display.php` |
| `player-control.php` | `/api/display.php` |

### Exemples de réponses d'erreur

```json
{
  "success": false,
  "message": "File not found: video.mp4",
  "error_code": "MEDIA_NOT_FOUND"
}
```

---

## Exemples d'utilisation

### JavaScript/Fetch API
```javascript
// Obtenir le statut système
const systemStatus = await fetch('/api/system.php')
  .then(response => response.json());

// Démarrer la lecture (commande au moteur Chromium)
await fetch('/api/display.php?action=command', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ cmd: 'play' })
});

// Upload d'un fichier
const formData = new FormData();
formData.append('media_files[]', fileInput.files[0]);
formData.append('action', 'upload');

await fetch('/api/upload.php', {
  method: 'POST',
  body: formData
});
```

### cURL
```bash
# Statut système
curl http://192.168.1.100/api/system.php

# Contrôler le lecteur (moteur Chromium)
curl -X POST "http://192.168.1.100/api/display.php?action=command" \
  -H "Content-Type: application/json" \
  -d '{"cmd": "play"}'

# Régler le volume système (ALSA)
curl -X POST http://192.168.1.100/api/system.php \
  -H "Content-Type: application/json" \
  -d '{"action": "set_volume", "value": 75}'

# Upload d'un fichier
curl -X POST http://192.168.1.100/api/upload.php \
  -F "media_files[]=@video.mp4" \
  -F "action=upload"
```

### Python
```python
import requests

# Statut système
response = requests.get('http://192.168.1.100/api/system.php')
system_info = response.json()

# Contrôler le lecteur (moteur Chromium)
requests.post('http://192.168.1.100/api/display.php?action=command',
              json={'cmd': 'play'})

# Upload d'un fichier
files = {'media_files[]': open('video.mp4', 'rb')}
data = {'action': 'upload'}
requests.post('http://192.168.1.100/api/upload.php',
              files=files, data=data)
```

---

## Webhooks et événements

### Configuration des webhooks
Les webhooks peuvent être configurés dans `/opt/pisignage/config/webhooks.json` pour recevoir des notifications d'événements.

**Événements disponibles :**
- `player.started` : Player Chromium démarré
- `player.stopped` : Player Chromium arrêté
- `media.uploaded` : Nouveau média uploadé
- `system.error` : Erreur système critique

### Notes de sécurité
- L'API n'est pas sécurisée par défaut - utilisez un firewall pour l'accès externe
- Les uploads sont limités à 500MB par défaut
- Les logs peuvent contenir des informations sensibles
- Configurez HTTPS en production

Cette documentation couvre l'API complète de Zaforge v0.12.0. Pour des questions spécifiques, consultez les logs ou ouvrez une issue sur GitHub.

## Migration depuis versions précédentes

La version 0.12.0 introduit des changements majeurs côté API :
- **Moteur unique Chromium HTML5**: VLC retiré (plus de service `pisignage-vlc`, plus d'interface HTTP VLC port 8080, plus de mot de passe VLC).
- **Contrôle du lecteur via `/api/display.php`**: commandes `next|prev|play|pause|reload`, état live, lecture isolée `playmedia`.
- **Playlists unifiées via `/api/playlists.php`**: source de vérité unique (`/opt/pisignage/playlists/<slug>.json`), activation « Diffuser à l'écran ».
- **Volume = ALSA système** via `/api/system.php` (`set_volume`/`get_volume`/`toggle_mute`).
- **Dayparting réel**: `scheduler.php` est un exécuteur CLI lancé par cron 1×/minute.
- **Endpoints dépréciés (HTTP 410)**: `playlist-simple.php`, `player.php`, `player-control.php`.

Les intégrations basées sur `player.php` ou `playlist-simple.php` doivent migrer vers `display.php` et `playlists.php`.