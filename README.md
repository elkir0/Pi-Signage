# 🎬 PiSignage v0.8.1 - Digital Signage for Raspberry Pi

## 🚀 Installation One-Click

### Méthode 1: Installation directe depuis GitHub
```bash
# Cloner le dépôt
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Lancer l'installation automatique
bash install.sh --auto
```

### Méthode 2: Installation avec wget
```bash
# Télécharger et exécuter le script
wget https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install.sh
bash install.sh --auto
```

## ✨ Fonctionnalités

- **Interface Web Glassmorphisme** v0.8.1
- **Double support lecteur** : VLC (par défaut) et MPV
- **Big Buck Bunny** : Vidéo de démonstration incluse
- **Installation automatique** : Configuration complète en une commande
- **Démarrage au boot** : Service systemd configuré

## 📋 Prérequis

- Raspberry Pi avec Raspberry Pi OS Bookworm
- Connexion Internet
- 2GB de RAM minimum
- 4GB d'espace disque libre

## 🎯 Composants installés

- **Serveur Web** : Nginx + PHP 8.2
- **Lecteurs Vidéo** : VLC et MPV
- **Interface** : Dashboard web responsive
- **Vidéo démo** : Big Buck Bunny 720p

## 🔧 Configuration

### Accès à l'interface
```
http://[IP_RASPBERRY]:80
```

### Fichiers de configuration
- Configuration player : `/opt/pisignage/config/player-config.json`
- Logs : `/opt/pisignage/logs/`
- Médias : `/opt/pisignage/media/`

## 📝 Commandes utiles

```bash
# Vérifier le statut
sudo systemctl status pisignage

# Redémarrer le service
sudo systemctl restart pisignage

# Voir les logs VLC
tail -f /opt/pisignage/logs/vlc.log
```

## 🐛 Dépannage

### VLC ne démarre pas
```bash
# Vérifier l'environnement
echo $DISPLAY  # Doit afficher :0

# Redémarrer VLC
pkill vlc
/opt/pisignage/scripts/start-vlc.sh
```

### Interface web inaccessible
```bash
# Vérifier nginx
sudo systemctl status nginx
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm
```

## 📊 Version

**v0.8.1** (2025-09-25) - Version stable avec installation automatique

## 🔗 Liens

- **GitHub** : https://github.com/elkir0/Pi-Signage
- **Issues** : https://github.com/elkir0/Pi-Signage/issues

---
*Développé avec ❤️ pour Raspberry Pi*
