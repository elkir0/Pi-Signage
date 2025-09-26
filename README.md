# PiSignage v0.8.1

Solution complète de digital signage pour Raspberry Pi avec installation one-click et interface web moderne.

## Présentation

PiSignage est une solution d'affichage dynamique conçue spécifiquement pour Raspberry Pi. Elle offre une interface web intuitive avec un design glassmorphisme, la gestion de médias multiples, et un système dual-player VLC/MPV optimisé pour les performances.

### Fonctionnalités principales

- **Installation automatique** : Déploiement complet en une commande
- **Interface web moderne** : Design glassmorphisme responsive v0.8.1
- **Dual-player avancé** : Support VLC et MPV avec basculement dynamique
- **Gestion multimédia** : Upload, playlists, programmation horaire
- **Optimisations Raspberry Pi** : Configurations spécifiques Pi 3/4/5
- **API REST complète** : Contrôle programmatique de tous les composants
- **Service systemd** : Démarrage automatique et supervision

## Installation rapide

### Installation depuis GitHub
```bash
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage
bash install.sh --auto
```

### Installation directe
```bash
wget https://raw.githubusercontent.com/elkir0/Pi-Signage/main/install.sh
bash install.sh --auto
```

Le script installe automatiquement :
- Serveur web (Nginx + PHP 8.2-FPM)
- Lecteurs vidéo (VLC + MPV)
- Interface web avec tous les assets
- Configuration optimisée pour votre modèle de Pi
- Service systemd `pisignage`
- Vidéo de démonstration Big Buck Bunny

## Prérequis système

- **Matériel** : Raspberry Pi 3, 4 ou 5
- **Système** : Raspberry Pi OS Bookworm (64-bit recommandé)
- **Mémoire** : 2GB RAM minimum, 4GB recommandé
- **Stockage** : 8GB d'espace libre minimum
- **Réseau** : Connexion Internet pour l'installation

## Accès et utilisation

### Interface web
Accédez à l'interface via : `http://[IP-RASPBERRY]`

L'interface propose :
- **Dashboard** : Vue d'ensemble du système et statut des lecteurs
- **Gestion de médias** : Upload, suppression, prévisualisation
- **Playlists** : Création et édition de listes de lecture
- **Programmateur** : Planification horaire d'affichage
- **Configuration** : Paramètres système et lecteurs
- **Monitoring** : Logs, performances, captures d'écran

### Structure des fichiers
```
/opt/pisignage/
├── config/          # Configuration système et lecteurs
├── docs/            # Documentation technique
├── logs/            # Fichiers de logs
├── media/           # Contenus multimédias
├── scripts/         # Scripts de gestion
├── web/             # Interface web et API
├── install.sh       # Script d'installation
└── README.md        # Documentation principale
```

### Configuration principale
- **Lecteurs** : `/opt/pisignage/config/player-config.json`
- **Médias** : `/opt/pisignage/media/`
- **Logs** : `/opt/pisignage/logs/`
- **Interface** : `http://[IP-RASPBERRY]/`

## Gestion des services

### Service principal
```bash
# Statut du service
sudo systemctl status pisignage

# Contrôle du service
sudo systemctl start|stop|restart pisignage

# Activation au démarrage
sudo systemctl enable pisignage
```

### Gestion des lecteurs
```bash
# Script de gestion unifié
/opt/pisignage/scripts/player-manager-v0.8.1.sh

# Actions disponibles
sudo systemctl restart pisignage    # Redémarrer le lecteur actuel
pkill vlc && pkill mpv             # Arrêt forcé des lecteurs
```

### Monitoring et logs
```bash
# Logs en temps réel
sudo journalctl -u pisignage -f

# Logs spécifiques
tail -f /opt/pisignage/logs/vlc.log      # Logs VLC
tail -f /opt/pisignage/logs/mpv.log      # Logs MPV
tail -f /opt/pisignage/logs/pisignage.log # Logs système
```

## Dépannage rapide

### Service ne démarre pas
```bash
# Vérifier les dépendances
sudo systemctl status nginx php8.2-fpm

# Redémarrer les services web
sudo systemctl restart nginx php8.2-fpm

# Vérifier les permissions
sudo chown -R www-data:www-data /opt/pisignage
```

### Problèmes d'affichage
```bash
# Vérifier l'affichage
echo $DISPLAY    # Doit retourner :0

# Test manuel des lecteurs
mpv --fs /opt/pisignage/media/*.mp4
cvlc --fullscreen /opt/pisignage/media/*.mp4
```

### Interface inaccessible
```bash
# Vérifier l'état des services
sudo systemctl status nginx php8.2-fpm pisignage

# Redémarrage complet
sudo systemctl restart nginx php8.2-fpm pisignage
```

## Documentation technique

Pour une utilisation avancée, consultez la documentation complète :

- **[Guide d'installation](docs/INSTALL.md)** : Procédures détaillées d'installation
- **[Documentation API](docs/API.md)** : Référence complète des endpoints
- **[Guide Dual-Player](docs/DUAL-PLAYER-GUIDE.md)** : Configuration VLC/MPV avancée
- **[Dépannage](docs/TROUBLESHOOTING.md)** : Résolution de problèmes détaillée

## Informations projet

- **Version** : 0.8.1
- **Date** : Septembre 2025
- **Licence** : MIT
- **Compatibilité** : Raspberry Pi 3/4/5, Raspberry Pi OS Bookworm

### Liens utiles

- **Code source** : https://github.com/elkir0/Pi-Signage
- **Signaler un problème** : https://github.com/elkir0/Pi-Signage/issues
- **Documentation** : Dossier `/opt/pisignage/docs/`

### Contribution

Les contributions sont les bienvenues via pull requests sur le dépôt GitHub. Merci de consulter les issues existantes avant de proposer de nouvelles fonctionnalités.
