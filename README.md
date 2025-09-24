# PiSignage v0.8.0

Système d'affichage digital pour Raspberry Pi avec interface web de gestion.

## 🚀 Installation rapide

```bash
# Cloner le repository
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Lancer l'installation
chmod +x install.sh
./install.sh
```

## 📋 Prérequis

- Raspberry Pi 3/4/5
- Raspberry Pi OS Bookworm (64-bit recommandé)
- Connexion internet
- 8GB+ carte SD

## 🌐 Accès

Après installation : `http://[IP_RASPBERRY]/`

## 📁 Structure

```
/opt/pisignage/
├── web/         # Interface web PHP
├── scripts/     # Scripts de contrôle
├── media/       # Fichiers média
├── config/      # Configuration
└── logs/        # Logs système
```

## 🎥 Fonctionnalités

- Lecture vidéo en boucle (VLC)
- Interface web de gestion
- Upload de fichiers média
- Gestion des playlists
- Téléchargement YouTube
- Capture d'écran à distance
- API REST complète

## 📚 Documentation

- [Guide d'installation](docs/INSTALL.md)
- [Documentation API](docs/API.md)
- [Dépannage](docs/TROUBLESHOOTING.md)

## 📄 License

MIT License - Voir [LICENSE](LICENSE)

## 🐛 Support

[Ouvrir une issue](https://github.com/elkir0/Pi-Signage/issues)