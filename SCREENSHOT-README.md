# PiSignage Screenshot System v0.8.0

## 📸 Vue d'ensemble

Le système de capture d'écran PiSignage v0.8.0 fournit une solution complète et optimisée pour les captures d'écran sur Raspberry Pi. Il combine l'accélération matérielle, des méthodes de fallback robustes, et une intégration transparente avec le système d'affichage.

## 🚀 Fonctionnalités principales

- **Accélération matérielle** avec raspi2png (accès GPU direct)
- **Méthodes de fallback multiples** (scrot, ImageMagick, fbgrab)
- **Captures automatiques** avec service systemd
- **Cache mémoire partagée** pour les performances
- **Configuration boot optimisée** pour Raspberry Pi
- **Sauvegarde et restauration** automatiques
- **Support Pi 3/4/5** avec détection automatique

## 📁 Structure des fichiers

```
/opt/pisignage/scripts/
├── install-screenshot.sh       # Installation complète du système
├── test-screenshot-install.sh  # Test de préparation à l'installation
├── screenshot-help.sh          # Documentation et aide complète
├── screenshot.sh               # Script de capture principal (amélioré)
└── optimize-screenshot-vlc.sh  # Optimisation VLC (généré automatiquement)

/opt/pisignage/
├── screenshots/                # Stockage des captures
├── logs/screenshot*.log        # Logs d'installation et runtime
└── backup/screenshot-install-* # Sauvegardes automatiques
```

## 🔧 Installation rapide

### 1. Test de préparation
```bash
/opt/pisignage/scripts/test-screenshot-install.sh
```

### 2. Installation complète
```bash
sudo /opt/pisignage/scripts/install-screenshot.sh
```

### 3. Redémarrage requis
```bash
sudo reboot
```

### 4. Validation
```bash
/opt/pisignage/scripts/screenshot.sh status
/opt/pisignage/scripts/screenshot.sh auto
```

## 📖 Documentation complète

Pour accéder à l'aide complète :
```bash
/opt/pisignage/scripts/screenshot-help.sh
```

Sujets d'aide disponibles :
- `overview` - Vue d'ensemble du système
- `installation` - Guide d'installation détaillé
- `usage` - Utilisation des commandes
- `troubleshooting` - Résolution de problèmes
- `api` - Intégration API
- `performance` - Optimisation des performances
- `configuration` - Fichiers de configuration
- `maintenance` - Maintenance et sauvegarde

## ⚡ Utilisation rapide

### Captures manuelles
```bash
# Capture automatique (méthode optimale)
/opt/pisignage/scripts/screenshot.sh auto

# Capture avec nom personnalisé
/opt/pisignage/scripts/screenshot.sh auto mon-screenshot.png

# Statut du système
/opt/pisignage/scripts/screenshot.sh status
```

### Service automatique
```bash
# Démarrer les captures automatiques (toutes les 5 minutes)
sudo systemctl start pisignage-screenshot.timer

# Vérifier le statut
systemctl status pisignage-screenshot.timer

# Logs du service
journalctl -u pisignage-screenshot.service
```

## 🔍 Méthodes de capture

### 1. raspi2png (Recommandé)
- **Avantages** : Accélération GPU, très rapide, faible CPU
- **Requis** : GPU memory ≥128MB, compilation depuis source
- **Usage** : Production, captures fréquentes

### 2. scrot
- **Avantages** : Rapide, bien testé, qualité excellente
- **Requis** : Session X11 active
- **Usage** : Développement, bureau

### 3. ImageMagick (import)
- **Avantages** : Qualité maximale, fonctionnalités avancées
- **Requis** : X11, plus de mémoire
- **Usage** : Captures de haute qualité

### 4. fbgrab
- **Avantages** : Fonctionne sans X11, accès framebuffer direct
- **Requis** : Accès /dev/fb0
- **Usage** : Serveur headless, fallback

## ⚙️ Configuration automatique

L'installation configure automatiquement :

### /boot/config.txt
```
gpu_mem=256                    # Mémoire GPU optimisée
dtoverlay=vc4-fkms-v3d        # Driver d'affichage (Pi 4/5)
start_x=1                     # Interface caméra
```

### Service systemd
- Timer automatique toutes les 5 minutes
- Service `pisignage-screenshot.timer`
- Logs dans journalctl

### Cache mémoire partagée
- Répertoire `/dev/shm/pisignage`
- Captures temporaires en RAM
- Performances optimisées

## 🛠️ Résolution de problèmes

### Problèmes courants

**Aucune méthode disponible :**
```bash
sudo /opt/pisignage/scripts/install-screenshot.sh
```

**raspi2png ne fonctionne pas :**
```bash
vcgencmd get_mem gpu  # Vérifier mémoire GPU
sudo reboot          # Redémarrer après config boot
```

**Erreurs de permissions :**
```bash
sudo chown -R pi:pi /opt/pisignage/screenshots
```

**Service automatique inactif :**
```bash
sudo systemctl restart pisignage-screenshot.timer
journalctl -u pisignage-screenshot.service
```

### Logs et diagnostics
- Installation : `/opt/pisignage/logs/screenshot-install.log`
- Runtime : `/opt/pisignage/logs/screenshot.log`
- Service : `journalctl -u pisignage-screenshot.service`

## 📊 Performances

### Comparaison des méthodes

| Méthode | Vitesse | Qualité | CPU | Mémoire | Prérequis |
|---------|---------|---------|-----|---------|-----------|
| raspi2png | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | GPU mem |
| scrot | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | X11 |
| import | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | X11, RAM |
| fbgrab | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | /dev/fb0 |

### Optimisations
- Cache SHM pour réduire I/O disque
- GPU memory 256MB pour raspi2png
- Nettoyage automatique (garde 50 captures)
- Driver d'affichage optimisé

## 🔄 Sauvegarde et restauration

### Sauvegarde automatique
L'installation crée automatiquement :
- Sauvegarde de `/boot/config.txt`
- Sauvegarde du script existant
- Script de restauration

### Restauration manuelle
```bash
# Trouver le répertoire de sauvegarde
ls /opt/pisignage/backup/screenshot-install-*

# Exécuter la restauration
bash /opt/pisignage/backup/screenshot-install-YYYYMMDD-HHMMSS/restore.sh
```

## 🔗 Intégration API

### Endpoints disponibles
- `GET /api/screenshot.php` - Récupérer dernière capture
- `POST /api/screenshot.php` - Déclencher nouvelle capture

### Exemples d'utilisation
```bash
# Récupérer dernière capture
curl http://localhost/api/screenshot.php

# Nouvelle capture
curl -X POST http://localhost/api/screenshot.php

# Méthode spécifique
curl -X POST http://localhost/api/screenshot.php -d 'method=raspi2png'
```

## 📋 Maintenance

### Tâches régulières
- **Hebdomadaire** : Vérifier logs, nettoyer captures anciennes
- **Mensuelle** : Mettre à jour système, vérifier espace disque
- **Au besoin** : Recompiler raspi2png, ajuster intervalles

### Commandes de maintenance
```bash
# Nettoyage des captures
/opt/pisignage/scripts/screenshot.sh cleanup

# Statut complet
/opt/pisignage/scripts/screenshot.sh status

# Sauvegarde des captures
tar -czf screenshots-backup.tar.gz /opt/pisignage/screenshots
```

## 🆘 Support et aide

### Aide intégrée
```bash
# Menu d'aide principal
/opt/pisignage/scripts/screenshot-help.sh

# Aide spécifique
/opt/pisignage/scripts/screenshot-help.sh troubleshooting
```

### Fichiers de logs
- `/opt/pisignage/logs/screenshot-install.log`
- `/opt/pisignage/logs/screenshot.log`
- `journalctl -u pisignage-screenshot.service`

### Test de diagnostic
```bash
/opt/pisignage/scripts/test-screenshot-install.sh
```

---

**PiSignage v0.8.0** - Système de capture d'écran optimisé pour Raspberry Pi
Documentation complète : `/opt/pisignage/scripts/screenshot-help.sh all`