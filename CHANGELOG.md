# Changelog

Toutes les modifications notables du projet Pi Signage Digital sont documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.3.0] - 2024-01-30

### 🆕 Ajouté
- **Mode Chromium Kiosk** : Alternative moderne et légère à VLC
  - Consommation mémoire réduite (~250MB vs ~350MB)
  - Démarrage plus rapide (~25s vs ~45s)
  - Support natif HTML5, CSS animations et JavaScript
  - Player HTML5 avec interface moderne
  - WebSocket pour contrôle temps réel
  - API REST pour gestion de playlist
- **Support VM/Headless** : Installation avec Xvfb pour tests sur VM (QEMU, UTM, VirtualBox)
  - Détection automatique de l'environnement VM
  - Installation et configuration Xvfb automatique
  - Mode headless pour développement et tests
- **Pages web manquantes** :
  - `videos.php` : Interface complète de gestion vidéos avec upload et YouTube
  - `settings.php` : Page de paramètres système avec contrôle services
- **Script `install.sh`** : Nouveau point d'entrée avec sélection du mode d'affichage
- **Comparaison interactive** : Aide au choix entre VLC et Chromium lors de l'installation
- **Scripts d'administration Chromium** :
  - `player-control.sh` : Contrôle du player (play, pause, next, etc.)
  - `update-playlist.sh` : Mise à jour automatique de la playlist
- **Documentation** : 
  - Guide de dépannage complet (`troubleshooting.md`)
  - Documentation Chromium dans `CHROMIUM_KIOSK_PROPOSAL.md`

### 🔄 Modifié
- **Installation modulaire** : Adaptation automatique selon le mode choisi
- **Interface web** : 
  - Détection du mode d'affichage pour adapter les contrôles
  - Utilisation de chemins absolus avec `dirname(__DIR__)` 
  - Harmonisation authentification SHA-512 entre bash et PHP
- **Documentation** : Mise à jour complète pour refléter les deux modes et corrections
- **README** : Ajout changelog v2.3.0, sections VM/Headless, état stable

### 🐛 Corrigé
- **PHP 8.2** : Suppression du package `php8.2-json` inexistant (JSON intégré)
- **Permissions** :
  - Changement 750→755 pour meilleure compatibilité
  - Ownership `/opt/videos` : signage→www-data
  - Ajout chmod 755 sur `/opt/scripts` dans l'installation
- **Authentification** : Harmonisation SHA-512 format `salt:hash` entre bash et PHP
- **Utilisateur signage** : Ajout flag `-m` pour création du home directory
- **Glances** : Suppression section `[network]` dupliquée
- **Chemins PHP** : Migration vers chemins absolus pour éviter erreurs relatives
- **Assets** : Création automatique de la structure si manquante

### 🛠️ Technique
- Support X11 minimal pour Chromium (sans gestionnaire de fenêtres)
- Optimisations spécifiques par modèle de Pi
- Cache Chromium en RAM pour performances
- Nginx pour servir le player HTML5 local
- Xvfb pour support headless/VM

## [2.2.0] - 2024-01-19

### 🔐 Sécurité
- **Module de sécurité centralisé** (`00-security-utils.sh`)
  - Chiffrement AES-256-CBC pour les mots de passe
  - Hachage SHA-512 avec salt
  - Validation robuste des entrées
  - Journalisation des événements de sécurité
- **Gestion d'erreurs améliorée**
  - Retry logic pour opérations réseau
  - Récupération automatique en cas d'échec
  - Logs détaillés pour debug
- **Permissions renforcées**
  - 600 pour fichiers sensibles
  - 750 pour répertoires système
  - Utilisateur système dédié 'signage'

### 🔄 Modifié
- Refactoring complet des scripts d'installation
- Migration de l'interface web vers GitHub
- Amélioration de la gestion des services

### 🐛 Corrigé
- Race conditions au démarrage des services
- Problèmes de permissions sur certains fichiers
- Échecs silencieux masqués par `|| true`

## [2.1.0] - 2024-01-18

### 🆕 Ajouté
- Interface web complète avec:
  - Dashboard moderne
  - Gestion des vidéos
  - Téléchargement YouTube via yt-dlp
  - Monitoring système
  - Contrôle des services
- Installation modulaire interactive
- Support multi-Pi (3B+, 4B, 5)

### 🔄 Modifié
- Architecture modulaire des scripts
- Amélioration des performances VLC
- Documentation complète

## [2.0.0] - 2024-01-15

### 🎉 Refonte majeure
- Nouvelle architecture complète
- Scripts modulaires
- Interface web from scratch
- Sécurité renforcée
- Documentation exhaustive

## [1.0.0] - 2023-12-01

### 🚀 Version initiale
- Player VLC basique
- Synchronisation Google Drive
- Scripts monolithiques
- Configuration manuelle

---

## Légende des emojis
- 🆕 Nouvelles fonctionnalités
- 🔄 Modifications
- 🐛 Corrections de bugs
- 🔐 Sécurité
- 🛠️ Changements techniques
- 📚 Documentation
- 🎉 Changements majeurs
- ⚠️ Changements non rétro-compatibles