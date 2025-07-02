# Changelog

Toutes les modifications notables du projet Pi Signage Digital sont documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.4.6] - 2025-01-02

### 🔒 Sécurité absolue du boot
- **Suppression TOTALE des modifications de boot** : Plus aucune modification de `/boot/config.txt` ni `/boot/cmdline.txt`
- **Script 01-system-config.sh** : Les fonctions `configure_boot_stable()` et `configure_cmdline()` n'écrivent plus rien
- **Conformité stricte** : Respect absolu de la directive "aucune modification du boot"
- **Configuration manuelle** : Instructions pour utiliser `raspi-config` si des ajustements sont nécessaires

### 📝 Modifications
- Fonction `configure_boot_stable()` : Ne fait plus aucune modification
- Fonction `configure_cmdline()` : Ne fait plus aucune modification
- Messages d'information ajoutés pour guider l'utilisateur vers `raspi-config`

### ✨ Nouvelles fonctionnalités
- **Mode test intégré** : Proposé automatiquement après installation Chromium
- **Diagnostic amélioré** : `pi-signage-diag --verify-chromium` pour vérifier la configuration
- **Scripts consolidés** : Toutes les fonctions de test/vérification intégrées dans les scripts principaux
- **Boot manager amélioré** : Gestion des conflits de services (désactive `x11-kiosk` automatiquement)
- **Test touchscreen** : Support intégré pour l'écran tactile officiel Raspberry Pi

## [2.4.5] - 2025-01-01

### 🚨 Corrections critiques
- **Suppression de toutes les modifications de `/boot/config.txt`** : Conformément aux exigences, aucun script ne modifie plus le boot
- **Correction du problème d'écran noir** : Suppression de `hdmi_drive=2` qui causait l'écran noir au démarrage
- **Script de réparation** : `fix-black-screen-boot.sh` pour réparer les systèmes affectés

### 🔧 Fichiers modifiés
- `03-chromium-kiosk.sh` : Suppression de la modification hdmi_drive=2
- `util-configure-audio.sh` : Suppression de la modification hdmi_drive=2

## [2.4.4] - 2025-01-01

### 🔧 Améliorations de robustesse
- **Fonction `safe_apt_install`** : Installation robuste avec récupération automatique
- **Préparation système** : Installation des dépendances critiques avant tout
- **Gestion dpkg améliorée** : Détection et réparation automatique des dépendances cassées
- **Chromium sans DRM** : Installation avec `--no-install-recommends` pour éviter Widevine

### 🐛 Corrections
- Résolution du problème `libgtk-3-common` manquant
- Correction du code retour 0 mal interprété dans `safe_execute`
- Installation des dépendances GTK avant Chromium
- Vérification `apt-get check` pour détecter les problèmes

## [2.4.3] - 2025-01-01

### 🔧 Optimisations de l'installation
- **Consolidation des paquets** : Tous les paquets de base dans `01-system-config.sh`
- **Élimination des redondances** : Plus d'installation multiple des mêmes paquets
- **Audio cohérent** : Activé dès le début (plus de désactivation/réactivation)
- **Détection X11** : Chromium vérifie si X11 est déjà installé
- **Détection services** : Scripts vérifient l'existence des services avant manipulation
- **Performance** : Installation plus rapide et moins d'utilisation réseau

### 🐛 Corrections
- Suppression des installations multiples de curl, git, ffmpeg, jq, etc.
- Un seul script crée `/opt/videos` (au lieu de 10 !)
- Configuration audio cohérente dans tous les scripts
- Glances vérifie les paquets avant installation
- Watchdog détecte dynamiquement les services à surveiller
- Scripts cron vérifient l'existence des services

### 📝 Documentation
- Ajout de `docs/OPTIMIZATIONS.md` détaillant les problèmes corrigés

## [2.4.2] - 2025-01-01

### 🔄 Modifié
- **Installation unifiée** : Suppression de la version LITE, une seule installation stable pour tous
- **Optimisations supprimées** : 
  - Plus d'overclocking ni de modifications GPU agressives
  - Configuration système conservative par défaut
  - Suppression des modifications mémoire risquées
  - Suppression de gpu_mem dans VLC et système
- **Compatibilité améliorée** : Le script `main_orchestrator.sh` fonctionne sur tous les systèmes sans modifications risquées

### 🗑️ Supprimé
- Scripts `install-lite.sh`, `01-system-config-lite.sh`, `02-x11-minimal.sh`
- Documentation `README-LITE.md`
- Toutes les optimisations GPU spécifiques dans `03-chromium-kiosk.sh`
- Fonction `optimize_vlc_pi` remplacée par `configure_vlc_environment`
- Configuration `gpu_mem=128` dans `01-system-config.sh`

### 📝 Notes
Cette version unifie l'installation en supprimant toutes les optimisations qui pouvaient causer des instabilités. Le système utilise maintenant les configurations par défaut du Raspberry Pi, garantissant une meilleure stabilité sur tous les modèles.

## [2.4.1] - 2025-01-01

### 🆕 Ajouté
- **Version LITE** pour Raspberry Pi OS Lite :
  - Script `install-lite.sh` pour installation minimale
  - Configuration système sans modifications agressives
  - Démarrage X11 direct sans display manager
  - Documentation dédiée `README-LITE.md`
- **Scripts de réparation d'urgence** :
  - `fix-boot-order.sh` : Correction rapide des problèmes de boot
  - `emergency-boot-fix.sh` : Réparation depuis un autre PC
  - `deep-boot-fix.sh` : Réparation profonde du système

### 🐛 Corrigé
- **Écran noir sur Raspberry Pi OS Lite** : Suppression de `dtoverlay=vc4-fkms-v3d`
- **Blocage au démarrage** : Services démarrent progressivement via `10-boot-manager`
- **Conflits systemd-tmpfiles** : Utilisation de `/var/cache` au lieu de `/tmp`

### 🔄 Modifié
- **Services systemd** : Dépendances simplifiées (`After=multi-user.target`)
- **LightDM** : Désactivé au boot, démarre via le gestionnaire de démarrage
- **Configuration boot** : Paramètres minimaux pour éviter les conflits

## [2.4.0] - 2025-01-01

### 🆕 Ajouté
- **Support audio complet** : 
  - Configuration HDMI/Jack avec `util-configure-audio.sh`
  - Volume réglable, 85% par défaut
  - Autoplay avec son dans Chromium
  - Script de test audio `util-test-audio.sh`
- **Page de gestion de playlist** (`playlist.php`) :
  - Organisation de l'ordre de lecture
  - Sélection des vidéos à diffuser
  - Sauvegarde automatique
- **Logo Pi Signage** :
  - Intégration dans toute l'interface web
  - Favicon et meta tags
  - Page de connexion avec logo
- **API player.php** :
  - Contrôle complet du player (play, pause, stop, next)
  - Mise à jour de playlist à distance
  - Support VLC et Chromium
- **Scripts utilitaires** :
  - `util-test-playlist.sh` : Vérification de la playlist
  - `util-configure-audio.sh` : Configuration audio interactive
  - `util-test-audio.sh` : Test du son
  - `dpkg-health-check.sh` : Vérification et réparation automatique de dpkg
- **Gestion robuste des erreurs dpkg** :
  - Détection automatique des problèmes dpkg au démarrage
  - Réparation automatique des verrous et paquets non configurés
  - Support spécifique pour Raspberry Pi après interruptions

### 🔄 Modifié
- **Téléchargement YouTube** :
  - Format MP4 forcé pour compatibilité Chromium
  - Sélection de la meilleure qualité (bestvideo+bestaudio)
  - Verbose persistant avec bouton de fermeture
- **Player HTML5** :
  - Suppression de l'attribut muted
  - Ajout des contrôles vidéo
  - Bouton play si autoplay bloqué
- **Interface web** :
  - Navigation avec nouveau menu Playlist
  - Mise à jour automatique après upload/téléchargement
  - Amélioration du feedback utilisateur

### 🐛 Corrigé
- **Erreur 400** : youtube_progress.php retourne toujours succès
- **Format vidéo** : Plus de fichiers MKV, seulement MP4
- **Mise à jour playlist** : Automatique après upload
- **Bouton update_playlist** : Action corrigée dans settings.php
- **API player.php** : Création du fichier manquant

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