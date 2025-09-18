# Documentation API PiSignage Desktop v3.0

## 📋 Table des matières

- [Vue d'ensemble](#-vue-densemble)
- [Authentification](#-authentification)
- [Endpoints disponibles](#-endpoints-disponibles)
- [Modèles de données](#-modèles-de-données)
- [Codes d'erreur](#-codes-derreur)
- [Exemples d'utilisation](#-exemples-dutilisation)
- [Clients et SDKs](#-clients-et-sdks)
- [Webhooks](#-webhooks)

## 🎯 Vue d'ensemble

L'API REST de PiSignage Desktop v3.0 permet le contrôle programmatique complet du système d'affichage dynamique. Elle est conçue pour être simple, RESTful et compatible avec tous les langages de programmation.

### Informations générales

- **Base URL** : `http://IP-DU-RASPBERRY/api/v1/endpoints.php`
- **Format** : JSON uniquement
- **Authentification** : Token Bearer (optionnel en v3.0)
- **CORS** : Activé pour développement web
- **Rate limiting** : Non implémenté (à configurer au niveau nginx)

### Structure des réponses

Toutes les réponses suivent le format standard :

```json
{
    "success": true|false,
    "data": {}, 
    "message": "Description du résultat",
    "timestamp": "2024-09-18T14:30:15+02:00"
}
```

### Codes de statut HTTP

| Code | Signification | Usage |
|------|---------------|--------|
| 200 | OK | Requête réussie |
| 400 | Bad Request | Paramètres invalides |
| 401 | Unauthorized | Authentification requise |
| 404 | Not Found | Ressource introuvable |
| 405 | Method Not Allowed | Méthode HTTP incorrecte |
| 500 | Internal Server Error | Erreur serveur |

## 🔐 Authentification

### Version actuelle (v3.0)

L'authentification est optionnelle pour la plupart des endpoints en v3.0. Pour les actions sensibles (reboot, configuration système), l'authentification est requise.

```bash
# Requête sans authentification
curl -X GET http://192.168.1.100/api/v1/endpoints.php?action=system_info

# Requête avec token (pour actions sensibles)
curl -X POST http://192.168.1.100/api/v1/endpoints.php \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"system_reboot"}'
```

### Authentification future (v3.1+)

```json
{
    "username": "admin",
    "password": "your_password"
}
```

**Réponse** :
```json
{
    "success": true,
    "data": {
        "token": "jwt_token_here",
        "expires_in": 3600
    },
    "message": "Authentification réussie"
}
```

## 📡 Endpoints disponibles

### Système et statut

#### GET /api/v1/endpoints.php?action=system_info

Récupère les informations système détaillées.

**Paramètres** : Aucun

**Réponse** :
```json
{
    "success": true,
    "data": {
        "hostname": "pisignage-001",
        "uptime": "up 2 days, 14 hours, 32 minutes",
        "ip": "192.168.1.100",
        "version": "3.0.0",
        "mode": "kiosk",
        "cpu_percent": 15.2,
        "memory": {
            "total": "4GB",
            "used": "1.8GB",
            "free": "2.2GB",
            "percent": 45
        },
        "disk": {
            "total": "32GB",
            "used": "8.5GB", 
            "free": "23.5GB",
            "percent": 27
        },
        "temperature": 42.5,
        "gpu_memory": "128MB"
    },
    "message": "Informations système récupérées"
}
```

#### GET /api/v1/endpoints.php?action=service_status

Vérifie le statut des services système.

**Réponse** :
```json
{
    "success": true,
    "data": {
        "pisignage": {
            "active": true,
            "enabled": true,
            "status": "running",
            "since": "2024-09-18 08:30:15"
        },
        "nginx": {
            "active": true,
            "enabled": true,
            "status": "running",
            "since": "2024-09-18 08:30:10"
        }
    },
    "message": "Statut des services récupéré"
}
```

#### POST /api/v1/endpoints.php

Contrôle des services système.

**Paramètres** :
```json
{
    "action": "service_control",
    "service": "pisignage|nginx",
    "action": "start|stop|restart|status"
}
```

**Exemple** :
```bash
curl -X POST http://192.168.1.100/api/v1/endpoints.php \
  -H "Content-Type: application/json" \
  -d '{"action":"service_control","service":"pisignage","action":"restart"}'
```

### Gestion des médias

#### GET /api/v1/endpoints.php?action=videos

Liste tous les fichiers vidéo disponibles.

**Réponse** :
```json
{
    "success": true,
    "data": [
        {
            "filename": "presentation.mp4",
            "path": "/opt/pisignage/videos/presentation.mp4",
            "size": 156789012,
            "size_formatted": "156 MB",
            "duration": 180,
            "duration_formatted": "3:00",
            "resolution": "1920x1080",
            "codec": "h264",
            "bitrate": "2.5 Mbps",
            "created": "2024-09-18T10:30:00+02:00",
            "modified": "2024-09-18T10:30:00+02:00"
        },
        {
            "filename": "pub-produit.mp4",
            "path": "/opt/pisignage/videos/pub-produit.mp4",
            "size": 89456123,
            "size_formatted": "89 MB",
            "duration": 45,
            "duration_formatted": "0:45",
            "resolution": "1920x1080",
            "codec": "h264",
            "bitrate": "1.8 Mbps",
            "created": "2024-09-17T15:20:00+02:00",
            "modified": "2024-09-17T15:20:00+02:00"
        }
    ],
    "message": "Liste des vidéos récupérée"
}
```

#### POST /api/v1/endpoints.php

Upload d'un nouveau fichier vidéo.

**Paramètres** : Multipart form-data avec fichier

```bash
curl -X POST http://192.168.1.100/api/v1/endpoints.php \
  -F "action=upload_video" \
  -F "video=@/path/to/video.mp4"
```

**Réponse** :
```json
{
    "success": true,
    "data": {
        "filename": "video.mp4",
        "size": 45123456,
        "path": "/opt/pisignage/videos/video.mp4"
    },
    "message": "Vidéo uploadée avec succès"
}
```

#### DELETE /api/v1/endpoints.php

Suppression d'un fichier vidéo.

**Paramètres** :
```json
{
    "action": "delete_video",
    "filename": "video.mp4"
}
```

### Contrôle du player

#### POST /api/v1/endpoints.php

Contrôle du lecteur multimédia.

**Paramètres** :
```json
{
    "action": "player_control",
    "action": "play|pause|stop|next|previous|restart|volume|seek"
}
```

**Actions supportées** :

| Action | Description | Paramètres supplémentaires |
|--------|-------------|---------------------------|
| `play` | Démarrer la lecture | - |
| `pause` | Mettre en pause | - |
| `stop` | Arrêter complètement | - |
| `next` | Média suivant | - |
| `previous` | Média précédent | - |
| `restart` | Redémarrer le player | - |
| `volume` | Ajuster le volume | `value`: 0.0-1.0 |
| `seek` | Aller à une position | `value`: secondes |

**Exemples** :

```bash
# Lecture
curl -X POST http://192.168.1.100/api/v1/endpoints.php \
  -H "Content-Type: application/json" \
  -d '{"action":"player_control","action":"play"}'

# Volume à 80%
curl -X POST http://192.168.1.100/api/v1/endpoints.php \
  -H "Content-Type: application/json" \
  -d '{"action":"player_control","action":"volume","value":0.8}'

# Aller à 30 secondes
curl -X POST http://192.168.1.100/api/v1/endpoints.php \
  -H "Content-Type: application/json" \
  -d '{"action":"player_control","action":"seek","value":30}'
```

### Gestion des playlists

#### GET /api/v1/endpoints.php?action=playlist

Récupère la playlist active.

**Réponse** :
```json
{
    "success": true,
    "data": {
        "name": "Playlist Principale",
        "active": true,
        "loop": true,
        "shuffle": false,
        "items": [
            {
                "type": "video",
                "filename": "presentation.mp4",
                "duration": 180,
                "order": 1
            },
            {
                "type": "image", 
                "filename": "logo.jpg",
                "duration": 10,
                "order": 2
            }
        ],
        "total_duration": 190,
        "created": "2024-09-18T08:00:00+02:00",
        "modified": "2024-09-18T10:30:00+02:00"
    },
    "message": "Playlist récupérée"
}
```

#### POST /api/v1/endpoints.php

Sauvegarde une nouvelle playlist.

**Paramètres** :
```json
{
    "action": "playlist",
    "name": "Nouvelle Playlist",
    "loop": true,
    "shuffle": false,
    "items": [
        {
            "type": "video",
            "filename": "video1.mp4",
            "duration": 60,
            "order": 1
        },
        {
            "type": "image",
            "filename": "image1.jpg", 
            "duration": 15,
            "order": 2
        }
    ]
}
```

### YouTube et médias externes

#### POST /api/v1/endpoints.php

Télécharge une vidéo depuis YouTube.

**Paramètres** :
```json
{
    "action": "youtube_download",
    "url": "https://www.youtube.com/watch?v=VIDEO_ID"
}
```

**Réponse** :
```json
{
    "success": true,
    "data": {
        "title": "Titre de la vidéo",
        "filename": "titre-video.mp4",
        "duration": 300,
        "size": 89456789
    },
    "message": "Vidéo YouTube téléchargée avec succès"
}
```

### Statistiques rapides

#### GET /api/v1/endpoints.php?action=stats

Récupère les statistiques essentielles pour dashboards.

**Réponse** :
```json
{
    "success": true,
    "data": {
        "cpu_percent": 15.2,
        "memory_percent": 45,
        "disk_percent": 27,
        "temperature": 42.5,
        "video_count": 12,
        "playlist_count": 3,
        "service_active": true,
        "disk_free": "23.5 GB"
    },
    "message": "Statistiques récupérées"
}
```

### Actions système avancées

#### POST /api/v1/endpoints.php

Redémarrage du système (authentification requise).

**Paramètres** :
```json
{
    "action": "system_reboot"
}
```

**Headers requis** :
```
Authorization: Bearer YOUR_TOKEN
```

## 📋 Modèles de données

### Objet Video

```typescript
interface Video {
    filename: string;           // Nom du fichier
    path: string;              // Chemin complet
    size: number;              // Taille en octets
    size_formatted: string;    // Taille formatée (ex: "156 MB")
    duration: number;          // Durée en secondes
    duration_formatted: string; // Durée formatée (ex: "3:00")
    resolution: string;        // Résolution (ex: "1920x1080")
    codec: string;             // Codec vidéo
    bitrate: string;           // Bitrate
    created: string;           // Date de création (ISO 8601)
    modified: string;          // Date de modification (ISO 8601)
}
```

### Objet Playlist

```typescript
interface Playlist {
    name: string;              // Nom de la playlist
    active: boolean;           // Playlist active ou non
    loop: boolean;             // Lecture en boucle
    shuffle: boolean;          // Lecture aléatoire
    items: PlaylistItem[];     // Liste des éléments
    total_duration: number;    // Durée totale en secondes
    created: string;           // Date de création
    modified: string;          // Date de modification
}

interface PlaylistItem {
    type: "video" | "image";   // Type de média
    filename: string;          // Nom du fichier
    duration: number;          // Durée d'affichage
    order: number;             // Ordre dans la playlist
}
```

### Objet SystemInfo

```typescript
interface SystemInfo {
    hostname: string;
    uptime: string;
    ip: string;
    version: string;
    mode: string;
    cpu_percent: number;
    memory: {
        total: string;
        used: string;
        free: string;
        percent: number;
    };
    disk: {
        total: string;
        used: string;
        free: string;
        percent: number;
    };
    temperature: number;
    gpu_memory: string;
}
```

## ⚠️ Codes d'erreur

### Erreurs métier

| Code | Message | Description |
|------|---------|-------------|
| 1001 | Service non trouvé | Service système inexistant |
| 1002 | Fichier non trouvé | Média inexistant |
| 1003 | Playlist invalide | Format de playlist incorrect |
| 1004 | Action non supportée | Action player non reconnue |
| 1005 | URL YouTube invalide | Format d'URL incorrect |

### Exemples de réponses d'erreur

```json
{
    "success": false,
    "data": null,
    "message": "Fichier non trouvé",
    "timestamp": "2024-09-18T14:30:15+02:00",
    "error_code": 1002
}
```

## 💡 Exemples d'utilisation

### Client JavaScript

```javascript
class PiSignageAPI {
    constructor(baseUrl) {
        this.baseUrl = baseUrl;
    }
    
    async request(action, method = 'GET', data = null) {
        const url = `${this.baseUrl}/api/v1/endpoints.php${method === 'GET' ? `?action=${action}` : ''}`;
        
        const options = {
            method,
            headers: {
                'Content-Type': 'application/json'
            }
        };
        
        if (data && method !== 'GET') {
            options.body = JSON.stringify({action, ...data});
        }
        
        const response = await fetch(url, options);
        return await response.json();
    }
    
    // Méthodes convenances
    async getSystemInfo() {
        return await this.request('system_info');
    }
    
    async getVideos() {
        return await this.request('videos');
    }
    
    async playVideo() {
        return await this.request('player_control', 'POST', {action: 'play'});
    }
    
    async pauseVideo() {
        return await this.request('player_control', 'POST', {action: 'pause'});
    }
    
    async setVolume(volume) {
        return await this.request('player_control', 'POST', {
            action: 'volume',
            value: volume
        });
    }
}

// Utilisation
const api = new PiSignageAPI('http://192.168.1.100');

// Récupérer informations système
api.getSystemInfo().then(response => {
    if (response.success) {
        console.log('CPU:', response.data.cpu_percent + '%');
        console.log('RAM:', response.data.memory.percent + '%');
    }
});

// Contrôler le player
api.playVideo();
api.setVolume(0.8);
```

### Client Python

```python
import requests
import json

class PiSignageAPI:
    def __init__(self, base_url):
        self.base_url = base_url
        self.session = requests.Session()
        
    def request(self, action, method='GET', data=None):
        url = f"{self.base_url}/api/v1/endpoints.php"
        
        if method == 'GET':
            params = {'action': action}
            response = self.session.get(url, params=params)
        else:
            payload = {'action': action}
            if data:
                payload.update(data)
            response = self.session.request(
                method, url, 
                json=payload,
                headers={'Content-Type': 'application/json'}
            )
            
        return response.json()
    
    def get_system_info(self):
        return self.request('system_info')
    
    def get_videos(self):
        return self.request('videos')
    
    def play(self):
        return self.request('player_control', 'POST', {'action': 'play'})
    
    def pause(self):
        return self.request('player_control', 'POST', {'action': 'pause'})
    
    def set_volume(self, volume):
        return self.request('player_control', 'POST', {
            'action': 'volume',
            'value': volume
        })

# Utilisation
api = PiSignageAPI('http://192.168.1.100')

# Informations système
info = api.get_system_info()
if info['success']:
    print(f"CPU: {info['data']['cpu_percent']}%")
    print(f"RAM: {info['data']['memory']['percent']}%")

# Contrôle du player
api.play()
api.set_volume(0.8)
```

### Client PHP

```php
<?php
class PiSignageAPI {
    private $baseUrl;
    
    public function __construct($baseUrl) {
        $this->baseUrl = $baseUrl;
    }
    
    private function request($action, $method = 'GET', $data = null) {
        $url = $this->baseUrl . '/api/v1/endpoints.php';
        
        $context = [
            'http' => [
                'method' => $method,
                'header' => 'Content-Type: application/json'
            ]
        ];
        
        if ($method === 'GET') {
            $url .= '?action=' . urlencode($action);
        } else {
            $payload = ['action' => $action];
            if ($data) {
                $payload = array_merge($payload, $data);
            }
            $context['http']['content'] = json_encode($payload);
        }
        
        $response = file_get_contents($url, false, stream_context_create($context));
        return json_decode($response, true);
    }
    
    public function getSystemInfo() {
        return $this->request('system_info');
    }
    
    public function play() {
        return $this->request('player_control', 'POST', ['action' => 'play']);
    }
    
    public function setVolume($volume) {
        return $this->request('player_control', 'POST', [
            'action' => 'volume',
            'value' => $volume
        ]);
    }
}

// Utilisation
$api = new PiSignageAPI('http://192.168.1.100');
$info = $api->getSystemInfo();

if ($info['success']) {
    echo "CPU: " . $info['data']['cpu_percent'] . "%\n";
    echo "RAM: " . $info['data']['memory']['percent'] . "%\n";
}
?>
```

### Client Bash

```bash
#!/bin/bash

PISIGNAGE_URL="http://192.168.1.100"
API_ENDPOINT="$PISIGNAGE_URL/api/v1/endpoints.php"

# Fonction helper pour requêtes GET
pisignage_get() {
    local action="$1"
    curl -s "$API_ENDPOINT?action=$action" | jq
}

# Fonction helper pour requêtes POST
pisignage_post() {
    local action="$1"
    local data="$2"
    curl -s -X POST "$API_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "$data" | jq
}

# Exemples d'utilisation
echo "=== Informations système ==="
pisignage_get "system_info" | jq '.data | {cpu_percent, memory, temperature}'

echo -e "\n=== Liste des vidéos ==="
pisignage_get "videos" | jq '.data[] | {filename, size_formatted, duration_formatted}'

echo -e "\n=== Contrôle du player ==="
pisignage_post "player_control" '{"action":"player_control","action":"play"}'
sleep 2
pisignage_post "player_control" '{"action":"player_control","action":"pause"}'

echo -e "\n=== Statistiques rapides ==="
pisignage_get "stats" | jq '.data'
```

## 🔗 Clients et SDKs

### Librairies officielles

- **JavaScript/TypeScript** : `pisignage-js-sdk`
- **Python** : `pisignage-python-sdk`
- **PHP** : `pisignage-php-sdk`

### Installation

```bash
# JavaScript (npm)
npm install pisignage-js-sdk

# Python (pip)
pip install pisignage-python-sdk

# PHP (composer)
composer require pisignage/php-sdk
```

### Intégrations tierces

- **Home Assistant** : Composant officiel
- **Node-RED** : Nodes PiSignage
- **Grafana** : Dashboard templates
- **Zapier** : Connecteur automatisé

## 🎣 Webhooks

### Configuration (v3.1+)

Les webhooks permettent de recevoir des notifications automatiques lors d'événements.

```json
{
    "webhooks": {
        "enabled": true,
        "endpoints": [
            {
                "url": "https://example.com/pisignage-webhook",
                "events": ["player.start", "player.stop", "system.error"],
                "secret": "webhook_secret_key"
            }
        ]
    }
}
```

### Événements disponibles

| Événement | Description | Payload |
|-----------|-------------|---------|
| `player.start` | Démarrage de lecture | `{video, timestamp}` |
| `player.stop` | Arrêt de lecture | `{reason, timestamp}` |
| `player.error` | Erreur de lecture | `{error, video, timestamp}` |
| `system.boot` | Démarrage système | `{uptime, timestamp}` |
| `system.error` | Erreur système | `{error, level, timestamp}` |
| `media.uploaded` | Nouveau média | `{filename, size, timestamp}` |
| `playlist.changed` | Changement playlist | `{old_playlist, new_playlist, timestamp}` |

### Exemple de payload webhook

```json
{
    "event": "player.start",
    "timestamp": "2024-09-18T14:30:15+02:00",
    "source": "pisignage-001",
    "data": {
        "video": "presentation.mp4",
        "duration": 180,
        "playlist": "Playlist Principale"
    },
    "signature": "sha256=hash_of_payload_with_secret"
}
```

---

*Cette documentation API complète vous permet d'intégrer PiSignage Desktop v3.0 dans vos applications et systèmes d'automatisation.*