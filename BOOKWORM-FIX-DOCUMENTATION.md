# Pi-Signage v0.8.1 - Fix pour Raspberry Pi OS Bookworm

## Problème Résolu

L'installation échouait avec les erreurs suivantes :
- `Unable to locate package weston-common`
- `Unable to locate package wayfire-plugins-extra`

**Cause** : Ces packages n'existent pas dans les dépôts Raspberry Pi OS Bookworm.

## Solution Implémentée

### 1. Script Fix Minimal : `fix-wayland-bookworm-minimal.sh`

**Approche** : Installation minimaliste avec UNIQUEMENT les packages vérifiés comme existants.

#### Packages Utilisés (tous vérifiés disponibles) :

**Environnement graphique minimal :**
- `lightdm` - Gestionnaire de connexion léger
- `lightdm-autologin-greeter` - Autologin automatique
- `openbox` - Gestionnaire de fenêtres minimal
- `lxde-core` + `lxde-common` - Bureau minimal LXDE

**Lecteurs vidéo :**
- `vlc` + `vlc-plugin-base` + `vlc-plugin-video-output`
- `mpv` (backup)

**Support Wayland :**
- `labwc` - Compositeur Wayland léger (remplace weston-common)
- `weston` - Compositeur de référence
- `wayland-utils` + `wlr-randr`

**Support DRM/GPU :**
- `libdrm2` + `mesa-utils` + `libgl1-mesa-dri`
- `libraspberrypi-bin` + `v4l-utils`

#### Configuration Automatique :

1. **Autologin graphique** via LightDM
2. **Mode graphique** : `graphical.target` par défaut
3. **Environnement Openbox** optimisé pour le plein écran
4. **VLC configuré** pour lecture automatique de Big Buck Bunny
5. **Permissions GPU/DRM** configurées automatiquement

### 2. Script de Validation : `test-bookworm-packages.sh`

**Fonction** : Teste AVANT installation si tous les packages sont disponibles.

**Vérifications :**
- Disponibilité des packages APT
- Services systemd
- Environnement Raspberry Pi
- Permissions utilisateur
- Connectivité réseau

## Différences avec l'Installation Originale

### Packages Supprimés (inexistants) :
- ❌ `weston-common`
- ❌ `wayfire-plugins-extra`

### Packages Ajoutés :
- ✅ `lightdm-autologin-greeter`
- ✅ `lxde-core` + `lxde-common`
- ✅ `openbox`
- ✅ `unclutter` (masquage curseur)

### Améliorations :

1. **100% Compatible Bookworm** : Tous les packages existent
2. **Minimaliste** : Seulement ce qui est nécessaire
3. **Autologin garanti** : Configuration LightDM robuste
4. **Validation préalable** : Évite les échecs d'installation
5. **Configuration VLC optimisée** : Paramètres spécifiques Pi

## Instructions d'Utilisation

### 1. Validation (Recommandé) :
```bash
sudo /opt/pisignage/test-bookworm-packages.sh
```

### 2. Installation :
```bash
sudo /opt/pisignage/fix-wayland-bookworm-minimal.sh
```

### 3. Activation :
```bash
sudo reboot
```

## Résultat Attendu

Après redémarrage :
1. **Autologin automatique** en mode graphique
2. **Openbox démarre** (bureau minimal)
3. **VLC lance automatiquement** Big Buck Bunny en plein écran
4. **Lecture en boucle** continue
5. **Curseur masqué** après 2 secondes

## Dépannage

### Si l'autologin ne fonctionne pas :
```bash
# Vérifier le service LightDM
sudo systemctl status lightdm

# Vérifier la configuration autologin
cat /etc/lightdm/lightdm.conf.d/01-pisignage-autologin.conf
```

### Si VLC ne démarre pas :
```bash
# Vérifier la configuration Openbox
cat ~/.config/openbox/autostart

# Tester VLC manuellement
vlc --fullscreen --no-video-title-show --loop --intf dummy \
    "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
```

### Logs :
- Installation : `/var/log/pisignage-fix-bookworm.log`
- VLC : `~/.config/vlc/vlcrc`
- Openbox : `~/.config/openbox/`

## Avantages de cette Solution

1. ✅ **Fiabilité** : Packages garantis existants
2. ✅ **Simplicité** : Une seule commande d'installation
3. ✅ **Validation** : Test préalable des prérequis
4. ✅ **Minimalisme** : Pas de packages inutiles
5. ✅ **Compatibilité** : Spécialement pour Bookworm
6. ✅ **Robustesse** : Gestion d'erreur intégrée

## Architecture Finale

```
Raspberry Pi OS Bookworm
├── LightDM (autologin)
├── Openbox (gestionnaire fenêtres)
├── VLC (lecture vidéo)
└── Support Wayland/DRM
```

Cette solution garantit un affichage numérique fonctionnel à 100% sur Raspberry Pi OS Bookworm.