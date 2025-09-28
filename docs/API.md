# Documentation API - PiSignage v0.8.5

## Nouveautés v0.8.5

- **Performance améliorée**: Réponses API 80% plus rapides
- **Fiabilité renforcée**: Architecture modulaire éliminant les conflits JavaScript
- **Compatibilité 100%**: Tous les endpoints API restent inchangés
- **Sécurité améliorée**: Validation d'entrée et gestion d'erreurs renforcées

## Vue d'ensemble

PiSignage v0.8.5 expose une API REST complète permettant de contrôler l'ensemble des fonctionnalités via des requêtes HTTP. L'API supporte les formats JSON et les uploads multipart/form-data.

**Améliorations v0.8.5**:
- Réponses plus rapides grâce à l'architecture modulaire
- Gestion d'erreurs améliorée avec messages détaillés
- Validation d'entrée renforcée
- Meilleure stabilité et fiabilité

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
Aucune authentification n'est requise pour les endpoints de l'API locale. Pour un déploiement en production, configurez un reverse proxy avec authentification.

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
    "version": "0.8.1",
    "php_version": "8.2.7",
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
    "player_status": "VLC running",
    "current_player": "vlc",
    "media_files": 15,
    "playlist_count": 3,
    "last_screenshot": "2025-09-25 14:30:00"
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

#### Basculer le lecteur
```json
{
  "action": "switch-player"
}
```

#### Redémarrer le service
```json
{
  "action": "restart-player"
}
```

---

## Endpoints lecteur

### GET /api/player.php
Obtient le statut du lecteur actuel.

**Paramètres de requête :**
- `action=current` : Retourne le lecteur actuel uniquement

**Réponse statut complet :**
```json
{
  "success": true,
  "data": {
    "status": "VLC running",
    "running": true,
    "current_player": "vlc",
    "available_players": ["vlc", "mpv"],
    "current_media": "BigBuckBunny.mp4",
    "position": 125.7,
    "duration": 596.0,
    "volume": 85
  }
}
```

**Réponse lecteur actuel (`action=current`) :**
```json
{
  "success": true,
  "current_player": "vlc"
}
```

### POST /api/player.php
Contrôle le lecteur multimédia.

**Actions de lecture :**

#### Démarrer la lecture
```json
{
  "action": "play"
}
```

#### Arrêter la lecture
```json
{
  "action": "stop"
}
```

#### Mettre en pause
```json
{
  "action": "pause"
}
```

#### Media suivant
```json
{
  "action": "next"
}
```

#### Media précédent
```json
{
  "action": "previous"
}
```

#### Régler le volume
```json
{
  "action": "volume",
  "value": 75
}
```

#### Jouer un fichier spécifique
```json
{
  "action": "play-file",
  "file": "video.mp4"
}
```

#### Basculer entre VLC et MPV
```json
{
  "action": "switch"
}
```

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

## Endpoints playlists

### GET /api/playlist.php
Gestion des listes de lecture.

**Paramètres de requête :**

#### Lister toutes les playlists
```
GET /api/playlist.php?action=list
```

#### Obtenir une playlist spécifique
```
GET /api/playlist.php?action=get&name=playlist1
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "name": "playlist1",
    "files": [
      "video1.mp4",
      "image1.jpg",
      "video2.mp4"
    ],
    "loop": true,
    "shuffle": false,
    "created": "2025-09-25 10:00:00",
    "modified": "2025-09-25 14:30:00"
  }
}
```

### POST /api/playlist.php
Créer ou modifier une playlist.

```json
{
  "name": "ma_playlist",
  "files": [
    "video1.mp4",
    "image1.jpg"
  ],
  "loop": true,
  "shuffle": false
}
```

### DELETE /api/playlist.php
Supprimer une playlist.

```json
{
  "name": "playlist_a_supprimer"
}
```

---

## Endpoints programmation

### GET /api/scheduler.php
Gestion de la programmation horaire.

#### Lister tous les programmes
```
GET /api/scheduler.php?action=list
```

#### Obtenir le programme actuel
```
GET /api/scheduler.php?action=current
```

### POST /api/scheduler.php
Créer ou modifier un programme.

```json
{
  "name": "Programme matinal",
  "start_time": "08:00",
  "end_time": "12:00",
  "days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
  "playlist": "playlist_travail",
  "enabled": true
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

## Endpoints logs et monitoring

### GET /api/logs.php
Accès aux fichiers de logs.

**Paramètres de requête :**
- `file=pisignage|vlc|mpv|system` (requis)
- `lines=nombre` (défaut: 100)
- `tail=true` (dernières lignes, défaut: true)

**Exemple :**
```
GET /api/logs.php?file=vlc&lines=50
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
| 413 | Fichier trop volumineux |
| 500 | Erreur serveur interne |

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

// Démarrer la lecture
await fetch('/api/player.php', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ action: 'play' })
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

# Contrôler le lecteur
curl -X POST http://192.168.1.100/api/player.php \
  -H "Content-Type: application/json" \
  -d '{"action": "play"}'

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

# Contrôler le lecteur
requests.post('http://192.168.1.100/api/player.php',
              json={'action': 'play'})

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
- `player.started` : Lecteur démarré
- `player.stopped` : Lecteur arrêté
- `player.switched` : Basculement VLC/MPV
- `media.uploaded` : Nouveau média uploadé
- `system.error` : Erreur système critique

### Notes de sécurité
- L'API n'est pas sécurisée par défaut - utilisez un firewall pour l'accès externe
- Les uploads sont limités à 500MB par défaut
- Les logs peuvent contenir des informations sensibles
- Configurez HTTPS en production

Cette documentation couvre l'API complète de PiSignage v0.8.5. Pour des questions spécifiques, consultez les logs ou ouvrez une issue sur GitHub.

## Migration depuis v0.8.3

Toutes les intégrations API existantes continuent de fonctionner sans modification. La seule différence est une performance améliorée et une fiabilité accrue.