# 🚀 PiSignage v0.9.0 - Système de Déploiement Automatisé

## 📋 Déploiement One-Click

```bash
# Commande magique - déploiement complet
./deploy.sh

# Avec IP personnalisée
./deploy.sh --ip 192.168.1.104

# Mode verbeux pour debugging
./deploy.sh --verbose deploy
```

## 🔧 Scripts Disponibles

### Script Principal
- **`deploy.sh`** - Script de déploiement principal avec toutes les options

### Scripts Modulaires
- **`pre-checks.sh`** - Vérifications pré-déploiement (OS, ressources, network)
- **`backup-system.sh`** - Sauvegarde complète avec rollback automatique
- **`install-packages.sh`** - Installation packages optimisés (Nginx, PHP, Chromium)
- **`configure-system.sh`** - Configuration système et GPU Raspberry Pi
- **`deploy-app.sh`** - Déploiement application PiSignage
- **`post-tests.sh`** - Tests automatiques complets (9 catégories)
- **`rollback.sh`** - Système de rollback intelligent
- **`monitor.sh`** - Monitoring continu post-déploiement

## ⚡ Fonctionnalités Clés

### Déploiement Intelligent
- ✅ **Idiot-proof** - Fonctionne du premier coup
- ✅ **Vérifications automatiques** - Validation à chaque étape
- ✅ **Sauvegardes automatiques** - Protection des données
- ✅ **Rollback automatique** - Retour arrière en cas d'échec
- ✅ **Tests complets** - Validation fonctionnelle

### Optimisations Raspberry Pi 4
- ✅ **GPU VC4** - Configuration optimisée pour 30+ FPS
- ✅ **Chromium Kiosk** - Mode plein écran optimisé
- ✅ **PHP 7.4** - Configuration allégée pour Pi
- ✅ **Nginx** - Serveur web optimisé
- ✅ **Services systemd** - Démarrage automatique

### Monitoring Avancé
- ✅ **Surveillance continue** - Métriques système temps réel
- ✅ **Alertes automatiques** - Détection problèmes
- ✅ **Rapports de santé** - État complet du système
- ✅ **Logs structurés** - Debugging facilité

## 🎯 Usage Rapide

### Installation Standard
```bash
cd /opt/pisignage
./deploy.sh deploy
```

### Vérifications Seulement
```bash
./deploy.sh verify
```

### Rollback d'Urgence
```bash
./deploy.sh rollback
```

### Monitoring Continu
```bash
./deploy.sh monitor
```

## 📊 Résultats Attendus

Après déploiement réussi :
- 🌐 **Interface accessible** : http://192.168.1.103
- ⚡ **Performance optimisée** : < 2s temps de réponse
- 🔧 **Services actifs** : nginx, php-fpm, pisignage
- 📱 **Interface responsive** : Dashboard moderne
- 🎮 **Mode kiosk** : Chromium plein écran
- 📊 **Monitoring** : Surveillance automatique

## 🔧 Dépannage Express

```bash
# Vérifier les services
sudo systemctl status nginx php7.4-fpm pisignage

# Voir les logs de déploiement
ls -la /tmp/pisignage-*.log

# Tests manuels
curl -s http://localhost | grep PiSignage
```

## 📞 Support

Consultez le **DEPLOYMENT-GUIDE.md** pour la documentation complète.

**Commande magique** : `./deploy.sh` 🪄