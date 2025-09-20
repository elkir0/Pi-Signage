# 🏗️ Architecture Technique - Pi-Signage v0.9.0

## Vue d'ensemble

Pi-Signage utilise une architecture modulaire optimisée pour les performances sur Raspberry Pi.

## Stack Technologique

### Système
- **OS** : Raspberry Pi OS Bookworm Lite 64-bit
- **Kernel** : 6.12+ avec support V4L2/DRM
- **GPU** : Configuration par défaut (76MB) SUFFISANTE

### Lecture Vidéo
- **VLC 3.0.21** : Mode dummy, sans interface
- **Décodage** : Software optimisé (7% CPU pour 30 FPS)
- **Sortie** : X11 minimal avec xserver-xorg-core
- **Auto-start** : systemd + xinit

### Interface Web
- **Serveur** : Nginx 1.22
- **Backend** : PHP 8.2-FPM
- **API** : REST JSON
- **Frontend** : Vanilla JS (pas de framework)

## Architecture des Composants

```
┌─────────────────────────────────────────────┐
│                 RASPBERRY PI 4               │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────┐    ┌────────────┐           │
│  │   Boot   │───▶│  Auto-login │           │
│  └──────────┘    └────────────┘           │
│        │               │                    │
│        ▼               ▼                    │
│  ┌──────────┐    ┌────────────┐           │
│  │  systemd │───▶│   startx    │           │
│  └──────────┘    └────────────┘           │
│                        │                    │
│                        ▼                    │
│              ┌──────────────────┐          │
│              │  VLC Fullscreen  │          │
│              │   30+ FPS @ 7%   │          │
│              └──────────────────┘          │
│                                             │
│  ┌────────────────────────────────┐        │
│  │        Interface Web           │        │
│  │  ┌──────────┐  ┌────────────┐ │        │
│  │  │  Nginx   │──│  PHP-FPM    │ │        │
│  │  └──────────┘  └────────────┘ │        │
│  │         │            │         │        │
│  │         ▼            ▼         │        │
│  │  ┌──────────────────────────┐ │        │
│  │  │      API REST JSON       │ │        │
│  │  └──────────────────────────┘ │        │
│  └────────────────────────────────┘        │
└─────────────────────────────────────────────┘
```

## Flux de Données

1. **Boot** : 30 secondes jusqu'à la vidéo
2. **Auto-login** : getty@tty1 avec systemd
3. **X démarrage** : .bash_profile → startx
4. **VLC** : .xinitrc → start-video.sh
5. **Web** : Port 80 → Nginx → PHP → API

## Performance

### Métriques Clés
- Boot to video : 30 secondes
- CPU usage : 7% (VLC) + 3% (X.org)
- RAM : ~300MB total
- FPS : 30+ confirmé visuellement

### Optimisations Appliquées
- Pas de window manager (économie 100MB RAM)
- VLC en mode dummy (pas d'UI)
- Configuration GPU par défaut (pas d'overclocking)
- Services inutiles désactivés

## Sécurité

- Interface web en local seulement (pas d'exposition internet)
- Permissions minimales (www-data pour web)
- Pas de services SSH exposés par défaut
- Mises à jour automatiques désactivées

## Fichiers de Configuration

```
/opt/pisignage/
├── scripts/vlc-control.sh     # Contrôle VLC
├── web/index.php              # Interface principale
├── web/api/*.php              # Endpoints API
├── config/playlists.json      # Stockage playlists
├── media/                     # Vidéos
└── logs/                      # Logs système
```
