# Plan de Migration v0.8.1 - Refonte Bookworm/Wayland
Date: 2025-09-25
État initial: v0.8.0

## ANALYSE CRITIQUE DES PROBLÈMES IDENTIFIÉS

### 1. Problèmes de Pile Vidéo
- **VLC 3.x incompatible** avec V4L2-request sur Bookworm
- **MPV mal configuré** sans raspberrypi-ffmpeg
- **Services système** ne peuvent pas accéder à la session Wayland

### 2. Problèmes de Permissions
- Services tournant en root/système sans accès DRM/GBM
- Groupes video/render manquants
- seatd non configuré correctement

### 3. Problèmes d'Architecture
- Pas de détection Wayland/X11
- Configuration hardcodée non adaptative
- Absence de validation post-installation

## OBJECTIFS v0.8.1

1. **Compatibilité totale Bookworm/Wayland**
2. **MPV comme lecteur principal** (VLC en fallback)
3. **Services utilisateur** (systemd --user)
4. **Détection automatique** de l'environnement
5. **Validation complète** post-installation

## CHANGEMENTS MAJEURS

### A. Installation System
```bash
# Nouveaux paquets requis
- raspberrypi-ffmpeg (accélération HW)
- seatd (gestion des sessions)
- v4l-utils (validation V4L2)
- libdrm-tests (tests DRM)
```

### B. Architecture Services
```
AVANT (v0.8.0):
/etc/systemd/system/pisignage-player.service (root/system)

APRÈS (v0.8.1):
~/.config/systemd/user/pisignage-player.service (user session)
```

### C. Configuration MPV
```ini
# Nouveau mpv.conf optimisé Bookworm
hwdec=drm
vo=gpu-next
gpu-context=wayland
profile=gpu-hq
```

### D. Détection Environnement
```bash
if [ -n "$WAYLAND_DISPLAY" ]; then
  # Mode Wayland
elif [ -n "$DISPLAY" ]; then
  # Mode X11
else
  # Mode TTY/DRM direct
fi
```

## ÉTAPES DE MIGRATION

### Phase 1: Préparation
1. Backup configuration actuelle
2. Arrêt des services v0.8.0
3. Nettoyage des anciens services

### Phase 2: Installation
1. Mise à jour des paquets système
2. Configuration des permissions
3. Installation des nouveaux scripts

### Phase 3: Configuration
1. Migration vers services utilisateur
2. Configuration MPV/VLC adaptative
3. Tests de validation

### Phase 4: Validation
1. Tests accélération HW
2. Tests permissions DRM/V4L2
3. Tests lecture vidéo H.264/H.265

## ROLLBACK PLAN

Si problème:
```bash
git checkout v0.8.0
./install.sh
systemctl restart pisignage-player
```

## MEMBRES DE L'ÉQUIPE IMPLIQUÉS

- **Lead Dev**: Architecture & Services
- **Video Team**: Configuration MPV/VLC
- **DevOps**: Scripts installation/validation
- **QA**: Tests sur différents Pi (3B+, 4, 5, Zero 2W)

## TIMELINE

- Jour 1: Développement scripts migration
- Jour 2: Tests unitaires composants
- Jour 3: Intégration & tests système
- Jour 4: Validation sur Pi frais
- Jour 5: Documentation & release

## CRITÈRES DE SUCCÈS

✓ MPV lit H.264/H.265 avec accélération HW
✓ Pas d'erreur permissions DRM/V4L2
✓ Service démarre automatiquement au boot
✓ CPU < 30% en lecture 1080p60
✓ Fonctionne sur Bookworm Desktop ET Lite