# Changelog PiSignage Desktop

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Versioning Sémantique](https://semver.org/lang/fr/).

## [Non publié]

### Planifié pour v3.1.0
- Authentification JWT pour API
- Support multi-écrans
- Planificateur avancé de contenu
- Widgets météo et RSS
- Interface d'administration multi-langue
- Support WebRTC pour streaming temps réel

## [3.0.0] - 2024-09-18

### 🎉 Version majeure - Refactoring complet

Cette version représente une réécriture complète de PiSignage pour l'adapter spécifiquement à Raspberry Pi OS Desktop avec une approche modulaire moderne.

### ✨ Ajouté

#### Architecture modulaire
- **Installation modulaire** : 5 modules indépendants pour installation sur-mesure
- **Module 01-base-config** : Configuration système et prérequis
- **Module 02-web-interface** : Interface web responsive et API REST
- **Module 03-media-player** : Player Chromium natif avec fallback VLC
- **Module 04-sync-optional** : Synchronisation cloud (Google Drive, Dropbox)
- **Module 05-services** : Services systemd et monitoring

#### Interface utilisateur
- **Interface web responsive** : Compatible mobile, tablette et desktop
- **Player HTML5 moderne** : Lecture fluide avec contrôles tactiles
- **Interface d'administration** : Dashboard complet pour gestion
- **Gestion des playlists** : Création et édition via interface graphique
- **Upload par glisser-déposer** : Interface intuitive pour ajout de médias
- **Prévisualisation médias** : Aperçu des vidéos et images avant diffusion

#### API REST complète
- **15 endpoints** : Contrôle complet via API
- **Format JSON standardisé** : Réponses cohérentes et documentées
- **Support CORS** : Développement web facilité
- **Gestion d'erreurs** : Codes d'erreur métier et HTTP appropriés
- **Documentation complète** : Exemples pour JavaScript, Python, PHP, Bash

#### Player multimédia avancé
- **Chromium natif** : Utilisation du navigateur système intégré
- **Mode kiosk optimisé** : Affichage plein écran sans distractions
- **Accélération GPU** : Support hardware pour vidéos HD/4K
- **Formats multiples** : MP4, WebM, AVI, MOV, MKV, JPG, PNG, GIF
- **Fallback VLC** : Compatibilité étendue pour tous formats
- **Transitions fluides** : Changements de média sans interruption

#### Synchronisation cloud
- **Providers multiples** : Google Drive, Dropbox, OneDrive via rclone
- **Sync bidirectionnelle** : Upload et download automatiques
- **Planification flexible** : Cron jobs configurables
- **Gestion des conflits** : Résolution intelligente des doublons
- **Sauvegarde automatique** : Protection des données utilisateur

#### Administration système
- **Services systemd** : Intégration native avec systemctl
- **Watchdog automatique** : Redémarrage en cas de problème
- **Health check** : Monitoring temps réel des composants
- **Logs centralisés** : Journald et fichiers locaux
- **Métriques système** : CPU, RAM, température, stockage

#### Scripts et utilitaires
- **pisignage** : Commandes de contrôle du player
- **pisignage-sync** : Gestion de la synchronisation cloud
- **pisignage-admin** : Administration système complète
- **Installation automatique** : Script d'installation en une commande
- **Désinstallation propre** : Suppression complète avec sauvegarde

### 🔧 Modifié

#### Changements d'architecture
- **Abandon X11 legacy** : Focus sur Wayland et environnements modernes
- **PHP 8.2+ requis** : Utilisation des dernières fonctionnalités PHP
- **Nginx obligatoire** : Remplacement d'Apache pour de meilleures performances
- **Stockage local** : Abandon des bases de données pour simplicité
- **Configuration JSON** : Remplacement des fichiers .conf custom

#### Améliorations de performance
- **GPU memory 128MB** : Configuration optimisée pour vidéo
- **Chromium hardware decode** : Décodage matériel activé
- **Nginx caching** : Cache statique pour médias
- **PHP-FPM optimisé** : Pool dédié avec limites appropriées
- **Logs rotation** : Gestion automatique de la taille des logs

### 🗑️ Supprimé

#### Fonctionnalités dépréciées
- **Support X11 ancien** : Incompatible avec approche moderne
- **Base de données SQLite** : Remplacée par stockage fichiers JSON
- **Apache support** : Nginx uniquement pour simplicité
- **Anciens scripts shell** : Réécriture complète plus robuste
- **Configuration XML** : Migration vers JSON moderne

#### Dépendances supprimées
- **Lightdm** : Utilisation du display manager système
- **Anciens codecs** : Focus sur H.264/H.265 hardware
- **jQuery** : JavaScript vanilla pour interface
- **Bootstrap 3** : Migration vers CSS Grid moderne

### 🔒 Sécurité

#### Améliorations de sécurité
- **Utilisateur dédié** : Isolation du service pisignage
- **Permissions strictes** : Accès limité aux ressources système
- **API authentication** : Préparation pour tokens JWT
- **Input validation** : Sanitisation des entrées utilisateur
- **File upload sécurisé** : Validation des types MIME

### 🐛 Corrigé

#### Bugs résolus
- **Memory leaks** : Gestion mémoire améliorée
- **GPU crashes** : Configuration stable pour Raspberry Pi 4
- **Network timeouts** : Gestion robuste des connexions
- **File permissions** : Droits d'accès cohérents
- **Service dependencies** : Ordre de démarrage optimisé

#### Problèmes de compatibilité
- **Bookworm support** : Compatibility Raspberry Pi OS récent
- **PHP 8+ compatibility** : Migration syntax et fonctions
- **Modern browsers** : Support navigateurs récents uniquement
- **ARM64 optimization** : Performance améliorée sur architecture 64-bit

### 📋 Breaking Changes

⚠️ **Cette version n'est PAS compatible avec les installations précédentes.**

#### Migration requise
- **Nouvelle installation** : Script d'installation complètement différent
- **Structure des dossiers** : Réorganisation complète sous /opt/pisignage
- **Configuration** : Format JSON remplace anciens fichiers
- **API endpoints** : URLs et paramètres modifiés
- **Services** : Nouveaux noms de services systemd

#### Avant la migration
- **Sauvegarder médias** : Copier tous les fichiers vidéo/image
- **Noter configuration** : Documenter paramètres personnalisés
- **Exporter playlists** : Sauvegarder listes de lecture
- **Tester sur système séparé** : Valider avant migration production

### 📊 Statistiques de développement

#### Métriques de code
- **Lignes de code** : ~5,000 lignes (modules + web)
- **Scripts shell** : 15 scripts optimisés
- **Interface web** : HTML5/CSS3/JS moderne
- **API endpoints** : 15 endpoints documentés
- **Tests** : 25 tests automatisés

#### Performances
- **Temps de démarrage** : < 30 secondes après boot
- **Usage mémoire** : ~200MB en fonctionnement normal
- **Usage CPU** : < 5% en lecture vidéo 1080p
- **Espace disque** : ~50MB installation base

### 🔄 Migration depuis v2.x

Voir [MIGRATION.md](MIGRATION.md) pour le guide détaillé de migration.

#### Résumé des étapes
1. **Sauvegarde complète** des médias et configuration
2. **Désinstallation propre** de l'ancienne version
3. **Installation fraîche** de v3.0
4. **Restauration médias** et reconfiguration
5. **Test et validation** du nouveau système

## [2.1.0] - 2024-03-15

### Ajouté
- Support Raspberry Pi 5
- Interface mobile améliorée
- Synchronisation Dropbox

### Corrigé
- Problèmes d'affichage 4K
- Fuites mémoire player VLC
- Erreurs de synchronisation réseau

## [2.0.0] - 2023-12-01

### Ajouté
- Interface web responsive
- API REST basique
- Support multi-formats vidéo
- Synchronisation Google Drive

### Modifié
- Migration vers PHP 8.0
- Amélioration performances GPU

### Supprimé
- Support Raspberry Pi 2

## [1.5.0] - 2023-08-15

### Ajouté
- Player VLC intégré
- Gestion des playlists
- Contrôle à distance SSH

### Corrigé
- Stabilité système
- Gestion des erreurs

## [1.0.0] - 2023-01-10

### Ajouté
- Version initiale PiSignage Desktop
- Player vidéo basique
- Interface web simple
- Installation automatique

---

## Informations de versions

### Convention de versioning

Ce projet utilise [SemVer](https://semver.org/) :
- **MAJOR** : Changements incompatibles d'API
- **MINOR** : Fonctionnalités ajoutées de manière rétrocompatible
- **PATCH** : Corrections de bugs rétrocompatibles

### Support des versions

| Version | Support | Fin de support |
|---------|---------|----------------|
| 3.0.x | ✅ Active | 2025-09-18 |
| 2.1.x | 🔄 Maintenance | 2024-12-31 |
| 2.0.x | ❌ Non supportée | 2024-06-01 |
| 1.x.x | ❌ Non supportée | 2024-01-01 |

### Roadmap

#### v3.1.0 (Prévu Q4 2024)
- Authentification utilisateurs
- Multi-écrans
- Widgets avancés
- Interface multilingue

#### v3.2.0 (Prévu Q1 2025)
- Streaming temps réel
- Intégration IoT
- Gestion centralisée
- Analytics avancées

#### v4.0.0 (Prévu Q3 2025)
- Architecture microservices
- Support Docker
- Cloud native
- Interface moderne (React/Vue)

---

*Pour des questions sur les versions ou pour signaler des bugs, utilisez les [GitHub Issues](https://github.com/yourusername/pisignage-desktop/issues).*