# 📺 Pi Signage Digital - Version 2.3.0

**Solution complète de digital signage pour Raspberry Pi avec interface web de gestion**

[![Compatible](https://img.shields.io/badge/Compatible-Pi%203B%2B%20%7C%204B%20%7C%205-green.svg)](https://www.raspberrypi.org/)
[![Version](https://img.shields.io/badge/Version-2.3.0-blue.svg)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)]()
[![Security](https://img.shields.io/badge/Security-Enhanced-brightgreen.svg)]()

## 🎯 Présentation

Pi Signage Digital est une solution clé en main pour transformer vos Raspberry Pi en système d'affichage dynamique professionnel. Conçu pour remplacer des solutions commerciales comme Yodeck, ce système offre :

- ✅ **Deux modes d'affichage** : VLC Classic ou Chromium Kiosk
- ✅ **Interface web complète** : Upload, gestion vidéos, paramètres système
- ✅ **Synchronisation automatique** depuis Google Drive
- ✅ **Support VM/Headless** : Tests avec Xvfb
- ✅ **Monitoring web** avec interface Glances sécurisée
- ✅ **Installation automatisée** en modules indépendants
- ✅ **Maintenance automatique** et récupération d'urgence
- ✅ **Sécurité renforcée** : SHA-512, CSRF, permissions strictes

## 🏗️ Architecture Modulaire

### Modules d'Installation

| Module | Fonction | Durée |
|--------|----------|-------|
| **00-Security** | Module de sécurité centralisé | 1 min |
| **01-System** | Configuration système stable | 5 min |
| **02-Display** | X11 + LightDM + Openbox (VLC uniquement) | 10 min |
| **03-VLC/Chromium** | Lecteur vidéo ou navigateur kiosk | 8 min |
| **04-rclone** | Synchronisation Google Drive | 5 min |
| **05-Glances** | Monitoring web sécurisé | 7 min |
| **06-Watchdog** | Surveillance et récupération | 3 min |
| **07-Services** | Services systemd | 5 min |
| **08-Backup** | Système de sauvegarde | 5 min |
| **09-Web Interface** | Interface de gestion PHP/nginx | 10 min |
| **10-Final Check** | Vérification finale | 3 min |

**Durée totale d'installation : ~60 minutes**

### Services Créés

```
pi-signage.target                # Target principal groupant tous les services
├── lightdm.service             # Gestionnaire d'affichage (mode VLC)
├── vlc-signage.service         # Lecteur VLC en mode kiosque
├── chromium-kiosk.service      # Navigateur Chromium (mode kiosk)
├── nginx.service               # Serveur web pour interface
├── php8.2-fpm.service          # PHP pour interface web
├── glances.service             # Interface web de monitoring
└── pi-signage-watchdog.service # Surveillance et récupération automatique
```

## 🔧 Installation

### Prérequis

**Matériel requis :**
- Raspberry Pi 3B+, 4B (2GB minimum) ou 5
- Carte SD 32GB minimum (Classe 10)
- Connexion internet (Ethernet ou WiFi configuré)

**Logiciel requis :**
- Raspberry Pi OS Lite 64-bit (recommandé)
- Accès SSH ou clavier/écran connecté
- Compte Google avec Google Drive

### Configuration Préalable

1. **Flasher l'OS :**
   - Télécharger [Raspberry Pi Imager](https://www.raspberrypi.org/software/)
   - Flasher Raspberry Pi OS Lite 64-bit
   - Activer SSH dans les options avancées

2. **Configuration WiFi (si nécessaire) :**
   ```bash
   sudo raspi-config
   # Choisir "System Options" > "Wireless LAN"
   # Ou utiliser l'interface graphique lors du premier boot
   ```

3. **Mise à jour initiale :**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

### Installation Automatique

1. **Télécharger et lancer l'installation :**
   ```bash
   # Cloner le dépôt
   git clone https://github.com/elkir0/Pi-Signage.git
   cd Pi-Signage/raspberry-pi-installer/scripts
   
   # Rendre exécutable
   chmod +x *.sh
   
   # Lancer l'installation v2.3.0
   sudo ./install.sh
   ```

2. **Suivre l'assistant d'installation :**
   - Choisir le mode d'affichage (VLC Classic ou Chromium Kiosk)
   - Sélectionner les modules à installer
   - Renseigner le nom du dossier Google Drive (défaut: "Signage")
   - Définir un mot de passe pour l'interface web
   - Définir un mot de passe pour Glances
   - Choisir un hostname pour le Pi

3. **Configuration Google Drive :**
   ```bash
   # Après l'installation, configurer Google Drive
   sudo /opt/scripts/setup-gdrive.sh
   ```

4. **Redémarrage :**
   ```bash
   sudo reboot
   ```

### Installation Manuelle Module par Module

```bash
# 1. Script principal
sudo ./install.sh

# 2. Modules individuels (si besoin)
sudo ./00-security-utils.sh
sudo ./01-system-config.sh
sudo ./02-display-manager.sh         # Mode VLC uniquement
sudo ./03-vlc-setup.sh              # OU
sudo ./03-chromium-kiosk.sh         # Selon le mode choisi
sudo ./04-rclone-gdrive.sh
sudo ./05-glances-setup.sh
sudo ./06-watchdog-setup.sh
sudo ./07-services-setup.sh
sudo ./08-backup-manager.sh
sudo ./09-web-interface-v2.sh
sudo ./10-final-check.sh
```

### Installation pour VM/Headless

```bash
# Le script détecte automatiquement l'environnement VM
# et installe Xvfb si nécessaire
sudo ./install.sh

# Pour forcer le mode VM manuellement
touch /etc/pi-signage/vm-mode.conf
```

## 🎛️ Utilisation

### Commandes Principales

#### Communes aux deux modes
```bash
# Contrôle général
sudo pi-signage status           # État de tous les services
sudo pi-signage start            # Démarrer tous les services
sudo pi-signage stop             # Arrêter tous les services
sudo pi-signage restart          # Redémarrer tous les services
sudo pi-signage emergency        # Récupération d'urgence

# Diagnostic et maintenance
sudo pi-signage-diag            # Diagnostic complet du système
sudo pi-signage-tools           # Menu interactif d'outils
sudo pi-signage-repair          # Réparation automatique
sudo pi-signage-logs            # Collecte de logs pour support

# Synchronisation
sudo /opt/scripts/sync-videos.sh    # Synchronisation manuelle
sudo /opt/scripts/test-gdrive.sh    # Test connexion Google Drive
```

#### Mode Chromium Kiosk (spécifique)
```bash
# Contrôle du player
sudo /opt/scripts/player-control.sh play     # Lecture
sudo /opt/scripts/player-control.sh pause    # Pause
sudo /opt/scripts/player-control.sh next     # Vidéo suivante
sudo /opt/scripts/player-control.sh reload   # Recharger le player

# Mise à jour de la playlist
sudo /opt/scripts/update-playlist.sh
```

### Interfaces Web

#### Interface de Gestion Web
**Accès :** `http://[IP_DU_PI]/`
- **Utilisateur :** admin
- **Mot de passe :** défini lors de l'installation
- **Fonctionnalités :**
  - Dashboard avec état système en temps réel
  - Upload et gestion de vidéos
  - Téléchargement YouTube (yt-dlp)
  - Page de paramètres système
  - Contrôle des services
  - Monitoring CPU, RAM, température
  - Gestion de l'espace disque

#### Interface de Monitoring Glances
**Accès :** `http://[IP_DU_PI]:61208`
- **Utilisateur :** admin
- **Mot de passe :** défini lors de l'installation
- **Informations disponibles :**
  - Utilisation CPU, mémoire, disque
  - Température du processeur
  - Services actifs
  - Historique des performances
  - Logs en temps réel

#### Player HTML5 (Mode Chromium)
**Accès :** `http://[IP_DU_PI]:8888/player.html`
- Player HTML5 moderne
- Contrôle WebSocket
- Overlays et transitions

### Ajout de Vidéos

1. **Créer le dossier dans Google Drive :**
   - Se connecter à [Google Drive](https://drive.google.com)
   - Créer un dossier nommé "Signage" (ou le nom choisi)

2. **Ajouter des vidéos :**
   - Formats supportés : MP4, AVI, MKV, MOV, WMV
   - Résolution recommandée : 1080p
   - Les vidéos sont synchronisées automatiquement toutes les 6h

3. **Synchronisation manuelle :**
   ```bash
   sudo /opt/scripts/sync-videos.sh
   ```

## 🔧 Outils de Diagnostic

### Script de Diagnostic Principal

```bash
sudo pi-signage-diag
```

**Vérifications effectuées :**
- ✅ État des services critiques
- ✅ Processus VLC et affichage
- ✅ Connectivité réseau et Google Drive
- ✅ Espace disque et mémoire
- ✅ Température du processeur
- ✅ Configuration système
- ✅ Logs d'erreurs récents

### Outils Spécialisés

```bash
# Diagnostic VLC
sudo /opt/scripts/diag-vlc.sh

# Diagnostic réseau
sudo /opt/scripts/diag-network.sh

# Diagnostic système
sudo /opt/scripts/diag-system.sh

# Menu interactif complet
sudo pi-signage-tools
```

### Collecte de Logs

```bash
# Collecter tous les logs pour support
sudo pi-signage-logs

# Fichier généré : /tmp/pi-signage-logs-[DATE].tar.gz
```

## 🛠️ Maintenance

### Automatisations Configurées

| Tâche | Fréquence | Description |
|-------|-----------|-------------|
| **Synchronisation vidéos** | Toutes les 6h | Télécharge les nouvelles vidéos depuis Google Drive |
| **Vérification santé** | Toutes les heures | Contrôle services, température, mémoire |
| **Surveillance VLC** | Toutes les 5 min | Redémarre VLC si nécessaire |
| **Surveillance réseau** | Toutes les 10 min | Vérifie la connectivité internet |
| **Nettoyage logs** | Quotidien à 2h | Supprime les anciens logs |
| **Rapport quotidien** | Quotidien à 8h | Génère un rapport de statut |
| **Redémarrage** | Dimanche à 3h | Redémarrage hebdomadaire de maintenance |

### Maintenance Manuelle

```bash
# Nettoyage manuel
sudo /opt/scripts/cleanup-logs.sh

# Vérification espace disque
sudo /opt/scripts/check-disk-space.sh

# Vérification santé système
sudo /opt/scripts/health-check.sh
```

### Surveillance des Services

```bash
# Logs en temps réel
sudo journalctl -u vlc-signage -f        # Logs VLC
sudo journalctl -u glances -f            # Logs Glances
sudo journalctl -u pi-signage-watchdog -f # Logs surveillance

# Logs Pi Signage
tail -f /var/log/pi-signage/*.log
```

## 🚨 Dépannage

### Problèmes Courants

**1. VLC ne démarre pas**
```bash
# Diagnostic VLC
sudo /opt/scripts/diag-vlc.sh

# Redémarrage forcé
sudo systemctl restart vlc-signage.service

# Vérifier les vidéos
ls -la /opt/videos/
```

**2. Pas de synchronisation Google Drive**
```bash
# Tester la connexion
sudo /opt/scripts/test-gdrive.sh

# Reconfigurer Google Drive
sudo /opt/scripts/setup-gdrive.sh

# Synchronisation manuelle
sudo /opt/scripts/sync-videos.sh
```

**3. Écran noir ou pas d'affichage**
```bash
# Vérifier X11
sudo systemctl status lightdm

# Redémarrer l'affichage
sudo systemctl restart lightdm

# Diagnostic système complet
sudo pi-signage-diag
```

**4. Interface Glances inaccessible**
```bash
# Vérifier le service
sudo systemctl status glances

# Redémarrer Glances
sudo systemctl restart glances

# Changer le mot de passe
sudo /opt/scripts/glances-password.sh
```

### Récupération d'Urgence

```bash
# Réparation automatique complète
sudo pi-signage emergency

# Ou réparation manuelle
sudo pi-signage-repair
```

### Réinstallation d'un Module

```bash
# Exemple: réinstaller le module VLC
sudo ./03-vlc-setup.sh

# Réinstallation complète
sudo ./main-setup.sh
```

## 📊 Performances et Optimisations

### Ressources Recommandées

| Modèle Pi | RAM | Stockage | Nb Écrans |
|-----------|-----|----------|-----------|
| **Pi 3B+** | 1GB | 32GB | 1-2 écrans |
| **Pi 4 2GB** | 2GB | 32GB | 1-2 écrans |
| **Pi 4 4GB** | 4GB | 64GB | 2-3 écrans |
| **Pi 4 8GB** | 8GB | 64GB | 3-4 écrans |

### Consommation Ressources

- **CPU moyen :** 15-25% (lecture vidéo 1080p)
- **RAM utilisée :** 200-400MB
- **Stockage vidéos :** Variable selon contenu
- **Réseau :** ~50MB/h (synchronisation)

### Optimisations Appliquées

- ✅ **GPU hardware acceleration** selon modèle Pi
- ✅ **Services non essentiels désactivés**
- ✅ **Cache système optimisé**
- ✅ **Rotation automatique des logs**
- ✅ **Gestion intelligente de la mémoire**

## 🔐 Sécurité

### Mesures Implémentées

- **Interface Glances protégée** par authentification
- **Utilisateur signage dédié** sans privilèges sudo
- **Services en sandbox** avec restrictions systemd
- **Logs d'accès** et audit des opérations
- **Mise à jour automatique** des paquets de sécurité

### Configuration Firewall (Optionnel)

```bash
# Installer UFW
sudo apt install ufw

# Autoriser SSH et Glances
sudo ufw allow ssh
sudo ufw allow 61208/tcp

# Activer le firewall
sudo ufw enable
```

## 📁 Structure des Fichiers

```
/opt/
├── videos/                     # Vidéos synchronisées depuis Google Drive
├── scripts/                    # Scripts de maintenance et diagnostic
│   ├── vlc-signage.sh         # Script principal VLC
│   ├── sync-videos.sh         # Synchronisation Google Drive  
│   ├── pi-signage-diag.sh     # Diagnostic complet
│   ├── auto-repair.sh         # Réparation automatique
│   └── ...
└── pi-signage-diag.sh         # Lien vers diagnostic principal

/etc/
├── pi-signage/
│   └── config.conf            # Configuration centralisée
├── systemd/system/            # Services systemd
│   ├── vlc-signage.service
│   ├── glances.service
│   ├── pi-signage-watchdog.service
│   └── pi-signage.target
├── lightdm/lightdm.conf       # Configuration auto-login
├── glances/glances.conf       # Configuration monitoring
└── cron.d/                    # Tâches automatisées
    ├── pi-signage-sync
    ├── pi-signage-maintenance
    └── pi-signage-monitoring

/var/log/pi-signage/           # Logs centralisés
├── setup.log                  # Installation
├── vlc.log                    # VLC
├── sync.log                   # Synchronisation
├── health.log                 # Santé système
└── daily-reports/             # Rapports quotidiens

/home/signage/                 # Utilisateur dédié
├── .config/
│   ├── vlc/vlcrc             # Configuration VLC
│   ├── rclone/rclone.conf    # Configuration Google Drive
│   └── openbox/              # Configuration gestionnaire fenêtres
```

## 🚀 Commandes de Référence Rapide

### Installation
```bash
sudo ./install.sh                    # Installation complète
sudo /opt/scripts/setup-gdrive.sh   # Configuration Google Drive
```

### Contrôle quotidien
```bash
sudo pi-signage status              # État général
sudo pi-signage-diag                # Diagnostic complet
```

### Maintenance
```bash
sudo pi-signage restart             # Redémarrage services
sudo /opt/scripts/sync-videos.sh   # Sync manuelle
sudo pi-signage-repair             # Réparation auto
```

### Monitoring
```bash
# Interface web: http://[IP]:61208
sudo journalctl -u vlc-signage -f  # Logs VLC temps réel
tail -f /var/log/pi-signage/*.log  # Tous les logs
```

### Dépannage
```bash
sudo pi-signage emergency          # Récupération urgence
sudo pi-signage-logs               # Collecte logs support
sudo /opt/scripts/diag-vlc.sh     # Diagnostic VLC spécialisé
```

## 💡 Conseils d'Utilisation

### Optimisation des Vidéos

**Formats recommandés :**
- **Codec vidéo :** H.264 (AVC)
- **Codec audio :** AAC ou MP3
- **Résolution :** 1920x1080 (1080p)
- **Bitrate :** 5-8 Mbps pour 1080p
- **FPS :** 25 ou 30 fps

**Outils de conversion :**
```bash
# Conversion avec ffmpeg
ffmpeg -i input.mov -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k output.mp4
```

### Gestion Multi-Écrans

Pour gérer plusieurs écrans Pi Signage :

1. **Nommer les Pi différemment :**
   ```bash
   # Lors de l'installation, utiliser des noms uniques
   pi-signage-accueil
   pi-signage-bureau
   pi-signage-atelier
   ```

2. **Organiser les dossiers Google Drive :**
   ```
   Google Drive/
   ├── Signage-Accueil/
   ├── Signage-Bureau/
   └── Signage-Atelier/
   ```

3. **Centraliser le monitoring :**
   - Noter les IP de chaque Pi
   - Créer des favoris pour chaque interface Glances

### Sauvegarde et Restauration

```bash
# Sauvegarde configuration
sudo tar -czf pi-signage-backup.tar.gz /etc/pi-signage/ /opt/scripts/ /home/signage/.config/

# Restauration (sur nouveau Pi)
sudo tar -xzf pi-signage-backup.tar.gz -C /
sudo chown -R signage:signage /home/signage/.config/
```

## 📞 Support et Contribution

### Obtenir de l'Aide

1. **Diagnostic automatique :**
   ```bash
   sudo pi-signage-diag
   ```

2. **Collecte de logs :**
   ```bash
   sudo pi-signage-logs
   ```

3. **Documentation :** Consultez ce README et les commentaires dans les scripts

### Contribution au Projet

1. **Fork** le repository
2. **Créez** une branche pour votre fonctionnalité
3. **Testez** vos modifications sur Pi réel
4. **Documentez** vos changements
5. **Soumettez** une Pull Request

### Signaler un Bug

**Informations à fournir :**
- Modèle de Raspberry Pi
- Version du système (Raspberry Pi OS)
- Sortie de `sudo pi-signage-diag`
- Archive de logs (`sudo pi-signage-logs`)
- Description détaillée du problème

## 📝 Notes de Version

### Version 2.3.0 (Actuelle)
- ✨ **Deux modes d'affichage** : VLC Classic et Chromium Kiosk
- ✨ **Interface web complète** : Dashboard, vidéos, paramètres
- ✨ **Support VM/Headless** : Installation avec Xvfb
- ✨ **Authentification harmonisée** : SHA-512 unifié
- ✨ **Corrections majeures** : Permissions, chemins, stabilité
- ✨ **Module de sécurité** : Fonctions centralisées
- ✨ **Pages web manquantes** : videos.php et settings.php ajoutées

### Version 2.2.0
- ✨ Architecture modulaire complète
- ✨ Système de sécurité renforcé
- ✨ Chiffrement AES-256-CBC
- ✨ Installation modulaire

### Version 2.0.0
- ✨ Compatibilité Raspberry Pi 4 et 5
- ✨ Système de watchdog et récupération automatique
- ✨ Interface de diagnostic et maintenance
- ✨ Configuration stable sans optimisations risquées
- ✨ Documentation complète

### Version 1.2.0
- Script monolithique avec optimisations
- Support Pi 3B+ uniquement
- Configuration basique

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.

---

**Pi Signage Digital** - Transformez vos Raspberry Pi en système d'affichage professionnel 🚀