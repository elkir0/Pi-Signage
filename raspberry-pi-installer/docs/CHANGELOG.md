# 📝 Changelog - Pi Signage Digital

Tous les changements notables de ce projet sont documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2024-01-20

### 🔐 Sécurité
- **Module de sécurité centralisé** (`00-security-utils.sh`) avec :
  - Chiffrement AES-256-CBC pour les mots de passe stockés
  - Hachage SHA-512 avec salt pour l'authentification
  - Gestion centralisée des permissions
  - Fonctions de validation des entrées
- **Permissions restrictives** sur tous les fichiers sensibles (600/640/750)
- **Protection CSRF** dans l'interface web
- **Headers de sécurité HTTP** (X-Frame-Options, CSP, etc.)
- **Rate limiting** pour les tentatives de connexion

### 🚀 Améliorations
- **Gestion d'erreurs robuste** :
  - Fonction `safe_execute()` avec retry logic
  - Suppression des `|| true` qui masquaient les erreurs
  - Propagation correcte des codes d'erreur
- **Correction des race conditions** :
  - Attente de l'initialisation X11
  - Fonctions `wait_for_service()` et `wait_for_process()`
- **Interface web modulaire** :
  - Séparation du code PHP dans `/web-interface/`
  - Installation depuis GitHub
  - Scripts de mise à jour automatique

### 🏗️ Architecture
- **Nouveau script** : `09-web-interface-v2.sh` qui clone depuis GitHub
- **Structure modulaire** pour l'interface web :
  ```
  web-interface/
  ├── public/      # Fichiers accessibles
  ├── includes/    # Logique PHP et sécurité
  ├── api/         # Points d'accès REST
  ├── assets/      # CSS, JS, images
  └── templates/   # Templates réutilisables
  ```

### 🐛 Corrections
- Renommage du fichier mal nommé `07-services-setup.sh .sh`
- Correction de l'installation d'ImageMagick dans `03-vlc-setup.sh`
- Amélioration du fallback pip/apt dans `05-glances-setup.sh`
- Configuration PHP équilibrée (shell_exec autorisé pour le contrôle des services)

### 📚 Documentation
- Nouveau guide de sécurité (`SECURITY.md`)
- Guide de migration (`MIGRATION.md`)
- README principal mis à jour avec toutes les nouvelles fonctionnalités
- Documentation de l'interface web séparée

## [2.1.0] - 2024-01-15

### ✨ Nouvelles fonctionnalités
- Support officiel du Raspberry Pi 5
- Interface web avec téléchargement YouTube via yt-dlp
- Scripts de mise à jour automatique
- Monitoring amélioré avec Glances

### 🔧 Améliorations
- Installation modulaire permettant de choisir les composants
- Optimisations pour chaque modèle de Pi (3B+, 4B, 5)
- Meilleure gestion de la mémoire GPU
- Logs centralisés dans `/var/log/pi-signage/`

## [2.0.0] - 2024-01-10

### 🎉 Refonte majeure
- Architecture complètement modulaire
- Scripts séparés par fonctionnalité
- Configuration centralisée
- Installation guidée interactive

### 🆕 Nouveautés
- Support de l'authentification Google Drive
- Système de backup/restore
- Watchdog pour surveillance automatique
- Dashboard web de base

### ⚡ Performances
- Temps d'installation réduit (~50 minutes)
- Boot optimisé (<30 secondes)
- Utilisation mémoire optimisée

## [1.5.0] - 2023-12-01

### Ajouts
- Support multi-écrans
- Rotation automatique des vidéos
- Message d'attente personnalisable

### Corrections
- Fix du problème de synchronisation au démarrage
- Amélioration de la stabilité VLC

## [1.0.0] - 2023-10-15

### 🎊 Version initiale
- Installation automatisée pour Raspberry Pi
- Lecture en boucle avec VLC
- Synchronisation manuelle des vidéos
- Configuration basique

---

## Légende

- 🔐 Sécurité
- 🚀 Améliorations
- ✨ Nouvelles fonctionnalités
- 🐛 Corrections de bugs
- 📚 Documentation
- 🏗️ Architecture
- ⚡ Performance
- 🎉 Changements majeurs