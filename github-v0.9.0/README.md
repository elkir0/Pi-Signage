# 📺 Pi-Signage v0.9.0

<div align="center">

![Version](https://img.shields.io/badge/version-0.9.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%204-red)
![FPS](https://img.shields.io/badge/FPS-30%2B-brightgreen)
![CPU](https://img.shields.io/badge/CPU-7%25-brightgreen)
![Status](https://img.shields.io/badge/status-stable-success)

**Solution de digital signage haute performance pour Raspberry Pi**  
**30+ FPS confirmés avec seulement 7% d'utilisation CPU**

[Installation](#-installation-rapide) • [Documentation](docs/) • [Performance](#-performance) • [Interface Web](#-interface-web)

</div>

---

## 🚀 Installation Rapide

### Installation complète (recommandée)
```bash
wget -O - https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install.sh | bash
```

### Installation manuelle
```bash
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage
chmod +x install.sh
sudo ./install.sh
```

**⏱️ Temps d'installation : ~5 minutes**  
**🔄 Redémarrage requis après installation**

---

## ✅ Prérequis

- **Raspberry Pi 4** (2GB RAM minimum)
- **Raspberry Pi OS Bookworm Lite 64-bit** (testé et validé)
- Carte SD 16GB minimum
- Connexion internet pour l'installation

---

## 📊 Performance Validée

Tests réels sur Raspberry Pi 4 en production :

| Métrique | Valeur | Status |
|----------|--------|---------|
| **FPS** | 30+ | ✅ Confirmé à l'écran |
| **CPU (VLC)** | 7% | ✅ Excellent |
| **RAM** | 300MB | ✅ Léger |
| **Boot time** | 30s | ✅ Rapide |
| **Stabilité** | 24/7 | ✅ Production |

---

## 🖥️ Interface Web

Interface complète accessible après installation : `http://IP_RASPBERRY/`

### Fonctionnalités
- Dashboard avec monitoring temps réel
- Gestion des médias (upload, suppression)
- Création de playlists
- Téléchargement YouTube
- Programmation horaire
- API REST complète

---

## 📁 Structure du Projet

```
Pi-Signage/
├── install.sh          # Script d'installation principal
├── scripts/            # Scripts de contrôle
├── web/               # Interface web PHP
│   └── api/           # APIs REST
├── config/            # Configurations
├── docs/              # Documentation complète
└── tests/             # Scripts de test
```

---

## 🔧 Configuration

La configuration par défaut est **optimale et ne nécessite AUCUNE modification** :
- ✅ GPU memory : 76MB (par défaut, suffisant)
- ✅ Pas d'overclocking nécessaire
- ✅ Pas de modification de config.txt requise

---

## 📝 Changelog

### v0.9.0 (20/09/2025)
- ✅ Performance 30+ FPS confirmée
- ✅ Installation stable et reproductible
- ✅ Interface web complète
- ✅ API REST fonctionnelle
- ✅ Auto-démarrage au boot
- ✅ Documentation complète

---

## 📚 Documentation

Documentation complète disponible dans le dossier [`docs/`](docs/) :
- [Guide d'installation détaillé](docs/INSTALLATION.md)
- [Architecture technique](docs/ARCHITECTURE.md)
- [Dépannage](docs/TROUBLESHOOTING.md)
- [API Reference](docs/API.md)

---

## 🤝 Contribution

Les contributions sont bienvenues ! Voir [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📄 Licence

Ce projet est sous licence MIT. Voir [LICENSE](LICENSE)

---

<div align="center">
Développé avec ❤️ pour la communauté Raspberry Pi

🤖 Assisté par [Claude](https://claude.ai) & [Happy Engineering](https://happy.engineering)
</div>
