# 🚀 PiSignage v0.8.1 GOLDEN - Installation ONE-CLICK

**Le script d'installation parfait pour déployer PiSignage en quelques minutes sur Raspberry Pi !**

---

## ⚡ Installation Ultra-Rapide

### Option 1: Installation Directe (Recommandée)
```bash
curl -sSL https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install-pisignage-v0.8.1-golden.sh | sudo bash
```

### Option 2: Installation avec Script Local
```bash
# Si vous avez déjà cloné le repository
cd /opt/pisignage
sudo ./install-pisignage-v0.8.1-golden.sh
```

### Option 3: Quick Install avec Téléchargement
```bash
sudo ./quick-install.sh
```

---

## 🎯 Ce que Vous Obtenez

### Interface Web Glassmorphisme (9 Sections)
- **Dashboard** - Vue d'ensemble du système
- **Médias** - Gestion complète des fichiers
- **Playlists** - Création et édition avancées
- **Planification** - Programmation horaire intelligente
- **Player** - Contrôle en temps réel
- **Système** - Monitoring complet (CPU, RAM, T°)
- **Réseau** - Configuration IP/Wi-Fi
- **Affichage** - Résolution, rotation, calibration
- **Paramètres** - Configuration générale

### Stack Technique Complète
- **PHP 8.2** + **Nginx** (serveur web optimisé)
- **MPV** + **VLC** (dual-player avec basculement automatique)
- **Accélération matérielle** (V4L2, DRM, GPU)
- **Support multi-environnement** (Wayland/X11/DRM)
- **Base SQLite** intégrée
- **API REST** complète
- **Services systemd** avec auto-démarrage

### Fonctionnalités Avancées
- **Upload jusqu'à 500MB** par fichier
- **Capture d'écran automatique** toutes les 30s
- **Monitoring temps réel** système
- **Interface responsive** (mobile/tablette/desktop)
- **Mode kiosk** automatique
- **Gestion intelligente des erreurs**

---

## 📋 Prérequis

- **Raspberry Pi 3/4/5** avec Raspberry Pi OS Bookworm
- **Connexion Internet** stable
- **Carte SD 16GB+** (32GB recommandé)
- **Accès sudo** sur le système

---

## 🔧 Installation Détaillée

### Étape 1: Vérifications Automatiques
Le script vérifie automatiquement :
- Permissions sudo
- Version de l'OS (optimisé Bookworm)
- Modèle de Raspberry Pi
- Connexion Internet
- Espace disque disponible

### Étape 2: Backup Automatique
- Sauvegarde des installations existantes
- Backup des configurations Nginx/PHP
- Conservation des médias existants

### Étape 3: Installation des Paquets
**Serveur Web:**
- nginx
- php8.2 + extensions (fpm, sqlite3, gd, curl, etc.)

**Lecteurs Vidéo:**
- mpv (avec accélération HW)
- vlc (mode fallback)
- ffmpeg (avec support V4L2)

**Accélération Matérielle:**
- raspberrypi-ffmpeg
- mesa-va-drivers
- v4l-utils

**Support Affichage:**
- seatd (Wayland)
- libdrm2 (DRM direct)
- wlr-randr (gestion multi-écrans)

### Étape 4: Déploiement du Code
- Clone automatique depuis GitHub
- Création de la structure de répertoires
- Configuration des permissions (www-data, video, render)
- Installation des services systemd

### Étape 5: Configuration Web
- Site Nginx optimisé (cache, gros fichiers)
- PHP 8.2 configuré pour uploads 500MB
- Base SQLite initialisée
- API REST opérationnelle

### Étape 6: Tests de Validation
- Vérification des services
- Test des lecteurs vidéo
- Validation de l'interface web
- Test des permissions
- Rapport de succès complet

---

## 🌐 Accès Post-Installation

### Interface Web
- **Local:** http://localhost/
- **Réseau:** http://[IP_du_Pi]/
- **Hostname:** http://raspberrypi.local/

### Commandes de Contrôle
```bash
# Démarrage
sudo systemctl start pisignage

# Arrêt
sudo systemctl stop pisignage

# Status
sudo systemctl status pisignage

# Logs temps réel
sudo journalctl -f -u pisignage

# Script de démarrage rapide
cd /opt/pisignage && ./start-pisignage.sh

# Validation post-installation
cd /opt/pisignage && ./validate-installation.sh
```

---

## 📂 Structure des Fichiers

```
/opt/pisignage/
├── 🌐 web/                              # Interface web PHP
│   ├── index.php                       # Page principale (9 sections)
│   ├── config.php                      # Configuration système
│   └── api/                            # API REST endpoints
├── 🎬 media/                            # Fichiers médias utilisateur
├── 📤 uploads/                          # Zone d'upload web
├── 🔧 scripts/                          # Scripts de contrôle
│   ├── player-manager.sh               # Gestionnaire MPV/VLC intelligent
│   ├── display-monitor.sh              # Monitoring système
│   └── ...
├── ⚙️  config/                          # Configurations
│   ├── mpv/mpv.conf                    # Config MPV optimisée Pi
│   ├── vlc/vlcrc                       # Config VLC fallback
│   └── systemd/                        # Services systemd
├── 📊 logs/                             # Fichiers de log
├── 📸 screenshots/                      # Captures d'écran auto
├── 🚀 install-pisignage-v0.8.1-golden.sh # Installeur principal
├── ⚡ quick-install.sh                   # Installation rapide
├── ✅ validate-installation.sh          # Validation post-install
└── 📖 README-INSTALLATION.md           # Ce fichier
```

---

## 🔍 Validation de l'Installation

Après l'installation, validez que tout fonctionne :

```bash
cd /opt/pisignage
./validate-installation.sh
```

Ce script teste automatiquement :
- ✅ Services système (Nginx, PHP-FPM, seatd)
- ✅ Fichiers critiques présents
- ✅ Permissions correctes
- ✅ Lecteurs vidéo fonctionnels
- ✅ Interface web accessible
- ✅ Configuration réseau
- ✅ Performance système

---

## 🚨 Résolution de Problèmes

### Interface Web Inaccessible
```bash
sudo systemctl status nginx php8.2-fpm
sudo tail -f /var/log/nginx/pisignage_error.log
```

### Lecteur Vidéo Ne Démarre Pas
```bash
cd /opt/pisignage
./scripts/player-manager.sh test
tail -f logs/mpv.log
```

### Problèmes d'Upload
```bash
sudo chown -R www-data:www-data /opt/pisignage/uploads/
sudo chmod 775 /opt/pisignage/uploads/
```

### Réinstallation Complète
```bash
# L'installation est idempotente - relancez simplement
sudo ./install-pisignage-v0.8.1-golden.sh
```

---

## 📈 Monitoring et Logs

### Logs Principaux
- **Installation:** `/var/log/pisignage-install.log`
- **Nginx:** `/var/log/nginx/pisignage_*.log`
- **PHP:** `/opt/pisignage/logs/php_errors.log`
- **MPV:** `/opt/pisignage/logs/mpv.log`
- **Système:** `sudo journalctl -u pisignage`

### Monitoring Temps Réel
L'interface web affiche en permanence :
- Utilisation CPU/RAM/Température
- Status des lecteurs vidéo
- Espace disque disponible
- Connexion réseau
- Médias en cours de lecture

---

## 🎉 Fonctionnalités Uniques

### Gestionnaire de Lecteur Intelligent
- **Auto-détection** de l'environnement (Wayland/X11/DRM)
- **Basculement automatique** MPV ↔ VLC en cas d'erreur
- **Accélération matérielle** optimisée par modèle de Pi
- **Support multi-format** (MP4, AVI, MKV, WebM, etc.)

### Interface Glassmorphisme Responsive
- **Design moderne** avec effets de transparence
- **9 sections intuitives** pour gestion complète
- **Adaptation automatique** mobile/tablette/desktop
- **Temps réel** pour tous les contrôles

### Installation Bulletproof
- **Backup automatique** avant installation
- **Tests de validation** complets
- **Gestion d'erreurs** robuste
- **Installation idempotente** (peut être relancée)

---

## 📞 Support

### Auto-Diagnostic
```bash
# Validation complète automatique
./validate-installation.sh

# Test des lecteurs vidéo
./scripts/player-manager.sh test

# Vérification de l'environnement
./scripts/player-manager.sh env
```

### Mise à Jour
Pour mettre à jour vers une nouvelle version, relancez simplement l'installation :
```bash
sudo ./install-pisignage-v0.8.1-golden.sh
```

Vos configurations et médias seront automatiquement préservés !

---

**🎊 Félicitations ! Vous disposez maintenant du système d'affichage dynamique le plus avancé pour Raspberry Pi !**

*PiSignage v0.8.1 GOLDEN - L'excellence de l'affichage numérique à portée de clic.*