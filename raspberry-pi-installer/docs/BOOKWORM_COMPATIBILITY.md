# 🔄 Compatibilité Raspberry Pi OS Bookworm

## Vue d'ensemble

Pi Signage v2.4.7+ est **100% compatible** avec Raspberry Pi OS Bookworm et **préserve toutes les configurations existantes**, notamment l'autologin.

## 🎯 Principe de fonctionnement

### 1. Détection intelligente
L'installateur détecte automatiquement :
- L'environnement graphique existant (Wayland, X11, LightDM, etc.)
- L'autologin configuré (via Raspberry Pi Imager, raspi-config, ou manuel)
- L'utilisateur configuré pour l'autologin

### 2. Préservation des configurations
**AUCUNE modification** n'est apportée aux configurations existantes :
- ✅ L'autologin existant est préservé
- ✅ L'utilisateur configuré est respecté
- ✅ Les paramètres système restent intacts
- ✅ `/boot/config.txt` et `/boot/cmdline.txt` ne sont PAS modifiés

### 3. Adaptation automatique
Pi Signage s'adapte à votre configuration :
- Si autologin configuré pour `pi` → utilise `pi`
- Si autologin configuré pour un autre utilisateur → s'adapte à cet utilisateur
- Si pas d'autologin → affiche un message informatif (sans forcer de configuration)

## 📋 Configurations testées

### Raspberry Pi OS avec Desktop (Bookworm)
- **Raspberry Pi Imager** : Autologin configuré via l'outil → ✅ Préservé
- **raspi-config** : Autologin configuré via le menu → ✅ Préservé
- **Installation fraîche** : Sans autologin → ✅ Fonctionne en mode manuel

### Environnements graphiques supportés
- **Wayfire** (nouveau desktop Bookworm) → ✅ Support natif
- **LXDE/PIXEL** (desktop classique) → ✅ Support natif
- **X11 minimal** → ✅ Détecté et utilisé
- **Wayland** → ✅ Détecté et utilisé

## 🔍 Vérification de l'autologin

Pour vérifier votre configuration actuelle :

```bash
# L'installateur vérifie automatiquement lors de l'installation
# Pour vérifier manuellement :
grep "autologin" /etc/lightdm/lightdm.conf 2>/dev/null
grep "autologin" /etc/systemd/system/getty@tty1.service.d/autologin.conf 2>/dev/null
```

## ⚙️ Configuration de l'autologin

Si vous souhaitez activer l'autologin **après** l'installation :

### Via raspi-config (recommandé)
```bash
sudo raspi-config
# System Options > Boot / Auto Login > Desktop Autologin
```

### Via Raspberry Pi Imager
Lors de la création de la carte SD, dans les options avancées :
- Cocher "Enable SSH"
- Configurer le nom d'utilisateur et mot de passe
- L'autologin sera configuré automatiquement

## 🚨 Problèmes courants

### "L'autologin ne fonctionne pas"
**Cause** : L'autologin n'était pas configuré avant l'installation
**Solution** : Utiliser `raspi-config` pour l'activer

### "Le système utilise le mauvais utilisateur"
**Cause** : L'autologin était configuré pour un autre utilisateur
**Solution** : Pi Signage s'adapte automatiquement à l'utilisateur configuré

### "Je veux changer l'utilisateur"
**Solution** : 
1. Changer l'autologin via `raspi-config`
2. Réinstaller Pi Signage qui détectera le nouvel utilisateur

## 💡 Bonnes pratiques

1. **Avant l'installation** : Si vous voulez l'autologin, configurez-le d'abord via raspi-config
2. **Utilisateur recommandé** : `pi` pour Chromium, `signage` pour VLC (mais tout utilisateur fonctionne)
3. **Vérification** : L'installateur affiche automatiquement l'autologin détecté

## 🔧 Détails techniques

### Fichiers vérifiés (sans modification)
- `/etc/lightdm/lightdm.conf` - Configuration LightDM
- `/etc/gdm3/custom.conf` - Configuration GDM3
- `/etc/sddm.conf.d/autologin.conf` - Configuration SDDM
- `/etc/systemd/system/getty@tty1.service.d/autologin.conf` - Autologin console

### Ordre de priorité
1. Configuration graphique (LightDM, GDM3, SDDM)
2. Configuration console (systemd/getty)
3. Pas de configuration → Message informatif

## ✅ Garanties

- **AUCUNE** modification des configurations système existantes
- **AUCUN** écrasement de l'autologin configuré
- **AUCUNE** création forcée d'autologin
- Respect total de vos choix de configuration