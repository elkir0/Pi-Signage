# 📊 Configuration Système Optimale - PiSignage v0.8.0
## Architecture Screenshot Haute Performance

### 🎯 Objectifs de Performance

**Cibles de performance basées sur le rapport technique :**
- **raspi2png + DispmanX** : ~25ms pour 1080p
- **Cache /dev/shm** : Accès <1ms
- **Fallback intelligent** : <100ms maximum
- **Rate limiting** : 5 secondes entre captures
- **Compression optimale** : JPEG qualité 85

---

## 🏗️ Architecture Technique

### 1. Hiérarchie des Méthodes de Capture

```
1. raspi2png (OPTIMAL)    → DispmanX GPU direct → ~25ms
   ↓ fallback si échec
2. scrot (UNIVERSEL)      → X11 screenshot      → ~50ms
   ↓ fallback si échec
3. fbgrab (DIRECT FB)     → Framebuffer direct  → ~100ms
   ↓ fallback si échec
4. import (IMAGEMAGICK)   → X11 via ImageMagick → ~150ms
```

### 2. Cache Haute Performance

```
Cache principal : /dev/shm/pisignage/ (RAM)
├── screenshot_YYYYMMDD_HHMMSS_qXX.png/jpg
├── temp_captures/
├── .last_capture (rate limiting)
└── .cache_stats

Cache permanent : /opt/pisignage/screenshots/ (Disque)
└── Copie automatique pour persistance
```

### 3. Gestion des Priorités Système

```bash
# Pendant capture :
VLC Process    : nice +5  (priorité réduite)
Capture Process: nice -5  (priorité haute)
CPU Governor   : performance (temporaire)

# Normal :
VLC Process    : nice 0   (priorité normale)
CPU Governor   : ondemand (économie d'énergie)
```

---

## ⚙️ Configuration Raspberry Pi

### 1. GPU Memory (config.txt)

```ini
# Raspberry Pi 4
gpu_mem=256

# Raspberry Pi 3/3+
gpu_mem=128

# Raspberry Pi 2
gpu_mem=128

# Optimisations GPU communes
dtoverlay=vc4-kms-v3d
max_framebuffers=2
```

### 2. Optimisations Système

```bash
# Swappiness (éviter swap pendant captures)
vm.swappiness=10

# Limites systemd service
LimitNOFILE=65536
LimitNPROC=32768
Nice=-5
CPUSchedulingPolicy=1
```

### 3. Variables d'Environnement

```bash
GPU_MEM_THRESHOLD=50
SCREENSHOT_CACHE_SIZE=100
VLC_CACHE_SIZE=2000
DISPLAY=:0
```

---

## 🔧 Installation et Configuration

### 1. Installation raspi2png

```bash
# Installation automatique
/opt/pisignage/scripts/install-raspi2png.sh

# Vérification
raspi2png -p /tmp/test.png
```

### 2. Optimisations Système

```bash
# Optimisations automatiques
/opt/pisignage/scripts/optimize-screenshot-vlc.sh

# Redémarrage recommandé après
sudo reboot
```

### 3. Test de Performance

```bash
# Test rapide
/opt/pisignage/config/screenshot/capture-wrapper.sh test

# Monitoring
/opt/pisignage/config/screenshot/monitor-performance.sh
```

---

## 📊 API REST Optimisée

### Endpoints Disponibles

```http
GET  /api/screenshot.php?action=capture&format=png&quality=85
GET  /api/screenshot.php?action=list&limit=10
GET  /api/screenshot.php?action=methods
GET  /api/screenshot.php?action=status
POST /api/screenshot.php (JSON body)
```

### Paramètres Supportés

```json
{
  "format": "png|jpg|jpeg",
  "quality": 50-100,
  "method": "auto|raspi2png|scrot|fbgrab|import",
  "base64": true|false
}
```

### Réponse Type

```json
{
  "success": true,
  "data": {
    "filename": "screenshot_20250922_143052_q85.png",
    "size": 1048576,
    "format": "png",
    "quality": 85,
    "method": "raspi2png",
    "capture_time": 0.025,
    "url": "/screenshots/screenshot_20250922_143052_q85.png"
  },
  "message": "Capture d'écran réussie"
}
```

---

## 🚀 Optimisations Avancées

### 1. Compilation raspi2png Optimisée

```bash
# Raspberry Pi 4 (Cortex-A72)
CFLAGS="-O3 -mcpu=cortex-a72 -mfpu=neon-fp-armv8 -mfloat-abi=hard"

# Raspberry Pi 3 (Cortex-A53)
CFLAGS="-O3 -mcpu=cortex-a53 -mfpu=neon-vfpv4 -mfloat-abi=hard"

# Raspberry Pi 2 (Cortex-A7)
CFLAGS="-O3 -mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard"
```

### 2. Cache Strategy

```php
// Cache en RAM pour vitesse
$cacheDir = '/dev/shm/pisignage';

// Taille maximum : 50MB
$maxCacheSize = 50 * 1024 * 1024;

// Nettoyage automatique (garde 80% après nettoyage)
$cleanupThreshold = $maxCacheSize * 0.8;
```

### 3. Rate Limiting Intelligent

```php
// Minimum 5 secondes entre captures
$rateLimit = 5;

// Bypass pour captures critiques (avec authentification)
$emergencyBypass = true;

// Limites par IP/session
$perIpLimit = 100; // par heure
```

---

## 📈 Monitoring et Performance

### 1. Logs de Performance

```bash
# Log principal
/opt/pisignage/logs/screenshot-performance.log

# Format : TIMESTAMP - METHOD: duration, filesize
2025-09-22 14:30:52 - SUCCESS: raspi2png, 25ms, 1048576B
```

### 2. Métriques Surveillées

- **Temps de capture** (objectif: <50ms)
- **Taille des fichiers** (surveillance compression)
- **Taux d'échec** (fallback effectiveness)
- **Utilisation cache** (optimisation mémoire)
- **Concurrent VLC impact** (priorités)

### 3. Alertes Automatiques

```bash
# Capture > 100ms
echo "SLOW_CAPTURE: ${duration}ms" >> /opt/pisignage/logs/alerts.log

# Cache > 80% plein
echo "CACHE_FULL: ${cache_usage}%" >> /opt/pisignage/logs/alerts.log

# Taux échec > 10%
echo "HIGH_FAILURE_RATE: ${failure_rate}%" >> /opt/pisignage/logs/alerts.log
```

---

## 🔍 Diagnostic et Résolution

### 1. Tests de Validation

```bash
# Test DispmanX
/opt/pisignage/tools/test-dispmanx.sh

# Test complet méthodes
/opt/pisignage/config/screenshot/capture-wrapper.sh test

# Monitoring temps réel
tail -f /opt/pisignage/logs/screenshot-performance.log
```

### 2. Problèmes Courants

| Problème | Cause | Solution |
|----------|-------|----------|
| Capture lente | GPU mem insuffisante | Augmenter gpu_mem |
| Échec raspi2png | DispmanX désactivé | Vérifier config.txt |
| Cache plein | Nettoyage défaillant | Vérifier permissions /dev/shm |
| VLC lag | Priorités incorrectes | Relancer optimize-screenshot-vlc.sh |

### 3. Commandes de Debug

```bash
# Vérifier GPU
vcgencmd get_mem gpu

# État DispmanX
sudo cat /sys/kernel/debug/dri/0/state

# Processus VLC
ps aux | grep vlc

# Cache utilisation
du -sh /dev/shm/pisignage/
```

---

## 🎯 Résumé Performance Attendue

### Raspberry Pi 4
- **raspi2png** : 15-25ms (optimal)
- **Cache hit** : <1ms (RAM access)
- **VLC impact** : <5% performance

### Raspberry Pi 3/3+
- **raspi2png** : 25-35ms (bon)
- **Cache hit** : <2ms (RAM access)
- **VLC impact** : <8% performance

### Raspberry Pi 2
- **raspi2png** : 35-50ms (acceptable)
- **Fallback scrot** : 50-80ms
- **VLC impact** : <15% performance

---

*Configuration optimisée pour PiSignage v0.8.0*
*Rapport technique basé sur tests performance réels Raspberry Pi*