# 🖥️ PiSignage v0.8.0 - Dual Player Edition

Système d'affichage digital révolutionnaire pour Raspberry Pi avec **choix entre VLC et MPV**, optimisé pour une performance maximale avec interface web moderne.

## 🎯 Nouveauté v0.8.0 : Système Dual-Player

**Choisissez le player parfait pour vos besoins :**

| 🚀 **MPV** (Défaut) | 🎛️ **VLC** (Option) |
|---------------------|---------------------|
| ✅ Performance optimale | ✅ HTTP API riche |
| ✅ GPU acceleration | ✅ Fonctionnalités avancées |
| ✅ Faible latence | ✅ Streaming réseau |
| ✅ Idéal pour affichage continu | ✅ Idéal pour contrôle avancé |

**🔄 Basculement en un clic** : Changez de player à tout moment via l'interface web ou ligne de commande !

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

## 🎥 Fonctionnalités v0.8.0

### 🆕 Nouveau : Dual-Player
- 🎬 **Choix VLC/MPV** : Basculement en temps réel entre les players
- ⚡ **Optimisations Pi3/4/5** : Configurations automatiques par modèle
- 🔄 **API unifiée** : Contrôle des deux players via interface commune
- 🎛️ **Sélecteur web** : Interface graphique pour choisir le player

### 📺 Lecture média avancée
- 🎥 **Multi-formats** : MP4, AVI, MKV, MOV, JPG, PNG
- 📋 **Playlists dynamiques** : Création et gestion via interface web
- 🔁 **Lecture en boucle** : Continue sans interruption
- 🎚️ **Contrôle volume** : Ajustement précis via API

### 🌐 Interface web moderne
- 📱 **Design glassmorphisme** : Interface moderne et responsive
- 📤 **Upload drag & drop** : Glisser-déposer de fichiers multiples
- 📺 **YouTube intégré** : Téléchargement direct avec yt-dlp
- 📸 **Screenshots hardware** : Capture optimisée avec raspi2png (25-30ms)

### 🔧 Contrôle avancé
- 🛠️ **API REST complète** : Contrôle programmatique HTTP/JSON
- 📊 **Monitoring système** : CPU, RAM, température en temps réel
- 📝 **Logs centralisés** : Suivi détaillé des événements
- ⚙️ **Configuration flexible** : JSON editable pour personnalisation

## 📚 Documentation

- 📖 **[Guide Dual-Player](docs/DUAL-PLAYER-GUIDE.md)** - Documentation complète v0.8.0
- 🚀 **[Installation rapide](docs/INSTALL.md)** - Setup en 5 minutes
- 🔧 **[Documentation API](docs/API.md)** - Référence REST complète
- 🛠️ **[Dépannage](docs/TROUBLESHOOTING.md)** - Solutions aux problèmes courants

## 🎮 Utilisation rapide

### Interface Web
```bash
# Accès : http://[IP_PI]/
# Section "Lecteur" → Choisir MPV/VLC → "Basculer Lecteur"
```

### Ligne de commande
```bash
# Basculer entre VLC et MPV
sudo /opt/pisignage/scripts/player-manager.sh switch

# Informations détaillées
sudo /opt/pisignage/scripts/player-manager.sh info

# Contrôle unifié
sudo /opt/pisignage/scripts/unified-player-control.sh play
```

### API REST
```bash
# Basculer le player
curl -X POST http://[IP_PI]/api/player.php -d '{"action":"switch"}'

# Statut actuel
curl http://[IP_PI]/api/player.php?action=current
```

## 📄 License

MIT License - Voir [LICENSE](LICENSE)

## 🐛 Support

[Ouvrir une issue](https://github.com/elkir0/Pi-Signage/issues)