# Changelog

Tous les changements notables de ce projet seront documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Versioning Sémantique](https://semver.org/lang/fr/).

## [2.0.0] - 2024-09-18

### 🎉 Migration complète vers FullPageOS

### Ajouté
- Support complet de FullPageOS (Bullseye/Buster)
- Script de déploiement automatique (`deploy-to-fullpageos.sh`)
- Outil de maintenance interactif (`maintenance.sh`)
- Diagnostic GPU avancé (`diagnostic-gpu.sh`)
- Script QuickStart tout-en-un (`QUICKSTART.sh`)
- Page HTML optimisée avec monitoring FPS en temps réel
- Documentation complète (Guide, FAQ, README)
- Support de l'accélération GPU hardware (VideoCore VI)
- Configuration automatique des paramètres GPU optimaux

### Changé
- **BREAKING:** Migration de Raspberry Pi OS Bookworm vers FullPageOS
- Architecture complète du projet refactorée
- Passage de 5-6 FPS à 25-30+ FPS garanti
- Utilisation CPU réduite de 90% à 15-30%

### Corrigé
- Problème d'accélération GPU avec Chromium 139 sur Bookworm
- SwiftShader forcé remplacé par GPU hardware natif
- Crashes fréquents de Chromium
- Problèmes de performance vidéo

### Supprimé
- Support de Raspberry Pi OS Bookworm
- Scripts legacy qui ne fonctionnaient pas
- Dépendance à des configurations manuelles complexes

### Obsolète
- Tous les scripts basés sur Bookworm (déplacés dans `legacy-bookworm/`)

## [1.5.0] - 2024-09-18 (Non publié)

### Tenté
- Multiple approches pour faire fonctionner GPU sur Bookworm
- Tests avec VLC, MPV, FFplay
- Différentes configurations Chromium
- Downgrade de versions

### Résultat
- Échec - Bookworm + Chromium 139 = GPU non fonctionnel
- Décision de migrer vers FullPageOS

## [1.0.0] - 2024-09-17

### Version initiale

### Ajouté
- Scripts de déploiement pour Raspberry Pi OS Bookworm
- Configuration Chromium en mode kiosk
- Scripts d'installation automatique
- Documentation de base

### Problèmes connus
- Performance limitée à 5-6 FPS
- Utilisation CPU excessive (90%+)
- Pas d'accélération GPU fonctionnelle
- Chromium force SwiftShader (software rendering)

## [0.1.0] - 2024-09-17

### Prototype initial
- Premiers tests sur Raspberry Pi 4
- Identification du problème GPU
- Recherche de solutions

---

## Légende des changements

- `Ajouté` pour les nouvelles fonctionnalités.
- `Changé` pour les changements dans les fonctionnalités existantes.
- `Obsolète` pour les fonctionnalités qui seront supprimées.
- `Supprimé` pour les fonctionnalités supprimées.
- `Corrigé` pour les corrections de bugs.
- `Sécurité` en cas de vulnérabilités.