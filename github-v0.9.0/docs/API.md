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
