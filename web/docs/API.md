# 📡 Documentation API - Pi Signage Web Interface

## Vue d'ensemble

L'interface web Pi Signage expose plusieurs endpoints API pour interagir avec le système. Tous les endpoints nécessitent une authentification via session PHP, sauf indication contraire.

## 🔐 Authentification

L'API utilise l'authentification par session PHP. Vous devez d'abord vous connecter via l'interface web pour obtenir une session valide.

### Cookies requis
- `PHPSESSID` : Cookie de session PHP

### Headers recommandés
```http
Content-Type: application/json
Accept: application/json
```

## 📍 Endpoints

### GET /api/status.php

Récupère le statut complet du système.

#### Requête
```bash
curl -X GET http://pi-signage.local/api/status.php \
     -H "Cookie: PHPSESSID=votre_session_id"
```

#### Réponse (200 OK)
```json
{
  "timestamp": "2024-01-15T10:30:45+01:00",
  "hostname": "pi-signage",
  "uptime": "5j 12h 34m",
  "services": {
    "vlc": {
      "status": true,
      "name": "VLC Media Player",
      "service": "vlc-signage.service"
    },
    "glances": {
      "status": true,
      "name": "Glances Monitoring",
      "service": "glances.service"
    },
    "lightdm": {
      "status": true,
      "name": "Display Manager",
      "service": "lightdm.service"
    },
    "watchdog": {
      "status": true,
      "name": "System Watchdog",
      "service": "pi-signage-watchdog.service"
    }
  },
  "system": {
    "cpu_usage": 25.5,
    "memory_usage": 62.3,
    "temperature": 52.1,
    "load_average": [0.15, 0.20, 0.18]
  },
  "storage": {
    "total": 31457280000,
    "used": 14173593600,
    "free": 17283686400,
    "percent": 45,
    "videos_count": 12,
    "videos_size": 2147483648
  },
  "network": {
    "ip_address": "192.168.1.100",
    "google_drive_configured": true
  },
  "last_sync": "2024-01-15T09:00:00+01:00",
  "version": "2.0.0"
}
```

#### Erreurs possibles
- `401 Unauthorized` : Session non valide

---

### POST /api/download.php

Lance le téléchargement d'une vidéo YouTube. Utilise Server-Sent Events pour la progression.

#### Requête
```bash
curl -X POST http://pi-signage.local/api/download.php \
     -H "Cookie: PHPSESSID=votre_session_id" \
     -H "Content-Type: application/json" \
     -d '{
       "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
       "quality": "720p",
       "csrf_token": "votre_csrf_token"
     }'
```

#### Paramètres
| Nom | Type | Requis | Description |
|-----|------|--------|-------------|
| url | string | Oui | URL YouTube de la vidéo |
| quality | string | Non | Qualité vidéo : "480p", "720p", "1080p" (défaut: "720p") |
| csrf_token | string | Oui | Token CSRF de la session |

#### Réponse (Server-Sent Events)
```
data: {"progress": 0, "status": "starting"}

data: {"progress": 15.5, "status": "downloading"}

data: {"progress": 45.2, "status": "downloading"}

data: {"progress": 100, "status": "completed"}
```

#### Erreurs possibles
```
data: {"error": "URL invalide", "status": "error"}
data: {"error": "Token CSRF invalide", "status": "error"}
data: {"error": "Échec du téléchargement", "status": "error"}
```

---

### POST /api/upload.php

Upload une vidéo directement sur le serveur.

#### Requête
```bash
curl -X POST http://pi-signage.local/api/upload.php \
     -H "Cookie: PHPSESSID=votre_session_id" \
     -F "video=@ma_video.mp4"
```

#### Paramètres
- `video` : Fichier vidéo (multipart/form-data)
- Taille max : 100MB
- Formats acceptés : mp4, avi, mkv, mov, wmv, flv, webm, m4v

#### Réponse (200 OK)
```json
{
  "success": true,
  "filename": "ma_video_1705315845.mp4",
  "size": 52428800
}
```

#### Erreurs possibles
- `400 Bad Request` : Aucun fichier envoyé
- `413 Payload Too Large` : Fichier trop volumineux
- `415 Unsupported Media Type` : Format non supporté
- `500 Internal Server Error` : Erreur serveur

---

### POST /api/control.php

Contrôle les services du système (VLC, synchronisation, etc).

#### Requête
```bash
curl -X POST http://pi-signage.local/api/control.php \
     -H "Cookie: PHPSESSID=votre_session_id" \
     -H "Content-Type: application/json" \
     -d '{
       "action": "restart_vlc",
       "csrf_token": "votre_csrf_token"
     }'
```

#### Actions disponibles
| Action | Description |
|--------|-------------|
| restart_vlc | Redémarre le service VLC |
| sync_now | Lance une synchronisation Google Drive |
| clear_cache | Vide le cache système |

#### Réponse (200 OK)
```json
{
  "success": true,
  "message": "VLC redémarré avec succès",
  "timestamp": "2024-01-15T10:35:00+01:00"
}
```

---

### GET /api/videos.php

Liste toutes les vidéos disponibles.

#### Requête
```bash
curl -X GET http://pi-signage.local/api/videos.php \
     -H "Cookie: PHPSESSID=votre_session_id"
```

#### Paramètres query
- `sort` : Tri par "name", "size", "date" (défaut: "date")
- `order` : "asc" ou "desc" (défaut: "desc")

#### Réponse (200 OK)
```json
{
  "videos": [
    {
      "name": "presentation_2024.mp4",
      "path": "/opt/videos/presentation_2024.mp4",
      "size": 104857600,
      "size_formatted": "100 MB",
      "modified": 1705315200,
      "modified_formatted": "2024-01-15 10:00:00",
      "extension": "mp4",
      "duration": null
    },
    {
      "name": "demo_produit.avi",
      "path": "/opt/videos/demo_produit.avi",
      "size": 209715200,
      "size_formatted": "200 MB",
      "modified": 1705228800,
      "modified_formatted": "2024-01-14 10:00:00",
      "extension": "avi",
      "duration": null
    }
  ],
  "total_count": 2,
  "total_size": 314572800,
  "total_size_formatted": "300 MB"
}
```

---

### DELETE /api/videos.php

Supprime une vidéo.

#### Requête
```bash
curl -X DELETE http://pi-signage.local/api/videos.php \
     -H "Cookie: PHPSESSID=votre_session_id" \
     -H "Content-Type: application/json" \
     -d '{
       "video": "/opt/videos/ma_video.mp4",
       "csrf_token": "votre_csrf_token"
     }'
```

#### Réponse (200 OK)
```json
{
  "success": true,
  "message": "Vidéo supprimée avec succès"
}
```

---

### GET /api/logs.php

Récupère les logs du système.

#### Requête
```bash
curl -X GET http://pi-signage.local/api/logs.php?file=vlc.log&lines=50 \
     -H "Cookie: PHPSESSID=votre_session_id"
```

#### Paramètres query
- `file` : Fichier de log ("vlc.log", "sync.log", "health.log", etc)
- `lines` : Nombre de lignes (défaut: 100, max: 1000)

#### Réponse (200 OK)
```json
{
  "log_file": "vlc.log",
  "lines_requested": 50,
  "lines_returned": 50,
  "entries": [
    "2024-01-15 10:30:00 - [INFO] VLC démarré avec succès",
    "2024-01-15 10:30:05 - [INFO] Lecture de presentation_2024.mp4",
    "2024-01-15 10:35:00 - [INFO] Fin de lecture, passage à la vidéo suivante"
  ]
}
```

## 🔒 Sécurité

### Protection CSRF

Tous les endpoints POST/PUT/DELETE nécessitent un token CSRF valide. Le token peut être obtenu depuis la page HTML ou via :

```javascript
// Dans le HTML
const csrfToken = document.querySelector('input[name="csrf_token"]').value;
```

### Rate Limiting

Les endpoints sensibles ont des limites de taux :
- `/api/download.php` : 10 requêtes par heure
- `/api/upload.php` : 20 requêtes par heure
- `/api/control.php` : 30 requêtes par heure

### Validation des entrées

Toutes les entrées utilisateur sont validées :
- URLs : Validation format URL
- Chemins fichiers : Vérification contre path traversal
- Tailles : Limites strictes
- Extensions : Liste blanche

## 🛠️ Exemples d'utilisation

### JavaScript (Fetch API)

```javascript
// Récupérer le statut
async function getSystemStatus() {
    try {
        const response = await fetch('/api/status.php', {
            credentials: 'same-origin'
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        console.log('System status:', data);
        return data;
    } catch (error) {
        console.error('Error fetching status:', error);
    }
}

// Télécharger une vidéo avec progression
async function downloadYouTubeVideo(url, quality = '720p') {
    const csrfToken = document.querySelector('input[name="csrf_token"]').value;
    
    const response = await fetch('/api/download.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            url: url,
            quality: quality,
            csrf_token: csrfToken
        }),
        credentials: 'same-origin'
    });
    
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        
        const text = decoder.decode(value);
        const lines = text.split('\n');
        
        for (const line of lines) {
            if (line.startsWith('data: ')) {
                const data = JSON.parse(line.substring(6));
                console.log('Progress:', data.progress + '%');
                
                if (data.error) {
                    console.error('Download error:', data.error);
                }
            }
        }
    }
}
```

### Python

```python
import requests
import json

class PiSignageAPI:
    def __init__(self, base_url, session_id):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.cookies.set('PHPSESSID', session_id)
    
    def get_status(self):
        """Récupère le statut du système"""
        response = self.session.get(f"{self.base_url}/api/status.php")
        response.raise_for_status()
        return response.json()
    
    def restart_vlc(self, csrf_token):
        """Redémarre VLC"""
        data = {
            'action': 'restart_vlc',
            'csrf_token': csrf_token
        }
        response = self.session.post(
            f"{self.base_url}/api/control.php",
            json=data
        )
        response.raise_for_status()
        return response.json()
    
    def list_videos(self):
        """Liste toutes les vidéos"""
        response = self.session.get(f"{self.base_url}/api/videos.php")
        response.raise_for_status()
        return response.json()

# Utilisation
api = PiSignageAPI('http://pi-signage.local', 'votre_session_id')
status = api.get_status()
print(f"CPU Usage: {status['system']['cpu_usage']}%")
```

### cURL Scripts

```bash
#!/bin/bash
# Script de monitoring Pi Signage

PI_URL="http://pi-signage.local"
SESSION_ID="votre_session_id"

# Fonction pour obtenir le statut
get_status() {
    curl -s -X GET "$PI_URL/api/status.php" \
         -H "Cookie: PHPSESSID=$SESSION_ID" | jq .
}

# Fonction pour redémarrer VLC
restart_vlc() {
    local csrf_token="$1"
    curl -s -X POST "$PI_URL/api/control.php" \
         -H "Cookie: PHPSESSID=$SESSION_ID" \
         -H "Content-Type: application/json" \
         -d "{\"action\": \"restart_vlc\", \"csrf_token\": \"$csrf_token\"}" | jq .
}

# Monitoring continu
while true; do
    STATUS=$(get_status)
    CPU=$(echo "$STATUS" | jq -r '.system.cpu_usage')
    TEMP=$(echo "$STATUS" | jq -r '.system.temperature')
    
    echo "CPU: ${CPU}% | Temp: ${TEMP}°C"
    
    # Alerte si température élevée
    if (( $(echo "$TEMP > 70" | bc -l) )); then
        echo "ALERTE: Température élevée!"
    fi
    
    sleep 60
done
```

## 📝 Notes

- Tous les timestamps sont en ISO 8601
- Les tailles sont en octets sauf indication contraire
- Les réponses d'erreur incluent toujours un champ `error`
- L'API est versionnée via le header de réponse `X-API-Version`

---

Pour toute question ou problème avec l'API, consultez la [documentation principale](../README.md) ou ouvrez une [issue sur GitHub](https://github.com/votre-username/pi-signage-web/issues).