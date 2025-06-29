# 📺 Pi Signage Digital - Solution Complète

**Solution tout-en-un de digital signage pour Raspberry Pi avec interface web de gestion**

[![Compatible](https://img.shields.io/badge/Compatible-Pi%203B%2B%20%7C%204B%20%7C%205-green.svg)](https://www.raspberrypi.org/)
[![Version](https://img.shields.io/badge/Version-2.2.0-blue.svg)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)]()
[![Security](https://img.shields.io/badge/Security-Enhanced-brightgreen.svg)]()

## 🎯 Présentation

Pi Signage Digital est une solution professionnelle complète pour transformer vos Raspberry Pi en système d'affichage dynamique. Ce projet offre une installation automatisée avec une sécurité renforcée et une interface web moderne.

### 🔐 Nouvelles fonctionnalités de sécurité (v2.2.0)
- **Chiffrement des mots de passe** avec AES-256-CBC
- **Gestion d'erreurs robuste** avec retry logic
- **Permissions restrictives** sur tous les fichiers sensibles
- **Protection CSRF** dans l'interface web
- **Module de sécurité centralisé** pour tous les scripts

## 📁 Structure du Projet

```
Pi-Signage/
├── raspberry-pi-installer/       # Scripts d'installation et configuration
│   ├── scripts/                 # Modules d'installation
│   │   ├── 00-security-utils.sh # Module de sécurité centralisé
│   │   ├── 01-system-config.sh  # Configuration système
│   │   ├── 02-display-manager.sh # Gestionnaire d'affichage
│   │   ├── 03-vlc-setup.sh      # Installation VLC
│   │   ├── 04-rclone-gdrive.sh  # Synchronisation Google Drive
│   │   ├── 05-glances-setup.sh  # Monitoring
│   │   ├── 06-watchdog-setup.sh # Surveillance système
│   │   ├── 07-services-setup.sh # Services systemd
│   │   ├── 08-backup-manager.sh # Gestion des sauvegardes
│   │   ├── 09-web-interface-v2.sh # Interface web (nouvelle version)
│   │   └── 10-final-check.sh    # Vérification finale
│   ├── docs/                    # Documentation technique
│   └── examples/                # Fichiers de configuration exemple
│
└── web-interface/               # Interface web de gestion
    ├── public/                  # Fichiers accessibles publiquement
    ├── includes/                # Logique PHP et sécurité
    ├── api/                     # Points d'accès API REST
    ├── assets/                  # CSS, JS, images
    └── templates/               # Templates réutilisables
```

## 🚀 Installation Rapide

### Prérequis
- **Raspberry Pi** : 3B+, 4B (2GB minimum recommandé) ou 5
- **Carte SD** : 32GB minimum (Classe 10 ou supérieure)
- **OS** : Raspberry Pi OS Lite 64-bit (Bookworm)
- **Réseau** : Connexion internet stable

### Installation en une commande

```bash
# Cloner le repository et lancer l'installation
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/raspberry-pi-installer
chmod +x install.sh
sudo ./install.sh
```

L'installation est **modulaire** - vous pouvez choisir les composants à installer :
- Configuration système de base
- Gestionnaire d'affichage (X11 + LightDM)
- VLC pour la lecture des vidéos
- Synchronisation Google Drive
- Monitoring avec Glances
- Interface web de gestion
- Et plus encore...

## 📖 Documentation

### Guides principaux
- **[🚀 Guide de démarrage rapide](raspberry-pi-installer/docs/quickstart_guide.md)**
- **[📘 Guide d'installation détaillé](raspberry-pi-installer/docs/README.md)**
- **[🔧 Guide technique complet](raspberry-pi-installer/docs/technical_guide.md)**
- **[🔐 Guide de sécurité](raspberry-pi-installer/docs/SECURITY.md)**
- **[🌐 Documentation interface web](web-interface/README.md)**
- **[📝 Guide de migration v2](raspberry-pi-installer/MIGRATION.md)**

### Guides spécifiques
- [Configuration Google Drive](raspberry-pi-installer/docs/google-drive-setup.md)
- [Personnalisation de l'installation](raspberry-pi-installer/docs/customization.md)
- [Dépannage](raspberry-pi-installer/docs/troubleshooting.md)

## ✨ Fonctionnalités

### 🖥️ Système Raspberry Pi
- ✅ **Lecture vidéos optimisée** : Support multi-formats avec VLC
- ✅ **Synchronisation Google Drive** : Mise à jour automatique des contenus
- ✅ **Installation modulaire** : Choisissez uniquement ce dont vous avez besoin
- ✅ **Surveillance automatique** : Récupération en cas de problème
- ✅ **Sécurité renforcée** : Chiffrement, permissions strictes, validation

### 🌐 Interface Web
- ✅ **Dashboard moderne** : Vue d'ensemble en temps réel
- ✅ **Gestion des vidéos** : Upload, suppression, organisation
- ✅ **Téléchargement YouTube** : Via yt-dlp (vos propres vidéos)
- ✅ **Monitoring système** : CPU, RAM, température, stockage
- ✅ **Contrôle à distance** : Démarrer/arrêter les services
- ✅ **Sécurité** : Authentification, CSRF, headers de sécurité

### 🔐 Sécurité (Nouveau!)
- ✅ **Module de sécurité centralisé** : Fonctions réutilisables
- ✅ **Chiffrement AES-256-CBC** : Pour les mots de passe stockés
- ✅ **Hachage SHA-512** : Pour l'authentification web
- ✅ **Retry logic** : Gestion robuste des erreurs réseau
- ✅ **Permissions restrictives** : 600/640/750 selon les besoins
- ✅ **Journalisation de sécurité** : Audit des événements

## 🛠️ Configuration

### Configuration minimale
- **Pi 3B+** : 1GB RAM, carte SD 32GB
- **Pi 4B** : 2GB RAM recommandé, carte SD 32GB+
- **Pi 5** : Configuration par défaut, carte SD 64GB recommandé

### Ports utilisés
- **80** : Interface web (nginx)
- **61208** : Monitoring Glances
- **8080** : API VLC (localhost uniquement)

## 🔧 Commandes Utiles

```bash
# Contrôle des services
sudo systemctl status vlc-signage    # État de VLC
sudo systemctl restart vlc-signage   # Redémarrer VLC

# Diagnostic
sudo pi-signage-diag                 # Diagnostic complet
sudo journalctl -u vlc-signage -f    # Logs en temps réel

# Mise à jour
sudo /opt/scripts/update-ytdlp.sh              # Mettre à jour yt-dlp
sudo /opt/scripts/update-web-interface.sh      # Mettre à jour l'interface web

# Sécurité
sudo /opt/scripts/glances-password.sh          # Changer le mot de passe Glances
```

## 📊 Accès aux Interfaces

- **Interface web** : `http://[IP_DU_PI]/`
  - Utilisateur : `admin`
  - Mot de passe : défini lors de l'installation
  
- **Monitoring Glances** : `http://[IP_DU_PI]:61208`
  - Utilisateur : `admin`
  - Mot de passe : défini lors de l'installation

## 🔄 Mises à jour

Le système inclut des scripts de mise à jour automatique :
- **yt-dlp** : Mis à jour chaque semaine automatiquement
- **Interface web** : Peut être mise à jour depuis GitHub

Pour une mise à jour manuelle :
```bash
cd /path/to/Pi-Signage
git pull
sudo /opt/scripts/update-web-interface.sh
```

## 🤝 Contribution

Les contributions sont les bienvenues ! 

### Comment contribuer
1. 🍴 Fork le projet
2. 🔧 Créez votre branche (`git checkout -b feature/AmazingFeature`)
3. 📝 Committez vos changements (`git commit -m 'Add AmazingFeature'`)
4. 📤 Push vers la branche (`git push origin feature/AmazingFeature`)
5. 🔄 Ouvrez une Pull Request

### Domaines prioritaires
- 🔐 Améliorations de sécurité
- 🎨 Interface utilisateur
- 📱 Support mobile
- 🌍 Internationalisation
- 📊 Nouvelles fonctionnalités de monitoring

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

- La communauté Raspberry Pi
- Les contributeurs du projet
- Les projets open source utilisés (VLC, nginx, PHP, etc.)

## 📞 Support

- **Issues GitHub** : Pour signaler des bugs ou demander des fonctionnalités
- **Discussions** : Pour les questions générales et l'aide
- **Wiki** : Documentation communautaire (à venir)

---

**Pi Signage Digital** - Transformez vos Raspberry Pi en système d'affichage professionnel sécurisé 🚀🔐