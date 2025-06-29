# 📺 Pi Signage Digital - Solution Complète

**Solution tout-en-un de digital signage pour Raspberry Pi avec interface web de gestion**

[![Compatible](https://img.shields.io/badge/Compatible-Pi%203B%2B%20%7C%204B%20%7C%205-green.svg)](https://www.raspberrypi.org/)
[![Version](https://img.shields.io/badge/Version-2.0.0-blue.svg)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)]()

## 🎯 Présentation

Pi Signage Digital est une solution professionnelle complète pour transformer vos Raspberry Pi en système d'affichage dynamique. Ce repository contient :

- **Installation automatisée pour Raspberry Pi** : Scripts modulaires pour configurer votre Pi
- **Interface web de gestion** : Dashboard moderne pour contrôler vos écrans à distance

## 📁 Structure du Projet

```
Pi-Signage/
├── raspberry-pi-installer/    # Scripts d'installation et configuration Raspberry Pi
│   ├── scripts/              # Modules d'installation
│   ├── docs/                 # Documentation technique
│   └── examples/             # Fichiers de configuration exemple
│
└── web/                      # Interface web de gestion
    ├── src/                  # Code source PHP
    ├── api/                  # Endpoints API
    ├── assets/               # CSS, JS, images
    └── install/              # Scripts d'installation web
```

## 🚀 Installation Rapide

### 1. Sur le Raspberry Pi

```bash
# Cloner le repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/raspberry-pi-installer

# Lancer l'installation
chmod +x install.sh
sudo ./install.sh
```

### 2. Interface Web (optionnelle)

```bash
cd ../web/install
sudo ./install-web.sh
```

## 📖 Documentation

- **[Guide d'installation Raspberry Pi](raspberry-pi-installer/docs/README.md)**
- **[Guide de démarrage rapide](raspberry-pi-installer/docs/quickstart_guide.md)**
- **[Documentation interface web](web/docs/INSTALL.md)**
- **[Guide technique complet](raspberry-pi-installer/docs/technical_guide.md)**

## ✨ Fonctionnalités

### Système Raspberry Pi
- ✅ Lecture vidéos en boucle avec rotation aléatoire
- ✅ Synchronisation automatique Google Drive
- ✅ Installation modulaire en ~50 minutes
- ✅ Surveillance et récupération automatique
- ✅ Support multi-écrans

### Interface Web
- ✅ Dashboard temps réel
- ✅ Téléchargement YouTube direct
- ✅ Gestion des vidéos
- ✅ Visualisation des logs
- ✅ Contrôle à distance sécurisé

## 🛠️ Configuration Requise

- **Raspberry Pi** : 3B+, 4B (2GB+) ou 5
- **Carte SD** : 32GB minimum
- **OS** : Raspberry Pi OS Lite 64-bit
- **Réseau** : Connexion internet requise

## 🔧 Commandes Principales

```bash
# Sur le Raspberry Pi
sudo pi-signage status          # État des services
sudo pi-signage-diag           # Diagnostic complet
sudo pi-signage emergency      # Récupération d'urgence

# Synchronisation manuelle
sudo /opt/scripts/sync-videos.sh
```

## 📊 Interface Web

Accès : `http://[IP_DU_PI]/` ou `http://[IP_DU_PI]:61208` pour Glances

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- 🐛 Signaler des bugs
- 💡 Proposer des améliorations
- 🔧 Soumettre des pull requests

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

Merci à tous les contributeurs et à la communauté Raspberry Pi !

---

**Pi Signage Digital** - Transformez vos Raspberry Pi en système d'affichage professionnel 🚀
