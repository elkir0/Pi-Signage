# API Screenshot - PiSignage v0.8.0

## Vue d'ensemble

L'API Screenshot de PiSignage v0.8.0 fournit une solution robuste et optimisée pour la capture d'écran sur Raspberry Pi. Elle détecte automatiquement la meilleure méthode disponible et offre des fonctionnalités avancées comme le cache en RAM, le rate limiting, et la conversion de format.

## Méthodes de capture supportées

### 1. raspi2png (Recommandée pour Raspberry Pi)
- **Performance** : ~25ms pour du 1080p
- **Qualité** : Excellente (capture GPU directe)
- **Pré-requis** : gpio_mem=128 dans /boot/config.txt
- **Installation** : Via script `install_screenshot_tools.sh`

### 2. scrot
- **Performance** : Rapide
- **Qualité** : Bonne
- **Pré-requis** : Serveur X11 actif
- **Installation** : `apt install scrot`

### 3. fbgrab
- **Performance** : Moyenne
- **Qualité** : Bonne
- **Pré-requis** : Accès au framebuffer
- **Installation** : `apt install fbgrab`

### 4. ImageMagick import
- **Performance** : Lente mais fiable
- **Qualité** : Excellente
- **Pré-requis** : Serveur X11 actif
- **Installation** : `apt install imagemagick`

## Endpoints

### GET /api/screenshot.php

#### Paramètres

| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `action` | string | `capture` | Action à exécuter |
| `format` | string | `png` | Format de sortie (`png`, `jpg`, `jpeg`) |
| `quality` | int | `85` | Qualité JPEG (50-100) |
| `method` | string | `auto` | Méthode forcée (`auto`, `raspi2png`, `scrot`, `fbgrab`, `import`) |
| `base64` | bool | `false` | Retourner l'image en base64 |
| `limit` | int | `10` | Limite pour action `list` |

#### Actions disponibles

##### `capture` - Capture d'écran
```bash
# Capture basique
curl 'http://localhost/api/screenshot.php?action=capture'

# Capture JPEG qualité 70
curl 'http://localhost/api/screenshot.php?action=capture&format=jpg&quality=70'

# Capture avec méthode forcée
curl 'http://localhost/api/screenshot.php?action=capture&method=scrot'

# Capture avec retour base64
curl 'http://localhost/api/screenshot.php?action=capture&base64=true'
```

**Réponse succès :**
```json
{
  "success": true,
  "data": {
    "filename": "screenshot_20250922151530_q85.png",
    "size": 245760,
    "format": "png",
    "quality": 85,
    "method": "raspi2png",
    "capture_time": 0.025,
    "url": "/screenshots/screenshot_20250922151530_q85.png",
    "base64": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..." // si demandé
  },
  "message": "Capture d'écran réussie",
  "timestamp": "2025-09-22 15:15:30"
}
```

**Réponse échec (rate limiting) :**
```json
{
  "success": false,
  "error": "Rate limit exceeded",
  "message": "Veuillez attendre 3 secondes avant la prochaine capture",
  "retry_after": 3,
  "timestamp": "2025-09-22 15:15:30"
}
```

##### `list` - Liste des captures récentes
```bash
curl 'http://localhost/api/screenshot.php?action=list&limit=5'
```

**Réponse :**
```json
{
  "success": true,
  "data": [
    {
      "filename": "screenshot_20250922151530.png",
      "size": 245760,
      "created": 1695379530,
      "url": "/screenshots/screenshot_20250922151530.png"
    }
  ],
  "message": "Liste des 5 dernières captures",
  "timestamp": "2025-09-22 15:15:30"
}
```

##### `methods` - Méthodes disponibles
```bash
curl 'http://localhost/api/screenshot.php?action=methods'
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "raspi2png": {
      "name": "raspi2png",
      "description": "Capture GPU optimisée Raspberry Pi",
      "speed": "Très rapide (~25ms)",
      "quality": "Excellente",
      "recommended": true
    },
    "scrot": {
      "name": "scrot",
      "description": "Capture X11 universelle",
      "speed": "Rapide",
      "quality": "Bonne",
      "recommended": false
    }
  },
  "message": "Méthodes de capture disponibles",
  "timestamp": "2025-09-22 15:15:30"
}
```

##### `status` - Configuration API
```bash
curl 'http://localhost/api/screenshot.php?action=status'
```

**Réponse :**
```json
{
  "success": true,
  "data": {
    "available_methods": { /* ... */ },
    "rate_limit_seconds": 5,
    "cache_dir": "/dev/shm/pisignage",
    "quality_range": [50, 100],
    "supported_formats": ["png", "jpg", "jpeg"]
  },
  "message": "Configuration de l'API screenshot",
  "timestamp": "2025-09-22 15:15:30"
}
```

### POST /api/screenshot.php

Même fonctionnalité que GET mais avec paramètres dans le body JSON.

```bash
curl -X POST 'http://localhost/api/screenshot.php' \
  -H 'Content-Type: application/json' \
  -d '{
    "format": "jpg",
    "quality": 80,
    "method": "auto",
    "base64": false
  }'
```

## Fonctionnalités avancées

### Cache en RAM
- **Localisation** : `/dev/shm/pisignage`
- **Taille max** : 50MB
- **Nettoyage** : Automatique (supprime les plus anciens)
- **Fallback** : Disque si /dev/shm indisponible

### Rate Limiting
- **Limite** : 5 secondes minimum entre captures
- **Stockage** : Fichier `.last_capture` dans le cache
- **Comportement** : Retourne `retry_after` en cas de dépassement

### Gestion d'erreurs
- **Fallback** : Teste toutes les méthodes disponibles
- **Logging** : Via `logMessage()` de config.php
- **Validation** : Vérification taille fichier > 0

### Optimisations Raspberry Pi
- **raspi2png** : Capture GPU directe sans X11
- **Permissions** : www-data dans groupe video
- **GPU** : Configuration automatique gpu_mem=128

## Installation

### Installation automatique
```bash
sudo /opt/pisignage/install_screenshot_tools.sh
```

### Installation manuelle
```bash
# Outils de base
sudo apt update
sudo apt install scrot imagemagick fbgrab

# raspi2png pour Raspberry Pi
git clone https://github.com/AndrewFromMelbourne/raspi2png.git
cd raspi2png && make && sudo cp raspi2png /usr/local/bin/

# Configuration GPU (Raspberry Pi)
echo "gpu_mem=128" | sudo tee -a /boot/config.txt

# Permissions
sudo usermod -a -G video www-data
sudo mkdir -p /dev/shm/pisignage
sudo chown www-data:www-data /dev/shm/pisignage
```

## Tests

### Test rapide
```bash
php /opt/pisignage/test_screenshot_api.php
```

### Test en conditions réelles
```bash
# Test capture
curl 'http://localhost/api/screenshot.php?action=capture&format=png'

# Test rate limiting
curl 'http://localhost/api/screenshot.php?action=capture'
curl 'http://localhost/api/screenshot.php?action=capture'  # Doit échouer

# Test méthodes
curl 'http://localhost/api/screenshot.php?action=methods'
```

### Test performance
```bash
# Mesure du temps de capture
time curl -s 'http://localhost/api/screenshot.php?action=capture&format=png' > /dev/null
```

## Intégration JavaScript

```javascript
// Capture simple
async function takeScreenshot() {
  const response = await fetch('/api/screenshot.php?action=capture&format=png');
  const result = await response.json();

  if (result.success) {
    console.log('Capture réussie:', result.data.url);
    // Afficher l'image
    document.getElementById('preview').src = result.data.url;
  } else {
    console.error('Erreur:', result.message);
  }
}

// Capture avec base64 pour affichage immédiat
async function takeScreenshotBase64() {
  const response = await fetch('/api/screenshot.php?action=capture&base64=true');
  const result = await response.json();

  if (result.success) {
    document.getElementById('preview').src = result.data.base64;
  }
}

// Gestion du rate limiting
async function takeScreenshotWithRetry() {
  try {
    const response = await fetch('/api/screenshot.php?action=capture');
    const result = await response.json();

    if (!result.success && result.retry_after) {
      console.log(`Rate limit, retry dans ${result.retry_after}s`);
      setTimeout(takeScreenshotWithRetry, result.retry_after * 1000);
      return;
    }

    return result;
  } catch (error) {
    console.error('Erreur réseau:', error);
  }
}
```

## Dépannage

### Erreurs communes

#### "Aucune méthode de capture disponible"
- Installer les outils : `sudo /opt/pisignage/install_screenshot_tools.sh`
- Vérifier X11 : `echo $DISPLAY`
- Vérifier permissions : `groups www-data`

#### "Rate limit exceeded"
- Attendre 5 secondes entre captures
- Modifier `SCREENSHOT_RATE_LIMIT` dans screenshot.php si nécessaire

#### "Permission denied" sur framebuffer
- Ajouter www-data au groupe video : `sudo usermod -a -G video www-data`
- Redémarrer nginx/php-fpm

#### raspi2png ne fonctionne pas
- Vérifier gpu_mem : `vcgencmd get_mem gpu`
- Augmenter si < 128MB : `echo "gpu_mem=128" | sudo tee -a /boot/config.txt`
- Redémarrer le Pi

### Logs
```bash
# Logs de l'API
tail -f /opt/pisignage/logs/pisignage.log

# Logs nginx
tail -f /var/log/nginx/error.log

# Test manuel des outils
raspi2png -p /tmp/test.png
scrot /tmp/test.png
fbgrab /tmp/test.png
```

## Performance

### Benchmarks typiques (Raspberry Pi 4)

| Méthode | Résolution | Temps moyen | Taille fichier |
|---------|------------|-------------|----------------|
| raspi2png | 1920x1080 | 25ms | 1.2MB (PNG) |
| scrot | 1920x1080 | 150ms | 1.8MB (PNG) |
| fbgrab | 1920x1080 | 300ms | 1.2MB (PNG) |
| import | 1920x1080 | 500ms | 1.1MB (PNG) |

### Optimisations recommandées
- Utiliser raspi2png sur Raspberry Pi
- Format JPEG pour taille réduite
- Qualité 75-85 pour bon compromis
- Cache en /dev/shm pour I/O rapides
- Rate limiting à 3-5 secondes minimum

---

**PiSignage v0.8.0** - API Screenshot
*Optimisée pour Raspberry Pi - Performance et fiabilité*