# 📺 PiSignage - Affichage Digital sur Raspberry Pi

## Description du projet
PiSignage est un système d'affichage digital (digital signage) conçu pour Raspberry Pi, permettant de diffuser des contenus multimédias (vidéos, images) en boucle sur un écran. Version stable officielle : v0.8.0.

## Objectifs principaux
- ✅ Lecture en boucle de vidéos et images via VLC
- ✅ Interface web de gestion accessible à distance
- ✅ APIs pour le contrôle du système
- ✅ Gestion de playlists personnalisables
- ✅ Téléchargement de vidéos YouTube
- ✅ Capture d'écran du contenu affiché
- ✅ Configuration flexible

## Stack technique
- **Backend** : PHP 8.2 (version stable après migration depuis Next.js)
- **Serveur web** : Nginx
- **Lecteur média** : VLC
- **Système** : Raspberry Pi OS
- **Scripts** : Bash pour automatisation
- **APIs** : REST APIs en PHP
- **Interface** : HTML/CSS/JavaScript vanilla

## Architecture globale
```
/opt/pisignage/          # Racine du projet
├── web/                 # Interface web et APIs
│   ├── index.php       # Point d'entrée principal
│   └── api/            # Endpoints API
├── scripts/            # Scripts système
├── media/              # Stockage des médias
├── config/             # Configuration
└── logs/               # Journalisation
```

## Environnement de production
- **Plateforme** : Raspberry Pi
- **IP Production** : 192.168.1.103
- **Port** : 80 (HTTP)
- **Services actifs** : nginx, php8.2-fpm, vlc

## État actuel
- **Version** : v0.8.0 (SEULE VERSION OFFICIELLE)
- **GitHub** : https://github.com/elkir0/Pi-Signage
- **Status** : Prêt pour production, en attente de déploiement final sur Raspberry Pi