# Changelog

Toutes les modifications notables du projet Pi Signage Digital sont documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.3.0] - 2024-01-20

### 🆕 Ajouté
- **Mode Chromium Kiosk** : Alternative moderne et légère à VLC
  - Consommation mémoire réduite (~250MB vs ~350MB)
  - Démarrage plus rapide (~25s vs ~45s)
  - Support natif HTML5, CSS animations et JavaScript
  - Player HTML5 avec interface moderne
  - WebSocket pour contrôle temps réel
  - API REST pour gestion de playlist
- **Script `main_orchestrator_v2.sh`** : Nouveau script principal avec sélection du mode d'affichage
- **Comparaison interactive** : Aide au choix entre VLC et Chromium lors de l'installation
- **Scripts d'administration Chromium** :
  - `player-control.sh` : Contrôle du player (play, pause, next, etc.)
  - `update-playlist.sh` : Mise à jour automatique de la playlist
- **Documentation Chromium** : Guide complet dans `CHROMIUM_KIOSK_PROPOSAL.md`

### 🔄 Modifié
- **Installation modulaire** : Adaptation automatique selon le mode choisi
- **Interface web** : Détection du mode d'affichage pour adapter les contrôles
- **Documentation** : Mise à jour complète pour refléter les deux modes
- **README** : Ajout des sections Chromium et comparaison des modes

### 🛠️ Technique
- Support X11 minimal pour Chromium (sans gestionnaire de fenêtres)
- Optimisations spécifiques par modèle de Pi
- Cache Chromium en RAM pour performances
- Nginx pour servir le player HTML5 local

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