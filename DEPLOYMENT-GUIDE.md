# 🚀 PiSignage v0.9.0 - Guide de Déploiement Automatisé

## 📋 Vue d'Ensemble

Ce guide détaille le système de déploiement automatisé **idiot-proof** pour PiSignage v0.9.0 sur Raspberry Pi OS Bullseye fraîchement installé.

### ✨ Caractéristiques

- **Déploiement One-Click** : Une seule commande pour tout installer
- **Tests Automatiques** : Validation complète à chaque étape
- **Rollback Automatique** : Retour arrière en cas de problème
- **Monitoring Continu** : Surveillance système en temps réel
- **Optimisé Raspberry Pi 4** : Configuration GPU pour 30+ FPS
- **Sauvegardes Automatiques** : Protection des données existantes

## 🎯 Prérequis

### Matériel Recommandé
- **Raspberry Pi 4** (4GB RAM minimum recommandé)
- **Carte SD** : 32GB minimum, Classe 10
- **Connexion Internet** stable
- **Écran HDMI** pour l'affichage

### Système
- **Raspberry Pi OS Bullseye** (32-bit ou 64-bit)
- **SSH activé** sur le Raspberry Pi
- **Utilisateur pi** avec mot de passe `raspberry`
- **IP fixe configurée** : `192.168.1.103`

### Machine de Développement
- **sshpass** installé : `sudo apt-get install sshpass`
- **Accès réseau** au Raspberry Pi
- **Git** (pour cloner le projet)

## 🔧 Installation Rapide

### Étape 1 : Préparer la Machine de Développement

```bash
# Cloner le projet
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage

# Ou utiliser un répertoire existant
cd /opt/pisignage
```

### Étape 2 : Déploiement One-Click

```bash
# Déploiement standard
./deploy.sh

# Déploiement avec IP personnalisée
./deploy.sh --ip 192.168.1.104

# Déploiement en mode verbeux
./deploy.sh --verbose deploy
```

### Étape 3 : Validation

L'interface sera accessible à : **http://192.168.1.103**

## 📚 Utilisation Avancée

### Commandes Principales

```bash
# Déploiement complet
./deploy.sh deploy

# Vérifications uniquement
./deploy.sh verify

# Installation packages uniquement
./deploy.sh install

# Configuration système uniquement
./deploy.sh configure

# Tests post-déploiement uniquement
./deploy.sh test

# Rollback automatique
./deploy.sh rollback

# Monitoring continu
./deploy.sh monitor
```

### Options Disponibles

```bash
-h, --help         Afficher l'aide
-v, --verbose      Mode verbeux (logs détaillés)
-d, --dry-run      Simulation sans modifications
-f, --force        Forcer l'installation
-s, --skip-backup  Ignorer les sauvegardes
--ip IP            IP du Raspberry Pi (défaut: 192.168.1.103)
--user USER        Utilisateur SSH (défaut: pi)
--pass PASS        Mot de passe SSH (défaut: raspberry)
```

## 🔍 Scripts de Déploiement

### Structure des Scripts

```
deployment/scripts/
├── pre-checks.sh       # Vérifications pré-déploiement
├── backup-system.sh    # Sauvegarde système complète
├── install-packages.sh # Installation packages optimisés
├── configure-system.sh # Configuration système et GPU
├── deploy-app.sh       # Déploiement application
├── post-tests.sh       # Tests automatiques complets
├── rollback.sh         # Système de rollback
└── monitor.sh          # Monitoring post-déploiement
```

### Détail des Étapes

#### 1. Vérifications Pré-Déploiement (`pre-checks.sh`)

- Vérification OS (Raspberry Pi OS Bullseye recommandé)
- Ressources système (RAM ≥1GB, Disque ≥2GB)
- Connectivité réseau et DNS
- Permissions et utilisateurs
- Services système et packages critiques
- GPU et configuration d'affichage

#### 2. Sauvegarde Système (`backup-system.sh`)

- Sauvegarde application existante
- Sauvegarde configurations (nginx, PHP, systemd)
- Sauvegarde données utilisateur (médias, logs)
- Création manifeste de sauvegarde
- Script de rollback automatique
- Nettoyage sauvegardes anciennes (garde 5 dernières)

#### 3. Installation Packages (`install-packages.sh`)

- Mise à jour système
- **Nginx** optimisé pour Raspberry Pi
- **PHP 7.4** avec extensions requises
- **Chromium** avec dépendances X11
- **Node.js 18** (pour outils développement)
- **Packages multimédia** (VLC, FFmpeg, etc.)
- **Dépendances GPU** pour accélération

#### 4. Configuration Système (`configure-system.sh`)

- **Configuration boot Raspberry Pi** :
  - GPU memory : 128MB
  - Driver VC4-FKMS-V3D
  - Overclock GPU : 500MHz
  - Configuration HDMI optimisée
- **Configuration Nginx** :
  - Virtual host PiSignage
  - Optimisations Raspberry Pi
  - Gzip, cache, sécurité
- **Configuration PHP** :
  - Limites augmentées (256MB, 300s)
  - OPcache optimisé
  - PHP-FPM ondemand
- **Services systemd** :
  - Service PiSignage principal
  - Service Chromium Kiosk
  - Service monitoring
- **Auto-login et kiosk** :
  - Login automatique utilisateur pi
  - Démarrage automatique X11
  - Mode kiosk Chromium optimisé

#### 5. Déploiement Application (`deploy-app.sh`)

- Copie fichiers application
- Création scripts de contrôle
- Interface web responsive avec APIs
- Configuration permissions finales
- Démarrage services

#### 6. Tests Post-Déploiement (`post-tests.sh`)

- **Tests services** : nginx, php-fpm, pisignage
- **Tests structure** : fichiers et répertoires requis
- **Tests HTTP** : accessibilité interface et APIs
- **Tests JSON** : validation APIs fonctionnelles
- **Tests performance** : temps de réponse < 2s
- **Tests GPU** : driver VC4, configuration
- **Tests sécurité** : permissions, headers
- **Tests Puppeteer** : validation interface (si disponible)

## 🔄 Système de Rollback

### Rollback Automatique

```bash
# Rollback interactif (liste les sauvegardes)
./deployment/scripts/rollback.sh

# Rollback automatique (plus récente)
./deployment/scripts/rollback.sh --auto

# Rollback vers sauvegarde spécifique
./deployment/scripts/rollback.sh --backup /opt/pisignage-backups/backup-20250922-150000
```

### Fonctionnalités Rollback

- **Détection automatique** des sauvegardes disponibles
- **Validation** de l'intégrité des sauvegardes
- **Sauvegarde d'urgence** avant rollback
- **Restauration complète** : app + config + données
- **Tests automatiques** post-rollback
- **Scripts dédiés** de rollback par sauvegarde

## 📊 Monitoring Post-Déploiement

### Lancement du Monitoring

```bash
# Monitoring continu
./deployment/scripts/monitor.sh

# Rapport de santé unique
./deployment/scripts/monitor.sh --report

# Vérification unique
./deployment/scripts/monitor.sh --check

# Intervalle personnalisé (30 secondes)
./deployment/scripts/monitor.sh --interval 30
```

### Métriques Surveillées

- **Température CPU** (seuils : 70°C warning, 80°C critical)
- **Charge système** (seuils : 2.0 warning, 4.0 critical)
- **Mémoire** (seuils : 80% warning, 90% critical)
- **Espace disque** (seuils : 80% warning, 90% critical)
- **Services** (nginx, php-fpm, pisignage)
- **Interface web** (accessibilité et temps de réponse)
- **APIs** (fonctionnalité JSON)
- **Réseau** (connectivité Internet)
- **GPU** (driver VC4, mémoire)

### Alertes Automatiques

- **Cooldown** : 5 minutes entre alertes du même type
- **Logs structurés** : `/opt/pisignage/logs/alerts.log`
- **Niveaux** : WARNING, CRITICAL
- **Extensible** : webhook, email (à configurer)

## 🎨 Interface Web

### Fonctionnalités

- **Dashboard** responsive avec glassmorphism
- **Gestion médias** : upload, parcours, galerie
- **Playlists** et programmation
- **Capture d'écran** temps réel
- **APIs REST** complètes
- **Monitoring** intégré
- **Configuration** système

### APIs Disponibles

- **`/api/system.php`** : Informations système et services
- **`/api/media.php`** : Gestion fichiers médias
- **`/api/playlist.php`** : Gestion playlists
- **`/api/screenshot.php`** : Capture d'écran
- **`/api/upload.php`** : Upload fichiers

## ⚡ Optimisations Raspberry Pi 4

### Configuration GPU

```bash
# /boot/config.txt
gpu_mem=128
dtoverlay=vc4-fkms-v3d
gpu_freq=500
hdmi_group=2
hdmi_mode=82
```

### Chromium Kiosk Optimisé

```bash
# Options Chromium pour 30+ FPS
--enable-gpu
--enable-gpu-memory-buffer-compositor-resources
--enable-accelerated-2d-canvas
--enable-accelerated-video-decode
--force-gpu-mem-available-mb=64
--max_old_space_size=128
```

### PHP Optimisé

```php
// Configuration PHP pour Raspberry Pi
memory_limit = 256M
max_execution_time = 300
pm = ondemand
pm.max_children = 3
opcache.memory_consumption = 64MB
```

## 🔧 Dépannage

### Problèmes Courants

#### Interface Web Non Accessible

```bash
# Vérifier les services
sudo systemctl status nginx php7.4-fpm pisignage

# Redémarrer les services
sudo systemctl restart nginx php7.4-fpm

# Vérifier les logs
sudo journalctl -u nginx -f
```

#### Mode Kiosk Non Fonctionnel

```bash
# Vérifier X11
echo $DISPLAY
xset q

# Vérifier le service kiosk
sudo systemctl status pisignage-kiosk

# Redémarrer X11
sudo systemctl restart lightdm
```

#### Performance Lente

```bash
# Vérifier la température
vcgencmd measure_temp

# Vérifier la charge
htop

# Vérifier la configuration GPU
vcgencmd get_mem gpu
lsmod | grep vc4
```

### Logs Utiles

```bash
# Logs déploiement
/tmp/pisignage-deploy-*.log

# Logs application
/opt/pisignage/logs/system.log
/opt/pisignage/logs/error.log

# Logs monitoring
/opt/pisignage/logs/monitor.log
/opt/pisignage/logs/alerts.log

# Logs système
sudo journalctl -u pisignage -f
sudo journalctl -u nginx -f
```

## 🚀 Mise en Production

### Checklist Pré-Production

- [ ] Tests complets réussis (post-tests.sh)
- [ ] Interface accessible et responsive
- [ ] Mode kiosk fonctionnel
- [ ] Monitoring actif
- [ ] Sauvegardes configurées
- [ ] Performance optimale (< 2s)
- [ ] Température normale (< 70°C)
- [ ] Tous les services actifs

### Déploiement Production

```bash
# Déploiement standard production
./deploy.sh deploy

# Validation complète
./deploy.sh test

# Démarrage monitoring
./deploy.sh monitor &

# Validation finale
curl -s http://192.168.1.103 | grep "PiSignage"
```

### Maintenance

```bash
# Rapport de santé hebdomadaire
./deployment/scripts/monitor.sh --report

# Nettoyage logs mensuels
find /opt/pisignage/logs -name "*.log" -mtime +30 -delete

# Mise à jour système
sudo apt-get update && sudo apt-get upgrade

# Vérification espace disque
df -h /opt/pisignage
```

## 📞 Support

### Informations Système

```bash
# Version PiSignage
cat /opt/pisignage/VERSION

# Informations système
/opt/pisignage/deployment/scripts/monitor.sh --report

# État des services
systemctl list-units | grep pisignage
```

### Contact

- **GitHub** : https://github.com/elkir0/Pi-Signage
- **Documentation** : README.md dans le projet
- **Logs** : Consultez les logs détaillés pour diagnostic

---

## 🎉 Conclusion

Le système de déploiement PiSignage v0.9.0 est conçu pour être **idiot-proof** et fournir une installation complète, optimisée et surveillée en une seule commande.

**Commande magique** : `./deploy.sh`

**Résultat** : Interface PiSignage opérationnelle sur http://192.168.1.103 avec surveillance continue.

Bon déploiement ! 🚀