# Optimisations de l'installation Pi Signage v2.4.3

## Problèmes identifiés et corrigés

### 1. ❌ Audio désactivé puis réactivé
**Problème** : 
- `01-system-config.sh` désactivait l'audio avec `dtparam=audio=off`
- `03-chromium-kiosk.sh` le réactivait ensuite

**Solution** : Audio activé dès le début dans `01-system-config.sh` avec `dtparam=audio=on`

### 2. ❌ Paquets installés plusieurs fois
**Problème** : Plusieurs scripts installaient les mêmes paquets
- `curl` : scripts 01 et 05
- `git` : scripts 01 et 09
- `ffmpeg` : scripts 03-vlc et 09
- `jq` : scripts 01 et 03-chromium
- `python3-pip` : scripts 01 et 09
- `alsa-utils` : scripts 01 et 03-chromium

**Solution** : Consolidation dans `01-system-config.sh` qui installe maintenant :
- Tous les outils système de base
- ffmpeg, jq, bc, net-tools, python3, python3-pip, alsa-utils

### 3. ❌ Paquets X11 en double
**Problème** : 
- `02-display-manager.sh` installe tous les paquets X11
- `03-chromium-kiosk.sh` les réinstallait

**Solution** : `03-chromium-kiosk.sh` vérifie maintenant si X11 est déjà installé avant d'installer

### 4. ❌ Création multiple de /opt/videos
**Problème** : 10 scripts différents créaient le même répertoire !

**Solution** : 
- Création unique dans `01-system-config.sh`
- Les autres scripts vérifient l'existence avant d'agir

### 5. ❌ Services contradictoires
**Problème** : 
- Installation possible de VLC ET Chromium simultanément
- lightdm activé puis désactivé

**Solution partielle** : Le choix dans `main_orchestrator.sh` empêche déjà l'installation des deux

## Ordre d'installation optimisé

1. **01-system-config.sh** : Base système + TOUS les paquets communs
2. **Choix exclusif** :
   - VLC : 02-display-manager.sh → 03-vlc-setup.sh
   - OU Chromium : 03-chromium-kiosk.sh
3. **Modules optionnels** : 04 à 09 selon les besoins
4. **10-boot-manager.sh** : Toujours en dernier

## Gains de performance

- **Temps d'installation réduit** : Plus de réinstallation de paquets
- **Moins d'utilisation réseau** : apt-get update moins fréquent
- **Cohérence système** : Configuration audio et GPU cohérente
- **Maintenance simplifiée** : Centralisation des paquets de base

## Scripts 04-10 : Problèmes supplémentaires

### 04-rclone-setup.sh
- ✅ Gère correctement l'installation d'unzip si nécessaire
- ⚠️ Le script de sync crée /opt/videos alors qu'il devrait juste vérifier

### 05-glances-setup.sh
- ❌ Installe `curl` déjà présent dans 01-system-config.sh
- **Solution** : Vérification avant installation ajoutée

### 06-cron-setup.sh
- ⚠️ Crée des scripts qui supposent l'existence de services optionnels
- **Solution** : Les scripts devraient vérifier l'existence des services

### 07-services-setup.sh  
- ❌ Le watchdog surveillait des services potentiellement non installés
- **Solution** : Détection dynamique des services à surveiller

### 08-diagnostic-tools.sh
- ✅ Aucune installation de paquets, seulement création d'outils

### 10-boot-manager.sh
- ✅ Gère le démarrage progressif sans installer de paquets

## Recommandations futures

1. **Créer un fichier de manifeste** listant tous les paquets par module
2. **Utiliser un système de cache** pour éviter les vérifications répétées
3. **Centraliser la création des répertoires** dans une fonction unique
4. **Logger les paquets installés** pour éviter les doublons
5. **Vérifier l'existence des services** avant de les surveiller/redémarrer