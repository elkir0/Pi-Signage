# PiSignage v0.8.1 GOLDEN - Instructions d'Installation ONE-CLICK

## 🚀 Installation Ultra-Rapide

### Prérequis
- Raspberry Pi 3/4/5 avec Raspberry Pi OS Bookworm
- Connexion Internet
- Accès sudo

### Installation en Une Seule Commande

```bash
# Téléchargement et installation directe depuis GitHub
curl -sSL https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install-pisignage-v0.8.1-golden.sh | sudo bash

# OU si vous avez déjà cloné le repository
cd /opt/pisignage
sudo ./install-pisignage-v0.8.1-golden.sh
```

## 🎯 Ce que fait le script automatiquement

### 1. Vérifications Système
- ✅ Détection Raspberry Pi OS Bookworm
- ✅ Vérification des permissions sudo
- ✅ Test de la connexion Internet
- ✅ Détection du modèle de Pi (optimisation HW)

### 2. Installation des Composants
- ✅ **PHP 8.2 + Nginx** (serveur web optimisé)
- ✅ **MPV + VLC** (lecteurs vidéo dual avec accélération HW)
- ✅ **Support Wayland/X11/DRM** (tous environnements graphiques)
- ✅ **Accélération matérielle** (V4L2, DRM, Mesa)
- ✅ **Outils système** (ffmpeg, v4l-utils, etc.)

### 3. Déploiement Automatique
- ✅ Clone depuis GitHub vers `/opt/pisignage/`
- ✅ Configuration des permissions (www-data, video, render)
- ✅ Création de la structure de répertoires
- ✅ Backup automatique des installations existantes

### 4. Configuration Web
- ✅ **Interface glassmorphisme** (9 sections validées)
- ✅ Configuration Nginx optimisée (gros fichiers, cache)
- ✅ PHP 8.2 configuré (500MB uploads, 5min timeout)
- ✅ Base de données SQLite intégrée
- ✅ API REST pour contrôle à distance

### 5. Services Systemd
- ✅ Service principal `pisignage.service`
- ✅ Monitoring système `pisignage-monitor.service`
- ✅ Capture d'écran automatique (timer)
- ✅ Démarrage automatique au boot

### 6. Tests de Validation
- ✅ Vérification des services
- ✅ Test des permissions
- ✅ Test des lecteurs vidéo
- ✅ Test de l'interface web
- ✅ Rapport de succès complet

## 🌐 Accès après Installation

### Interface Web
- **Local:** http://localhost/
- **Réseau:** http://[IP_du_Pi]/
- **mDNS:** http://pisignage.local/ (si configuré)

### Sections Disponibles
1. **Dashboard** - Vue d'ensemble système
2. **Médias** - Gestion des fichiers (images, vidéos)
3. **Playlists** - Création et édition des séquences
4. **Planification** - Programmation horaire
5. **Player** - Contrôle de lecture en temps réel
6. **Système** - Monitoring (CPU, RAM, température)
7. **Réseau** - Configuration IP, Wi-Fi
8. **Affichage** - Résolution, rotation, calibration
9. **Paramètres** - Configuration générale

## 🎮 Contrôle des Services

### Commandes Principales
```bash
# Démarrage
sudo systemctl start pisignage.service

# Arrêt
sudo systemctl stop pisignage.service

# Redémarrage
sudo systemctl restart pisignage.service

# Statut
sudo systemctl status pisignage.service

# Logs en temps réel
sudo journalctl -f -u pisignage.service
```

### Script de Démarrage Rapide
```bash
cd /opt/pisignage
./start-pisignage.sh
```

## 📂 Structure des Répertoires

```
/opt/pisignage/
├── web/                    # Interface web PHP
│   ├── index.php          # Page principale
│   ├── config.php         # Configuration
│   └── api/               # API REST
├── media/                 # Fichiers médias
├── uploads/               # Zone d'upload web
├── scripts/               # Scripts de contrôle
│   ├── player-manager.sh  # Gestionnaire MPV/VLC
│   └── display-monitor.sh # Monitoring
├── config/                # Configurations
│   ├── mpv/              # Config MPV
│   └── vlc/              # Config VLC
├── logs/                  # Fichiers de log
└── screenshots/           # Captures d'écran
```

## 🔧 Fonctionnalités Avancées

### Lecteurs Vidéo Intelligents
- **MPV Primary:** Accélération HW optimale
- **VLC Fallback:** Compatibilité maximale
- **Auto-switch:** Basculement automatique si erreur
- **Support formats:** MP4, AVI, MKV, MOV, WebM, etc.

### Interface Adaptative
- **Responsive Design:** Tablette, smartphone, desktop
- **Glassmorphisme:** Design moderne et élégant
- **Dark/Light Mode:** Adaptation automatique
- **Multi-langue:** Français/Anglais

### Monitoring Temps Réel
- **Statut système:** CPU, RAM, température
- **Statut réseau:** IP, débit, latence
- **Statut player:** Fichier en cours, position
- **Screenshots:** Capture périodique de l'écran

## 🚨 Résolution de Problèmes

### Problèmes Courants

**Interface web inaccessible :**
```bash
sudo systemctl status nginx php8.2-fpm
sudo tail -f /var/log/nginx/pisignage_error.log
```

**Lecteur vidéo ne démarre pas :**
```bash
cd /opt/pisignage
./scripts/player-manager.sh test
tail -f logs/mpv.log
```

**Permissions d'upload :**
```bash
sudo chown -R www-data:www-data /opt/pisignage/uploads/
sudo chmod 775 /opt/pisignage/uploads/
```

### Logs Utiles
- **Installation:** `/var/log/pisignage-install.log`
- **Nginx:** `/var/log/nginx/pisignage_*.log`
- **PHP:** `/opt/pisignage/logs/php_errors.log`
- **MPV:** `/opt/pisignage/logs/mpv.log`
- **VLC:** `/opt/pisignage/logs/vlc.log`

## 📞 Support

### Vérifications Post-Installation
Le script effectue automatiquement tous les tests nécessaires et affiche un rapport détaillé. En cas de problème, consultez les logs spécifiés dans le rapport.

### Mise à Jour
Pour mettre à jour PiSignage, relancez simplement le script d'installation. Vos configurations et médias seront automatiquement sauvegardés.

---

**🎉 Profitez de votre affichage dynamique PiSignage v0.8.1 GOLDEN !**